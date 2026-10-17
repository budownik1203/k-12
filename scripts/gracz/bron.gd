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
		model = Node3D.new()
		add_child(model)
		model.add_child(Kit.instancja(md["cialo"]))
		mag_node = Node3D.new()
		model.add_child(mag_node)
		if not md["mag"].is_empty():
			mag_node.add_child(Kit.instancja(md["mag"]))
		# prawa ręka na stałe przy chwycie, lewa jako osobny węzeł (animowana przy przeładowaniu)
		var rece: Array = Modele.rece(md["przod"], bd["slot"] == "pistolet", latarka_w_rece)
		model.add_child(Kit.instancja(rece.slice(0, 2)))
		_lewa = null
		if rece.size() > 2:
			_lewa = Node3D.new()
			_lewa.add_child(Kit.instancja(rece.slice(2)))
			model.add_child(_lewa)
		if latarka_w_rece:
			# chwyt Harriesa: latarka pod pistoletem, nadgarstki skrzyżowane
			_lat_node = _wezel_latarki()
			_lat_node.position = Vector3(-0.02, -0.075, 0.02)
			_lat_node.rotation = Vector3(0.03, 0.0, 0)
			model.add_child(_lat_node)
		# płomień wylotowy: dwa skrzyżowane czworokąty widoczne przez ułamek sekundy
		_blysk = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.05, 0.05) if bd["slot"] == "pistolet" else Vector2(0.075, 0.075)
		_blysk.mesh = q
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(1.0, 0.72, 0.32)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.no_depth_test = true
		_blysk.material_override = mat
		_blysk.position = Vector3(md["lufa"]) + Vector3(0, 0, -0.07)
		_blysk.visible = false
		_blysk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(_blysk)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi == _blysk or mi == _szklo:
			continue
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MeshInstance3D).material_override = Kit.material_kolor_vm()
	_odswiez_mag()
	stan = "wyciaganie"
	stan_t = 0.0
	stan_total = 0.45
	zmiana.emit()


var _szklo: MeshInstance3D
var _lewa: Node3D
var _bieg := 0.0
var _byl_pusty := false


func _wezel_latarki() -> Node3D:
	var n := Node3D.new()
	n.add_child(Kit.instancja(Modele.latarka() + Modele.reka_z_latarka()))
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
	if _lat_node == null or not is_instance_valid(_lat_node):
		return Transform3D(kamera.global_basis, kamera.global_position)
	var b := _lat_node.global_basis.orthonormalized()
	return Transform3D(b, _lat_node.global_transform * Vector3(0, 0, -0.15))


func swiecenie_szkla(wl: bool) -> void:
	if _szklo:
		(_szklo.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.95, 0.78) if wl else Color(0.25, 0.25, 0.22)


## Animacja rąk przy akcji gracza (leczenie, napełnianie magazynków); "" kończy.
func animacja_akcji(nazwa: String) -> void:
	if nazwa != "" and nazwa != "schowaj" and nazwa != _rece_typ:
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
		if _byl_pusty and f > 0.84 and f < 0.95:
			# zamek: szarpnięcie broni przy przeładowaniu z pustą komorą
			_kick_rot.z += 0.012
			_kick.z += 0.002
	if f < 0.7:
		_wcisniety = false
	if mag_node:
		mag_node.position = mag
	if _lewa:
		_lewa.position = reka - p_przod if not jest_pistolet() else (reka - p_przod) * 0.7


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
	ads = move_toward(ads, 1.0 if (we.get("ads", false) and moze and stan == "gotowa") else 0.0, delta * 6.0)
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
	_kick += Vector3(randf_range(-0.006, 0.006), 0.012, 0.07 + sila * 0.016)
	_kick_rot += Vector3(deg_to_rad(6.0 + sila * 2.0), randf_range(-0.04, 0.04), randf_range(-0.05, 0.05))
	var wylot := model.global_transform * Vector3(md["lufa"])
	Efekty.blysk(gracz.get_parent(), wylot, 3.0 if bd["slot"] == "pistolet" else 4.0)
	if _blysk:
		_blysk.visible = true
		_blysk.rotation.z = randf() * TAU
		# przy celowaniu płomień jest tuż przed okiem: mały i krótki, żeby nie zasłaniał celu
		_blysk.scale = Vector3.ONE * randf_range(0.8, 1.2) * lerpf(1.0, 0.35, ads)
		_blysk_t = 0.03
	if not bd.has("wewnetrzny"):
		Efekty.luska(gracz.get_parent(), model.global_transform * Vector3(0.03, 0.05, -0.06), kamera.global_basis.x)
	if gracz.has_method("kopniecie"):
		gracz.kopniecie(sila)
	var halas := 26.0
	match bd["kaliber"]:
		"7.62x39": halas = 36.0
		"12/70": halas = 32.0
	Gra.emituj_halas(gracz.global_position, halas, gracz)
	var dzw := {"9x18": "strzal_pistolet", "7.62x39": "strzal_karabin", "12/70": "strzal_strzelba"}
	var nazwa_dzw: String = dzw.get(bd["kaliber"], "strzal_pistolet")
	Dzwiek.graj(nazwa_dzw, -1.0)
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


func _process(delta: float) -> void:
	_anim_akcji_t += delta
	_opusc = move_toward(_opusc, 1.0 if _anim_akcji != "" else 0.0, delta * 4.0)
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
	var hip := Vector3(0.16, -0.18, -0.42) if not pistolet else Vector3(0.13, -0.15, -0.4)
	if przedmiot == null:
		hip = Vector3(-0.07, -0.17, -0.36)
	var celownik := float(md["celownik"])
	var ads_poz := Vector3(0.0, -celownik, -0.24 if not pistolet else -0.3)
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
	model.position = poz
	model.rotation = rot
	model.visible = _opusc < 0.95
	# snop latarki z soczewki, po ustawieniu modelu w tej klatce (bez opóźnienia)
	if _lat_node and gracz and gracz.get("latarka") and gracz.latarka.visible:
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
