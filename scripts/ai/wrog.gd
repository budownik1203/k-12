class_name Wrog
extends CharacterBody3D
## Przeciwnik ludzki (Szabrownicy, Najemnicy). Percepcja: wzrok, słuch, pamięć ostatniej pozycji.
## Zachowanie: patrol → czujność → walka (osłony, flankowanie, ostrzał) → szukanie → ucieczka przy niskim morale.

signal zginal(wrog: Wrog)

const MASKA_WZROKU := Balistyka.WARSTWA_SWIAT
const MASKA_STRZALU := Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_HITBOX_GRACZA

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
var gracz: Gracz
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
var _drgniecie := 0.0         # odrzut ciała po trafieniu (0..1)
var _ost_kier := Vector3.FORWARD
var _nasluch := false         # czujny w miejscu: słyszał odległe strzały, nie idzie sprawdzać
var _sluch_ms := -10000
var _sluch_pos := Vector3.ZERO
var _sluch_d := 0.0
var _przygwozdzenie := 0.0   # ostrzał gracza psuje celność


func _init() -> void:
	collision_layer = Balistyka.WARSTWA_POSTACIE
	collision_mask = Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_POSTACIE


func przygotuj(frak: String, zestaw: Dictionary, rng: RandomNumberGenerator) -> void:
	frakcja = frak
	dane_frakcji = Dane.frakcje[frak]
	nazwa_jednostki = {"szabrownik": "Szabrownik", "najemnik": "Najemnik"}.get(frak, frak)
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
	_model = Node3D.new()
	add_child(_model)
	# węzły części (pivoty) – animowane proceduralnie
	_czesci["biodra"] = _czesc(_model, Vector3(0, 0.95, 0))
	_czesci["tulow"] = _czesc(_czesci["biodra"], Vector3(0, 0.0, 0))
	_czesci["tulow"].add_child(Kit.instancja([[Vector3(0, 0.3, 0), Vector3(0.44, 0.6, 0.26), ubr]]))
	if pancerz != null:
		_czesci["tulow"].add_child(Kit.instancja([[Vector3(0, 0.33, 0), Vector3(0.48, 0.48, 0.32), Color(0.2, 0.24, 0.18) if frakcja == "najemnik" else Color(0.16, 0.18, 0.26)]]))
	_czesci["glowa"] = _czesc(_czesci["tulow"], Vector3(0, 0.62, 0))
	var glowa_bryly := [[Vector3(0, 0.13, 0), Vector3(0.22, 0.26, 0.24), skora], [Vector3(0, 0.2, 0.0), Vector3(0.25, 0.16, 0.27), gl]]
	if frakcja == "szabrownik":
		glowa_bryly.append([Vector3(0, 0.12, 0.04), Vector3(0.28, 0.32, 0.24), gl])  # kaptur
		glowa_bryly.append([Vector3(0, 0.1, -0.125), Vector3(0.18, 0.1, 0.02), Color(0.12, 0.1, 0.09)])  # chusta na twarzy
	if helm != null:
		glowa_bryly.append([Vector3(0, 0.25, 0), Vector3(0.3, 0.14, 0.32), Color(0.22, 0.26, 0.18)])
	_czesci["glowa"].add_child(Kit.instancja(glowa_bryly))
	for strona in [-1, 1]:
		var ramie := _czesc(_czesci["tulow"], Vector3(0.27 * strona, 0.55, 0))
		ramie.add_child(Kit.instancja([[Vector3(0, -0.28, 0), Vector3(0.13, 0.56, 0.13), ubr], [Vector3(0, -0.6, 0), Vector3(0.1, 0.1, 0.1), skora]]))
		_czesci["ramie_l" if strona < 0 else "ramie_p"] = ramie
		var noga := _czesc(_czesci["biodra"], Vector3(0.11 * strona, 0.0, 0))
		noga.add_child(Kit.instancja([[Vector3(0, -0.47, 0), Vector3(0.16, 0.94, 0.17), spod], [Vector3(0, -0.92, -0.05), Vector3(0.15, 0.08, 0.26), Color(0.1, 0.09, 0.08)]]))
		_czesci["noga_l" if strona < 0 else "noga_p"] = noga
	# broń w rękach
	var md := Modele.bron(bron.id)
	var bm := Kit.instancja(md["cialo"] + md["mag"])
	_czesci["bron"] = _czesc(_czesci["tulow"], Vector3(0.12, 0.38, -0.25))
	_czesci["bron"].add_child(bm)
	_czesci["wylot"] = Vector3(md["lufa"])
	# hitboksy
	_hitbox(_czesci["glowa"], "glowa", Vector3(0, 0.14, 0), Vector3(0.26, 0.3, 0.27))
	_hitbox(_czesci["tulow"], "klatka", Vector3(0, 0.42, 0), Vector3(0.44, 0.34, 0.27))
	_hitbox(_czesci["tulow"], "brzuch", Vector3(0, 0.12, 0), Vector3(0.42, 0.26, 0.26))
	_hitbox(_czesci["ramie_l"], "rece", Vector3(0, -0.3, 0), Vector3(0.14, 0.6, 0.14))
	_hitbox(_czesci["ramie_p"], "rece", Vector3(0, -0.3, 0), Vector3(0.14, 0.6, 0.14))
	_hitbox(_czesci["noga_l"], "nogi", Vector3(0, -0.47, 0), Vector3(0.17, 0.94, 0.18))
	_hitbox(_czesci["noga_p"], "nogi", Vector3(0, -0.47, 0), Vector3(0.17, 0.94, 0.18))
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _kolor(a: Array) -> Color:
	return Color(a[0], a[1], a[2])


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
	# reakcja: wie, skąd strzelano
	if od_kogo is Gracz:
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
	if zrodlo is Wrog:
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
	if zrodlo is Gracz:
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
	if gracz == null or not is_instance_valid(gracz) or gracz.cialo.martwy:
		var g := get_tree().get_first_node_in_group("gracz")
		gracz = g as Gracz
		if gracz == null:
			return
	var oko := _oko()
	var cel := gracz.global_position + Vector3.UP * lerpf(1.45, 0.85, gracz.kucanie)
	var d := oko.distance_to(cel)
	if d > 32.0:
		return
	var przod := -global_basis.z
	var do_celu := (cel - oko).normalized()
	var kat := rad_to_deg(acos(clampf(przod.dot(do_celu), -1.0, 1.0)))
	if kat > 62.0 and d > 2.5 and stan != "walka":
		return
	if kat > 95.0 and d > 2.5:
		return
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(oko, cel, MASKA_WZROKU)
	if not space.intersect_ray(q).is_empty():
		# druga próba: nogi/tułów (gracz częściowo zasłonięty)
		var cel2 := gracz.global_position + Vector3.UP * 0.6
		q = PhysicsRayQueryParameters3D.create(oko, cel2, MASKA_WZROKU)
		if not space.intersect_ray(q).is_empty():
			return
	widzi = true


func _oswietlenie_gracza() -> float:
	if gracz.latarka.visible:
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
	match stan:
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
		tempo *= lerpf(1.0, 0.55, gracz.kucanie) * (1.0 + gracz.halas_ruchu * 0.6)
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
	# podchodzi ostrożnie; biegną tylko zadziorni i tylko na początku
	biegnie = czas_bez_kontaktu < 3.0 and cecha == "agresywny"
	_kucanie_cel = 0.0
	czas_bez_kontaktu += delta
	if widzi and wykrycie > 0.6:
		_wejdz_w_walke()
		return
	_idz(ostatnia_pozycja)
	if _agent.is_navigation_finished():
		biegnie = false
		_obroc_do(ostatnia_pozycja + Vector3(sin(czas_bez_kontaktu * 0.7), 0, cos(czas_bez_kontaktu * 0.7)) * 4.0, delta, 2.0)
	if czas_bez_kontaktu > 25.0:
		stan = "patrol"
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
		if czas_bez_kontaktu > 4.0:
			stan = "szukanie"
			_napis(["Gdzie on jest?", "Straciłem kontakt!", "Szukać go!"].pick_random())
			return
	if morale < 12.0 and cecha != "agresywny":
		stan = "ucieczka"
		czas_bez_kontaktu = 0.0
		_napis(["Spadam stąd!", "Odwrót!", "Nie płacą mi za to!"].pick_random())
		return
	_obroc_do(ostatnia_pozycja, delta, 7.0)
	# przeładowanie za osłoną
	if _przeladowanie > 0.0:
		_przeladowanie -= delta
		_kucanie_cel = 1.0
		if _przeladowanie <= 0.0:
			_w_magazynku = _pojemnosc()
		return
	_decyzja_t -= delta
	if _decyzja_t <= 0.0:
		_decyzja_t = randf_range(2.5, 5.0) if not _w_oslonie else randf_range(4.0, 8.0)
		_wybierz_pozycje()
	if _w_oslonie and _oslona.get("niska", false):
		# wychylanie się zza niskiej osłony
		_wychyl_t -= delta
		if _wychyl_t <= 0.0:
			_wychyl_t = randf_range(1.0, 2.4)
			_kucanie_cel = 0.0 if _kucanie_cel > 0.5 else 1.0
	elif not _w_oslonie:
		_kucanie_cel = 0.0
	if _reakcja > 0.0:
		_reakcja -= delta
		return
	if widzi and _kucanie_cel < 0.5:
		_strzelaj(delta)


func _wybierz_pozycje() -> void:
	_w_oslonie = false
	if menedzer == null or gracz == null:
		return
	var flanka := rola == "flanka" or (frakcja == "najemnik" and randf() < 0.45)
	var najlepsza := {}
	var best := -INF
	var pg := gracz.global_position
	for o in menedzer.oslony:
		var p: Vector3 = o["pos"]
		var d_ja := global_position.distance_to(p)
		var d_g := pg.distance_to(p)
		if d_ja > 14.0 or d_g < 3.5 or d_g > 22.0:
			continue
		if menedzer.zajeta_oslona(o, self):
			continue
		# osłona ma być między nami a graczem: mebel bliżej gracza niż punkt
		var m: Vector3 = o["mebel"]
		var ochrona := 1.0 if m.distance_to(pg) < p.distance_to(pg) else -1.0
		var s := ochrona * 5.0 - d_ja * 0.35 - absf(d_g - 9.0) * 0.3
		if flanka:
			var a := (global_position - pg).normalized()
			var b := (p - pg).normalized()
			s += (1.0 - a.dot(b)) * 4.0
		if cecha == "agresywny":
			s -= d_g * 0.2
		elif cecha == "ostrozny":
			s += d_g * 0.1
		if s > best:
			best = s
			najlepsza = o
	if najlepsza.is_empty():
		# brak osłony: krótki unik w bok
		var bok := global_basis.x * (1.0 if randf() < 0.5 else -1.0) * randf_range(1.5, 3.0)
		_idz(_najblizszy_na_siatce(global_position + bok))
		biegnie = false
		return
	_oslona = najlepsza
	menedzer.zajmij_oslone(najlepsza, self)
	biegnie = true
	_idz(najlepsza["pos"])
	if flanka and oddzial and randf() < 0.5:
		_napis(["Obchodzę go!", "Flankuję!", "Idę lewą!"].pick_random())


func _strzelaj(delta: float) -> void:
	_strzal_t -= delta
	if _strzal_t > 0.0:
		return
	if _w_magazynku <= 0:
		if zapas_mag > 0 or bron.defn()["bron"].has("wewnetrzny"):
			zapas_mag = maxi(0, zapas_mag - 1)
			_przeladowanie = float(bron.defn()["bron"]["przeladowanie"]) * 1.1
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
	var cel := gracz.global_position + Vector3.UP * lerpf(1.12, 0.7, gracz.kucanie)
	var d := oko.distance_to(cel)
	var celnosc := float(dane_frakcji.get("celnosc", 0.6))
	var kat := (4.5 * (1.5 - celnosc)) * (1.0 + d / 25.0) * (1.0 + gracz.halas_ruchu * 0.8)
	kat *= cialo.mnoznik_celnosci()
	# pierwsze strzały są nerwowe i niecelne, potem przeciwnik się "wstrzeliwuje"
	kat *= lerpf(2.2, 1.0, clampf(_czas_walki / 3.5, 0.0, 1.0)) * (1.0 + _przygwozdzenie)
	if gracz.kucanie > 0.5:
		kat *= 1.15
	var srut := int(ad.get("srut", 1))
	var space := get_world_3d().direct_space_state
	var kier0 := (cel - oko).normalized()
	for i in srut:
		var kier := Balistyka.rozrzut(kier0, kat + (float(bd.get("rozrzut_srutu", 0.0)) if srut > 1 else 0.0))
		var q := PhysicsRayQueryParameters3D.create(oko, oko + kier * 120.0, MASKA_STRZALU)
		q.collide_with_areas = true
		var r := space.intersect_ray(q)
		if r.is_empty():
			continue
		var col: Object = r["collider"]
		if col.has_meta("gracz"):
			var g: Gracz = col.get_meta("gracz")
			g.set_meta("zabojca", "%s (%s)" % [nazwa_jednostki, Dane.nazwa(bron.id)])
			g.trafiony(r["position"], float(ad["obrazenia"]) * float(bd.get("mnoznik", 1.0)), float(ad["penetracja"]), self, srut > 1)
		else:
			Efekty.slad(get_parent(), r["position"], r["normal"])
			Efekty.czastki(get_parent(), r["position"], r["normal"], Color(0.5, 0.48, 0.44), 5)
			# świst kuli blisko gracza
			if gracz and r["position"].distance_to(gracz.global_position) < 2.5:
				Dzwiek.graj("swist", -6.0)
	var wylot: Vector3 = (_czesci["bron"] as Node3D).global_transform * Vector3(_czesci["wylot"])
	Efekty.blysk(get_parent(), wylot, 2.5)
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
	var przysp := 3.2 if v.length() > Vector2(velocity.x, velocity.z).length() else 4.5
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
	_anim_t += delta * pozioma * 2.6
	var faza := sin(_anim_t)
	var amp := clampf(pozioma / 4.0, 0.0, 1.0) * 0.7
	var biodra: Node3D = _czesci["biodra"]
	# przysiad przy każdym kroku i kołysanie tułowia: ciężar ciała przenoszony z nogi na nogę
	biodra.position.y = lerpf(0.95, 0.6, kucanie) - absf(sin(_anim_t)) * amp * 0.06
	biodra.rotation.z = sin(_anim_t) * amp * 0.08
	(_czesci["noga_l"] as Node3D).rotation.x = faza * amp + kucanie * 1.2
	(_czesci["noga_p"] as Node3D).rotation.x = -faza * amp + kucanie * 0.4
	_drgniecie = move_toward(_drgniecie, 0.0, delta * 3.5)
	var lk := global_basis.inverse() * _ost_kier
	(_czesci["tulow"] as Node3D).rotation.x = -0.1 - kucanie * 0.25 - amp * 0.12 + _drgniecie * 0.45 * signf(lk.z)
	(_czesci["tulow"] as Node3D).rotation.z = -_drgniecie * 0.3 * signf(lk.x)
	var celuje := stan == "walka" or stan == "szukanie"
	var ram_cel := 1.3 if celuje else 0.35
	(_czesci["ramie_p"] as Node3D).rotation.x = lerpf((_czesci["ramie_p"] as Node3D).rotation.x, ram_cel, delta * 8.0)
	(_czesci["ramie_l"] as Node3D).rotation.x = lerpf((_czesci["ramie_l"] as Node3D).rotation.x, ram_cel + 0.1, delta * 8.0)
	(_czesci["ramie_l"] as Node3D).rotation.z = -0.45 if celuje else -0.05
	(_czesci["ramie_p"] as Node3D).rotation.z = 0.15 if celuje else 0.05
	var b: Node3D = _czesci["bron"]
	b.position = Vector3(0.12, 0.38 if celuje else 0.2, -0.32 if celuje else -0.15)
	b.rotation.x = 0.0 if celuje else 0.6


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
	var t := create_tween()
	t.tween_property(_model, "rotation:x", deg_to_rad(86.0 * (1.0 if lk.z >= 0.0 else -1.0)), 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(_model, "rotation:z", randf_range(-0.35, 0.35), 0.55)
	t.parallel().tween_property(_model, "position", _model.position + Vector3(lk.x, 0, lk.z).normalized() * 0.35 + Vector3(0, 0.12, 0), 0.55)
	_zwloki.call_deferred()
	zginal.emit(self)
	get_tree().call_group("ui_rajdu", "zabity_wrog", self)


func _zwloki() -> void:
	var pj := Pojemnik.new()
	pj.nazwa = "Zwłoki: " + nazwa_jednostki
	pj.collision_layer = Balistyka.WARSTWA_INTERAKCJE
	pj.czas_na_przedmiot = 0.45
	pj.siatka = Siatka.new(6, 5)
	# broń z resztą amunicji w magazynku
	var bd: Dictionary = bron.defn()["bron"]
	if bd.has("wewnetrzny"):
		bron.dane["wewn"] = clampi(_w_magazynku, 0, int(bd["wewnetrzny"]))
		bron.dane["komora"] = ""
	elif bron.dane["mag"] != null:
		bron.dane["mag"].dane["naboje"] = maxi(0, _w_magazynku - 1)
		bron.dane["komora"] = amunicja_id if _w_magazynku > 0 else ""
	pj.siatka.dodaj(bron)
	if not bd.has("wewnetrzny"):
		for i in zapas_mag:
			var m := Gra.magazynek(bd["magazynki"][0], amunicja_id, randi_range(5, _pojemnosc()))
			pj.siatka.dodaj(m)
	else:
		pj.siatka.dodaj(Przedmiot.nowy(amunicja_id, randi_range(3, 10)))
	if pancerz:
		pj.siatka.dodaj(pancerz)
	if helm:
		pj.siatka.dodaj(helm)
	for p in lup:
		pj.siatka.dodaj(p)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.2, 0.5, 2.2)
	cs.shape = bs
	cs.position = Vector3(0, 0.25, 0)
	pj.add_child(cs)
	add_child(pj)
	set_physics_process(false)
