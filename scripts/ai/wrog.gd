class_name Wrog
extends CharacterBody3D
## Przeciwnik ludzki (Szabrownicy, Najemnicy). Percepcja: wzrok, słuch, pamięć ostatniej pozycji.
## Zachowanie: patrol → czujność → walka (osłony, flankowanie, ostrzał) → szukanie → ucieczka przy niskim morale.

signal zginal(wrog: Wrog)

const MASKA_WZROKU := Balistyka.WARSTWA_SWIAT
const MASKA_STRZALU := Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_HITBOX_GRACZA | Balistyka.WARSTWA_HITBOX_WROGA

var frakcja := "szabrownik"
var dane_frakcji := {}
var nazwa_jednostki := "Szabrownik"
var oddzial: Variant = null     # MenedzerWrogow.Oddzial
var rola := "strzelec"           # strzelec | dowodca | flanka
var cecha := "zwykly"            # ostrozny | agresywny | tchorzliwy | zwykly
var menedzer: Node

var cialo: Cialo
var bron: Przedmiot
var pancerz: Przedmiot
var helm: Przedmiot
var lup: Array = []
var zapas_mag := 0
var amunicja_id := ""

var stan := "patrol"
var gracz: Node3D              # bieżący cel: gracz, wróg z innej frakcji albo mutant (nazwa historyczna)
var _wybor_t := 0.0
var _moje_hitboxy: Array[RID] = []
var ostatnia_pozycja := Vector3.ZERO
var widzi := false
var wykrycie := 0.0
var czas_bez_kontaktu := 0.0
var morale := 50.0
var cel_ruchu := Vector3.ZERO
var biegnie := false
var kucanie := 0.0
var _kucanie_cel := 0.0

var _agent: NavigationAgent3D
var _model: Node3D
var _czesci := {}
var _percepcja_t := 0.0
var _decyzja_t := 0.0
var _strzal_t := 0.0
var _seria := 0
var _reakcja := 0.0
var _przeladowanie := 0.0
var _w_magazynku := 0
var _patrol_t := 0.0
var _krok_t := 0.0
var _anim_t := 0.0
var _wychyl_t := 0.0
var _w_oslonie := false
var _oslona := {}
var _napis_t := 0.0
var _czas_walki := 0.0
const RAMIE := 0.29           # długość ramienia i przedramienia
var _md := {}
var _mag_node: Node3D
var _latarka: SpotLight3D
var _odrzut_anim := 0.0
var _przeladowanie_max := 1.0
var _oddech := 0.0
var _rozgl := 0.0
var _drgniecie := 0.0         # odrzut ciała po trafieniu (0..1)
var _ost_kier := Vector3.FORWARD
var _nasluch := false         # czujny w miejscu: słyszał odległe strzały, nie idzie sprawdzać
var _sluch_ms := -10000
var _sluch_pos := Vector3.ZERO
var _sluch_d := 0.0
var _przygwozdzenie := 0.0   # ostrzał gracza psuje celność
var _zachwianie := 0.0        # chwila po trafieniu: nie strzela
var _zachwianie_cd := 0.0
var _trzymaj_t := 0.0         # po utracie kontaktu: trzyma kąt zamiast od razu szukać
var _opatrunki := 0
var _opatr_t := 0.0
var _krew_t := 0.0
var posterunek := {}          # {"pos", "kier"}: wojskowy w gnieździe z worków, nie opuszcza go
var _cykl_t := 0.0


func _init() -> void:
	collision_layer = Balistyka.WARSTWA_POSTACIE
	collision_mask = Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_POSTACIE


func przygotuj(frak: String, zestaw: Dictionary, rng: RandomNumberGenerator) -> void:
	frakcja = frak
	dane_frakcji = Dane.frakcje[frak]
	nazwa_jednostki = {"szabrownik": "Szabrownik", "najemnik": "Najemnik", "wojskowy": "Wojskowy"}.get(frak, frak)
	_opatrunki = rng.randi_range(0, 1) if frak == "szabrownik" else rng.randi_range(1, 3)
	amunicja_id = zestaw["amunicja"]
	bron = Gra.nowy_naladowany(zestaw["bron"], amunicja_id)
	_w_magazynku = _pojemnosc()
	zapas_mag = int(zestaw["magazynki"])
	if zestaw.get("pancerz") != null:
		pancerz = Przedmiot.nowy(zestaw["pancerz"])
		pancerz.dane["wytrz"] *= rng.randf_range(0.5, 1.0)
	if zestaw.get("helm") != null:
		helm = Przedmiot.nowy(zestaw["helm"])
	for i in rng.randi_range(0, 2):
		var pid := Dane.losuj(dane_frakcji["lup"], rng)
		if pid != "":
			lup.append(Przedmiot.nowy(pid))
	cecha = ["ostrozny", "agresywny", "tchorzliwy", "zwykly", "zwykly"][rng.randi() % 5]
	morale = float(dane_frakcji["morale"]) * 100.0 + {"agresywny": 15.0, "tchorzliwy": -15.0}.get(cecha, 0.0)


func _pojemnosc() -> int:
	var bd: Dictionary = bron.defn()["bron"]
	if bd.has("wewnetrzny"):
		return int(bd["wewnetrzny"])
	return int(Dane.def(bd["magazynki"][0])["magazynek"]["pojemnosc"])


func _ready() -> void:
	add_to_group("wrogowie")
	cialo = Cialo.new()
	cialo.npc = true
	cialo.smierc.connect(_smierc)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	_agent = NavigationAgent3D.new()
	_agent.path_search_max_polygons = 20000
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.6
	_agent.radius = 0.35
	_agent.height = 1.7
	add_child(_agent)
	_buduj_model()
	Gra.halas.connect(_uslyszal)
	_patrol_t = randf_range(1.0, 4.0)


# ------------------------------------------------------------------ model i trafienia

func _buduj_model() -> void:
	var kol: Dictionary = dane_frakcji.get("kolory", {})
	var ubr := _kolor(kol.get("ubranie", [0.3, 0.3, 0.3]))
	var spod := _kolor(kol.get("spodnie", [0.2, 0.2, 0.2]))
	var gl := _kolor(kol.get("glowa", [0.2, 0.2, 0.2]))
	var skora := Color(0.6, 0.46, 0.38)
	var ciemny := Color(0.09, 0.085, 0.08)
	var rek := ciemny if frakcja != "szabrownik" else skora
	var ubr_c := ubr.darkened(0.25)
	_model = Node3D.new()
	add_child(_model)
	# miednica i pas
	_czesci["biodra"] = _czesc(_model, Vector3(0, 0.95, 0))
	_czesci["biodra"].add_child(_bryly([
		[Vector3(0, 0.04, 0), Vector3(0.34, 0.2, 0.22), spod],
		[Vector3(0, 0.13, 0), Vector3(0.36, 0.05, 0.24), ciemny],
		[Vector3(0.12, 0.1, -0.12), Vector3(0.07, 0.08, 0.04), ubr_c],
	]))
	# tułów: brzuch, klatka, kołnierz
	_czesci["tulow"] = _czesc(_czesci["biodra"], Vector3(0, 0.12, 0))
	var tul := [
		[Vector3(0, 0.15, 0), Vector3(0.36, 0.28, 0.22), ubr],
		[Vector3(0, 0.4, 0), Vector3(0.43, 0.26, 0.25), ubr],
		[Vector3(0, 0.55, 0.01), Vector3(0.22, 0.05, 0.19), ubr_c],
		[Vector3(0, 0.03, -0.01), Vector3(0.38, 0.06, 0.24), ubr_c],
	]
	var panc := []
	if pancerz != null:
		var kp := Color(0.2, 0.24, 0.17) if frakcja != "szabrownik" else Color(0.16, 0.18, 0.26)
		panc.append([Vector3(0, 0.35, 0), Vector3(0.41, 0.34, 0.3), kp])
		for i in 3:
			panc.append([Vector3(-0.1 + i * 0.1, 0.24, -0.16), Vector3(0.075, 0.12, 0.05), kp.darkened(0.2)])
		panc.append([Vector3(-0.14, 0.43, -0.16), Vector3(0.07, 0.08, 0.04), kp.darkened(0.25)])
	else:
		# kamizelka wędkarska z kieszeniami
		tul.append([Vector3(0, 0.33, -0.005), Vector3(0.44, 0.3, 0.26), Color(0.32, 0.3, 0.2)])
		for x in [-0.11, 0.11]:
			tul.append([Vector3(x, 0.26, -0.14), Vector3(0.1, 0.09, 0.04), Color(0.27, 0.25, 0.17)])
	if frakcja == "szabrownik" and randf() < 0.6:
		tul.append([Vector3(0, 0.33, 0.2), Vector3(0.3, 0.36, 0.15), Color(0.3, 0.22, 0.14)])   # tobołek
		tul.append([Vector3(0, 0.53, 0.2), Vector3(0.24, 0.06, 0.13), Color(0.25, 0.18, 0.11)])
	_czesci["tulow"].add_child(_bryly(tul))
	if not panc.is_empty():
		# osobny węzeł: zdjęty z ciała pancerz znika z modelu
		_czesci["pancerz_m"] = _bryly(panc)
		_czesci["tulow"].add_child(_czesci["pancerz_m"])
	# głowa
	_czesci["glowa"] = _czesc(_czesci["tulow"], Vector3(0, 0.58, 0))
	var glowa_bryly := [
		[Vector3(0, 0.04, 0), Vector3(0.1, 0.08, 0.1), skora],
		[Vector3(0, 0.17, 0), Vector3(0.2, 0.24, 0.22), skora],
		[Vector3(0, 0.135, -0.113), Vector3(0.032, 0.05, 0.022), skora.darkened(0.05)],    # nos
	]
	if frakcja == "szabrownik":
		glowa_bryly.append([Vector3(0, 0.2, 0.025), Vector3(0.26, 0.3, 0.24), gl])           # kaptur
		glowa_bryly.append([Vector3(0, 0.1, -0.112), Vector3(0.19, 0.1, 0.02), Color(0.14, 0.11, 0.1)])  # chusta
	elif frakcja == "wojskowy":
		glowa_bryly.append([Vector3(0, 0.07, 0.0), Vector3(0.215, 0.07, 0.235), gl])         # kołnierz
	else:
		glowa_bryly.append([Vector3(0, 0.15, 0.0), Vector3(0.215, 0.27, 0.235), gl])         # kominiarka
		glowa_bryly.append([Vector3(0, 0.19, -0.119), Vector3(0.15, 0.045, 0.01), skora.darkened(0.2)])
		glowa_bryly.append([Vector3(0, 0.19, -0.125), Vector3(0.14, 0.026, 0.01), Color(0.06, 0.05, 0.05)])
	var gm := _bryly(glowa_bryly)
	_czesci["glowa"].add_child(gm)
	if helm != null:
		_czesci["helm_m"] = _bryly([[Vector3(0, 0.29, 0.0), Vector3(0.27, 0.12, 0.29), Color(0.22, 0.26, 0.18)],
			[Vector3(0, 0.24, 0.0), Vector3(0.31, 0.03, 0.33), Color(0.2, 0.24, 0.16)],
			[Vector3(0, 0.33, 0.0), Vector3(0.2, 0.04, 0.22), Color(0.24, 0.28, 0.2)]])
		_czesci["glowa"].add_child(_czesci["helm_m"])
	# twarz z teksturą (oczy, brwi, zarost) albo kominiarka najemnika
	var tw := Bryly.instancja([Bryly.quad(Vector3(0, 0.165, -0.1112 if frakcja != "najemnik" else -0.1185), Vector2(0.18, 0.21),
		Vector3(0, 0, -1), "twarz" if frakcja != "najemnik" else "twarz_maska")], false)
	_czesci["glowa"].add_child(tw)
	# ręce: ramię -> łokieć -> dłoń (ustawiane kinematyką odwrotną na chwyt broni)
	for strona in [-1, 1]:
		var ramie := _czesc(_czesci["tulow"], Vector3(0.25 * strona, 0.5, 0))
		ramie.add_child(_bryly([[Vector3(0, -0.13, 0), Vector3(0.12, 0.29, 0.12), ubr], [Vector3(0, 0.0, 0), Vector3(0.14, 0.08, 0.14), ubr_c]]))
		var lokiec := _czesc(ramie, Vector3(0, -RAMIE, 0))
		lokiec.add_child(_bryly([[Vector3(0, -0.12, 0), Vector3(0.095, 0.25, 0.095), ubr], [Vector3(0, -0.26, 0), Vector3(0.1, 0.04, 0.1), ubr_c],
			[Vector3(0, -RAMIE, -0.01), Vector3(0.075, 0.095, 0.085), rek]]))
		var s := "_l" if strona < 0 else "_p"
		_czesci["ramie" + s] = ramie
		_czesci["lokiec" + s] = lokiec
		# nogi: udo -> kolano -> stopa
		var noga := _czesc(_czesci["biodra"], Vector3(0.1 * strona, 0.0, 0))
		noga.add_child(_bryly([[Vector3(0, -0.22, 0), Vector3(0.15, 0.46, 0.16), spod], [Vector3(0.08 * strona, -0.25, -0.02), Vector3(0.04, 0.1, 0.09), spod.darkened(0.2)]]))
		var kolano := _czesc(noga, Vector3(0, -0.45, 0))
		kolano.add_child(_bryly([[Vector3(0, -0.2, 0), Vector3(0.135, 0.4, 0.145), spod],
			[Vector3(0, -0.38, 0), Vector3(0.14, 0.1, 0.15), ciemny], [Vector3(0, -0.455, -0.045), Vector3(0.13, 0.09, 0.26), ciemny]]))
		_czesci["noga" + s] = noga
		_czesci["kolano" + s] = kolano
	# broń w rękach
	var md := Modele.bron(bron.id)
	_md = md
	_czesci["bron"] = _czesc(_czesci["tulow"], Vector3(0.1, 0.25, -0.25))
	_czesci["bron"].add_child(Bryly.instancja(md["cialo3"], false) if md.has("cialo3") else Kit.instancja(md["cialo"]))
	if md.has("mag3") and not (md["mag3"] as Array).is_empty():
		_mag_node = Bryly.instancja(md["mag3"], false)
	else:
		_mag_node = Kit.instancja(md["mag"]) if not md["mag"].is_empty() else Node3D.new()
	_czesci["bron"].add_child(_mag_node)
	_czesci["wylot"] = Vector3(md["lufa"])
	# latarka na broni najemnika: włączana przy czujności i walce (zdradza pozycję)
	if frakcja != "szabrownik" and bron.defn()["bron"]["slot"] != "pistolet":
		var lw := Vector3(md["lufa"]) + Vector3(0.0, -0.035, 0.12)
		_czesci["bron"].add_child(Kit.instancja([[lw + Vector3(0, 0, 0.02), Vector3(0.03, 0.03, 0.07), Color(0.1, 0.1, 0.1)]]))
		_latarka = SpotLight3D.new()
		_latarka.light_color = Color(0.92, 0.95, 1.0)
		_latarka.light_energy = 2.2
		_latarka.spot_range = 15.0
		_latarka.spot_angle = 17.0
		_latarka.spot_attenuation = 1.2
		_latarka.shadow_enabled = false
		_latarka.visible = false
		_latarka.position = lw - Vector3(0, 0, 0.02)
		_czesci["bron"].add_child(_latarka)
	# hitboksy
	_hitbox(_czesci["glowa"], "glowa", Vector3(0, 0.17, 0), Vector3(0.24, 0.3, 0.26))
	_hitbox(_czesci["tulow"], "klatka", Vector3(0, 0.4, 0), Vector3(0.44, 0.32, 0.27))
	_hitbox(_czesci["tulow"], "brzuch", Vector3(0, 0.12, 0), Vector3(0.4, 0.26, 0.25))
	for s2 in ["_l", "_p"]:
		_hitbox(_czesci["ramie" + s2], "rece", Vector3(0, -0.14, 0), Vector3(0.13, 0.3, 0.13))
		_hitbox(_czesci["lokiec" + s2], "rece", Vector3(0, -0.14, 0), Vector3(0.11, 0.3, 0.11))
		_hitbox(_czesci["noga" + s2], "nogi", Vector3(0, -0.22, 0), Vector3(0.16, 0.46, 0.17))
		_hitbox(_czesci["kolano" + s2], "nogi", Vector3(0, -0.22, 0), Vector3(0.15, 0.46, 0.16))
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _kolor(a: Array) -> Color:
	return Color(a[0], a[1], a[2])


## Bryły postaci w stylu Iron Blight: fazowane, z teksturą tkaniny barwioną kolorem frakcji
## (skóra i buty osobnymi materiałami).
func _bryly(boxes: Array) -> MeshInstance3D:
	var cz := []
	for bx in boxes:
		var c: Color = bx[2]
		var s3: Vector3 = bx[1]
		var faza := minf(s3.x, minf(s3.y, s3.z)) * 0.22
		var rot: Vector3 = bx[3] if bx.size() > 3 else Vector3.ZERO
		var m := "tkanina"
		var k := Color(minf(1.0, c.r / 0.75), minf(1.0, c.g / 0.75), minf(1.0, c.b / 0.75))
		if absf(c.r - 0.6) < 0.08 and absf(c.g - 0.46) < 0.08 and absf(c.b - 0.38) < 0.08:
			m = "skora_npc"
			k = Color(c.r / 0.69, c.g / 0.53, c.b / 0.44).clamp()
		elif c.r < 0.11 and c.g < 0.11 and c.b < 0.11:
			m = "but"
			k = Color.WHITE
		# wydłużone bryły bez obrotu (ramiona, przedramiona, uda, łydki) jako walce – okrągłe kończyny
		var mx := maxf(s3.x, maxf(s3.y, s3.z))
		var drugi := (s3.x + s3.y + s3.z - mx) * 0.5
		if rot == Vector3.ZERO and s3.y == mx and mx > drugi * 2.2 and m != "but":
			var srod: Vector3 = bx[0]
			var r0 := (s3.x + s3.z) * 0.25 * 1.08
			cz.append({"t": "walec", "a": srod + Vector3(0, s3.y * 0.5, 0), "b": srod - Vector3(0, s3.y * 0.5, 0),
				"r0": r0, "r1": r0 * 0.88, "m": m, "k": k, "n": 8, "kat": PI / 8.0})
			continue
		cz.append({"t": "box", "c": bx[0], "s": s3, "m": m, "k": k, "f": minf(s3.x, minf(s3.y, s3.z)) * 0.3, "r": rot})
	var mi := Bryly.instancja(cz, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


func _czesc(rodzic: Node3D, poz: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = poz
	rodzic.add_child(n)
	return n


func _hitbox(rodzic: Node3D, czesc: String, poz: Vector3, roz: Vector3) -> void:
	var a := Area3D.new()
	a.collision_layer = Balistyka.WARSTWA_HITBOX_WROGA
	a.collision_mask = 0
	a.monitoring = false
	a.set_meta("czesc", czesc)
	a.set_meta("wlasciciel", self)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = roz
	cs.shape = bs
	cs.position = poz
	a.add_child(cs)
	rodzic.add_child(a)
	_moje_hitboxy.append(a.get_rid())


# ------------------------------------------------------------------ cele (gracz, inne frakcje, mutanty)

## Czy ta postać jest dla nas wroga: inna frakcja ludzka, mutant albo gracz.
func wrogi(n: Node) -> bool:
	if n == null or n == self or not is_instance_valid(n):
		return false
	if n is Gracz:
		return true
	var f = n.get("frakcja")
	if f == null:
		return false
	return String(f) != frakcja


func _zywy(n: Node) -> bool:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return false
	var c = n.get("cialo")
	return c != null and not c.martwy


static func _kuc(n: Node) -> float:
	var k = n.get("kucanie")
	return float(k) if k != null else 0.0


static func _halas_celu(n: Node) -> float:
	var h = n.get("halas_ruchu")
	return float(h) if h != null else 0.4


static func _swieci(n: Node) -> bool:
	if n is Gracz:
		return (n as Gracz).latarka.visible
	var l = n.get("_latarka")
	return l != null and is_instance_valid(l) and (l as Node3D).visible


func _wysokosc_celu(n: Node, gora: bool) -> float:
	return lerpf(1.45, 0.85, _kuc(n)) if gora else lerpf(1.12, 0.7, _kuc(n))


## Punkt, w który patrzy/celuje (mutant pod sufitem ma własny środek ciała).
func _punkt_celu(n: Node3D, gora: bool) -> Vector3:
	if n.has_method("punkt_celu"):
		return n.punkt_celu()
	return n.global_position + Vector3.UP * _wysokosc_celu(n, gora)


func _widze(n: Node3D, oko: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	var cel := _punkt_celu(n, true)
	var d := oko.distance_to(cel)
	if d > 32.0:
		return false
	var przod := -global_basis.z
	var kat := rad_to_deg(acos(clampf(przod.dot((cel - oko).normalized()), -1.0, 1.0)))
	if kat > 62.0 and d > 2.5 and stan != "walka":
		return false
	if kat > 95.0 and d > 2.5:
		return false
	var q := PhysicsRayQueryParameters3D.create(oko, cel, MASKA_WZROKU)
	if not space.intersect_ray(q).is_empty():
		var cel2 := n.global_position + Vector3.UP * 0.6
		q = PhysicsRayQueryParameters3D.create(oko, cel2, MASKA_WZROKU)
		if not space.intersect_ray(q).is_empty():
			return false
	return true


## Wybór celu: najbliższy widoczny wróg (gracz nie ma pierwszeństwa). Bieżący cel trzymany, dopóki
## ktoś inny nie jest wyraźnie bliżej – bez przeskakiwania co chwilę.
func _wybierz_cel() -> void:
	var oko := _oko()
	var space := get_world_3d().direct_space_state
	var kandydaci: Array = get_tree().get_nodes_in_group("gracz") + get_tree().get_nodes_in_group("wrogowie") + get_tree().get_nodes_in_group("fauna")
	var najlepszy: Node3D = null
	var best_d := INF
	for n in kandydaci:
		if not (n is Node3D) or not wrogi(n) or not _zywy(n):
			continue
		var d := global_position.distance_to((n as Node3D).global_position)
		if d > 32.0:
			continue
		if not _widze(n, oko, space):
			continue
		if n == gracz:
			d *= 0.6          # trzyma obecny cel
		if d < best_d:
			best_d = d
			najlepszy = n
	if najlepszy != null and najlepszy != gracz:
		if gracz != null and _zywy(gracz) and stan == "walka" and najlepszy is not Gracz:
			_napis(["Tam! Następni!", "Obcy na dziewiątej!", "Uwaga, z boku!"].pick_random())
		gracz = najlepszy
		wykrycie = maxf(wykrycie, 0.5) if stan == "walka" else wykrycie


## Trafienie z broni gracza.
func trafiony(czesc: String, obr: float, pen: float, od_kogo: Node, punkt: Vector3, kier: Vector3) -> void:
	if cialo.martwy:
		return
	var wynik := Balistyka.przez_pancerz({"pancerz": pancerz, "helm": helm}, czesc, obr, pen)
	_ost_kier = kier
	_drgniecie = minf(1.0, _drgniecie + 0.45 + wynik["obr"] * 0.012)
	velocity *= 0.25
	cialo.obrazenia(czesc, wynik["obr"], "pocisk")
	var swiat := get_parent() as Node3D
	if wynik["pancerz"] and not wynik["przebity"]:
		Efekty.czastki(swiat, punkt, -kier, Color(0.9, 0.8, 0.5), 6, 3.0)
		Dzwiek.graj_3d("trafienie_pancerz", punkt, swiat, -2.0)
	else:
		Efekty.czastki(swiat, punkt, -kier, Color(0.45, 0.04, 0.03), 9, 1.8)
		Dzwiek.graj_3d("trafienie_cialo", punkt, swiat, -2.0)
	if cialo.martwy:
		return
	morale -= 8.0 + wynik["obr"] * 0.3
	_przygwozdzenie = minf(2.0, _przygwozdzenie + 0.8)
	# zachwianie po trafieniu, ale nie w kółko: po nim chwila odporności (inaczej seria = paraliż)
	if _zachwianie_cd <= 0.0:
		_zachwianie = minf(0.7, 0.35 + wynik["obr"] * 0.008)
		_zachwianie_cd = 1.4
	_napis_t = 0.0
	if cialo.krwawi() == 2:
		_napis(["Krwawię! Osłaniajcie!", "Trafili mnie! Krwawię!", "Medyka!"].pick_random())
	else:
		_napis(["Dostałem!", "Trafiony!", "Kurwa, boli!"].pick_random())
	# reakcja: wie, skąd strzelano (gracz, inna frakcja albo mutant)
	if od_kogo is Node3D and wrogi(od_kogo):
		gracz = od_kogo
		ostatnia_pozycja = gracz.global_position
		wykrycie = 1.0
		if stan != "walka" and stan != "ucieczka":
			_wejdz_w_walke()
		if oddzial:
			oddzial.alarm(ostatnia_pozycja, self)
	_reakcja = maxf(_reakcja, 0.25)


# ------------------------------------------------------------------ percepcja

func _uslyszal(pos: Vector3, zasieg: float, zrodlo: Node) -> void:
	if cialo == null or cialo.martwy or zrodlo == self:
		return
	if zrodlo is Wrog and not wrogi(zrodlo):
		return
	if global_position.distance_to(pos) > zasieg:
		return
	# droga dźwięku przez korytarze i drzwi; seria strzałów z jednego miejsca liczona raz
	var teraz := Time.get_ticks_msec()
	var d := _sluch_d
	if teraz - _sluch_ms > 400 or pos.distance_to(_sluch_pos) > 2.0:
		d = Balistyka.odleglosc_dzwieku(get_world_3d(), pos, global_position)
		_sluch_ms = teraz
		_sluch_pos = pos
		_sluch_d = d
	if d > zasieg:
		return
	if zrodlo is Node3D and wrogi(zrodlo) and (gracz == null or not _zywy(gracz) or stan != "walka"):
		gracz = zrodlo
	if stan in ["patrol", "szukanie", "czujny"]:
		var niepewnosc := clampf(d * 0.15, 0.5, 4.0)
		var strzal := zasieg > 20.0
		if strzal and d < zasieg * 0.42:
			# blisko – od razu w gotowości bojowej i alarm dla oddziału
			ostatnia_pozycja = pos + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * niepewnosc
			if stan != "szukanie":
				_napis(["Strzały!", "Kto strzela?!", "Kontakt!"].pick_random())
			stan = "szukanie"
			_nasluch = false
			czas_bez_kontaktu = 0.0
			if oddzial:
				oddzial.alarm(ostatnia_pozycja, self)
		elif strzal:
			# daleko – nasłuchuje i trzyma pozycję, nie biegnie przez pół budynku
			if stan == "patrol":
				ostatnia_pozycja = pos + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * niepewnosc * 2.0
				_napis(["Strzelają gdzieś...", "Słyszysz? Daleko.", "Ktoś się tam tłucze."].pick_random())
				stan = "czujny"
				_nasluch = true
				czas_bez_kontaktu = 0.0
			elif stan == "czujny" and _nasluch:
				czas_bez_kontaktu = 0.0
		else:
			ostatnia_pozycja = pos + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * niepewnosc
			if stan == "patrol":
				_napis(["Słyszałeś?", "Co to było?", "Ktoś tu jest..."].pick_random())
				stan = "czujny"
			_nasluch = false
			czas_bez_kontaktu = 0.0


func _sprawdz_wzrok() -> void:
	widzi = false
	_wybor_t -= 0.15
	if _wybor_t <= 0.0 or gracz == null or not _zywy(gracz):
		_wybor_t = 0.45
		_wybierz_cel()
	if gracz == null or not _zywy(gracz):
		gracz = null
		return
	widzi = _widze(gracz, _oko(), get_world_3d().direct_space_state)


func _oswietlenie_gracza() -> float:
	if _swieci(gracz):
		return 1.0
	var best := 0.18
	if menedzer:
		for l in menedzer.lampy:
			if not is_instance_valid(l) or l.light_energy < 0.3:
				continue
			var d: float = l.global_position.distance_to(gracz.global_position)
			if d < l.omni_range * 0.75:
				best = maxf(best, 1.0 - d / (l.omni_range * 0.75) * 0.6)
	return best


func _oko() -> Vector3:
	return global_position + Vector3.UP * lerpf(1.6, 1.05, kucanie)


# ------------------------------------------------------------------ pętla

func _physics_process(delta: float) -> void:
	if cialo.martwy:
		return
	cialo.tick(delta)
	if cialo.martwy:
		return
	_percepcja_t -= delta
	if _percepcja_t <= 0.0:
		_percepcja_t = 0.15
		_sprawdz_wzrok()
		_aktualizuj_wykrycie(0.15)
	_napis_t = maxf(0.0, _napis_t - delta)
	_przygwozdzenie = maxf(0.0, _przygwozdzenie - delta * 0.6)
	_zachwianie = maxf(0.0, _zachwianie - delta)
	_zachwianie_cd = maxf(0.0, _zachwianie_cd - delta)
	# krwawienie: krople na podłodze (ślad do wytropienia)
	var k := cialo.krwawi()
	if k > 0:
		_krew_t -= delta
		if _krew_t <= 0.0:
			_krew_t = 0.6 if k == 2 else 1.5
			Efekty.slad(get_parent(), global_position + Vector3(randf_range(-0.2, 0.2), 0.02, randf_range(-0.2, 0.2)), Vector3.UP, true)
		# opatruje się, gdy ma czym i nie jest pod bezpośrednim ostrzałem
		if _opatrunki > 0 and stan in ["walka", "szukanie", "czujny"] and (not widzi or _w_oslonie) and _przygwozdzenie < 0.5 and randf() < delta * 0.8:
			stan = "opatrywanie"
			_opatr_t = randf_range(4.0, 6.0)
			_napis(["Opatruję się!", "Osłaniaj, bandażuję!", "Chwila, krwawię!"].pick_random())
	# wojskowi z posterunku nie opuszczają gniazda: zaalarmowani trzymają wejście
	if not posterunek.is_empty() and stan in ["czujny", "szukanie", "patrol"]:
		_posterunek_alarm(delta)
		_ruch(delta)
		_animuj(delta)
		return
	match stan:
		"opatrywanie":
			_opatrywanie(delta)
		"posterunek":
			_posterunek(delta)
		"patrol":
			_patrol(delta)
		"czujny":
			_czujny(delta)
		"walka":
			_walka(delta)
		"szukanie":
			_szukanie(delta)
		"ucieczka":
			_ucieczka(delta)
	_ruch(delta)
	_animuj(delta)


func _aktualizuj_wykrycie(dt: float) -> void:
	if widzi:
		var d := global_position.distance_to(gracz.global_position)
		var tempo := 1.6 * clampf(12.0 / maxf(d, 1.0), 0.25, 3.0) * _oswietlenie_gracza()
		tempo *= lerpf(1.0, 0.55, _kuc(gracz)) * (1.0 + _halas_celu(gracz) * 0.6)
		if gracz is not Gracz:
			tempo *= 1.6     # obcy w walce są głośni i nie kryją się
		if stan in ["walka", "szukanie"]:
			tempo *= 3.0
		wykrycie = minf(1.0, wykrycie + tempo * dt)
		if wykrycie >= 1.0:
			ostatnia_pozycja = gracz.global_position
			czas_bez_kontaktu = 0.0
			if stan != "walka" and stan != "ucieczka":
				_wejdz_w_walke()
				_napis(["Tam jest!", "Kontakt!", "Widzę go!", "Mam go!"].pick_random())
				if oddzial:
					oddzial.alarm(ostatnia_pozycja, self)
		elif wykrycie > 0.35 and (stan == "patrol" or _nasluch):
			stan = "czujny"
			_nasluch = false
			ostatnia_pozycja = gracz.global_position
	else:
		wykrycie = maxf(0.0, wykrycie - dt * 0.25)


func _wejdz_w_walke() -> void:
	_nasluch = false
	if stan != "walka":
		_czas_walki = 0.0
	stan = "walka"
	_reakcja = float(dane_frakcji.get("reakcja", 0.6)) * randf_range(0.8, 1.4)
	_decyzja_t = 0.0
	czas_bez_kontaktu = 0.0


## Wołane przez oddział, gdy ktoś inny wykrył gracza (łączność radiowa).
func alarm_od_oddzialu(pos: Vector3) -> void:
	if stan == "ucieczka" or cialo.martwy:
		return
	ostatnia_pozycja = pos
	_nasluch = false
	if stan != "walka":
		stan = "szukanie"
		czas_bez_kontaktu = 0.0
		_decyzja_t = 0.0


func _patrol(delta: float) -> void:
	_kucanie_cel = 0.0
	biegnie = false
	_patrol_t -= delta
	if _patrol_t <= 0.0 or (_agent.is_navigation_finished() and cel_ruchu != Vector3.ZERO):
		_patrol_t = randf_range(4.0, 9.0)
		var r := randf_range(2.0, 7.0)
		var p := global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * r
		_idz(_najblizszy_na_siatce(p))


func _czujny(delta: float) -> void:
	biegnie = false
	_kucanie_cel = 0.3 if cecha == "ostrozny" else 0.0
	czas_bez_kontaktu += delta
	if _nasluch:
		_kucanie_cel = 0.5
		_idz(global_position)
		_obroc_do(ostatnia_pozycja, delta, 2.0)
		if czas_bez_kontaktu > 15.0:
			stan = "patrol"
			_nasluch = false
		return
	_idz(ostatnia_pozycja)
	if _agent.is_navigation_finished():
		_obroc_do(ostatnia_pozycja + Vector3(sin(czas_bez_kontaktu), 0, cos(czas_bez_kontaktu)) * 3.0, delta, 2.0)
	if czas_bez_kontaktu > 12.0:
		stan = "patrol"
		_napis(["Pewnie szczury.", "Nic tu nie ma."].pick_random())


func _szukanie(delta: float) -> void:
	biegnie = false
	czas_bez_kontaktu += delta
	if widzi and wykrycie > 0.6:
		_wejdz_w_walke()
		return
	# najpierw trzyma kąt: przykucnięty, broń na ostatnią pozycję gracza
	if _trzymaj_t > 0.0:
		_trzymaj_t -= delta
		_kucanie_cel = 0.5 if _w_oslonie else 0.25
		_idz(global_position)
		_obroc_do(ostatnia_pozycja, delta, 3.0)
		return
	_kucanie_cel = 0.15
	# w oddziale naprzód idzie jeden, reszta osłania z dystansu
	var prow: Node = oddzial.prowadzacy() if oddzial else self
	if prow != self and is_instance_valid(prow) and prow.global_position.distance_to(ostatnia_pozycja) > 2.0:
		var za: Vector3 = prow.global_position + (global_position - prow.global_position).normalized() * 3.5
		if global_position.distance_to(za) > 2.0:
			_idz(_najblizszy_na_siatce(za))
		else:
			_idz(global_position)
			_obroc_do(ostatnia_pozycja, delta, 3.0)
		if czas_bez_kontaktu > 35.0:
			stan = "patrol"
		return
	_idz(ostatnia_pozycja)
	if _agent.is_navigation_finished():
		biegnie = false
		_obroc_do(ostatnia_pozycja + Vector3(sin(czas_bez_kontaktu * 0.7), 0, cos(czas_bez_kontaktu * 0.7)) * 4.0, delta, 2.0)
	if czas_bez_kontaktu > 30.0:
		stan = "patrol" if posterunek.is_empty() else "posterunek"
		_napis(["Straciłem go.", "Uciekł.", "Wracamy."].pick_random())


func _ucieczka(delta: float) -> void:
	biegnie = true
	_kucanie_cel = 0.0
	czas_bez_kontaktu += delta
	if _agent.is_navigation_finished() or _decyzja_t <= 0.0:
		_decyzja_t = 3.0
		var od := global_position - (gracz.global_position if gracz else global_position)
		od.y = 0
		var p := global_position + od.normalized() * 10.0 + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		_idz(_najblizszy_na_siatce(p))
	_decyzja_t -= delta
	if czas_bez_kontaktu > 18.0:
		morale = 30.0
		stan = "szukanie"
	# osaczony strzela
	if widzi and gracz and global_position.distance_to(gracz.global_position) < 5.0:
		_strzelaj(delta)


func _walka(delta: float) -> void:
	if gracz == null:
		stan = "szukanie"
		return
	_czas_walki += delta
	if widzi:
		czas_bez_kontaktu = 0.0
		ostatnia_pozycja = gracz.global_position
	else:
		czas_bez_kontaktu += delta
		if czas_bez_kontaktu > 3.0:
			# nie gna od razu za graczem: trzyma kąt, potem ostrożnie szuka
			stan = "szukanie"
			_trzymaj_t = randf_range(5.0, 11.0) if cecha != "agresywny" else randf_range(2.0, 4.0)
			_napis(["Gdzie on jest?", "Straciłem kontakt!", "Trzymać kąty!"].pick_random())
			return
	if morale < 12.0 and cecha != "agresywny" and posterunek.is_empty():
		stan = "ucieczka"
		czas_bez_kontaktu = 0.0
		_napis(["Spadam stąd!", "Odwrót!", "Nie płacą mi za to!"].pick_random())
		return
	_obroc_do(ostatnia_pozycja, delta, 4.5)
	# przeładowanie za osłoną
	if _przeladowanie > 0.0:
		_przeladowanie -= delta
		_kucanie_cel = 1.0
		if _przeladowanie <= 0.0:
			_w_magazynku = _pojemnosc()
		return
	# na posterunku: zza worków, wstaje do strzału i chowa się
	if not posterunek.is_empty():
		_walka_z_posterunku(delta)
		return
	_decyzja_t -= delta
	if _decyzja_t <= 0.0:
		_decyzja_t = randf_range(6.0, 11.0) if _w_oslonie else randf_range(3.0, 5.0)
		if _potrzeba_zmiany_pozycji():
			_wybierz_pozycje()
	var idzie := not _agent.is_navigation_finished() and cel_ruchu.distance_to(global_position) > 0.6
	if _w_oslonie and _oslona.get("niska", false):
		# wychylanie się zza niskiej osłony
		_wychyl_t -= delta
		if _wychyl_t <= 0.0:
			_wychyl_t = randf_range(1.6, 3.2) if _kucanie_cel > 0.5 else randf_range(1.2, 2.4)
			_kucanie_cel = 0.0 if _kucanie_cel > 0.5 else 1.0
	elif idzie:
		_kucanie_cel = 0.35
	elif not _w_oslonie:
		_kucanie_cel = 0.0 if _przygwozdzenie < 1.0 else 1.0
	# pod silnym ostrzałem chowa głowę zamiast odpowiadać ogniem
	if _przygwozdzenie > 1.3 and _w_oslonie:
		_kucanie_cel = 1.0
		return
	if _zachwianie > 0.0:
		return
	if _reakcja > 0.0:
		_reakcja -= delta
		return
	# szabrownicy strzelają z miejsca, wyszkoleni także w marszu
	if idzie and frakcja == "szabrownik":
		return
	if widzi and _kucanie_cel < 0.5:
		_strzelaj(delta)


## Czy warto zmieniać pozycję: brak osłony, osłona już nie zasłania, ranny, albo flankujący.
func _potrzeba_zmiany_pozycji() -> bool:
	if _oslona.is_empty():
		return true
	var pg := gracz.global_position
	var m: Vector3 = _oslona["mebel"]
	if m.distance_to(pg) > (_oslona["pos"] as Vector3).distance_to(pg):
		return true          # gracz obszedł osłonę
	if cialo.procent() < 0.65 and pg.distance_to(global_position) < 8.0:
		return true          # ranny: odskok dalej
	if rola == "flanka" and randf() < 0.5:
		return true
	return randf() < 0.12


func _walka_z_posterunku(delta: float) -> void:
	_idz(posterunek["pos"])
	_cykl_t -= delta
	if _cykl_t <= 0.0:
		_cykl_t = randf_range(2.0, 3.5) if _kucanie_cel < 0.7 else randf_range(1.2, 2.2)
		_kucanie_cel = 1.0 if _kucanie_cel < 0.7 else 0.45
	if _przygwozdzenie > 1.2:
		_kucanie_cel = 1.0
		return
	if _zachwianie > 0.0 or _reakcja > 0.0:
		_reakcja -= delta
		return
	if widzi and _kucanie_cel < 0.7:
		_strzelaj(delta)


func _posterunek(delta: float) -> void:
	if not posterunek.has("pos"):
		stan = "patrol"
		return
	biegnie = false
	_kucanie_cel = 0.55
	_idz(posterunek["pos"])
	var kier: Vector3 = posterunek["kier"]
	_rozgl += delta * 0.4
	_obroc_do(global_position + kier.rotated(Vector3.UP, sin(_rozgl) * 0.5), delta, 1.5)


func _posterunek_alarm(delta: float) -> void:
	biegnie = false
	_kucanie_cel = 0.5
	_idz(posterunek["pos"])
	czas_bez_kontaktu += delta
	if ostatnia_pozycja != Vector3.ZERO:
		_obroc_do(ostatnia_pozycja, delta, 2.5)
	if widzi and wykrycie > 0.6:
		_wejdz_w_walke()
	elif czas_bez_kontaktu > 25.0:
		stan = "posterunek"


func _opatrywanie(delta: float) -> void:
	biegnie = false
	_kucanie_cel = 1.0
	_idz(global_position)
	_opatr_t -= delta
	if widzi and wykrycie >= 1.0 and _opatr_t > 1.5 and randf() < delta * 1.5:
		_wejdz_w_walke()
		return
	if _opatr_t <= 0.0:
		_opatrunki -= 1
		cialo.lecz("krwawienie_ciezkie", {}, null)
		if cialo.krwawi() > 0 and _opatrunki > 0:
			_opatr_t = randf_range(3.0, 4.0)
			return
		stan = "walka" if widzi else "szukanie"
		_trzymaj_t = randf_range(3.0, 6.0)


func _wybierz_pozycje() -> void:
	_w_oslonie = false
	if menedzer == null or gracz == null:
		return
	var flanka := rola == "flanka" or (frakcja != "szabrownik" and randf() < 0.35)
	var ranny := cialo.procent() < 0.65
	var najlepsza := {}
	var best := -INF
	var pg := gracz.global_position
	for o in menedzer.oslony:
		var p: Vector3 = o["pos"]
		var d_ja := global_position.distance_to(p)
		var d_g := pg.distance_to(p)
		if d_ja > (16.0 if flanka else 10.0) or d_g < 3.5 or d_g > 24.0:
			continue
		if menedzer.zajeta_oslona(o, self):
			continue
		# osłona ma być między nami a graczem: mebel bliżej gracza niż punkt
		var m: Vector3 = o["mebel"]
		var ochrona := 1.0 if m.distance_to(pg) < p.distance_to(pg) else -1.0
		# blisko obecnej pozycji: krótkie, przemyślane skoki zamiast biegania po pół mapy
		var s := ochrona * 6.0 - d_ja * 0.6 - absf(d_g - (13.0 if ranny else 9.0)) * 0.3
		if flanka:
			var a := (global_position - pg).normalized()
			var b := (p - pg).normalized()
			s += (1.0 - a.dot(b)) * 4.0
		if cecha == "agresywny":
			s -= d_g * 0.2
		elif cecha == "ostrozny" or ranny:
			s += d_g * 0.15
		if s > best:
			best = s
			najlepsza = o
	if najlepsza.is_empty():
		# brak osłony: krótki krok w bok, przykucnięty
		var bok := global_basis.x * (1.0 if randf() < 0.5 else -1.0) * randf_range(1.0, 2.0)
		_idz(_najblizszy_na_siatce(global_position + bok))
		biegnie = false
		return
	_oslona = najlepsza
	menedzer.zajmij_oslone(najlepsza, self)
	var dyst := global_position.distance_to(najlepsza["pos"])
	# biegnie tylko przez otwartą przestrzeń pod ostrzałem; krótkie skoki marszem z bronią przy oku
	biegnie = dyst > 4.5 and (_przygwozdzenie > 0.3 or flanka or ranny)
	_idz(najlepsza["pos"])
	if flanka and oddzial and randf() < 0.5:
		_napis(["Obchodzę go!", "Flankuję!", "Idę lewą!"].pick_random())
	elif biegnie and randf() < 0.4:
		_napis(["Zmieniam pozycję!", "Osłaniaj!", "Przechodzę!"].pick_random())


func _strzelaj(delta: float) -> void:
	_strzal_t -= delta
	if _strzal_t > 0.0:
		return
	if _w_magazynku <= 0:
		if zapas_mag > 0 or bron.defn()["bron"].has("wewnetrzny"):
			zapas_mag = maxi(0, zapas_mag - 1)
			_przeladowanie = float(bron.defn()["bron"]["przeladowanie"]) * 1.1
			_przeladowanie_max = _przeladowanie
			_napis(["Przeładowuję!", "Osłaniaj!", "Pusty!"].pick_random())
			Dzwiek.graj_3d("przeladowanie", global_position, get_parent(), -4.0)
		else:
			# bez amunicji – ucieczka
			morale = 0.0
		return
	var bd: Dictionary = bron.defn()["bron"]
	var auto: bool = bd["tryby"][0] == "auto"
	_strzal_t = 60.0 / float(bd["rpm"])
	if auto:
		_seria += 1
		if _seria >= randi_range(3, 6):
			_seria = 0
			_strzal_t = randf_range(0.5, 1.1)
	else:
		_strzal_t += randf_range(0.25, 0.7)
	_w_magazynku -= 1
	var ad: Dictionary = Dane.def(amunicja_id)["amunicja"]
	var oko := _oko() + Vector3.UP * -0.1
	var cel := _punkt_celu(gracz, false)
	var d := oko.distance_to(cel)
	var celnosc := float(dane_frakcji.get("celnosc", 0.6))
	var kat := (4.5 * (1.5 - celnosc)) * (1.0 + d / 25.0) * (1.0 + _halas_celu(gracz) * 0.8)
	kat *= cialo.mnoznik_celnosci()
	# pierwsze strzały są nerwowe i niecelne, potem przeciwnik się "wstrzeliwuje"
	kat *= lerpf(2.2, 1.0, clampf(_czas_walki / 3.5, 0.0, 1.0)) * (1.0 + _przygwozdzenie)
	if _kuc(gracz) > 0.5:
		kat *= 1.15
	var srut := int(ad.get("srut", 1))
	var space := get_world_3d().direct_space_state
	var kier0 := (cel - oko).normalized()
	for i in srut:
		var kier := Balistyka.rozrzut(kier0, kat + (float(bd.get("rozrzut_srutu", 0.0)) if srut > 1 else 0.0))
		var q := PhysicsRayQueryParameters3D.create(oko, oko + kier * 120.0, MASKA_STRZALU)
		q.collide_with_areas = true
		q.exclude = _moje_hitboxy
		var r := space.intersect_ray(q)
		if r.is_empty():
			continue
		var col: Object = r["collider"]
		if col.has_meta("gracz"):
			var g: Gracz = col.get_meta("gracz")
			g.set_meta("zabojca", "%s (%s)" % [nazwa_jednostki, Dane.nazwa(bron.id)])
			g.trafiony(r["position"], float(ad["obrazenia"]) * float(bd.get("mnoznik", 1.0)), float(ad["penetracja"]), self, srut > 1)
		elif col.has_meta("czesc"):
			# trafiony ktoś inny: wróg innej frakcji, mutant albo (pechowo) swój
			var wl = col.get_meta("wlasciciel")
			if is_instance_valid(wl) and wl.has_method("trafiony"):
				wl.trafiony(String(col.get_meta("czesc")), float(ad["obrazenia"]) * float(bd.get("mnoznik", 1.0)), float(ad["penetracja"]), self, r["position"], kier)
		else:
			Efekty.slad(get_parent(), r["position"], r["normal"])
			Efekty.czastki(get_parent(), r["position"], r["normal"], Color(0.5, 0.48, 0.44), 5)
			# świst kuli blisko gracza
			var gr := get_tree().get_first_node_in_group("gracz") as Node3D
			if gr and r["position"].distance_to(gr.global_position) < 2.5:
				Dzwiek.graj("swist", -6.0)
	var wylot: Vector3 = (_czesci["bron"] as Node3D).global_transform * Vector3(_czesci["wylot"])
	Efekty.blysk(get_parent(), wylot, 2.5)
	var bxf: Transform3D = (_czesci["bron"] as Node3D).global_transform
	Efekty.plomien_wylotu(get_parent(), Transform3D(bxf.basis.orthonormalized(), wylot), 1.8)
	_odrzut_anim = 1.0
	# strzał słychać: inne frakcje i mutanty schodzą się na odgłos walki (także bez udziału gracza)
	Gra.emituj_halas(global_position, 34.0, self)
	if randf() < 0.45:
		Efekty.smuga(get_parent(), wylot, wylot + kier0 * minf(d, 60.0))
	var dzw := {"9x18": "strzal_pistolet", "7.62x39": "strzal_karabin", "12/70": "strzal_strzelba"}
	Dzwiek.graj_3d(dzw.get(bd["kaliber"], "strzal_pistolet"), wylot, get_parent(), 2.0, 0.97, 70.0)


# ------------------------------------------------------------------ ruch i animacja

func _idz(p: Vector3) -> void:
	if p.distance_to(cel_ruchu) < 0.3 and not _agent.is_navigation_finished():
		return
	cel_ruchu = p
	_agent.target_position = p


func _najblizszy_na_siatce(p: Vector3) -> Vector3:
	var mapa := get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(mapa, p)


func _obroc_do(p: Vector3, delta: float, szybkosc: float) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() < 0.1:
		return
	var cel_rot := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, cel_rot, minf(1.0, delta * szybkosc))


func _ruch(delta: float) -> void:
	var v := Vector3.ZERO
	var predkosc := (3.7 if biegnie else 1.55) * cialo.mnoznik_ruchu() * lerpf(1.0, 0.5, kucanie)
	if not _agent.is_navigation_finished() and cel_ruchu != Vector3.ZERO:
		var nast := _agent.get_next_path_position()
		var d := nast - global_position
		d.y = 0
		if d.length() > 0.05:
			v = d.normalized() * predkosc
			if stan != "walka" or not widzi:
				_obroc_do(global_position + d, delta, 3.2)
	elif _w_oslonie == false and stan == "walka" and not _oslona.is_empty():
		if global_position.distance_to(_oslona["pos"]) < 0.9:
			_w_oslonie = true
			_wychyl_t = 0.5
	if not _oslona.is_empty() and global_position.distance_to(_oslona["pos"]) < 0.9:
		_w_oslonie = true
	# ciężki ruch: powolne rozpędzanie i hamowanie z wyposażeniem na plecach
	var przysp := 9.0 if v.length() > Vector2(velocity.x, velocity.z).length() else 14.0
	velocity.x = move_toward(velocity.x, v.x, delta * przysp)
	velocity.z = move_toward(velocity.z, v.z, delta * przysp)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = -0.3
	move_and_slide()
	kucanie = move_toward(kucanie, _kucanie_cel, delta * 3.5)
	var pozioma := Vector2(velocity.x, velocity.z).length()
	if pozioma > 0.5:
		_krok_t += pozioma * delta
		if _krok_t > (0.85 if biegnie else 0.65):
			_krok_t = 0.0
			Dzwiek.graj_3d("krok_wrog", global_position, get_parent(), -2.0 if biegnie else -8.0, 0.9, 25.0)


func _animuj(delta: float) -> void:
	var pozioma := Vector2(velocity.x, velocity.z).length()
	_anim_t += delta * (pozioma * 2.7 + 0.0)
	_oddech += delta
	var amp := clampf(pozioma / 3.7, 0.0, 1.0)
	var p := _anim_t
	var biodra: Node3D = _czesci["biodra"]
	var tulow: Node3D = _czesci["tulow"]
	# biodra: przysiad przy kroku, przenoszenie ciężaru, kucanie
	biodra.position.y = lerpf(0.95, 0.58, kucanie) - absf(sin(p)) * amp * 0.05
	biodra.rotation.z = sin(p) * amp * 0.06
	biodra.rotation.y = sin(p) * amp * 0.1
	# nogi: udo w przód/tył, kolano zgina się przy przenoszeniu nogi
	for i in 2:
		var s := "_l" if i == 0 else "_p"
		var faza := p + (PI if i == 1 else 0.0)
		var udo := sin(faza) * amp * 0.75 + kucanie * (1.25 if i == 0 else 0.55)
		var zgiecie := maxf(0.0, -cos(faza)) * amp * 1.2 + amp * 0.1 + kucanie * (2.1 if i == 0 else 1.75)
		(_czesci["noga" + s] as Node3D).rotation.x = udo
		(_czesci["kolano" + s] as Node3D).rotation.x = -zgiecie
	if kucanie > 0.0 and amp < 0.1:
		# przyklęk na jedno kolano
		(_czesci["noga_p"] as Node3D).rotation.x = lerpf(0.0, -0.35, kucanie)
		(_czesci["kolano_p"] as Node3D).rotation.x = lerpf(0.0, -1.9, kucanie)
	# tułów: oddech, pochylenie w ruchu, drgnięcie po trafieniu, celowanie w pionie
	_drgniecie = move_toward(_drgniecie, 0.0, delta * 3.5)
	_odrzut_anim = move_toward(_odrzut_anim, 0.0, delta * 9.0)
	var lk := global_basis.inverse() * _ost_kier
	var celuje := stan in ["walka", "posterunek"] or (stan == "szukanie" and frakcja != "szabrownik") or (stan == "czujny" and not _nasluch)
	var pion := 0.0
	if celuje and ostatnia_pozycja != Vector3.ZERO:
		var oko := _oko()
		var cel := ostatnia_pozycja + Vector3.UP * 1.1
		var poz := Vector2(cel.x - oko.x, cel.z - oko.z).length()
		pion = clampf(atan2(cel.y - oko.y, maxf(poz, 0.5)), -0.6, 0.5)
	tulow.rotation.x = -0.06 - kucanie * 0.15 - amp * 0.1 + _drgniecie * 0.45 * signf(lk.z) + pion * 0.7 + sin(_oddech * 1.6) * 0.012
	tulow.rotation.z = -_drgniecie * 0.3 * signf(lk.x)
	tulow.rotation.y = -biodra.rotation.y * 0.8 + (0.12 if celuje else 0.0)
	# głowa: rozgląda się na patrolu, w walce patrzy w cel
	var glowa: Node3D = _czesci["glowa"]
	if stan == "patrol":
		_rozgl += delta * 0.6
		glowa.rotation.y = sin(_rozgl) * 0.45 * (1.0 - amp * 0.5)
		glowa.rotation.x = 0.08
	else:
		glowa.rotation.y = lerpf(glowa.rotation.y, -0.12 if celuje else 0.0, delta * 5.0)
		glowa.rotation.x = pion * 0.3
	# broń: złożona do strzału albo w pozycji niskiej gotowości
	var b: Node3D = _czesci["bron"]
	var pistolet: bool = bron.defn()["bron"]["slot"] == "pistolet"
	var b_poz := Vector3(0.09, 0.44, -0.33) if celuje else Vector3(0.11, 0.24, -0.27)
	var b_rot := Vector3(0.0, 0.03, 0.0) if celuje else Vector3(-0.75, 0.35, 0.15)
	if pistolet:
		b_poz = Vector3(0.02, 0.44, -0.45) if celuje else Vector3(0.12, 0.2, -0.2)
		b_rot = Vector3(0, 0, 0) if celuje else Vector3(-1.0, 0.2, 0)
	var przel := 0.0
	if _przeladowanie > 0.0:
		przel = 1.0 - _przeladowanie / maxf(0.1, _przeladowanie_max)
		b_poz = Vector3(0.06, 0.32, -0.28)
		b_rot = Vector3(0.35, 0.3, 0.7)
	b_poz += Vector3(0, 0.01, 0.06) * _odrzut_anim
	b_rot += Vector3(0.18, 0, 0) * _odrzut_anim
	b_poz.y += sin(p) * amp * 0.012 + sin(_oddech * 1.6) * 0.004
	b.position = b.position.lerp(b_poz, minf(1.0, delta * 10.0))
	b.rotation = b.rotation.lerp(b_rot, minf(1.0, delta * 10.0))
	# magazynek w czasie przeładowania: wypada, wraca w dłoni
	var reka_l_cel: Vector3 = b.transform * (Vector3(_md["przod"]) + Vector3(0, -0.02, 0))
	if pistolet:
		reka_l_cel = b.transform * Vector3(-0.03, -0.05, 0.03)
	if _mag_node:
		_mag_node.position = Vector3.ZERO
		_mag_node.visible = true
	if przel > 0.0 and not _md["mag"].is_empty():
		var mag_poz := b.transform * Vector3(0, -0.08, -0.05)
		var pas := Vector3(-0.16, 0.08, -0.12)
		if przel < 0.3:
			reka_l_cel = mag_poz
			_mag_node.position = Vector3(0, -0.3 * przel / 0.3, 0)
			_mag_node.visible = przel < 0.25
		elif przel < 0.6:
			reka_l_cel = mag_poz.lerp(pas, sin((przel - 0.3) / 0.3 * PI))
			_mag_node.visible = false
		elif przel < 0.85:
			reka_l_cel = pas.lerp(mag_poz, (przel - 0.6) / 0.25)
			_mag_node.visible = true
			_mag_node.position = (b.transform.affine_inverse() * reka_l_cel) - Vector3(0, -0.08, -0.05)
		else:
			reka_l_cel = mag_poz.lerp(b.transform * Vector3(_md["przod"]), (przel - 0.85) / 0.15)
	_ik(_czesci["ramie_p"], _czesci["lokiec_p"], b.transform * Vector3(0, -0.04, 0.03), Vector3(1.0, -1.0, 0.4))
	_ik(_czesci["ramie_l"], _czesci["lokiec_l"], reka_l_cel, Vector3(-1.0, -1.0, 0.2))
	# latarka na broni
	if _latarka:
		_latarka.visible = stan in ["walka", "szukanie", "czujny"]


## Kinematyka odwrotna ręki (dwa odcinki): ramię celuje tak, by dłoń trafiła w punkt cel (przestrzeń tułowia).
## biegun: kierunek, w którą stronę wypycha się łokieć.
func _ik(ramie: Node3D, lokiec: Node3D, cel: Vector3, biegun: Vector3) -> void:
	var s := ramie.position
	var v := cel - s
	var d := clampf(v.length(), 0.08, RAMIE * 2.0 - 0.003)
	var dir := v.normalized()
	var cos_a := clampf(d / (2.0 * RAMIE), -1.0, 1.0)
	var alfa := acos(cos_a)
	var pole := biegun.normalized() - dir * biegun.normalized().dot(dir)
	if pole.length() < 0.01:
		pole = Vector3(0, -1, 0)
	pole = pole.normalized()
	var u := (dir * cos(alfa) + pole * sin(alfa)).normalized()
	var e := s + u * RAMIE
	var f := (s + dir * d - e).normalized()
	var bu := _baza_wzdluz(-u, pole)
	ramie.basis = bu
	lokiec.basis = bu.inverse() * _baza_wzdluz(-f, pole)


## Baza, której oś Y jest równa y (czyli -Y kości wskazuje kierunek kończyny).
func _baza_wzdluz(y: Vector3, pomoc: Vector3) -> Basis:
	var x := y.cross(pomoc)
	if x.length() < 0.01:
		x = y.cross(Vector3.FORWARD)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


func _napis(t: String) -> void:
	if _napis_t > 0.0:
		return
	_napis_t = 4.0
	get_tree().call_group("hud", "napis_wroga", nazwa_jednostki, t, global_position)


# ------------------------------------------------------------------ śmierć

func _smierc(_przyczyna: String) -> void:
	stan = "martwy"
	collision_layer = 0
	collision_mask = Balistyka.WARSTWA_SWIAT
	for a in find_children("*", "Area3D", true, false):
		a.queue_free()
	if oddzial:
		oddzial.strata(self)
	if not _oslona.is_empty() and menedzer:
		menedzer.zwolnij_oslone(self)
	# upada w kierunku lotu pocisku: postrzelony z przodu – na plecy
	var lk := global_basis.inverse() * _ost_kier
	if _latarka:
		_latarka.visible = false
	# nogi się uginają, ręce opadają
	var tk := create_tween().set_parallel(true)
	for s2 in ["_l", "_p"]:
		tk.tween_property(_czesci["kolano" + s2], "rotation:x", -1.4 + randf_range(-0.3, 0.3), 0.3)
		tk.tween_property(_czesci["noga" + s2], "rotation:x", 0.7 + randf_range(-0.3, 0.3), 0.3)
		tk.tween_property(_czesci["ramie" + s2], "rotation", Vector3(randf_range(-0.6, 0.6), 0, randf_range(-1.2, 1.2)), 0.45)
		tk.tween_property(_czesci["lokiec" + s2], "rotation", Vector3(randf_range(-0.8, 0.2), 0, 0), 0.45)
	tk.tween_property(_czesci["bron"], "position", Vector3(0.3, 0.1, -0.1), 0.4)
	tk.tween_property(_czesci["glowa"], "rotation:x", randf_range(-0.5, 0.5), 0.5)
	var t := create_tween()
	t.tween_interval(0.12)
	t.tween_property(_model, "rotation:x", deg_to_rad(86.0 * (1.0 if lk.z >= 0.0 else -1.0)), 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(_model, "rotation:z", randf_range(-0.35, 0.35), 0.55)
	t.parallel().tween_property(_model, "position", _model.position + Vector3(lk.x, 0, lk.z).normalized() * 0.35 + Vector3(0, 0.12, 0), 0.55)
	_zwloki.call_deferred()
	zginal.emit(self)
	get_tree().call_group("ui_rajdu", "zabity_wrog", self)


## Z ciała zdjęto przedmiot (przeszukiwanie): znika z modelu.
func zdjeto(p: Przedmiot) -> void:
	if p == pancerz and _czesci.has("pancerz_m"):
		(_czesci["pancerz_m"] as Node3D).visible = false
	if p == helm and _czesci.has("helm_m"):
		(_czesci["helm_m"] as Node3D).visible = false


func _zwloki() -> void:
	var pj := Pojemnik.new()
	pj.nazwa = "Zwłoki: " + nazwa_jednostki
	pj.collision_layer = Balistyka.WARSTWA_INTERAKCJE
	pj.czas_na_przedmiot = 0.5
	pj.niski = true
	pj.wys_wnetrza = 0.25
	# przeszukiwanie ciała po kolei: kieszenie kurtki, spodni, ładownice, worek/plecak; pancerz i hełm
	# trzeba odpiąć i zdjąć (trwa)
	var kurtka := Siatka.new(2, 2)
	var spodnie := Siatka.new(2, 2)
	var ladownice := Siatka.new(4, 2)
	var plecak := Siatka.new(5, 4)
	var na_ciele := Siatka.new(5, 3)
	pj.siatka = kurtka
	# broń z resztą amunicji w magazynku – wypada z rąk i leży obok
	var bd: Dictionary = bron.defn()["bron"]
	if bd.has("wewnetrzny"):
		bron.dane["wewn"] = clampi(_w_magazynku, 0, int(bd["wewnetrzny"]))
		bron.dane["komora"] = ""
	elif bron.dane["mag"] != null:
		bron.dane["mag"].dane["naboje"] = maxi(0, _w_magazynku - 1)
		bron.dane["komora"] = amunicja_id if _w_magazynku > 0 else ""
	var l := LupNaZiemi.new()
	l.przedmiot = bron
	var bw: Node3D = _czesci.get("bron")
	if bw and is_instance_valid(bw):
		l.rzut_z = bw.global_position
		bw.visible = false
	get_parent().add_child(l)
	l.global_position = global_position + global_basis.x * 0.6 + global_basis.z * 0.2 + Vector3.UP * 0.4
	if not bd.has("wewnetrzny"):
		for i in zapas_mag:
			var m := Gra.magazynek(bd["magazynki"][0], amunicja_id, randi_range(5, _pojemnosc()))
			if not ladownice.dodaj(m):
				plecak.dodaj(m)
	else:
		spodnie.dodaj(Przedmiot.nowy(amunicja_id, randi_range(3, 10)))
	if pancerz:
		na_ciele.dodaj(pancerz)
	if helm:
		na_ciele.dodaj(helm)
	for p in lup:
		if not (kurtka.dodaj(p) or spodnie.dodaj(p) or plecak.dodaj(p)):
			var lp := LupNaZiemi.new()
			lp.przedmiot = p
			get_parent().add_child(lp)
			lp.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5))
	pj.czesci = [{"nazwa": "Kieszenie kurtki", "siatka": kurtka, "odkryte": 0, "zdejmowane": false},
		{"nazwa": "Kieszenie spodni", "siatka": spodnie, "odkryte": 0, "zdejmowane": false}]
	if not ladownice.items.is_empty():
		pj.czesci.append({"nazwa": "Ładownice", "siatka": ladownice, "odkryte": 0, "zdejmowane": false})
	if not plecak.items.is_empty():
		pj.czesci.append({"nazwa": "Chlebak", "siatka": plecak, "odkryte": 0, "zdejmowane": false})
	if not na_ciele.items.is_empty():
		pj.czesci.append({"nazwa": "Na ciele", "siatka": na_ciele, "odkryte": 0, "zdejmowane": true})
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.2, 0.5, 2.2)
	cs.shape = bs
	cs.position = Vector3(0, 0.25, 0)
	pj.add_child(cs)
	add_child(pj)
	set_physics_process(false)
