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
var zamroz := false          # testy: czas stanu ustawiany ręcznie (klatki animacji)

var latarka_w_rece := false
var _lat_node: Node3D
var _blysk: MeshInstance3D
var _blysk_t := 0.0
var _anim_akcji := ""          # "leczenie" | "magazynek" | "" – animacja rąk przy akcjach gracza
var _anim_akcji_t := 0.0
var _kick := Vector3.ZERO
var _kick_rot := Vector3.ZERO
var _kick_v := Vector3.ZERO          # sprężyna odrzutu: prędkości (broń szarpnięta i wracająca z lekkim przestrzeleniem)
var _kick_rot_v := Vector3.ZERO
var _seria := 0                      # strzały w bieżącej serii (wzór odrzutu)
var _seria_t := 0.0
var _kurz_strzaly := 0.0        # strzały w ostatnich sekundach (zanika) – seria w ciasnym pokoju wzbija kurz
var _kurz_cd := 0.0
var _sway := Vector2.ZERO
var _bob := 0.0
var _ruch := 0.0


func _ready() -> void:
	scale = Vector3.ONE * SKALA


## Ustawia broń w rękach. latarka: lewa ręka trzyma latarkę (z pistoletem albo sama, gdy p == null).
func ustaw(p: Przedmiot, latarka := false) -> void:
	var chowaj := model != null and is_instance_valid(model) and model.visible and p != przedmiot and not ogladanie
	przedmiot = p
	if model:
		if chowaj:
			# zmiana broni: stara schodzi w dół poza kadr, nowa wyjmowana dopiero po chwili
			var stary := model
			var tw := stary.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(stary, "position", stary.position + Vector3(0.04, -0.32, 0.08), 0.22)
			tw.tween_property(stary, "rotation", stary.rotation + Vector3(-0.9, 0.3, 0.4), 0.22)
			tw.chain().tween_callback(stary.queue_free)
		else:
			model.queue_free()
		model = null
		mag_node = null
		_lat_node = null
		_blysk = null
		_lewa = null
		_szklo = null
	_reka_p = null
	_reka_l = null
	_chor = null
	_chor_wezly.clear()
	_ruchome.clear()
	_luska_reka = null
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
		# części ruchome: zamek / rączka zamka (odskok, blokada w tyle), lufy obrzyna (łamane na zawiasie)
		_ruchome.clear()
		var ruch: Dictionary = md.get("ruchome", {})
		for nazwa in ruch:
			var r: Dictionary = ruch[nazwa]
			var wezel := Node3D.new()
			var zaw: Vector3 = r.get("zawias", Vector3.ZERO)
			wezel.position = zaw
			model.add_child(wezel)
			var mi := Bryly.instancja(r["czesci"])
			mi.position = -zaw
			wezel.add_child(mi)
			_ruchome[nazwa] = {"wezel": wezel, "dane": r}
		_luska_reka = null
		if not dod_bryly.is_empty():
			model.add_child(Bryly.instancja(dod_bryly))
		if _szklo_broni_poz != Vector3.ZERO and p.dodatek("latarka") != null:
			# szkło latarki taktycznej: jasne, świeci przy włączonej latarce
			var sz := Kit.instancja([[_szklo_broni_poz, Vector3(0.017, 0.017, 0.002), Color(1.0, 0.95, 0.8)]])
			var szm := StandardMaterial3D.new()
			szm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			szm.albedo_color = Color(1.0, 0.95, 0.8)
			sz.material_override = szm
			sz.set_meta("bryly", true)
			model.add_child(sz)
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
			_lat_node.position = LAT_HARRIS
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
	stan_t = -0.35 if chowaj else 0.0
	stan_total = 0.75 if p and p.defn().get("bron", {}).get("slot", "") == "glowna" else 0.55
	if ogladanie:
		stan = "gotowa"
	zmiana.emit()


var _szklo: MeshInstance3D
const LAT_HARRIS := Vector3(-0.02, -0.075, 0.02)   # latarka pod pistoletem (chwyt Harriesa)


## Chwyt Harriesa: lewa dłoń trzyma latarkę, więc to ona (z latarką w garści) sięga po magazynek,
## podsuwa go do chwytu i wraca pod pistolet – snop przy tym ucieka w dół.
func _lat_za_reka(off: Vector3) -> void:
	if _lewa != null or not latarka_w_rece or _lat_node == null or not is_instance_valid(_lat_node):
		return
	_lat_node.position = LAT_HARRIS + off
	var w := clampf(off.length() / 0.25, 0.0, 1.0)
	_lat_node.rotation = Vector3(0.03 - 0.9 * w, 0.35 * w, 0.0)
var _kropka_poz := Vector3.ZERO
var _lat_bron_poz := Vector3.ZERO    # soczewka latarki na broni (współrzędne modelu)
var _bez_plomienia := false
var _montaz := 0.0
var _lewa: Node3D
var _bieg := 0.0
var _byl_pusty := false


## Dodatki zamontowane na broni: zmieniają punkty modelu (wylot, linia celowania, chwyt lewej ręki)
## i zwracają bryły do dorysowania.
var ogladanie := false            # podgląd broni z bliska (dodatki, montaż)
var ogl_obrot := Vector2.ZERO      # obrót podglądu myszą
var _ogl := 0.0
var _ukryj_slot := ""              # dodatek chwilowo niewidoczny (zdejmowany w animacji)
var _mont := {}                    # animacja montażu w podglądzie: {"wezel", "punkt", "slot", "zdejmij", "start"}


func _dod(p: Przedmiot, slot: String) -> Przedmiot:
	return null if slot == _ukryj_slot else p.dodatek(slot)


## Punkt montażu slotu na bazowym modelu broni (bez dodatków).
func _punkt_montazu(slot: String) -> Vector3:
	var baza := Modele.bron(przedmiot.id)
	var mont: Dictionary = baza.get("montaz", {})
	match slot:
		"wylot":
			return Vector3(baza["lufa"])
		"celownik":
			return mont.get("celownik", Vector3(0, 0.08, -0.1))
		"chwyt":
			return mont.get("chwyt", Vector3(0, 0.0, -0.3))
	return mont.get("latarka", Vector3(0.03, 0.03, -0.3))


## Bryły jednego dodatku (do animacji montażu) – liczone na świeżym modelu, bez zmiany stanu broni.
func _bryly_dodatku(dod: Przedmiot) -> Array:
	var kopia := [md, _kropka_poz, _lat_bron_poz, _szklo_broni_poz, _bez_plomienia, _ukryj_slot]
	var slot: String = dod.defn()["dodatek"]["slot"]
	var fake := Przedmiot.nowy(przedmiot.id)
	fake.dane["dod_" + slot] = dod
	md = Modele.bron(przedmiot.id)
	_ukryj_slot = ""
	var cz := _zastosuj_dodatki(fake)
	md = kopia[0]
	_kropka_poz = kopia[1]
	_lat_bron_poz = kopia[2]
	_szklo_broni_poz = kopia[3]
	_bez_plomienia = kopia[4]
	_ukryj_slot = kopia[5]
	return cz


func _zacznij_montaz_podglad(dod: Przedmiot, zdejmij: bool) -> void:
	_konczy_montaz_podglad()
	var slot: String = dod.defn()["dodatek"]["slot"]
	if zdejmij:
		# zdejmowany dodatek znika z modelu – zastępuje go ruchoma kopia w dłoni
		_ukryj_slot = slot
		ustaw(przedmiot, latarka_w_rece)
	var punkt := _punkt_montazu(slot)
	var piv := Node3D.new()
	piv.position = punkt
	model.add_child(piv)
	var mi := Bryly.instancja(_bryly_dodatku(dod))
	mi.position = -punkt
	piv.add_child(mi)
	var start: Vector3 = {"wylot": Vector3(0.0, -0.12, 0.12), "celownik": Vector3(-0.02, 0.16, 0.08), "chwyt": Vector3(0.0, -0.18, 0.06)}.get(slot, Vector3(0.12, -0.1, 0.06))
	_mont = {"wezel": piv, "punkt": punkt, "slot": slot, "zdejmij": zdejmij, "start": start}


func _konczy_montaz_podglad() -> void:
	if not _mont.is_empty() and is_instance_valid(_mont["wezel"]):
		(_mont["wezel"] as Node3D).queue_free()
	_mont = {}
	if _ukryj_slot != "":
		_ukryj_slot = ""
		if przedmiot:
			ustaw(przedmiot, latarka_w_rece)


func _animuj_montaz_podglad() -> void:
	if _mont.is_empty() or gracz == null or gracz.akcja.is_empty():
		return
	var a: Dictionary = gracz.akcja
	var f := clampf(float(a["t"]) / maxf(0.01, float(a["czas"])), 0.0, 1.0)
	if _mont["zdejmij"]:
		f = 1.0 - f
	var piv: Node3D = _mont["wezel"]
	var slot: String = _mont["slot"]
	var off := Vector3.ZERO
	var obr := 0.0
	if f < 0.55:
		off = (_mont["start"] as Vector3) * (1.0 - smoothstep(0.0, 0.55, f))
	elif f < 0.92:
		var t := (f - 0.55) / 0.37
		if slot == "wylot":
			obr = (1.0 - t) * TAU * 1.5            # nakręcanie gwintu
		else:
			off = Vector3(0, 0, 0.04) * (1.0 - smoothstep(0.0, 1.0, t))   # wsuwanie na szynę / zatrzask
	piv.position = Vector3(_mont["punkt"]) + off
	piv.rotation = Vector3(0, 0, obr)
	if _lewa:
		var loz: Vector3 = md.get("lozysko", md["przod"])
		_lewa.position = piv.position - loz + Vector3(-0.01, -0.03, 0.03)
	if _reka_l and is_instance_valid(_reka_l):
		_reka_l.ustaw_chwyt("szczypta" if slot == "wylot" else "magazynek")


func _zastosuj_dodatki(p: Przedmiot) -> Array:
	md = md.duplicate(true)
	_kropka_poz = Vector3.ZERO
	_lat_bron_poz = Vector3.ZERO
	_szklo_broni_poz = Vector3.ZERO
	_bez_plomienia = false
	var B := Bryly
	var cz := []
	var mont: Dictionary = md.get("montaz", {})
	var lufa: Vector3 = Vector3(md["lufa"])
	# wylot: tłumik (walec z pierścieniami i czołem) albo hamulec (krótki, z oknami)
	var w := _dod(p, "wylot")
	if w:
		var dd: Dictionary = w.defn()["dodatek"]
		var dl := float(dd.get("dl", 0.1))
		var r := float(dd.get("gr", 0.035)) * 0.5
		var a := lufa + Vector3(0, 0, 0.012)
		var b := lufa + Vector3(0, 0, -dl)
		if w.id == "hamulec":
			cz.append(B.walec(a, b, r, r * 0.95, "metal", 10))
			for zz in [0.02, 0.036]:
				for sx in [-1.0, 1.0]:
					cz.append(B.box(lufa + Vector3(sx * r * 0.8, 0.0, -zz), Vector3(r * 0.5, r * 0.9, 0.007), "czern", 0.0))
			cz.append(B.walec(b, b + Vector3(0, 0, -0.002), r * 0.55, r * 0.55, "czern", 8))
		else:
			cz.append(B.walec(a, a + Vector3(0, 0, -0.025), r * 0.75, r, "metal", 12))
			cz.append(B.walec(a + Vector3(0, 0, -0.025), b + Vector3(0, 0, 0.012), r, r, "metal", 12))
			cz.append(B.walec(b + Vector3(0, 0, 0.012), b, r, r * 0.8, "metal", 12))
			for i in 3:
				var zz := lerpf(a.z - 0.04, b.z + 0.03, float(i) / 2.0)
				cz.append(B.walec(Vector3(a.x, a.y, zz + 0.003), Vector3(a.x, a.y, zz - 0.003), r + 0.0012, r + 0.0012, "metal", 12))
			cz.append(B.walec(b, b + Vector3(0, 0, -0.002), r * 0.35, r * 0.35, "czern", 8))
		_bez_plomienia = not bool(dd.get("plomien", true))
		md["lufa"] = b
	# celownik na szynie bocznej/górnej: kolimator (okienko z kropką) albo luneta PSO (tuba z muszlą)
	var c := _dod(p, "celownik")
	if c and mont.has("celownik"):
		var dd2: Dictionary = c.defn()["dodatek"]
		var baza: Vector3 = mont["celownik"]
		var os_y := baza.y + float(dd2.get("wys", 0.04))
		var z0 := baza.z
		# montaż: płytka na pokrywie + słupek
		cz.append(B.box(Vector3(0, baza.y + 0.004, z0), Vector3(0.03, 0.008, 0.07), "metal", 0.002))
		if c.id == "kolimator":
			cz.append(B.profil([Vector2(z0 + 0.028, baza.y + 0.008), Vector2(z0 + 0.022, os_y - 0.012), Vector2(z0 - 0.022, os_y - 0.012), Vector2(z0 - 0.028, baza.y + 0.008)], 0.026, "metal", 0.004))
			# okienko: ramka z czterech belek wokół osi
			var rr := 0.017
			cz.append(B.box(Vector3(0, os_y + rr, z0 - 0.008), Vector3(0.04, 0.005, 0.03), "metal", 0.002))
			cz.append(B.box(Vector3(0, os_y - rr, z0 - 0.008), Vector3(0.04, 0.005, 0.03), "metal", 0.002))
			cz.append(B.box(Vector3(-rr - 0.002, os_y, z0 - 0.008), Vector3(0.005, rr * 2.0 + 0.005, 0.03), "metal", 0.002))
			cz.append(B.box(Vector3(rr + 0.002, os_y, z0 - 0.008), Vector3(0.005, rr * 2.0 + 0.005, 0.03), "metal", 0.002))
			cz.append(B.walec(Vector3(rr + 0.004, os_y + 0.006, z0), Vector3(rr + 0.01, os_y + 0.006, z0), 0.005, 0.005, "metal_jasny", 8))
			_kropka_poz = Vector3(0, os_y, z0 - 0.02)
		else:
			cz.append(B.box(Vector3(0, (baza.y + os_y) * 0.5, z0 + 0.03), Vector3(0.012, os_y - baza.y, 0.014), "metal", 0.002))
			cz.append(B.box(Vector3(0, (baza.y + os_y) * 0.5, z0 - 0.03), Vector3(0.012, os_y - baza.y, 0.014), "metal", 0.002))
			cz.append(B.walec(Vector3(0, os_y, z0 + 0.06), Vector3(0, os_y, z0 - 0.07), 0.0135, 0.0135, "metal", 12))
			cz.append(B.walec(Vector3(0, os_y, z0 - 0.07), Vector3(0, os_y, z0 - 0.1), 0.0135, 0.019, "metal", 12))
			cz.append(B.walec(Vector3(0, os_y, z0 - 0.1), Vector3(0, os_y, z0 - 0.112), 0.019, 0.019, "metal", 12))
			cz.append(B.walec(Vector3(0, os_y, z0 + 0.06), Vector3(0, os_y, z0 + 0.085), 0.0135, 0.017, "metal", 12))
			cz.append(B.walec(Vector3(0, os_y, z0 + 0.085), Vector3(0, os_y, z0 + 0.105), 0.017, 0.017, "bakelit", 12))
			cz.append(B.walec(Vector3(0, os_y + 0.012, z0), Vector3(0, os_y + 0.024, z0), 0.007, 0.007, "metal", 8))
			cz.append(B.walec(Vector3(0.012, os_y, z0 - 0.01), Vector3(0.024, os_y, z0 - 0.01), 0.007, 0.007, "metal", 8))
		md["celownik"] = os_y
		md["luneta"] = c.id == "luneta"
	# chwyt przedni pod łożem: lewa dłoń przechodzi na chwyt pionowy
	var ch := _dod(p, "chwyt")
	if ch and mont.has("chwyt"):
		var pz: Vector3 = mont["chwyt"]
		cz.append(B.box(pz + Vector3(0, -0.004, 0), Vector3(0.03, 0.012, 0.05), "metal", 0.003))
		cz.append(B.profil([Vector2(pz.z + 0.018, pz.y - 0.008), Vector2(pz.z + 0.022, pz.y - 0.08), Vector2(pz.z + 0.008, pz.y - 0.092),
			Vector2(pz.z - 0.018, pz.y - 0.088), Vector2(pz.z - 0.016, pz.y - 0.008)], 0.028, "bakelit", 0.009))
		md["chwyt_pionowy"] = pz + Vector3(0, -0.05, 0.002)
		md["przod"] = pz + Vector3(0, -0.05, 0.0)
	# latarka taktyczna z boku łoża (albo pod szkieletem pistoletu / pod lufami)
	var lt := _dod(p, "latarka")
	if lt:
		var lp: Vector3 = mont.get("latarka", lufa + Vector3(0.024, -0.022, 0.12))
		var pod: bool = mont.get("latarka_pod", false)
		var uchwyt := Vector3(0, 0.014, 0) if pod else Vector3(-0.012, 0, 0)
		cz.append(B.box(lp + uchwyt, Vector3(0.012 if not pod else 0.02, 0.01 if not pod else 0.008, 0.03), "metal", 0.002))
		cz.append(B.walec(lp + Vector3(0, 0, 0.035), lp + Vector3(0, 0, -0.025), 0.0105, 0.0105, "latarka", 10))
		cz.append(B.walec(lp + Vector3(0, 0, -0.025), lp + Vector3(0, 0, -0.04), 0.0105, 0.0135, "latarka", 10))
		cz.append(B.walec(lp + Vector3(0, 0, -0.04), lp + Vector3(0, 0, -0.042), 0.011, 0.011, "metal_jasny", 10))
		cz.append(B.box(lp + Vector3(0, 0.011, 0.02), Vector3(0.006, 0.004, 0.012), "bakelit", 0.001))
		_lat_bron_poz = lp + Vector3(0, 0, -0.045)
		_szklo_broni_poz = lp + Vector3(0, 0, -0.0425)
	return cz


var _szklo_broni_poz := Vector3.ZERO


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
var _reka_baza := Transform3D()      # spoczynkowa poza lewej dłoni (przestrzeń modelu)
var _lok_baza := Vector3.ZERO
var _chor: Choreografia = null       # bieżąca choreografia przeładowania / sprawdzania
var _chor_wezly: Array = []          # naboje, łuski, drugi magazynek – zwalniane po choreografii


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
		_lok_baza = Vector3(-0.14, -0.34, 0.4)
	elif md.has("chwyt_pionowy"):
		# chwyt przedni: lewa dłoń obejmuje go jak rękojeść pistoletu
		_reka_l.ustaw_chwyt("pistolet", true)
		_reka_l.chwyc(md["chwyt_pionowy"], Vector3(0, -1, 0.1), Vector3(1, 0, 0), 0.07)
		_lok_baza = Vector3(md["chwyt_pionowy"]) + Vector3(-0.2, -0.3, 0.3)
	else:
		var przod: Vector3 = md.get("lozysko", md["przod"])
		_reka_l.chwyc(przod, Vector3(0, 0, 1), Vector3(0.15, 1.0, 0.0), 0.062, 0.042)
		_lok_baza = przod + Vector3(-0.22, -0.3, 0.28)
	_reka_l.celuj_lokiec(_lok_baza, model)
	_reka_baza = _reka_l.transform


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
	if nazwa == "montaz" and ogladanie and gracz and gracz.akcja.has("dod"):
		_zacznij_montaz_podglad(gracz.akcja["dod"], bool(gracz.akcja.get("zdejmij", false)))
	elif nazwa == "" and not _mont.is_empty():
		_konczy_montaz_podglad()
	if nazwa != "" and nazwa != "schowaj" and nazwa != "montaz":
		# osobna animacja dla każdej czynności (lek / magazynek), rekwizyty z modeli
		if _anim_cz:
			_anim_cz.queue_free()
		_anim_cz = AnimacjeAkcji.new()
		_anim_cz.gracz = gracz
		add_child(_anim_cz)
		var a: Dictionary = gracz.akcja if gracz else {}
		var t := nazwa.trim_prefix("leczenie_") if nazwa.begins_with("leczenie") else nazwa
		if t == "leczenie":
			t = "apteczka"
		_anim_cz.zbuduj(t, String(a.get("id", "")), String(a.get("amun", "")))
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
	if not job.is_empty() and gracz and job.get("siatka") == gracz.ekw.kieszenie:
		kamizelka = chwyt + Vector3(-0.12, -0.5, 0.2)        # niżej: kieszeń spodni
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
			# pusta komora: lewa dłoń sięga do rączki zamka po prawej stronie i przeciąga ją do tyłu;
			# dłoń obraca się wnętrzem do broni (chwyt rączki z boku, nie od spodu)
			var raczka := Vector3(0.062, 0.018, -0.085) + (p_przod - Vector3(md.get("lozysko", p_przod)))
			var t := (f - 0.78) / 0.22
			_roll_l = 1.45 * smoothstep(0.05, 0.3, t) * (1.0 - smoothstep(0.62, 0.9, t))
			if t < 0.35:
				reka = chwyt.lerp(raczka, smoothstep(0.0, 0.35, t))
			elif t < 0.6:
				reka = raczka + Vector3(0, 0, 0.07) * smoothstep(0.35, 0.5, t)
				_raczka = smoothstep(0.35, 0.5, t) if t < 0.56 else 0.0
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
	if f < 0.78 or f > 0.99:
		_raczka = 0.0
	if mag_node:
		mag_node.position = mag
	if not (_byl_pusty and not jest_pistolet() and f >= 0.78):
		_roll_l = move_toward(_roll_l, 0.0, 0.2)
	_lat_za_reka((reka - p_przod) * 0.7)
	if _lewa:
		if jest_pistolet():
			_lewa.position = (reka - p_przod) * 0.7
		else:
			# obrót dłoni wokół punktu chwytu (osi lufy)
			var g: Vector3 = Vector3(md.get("lozysko", p_przod))
			var rb := Basis(Vector3(0, 0, 1), _roll_l)
			_lewa.basis = rb
			_lewa.position = (reka - p_przod + g) - rb * g
			# łokieć idzie za dłonią: przy rączce zamka (prawa strona) niżej i bardziej w prawo
			if _reka_l and is_instance_valid(_reka_l) and not md.has("chwyt_pionowy"):
				var w := clampf(_roll_l / 1.45, 0.0, 1.0)
				var lok_dom := g + Vector3(-0.22, -0.3, 0.28)
				var lok_racz := (reka - p_przod + g) + Vector3(0.05, -0.3, 0.24)
				_reka_l.celuj_lokiec(lok_dom.lerp(lok_racz, w), model)
	# palce lewej dłoni: otwarta przy sięganiu, zaciśnięta na magazynku, chwyt rączki zamka, powrót na łoże
	if _lewa and _reka_l and is_instance_valid(_reka_l):
		var poza := "pistolet" if (jest_pistolet() or md.has("chwyt_pionowy")) else "lozysko"
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
var _roll_l := 0.0


func _animuj_ladowanie_naboju(f: float) -> void:
	if _lewa == null:
		return
	var p_przod: Vector3 = Vector3(md["przod"])
	var kieszen := p_przod + Vector3(-0.12, -0.36, 0.26)
	var komora := Vector3(0.0, 0.075, -0.03)
	var reka := p_przod
	var poza := "otwarta"
	var naboj := false
	if f < 0.38:
		reka = (p_przod if f < 0.05 else komora).lerp(kieszen, smoothstep(0.0, 0.38, f))
	elif f < 0.78:
		reka = kieszen.lerp(komora + Vector3(0, 0.03, 0.03), smoothstep(0.38, 0.78, f))
		poza = "magazynek"
		naboj = f > 0.42
	elif f < 0.92:
		reka = (komora + Vector3(0, 0.03, 0.03)).lerp(komora, smoothstep(0.78, 0.92, f))
		poza = "magazynek"
		naboj = true
	else:
		reka = komora
	_lewa.position = reka - p_przod
	if _reka_l and is_instance_valid(_reka_l):
		_reka_l.ustaw_chwyt(poza)
	if _luska_reka == null or not is_instance_valid(_luska_reka):
		_luska_reka = Bryly.instancja([
			Bryly.walec(Vector3(0, 0, 0.0), Vector3(0, 0, -0.05), 0.0105, 0.0105, "bakelit", 8),
			Bryly.walec(Vector3(0, 0, 0.0), Vector3(0, 0, 0.012), 0.0112, 0.0112, "metal_jasny", 8),
		])
		_luska_reka.material_override = null
		model.add_child(_luska_reka)
	_luska_reka.visible = naboj
	_luska_reka.position = reka + Vector3(0.0, 0.012, 0.0)
	_luska_reka.rotation = Vector3(0.5, 0, 0)


## H: spojrzenie na zegarek – broń w dół, lewy nadgarstek przed oczy (zdrowie na tarczy).
func _animuj_zegarek(delta: float) -> void:
	var chce: bool = Input.is_action_pressed("zegarek") and gracz != null and bool(gracz.get("sterowanie")) and not Sterowanie.blokada
	_zegarek = move_toward(_zegarek, 1.0 if chce else 0.0, delta * 4.0)
	if _zegarek <= 0.001:
		if _reka_zeg and is_instance_valid(_reka_zeg):
			_reka_zeg.visible = false
		return
	if _reka_zeg == null or not is_instance_valid(_reka_zeg):
		_reka_zeg = Reka.new(false, true, "magazynek", 0.5)
		add_child(_reka_zeg)
		# wnętrze nadgarstka (z tarczą) do oczu, palce luźno w prawo
		var zl := Vector3(-0.9, -0.38, -0.2).normalized()
		var yl := Vector3(0.1, -0.15, -1).normalized()
		yl = (yl - zl * yl.dot(zl)).normalized()
		var xl := yl.cross(zl).normalized()
		_reka_zeg.basis = Basis(xl, yl, zl)
		_reka_zeg.celuj_lokiec(Vector3(-0.3, -0.5, 0.05), self)
	_reka_zeg.visible = true
	var e := _zegarek * _zegarek * (3.0 - 2.0 * _zegarek)
	_reka_zeg.position = Vector3(-0.12, -0.42, -0.25).lerp(Vector3(-0.02, -0.1, -0.3), e)
	if gracz and gracz.get("cialo"):
		_reka_zeg.ustaw_zdrowie(gracz.cialo.procent(), gracz.cialo.krwawi() > 0)


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
	_seria_t += delta
	_kurz_strzaly = maxf(0.0, _kurz_strzaly - delta * 1.2)
	_kurz_cd = maxf(0.0, _kurz_cd - delta)
	if _seria_t > 0.32:
		_seria = 0
	var moze: bool = we.get("moze", true) and przedmiot != null and sciana < 0.6 and _bieg < 0.35
	# złożenie do strzału: ciężka broń wolniej (ok. 0,3 s pistolet, 0,4 s karabin z dodatkami)
	var ciez_ads := clampf(przedmiot.waga() / 3.0, 0.6, 1.5) if przedmiot else 1.0
	ciez_ads *= lerpf(0.85, 1.7, _nisko_f)     # z broni nisko złożenie trwa dłużej
	ads = move_toward(ads, 1.0 if (we.get("ads", false) and moze and stan == "gotowa") else 0.0, delta * 4.2 / (ciez_ads * (1.0 + (zoom() - 1.0) * 0.35)))
	if przedmiot == null:
		# sama latarka: tylko animacja wyjmowania
		if stan != "gotowa":
			stan_t += delta
			_graj_fazy()
			if stan_t >= stan_total:
				stan = "gotowa"
				_fazy_dzw = []
		return
	# stany czasowe
	if stan != "gotowa":
		if not zamroz:
			stan_t += delta
		_graj_fazy()
		if _chor:
			_chor.aktualizuj(minf(stan_t, stan_total))
		if stan == "ladowanie_wewn" and we.get("strzal", false):
			_koniec_stanu()  # przerwanie ładowania strzelby strzałem
		elif stan == "lamanie" and we.get("strzal", false) and spust_puszczony and _chor:
			# strzał w trakcie: naboje z dłoni z powrotem, od razu zamknięcie luf
			var iz := _chor.indeks("zamknij_chwyt")
			if iz > _chor.biezacy():
				stan_t = _chor.skocz(iz)
			spust_puszczony = false
		elif stan_t >= stan_total:
			_koniec_stanu()
		if not we.get("strzal", false):
			spust_puszczony = true
		return
	if not moze:
		spust_puszczony = not we.get("strzal", false)
		return
	# przeładowanie: krótkie wciśnięcie = zwykłe, przytrzymanie = szybkie z upuszczeniem magazynka
	# zacięcie: R usuwa je (przeciągnięcie zamka) zamiast przeładowania
	if przedmiot.dane.get("zaciecie", false) and we.get("przeladuj", false) and r_trzymany >= 0.0:
		stan = "usuwanie"
		stan_t = 0.0
		stan_total = 1.3
		_byl_pusty = true
		r_trzymany = -99.0
		_fazy_dzw = [[0.25, _zamek_dzw(), -5.0], [0.75, _zamek_dzw(), -6.0]]
		if _lewa and _reka_l:
			# choreografia: klepnięcie / rączka zamka (dźwięki w niej)
			_chor = Przeladowania.zaciecie(self)
			stan_total = _chor.calosc
			_fazy_dzw = []
		return
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
		Dzwiek.graj("przelacznik", -8.0)
		komunikat.emit("Tryb ognia: " + ("ogień ciągły" if bd["tryby"][przedmiot.dane["tryb"]] == "auto" else "pojedynczy"))
	if we.get("sprawdz", false):
		stan = "sprawdzanie"
		stan_t = 0.0
		stan_total = 1.8
		if _ruchome.has("lufy"):
			_chor = Przeladowania.obrzyn_sprawdz(self)
			stan_total = _chor.calosc
		elif przedmiot.dane.get("mag") != null and mag_node and _lewa:
			# zerknięcie na okienka magazynka
			_chor = Przeladowania.sprawdz_magazynek(self)
			stan_total = _chor.calosc
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
			d["luski"] = int(d.get("luski", 0)) + 1     # łuska zostaje w komorze do przeładowania
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
	if przedmiot.dane.get("zaciecie", false):
		if spust_puszczony:
			Dzwiek.graj("sucho", -4.0, 0.8)
			komunikat.emit("Zacięcie! [R] – przeciągnij zamek")
		spust_puszczony = false
		cooldown = 0.3
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
	var kat: float = baza * (1.0 + _ruch * 1.4) * lerpf(1.0, 0.8, we.get("kucanie", 0.0)) * we.get("celnosc", 1.0) * (1.0 + float(gracz.get("przygniecenie")) * 0.8) + bloom
	# zabrudzona lufa i luzy: brudna broń trochę rozrzuca
	kat *= 1.0 + (100.0 - float(przedmiot.dane.get("stan", 100.0))) / 260.0
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
	var sila: float = float(bd["odrzut"]) * przedmiot.mod("odrzut") * lerpf(1.0, 0.65, ads) * lerpf(1.0, 0.85, float(we.get("kucanie", 0.0))) * float(we.get("celnosc", 1.0)) * lerpf(1.0, 0.62, podparcie)
	# wzór odrzutu: w serii lufa idzie w górę i znosi ją w jedną stronę (do opanowania), trochę losowo
	var bok := 0.0
	match bd["kaliber"]:
		"7.62x39": bok = 0.22 + sin(_seria * 0.8) * 0.3
		"9x18": bok = sin(_seria * 1.3) * 0.35 - 0.05
		_: bok = 0.0
	if gracz.has_method("dodaj_odrzut"):
		gracz.dodaj_odrzut(Vector2((bok + randf_range(-0.18, 0.18)) * sila, sila * (1.0 + minf(_seria, 6) * 0.04)))
	_seria += 1
	_seria_t = 0.0
	_kurz_strzaly += 1.0 if not _bez_plomienia else 0.6
	# nagar i pył osiadają w mechanizmie: im więcej strzałów w rajdzie, tym brudniejsza wraca
	przedmiot.dane["brud_rajd"] = float(przedmiot.dane.get("brud_rajd", 0.0)) + 0.05
	if _kurz_strzaly > 7.0 and _kurz_cd <= 0.0 and Dzwiek.akustyka_fn.is_valid():
		var ak: Dictionary = Dzwiek.akustyka_fn.call(gracz.global_position)
		var pole := float(ak.get("pole", 400.0))
		if String(ak.get("typ", "")) != "zewnatrz" and pole < 70.0:
			_kurz_cd = 4.0
			przedmiot.dane["brud_rajd"] = float(przedmiot.dane.get("brud_rajd", 0.0)) + 1.0
			Efekty.zawiesina(gracz.get_parent(), gracz.global_position + Vector3.UP * 1.3 - gracz.global_basis.z * 1.2, clampf(1.6 - pole / 70.0, 0.6, 1.4))
	if _tryb() == "auto":
		bloom = minf(bloom + 0.35, 3.0)
	# szarpnięcie broni w widoku (sprężyna): pistolet podbija lufę, karabin wchodzi w ramię, obrzyn – jedno i drugie
	var p_cofa := 1.0
	var p_lufa := 1.0
	match bd["slot"]:
		"pistolet":
			p_cofa = 0.7
			p_lufa = 1.6
	if bd["kaliber"] == "12/70":
		p_cofa = 1.7
		p_lufa = 1.5
	var mn := lerpf(1.0, 0.55, ads) * lerpf(1.0, 0.6, podparcie)
	_kick += Vector3(0.0, 0.004, 0.02 + sila * 0.006) * p_cofa
	_kick_v += Vector3(randf_range(-0.12, 0.12), 0.25 * lerpf(1.0, 0.25, ads), 1.6 + sila * 0.35) * p_cofa * mn
	# przy celowaniu broń idzie głównie w tył (w ramię), a nie w górę – zamek nie wchodzi na linię wzroku
	_kick_rot_v += Vector3(deg_to_rad(110.0 + sila * 30.0) * lerpf(1.0, 0.35, ads) * p_lufa, randf_range(-0.6, 0.6) + bok * 0.8, randf_range(-0.9, 0.9) - bok * 0.5) * mn
	var wylot := model.global_transform * Vector3(md["lufa"])
	Efekty.blysk(gracz.get_parent(), wylot, (3.0 if bd["slot"] == "pistolet" else 4.0) * (0.15 if _bez_plomienia else 1.0) * lerpf(1.0, 0.6, ads))
	if not _bez_plomienia:
		# gwiazda + języki ognia wzdłuż lufy; przy celowaniu gwiazda bez środka – cel zostaje widoczny
		var sk := 0.65 if bd["slot"] == "pistolet" else (1.35 if bd["kaliber"] == "12/70" else 1.0)
		Efekty.plomien_wylotu(model, Transform3D(Basis(), Vector3(md["lufa"])), sk, ads)
	if _reka_p and is_instance_valid(_reka_p):
		_reka_p.ustaw_chwyt("strzal")
		_spust_t = 0.07
	_odskok = 1.0
	# zużycie: każdy strzał brudzi broń (nagar), tłumik szybciej
	przedmiot.dane["stan"] = maxf(0.0, float(przedmiot.dane.get("stan", 100.0)) - (0.12 if _bez_plomienia else 0.08))
	# zacięcie: rzadkie, częstsze przy długich seriach (gorąca broń) i w brudnej broni
	if not bd.has("wewnetrzny") and przedmiot.dane.get("komora", "") != "":
		var stan_b := float(przedmiot.dane.get("stan", 100.0))
		var szansa := (0.0035 + bloom * 0.002) * (1.0 + (100.0 - stan_b) / 35.0) * (1.0 + float(przedmiot.dane.get("brud", 0.0)) / 20.0)
		if randf() < szansa:
			przedmiot.dane["zaciecie"] = true
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
	if not bd.has("wewnetrzny"):
		# praca zamka tuż przy uchu; po ostatnim naboju zamek staje w tyle (głośniejszy, suchy klik)
		Dzwiek.graj("mechanizm", -13.0, randf_range(0.92, 1.08) * (1.15 if bd["slot"] == "pistolet" else 1.0))
		if przedmiot.dane.get("komora", "") == "" and _ruchome.has("zamek") and bool(_ruchome["zamek"]["dane"].get("blokada", false)):
			get_tree().create_timer(0.05).timeout.connect(func(): Dzwiek.graj("klik", -7.0, 0.8))
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


func _promien(space: PhysicsDirectSpaceState3D, od: Vector3, kier: Vector3, obr: float, pen: float, glebokosc := 0) -> void:
	var q := PhysicsRayQueryParameters3D.create(od, od + kier * 150.0, MASKA_STRZALU)
	q.collide_with_areas = true
	var r := space.intersect_ray(q)
	# kula przelatująca obok wroga przygniata go (kryje się, gorzej celuje, traci morale)
	var koniec: Vector3 = r["position"] if not r.is_empty() else od + kier * 150.0
	var trafiony_w = r["collider"].get_meta("wlasciciel") if not r.is_empty() and r["collider"].has_meta("wlasciciel") else null
	for w in get_tree().get_nodes_in_group("wrogowie"):
		if w == trafiony_w or not is_instance_valid(w) or not w.has_method("przygniec"):
			continue
		var dd := Balistyka.odl_od_odcinka((w as Node3D).global_position + Vector3.UP * 1.4, od, koniec)
		if dd < 2.0:
			w.przygniec(1.0 - dd / 2.0, gracz)
	if r.is_empty():
		return
	var col: Object = r["collider"]
	if col.has_meta("drzwi") and glebokosc < 2:
		# drewniane drzwi kula przebija (słabsza), w blasze tylko iskry
		var dr = col.get_meta("drzwi")
		Efekty.slad(col as Node3D, r["position"], r["normal"])
		if is_instance_valid(dr) and dr.rodzaj != "metal":
			Efekty.czastki(gracz.get_parent(), r["position"], r["normal"], Color(0.55, 0.42, 0.3), 10, 2.5)
			Dzwiek.graj_3d("trafienie_drewno", r["position"], gracz.get_parent(), -4.0)
			_promien(space, r["position"] + kier * 0.08, kier, obr * 0.65, pen * 0.7, glebokosc + 1)
		else:
			Efekty.czastki(gracz.get_parent(), r["position"], r["normal"], Color(1.0, 0.8, 0.4), 6, 5.0)
			Dzwiek.graj_3d("trafienie_pancerz", r["position"], gracz.get_parent(), -4.0)
		return
	if col.has_meta("czesc"):
		var wl = col.get_meta("wlasciciel")
		if is_instance_valid(wl) and wl.has_method("trafiony"):
			var czesc_t := String(col.get_meta("czesc"))
			wl.trafiony(czesc_t, obr, pen, gracz, r["position"], kier)
			var zabity: bool = wl.get("cialo") != null and wl.cialo.martwy
			# z daleka trafienie słychać z opóźnieniem dźwięku (głuche w ciało, metaliczne w płytę) – bez znaczników
			var odl := gracz.global_position.distance_to(r["position"])
			if odl > 12.0:
				var w_panc := false
				var pc = wl.get("helm") if czesc_t == "glowa" else wl.get("pancerz")
				if pc is Przedmiot and czesc_t in ((pc as Przedmiot).defn()["pancerz"]["strefy"] as Array):
					w_panc = true
				var dzw := "trafienie_pancerz" if w_panc else "trafienie_cialo"
				get_tree().create_timer(odl / 343.0).timeout.connect(func(): Dzwiek.graj(dzw, -13.0, randf_range(0.9, 1.05)))
			get_tree().call_group("hud", "znacznik_trafienia", zabity, String(col.get_meta("czesc")) == "glowa")
			# krew na ścianie za celem
			var q2 := PhysicsRayQueryParameters3D.create(r["position"], r["position"] + kier * 2.5, Balistyka.WARSTWA_SWIAT)
			var r2 := space.intersect_ray(q2)
			if not r2.is_empty() and randf() < 0.7:
				Efekty.slad(gracz.get_parent(), r2["position"], r2["normal"], true)
			return
	var swiat := gracz.get_parent() as Node3D
	# meble i przedmioty: dotychczasowy ślad; ściany i podłogi: dziura i pył wg materiału
	if (col as Node).name.begins_with("Sciany"):
		Efekty.trafienie_sciany(swiat, r["position"], r["normal"])
		return
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
		if _ruchome.has("lufy"):
			# łamana: pełna choreografia (łuski, naboje, zatrzaśnięcie)
			_chor = Przeladowania.obrzyn(self, szybkie)
			stan = "lamanie"
			stan_t = 0.0
			stan_total = _chor.calosc
			_fazy_dzw = []
			return
		stan = "ladowanie_wewn"
		stan_t = 0.0
		stan_total = float(bd["przeladowanie"]) * 0.5
		_fazy_dzw = [[0.7, "naboj_wloz", -8.0]]
		return
	var z := ekw.znajdz_magazynek(bd["magazynki"])
	if z.is_empty():
		komunikat.emit("Brak załadowanych magazynków (napełnij: G w ekwipunku)")
		return
	var t := float(bd["przeladowanie"]) * float(z.get("mnoznik", 1.0 if z["szybki"] else 1.7))
	if gracz.has_method("_otworz_po_drodze"):
		gracz._otworz_po_drodze(z["p"])
	if szybkie:
		t *= 0.7
	if przedmiot.dane["komora"] == "":
		t += 0.5
	_byl_pusty = przedmiot.dane["komora"] == ""
	job = {"nowy": z["p"], "siatka": z["siatka"], "szybkie": szybkie}
	stan = "przeladowanie"
	stan_t = 0.0
	stan_total = t
	# wypięcie starego magazynka, ładownica, wpięcie nowego, (pusta komora) przeciągnięcie zamka –
	# dźwięki i ruchy w choreografii
	_fazy_dzw = []
	_chor = Przeladowania.magazynek(self, szybkie, t)
	if z["siatka"] == ekw.kieszenie:
		komunikat.emit("Magazynek z kieszeni – dłużej niż z ładownicy")
	elif not z["szybki"]:
		komunikat.emit("Magazynek z plecaka – dłuższe przeładowanie")


var _fazy_dzw: Array = []


func _zamek_dzw() -> String:
	return "zamek_pist" if bd.get("slot", "") == "pistolet" else "zamek_kb"


## Dźwięki mechanizmu w kolejnych fazach czynności (ułamki czasu stanu).
func _graj_fazy() -> void:
	if _fazy_dzw.is_empty() or stan_total <= 0.0:
		return
	var f := stan_t / stan_total
	while not _fazy_dzw.is_empty() and f >= float(_fazy_dzw[0][0]):
		var fz: Array = _fazy_dzw.pop_front()
		Dzwiek.graj(fz[1], fz[2], randf_range(0.97, 1.03))


func _koniec_stanu() -> void:
	_fazy_dzw = []
	var s := stan
	stan = "gotowa"
	if _chor:
		_chor.aktualizuj(stan_total)
	match s:
		"przeladowanie":
			_dokoncz_przeladowanie()
		"ladowanie_wewn":
			var wz: Dictionary = gracz.ekw.zabierz_amunicje(bd["kaliber"], 1, przedmiot.dane["wewn_typ"])
			if wz["n"] > 0:
				if przedmiot.dane["wewn"] == 0 or przedmiot.dane["wewn_typ"] == "":
					przedmiot.dane["wewn_typ"] = wz["id"]
				przedmiot.dane["wewn"] += 1
				if przedmiot.dane["wewn"] < int(bd["wewnetrzny"]) and gracz.ekw.policz_amunicje(bd["kaliber"]) > 0:
					stan = "ladowanie_wewn"
					stan_t = 0.0
					_fazy_dzw = [[0.7, "naboj_wloz", -8.0]]
				else:
					Dzwiek.graj("obrzyn_zamk", -5.0)
		"sprawdzanie":
			komunikat.emit(opis_amunicji())
		"lamanie":
			if int(przedmiot.dane.get("wewn", 0)) > 0:
				komunikat.emit(opis_amunicji())
		"usuwanie":
			przedmiot.dane["zaciecie"] = false
			_byl_pusty = false
			_raczka = 0.0
			# zacięty nabój wypada, z magazynka wchodzi następny
			var m: Przedmiot = przedmiot.dane.get("mag")
			if m != null and m.dane["naboje"] > 0:
				przedmiot.dane["komora"] = m.dane["amunicja"]
				m.dane["naboje"] -= 1
			else:
				przedmiot.dane["komora"] = ""
			Efekty.luska(gracz.get_parent(), model.global_transform * Vector3(0.03, 0.05, -0.06), kamera.global_basis.x)
			komunikat.emit("Zacięcie usunięte")
	_chor_koniec()
	zmiana.emit()


## Koniec choreografii: lewa dłoń wraca do spoczynku, pomocnicze obiekty znikają.
func _chor_koniec() -> void:
	if _chor == null:
		return
	_chor = null
	for w in _chor_wezly:
		if is_instance_valid(w):
			w.queue_free()
	_chor_wezly.clear()
	if mag_node:
		mag_node.transform = Transform3D()
	if _lewa and _reka_l and is_instance_valid(_reka_l):
		_lewa.transform = Transform3D()
		_reka_l.transform = _reka_baza
		_reka_l.celuj_lokiec(_lok_baza, model)
		_reka_l.ustaw_chwyt("pistolet" if (jest_pistolet() or md.has("chwyt_pionowy")) else "lozysko")
	_raczka = 0.0
	_odswiez_mag()


## Szarpnięcie broni w choreografii (zatrzask luf, wpięty magazynek, puszczony zamek).
func _kop_anim(r: Vector3, p: Vector3) -> void:
	_kick_rot += r
	_kick += p


## Choreografia w tej klatce: lewa dłoń, łokieć, palce, przechył broni.
func _zastosuj_chor() -> Array:
	if _lewa and _reka_l and is_instance_valid(_reka_l):
		_lewa.transform = Transform3D()
		_reka_l.transform = _chor.reka
		_reka_l.celuj_lokiec(_chor.reka.origin + _chor.lok, model)
		if _chor.chwyt != "" and _reka_l._chwyt != _chor.chwyt:
			_reka_l.ustaw_chwyt(_chor.chwyt)
	return [_chor.bron_rot, _chor.bron_poz]


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
	# bezwładność: cięższa broń zostaje bardziej w tyle za ruchem głowy
	_sway += mysz * 0.00035 / _bezwladnosc()
	_sway = _sway.limit_length(0.07)


var _sway_v := Vector2.ZERO
var _lok := Vector3.ZERO        # wygładzona prędkość gracza w układzie postaci
var _oddech_t := 0.0
var sciana := 0.0               # 0..1 – lufa przy przeszkodzie (broń odsunięta / opuszczona)
var nisko := false               # [V] broń nisko (swobodny marsz, długie złożenie) / wysoko (gotowa, męczy ręce)
var _nisko_f := 0.0
var zmecz_rak := 0.0            # 0..1 – ręce mdleją przy długim celowaniu (stojąc szybciej, podparcie prawie nie męczy)
var podparcie := 0.0            # 0..1 – broń oparta o parapet, mebel, krawędź ściany (mniejszy odrzut)
var _sciana_t := 0.0


func _bezwladnosc() -> float:
	return clampf(0.6 + (przedmiot.waga() if przedmiot else 0.5) * 0.15, 0.7, 1.5)


## Lufa przy ścianie i podparcie broni (promienie z kamery).
func _przeszkody(delta: float) -> void:
	_sciana_t -= delta
	if _sciana_t > 0.0 or gracz == null or kamera == null:
		return
	_sciana_t = 0.05
	var space := gracz.get_world_3d().direct_space_state
	var od := kamera.global_position
	var przod := -kamera.global_basis.z
	var dl := 0.5 if jest_pistolet() else 0.82
	var q := PhysicsRayQueryParameters3D.create(od, od + przod * (dl + 0.1), Balistyka.WARSTWA_SWIAT)
	q.exclude = [gracz.get_rid()]
	var r := space.intersect_ray(q)
	var cel_s := 0.0
	if not r.is_empty():
		cel_s = clampf((dl + 0.1 - od.distance_to(r["position"])) / (dl * 0.6), 0.0, 1.0)
	sciana = move_toward(sciana, cel_s, 0.05 * (5.0 if cel_s > sciana else 3.0))
	# podparcie: przy celowaniu, stojąc w miejscu – pod łożem albo z boku jest twarda krawędź
	var cel_p := 0.0
	if ads > 0.5 and Vector2(gracz.velocity.x, gracz.velocity.z).length() < 0.4 and sciana < 0.3:
		var pp := od + przod * (0.42 if not jest_pistolet() else 0.3) - kamera.global_basis.y * 0.07
		var prawo := kamera.global_basis.x
		for k in [[pp, pp - Vector3.UP * 0.28], [pp, pp + prawo * 0.24], [pp, pp - prawo * 0.24]]:
			var q2 := PhysicsRayQueryParameters3D.create(k[0], k[1], Balistyka.WARSTWA_SWIAT)
			q2.exclude = [gracz.get_rid()]
			if not space.intersect_ray(q2).is_empty():
				cel_p = 1.0
				break
	podparcie = move_toward(podparcie, cel_p, 0.05 * 4.0)


var _spust_t := 0.0
var _ruchome := {}
var _odskok := 0.0           # 1 = zamek w tyle po strzale, maleje
var _raczka := 0.0           # przeciąganie rączki zamka przez lewą dłoń (0..1)
var _lufy_otw := 0.0
var _luska_reka: MeshInstance3D   # nabój w lewej dłoni przy ładowaniu obrzyna
var _zegarek := 0.0
var _reka_zeg: Reka


## Części ruchome i pokazywanie zegarka (H): zamek, rączka, lufy obrzyna.
func _animuj_mechanizm(delta: float) -> void:
	_odskok = maxf(0.0, _odskok - delta * 16.0)
	var cel_lufy := 1.0 if stan == "ladowanie_wewn" else 0.0
	_lufy_otw = move_toward(_lufy_otw, cel_lufy, delta * 4.5)
	var ch_lufy := -1.0
	var ch_zamek := -1.0
	if _chor:
		ch_lufy = float(_chor.kanaly.get("lufy", -1.0))
		ch_zamek = float(_chor.kanaly.get("zamek", -1.0))
		_raczka = float(_chor.kanaly.get("raczka", 0.0))
	for nazwa in _ruchome:
		var r: Dictionary = _ruchome[nazwa]
		var w: Node3D = r["wezel"]
		var d: Dictionary = r["dane"]
		if nazwa == "lufy":
			var e := _lufy_otw * _lufy_otw * (3.0 - 2.0 * _lufy_otw)
			w.rotation.x = float(d["kat"]) * (ch_lufy if ch_lufy >= 0.0 else e)
			continue
		var skok: float = d["skok"]
		var otwarty := 0.0
		if bool(d.get("blokada", false)) and przedmiot and przedmiot.dane.get("komora", "x") == "" and stan != "wyciaganie":
			otwarty = 1.0      # zamek zablokowany w tylnym położeniu (pusta broń)
		if ch_zamek >= 0.0:
			otwarty = ch_zamek      # choreografia trzyma zamek (puszczany po wpięciu magazynka)
		var o := maxf(maxf(sin(_odskok * PI * 0.5), otwarty), _raczka)
		w.position = Vector3(0, 0, skok * o)




func _process(delta: float) -> void:
	_anim_akcji_t += delta
	zerkniecie = move_toward(zerkniecie, 1.0 if (stan == "sprawdzanie" and stan_t < stan_total - 0.3) else 0.0, delta * 3.0)
	_animuj_mechanizm(delta)
	_animuj_zegarek(delta)
	if _spust_t > 0.0:
		_spust_t -= delta
		if _spust_t <= 0.0 and _reka_p and is_instance_valid(_reka_p):
			_reka_p.ustaw_chwyt("spust")
	if _reka_l and is_instance_valid(_reka_l) and gracz and gracz.get("cialo"):
		_reka_l.ustaw_zdrowie(gracz.cialo.procent(), gracz.cialo.krwawi() > 0)
	_opusc = move_toward(_opusc, 1.0 if (_anim_akcji != "" and _anim_akcji != "montaz") else 0.0, delta * 4.0)
	_montaz = move_toward(_montaz, 1.0 if _anim_akcji == "montaz" else 0.0, delta * 3.0)
	if _anim_cz and is_instance_valid(_anim_cz):
		var widac := _opusc > 0.05 and _anim_akcji != "schowaj" and _anim_akcji != ""
		_anim_cz.visible = widac
		if widac and gracz and not gracz.akcja.is_empty():
			var a: Dictionary = gracz.akcja
			var e := _opusc * _opusc * (3.0 - 2.0 * _opusc)
			_anim_cz.aktualizuj(float(a["t"]), float(a["czas"]), int(a["kroki"]), int(a["zrobione"]), e)
		elif not widac and _opusc <= 0.05 and _anim_akcji == "":
			_anim_cz.queue_free()
			_anim_cz = null
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
	# sprężyna bezwładności: broń dochodzi do środka z lekkim przestrzeleniem (cięższa wolniej)
	var bz := _bezwladnosc()
	var reszta := minf(delta, 0.1)
	while reszta > 0.0:
		var h := minf(reszta, 0.008)
		_sway_v += (-_sway * 150.0 / bz - _sway_v * 15.0 / sqrt(bz)) * h
		_sway += _sway_v * h
		reszta -= h
	_sway = _sway.limit_length(0.08)
	# sprężyny odrzutu (kroki ≤ 8 ms – stabilne przy niskim FPS)
	var rk := minf(delta, 0.1)
	while rk > 0.0:
		var hk := minf(rk, 0.008)
		_kick_v += (-_kick * 340.0 - _kick_v * 26.0) * hk
		_kick += _kick_v * hk
		_kick_rot_v += (-_kick_rot * 300.0 - _kick_rot_v * 22.0) * hk
		_kick_rot += _kick_rot_v * hk
		rk -= hk
	_przeszkody(delta)
	# broń nisko: kolba przy biodrze, lufa w podłogę (kadr wolny, do strzału daleko)
	_nisko_f = move_toward(_nisko_f, 1.0 if nisko and ads < 0.2 else 0.0, delta * 2.4)
	var nf := _nisko_f * _nisko_f * (3.0 - 2.0 * _nisko_f)
	hip += Vector3(0.02, -0.09, 0.05) * nf
	var poz := hip.lerp(ads_poz, t) + bob + _kick + Vector3(-_sway.x, _sway.y, 0) * (1.0 - t * 0.7)
	var rot := _kick_rot + Vector3(_sway.y * 2.0, -_sway.x * 2.0, -_sway.x * 1.5) + Vector3(0, 0.05, 0) * (1.0 - t) + Vector3(-0.42, 0.18, 0.1) * nf
	if gracz:
		# ruch postaci: przechył przy kroku w bok, broń zostaje w tyle przy ruszaniu, unosi się/opada przy skoku
		var lv: Vector3 = gracz.global_basis.inverse() * gracz.velocity
		_lok = _lok.lerp(lv, minf(1.0, delta * 6.0 / bz))
		var kt := 1.0 - t * 0.65
		rot.z += clampf(-_lok.x * 0.035, -0.12, 0.12) * kt
		poz.x += clampf(-_lok.x * 0.004, -0.015, 0.015) * kt
		poz.z += clampf(-_lok.z * 0.005, -0.02, 0.02) * kt
		poz.y += clampf(-_lok.y * 0.008, -0.035, 0.035)
		rot.x += clampf(_lok.y * 0.02, -0.06, 0.06)
		var lad: float = float(gracz.get("_ladowanie")) if gracz.get("_ladowanie") != null else 0.0
		poz.y -= lad * 0.22
		rot.x -= lad * 0.45
		# oddech i drżenie: zmęczenie i rany powiększają, celowanie i podparcie zmniejszają
		var wytrz: float = float(gracz.get("wytrzymalosc")) if gracz.get("wytrzymalosc") != null else 100.0
		var zm := 1.0 - wytrz / 100.0
		_oddech_t += delta * (1.0 + zm * 1.6)
		var celn: float = gracz.cialo.mnoznik_celnosci() if gracz.get("cialo") else 1.0
		var alk: float = float(gracz.get("alkohol")) if gracz.get("alkohol") != null else 0.0
		var prz: float = float(gracz.get("przygniecenie")) if gracz.get("przygniecenie") != null else 0.0
		# zmęczenie rąk: przy przyrządach rośnie (ciężka broń, stanie, wychylenie, zadyszka), opada po opuszczeniu
		if t > 0.6:
			var ciez := clampf(przedmiot.waga() / 3.5, 0.4, 1.6) if przedmiot else 1.0
			var poza := lerpf(1.0, 0.55, float(gracz.get("kucanie"))) * (1.0 + absf(float(gracz.get("wychylenie"))) * 0.4)
			zmecz_rak = minf(1.0, zmecz_rak + delta / 16.0 * ciez * poza * (1.0 + zm) * (1.0 - podparcie * 0.9))
		elif not nisko:
			# broń wysoko (gotowa do strzału): ręce też pracują, choć wolniej niż przy oku
			zmecz_rak = clampf(zmecz_rak + delta / 70.0 - (delta * 0.05 if zmecz_rak > 0.45 else 0.0), 0.0, 1.0)
		else:
			zmecz_rak = maxf(0.0, zmecz_rak - delta * 0.22)
		var rece := maxf(0.0, zmecz_rak - 0.3) / 0.7
		var st: float = float(gracz.get("stres")) if gracz.get("stres") != null else 0.0
		var amp := 0.0022 * (1.0 + st * 2.2 + prz * 3.0 + zm * 2.5 + maxf(0.0, celn - 1.0) * 2.0 + minf(2.5, alk / 40.0) + rece * 2.2) * (1.0 - t * 0.6 * (1.0 - rece * 0.5)) * (1.0 - podparcie * 0.75)
		poz += Vector3(sin(_oddech_t * 1.1) * amp, sin(_oddech_t * 2.2) * amp * 0.7, 0.0)
		rot += Vector3(sin(_oddech_t * 2.2 + 0.4) * amp * 1.4, sin(_oddech_t * 1.1 + 0.8) * amp * 1.2, 0.0)
	# lufa przy przeszkodzie: broń cofnięta i opuszczona (nie przenika przez ścianę), strzał niemożliwy
	if sciana > 0.0:
		var es := sciana * sciana * (3.0 - 2.0 * sciana)
		poz += Vector3(-0.015, -0.05, 0.11) * es
		rot += Vector3(-0.55, 0.42, 0.28) * es
	# animacje stanów
	var f := 0.0
	if stan != "gotowa" and stan_total > 0.0:
		f = clampf(stan_t / stan_total, 0.0, 1.0)
	var dip := 0.0
	var st_anim := stan
	if _chor:
		var rp := _zastosuj_chor()
		rot += rp[0]
		poz += rp[1]
		st_anim = "chor"
	match st_anim:
		"przeladowanie":
			# broń przechylona do magazynka; lewa ręka: wyjmuje stary, sięga do kamizelki, wkłada nowy
			var przechyl := smoothstep(0.0, 0.15, f) * (1.0 - smoothstep(0.85, 1.0, f))
			rot += Vector3(0.18, 0.3, 0.55) * przechyl
			poz += Vector3(-0.02, 0.0, 0.02) * przechyl
			_animuj_przeladowanie(f)
		"ladowanie_wewn":
			if _ruchome.has("lufy"):
				# obrzyn złamany i przechylony komorami do oka; lewa dłoń: do kieszeni po nabój, do komory, wcisk
				var ot := _lufy_otw * _lufy_otw * (3.0 - 2.0 * _lufy_otw)
				rot += Vector3(0.45, 0.35, 0.35) * ot
				poz += Vector3(-0.03, 0.02, 0.04) * ot
				_animuj_ladowanie_naboju(f)
			else:
				dip = sin(f * PI) * 0.6
				rot += Vector3(0.5, 0.0, 0.3) * dip
				poz += Vector3(0, -0.04, 0.02) * dip
		"usuwanie":
			# przechył broni i przeciągnięcie zamka lewą dłonią (pistolet: zamek do tyłu i puszczony)
			var pr := smoothstep(0.0, 0.2, f) * (1.0 - smoothstep(0.85, 1.0, f))
			rot += Vector3(0.1, 0.25, 0.6) * pr
			poz += Vector3(-0.02, 0.01, 0.02) * pr
			if _lewa:
				var p_przod: Vector3 = Vector3(md["przod"])
				var raczka := Vector3(0.05, 0.075, -0.09) + (p_przod - Vector3(md.get("lozysko", p_przod)))
				if jest_pistolet():
					raczka = Vector3(-0.02, 0.06, 0.0) + (p_przod - Vector3(md.get("lozysko", p_przod)))
				var r: Vector3
				if f < 0.3:
					r = p_przod.lerp(raczka, smoothstep(0.0, 0.3, f))
				elif f < 0.6:
					r = raczka + Vector3(0, 0, 0.07) * smoothstep(0.3, 0.45, f)
					_raczka = smoothstep(0.3, 0.45, f) if f < 0.52 else 0.0
				else:
					_raczka = 0.0
					r = (raczka + Vector3(0, 0, 0.07)).lerp(p_przod, smoothstep(0.6, 1.0, f))
				_lewa.position = r - p_przod
				if _reka_l and is_instance_valid(_reka_l):
					_reka_l.ustaw_chwyt("piesc" if f > 0.25 and f < 0.6 else "otwarta")
		"sprawdzanie":
			dip = sin(f * PI)
			if mag_node and not md["mag"].is_empty() and przedmiot.dane.get("mag") != null:
				# sprawdzenie magazynka: lewa dłoń wysuwa go do połowy, broń przechylona, rzut oka na naboje
				rot += Vector3(0.15, 0.25, 0.75) * dip
				poz += Vector3(-0.04, 0.03, 0.03) * dip
				var wys := smoothstep(0.2, 0.4, f) * (1.0 - smoothstep(0.7, 0.88, f))
				mag_node.position = Vector3(0, -0.055, 0.012) * wys
				mag_node.rotation = Vector3(-0.15, 0, 0) * wys
				if _lewa == null and latarka_w_rece:
					var p_mag2: Vector3 = Vector3(md["mag"][0][0])
					var cel2 := p_mag2 + Vector3(0, -0.05, 0) + mag_node.position
					var pp2: Vector3 = Vector3(md["przod"])
					_lat_za_reka((pp2.lerp(cel2, smoothstep(0.0, 0.2, f) * (1.0 - smoothstep(0.88, 1.0, f))) - pp2) * 0.7)
				if _lewa:
					var p_mag: Vector3 = Vector3(md["mag"][0][0])
					var cel := p_mag + Vector3(0, -0.05, 0) + mag_node.position
					var p_przod: Vector3 = Vector3(md["przod"])
					var r := p_przod.lerp(cel, smoothstep(0.0, 0.2, f) * (1.0 - smoothstep(0.88, 1.0, f)))
					_lewa.position = r - p_przod if not jest_pistolet() else (r - p_przod) * 0.7
					if _reka_l and is_instance_valid(_reka_l):
						_reka_l.ustaw_chwyt("magazynek" if f > 0.15 and f < 0.9 else ("pistolet" if jest_pistolet() else "lozysko"))
			else:
				rot += Vector3(0.2, 0.0, -0.9) * dip
				poz += Vector3(-0.06, 0.02, 0.02) * dip
		"wyciaganie":
			var w := 1.0 - f
			rot += Vector3(-0.8, 0.0, 0.2) * w
			poz += Vector3(0, -0.2, 0.05) * w
	if stan != "przeladowanie" and stan != "sprawdzanie" and _chor == null:
		if mag_node:
			mag_node.position = Vector3.ZERO
			mag_node.rotation = Vector3.ZERO
			_odswiez_mag()
		if _lewa and stan != "ladowanie_wewn" and stan != "sprawdzanie" and stan != "usuwanie":
			_lewa.position = _lewa.position.lerp(Vector3.ZERO, minf(1.0, delta * 12.0))
		if _lewa == null and latarka_w_rece and _lat_node and is_instance_valid(_lat_node) and przedmiot != null:
			_lat_node.position = _lat_node.position.lerp(LAT_HARRIS, minf(1.0, delta * 12.0))
			_lat_node.rotation = _lat_node.rotation.lerp(Vector3(0.03, 0.0, 0.0), minf(1.0, delta * 12.0))
	if stan != "ladowanie_wewn" and _chor == null:
		if _luska_reka and is_instance_valid(_luska_reka):
			_luska_reka.visible = false
		if _lewa and _reka_l and is_instance_valid(_reka_l) and _ruchome.has("lufy") and _reka_l._chwyt != "lozysko":
			_reka_l.ustaw_chwyt("lozysko")
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
	if _zegarek > 0.0:
		var ez := _zegarek * _zegarek * (3.0 - 2.0 * _zegarek)
		rot += Vector3(-0.5, 0.35, 0.3) * ez
		poz += Vector3(0.06, -0.12, 0.05) * ez
		if _lewa:
			_lewa.position = _lewa.position.lerp(Vector3(-0.1, -0.3, 0.15), ez)
	if _montaz > 0.0 and not ogladanie:
		var rp := _animuj_montaz(rot, poz)
		rot = rp[0]
		poz = rp[1]
	# podgląd broni: z boku przed sobą (prawą stroną do oka), obracany myszą
	_ogl = move_toward(_ogl, 1.0 if ogladanie else 0.0, delta * 3.0)
	if _ogl > 0.0 and przedmiot:
		var eo := _ogl * _ogl * (3.0 - 2.0 * _ogl)
		var srodek := -0.07 if jest_pistolet() else -0.2
		var p_o := Vector3(srodek * -1.0 * 0.0, -0.02, -0.34 if jest_pistolet() else -0.58)
		var r_o := Vector3(ogl_obrot.y + 0.12, -PI * 0.5 + ogl_obrot.x, 0.0)
		var bo := Basis.from_euler(r_o)
		p_o -= bo * Vector3(0, 0.0, srodek)
		poz = poz.lerp(p_o, eo)
		rot = rot.lerp(r_o, eo)
		_animuj_montaz_podglad()
	model.position = poz
	model.rotation = rot
	# przy lunecie patrzymy przez okular: model znika, HUD rysuje siatkę PSO
	model.visible = _opusc < 0.95 and not (ma_lunete() and ads > 0.9)
	# snop latarki z soczewki, po ustawieniu modelu w tej klatce (bez opóźnienia)
	if (_lat_node or ma_latarke_broni()) and gracz and gracz.get("latarka") and gracz.latarka.visible:
		gracz.latarka.global_transform = transform_latarki()


var _opusc := 0.0
var zerkniecie := 0.0        # 0..1 – głowa pochylona do broni (sprawdzanie magazynka / komór)
var _rece_akcji: Node3D
var _anim_cz: AnimacjeAkcji
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
