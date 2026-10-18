class_name Bron
extends Node3D
## Broń w rękach gracza: model w widoku FPS, strzelanie hitscan, przeładowania, tryby ognia.
## Model jest przeskalowany (SKALA) i przysunięty do kamery w tej samej proporcji, więc wygląda
## identycznie, a nie przenika przez ściany.

signal komunikat(tekst: String)
signal zmiana

const SKALA := 0.3
const MASKA_STRZALU := Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_HITBOX_WROGA

var gracz: Node3D
var kamera: Camera3D
var przedmiot: Przedmiot = null
var bd := {}                 # definicja "bron" z danych
var md := {}                 # definicja modelu
var model: Node3D
var mag_node: Node3D

var ads := 0.0
var cooldown := 0.0
var stan := "gotowa"         # gotowa | przeladowanie | ladowanie_wewn | sprawdzanie | wyciaganie
var stan_t := 0.0
var stan_total := 0.0
var job := {}
var bloom := 0.0
var spust_puszczony := true
var r_trzymany := 0.0
var r_aktywny := false

var latarka_w_rece := false
var _lat_node: Node3D
var _blysk: MeshInstance3D
var _blysk_t := 0.0
var _anim_akcji := ""          # "leczenie" | "magazynek" | "" – animacja rąk przy akcjach gracza
var _anim_akcji_t := 0.0
var _kick := Vector3.ZERO
var _kick_rot := Vector3.ZERO
var _sway := Vector2.ZERO
var _bob := 0.0
var _ruch := 0.0


func _ready() -> void:
	scale = Vector3.ONE * SKALA


## Ustawia broń w rękach. latarka: lewa ręka trzyma latarkę (z pistoletem albo sama, gdy p == null).
func ustaw(p: Przedmiot, latarka := false) -> void:
	przedmiot = p
	if model:
		model.queue_free()
		model = null
		mag_node = null
		_lat_node = null
		_blysk = null
		_lewa = null
		_szklo = null
	_reka_p = null
	_reka_l = null
	stan = "gotowa"
	job = {}
	latarka_w_rece = latarka and (p == null or p.defn()["bron"]["slot"] == "pistolet")
	if p == null:
		bd = {}
		if not latarka_w_rece:
			zmiana.emit()
			return
		md = {"celownik": 0.0, "lufa": [0, 0, 0], "mag": []}
		model = Node3D.new()
		add_child(model)
		_lat_node = _wezel_latarki()
		model.add_child(_lat_node)
	else:
		bd = p.defn()["bron"]
		md = Modele.bron(p.id)
		var dod_bryly := _zastosuj_dodatki(p)
		model = Node3D.new()
		add_child(model)
		if md.has("cialo3"):
			model.add_child(Bryly.instancja(md["cialo3"]))
		else:
			model.add_child(Kit.instancja(md["cialo"]))
		if not dod_bryly.is_empty():
			model.add_child(Kit.instancja(dod_bryly))
		if _kropka_poz != Vector3.ZERO:
			# czerwona kropka kolimatora: świecąca, widoczna przez okienko
			var kr := Kit.instancja([[_kropka_poz, Vector3(0.004, 0.004, 0.002), Color(1.0, 0.15, 0.1)]])
			var km := StandardMaterial3D.new()
			km.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			km.albedo_color = Color(1.0, 0.18, 0.12)
			kr.material_override = km
			kr.name = "Kropka"
			model.add_child(kr)
		mag_node = Node3D.new()
		model.add_child(mag_node)
		if md.has("mag3") and not (md["mag3"] as Array).is_empty():
			mag_node.add_child(Bryly.instancja(md["mag3"]))
		elif not md["mag"].is_empty():
			mag_node.add_child(Kit.instancja(md["mag"]))
		# dłonie z palcami (jak w Iron Blight): prawa na chwycie z palcem przy spuście,
		# lewa w osobnym węźle (animowana przy przeładowaniu), z zegarkiem pokazującym zdrowie
		_zbuduj_dlonie(bd["slot"] == "pistolet", latarka_w_rece)
		if latarka_w_rece:
			# chwyt Harriesa: latarka pod pistoletem, nadgarstki skrzyżowane
			_lat_node = _wezel_latarki()
			_lat_node.position = Vector3(-0.02, -0.075, 0.02)
			_lat_node.rotation = Vector3(0.03, 0.0, 0)
			model.add_child(_lat_node)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi == _blysk or mi == _szklo:
			continue
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not mi.has_meta("bryly"):
			(mi as MeshInstance3D).material_override = Kit.material_kolor_vm()
	_odswiez_mag()
	stan = "wyciaganie"
	stan_t = 0.0
	stan_total = 0.45
	zmiana.emit()


var _szklo: MeshInstance3D
var _kropka_poz := Vector3.ZERO
var _lat_bron_poz := Vector3.ZERO    # soczewka latarki na broni (współrzędne modelu)
var _bez_plomienia := false
var _montaz := 0.0
var _lewa: Node3D
var _bieg := 0.0
var _byl_pusty := false


## Dodatki zamontowane na broni: zmieniają punkty modelu (wylot, linia celowania, chwyt lewej ręki)
## i zwracają bryły do dorysowania.
func _zastosuj_dodatki(p: Przedmiot) -> Array:
	md = md.duplicate(true)
	_kropka_poz = Vector3.ZERO
	_lat_bron_poz = Vector3.ZERO
	_bez_plomienia = false
	var bryly := []
	var lufa: Vector3 = Vector3(md["lufa"])
	var ciemny := Color(0.13, 0.14, 0.13)
	var w := p.dodatek("wylot")
	if w:
		var dd: Dictionary = w.defn()["dodatek"]
		var dl := float(dd.get("dl", 0.1))
		var gr := float(dd.get("gr", 0.035))
		bryly.append([lufa + Vector3(0, 0, -dl * 0.5), Vector3(gr, gr, dl), ciemny])
		if w.id == "hamulec":
			for z in [0.015, 0.035]:
				bryly.append([lufa + Vector3(0, gr * 0.5, -z), Vector3(gr * 0.6, 0.006, 0.008), Color(0.05, 0.05, 0.05)])
		else:
			for i in 3:
				bryly.append([lufa + Vector3(0, 0, -dl * (0.25 + i * 0.25)), Vector3(gr + 0.003, gr + 0.003, 0.006), Color(0.09, 0.09, 0.09)])
		_bez_plomienia = not bool(dd.get("plomien", true))
		md["lufa"] = lufa + Vector3(0, 0, -dl)
	var c := p.dodatek("celownik")
	if c:
		var dd2: Dictionary = c.defn()["dodatek"]
		var os_y := float(md["celownik"]) + float(dd2.get("wys", 0.04))
		var z0 := -0.05 if p.id == "kb47" else -0.01
		if c.id == "kolimator":
			bryly.append([Vector3(0, (float(md["celownik"]) + os_y) * 0.5 - 0.01, z0), Vector3(0.024, os_y - float(md["celownik"]), 0.05), ciemny])
			# okienko: cztery cienkie ramki wokół osi optycznej
			bryly.append([Vector3(0, os_y + 0.018, z0), Vector3(0.036, 0.005, 0.03), ciemny])
			bryly.append([Vector3(0, os_y - 0.016, z0), Vector3(0.036, 0.005, 0.03), ciemny])
			bryly.append([Vector3(-0.017, os_y, z0), Vector3(0.004, 0.036, 0.03), ciemny])
			bryly.append([Vector3(0.017, os_y, z0), Vector3(0.004, 0.036, 0.03), ciemny])
			_kropka_poz = Vector3(0, os_y, z0 - 0.01)
		else:
			bryly.append([Vector3(0, (float(md["celownik"]) + os_y) * 0.5, z0), Vector3(0.018, os_y - float(md["celownik"]), 0.06), ciemny])
			bryly.append([Vector3(0, os_y, z0), Vector3(0.026, 0.026, 0.17), Color(0.1, 0.11, 0.1)])
			bryly.append([Vector3(0, os_y, z0 - 0.095), Vector3(0.036, 0.036, 0.03), Color(0.12, 0.12, 0.12)])
			bryly.append([Vector3(0, os_y, z0 + 0.095), Vector3(0.032, 0.032, 0.025), Color(0.12, 0.12, 0.12)])
			bryly.append([Vector3(0, os_y + 0.02, z0), Vector3(0.01, 0.014, 0.012), Modele.METAL])
		md["celownik"] = os_y
		md["luneta"] = c.id == "luneta"
	var ch := p.dodatek("chwyt")
	if ch:
		var pz: Vector3 = Vector3(md["przod"])
		bryly.append([pz + Vector3(0, -0.035, 0), Vector3(0.024, 0.07, 0.028), Color(0.27, 0.15, 0.09)])
		bryly.append([pz + Vector3(0, 0.0, 0), Vector3(0.03, 0.012, 0.05), ciemny])
		md["przod"] = pz + Vector3(0, -0.06, 0.0)
	var lt := p.dodatek("latarka")
	if lt:
		var lp := lufa + Vector3(0.024, -0.022, 0.12)
		bryly.append([lp, Vector3(0.022, 0.022, 0.07), ciemny])
		bryly.append([lp + Vector3(-0.012, 0.0, 0), Vector3(0.008, 0.016, 0.03), Modele.METAL_C])
		bryly.append([lp + Vector3(0, 0, -0.036), Vector3(0.018, 0.018, 0.004), Color(0.95, 0.92, 0.75)])
		_lat_bron_poz = lp + Vector3(0, 0, -0.04)
	return bryly


func ma_latarke_broni() -> bool:
	return przedmiot != null and przedmiot.dodatek("latarka") != null and model != null


## Powiększenie przy celowaniu (luneta).
func zoom() -> float:
	return przedmiot.mod("zoom") if przedmiot else 1.0


func ma_lunete() -> bool:
	return przedmiot != null and md.get("luneta", false)


## Animacja montażu dodatku: broń obrócona bokiem, lewa ręka kręci przy wylocie.
func _animuj_montaz(rot: Vector3, poz: Vector3) -> Array:
	var e := _montaz * _montaz * (3.0 - 2.0 * _montaz)
	rot += Vector3(0.22, 0.78, -0.2) * e
	poz += Vector3(0.02, -0.035, -0.03) * e
	if _lewa:
		var cel: Vector3 = (Vector3(md["lufa"]) + Vector3(0, 0, 0.06)) - Vector3(md["przod"])
		var t := _anim_akcji_t
		_lewa.position = cel * e + Vector3(sin(t * 9.0) * 0.01, cos(t * 9.0) * 0.01, 0) * e
		_lewa.rotation = Vector3(0, 0, sin(t * 9.0) * 0.6 * e)
	return [rot, poz]


var _reka_p: Reka
var _reka_l: Reka


## Dłonie przy broni: prawa obejmuje chwyt pistoletowy, lewa łoże (karabin) albo prawą dłoń (pistolet).
func _zbuduj_dlonie(pistolet: bool, tylko_prawa: bool) -> void:
	var chw: Vector3 = md.get("chwyt", Vector3(0, -0.04, 0.02))
	var kat: float = md.get("kat_chwytu", 14.0)
	var os_dol := Basis.from_euler(Vector3(deg_to_rad(kat), 0, 0)) * Vector3(0, -1, 0)
	_reka_p = Reka.new(true, false, "spust", 0.5)
	model.add_child(_reka_p)
	_reka_p.chwyc(chw, os_dol, Vector3(-1, 0, 0), 0.072)
	_reka_p.celuj_lokiec(Vector3(0.16, -0.34, 0.42), model)
	_lewa = null
	_reka_l = null
	if tylko_prawa:
		return
	_lewa = Node3D.new()
	model.add_child(_lewa)
	_reka_l = Reka.new(false, true, "pistolet" if pistolet else "lozysko", 0.5)
	_lewa.add_child(_reka_l)
	if pistolet:
		_reka_l.chwyc(chw + Vector3(-0.024, -0.012, 0.014), os_dol, Vector3(1, 0.1, 0), 0.07)
		_reka_l.celuj_lokiec(Vector3(-0.14, -0.34, 0.4), model)
	else:
		var przod: Vector3 = md.get("lozysko", md["przod"])
		_reka_l.chwyc(przod, Vector3(0, 0, 1), Vector3(0.15, 1.0, 0.0), 0.062, 0.042)
		_reka_l.celuj_lokiec(przod + Vector3(-0.22, -0.3, 0.28), model)


func _wezel_latarki() -> Node3D:
	var n := Node3D.new()
	n.add_child(Kit.instancja(Modele.latarka()))
	var rl := Reka.new(false, true, "latarka", 0.5)
	n.add_child(rl)
	rl.chwyc(Vector3(0, 0, 0.0), Vector3(0, 0, 1), Vector3(1, 0.3, 0), 0.07)
	rl.celuj_lokiec(Vector3(-0.1, -0.3, 0.32), n)
	_reka_l = rl
	_szklo = Kit.instancja(Modele.szklo_latarki())
	_szklo.name = "Szklo"
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.95, 0.78)
	_szklo.material_override = m
	n.add_child(_szklo)
	return n


## Punkt i kierunek snopu latarki w świecie (soczewka trzymanej latarki).
func transform_latarki() -> Transform3D:
	if (_lat_node == null or not is_instance_valid(_lat_node)) and ma_latarke_broni():
		return Transform3D(model.global_basis.orthonormalized(), model.global_transform * _lat_bron_poz)
	if _lat_node == null or not is_instance_valid(_lat_node):
		return Transform3D(kamera.global_basis, kamera.global_position)
	var b := _lat_node.global_basis.orthonormalized()
	return Transform3D(b, _lat_node.global_transform * Vector3(0, 0, -0.15))


func swiecenie_szkla(wl: bool) -> void:
	if _szklo:
		(_szklo.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.95, 0.78) if wl else Color(0.25, 0.25, 0.22)


## Animacja rąk przy akcji gracza (leczenie, napełnianie magazynków); "" kończy.
func animacja_akcji(nazwa: String) -> void:
	if nazwa != "" and nazwa != "schowaj" and nazwa != "montaz" and nazwa != _rece_typ:
		_zbuduj_rece_akcji(nazwa)
	_anim_akcji = nazwa
	_anim_akcji_t = 0.0


## Przeładowanie magazynkiem: fazy ruchu lewej ręki i magazynka (współrzędne modelu broni).
func _animuj_przeladowanie(f: float) -> void:
	if md["mag"].is_empty():
		return
	var p_mag: Vector3 = Vector3(md["mag"][0][0])
	var p_przod: Vector3 = Vector3(md["przod"])
	var chwyt := p_mag + Vector3(0, -0.035, 0.0)           # dłoń na magazynku
	var kamizelka := chwyt + Vector3(-0.06, -0.32, 0.12)    # poza kadrem, przy kamizelce
	var reka := Vector3.ZERO
	var mag := Vector3.ZERO
	var szybkie: bool = job.get("szybkie", false)
	if f < 0.18:
		var e := smoothstep(0.0, 0.18, f)
		reka = p_przod.lerp(chwyt, e)
		mag = Vector3.ZERO
	elif f < 0.42:
		var e := smoothstep(0.18, 0.42, f)
		reka = chwyt.lerp(kamizelka, e)
		# przy szybkim przeładowaniu stary magazynek leci na ziemię, inaczej ręka go zabiera
		mag = (Vector3(0, -0.6, 0.05) * e) if szybkie else (reka - chwyt)
		if mag_node:
			mag_node.visible = e < (0.4 if szybkie else 0.9)
	elif f < 0.68:
		var e := smoothstep(0.42, 0.68, f)
		reka = kamizelka.lerp(chwyt + Vector3(0, -0.05, 0), e)
		mag = reka - chwyt
		if mag_node:
			mag_node.visible = e > 0.15
	elif f < 0.78:
		var e := smoothstep(0.68, 0.78, f)
		reka = (chwyt + Vector3(0, -0.05, 0)).lerp(chwyt + Vector3(0, 0.008, 0), e)
		mag = reka - chwyt
		if mag_node:
			mag_node.visible = true
		if e > 0.95 and not _wcisniety:
			_wcisniety = true
			Dzwiek.graj("klik", -6.0, 0.9)
	else:
		var e := smoothstep(0.78, 1.0, f)
		mag = Vector3.ZERO
		reka = chwyt.lerp(p_przod, e)
		if _byl_pusty and not jest_pistolet():
			# pusta komora: lewa dłoń sięga do rączki zamka po prawej stronie i przeciąga ją do tyłu
			var raczka := Vector3(0.05, 0.075, -0.09) + (p_przod - Vector3(md.get("lozysko", p_przod)))
			var t := (f - 0.78) / 0.22
			if t < 0.35:
				reka = chwyt.lerp(raczka, smoothstep(0.0, 0.35, t))
			elif t < 0.6:
				reka = raczka + Vector3(0, 0, 0.07) * smoothstep(0.35, 0.5, t)
				if t > 0.5 and t < 0.56:
					_kick_rot.z += 0.012
					_kick.z += 0.002
			else:
				reka = (raczka + Vector3(0, 0, 0.07)).lerp(p_przod, smoothstep(0.6, 1.0, t))
		elif _byl_pusty and f > 0.84 and f < 0.95:
			# zamek: szarpnięcie broni przy przeładowaniu z pustą komorą
			_kick_rot.z += 0.012
			_kick.z += 0.002
	if f < 0.7:
		_wcisniety = false
	if mag_node:
		mag_node.position = mag
	if _lewa:
		_lewa.position = reka - p_przod if not jest_pistolet() else (reka - p_przod) * 0.7
	# palce lewej dłoni: otwarta przy sięganiu, zaciśnięta na magazynku, chwyt rączki zamka, powrót na łoże
	if _lewa and _reka_l and is_instance_valid(_reka_l):
		var poza := "pistolet" if jest_pistolet() else "lozysko"
		if f < 0.16:
			poza = "otwarta"
		elif f < 0.78:
			poza = "magazynek"
		elif _byl_pusty and not jest_pistolet() and f < 0.93:
			poza = "piesc"
		elif f < 0.9:
			poza = "otwarta"
		_reka_l.ustaw_chwyt(poza)


var _wcisniety := false


func _odswiez_mag() -> void:
	if mag_node:
		mag_node.visible = przedmiot != null and przedmiot.dane.get("mag") != null


func jest_pistolet() -> bool:
	return not bd.is_empty() and bd["slot"] == "pistolet"


func zajeta() -> bool:
	return stan != "gotowa"


## Aktualizacja logiki, wołana przez gracza w _physics_process.
## we: {"strzal": bool (trzymany), "ads": bool, "przeladuj": bool (trzymany), "tryb": bool (wciśnięty),
##      "sprawdz": bool (wciśnięty), "moze": bool, "ruch": float 0..1, "kucanie": float, "celnosc": float}
func aktualizuj(delta: float, we: Dictionary) -> void:
	_ruch = we.get("ruch", 0.0)
	_bieg = move_toward(_bieg, 1.0 if we.get("bieg", false) else 0.0, delta * 5.0)
	cooldown = maxf(0.0, cooldown - delta)
	bloom = maxf(0.0, bloom - delta * 2.5)
	var moze: bool = we.get("moze", true) and przedmiot != null
	ads = move_toward(ads, 1.0 if (we.get("ads", false) and moze and stan == "gotowa") else 0.0, delta * 6.0 / (1.0 + (zoom() - 1.0) * 0.35))
	if przedmiot == null:
		# sama latarka: tylko animacja wyjmowania
		if stan != "gotowa":
			stan_t += delta
			if stan_t >= stan_total:
				stan = "gotowa"
		return
	# stany czasowe
	if stan != "gotowa":
		stan_t += delta
		if stan == "ladowanie_wewn" and we.get("strzal", false):
			_koniec_stanu()  # przerwanie ładowania strzelby strzałem
		elif stan_t >= stan_total:
			_koniec_stanu()
		return
	if not moze:
		spust_puszczony = not we.get("strzal", false)
		return
	# przeładowanie: krótkie wciśnięcie = zwykłe, przytrzymanie = szybkie z upuszczeniem magazynka
	if we.get("przeladuj", false):
		r_trzymany += delta
		r_aktywny = true
		if r_trzymany >= 0.35:
			r_aktywny = false
			r_trzymany = -99.0
			_zacznij_przeladowanie(true)
	elif r_aktywny:
		r_aktywny = false
		if r_trzymany > 0.0:
			_zacznij_przeladowanie(false)
		r_trzymany = 0.0
	else:
		r_trzymany = 0.0
	if we.get("tryb", false) and bd["tryby"].size() > 1:
		przedmiot.dane["tryb"] = (int(przedmiot.dane["tryb"]) + 1) % bd["tryby"].size()
		komunikat.emit("Tryb ognia: " + ("ogień ciągły" if bd["tryby"][przedmiot.dane["tryb"]] == "auto" else "pojedynczy"))
		Dzwiek.graj("klik", -8.0)
	if we.get("sprawdz", false):
		stan = "sprawdzanie"
		stan_t = 0.0
		stan_total = 1.1
		return
	if we.get("strzal", false):
		_sprobuj_strzal(we)
	else:
		spust_puszczony = true


func _tryb() -> String:
	return bd["tryby"][clampf(int(przedmiot.dane["tryb"]), 0, bd["tryby"].size() - 1)]


func _pobierz_naboj() -> String:
	var d := przedmiot.dane
	if bd.has("wewnetrzny"):
		if d["wewn"] > 0:
			d["wewn"] -= 1
			return d["wewn_typ"]
		return ""
	if d["komora"] == "":
		return ""
	var a: String = d["komora"]
	var m: Przedmiot = d["mag"]
	if m != null and m.dane["naboje"] > 0:
		d["komora"] = m.dane["amunicja"]
		m.dane["naboje"] -= 1
	else:
		d["komora"] = ""
	return a


func _sprobuj_strzal(we: Dictionary) -> void:
	if cooldown > 0.0:
		return
	if _tryb() == "semi" and not spust_puszczony:
		return
	spust_puszczony = false
	var amun := _pobierz_naboj()
	if amun == "":
		Dzwiek.graj("sucho", -4.0)
		cooldown = 0.25
		return
	cooldown = 60.0 / float(bd["rpm"])
	var ad: Dictionary = Dane.def(amun)["amunicja"]
	var srut := int(ad.get("srut", 1))
	var baza: float = lerpf(float(bd["rozrzut_biodro"]) * przedmiot.mod("rozrzut_biodro"), float(bd["rozrzut_ads"]) * przedmiot.mod("rozrzut_ads"), ads)
	var kat: float = baza * (1.0 + _ruch * 1.4) * lerpf(1.0, 0.8, we.get("kucanie", 0.0)) * we.get("celnosc", 1.0) + bloom
	var space := kamera.get_world_3d().direct_space_state
	var od := kamera.global_position
	var przod := -kamera.global_basis.z
	var obr := float(ad["obrazenia"]) * float(bd.get("mnoznik", 1.0)) * przedmiot.mod("obrazenia")
	for i in srut:
		var kier := Balistyka.rozrzut(przod, kat)
		if srut > 1:
			kier = Balistyka.rozrzut(kier, float(bd.get("rozrzut_srutu", 3.0)))
		_promien(space, od, kier, obr, float(ad["penetracja"]))
	# odrzut
	var sila: float = float(bd["odrzut"]) * przedmiot.mod("odrzut") * lerpf(1.0, 0.65, ads) * lerpf(1.0, 0.85, float(we.get("kucanie", 0.0))) * float(we.get("celnosc", 1.0))
	if gracz.has_method("dodaj_odrzut"):
		gracz.dodaj_odrzut(Vector2(randf_range(-0.35, 0.35) * sila, sila))
	if _tryb() == "auto":
		bloom = minf(bloom + 0.35, 3.0)
	_kick += Vector3(randf_range(-0.006, 0.006), 0.012 * lerpf(1.0, 0.2, ads), 0.07 + sila * 0.016)
	# przy celowaniu broń idzie głównie w tył (w ramię), a nie w górę – zamek nie wchodzi na linię wzroku
	_kick_rot += Vector3(deg_to_rad(6.0 + sila * 2.0) * lerpf(1.0, 0.3, ads), randf_range(-0.04, 0.04), randf_range(-0.05, 0.05))
	var wylot := model.global_transform * Vector3(md["lufa"])
	Efekty.blysk(gracz.get_parent(), wylot, (3.0 if bd["slot"] == "pistolet" else 4.0) * (0.15 if _bez_plomienia else 1.0) * lerpf(1.0, 0.6, ads))
	if not _bez_plomienia:
		# gwiazda + języki ognia wzdłuż lufy; przy celowaniu gwiazda bez środka – cel zostaje widoczny
		var sk := 0.65 if bd["slot"] == "pistolet" else (1.35 if bd["kaliber"] == "12/70" else 1.0)
		Efekty.plomien_wylotu(model, Transform3D(Basis(), Vector3(md["lufa"])), sk, ads)
	if _reka_p and is_instance_valid(_reka_p):
		_reka_p.ustaw_chwyt("strzal")
		_spust_t = 0.07
	if ads < 0.5:
		Efekty.dym_wylotu(gracz.get_parent(), wylot, -kamera.global_basis.z, 0.6 if _bez_plomienia else 1.0)
	if not bd.has("wewnetrzny"):
		Efekty.luska(gracz.get_parent(), model.global_transform * Vector3(0.03, 0.05, -0.06), kamera.global_basis.x)
	if gracz.has_method("kopniecie"):
		gracz.kopniecie(sila)
	var halas := 26.0
	match bd["kaliber"]:
		"7.62x39": halas = 36.0
		"12/70": halas = 32.0
	halas *= przedmiot.mod("halas")
	Gra.emituj_halas(gracz.global_position, halas, gracz)
	var dzw := {"9x18": "strzal_pistolet", "7.62x39": "strzal_karabin", "12/70": "strzal_strzelba"}
	var nazwa_dzw: String = dzw.get(bd["kaliber"], "strzal_pistolet")
	if _bez_plomienia:
		# tłumik: krótki, suchy trzask bez pogłosu
		Dzwiek.graj(nazwa_dzw, -13.0, 1.45)
		Dzwiek.graj("klik", -6.0, 0.6)
	else:
		Dzwiek.graj(nazwa_dzw, -1.0 + (2.0 if przedmiot.mod("halas") > 1.0 else 0.0))
		# pogłos w ciasnych wnętrzach: przytłumione odbicie po ułamku sekundy
		get_tree().create_timer(0.09).timeout.connect(func(): Dzwiek.graj(nazwa_dzw, -15.0, 0.78))
		get_tree().create_timer(0.21).timeout.connect(func(): Dzwiek.graj(nazwa_dzw, -22.0, 0.7))
	zmiana.emit()


func _promien(space: PhysicsDirectSpaceState3D, od: Vector3, kier: Vector3, obr: float, pen: float) -> void:
	var q := PhysicsRayQueryParameters3D.create(od, od + kier * 150.0, MASKA_STRZALU)
	q.collide_with_areas = true
	var r := space.intersect_ray(q)
	if r.is_empty():
		return
	var col: Object = r["collider"]
	if col.has_meta("czesc"):
		var wl = col.get_meta("wlasciciel")
		if is_instance_valid(wl) and wl.has_method("trafiony"):
			wl.trafiony(String(col.get_meta("czesc")), obr, pen, gracz, r["position"], kier)
			var zabity: bool = wl.get("cialo") != null and wl.cialo.martwy
			get_tree().call_group("hud", "znacznik_trafienia", zabity, String(col.get_meta("czesc")) == "glowa")
			# krew na ścianie za celem
			var q2 := PhysicsRayQueryParameters3D.create(r["position"], r["position"] + kier * 2.5, Balistyka.WARSTWA_SWIAT)
			var r2 := space.intersect_ray(q2)
			if not r2.is_empty() and randf() < 0.7:
				Efekty.slad(gracz.get_parent(), r2["position"], r2["normal"], true)
			return
	var swiat := gracz.get_parent() as Node3D
	Efekty.slad(swiat, r["position"], r["normal"])
	Efekty.czastki(swiat, r["position"], r["normal"], Color(0.5, 0.48, 0.44), 12, 3.0)
	if randf() < 0.35:
		Efekty.czastki(swiat, r["position"], r["normal"], Color(1.0, 0.8, 0.4), 3, 5.0)
	Dzwiek.graj_3d("trafienie_beton", r["position"], swiat, -6.0)


# ------------------------------------------------------------------ przeładowania

func _zacznij_przeladowanie(szybkie: bool) -> void:
	var ekw: Ekwipunek = gracz.ekw
	if bd.has("wewnetrzny"):
		if przedmiot.dane["wewn"] >= int(bd["wewnetrzny"]):
			return
		if ekw.policz_amunicje(bd["kaliber"]) <= 0:
			komunikat.emit("Brak amunicji " + bd["kaliber"])
			return
		stan = "ladowanie_wewn"
		stan_t = 0.0
		stan_total = float(bd["przeladowanie"]) * 0.5
		Dzwiek.graj("przeladowanie", -6.0, 1.2)
		return
	var z := ekw.znajdz_magazynek(bd["magazynki"])
	if z.is_empty():
		komunikat.emit("Brak załadowanych magazynków (napełnij: G w ekwipunku)")
		return
	var t := float(bd["przeladowanie"]) * (1.0 if z["szybki"] else 1.7)
	if szybkie:
		t *= 0.7
	if przedmiot.dane["komora"] == "":
		t += 0.5
	_byl_pusty = przedmiot.dane["komora"] == ""
	job = {"nowy": z["p"], "siatka": z["siatka"], "szybkie": szybkie}
	stan = "przeladowanie"
	stan_t = 0.0
	stan_total = t
	Dzwiek.graj("przeladowanie", -4.0)
	if not z["szybki"]:
		komunikat.emit("Magazynek z plecaka – dłuższe przeładowanie")


func _koniec_stanu() -> void:
	var s := stan
	stan = "gotowa"
	match s:
		"przeladowanie":
			_dokoncz_przeladowanie()
		"ladowanie_wewn":
			var wz: Dictionary = gracz.ekw.zabierz_amunicje(bd["kaliber"], 1, przedmiot.dane["wewn_typ"])
			if wz["n"] > 0:
				if przedmiot.dane["wewn"] == 0 or przedmiot.dane["wewn_typ"] == "":
					przedmiot.dane["wewn_typ"] = wz["id"]
				przedmiot.dane["wewn"] += 1
				Dzwiek.graj("klik", -6.0, 0.8)
				if przedmiot.dane["wewn"] < int(bd["wewnetrzny"]) and gracz.ekw.policz_amunicje(bd["kaliber"]) > 0:
					stan = "ladowanie_wewn"
					stan_t = 0.0
		"sprawdzanie":
			komunikat.emit(opis_amunicji())
	zmiana.emit()


func _dokoncz_przeladowanie() -> void:
	var nowy: Przedmiot = job.get("nowy")
	var siatka: Siatka = job.get("siatka")
	if nowy == null or siatka == null or not siatka.zawiera(nowy):
		job = {}
		return
	var stary: Przedmiot = przedmiot.dane["mag"]
	siatka.usun(nowy)
	przedmiot.dane["mag"] = nowy
	if stary != null:
		if job["szybkie"]:
			gracz.upusc(stary)
		elif not siatka.dodaj(stary) and not gracz.ekw.dodaj(stary):
			gracz.upusc(stary)
	if przedmiot.dane["komora"] == "" and nowy.dane["naboje"] > 0:
		przedmiot.dane["komora"] = nowy.dane["amunicja"]
		nowy.dane["naboje"] -= 1
	job = {}
	_odswiez_mag()
	gracz.ekw.zmieniony.emit()


## Przybliżony stan amunicji (bez dokładnej liczby, jak przy sprawdzaniu magazynka na dotyk).
func opis_amunicji() -> String:
	if przedmiot == null:
		return ""
	if bd.has("wewnetrzny"):
		return "Załadowane lufy: %d/%d" % [przedmiot.dane["wewn"], int(bd["wewnetrzny"])]
	var m: Przedmiot = przedmiot.dane["mag"]
	if m == null:
		return "Brak magazynka" + (" (nabój w komorze)" if przedmiot.dane["komora"] != "" else "")
	var cap := float(m.defn()["magazynek"]["pojemnosc"])
	var f: float = m.dane["naboje"] / cap
	var t := "pusty"
	if f > 0.85:
		t = "pełny"
	elif f > 0.55:
		t = "ponad połowa"
	elif f > 0.3:
		t = "około połowy"
	elif f > 0.0:
		t = "prawie pusty"
	return "Magazynek: " + t


# ------------------------------------------------------------------ wygląd

func dodaj_sway(mysz: Vector2) -> void:
	_sway += mysz * 0.00035


var _spust_t := 0.0


func _process(delta: float) -> void:
	_anim_akcji_t += delta
	if _spust_t > 0.0:
		_spust_t -= delta
		if _spust_t <= 0.0 and _reka_p and is_instance_valid(_reka_p):
			_reka_p.ustaw_chwyt("spust")
	if _reka_l and is_instance_valid(_reka_l) and gracz and gracz.get("cialo"):
		_reka_l.ustaw_zdrowie(gracz.cialo.procent(), gracz.cialo.krwawi() > 0)
	_opusc = move_toward(_opusc, 1.0 if (_anim_akcji != "" and _anim_akcji != "montaz") else 0.0, delta * 4.0)
	_montaz = move_toward(_montaz, 1.0 if _anim_akcji == "montaz" else 0.0, delta * 3.0)
	if _rece_akcji:
		_rece_akcji.visible = _opusc > 0.05 and _anim_akcji != "schowaj"
		if _rece_akcji.visible:
			_animuj_rece_akcji(delta)
	if model == null:
		return
	if _blysk and _blysk.visible:
		_blysk_t -= delta
		if _blysk_t <= 0.0:
			_blysk.visible = false
	var pistolet := jest_pistolet()
	var hip := Vector3(0.14, -0.165, -0.37) if not pistolet else Vector3(0.085, -0.125, -0.3)
	if przedmiot == null:
		hip = Vector3(-0.07, -0.17, -0.36)
	var celownik := float(md["celownik"])
	var ads_poz := Vector3(0.0, -celownik, (-0.3 if not pistolet else -0.32) + (0.06 if md.get("luneta", false) else 0.0))
	var t := ads * ads * (3.0 - 2.0 * ads)
	_bob += delta * (6.0 * _ruch + 2.5 * _bieg)
	var bob := Vector3(sin(_bob) * 0.011, absf(cos(_bob)) * -0.014, 0) * _ruch * (1.0 - t * 0.85) * (1.0 + _bieg * 0.8)
	_sway = _sway.lerp(Vector2.ZERO, delta * 8.0)
	_kick = _kick.lerp(Vector3.ZERO, delta * 14.0)
	_kick_rot = _kick_rot.lerp(Vector3.ZERO, delta * 12.0)
	var poz := hip.lerp(ads_poz, t) + bob + _kick + Vector3(-_sway.x, _sway.y, 0) * (1.0 - t * 0.7)
	var rot := _kick_rot + Vector3(_sway.y * 2.0, -_sway.x * 2.0, -_sway.x * 1.5) + Vector3(0, 0.05, 0) * (1.0 - t)
	# animacje stanów
	var f := 0.0
	if stan != "gotowa" and stan_total > 0.0:
		f = clampf(stan_t / stan_total, 0.0, 1.0)
	var dip := 0.0
	match stan:
		"przeladowanie":
			# broń przechylona do magazynka; lewa ręka: wyjmuje stary, sięga do kamizelki, wkłada nowy
			var przechyl := smoothstep(0.0, 0.15, f) * (1.0 - smoothstep(0.85, 1.0, f))
			rot += Vector3(0.18, 0.3, 0.55) * przechyl
			poz += Vector3(-0.02, 0.0, 0.02) * przechyl
			_animuj_przeladowanie(f)
		"ladowanie_wewn":
			dip = sin(f * PI) * 0.6
			rot += Vector3(0.5, 0.0, 0.3) * dip
			poz += Vector3(0, -0.04, 0.02) * dip
		"sprawdzanie":
			dip = sin(f * PI)
			rot += Vector3(0.2, 0.0, -0.9) * dip
			poz += Vector3(-0.06, 0.02, 0.02) * dip
		"wyciaganie":
			var w := 1.0 - f
			rot += Vector3(-0.8, 0.0, 0.2) * w
			poz += Vector3(0, -0.2, 0.05) * w
	if stan != "przeladowanie":
		if mag_node:
			mag_node.position = Vector3.ZERO
			_odswiez_mag()
		if _lewa:
			_lewa.position = _lewa.position.lerp(Vector3.ZERO, minf(1.0, delta * 12.0))
	# bieg: broń opuszczona i odwrócona w bok
	if _bieg > 0.0:
		var eb := _bieg * _bieg * (3.0 - 2.0 * _bieg)
		rot += Vector3(-0.38, 0.42, 0.22) * eb
		poz += Vector3(0.0, -0.06, 0.04) * eb
	# akcje gracza: broń opuszczona w bok, ręce pracują przy dole kadru
	if _opusc > 0.0:
		var e := _opusc * _opusc * (3.0 - 2.0 * _opusc)
		rot += Vector3(-0.9, 0.5, 0.7) * e
		poz += Vector3(0.05, -0.16, 0.06) * e
		if _anim_akcji == "magazynek":
			# rytm wciskania nabojów
			poz.y += sin(_anim_akcji_t * 14.0) * 0.006 * e
	if _montaz > 0.0:
		var rp := _animuj_montaz(rot, poz)
		rot = rp[0]
		poz = rp[1]
	model.position = poz
	model.rotation = rot
	# przy lunecie patrzymy przez okular: model znika, HUD rysuje siatkę PSO
	model.visible = _opusc < 0.95 and not (ma_lunete() and ads > 0.9)
	# snop latarki z soczewki, po ustawieniu modelu w tej klatce (bez opóźnienia)
	if (_lat_node or ma_latarke_broni()) and gracz and gracz.get("latarka") and gracz.latarka.visible:
		gracz.latarka.global_transform = transform_latarki()


var _opusc := 0.0
var _rece_akcji: Node3D
var _rece_typ := ""


## Ręce (i trzymany przedmiot) przy akcji: bandażowanie, wciskanie nabojów do magazynka.
func _animuj_rece_akcji(_delta: float) -> void:
	var e := _opusc * _opusc * (3.0 - 2.0 * _opusc)
	var t := _anim_akcji_t
	_rece_akcji.position = Vector3(0.0, -0.24 + 0.08 * e, -0.44)
	var lewa: Node3D = _rece_akcji.get_child(0)
	var prawa: Node3D = _rece_akcji.get_child(1)
	if _rece_typ == "magazynek":
		# lewa trzyma magazynek pionowo, prawa wciska kolejne naboje (rytm kroku akcji)
		lewa.position = Vector3(-0.03, sin(t * 2.0) * 0.003, 0)
		lewa.rotation = Vector3(0.15, 0.25, 0.25)
		var f := fmod(t / 0.36, 1.0)
		var wcisk := sin(clampf(f / 0.5, 0.0, 1.0) * PI)
		prawa.position = Vector3(0.035 - wcisk * 0.02, 0.075 - wcisk * 0.03, 0.0)
		prawa.rotation = Vector3(0.3, -0.35, -0.5)
	else:
		# owijanie bandażem: prawa ręka krąży wokół lewego przedramienia
		lewa.position = Vector3(-0.04, -0.01, 0.0)
		lewa.rotation = Vector3(0.1, 0.5, 1.1)
		prawa.position = Vector3(-0.03 + cos(t * 6.0) * 0.04, 0.01 + sin(t * 6.0) * 0.025, sin(t * 6.0) * 0.02)
		prawa.rotation = Vector3(0.2, -0.4, -0.5 + sin(t * 6.0) * 0.3)


func _zbuduj_rece_akcji(typ: String) -> void:
	if _rece_akcji:
		_rece_akcji.queue_free()
	_rece_typ = typ
	_rece_akcji = Node3D.new()
	add_child(_rece_akcji)
	var lewa := Node3D.new()
	var prawa := Node3D.new()
	_rece_akcji.add_child(lewa)
	_rece_akcji.add_child(prawa)
	var dlon := [Vector3(0, 0, 0), Vector3(0.045, 0.045, 0.065), Modele.RUKAWICA]
	# rękawy opadają w dół i do tyłu, poza kadr
	var rek_l := [Vector3(-0.015, -0.07, 0.09), Vector3(0.055, 0.055, 0.2), Modele.RUKAW, Vector3(48, 12, 0)]
	var rek_p := [Vector3(0.015, -0.07, 0.09), Vector3(0.055, 0.055, 0.2), Modele.RUKAW, Vector3(48, -12, 0)]
	if typ == "magazynek":
		lewa.add_child(Kit.instancja([dlon, rek_l, [Vector3(0.0, 0.04, -0.005), Vector3(0.022, 0.075, 0.032), Modele.METAL_C]]))
		prawa.add_child(Kit.instancja([dlon, rek_p, [Vector3(-0.012, 0.028, -0.02), Vector3(0.009, 0.009, 0.024), Color(0.8, 0.6, 0.22)]]))
	else:
		lewa.add_child(Kit.instancja([dlon, rek_l, [Vector3(0.0, 0.0, 0.05), Vector3(0.058, 0.058, 0.05), Color(0.86, 0.83, 0.75)]]))
		prawa.add_child(Kit.instancja([dlon, rek_p, [Vector3(0.0, 0.025, -0.015), Vector3(0.028, 0.028, 0.045), Color(0.86, 0.83, 0.75)]]))
	for mi in _rece_akcji.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MeshInstance3D).material_override = Kit.material_kolor_vm()
