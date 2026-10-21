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
var szansa_poddania := 0.6   # osaczony i bez szans: poddaje się zamiast uciekać
var _model: Node3D
var _czesci := {}
var _ragdoll: Ragdoll = null
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
var granaty := 0
var _unik_t := 0.0
var _granat_cd := 0.0
var poddany := false          # rzucił broń, ręce w górze – nie strzela do gracza
var rozejm := false           # oddział przekupiony: nie atakuje gracza, dopóki ten nie strzeli
var ostatni_sprawca: Node = null   # kto trafił ostatni (gracz / inna frakcja) – do rozliczeń zabójstw
var boss := false             # Sęp: dowódca dezerterów
var dezerter := false         # obstawa Sępa: najemnicy-dezerterzy (bez wpływu na reputację, bez rozejmu)
var _poddany_t := 0.0
var _oddal_lup := false
var _sprzedal_info := false
var _handel_info := false      # przyjazny (rozejm z reputacji): sprzedał informacje
var _handel_amun := false      # … i amunicję
var _boss_wycofany := false
var _boss_ucieka := false
var _boss_cel := Vector3.ZERO
var _bron_upuszczona := false
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
	granaty = rng.randi_range(0, 2) if frak != "szabrownik" else (1 if rng.randf() < 0.12 else 0)
	morale = float(dane_frakcji["morale"]) * 100.0 + {"agresywny": 15.0, "tchorzliwy": -15.0}.get(cecha, 0.0)
	# reputacja w placówce: oddziały przyjaznej frakcji nie strzelają pierwsze
	if FrakcjeBazy.rep(frak) >= FrakcjeBazy.prog_rozejmu(frak):
		rozejm = true


## Zginął od gracza (kula, granat, wykrwawienie po jego trafieniu)?
func zabity_przez_gracza() -> bool:
	return is_instance_valid(ostatni_sprawca) and ostatni_sprawca is Gracz


## Sęp – boss Blokowiska: dezerter z najemników, w czarnej skórze, KB-47 z kolimatorem na BP, pancerz kl. 4.
## Twardszy (×1,8 zdrowia), szybszy w reakcji, celniejszy, nie ucieka i się nie poddaje. Niesie nieśmiertelnik.
func uczyn_bossem() -> void:
	boss = true
	dezerter = true
	rozejm = false
	nazwa_jednostki = "Sęp"
	dane_frakcji = (dane_frakcji as Dictionary).duplicate(true)
	dane_frakcji["kolory"] = {"ubranie": [0.12, 0.11, 0.11], "spodnie": [0.16, 0.15, 0.14], "glowa": [0.35, 0.08, 0.07]}
	dane_frakcji["celnosc"] = 0.88
	dane_frakcji["reakcja"] = 0.5
	amunicja_id = "a_762bp"
	bron = Gra.nowy_naladowany("kb47", "a_762bp")
	bron.dane["dod_celownik"] = Przedmiot.nowy("kolimator")
	_w_magazynku = _pojemnosc()
	zapas_mag = 4
	pancerz = Przedmiot.nowy("kamizelka_kl4")
	helm = Przedmiot.nowy("helm_wz67")
	lup = [Przedmiot.nowy("niesmiertelnik"), Przedmiot.nowy("lancuszek"), Przedmiot.nowy("a_762bp", 30)]
	cecha = "agresywny"
	morale = 400.0
	granaty = 3
	_opatrunki = 4


## Obstawa Sępa: dezerterzy – nie liczą się do reputacji najemników i nie respektują rozejmu.
func uczyn_dezerterem() -> void:
	dezerter = true
	rozejm = false
	morale += 25.0


## Sęp: po stracie pierwszego człowieka wycofuje się o kilka metrów od gracza i znów trzyma pozycję;
## sam albo poniżej połowy zdrowia – ucieka do najbliższego wyjścia z dala od gracza (jeśli dobiegnie, znika ze strefy).
func _boss_decyzje() -> void:
	if _boss_ucieka:
		return
	var ochrona := 0
	if oddzial:
		for w in oddzial.czlonkowie:
			if is_instance_valid(w) and w != self and not w.cialo.martwy:
				ochrona += 1
	var zagrozenie_gracz: Node3D = gracz if gracz is Gracz else null
	if not _boss_wycofany and ochrona < 2 and zagrozenie_gracz:
		_boss_wycofany = true
		var od := global_position - zagrozenie_gracz.global_position
		od.y = 0.0
		var p := _najblizszy_na_siatce(global_position + od.normalized() * 8.0)
		var kier := zagrozenie_gracz.global_position - p
		kier.y = 0.0
		posterunek = {"pos": p, "kier": kier.normalized() if kier.length() > 0.1 else -global_basis.z}
		_napis_t = 0.0
		_napis(["Cofamy się! Trzymać korytarz!", "Do tyłu, osłaniać mnie!"].pick_random())
	if (ochrona == 0 and stan in ["walka", "szukanie", "czujny"]) or cialo.procent() < 0.5:
		var rajd := get_tree().get_first_node_in_group("ui_rajdu")
		if rajd == null or rajd.get("info") == null:
			return
		var best: Vector3 = Vector3.INF
		var bd := INF
		for w in rajd.info["wyjscia"]:
			var e := w as Node3D
			var d := e.global_position.distance_to(global_position)
			# z dala od gracza: wyjście, do którego gracz ma bliżej niż Sęp, odpada
			if zagrozenie_gracz and e.global_position.distance_to(zagrozenie_gracz.global_position) < d * 0.8:
				continue
			if d < bd:
				bd = d
				best = e.global_position
		if best == Vector3.INF:
			return
		_boss_ucieka = true
		_boss_cel = _najblizszy_na_siatce(best)
		posterunek = {}
		_napis_t = 0.0
		_napis(["Dość tego! Spadam!", "Nie dziś, nie dla was!"].pick_random())
		if rajd.has_method("dodaj_zdarzenie"):
			rajd.dodaj_zdarzenie("Sęp rzucił się do ucieczki.")


func _boss_ewakuacja(delta: float) -> void:
	biegnie = true
	_kucanie_cel = 0.0
	_idz(_boss_cel)
	if widzi and gracz and global_position.distance_to(gracz.global_position) < 12.0:
		_strzelaj(delta)
	if global_position.distance_to(_boss_cel) < 1.6:
		var rajd := get_tree().get_first_node_in_group("ui_rajdu")
		if rajd and rajd.has_method("dodaj_zdarzenie"):
			rajd.dodaj_zdarzenie("Sęp uciekł ze strefy. Nieśmiertelnik razem z nim.")
		if gracz is Gracz:
			(gracz as Gracz).komunikat.emit("Gdzieś daleko trzasnęły drzwi. Sęp się wymknął.")
		if oddzial:
			oddzial.czlonkowie.erase(self)
		queue_free()


func _pojemnosc() -> int:
	var bd: Dictionary = bron.defn()["bron"]
	if bd.has("wewnetrzny"):
		return int(bd["wewnetrzny"])
	return int(Dane.def(bd["magazynki"][0])["magazynek"]["pojemnosc"])


func _ready() -> void:
	add_to_group("wrogowie")
	cialo = Cialo.new()
	cialo.npc = true
	if rozejm and not dezerter:
		call_deferred("_dodaj_obszar_rozmowy")
	if boss:
		for c in cialo.hp:
			cialo.hp[c] = float(cialo.hp[c]) * 1.8
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
	# warianty: każda postać trochę inna (budowa, odcień ubrania i skóry, nakrycie głowy, dodatki)
	var rr := RandomNumberGenerator.new()
	rr.seed = get_instance_id()
	var odc := func(c: Color, z: float) -> Color: return Color(clampf(c.r * rr.randf_range(1.0 - z, 1.0 + z), 0, 1), clampf(c.g * rr.randf_range(1.0 - z, 1.0 + z), 0, 1), clampf(c.b * rr.randf_range(1.0 - z, 1.0 + z), 0, 1))
	var ubr: Color = odc.call(_kolor(kol.get("ubranie", [0.3, 0.3, 0.3])), 0.12)
	var spod: Color = odc.call(_kolor(kol.get("spodnie", [0.2, 0.2, 0.2])), 0.1)
	var gl: Color = odc.call(_kolor(kol.get("glowa", [0.2, 0.2, 0.2])), 0.12)
	var skora := Color(0.6, 0.46, 0.38) * rr.randf_range(0.93, 1.06)
	skora.a = 1.0
	var ciemny := Color(0.09, 0.085, 0.08)
	var rek := ciemny if frakcja != "szabrownik" else skora
	var ubr_c := ubr.darkened(0.25)
	_model = Node3D.new()
	add_child(_model)
	var bud := rr.randf_range(0.94, 1.08)
	_model.scale = Vector3(bud, rr.randf_range(0.95, 1.05), bud)
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
	# odzież wierzchnia i dodatki
	if frakcja == "szabrownik":
		match rr.randi() % 3:
			0:   # waciak: pikowane pasy
				for y in [0.12, 0.24, 0.36, 0.48]:
					tul.append([Vector3(0, y, -0.128), Vector3(0.42, 0.012, 0.012), ubr.darkened(0.35)])
			1:   # kurtka dresowa z lampasami
				for x in [-0.205, 0.205]:
					tul.append([Vector3(x, 0.32, 0.0), Vector3(0.014, 0.42, 0.24), Color(0.85, 0.85, 0.82)])
			_:   # płaszcz do pół uda
				_czesci["biodra"].add_child(_bryly([[Vector3(0, -0.07, 0.005), Vector3(0.39, 0.26, 0.255), ubr]]))
	if frakcja != "szabrownik" and rr.randf() < 0.35:
		tul.append([Vector3(0, 0.33, 0.2), Vector3(0.3, 0.38, 0.16), ubr.darkened(0.15)])     # plecak
		tul.append([Vector3(0, 0.5, 0.13), Vector3(0.28, 0.08, 0.06), ubr.darkened(0.3)])
	if frakcja == "wojskowy" and rr.randf() < 0.3:
		tul.append([Vector3(-0.12, 0.43, -0.16), Vector3(0.07, 0.11, 0.05), Color(0.2, 0.22, 0.16)])   # radiostacja
		tul.append([Vector3(-0.14, 0.6, -0.16), Vector3(0.008, 0.26, 0.008), ciemny.lightened(0.1)])
	if rr.randf() < 0.3:
		_czesci["biodra"].add_child(_bryly([[Vector3(0.2 if rr.randf() < 0.5 else -0.2, 0.0, -0.02), Vector3(0.08, 0.13, 0.12), Color(0.32, 0.33, 0.24)]]))  # torba z maską
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
	_nakrycie_glowy(glowa_bryly, gl, skora, rr)
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


## Nakrycie głowy wg frakcji (losowy wariant): kaptur, uszanka, czapka, włosy; furażerka, beret;
## kominiarka, czapka z daszkiem, gogle.
func _nakrycie_glowy(gb: Array, gl: Color, skora: Color, rr: RandomNumberGenerator) -> void:
	var wlosy: Color = [Color(0.12, 0.09, 0.07), Color(0.3, 0.22, 0.14), Color(0.42, 0.4, 0.38)][rr.randi() % 3]
	match frakcja:
		"szabrownik":
			match rr.randi() % 4:
				0:
					gb.append([Vector3(0, 0.2, 0.025), Vector3(0.26, 0.3, 0.24), gl])           # kaptur
					gb.append([Vector3(0, 0.1, -0.112), Vector3(0.19, 0.1, 0.02), Color(0.14, 0.11, 0.1)])  # chusta
				1:
					gb.append([Vector3(0, 0.3, 0.0), Vector3(0.25, 0.1, 0.25), Color(0.36, 0.3, 0.24)])   # uszanka
					for sx in [-1.0, 1.0]:
						gb.append([Vector3(sx * 0.12, 0.2, 0.01), Vector3(0.035, 0.11, 0.15), Color(0.36, 0.3, 0.24)])
				2:
					gb.append([Vector3(0, 0.29, 0.005), Vector3(0.215, 0.09, 0.235), gl])        # czapka z wełny
					gb.append([Vector3(0, 0.35, 0.0), Vector3(0.05, 0.04, 0.05), gl.lightened(0.2)])
				_:
					gb.append([Vector3(0, 0.29, 0.012), Vector3(0.205, 0.05, 0.225), wlosy])     # włosy
					gb.append([Vector3(0, 0.2, 0.1), Vector3(0.2, 0.17, 0.03), wlosy])
		"wojskowy":
			gb.append([Vector3(0, 0.07, 0.0), Vector3(0.215, 0.07, 0.235), gl])                  # kołnierz
			if helm == null:
				match rr.randi() % 3:
					0:
						gb.append([Vector3(0, 0.3, 0.0), Vector3(0.08, 0.05, 0.23), gl.darkened(0.1)])     # furażerka
					1:
						gb.append([Vector3(0.01, 0.295, 0.0), Vector3(0.24, 0.035, 0.24), Color(0.38, 0.12, 0.1), Vector3(0, 0, 8)])  # beret
					_:
						gb.append([Vector3(0, 0.285, 0.012), Vector3(0.205, 0.04, 0.225), wlosy])
		_:
			match rr.randi() % 3:
				0, 1:
					gb.append([Vector3(0, 0.15, 0.0), Vector3(0.215, 0.27, 0.235), gl])         # kominiarka
					gb.append([Vector3(0, 0.19, -0.119), Vector3(0.15, 0.045, 0.01), skora.darkened(0.2)])
					gb.append([Vector3(0, 0.19, -0.125), Vector3(0.14, 0.026, 0.01), Color(0.06, 0.05, 0.05)])
					if helm == null and rr.randf() < 0.5:
						gb.append([Vector3(0, 0.26, -0.11), Vector3(0.2, 0.05, 0.03), Color(0.1, 0.1, 0.1)])   # gogle na czole
				_:
					gb.append([Vector3(0, 0.15, 0.0), Vector3(0.215, 0.27, 0.235), gl])
					if helm == null:
						gb.append([Vector3(0, 0.3, 0.005), Vector3(0.22, 0.07, 0.24), Color(0.15, 0.15, 0.14)])   # czapka z daszkiem
						gb.append([Vector3(0, 0.275, -0.15), Vector3(0.16, 0.012, 0.09), Color(0.13, 0.13, 0.12)])


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
		return not (poddany or rozejm)
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
		if float(_odpuszczone.get(n, 0.0)) > Time.get_ticks_msec() / 1000.0:
			continue          # odpuścił ten posterunek – na razie go omija
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
	if od_kogo:
		ostatni_sprawca = od_kogo
	var wynik := Balistyka.przez_pancerz({"pancerz": pancerz, "helm": helm}, czesc, obr, pen)
	_ost_kier = kier
	_drgniecie = minf(1.0, _drgniecie + 0.45 + wynik["obr"] * 0.012)
	velocity *= 0.25
	cialo.obrazenia(czesc, wynik["obr"], "pocisk")
	if od_kogo is Gracz and rozejm:
		# strzał gracza zrywa rozejm całego oddziału – także gdy trafiony zginął od razu
		if oddzial:
			for w in oddzial.czlonkowie:
				if is_instance_valid(w):
					w.rozejm = false
					w.wykrycie = maxf(float(w.wykrycie), 0.6)
		rozejm = false
	var swiat := get_parent() as Node3D
	if wynik["pancerz"] and not wynik["przebity"]:
		cialo.siniak = maxf(cialo.siniak, 3.0 + obr * 0.06)   # stłuczenie pod płytą: gorzej celuje
		Efekty.czastki(swiat, punkt, -kier, Color(0.9, 0.8, 0.5), 6, 3.0)
		Dzwiek.graj_3d("trafienie_pancerz", punkt, swiat, -2.0)
	else:
		Efekty.czastki(swiat, punkt, -kier, Color(0.45, 0.04, 0.03), 9, 1.8)
		Dzwiek.graj_3d("trafienie_cialo", punkt, swiat, -2.0)
	if cialo.martwy:
		return
	morale -= 8.0 + wynik["obr"] * 0.3
	if od_kogo is Gracz:
		# strzał gracza zrywa rozejm (cały oddział) i poddanie
		poddany = false
		if rozejm and oddzial:
			for w in oddzial.czlonkowie:
				if is_instance_valid(w):
					w.rozejm = false
		rozejm = false
	_przygwozdzenie = minf(2.0, _przygwozdzenie + 0.8)
	# ciężko ranny woła o pomoc: swoi biegną do niego (i każdy w okolicy słyszy, gdzie leży)
	if _wolanie_cd <= 0.0 and (cialo.krwawi() == 2 or cialo.procent() < 0.45) and randf() < 0.7:
		_wolanie_cd = randf_range(9.0, 14.0)
		_napis_t = 0.0
		_napis(["Dostałem! Pomocy!", "Sanitariusz! Tutaj!", "Trafili mnie! Do mnie!", "Krwawię, chłopaki!"].pick_random())
		Gra.emituj_halas(global_position, 16.0, self)
		if oddzial:
			var najb: Node = null
			var nd := INF
			for w in oddzial.czlonkowie:
				if is_instance_valid(w) and w != self and not w.cialo.martwy and w.stan != "walka":
					w.alarm_od_oddzialu(global_position)
					var dw: float = (w as Node3D).global_position.distance_to(global_position)
					if w._pomoc_dla == null and dw < nd:
						nd = dw
						najb = w
			if najb:
				najb._pomoc_dla = self      # najbliższy wolny kolega idzie opatrzyć
				najb._pomoc_t = 0.0
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
	if poddany:
		return
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
	if poddany:
		return
	_wybor_t -= 0.15
	if _wybor_t <= 0.0 or gracz == null or not _zywy(gracz):
		_wybor_t = 0.45
		_wybierz_cel()
	if gracz == null or not _zywy(gracz) or not wrogi(gracz):
		gracz = null
		if stan == "walka":
			stan = "patrol"
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
	_wolanie_cd = maxf(0.0, _wolanie_cd - delta)
	_ciala_t -= delta
	if _ciala_t <= 0.0:
		_ciala_t = 0.8
		_sprawdz_ciala()
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
	if boss:
		_boss_decyzje()
		if _boss_ucieka:
			_boss_ewakuacja(delta)
			_ruch(delta)
			_animuj(delta)
			return
	# wojskowi z posterunku nie opuszczają gniazda: zaalarmowani trzymają wejście
	if not posterunek.is_empty() and stan in ["czujny", "szukanie", "patrol"]:
		_posterunek_alarm(delta)
		_ruch(delta)
		_animuj(delta)
		return
	_granat_cd = maxf(0.0, _granat_cd - delta)
	if _unik_t > 0.0 and stan != "poddany":
		# ucieczka przed granatem: biegiem, bez strzelania
		_unik_t -= delta
		biegnie = true
		_kucanie_cel = 0.0
		_ruch(delta)
		_animuj(delta)
		return
	match stan:
		"poddany":
			_poddany(delta)
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
		"szaber":
			_szaber(delta)
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
		# kurz w powietrzu (seria w ciasnym pokoju) zasłania sylwetkę
		tempo *= 1.0 - 0.65 * Efekty.zaslona_kurzu(_oko(), gracz.global_position + Vector3.UP * 1.2)
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
	if poddany:
		return
	_nasluch = false
	if stan != "walka":
		_czas_walki = 0.0
	stan = "walka"
	_reakcja = float(dane_frakcji.get("reakcja", 0.6)) * randf_range(0.8, 1.4)
	_decyzja_t = 0.0
	czas_bez_kontaktu = 0.0


## Wołane przez oddział, gdy ktoś inny wykrył gracza (łączność radiowa).
func alarm_od_oddzialu(pos: Vector3) -> void:
	if stan == "ucieczka" or stan == "poddany" or cialo.martwy:
		return
	ostatnia_pozycja = pos
	_nasluch = false
	if stan != "walka":
		stan = "szukanie"
		czas_bez_kontaktu = 0.0
		_decyzja_t = 0.0


var _szaber_cel: Node3D = null
var _szaber_t := 0.0
var _szaber_skan := 0.0
var _szaber_ost: Node3D = null
var _szaber_droga := 0.0         # ile już idzie do celu szabru (limit – cel może być nieosiągalny)
var _nieosiagalne := {}          # id celów szabru, do których nie dało się dojść


func _patrol(delta: float) -> void:
	_kucanie_cel = 0.0
	biegnie = false
	# szabrownicy (i czasem najemnicy) wypatrują leżących rzeczy, ciał i porzuconych plecaków
	_szaber_skan -= delta
	if _szaber_skan <= 0.0:
		_szaber_skan = randf_range(2.5, 4.0)
		var chetny := frakcja == "szabrownik" or (frakcja == "najemnik" and cecha != "ostrozny")
		if chetny:
			var cel := _szukaj_lupu()
			if cel:
				_szaber_cel = cel
				_szaber_cel.set_meta("szabrowany", self)
				_szaber_t = randf_range(3.0, 5.0)
				stan = "szaber"
				_napis(["O, coś leży.", "Zobaczmy, co tu mamy.", "Moje!"].pick_random())
				return
	_patrol_t -= delta
	if _patrol_t <= 0.0 or (_agent.is_navigation_finished() and cel_ruchu != Vector3.ZERO):
		_patrol_t = randf_range(4.0, 9.0)
		var r := randf_range(2.0, 7.0)
		var p := global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * r
		_idz(_najblizszy_na_siatce(p))


## Zauważona pułapka (szklanka na klamce, drut przy ziemi): ostrzega swoich i ją rozbraja – granat zabiera.
func rozbroj_pulapke(p: Node3D) -> void:
	if cialo.martwy or stan == "szaber":
		return
	_szaber_cel = p
	_szaber_t = randf_range(4.0, 5.5)
	stan = "szaber"
	_napis(["Stój! Granat na klamce!", "Uwaga, drut!", "Pułapka. Nikt nie rusza."].pick_random() if p is Pulapka else ["Uwaga, drut!", "Stać – potykacz.", "Drut przy ziemi!"].pick_random())
	if oddzial:
		for w in oddzial.czlonkowie:
			if is_instance_valid(w) and w != self:
				w.wykrycie = maxf(float(w.wykrycie), 0.3)


## Czy droga prowadzi przez te drzwi (otwiera tylko te, przez które naprawdę idzie – nie każde, przy których stoi).
func chce_przez(d: Node3D) -> bool:
	if _agent == null or _agent.is_navigation_finished() or cel_ruchu == Vector3.ZERO:
		return false
	var z := d.global_basis.z
	var moja := signf((global_position - d.global_position).dot(z))
	var nast := _agent.get_next_path_position()
	if signf((nast - d.global_position).dot(z)) != moja and absf((nast - d.global_position).dot(z)) > 0.05:
		return true
	return signf((cel_ruchu - d.global_position).dot(z)) != moja and cel_ruchu.distance_to(d.global_position) < 25.0 \
		and nast.distance_to(d.global_position) < 1.6


func _szukaj_lupu(zasieg := 9.0) -> Node3D:
	var best: Node3D = null
	var bd := zasieg
	for n in get_tree().get_nodes_in_group("lup_swiat"):
		var w := n as Node3D
		if w == null or not is_instance_valid(w) or w == self or w.is_ancestor_of(self) or self.is_ancestor_of(w):
			continue
		var kto = w.get_meta("szabrowany") if w.has_meta("szabrowany") else null
		if kto != null and is_instance_valid(kto) and kto != self and not kto.cialo.martwy and kto.stan == "szaber":
			continue
		if w is Pojemnik and ((w as Pojemnik).pusty() or not String((w as Pojemnik).nazwa).begins_with("Zwłoki")):
			continue
		if w is LupNaZiemi and (w as LupNaZiemi)._podnoszony:
			continue
		if _nieosiagalne.has(w.get_instance_id()):
			continue
		var d := global_position.distance_to(w.global_position)
		if d < bd and absf(w.global_position.y - global_position.y) < 1.5:
			bd = d
			best = w
	return best


## Szaber: podejście, przyklęk, grzebanie; zabiera leżące rzeczy albo najcenniejsze z ciała (trafią do jego łupu).
func _szaber(delta: float) -> void:
	biegnie = false
	if _szaber_cel == null or not is_instance_valid(_szaber_cel):
		stan = "patrol"
		return
	if _szaber_cel != _szaber_ost:
		_szaber_ost = _szaber_cel
		_szaber_droga = 0.0
	var cel: Vector3 = _szaber_cel.global_position if not _szaber_cel.has_method("punkt_rozbrajania") else _szaber_cel.punkt_rozbrajania()
	# zasięg ręki liczony w poziomie (ciało leży na wersalce, granat wisi na klamce – środek bywa wyżej niż biodra)
	var poziom := Vector2(cel.x - global_position.x, cel.z - global_position.z).length()
	if poziom > 1.15 or absf(cel.y - global_position.y) > 1.4:
		_kucanie_cel = 0.0
		_szaber_droga += delta
		if _szaber_droga > 14.0:
			# nie da się podejść (ciało za meblem, na innym piętrze): odpuszcza i więcej tu nie wraca
			_nieosiagalne[_szaber_cel.get_instance_id()] = true
			if _szaber_cel.has_meta("szabrowany"):
				_szaber_cel.remove_meta("szabrowany")
			_szaber_cel = null
			_szaber_droga = 0.0
			stan = "patrol"
			return
		_idz(_najblizszy_na_siatce(cel))
		return
	_szaber_droga = 0.0
	_idz(global_position)
	_kucanie_cel = 1.0
	_obroc_do(cel, delta, 3.0)
	var przed := _szaber_t
	_szaber_t -= delta
	if int(przed * 1.4) != int(_szaber_t * 1.4):
		Dzwiek.graj_3d("szukanie", global_position + Vector3.UP * 0.4, get_parent(), -8.0, randf_range(0.9, 1.1), 14.0)
	if _szaber_t > 0.0:
		return
	if _szaber_cel is Pulapka or _szaber_cel is Potykacz:
		var gdzie: Vector3 = _szaber_cel.punkt_rozbrajania()
		_szaber_cel.rozbrojony_przez(self)
		_napis(["Zawleczka z powrotem. Ktoś tu na nas czekał.", "Granat jest mój.", "Mało brakowało."].pick_random())
		_szaber_cel = null
		_kucanie_cel = 0.0
		# ktoś zastawił pułapkę niedawno – jest gdzieś w okolicy: oddział przeczesuje teren
		ostatnia_pozycja = _najblizszy_na_siatce(gdzie + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
		stan = "szukanie"
		_trzymaj_t = 1.5
		czas_bez_kontaktu = 0.0
		if oddzial:
			oddzial.alarm(ostatnia_pozycja, self)
		return
	if _szaber_cel is LupNaZiemi:
		lup.append((_szaber_cel as LupNaZiemi).przedmiot)
		_szaber_cel.queue_free()
	elif _szaber_cel is Pojemnik:
		var wz := []
		for c in (_szaber_cel as Pojemnik).lista_czesci():
			for e in (c["siatka"] as Siatka).items:
				wz.append([e["p"], c["siatka"]])
		wz.sort_custom(func(a, b): return (a[0] as Przedmiot).wartosc() > (b[0] as Przedmiot).wartosc())
		for i in mini(2, wz.size()):
			(wz[i][1] as Siatka).usun(wz[i][0])
			lup.append(wz[i][0])
	if wykrycie > 0.25 and gracz:
		# zauważył kogoś przy łupie: zwiewa z tym, co zgarnął
		_napis(["Spadam z tym!", "Moje, nie oddam!", "Zmywam się!"].pick_random())
		stan = "ucieczka"
		czas_bez_kontaktu = 6.0
		_decyzja_t = 0.0
		_szaber_cel = null
		return
	_napis(["Się przyda.", "Nie twoje, nie moje – teraz moje.", "Dobre."].pick_random())
	if is_instance_valid(_szaber_cel) and _szaber_cel.has_meta("szabrowany"):
		_szaber_cel.remove_meta("szabrowany")
	_szaber_cel = null
	_kucanie_cel = 0.0
	stan = "patrol"


## Po strzelaninie, gdy ucichło: szabrownik idzie obszukać świeże ciała w okolicy (do 14 m).
func _szaber_po_walce(delta: float) -> bool:
	if frakcja != "szabrownik" or widzi or czas_bez_kontaktu < 10.0:
		return false
	_szaber_skan -= delta
	if _szaber_skan > 0.0:
		return false
	_szaber_skan = randf_range(2.0, 3.5)
	var cel := _szukaj_lupu(14.0)
	if cel == null or not (cel is Pojemnik):
		return false
	_szaber_cel = cel
	_szaber_cel.set_meta("szabrowany", self)
	_szaber_t = randf_range(3.0, 5.0)
	stan = "szaber"
	_napis(["Ucichło. Zobaczmy, co mieli.", "Trupom już się nie przyda.", "Szybko, zanim ktoś przyjdzie."].pick_random())
	return true


## Ciało swojego w zasięgu wzroku: alarm oddziału i poszukiwania w stronę, z której padł strzał.
func _sprawdz_ciala() -> void:
	if stan not in ["patrol", "czujny", "szukanie"] or poddany:
		return
	var oko := _oko()
	var space := get_world_3d().direct_space_state
	for w in get_tree().get_nodes_in_group("wrogowie"):
		if not (w is Wrog) or w == self or _widziane_ciala.has(w) or str(w.stan) != "martwy" or w.frakcja != frakcja:
			continue
		var cp: Vector3 = (w as Node3D).global_position + Vector3.UP * 0.3
		if w._ragdoll and is_instance_valid(w._ragdoll):
			cp = w._ragdoll.srodek()
		var d := oko.distance_to(cp)
		if d > 14.0:
			continue
		var do_ciala := (cp - oko).normalized()
		if do_ciala.dot(-global_basis.z) < 0.2:
			continue
		var q := PhysicsRayQueryParameters3D.create(oko, cp, Balistyka.WARSTWA_SWIAT)
		if not space.intersect_ray(q).is_empty():
			continue
		# ciało w ciemnym kącie widać tylko z bliska (albo w świetle latarki na broni)
		if menedzer and menedzer.rajd and menedzer.rajd.has_method("oswietlenie"):
			var sw: float = menedzer.rajd.oswietlenie(cp)
			if _latarka and _latarka.visible:
				sw = maxf(sw, 0.8)
			if d > lerpf(2.5, 14.0, clampf((sw - 0.1) / 0.5, 0.0, 1.0)):
				continue
		_widziane_ciala[w] = true
		var kier: Vector3 = w._ost_kier
		kier.y = 0.0
		var skad := cp - (kier.normalized() * randf_range(6.0, 11.0) if kier.length() > 0.01 else Vector3.ZERO)
		ostatnia_pozycja = _najblizszy_na_siatce(skad)
		_napis(["Mają naszego!", "Leży... ktoś go sprzątnął.", "Trup! Kryć się!", "Nie żyje! Uważajcie!"].pick_random())
		stan = "szukanie"
		_nasluch = false
		czas_bez_kontaktu = 0.0
		_trzymaj_t = randf_range(1.5, 3.0)
		if oddzial:
			oddzial.alarm(ostatnia_pozycja, self)
		return


var _widziane_ciala := {}
var _ciala_t := 0.0
var _wolanie_cd := 0.0


func _czujny(delta: float) -> void:
	biegnie = false
	if _szaber_po_walce(delta):
		return
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


var _odpuszczone := {}          # posterunek -> czas (s), do którego go nie atakuje (impas)
var _pomoc_dla: Node = null      # ranny kolega, którego idzie opatrzyć
var _pomoc_t := 0.0


## Kolega przy rannym: przyklęka i opatruje go (kilka sekund bez strzelania – okazja dla przeciwnika).
func _pomagaj(delta: float) -> bool:
	if _pomoc_dla == null:
		return false
	var r = _pomoc_dla
	if not is_instance_valid(r) or r.cialo.martwy or r.cialo.krwawi() == 0 or (widzi and wykrycie > 0.6):
		_pomoc_dla = null
		_pomoc_t = 0.0
		_kucanie_cel = 0.0
		return false
	var rp: Vector3 = (r as Node3D).global_position
	if Vector2(rp.x - global_position.x, rp.z - global_position.z).length() > 1.2:
		_idz(_najblizszy_na_siatce(rp))
		biegnie = true
		_pomoc_t += delta * 0.2
		if _pomoc_t > 6.0:
			_pomoc_dla = null    # nie dojdzie
		return true
	_idz(global_position)
	biegnie = false
	_kucanie_cel = 1.0
	_obroc_do(rp, delta, 3.0)
	if _pomoc_t < 1.0:
		_pomoc_t = 1.0
		_napis(["Trzymaj się, opatrzę!", "Leż, nie ruszaj się!", "Bandaż! Uciskaj tu!"].pick_random())
	_pomoc_t += delta
	if _pomoc_t > 6.5:
		for c in r.cialo.krwawienie:
			r.cialo.krwawienie[c] = maxi(0, int(r.cialo.krwawienie[c]) - 1)
		Dzwiek.graj_3d("plecak", rp + Vector3.UP * 0.4, get_parent(), -12.0, 1.3, 10.0)
		_pomoc_dla = null
		_pomoc_t = 0.0
		_kucanie_cel = 0.0
	return true


func _szukanie(delta: float) -> void:
	biegnie = false
	czas_bez_kontaktu += delta
	if _pomagaj(delta):
		return
	if _szaber_po_walce(delta):
		return
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


# ------------------------------------------------------------------ granaty

## Rzut granatem łukiem w ostatnią znaną pozycję (z krzykiem – gracz ma chwilę na reakcję).
func _rzuc_granat(cel: Vector3) -> void:
	granaty -= 1
	_granat_cd = 12.0
	_napis_t = 0.0
	_napis(["Granat!", "Granat, kryć się!", "Łap prezent!"].pick_random())
	Dzwiek.graj_3d("zawleczka", global_position + Vector3.UP * 1.3, get_parent(), -4.0, 1.0, 12.0)
	var skad := global_position + Vector3.UP * 1.7 - global_basis.z * 0.3
	var cel2 := cel + Vector3(randf_range(-1.5, 1.5), 0.05, randf_range(-1.5, 1.5))
	var d := Vector2(cel2.x - skad.x, cel2.z - skad.z)
	var t := clampf(d.length() / 11.0, 0.5, 1.6)
	var v := Vector3(d.x / t, (cel2.y - skad.y + 4.9 * t * t) / t, d.y / t)
	Granat.rzuc(get_parent(), skad, v, self, Dane.def("granat_f1"))


## Granat obok: uciec poza zasięg odłamków.
func unik_granatu(p: Vector3) -> void:
	if cialo.martwy or poddany or _unik_t > 0.0:
		return
	_unik_t = 2.8
	var od := global_position - p
	od.y = 0.0
	if od.length() < 0.1:
		od = global_basis.z
	_idz(_najblizszy_na_siatce(global_position + od.normalized() * 8.0))
	_napis_t = 0.0
	_napis(["Granat!", "Uwaga, granat!", "Padnij!"].pick_random())


# ------------------------------------------------------------------ poddanie się, okup

func _poddaj_sie() -> void:
	stan = "poddany"
	poddany = true
	_poddany_t = 0.0
	velocity = Vector3.ZERO
	_idz(global_position)
	_kucanie_cel = 0.0
	_napis_t = 0.0
	_napis(["Nie strzelaj! Poddaję się!", "Dobra, dobra! Nie strzelaj!", "Już, już – rzucam broń!"].pick_random())
	_upusc_bron()
	# można do niego podejść i porozmawiać (F)
	var a := Area3D.new()
	a.collision_layer = Balistyka.WARSTWA_INTERAKCJE
	a.collision_mask = 0
	a.monitoring = false
	a.set_meta("interakcja", self)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.7, 1.8, 0.7)
	cs.shape = bs
	cs.position.y = 0.9
	a.add_child(cs)
	add_child(a)
	_obszar_rozmowy = a


var _obszar_rozmowy: Area3D


func _dodaj_obszar_rozmowy() -> void:
	if _obszar_rozmowy and is_instance_valid(_obszar_rozmowy):
		return
	var a := Area3D.new()
	a.collision_layer = Balistyka.WARSTWA_INTERAKCJE
	a.collision_mask = 0
	a.monitoring = false
	a.set_meta("interakcja", self)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.7, 1.8, 0.7)
	cs.shape = bs
	cs.position.y = 0.9
	a.add_child(cs)
	add_child(a)
	_obszar_rozmowy = a


func _upusc_bron() -> void:
	if _bron_upuszczona:
		return
	_bron_upuszczona = true
	var bd: Dictionary = bron.defn()["bron"]
	if bd.has("wewnetrzny"):
		bron.dane["wewn"] = clampi(_w_magazynku, 0, int(bd["wewnetrzny"]))
	elif bron.dane["mag"] != null:
		bron.dane["mag"].dane["naboje"] = maxi(0, _w_magazynku - 1)
		bron.dane["komora"] = amunicja_id if _w_magazynku > 0 else ""
	bron.dane["stan"] = randf_range(35.0, 80.0)
	var l := LupNaZiemi.new()
	l.przedmiot = bron
	var bw: Node3D = _czesci.get("bron")
	if bw and is_instance_valid(bw):
		l.rzut_z = bw.global_position
		bw.visible = false
	get_parent().add_child(l)
	l.global_position = global_position - global_basis.z * 0.7 + Vector3.UP * 0.4


func _poddany(delta: float) -> void:
	_poddany_t += delta
	biegnie = false
	_kucanie_cel = 0.0
	var g := get_tree().get_first_node_in_group("gracz") as Node3D
	if g:
		_obroc_do(g.global_position, delta, 3.0)
		# gracz odszedł albo minęła dłuższa chwila – ucieka (już niegroźny)
		if g.global_position.distance_to(global_position) > 16.0 or _poddany_t > 90.0:
			_odejdz()


func _odejdz() -> void:
	stan = "ucieczka"
	morale = 0.0
	czas_bez_kontaktu = 0.0
	if _obszar_rozmowy and is_instance_valid(_obszar_rozmowy):
		_obszar_rozmowy.queue_free()


func _przyjazny_do_rozmowy() -> bool:
	return rozejm and not poddany and not dezerter and not cialo.martwy and stan not in ["walka", "ucieczka", "opatrywanie"]


## Amunicja do broni gracza, którą ta frakcja nosi (albo pusty napis).
func _amunicja_dla(g) -> Array:
	var b: Przedmiot = g.bron.przedmiot if g.bron and g.bron.przedmiot else null
	if b == null:
		return []
	var kal := String(b.defn()["bron"]["kaliber"])
	# każda frakcja ma tylko to, z czego sama strzela
	var ma: Array = {"szabrownik": ["9x18", "12/70"], "najemnik": ["9x18", "7.62x39"], "wojskowy": ["7.62x39", "9x18"]}.get(frakcja, [])
	if kal not in ma:
		return []
	var am := Dane.amunicja_dla(kal)
	if am.is_empty():
		return []
	var id := String(am[0])
	var n := 10 if kal == "12/70" else 20
	var cena := int(float(Dane.def(id).get("cena", 50)) * n * 1.5)
	return [id, n, cena]


func tekst_interakcji(g) -> String:
	if _przyjazny_do_rozmowy() and g is Gracz:
		if not _handel_info:
			return "Pogadaj: informacje (200 bonów)"
		if not _handel_amun:
			var a := _amunicja_dla(g)
			if not a.is_empty():
				return "Odkup amunicję: %s ×%d (%d bonów)" % [Dane.nazwa(a[0]), a[1], a[2]]
		return ""
	if not poddany or cialo.martwy:
		return ""
	if not _oddal_lup:
		return "Każ oddać łup i amunicję"
	if not _sprzedal_info:
		return "Zapłać za informacje i rozejm z jego ludźmi (300 bonów)"
	return "Puść wolno"


func interakcja(g) -> void:
	if _przyjazny_do_rozmowy() and g is Gracz:
		if not _handel_info:
			if Gra.bony < 200:
				g.komunikat.emit("Za mało bonów (200).")
				return
			Gra.bony -= 200
			Gra.zmiana_bonow.emit()
			_handel_info = true
			_napis_t = 0.0
			_napis(["Słuchaj uważnie, nie powtórzę.", "Za darmo to w piwnicy pełzacze.", "Dobra, mów cicho."].pick_random())
			g.komunikat.emit(_informacja(g))
			return
		if not _handel_amun:
			var a := _amunicja_dla(g)
			if a.is_empty():
				return
			if Gra.bony < int(a[2]):
				g.komunikat.emit("Za mało bonów (%d)." % int(a[2]))
				return
			Gra.bony -= int(a[2])
			Gra.zmiana_bonow.emit()
			_handel_amun = true
			var p := Przedmiot.nowy(String(a[0]), int(a[1]))
			if not (g as Gracz).ekw.dodaj(p):
				var l := LupNaZiemi.new()
				l.przedmiot = p
				get_parent().add_child(l)
				l.global_position = global_position - global_basis.z * 0.6 + Vector3.UP * 0.3
			Dzwiek.graj_3d("szelest_0", global_position, get_parent(), -6.0)
			g.komunikat.emit("Odkupiłeś %s ×%d." % [Dane.nazwa(a[0]), int(a[1])])
		return
	if not poddany or cialo.martwy:
		return
	if not _oddal_lup:
		_oddal_lup = true
		var rzeczy: Array = lup.duplicate()
		lup.clear()
		var bd: Dictionary = bron.defn()["bron"]
		if not bd.has("wewnetrzny"):
			for i in zapas_mag:
				rzeczy.append(Gra.magazynek(bd["magazynki"][0], amunicja_id, randi_range(5, _pojemnosc())))
		else:
			rzeczy.append(Przedmiot.nowy(amunicja_id, randi_range(3, 10)))
		zapas_mag = 0
		for p in rzeczy:
			var l := LupNaZiemi.new()
			l.przedmiot = p
			get_parent().add_child(l)
			l.global_position = global_position - global_basis.z * randf_range(0.5, 0.9) + global_basis.x * randf_range(-0.4, 0.4) + Vector3.UP * 0.3
		Dzwiek.graj_3d("upadek_miekki", global_position, get_parent(), -6.0)
		_napis_t = 0.0
		_napis(["Masz, bierz wszystko!", "To wszystko, przysięgam!", "Tylko nie strzelaj..."].pick_random())
		g.komunikat.emit("Oddał %d %s." % [rzeczy.size(), "rzecz" if rzeczy.size() == 1 else "rzeczy"])
		return
	if not _sprzedal_info:
		if Gra.bony < 300:
			g.komunikat.emit("Za mało bonów (300).")
			return
		Gra.bony -= 300
		Gra.zmiana_bonow.emit()
		_sprzedal_info = true
		g.komunikat.emit(_informacja(g))
		# rozejm: jego oddział nie atakuje gracza (dopóki gracz nie zacznie strzelać do nich)
		if oddzial:
			for w in oddzial.czlonkowie:
				if is_instance_valid(w) and w != self:
					w.rozejm = true
					if w.stan == "walka":
						w.stan = "patrol"
		return
	_odejdz()
	g.komunikat.emit("Odchodzi z rękami w górze, potem biegnie.")


## Co mówi poddany po zapłacie: najbliższe wyjście ze strefy i ilu uzbrojonych jest w okolicy.
func _informacja(g) -> String:
	var rajd := get_tree().get_first_node_in_group("ui_rajdu")
	var t := "„"
	if rajd and rajd.get("info"):
		var best = null
		var bd := 1e9
		for w in rajd.info["wyjscia"]:
			var e := w as Node3D
			var d := e.global_position.distance_to(g.global_position)
			var dost: bool = bool(w.get("otwarte")) and String(w.get("wymagany_klucz")) == "" and String(w.get("typ")) != "czasowe"
			if d < bd and dost:
				bd = d
				best = w
		if best:
			var kier: Vector3 = (best as Node3D).global_position - g.global_position
			var strony := ["na północ", "na północny wschód", "na wschód", "na południowy wschód", "na południe", "na południowy zachód", "na zachód", "na północny zachód"]
			var kat := fposmod(atan2(kier.x, -kier.z), TAU)
			t += "%s – %s, jakieś %d metrów. " % [String(best.get("nazwa")) if best.get("nazwa") != null else "Wyjście", strony[int(round(kat / (TAU / 8.0))) % 8], int(bd)]
	var ilu := 0
	for w in get_tree().get_nodes_in_group("wrogowie"):
		if w != self and is_instance_valid(w) and w is Wrog and not w.cialo.martwy and not w.rozejm and w.global_position.distance_to(global_position) < 30.0:
			ilu += 1
	t += ("Moi chłopcy cię nie ruszą. " if oddzial else "") + ("W okolicy jeszcze %d uzbrojonych.”" % ilu if ilu > 0 else "W okolicy czysto, na razie.”")
	return t


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
	# uciekający na muszce gracza (blisko, celuje w niego) – staje i podnosi ręce
	if not rozejm and gracz is Gracz and widzi and frakcja != "wojskowy" and global_position.distance_to(gracz.global_position) < 8.0 and gracz.bron.ads > 0.6:
		var do_mnie: Vector3 = (_punkt_celu(self, false) - gracz.kamera.global_position).normalized()
		if do_mnie.dot(-gracz.kamera.global_basis.z) > 0.985 and randf() < delta * 2.0:
			_poddaj_sie()
			return
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
		# schowany za osłoną, pozycja znana – granat
		if granaty > 0 and _granat_cd <= 0.0 and czas_bez_kontaktu > 1.2 and ostatnia_pozycja != Vector3.ZERO:
			var dg := global_position.distance_to(ostatnia_pozycja)
			if dg > 6.0 and dg < 22.0 and randf() < delta * 0.9:
				_rzuc_granat(ostatnia_pozycja)
		if czas_bez_kontaktu > 3.0:
			# nie gna od razu za graczem: trzyma kąt, potem ostrożnie szuka
			stan = "szukanie"
			_trzymaj_t = randf_range(5.0, 11.0) if cecha != "agresywny" else randf_range(2.0, 4.0)
			_napis(["Gdzie on jest?", "Straciłem kontakt!", "Trzymać kąty!"].pick_random())
			return
	if morale < 12.0 and cecha != "agresywny" and posterunek.is_empty():
		# osaczony, ranny albo bez amunicji – przy graczu blisko rzuca broń i się poddaje
		var blisko: bool = gracz is Gracz and widzi and global_position.distance_to(gracz.global_position) < 9.0
		var beznadzieja: bool = cialo.procent() < 0.6 or (_w_magazynku <= 0 and zapas_mag <= 0) or _przygwozdzenie > 1.2
		if blisko and beznadzieja and frakcja != "wojskowy" and randf() < szansa_poddania:
			_poddaj_sie()
			return
		stan = "ucieczka"
		czas_bez_kontaktu = 0.0
		_napis(["Spadam stąd!", "Odwrót!", "Nie płacą mi za to!"].pick_random())
		return
	# impas: długa wymiana ognia z okopanym posterunkiem nic nie daje – oddział odpuszcza i odchodzi
	if gracz is Wrog and not (gracz as Wrog).posterunek.is_empty() and posterunek.is_empty() and _czas_walki > 75.0:
		_odpuszczone[gracz] = Time.get_ticks_msec() / 1000.0 + 120.0
		_napis(["Nie przejdziemy tędy. Odwrót!", "Okopali się. Szkoda ludzi – wycofać się!", "Obchodzimy to gniazdo!"].pick_random())
		if oddzial:
			for w in oddzial.czlonkowie:
				if is_instance_valid(w) and w != self and not w.cialo.martwy:
					w._odpuszczone[gracz] = _odpuszczone[gracz]
					if w.gracz == gracz:
						w.gracz = null
						w.stan = "patrol"
		var od: Vector3 = global_position + (global_position - (gracz as Node3D).global_position).normalized() * 14.0
		gracz = null
		_czas_walki = 0.0
		stan = "patrol"
		_idz(_najblizszy_na_siatce(od))
		_patrol_t = 8.0
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
	if _przygwozdzenie > 0.95 and _w_oslonie:
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


## Kula przeleciała blisko (przygniatanie ogniem): gorsza celność, częstsze krycie się, spadek morale.
func przygniec(sila: float, od_kogo: Node = null) -> void:
	if cialo == null or cialo.martwy:
		return
	_przygwozdzenie = minf(2.0, _przygwozdzenie + 0.5 * sila)
	morale -= 1.2 * sila
	if od_kogo is Node3D and wrogi(od_kogo) and stan in ["patrol", "czujny", "szukanie"]:
		gracz = od_kogo
		ostatnia_pozycja = (od_kogo as Node3D).global_position
		stan = "szukanie"
	if _przygwozdzenie > 1.2 and randf() < 0.3:
		_napis(["Przygniata nas!", "Głowy w dół!", "Nie da się wychylić!"].pick_random())


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
			Dzwiek.graj_3d("mag_wyjmij", global_position + Vector3.UP * 1.2, get_parent(), -4.0, 1.0, 18.0)
			get_tree().create_timer(_przeladowanie * 0.6).timeout.connect(func():
				if is_instance_valid(self) and stan != "martwy":
					Dzwiek.graj_3d("mag_wloz", global_position + Vector3.UP * 1.2, get_parent(), -3.0, 1.0, 18.0)
					Dzwiek.graj_3d("zamek_kb", global_position + Vector3.UP * 1.2, get_parent(), -4.0, 1.0, 20.0))
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
	# zaniedbana broń wroga też się zacina: przerwa na przeładowanie zamka, okrzyk
	var stan_b := float(bron.dane.get("stan", 70.0))
	if not bd.has("wewnetrzny") and randf() < 0.004 * (1.0 + (100.0 - stan_b) / 30.0):
		_strzal_t = randf_range(1.4, 2.2)
		_napis(["Zacięcie!", "Kurwa, zacięło!", "Zacięło mi się!"].pick_random())
		Dzwiek.graj_3d("sucho", global_position, get_parent(), -2.0, 0.9)
		return
	_w_magazynku -= 1
	var ad: Dictionary = Dane.def(amunicja_id)["amunicja"]
	var oko := _oko() + Vector3.UP * -0.1
	var cel := _punkt_celu(gracz, false)
	var d := oko.distance_to(cel)
	var celnosc := float(dane_frakcji.get("celnosc", 0.6))
	# celność spada z odległością wyraźniej (karabin z ręki, stres) – walka na dystans to tłumienie, nie snajperka
	var kat := (4.5 * (1.5 - celnosc)) * (1.0 + d / 14.0) * (1.0 + _halas_celu(gracz) * 0.8)
	kat *= cialo.mnoznik_celnosci()
	# pierwsze strzały są nerwowe i niecelne, potem przeciwnik się "wstrzeliwuje"
	kat *= lerpf(2.2, 1.0, clampf(_czas_walki / 3.5, 0.0, 1.0)) * (1.0 + _przygwozdzenie)
	kat *= 1.0 + 1.5 * Efekty.zaslona_kurzu(_oko(), gracz.global_position + Vector3.UP * 1.2)   # strzela w kurz
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
		# kula obok gracza (nie w niego): świst i przygniecenie ogniem
		if not col.has_meta("gracz"):
			var gr := get_tree().get_first_node_in_group("gracz") as Node3D
			if gr and gr.has_method("swist"):
				var dd := Balistyka.odl_od_odcinka(gr.global_position + Vector3.UP * 1.5, oko, r["position"])
				if dd < 1.8:
					Dzwiek.graj("swist", lerpf(-2.0, -12.0, dd / 1.8), randf_range(0.9, 1.15))
					gr.swist(dd, oko, r["position"])
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
	var predkosc := (3.1 if biegnie else 1.2) * cialo.mnoznik_ruchu() * lerpf(1.0, 0.5, kucanie)
	if not _agent.is_navigation_finished() and cel_ruchu != Vector3.ZERO:
		var nast := _agent.get_next_path_position()
		var d := nast - global_position
		d.y = 0
		if d.length() > 0.05:
			v = d.normalized() * predkosc
			if stan != "walka" or not widzi:
				_obroc_do(global_position + d, delta, 2.4)
	elif _w_oslonie == false and stan == "walka" and not _oslona.is_empty():
		if global_position.distance_to(_oslona["pos"]) < 0.9:
			_w_oslonie = true
			_wychyl_t = 0.5
	if not _oslona.is_empty() and global_position.distance_to(_oslona["pos"]) < 0.9:
		_w_oslonie = true
	# ciężki ruch: powolne rozpędzanie i hamowanie z wyposażeniem na plecach
	var przysp := 5.0 if v.length() > Vector2(velocity.x, velocity.z).length() else 9.0
	velocity.x = move_toward(velocity.x, v.x, delta * przysp)
	velocity.z = move_toward(velocity.z, v.z, delta * przysp)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = -0.3
	move_and_slide()
	# przesuwne przedmioty na drodze: odpycha je z drogi (krzesło łatwo, szafkę z trudem – słychać)
	for ci in get_slide_collision_count():
		var kol := get_slide_collision(ci)
		var c := kol.get_collider()
		if c is Przesuwny and v.length() > 0.1:
			(c as Przesuwny).apply_central_impulse(v.normalized() * minf(40.0, (c as Przesuwny).mass * 0.6) * get_physics_process_delta_time() * 6.0)

	kucanie = move_toward(kucanie, _kucanie_cel, delta * 3.5)
	var pozioma := Vector2(velocity.x, velocity.z).length()
	if pozioma > 0.5:
		_krok_t += pozioma * delta
		if _krok_t > (0.85 if biegnie else 0.65):
			_krok_t = 0.0
			Dzwiek.krok(global_position, get_parent(), -1.0 if biegnie else -7.0, 0.9, 25.0)


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
	if poddany:
		# ręce w górze, dłonie przy głowie
		var drz := sin(_oddech * 9.0) * 0.006
		_ik(_czesci["ramie_p"], _czesci["lokiec_p"], Vector3(0.24, 0.93 + drz, -0.04), Vector3(1.0, -0.2, 0.3))
		_ik(_czesci["ramie_l"], _czesci["lokiec_l"], Vector3(-0.24, 0.93 - drz, -0.04), Vector3(-1.0, -0.2, 0.3))
	else:
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
	_glos(t)


## Głos do okrzyku (syntezowany, bez słów – barwa stała dla danej postaci): krzyk alarmu, komenda,
## ranny albo przyciszone mruknięcie. Głos słychać dalej niż kroki – i zdradza pozycję.
func _glos(t: String, rodzaj := "") -> void:
	if rodzaj == "":
		var krzyk := ["Kontakt", "Tam", "Widzę", "Mam go", "Strzały", "Uwaga", "Obcy", "Zacię", "Odwrót", "Spadam"]
		if ["Dostałem", "Trafi", "boli", "Krwawię", "Medyka"].any(func(k): return t.contains(k)):
			rodzaj = "ranny"
		elif t.ends_with("...") or not t.contains("!"):
			rodzaj = "szept"
		elif krzyk.any(func(k): return t.contains(k)):
			rodzaj = "krzyk"
		else:
			rodzaj = "komenda"
	var id := get_instance_id()
	var barwa := int(id % 3)
	var wys := 0.92 + float(id % 7) * 0.025
	var nazwa := "glos_szept" if rodzaj == "szept" else ("glos_smierc" if rodzaj == "smierc" else "glos_%s_%d" % [rodzaj, barwa])
	var db: float = {"szept": -14.0, "komenda": -4.0, "krzyk": 0.0, "ranny": -2.0, "smierc": -3.0}.get(rodzaj, -4.0)
	var zas: float = {"szept": 9.0, "komenda": 30.0, "krzyk": 40.0, "ranny": 30.0, "smierc": 25.0}.get(rodzaj, 30.0)
	Dzwiek.graj_3d(nazwa, global_position + Vector3.UP * 1.6, get_parent(), db, wys, zas)


# ------------------------------------------------------------------ śmierć

func _smierc(_przyczyna: String) -> void:
	if randf() < 0.75:
		_glos("", "smierc")
	stan = "martwy"
	collision_layer = 0
	collision_mask = Balistyka.WARSTWA_SWIAT
	for a in find_children("*", "Area3D", true, false):
		a.queue_free()
	if oddzial:
		oddzial.strata(self)
	if not _oslona.is_empty() and menedzer:
		menedzer.zwolnij_oslone(self)
	if _latarka:
		_latarka.visible = false
	# bezwładne ciało (ragdoll): upada zgodnie z kierunkiem kuli; broń wypada z rąk w _zwloki
	if is_instance_valid(_czesci.get("bron")):
		(_czesci["bron"] as Node3D).visible = false
	_ragdoll = Ragdoll.z_postaci(get_parent(), _czesci, velocity, _ost_kier if _ost_kier.length() > 0.01 else -global_basis.z * -1.0)
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(_ragdoll):
			Dzwiek.graj_3d("upadek_miekki", _ragdoll.srodek(), get_parent(), -4.0, randf_range(0.8, 0.95)))
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
	pj.add_to_group("lup_swiat")
	# przeszukiwanie ciała po kolei: kieszenie kurtki, spodni, ładownice, worek/plecak; pancerz i hełm
	# trzeba odpiąć i zdjąć (trwa)
	var kurtka := Siatka.new(4, 4)
	var spodnie := Siatka.new(4, 4)
	var ladownice := Siatka.new(8, 4)
	var plecak := Siatka.new(10, 8)
	var na_ciele := Siatka.new(10, 6)
	pj.siatka = kurtka
	# broń z resztą amunicji w magazynku – wypada z rąk i leży obok (chyba że już ją rzucił, poddając się)
	var bd: Dictionary = bron.defn()["bron"]
	if _bron_upuszczona:
		pass
	elif bd.has("wewnetrzny"):
		bron.dane["wewn"] = clampi(_w_magazynku, 0, int(bd["wewnetrzny"]))
		bron.dane["komora"] = ""
	elif bron.dane["mag"] != null:
		bron.dane["mag"].dane["naboje"] = maxi(0, _w_magazynku - 1)
		bron.dane["komora"] = amunicja_id if _w_magazynku > 0 else ""
	if not _bron_upuszczona:
		bron.dane["stan"] = randf_range(35.0, 80.0)    # broń z ciała: zaniedbana
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
			m.dane["sprawdzony"] = false
			if not ladownice.dodaj(m):
				plecak.dodaj(m)
	else:
		spodnie.dodaj(Przedmiot.nowy(amunicja_id, randi_range(3, 10)))
	for i in granaty:
		if not ladownice.dodaj(Przedmiot.nowy("granat_f1")):
			plecak.dodaj(Przedmiot.nowy("granat_f1"))
	if pancerz:
		na_ciele.dodaj(pancerz)
	if helm:
		na_ciele.dodaj(helm)
	for p in lup:
		if p.typ() == "lup" and randf() < 0.6:
			p.dane["nieznany"] = true
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
	add_child(pj)
	if _ragdoll and is_instance_valid(_ragdoll):
		# przeszukiwanie z każdej części ciała; pole przenosi się na tułów, gdy ciało się ułoży
		_ragdoll.ustaw_pojemnik(pj)
		pj.collision_layer = 0
		pj.set_meta("ragdoll", _ragdoll)
		pj.global_position = _ragdoll.srodek()
	else:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.2, 0.5, 2.2)
		cs.shape = bs
		cs.position = Vector3(0, 0.25, 0)
		pj.add_child(cs)
	set_physics_process(false)
