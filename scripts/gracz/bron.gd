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

var _kick := Vector3.ZERO
var _kick_rot := Vector3.ZERO
var _sway := Vector2.ZERO
var _bob := 0.0
var _ruch := 0.0


func _ready() -> void:
	scale = Vector3.ONE * SKALA


func ustaw(p: Przedmiot) -> void:
	przedmiot = p
	if model:
		model.queue_free()
		model = null
		mag_node = null
	stan = "gotowa"
	job = {}
	if p == null:
		bd = {}
		zmiana.emit()
		return
	bd = p.defn()["bron"]
	md = Modele.bron(p.id)
	model = Node3D.new()
	add_child(model)
	model.add_child(Kit.instancja(md["cialo"]))
	mag_node = Node3D.new()
	model.add_child(mag_node)
	if not md["mag"].is_empty():
		mag_node.add_child(Kit.instancja(md["mag"]))
	model.add_child(Kit.instancja(Modele.rece(md["przod"], bd["slot"] == "pistolet")))
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MeshInstance3D).material_override = Kit.material_kolor_vm()
	_odswiez_mag()
	stan = "wyciaganie"
	stan_t = 0.0
	stan_total = 0.45
	zmiana.emit()


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
	cooldown = maxf(0.0, cooldown - delta)
	bloom = maxf(0.0, bloom - delta * 2.5)
	var moze: bool = we.get("moze", true) and przedmiot != null
	ads = move_toward(ads, 1.0 if (we.get("ads", false) and moze and stan == "gotowa") else 0.0, delta * 6.0)
	if przedmiot == null:
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
	var baza: float = lerpf(float(bd["rozrzut_biodro"]), float(bd["rozrzut_ads"]), ads)
	var kat: float = baza * (1.0 + _ruch * 1.4) * lerpf(1.0, 0.8, we.get("kucanie", 0.0)) * we.get("celnosc", 1.0) + bloom
	var space := kamera.get_world_3d().direct_space_state
	var od := kamera.global_position
	var przod := -kamera.global_basis.z
	var obr := float(ad["obrazenia"]) * float(bd.get("mnoznik", 1.0))
	for i in srut:
		var kier := Balistyka.rozrzut(przod, kat)
		if srut > 1:
			kier = Balistyka.rozrzut(kier, float(bd.get("rozrzut_srutu", 3.0)))
		_promien(space, od, kier, obr, float(ad["penetracja"]))
	# odrzut
	var sila: float = float(bd["odrzut"]) * lerpf(1.0, 0.65, ads) * lerpf(1.0, 0.85, float(we.get("kucanie", 0.0))) * float(we.get("celnosc", 1.0))
	if gracz.has_method("dodaj_odrzut"):
		gracz.dodaj_odrzut(Vector2(randf_range(-0.35, 0.35) * sila, sila))
	if _tryb() == "auto":
		bloom = minf(bloom + 0.35, 3.0)
	_kick += Vector3(randf_range(-0.004, 0.004), 0.01, 0.05 + sila * 0.012)
	_kick_rot += Vector3(deg_to_rad(4.0 + sila * 1.5), randf_range(-0.02, 0.02), 0)
	var wylot := model.global_transform * Vector3(md["lufa"])
	Efekty.blysk(gracz.get_parent(), wylot, 3.0)
	var halas := 32.0
	match bd["kaliber"]:
		"7.62x39": halas = 46.0
		"12/70": halas = 40.0
	Gra.emituj_halas(gracz.global_position, halas, gracz)
	var dzw := {"9x18": "strzal_pistolet", "7.62x39": "strzal_karabin", "12/70": "strzal_strzelba"}
	Dzwiek.graj(dzw.get(bd["kaliber"], "strzal_pistolet"), -2.0)
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
			return
	var swiat := gracz.get_parent() as Node3D
	Efekty.slad(swiat, r["position"], r["normal"])
	Efekty.czastki(swiat, r["position"], r["normal"], Color(0.5, 0.48, 0.44), 7)
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


func _process(delta: float) -> void:
	if model == null:
		return
	var pistolet := jest_pistolet()
	var hip := Vector3(0.16, -0.18, -0.42) if not pistolet else Vector3(0.13, -0.15, -0.4)
	var celownik := float(md["celownik"])
	var ads_poz := Vector3(0.0, -celownik, -0.24 if not pistolet else -0.3)
	var t := ads * ads * (3.0 - 2.0 * ads)
	_bob += delta * (6.5 * _ruch)
	var bob := Vector3(sin(_bob) * 0.008, absf(cos(_bob)) * -0.01, 0) * _ruch * (1.0 - t * 0.85)
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
			dip = sin(f * PI)
			rot += Vector3(-0.35, 0.25, 0.6) * dip
			poz += Vector3(-0.03, -0.05, 0.03) * dip
			if mag_node:
				var m := 0.0
				if f < 0.5:
					m = f / 0.5
				else:
					m = 1.0 - (f - 0.5) / 0.5
				mag_node.position = Vector3(0, -0.25 * m, 0.05 * m)
				mag_node.visible = true
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
	if stan != "przeladowanie" and mag_node:
		mag_node.position = Vector3.ZERO
		_odswiez_mag()
	model.position = poz
	model.rotation = rot
