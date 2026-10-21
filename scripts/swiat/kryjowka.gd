class_name Kryjowka
extends Node3D
## Kryjówka gracza w placówce: meble z Gra.kryjowka, ich funkcje i tryb budowy.
## Tryb budowy ([B] – akcja „tryb”): lista mebli z magazynu kwatery, podgląd stawianego mebla pod celownikiem
## (zielony – można, czerwony – nie i dlaczego), [R] obraca o 90°, [LPM] stawia, [PPM] anuluje.
## Bez mebla w ręce: celownik na postawionym meblu – [LPM] przestaw, [X] do magazynu.
## Meble do skrytki powiększają skrytkę; zabranie mebla, który by ucinał przedmioty w skrytce, jest odrzucane.

signal zmiana

enum Tryb { WYL, LISTA, STAWIANIE, PRZEGLAD }

var baza: Node                 # scena bazy (komunikaty, ekran ekwipunku)
var gracz: Gracz
var granice := Rect2(0, 0, 8, 7)          # wnętrze kryjówki (x, z)
var wysokosc := 2.8
var strefa_drzwi := Rect2(3.2, 6.0, 1.6, 1.0)   # przejście do korytarza – zawsze wolne
var przeszkody: Array = []     # Rect2 ścian wewnątrz granic (przegroda między izbami)
var wolne_strefy: Array = []   # Rect2 przejść, których nie wolno zastawić (oprócz drzwi do korytarza)
var tryb := Tryb.WYL

var _gen: GeneratorBiomu
var _wezly: Array = []         # węzeł na każdy wpis Gra.kryjowka
var _duch: Node3D              # podgląd stawianego mebla
var _duch_id := ""
var _duch_kat := 0.0           # obrót stawianego mebla w stopniach (co 15°; Shift – co 90°)
var _duch_idx := -1            # przestawiany postawiony mebel (-1 = nowy z magazynu)
var _duch_ok := false
var _duch_pos := Vector2.ZERO
var _wskazany := -1
var _ui: CanvasLayer
var _panel: PanelContainer
var _lista: VBoxContainer
var _podpis: Label
var _mat_ok: StandardMaterial3D
var _mat_zle: StandardMaterial3D
var _stojaki_odswiezane := false


func _ready() -> void:
	_gen = GeneratorBiomu.new()
	_gen.swiat = self
	_gen.meble = Dane.meble
	_mat_ok = _mat_ducha(Color(0.45, 0.95, 0.5, 0.42))
	_mat_zle = _mat_ducha(Color(1.0, 0.3, 0.25, 0.42))
	_buduj_ui()
	odbuduj()
	Gra.skrytka.zmieniona.connect(func():
		if not _stojaki_odswiezane:
			_stojaki_odswiezane = true
			(func():
				_stojaki_odswiezane = false
				odswiez_stojaki()).call_deferred())


func _mat_ducha(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


# ------------------------------------------------------------------ meble w świecie

## Stawia od nowa wszystkie meble z zapisu.
func odbuduj() -> void:
	for w in _wezly:
		if is_instance_valid(w):
			w.queue_free()
	_wezly.clear()
	for i in Gra.kryjowka.size():
		_wezly.append(_wezel(Gra.kryjowka[i], i))
	Gra.dopasuj_skrytke()
	odswiez_stojaki()
	zmiana.emit()


## Stojak na broń: rama z desek, dwie belki z wycięciami, półka na kolby (tył przy ścianie: −Z).
func _stojak(duch := false) -> Node3D:
	var B := preload("res://scripts/core/bryly.gd")
	var dr := Color(0.45, 0.32, 0.2)
	var cz := []
	for sx in [-0.62, 0.62]:
		cz.append({"t": "box", "c": Vector3(sx, 0.85, -0.12), "s": Vector3(0.06, 1.7, 0.08), "m": "drewno_m", "k": dr, "f": 0.006})
		cz.append({"t": "box", "c": Vector3(sx, 0.03, 0.0), "s": Vector3(0.08, 0.06, 0.4), "m": "drewno_m", "k": dr, "f": 0.006})
	cz.append({"t": "box", "c": Vector3(0, 0.3, 0.02), "s": Vector3(1.3, 0.05, 0.28), "m": "drewno_m", "k": dr.darkened(0.1), "f": 0.006})
	cz.append({"t": "box", "c": Vector3(0, 1.3, -0.08), "s": Vector3(1.3, 0.08, 0.12), "m": "drewno_m", "k": dr, "f": 0.006})
	cz.append({"t": "box", "c": Vector3(0, 1.62, -0.12), "s": Vector3(1.3, 0.06, 0.06), "m": "drewno_m", "k": dr, "f": 0.006})
	for i in 4:
		cz.append({"t": "box", "c": Vector3(-0.45 + i * 0.3, 1.36, -0.02), "s": Vector3(0.05, 0.05, 0.06), "m": "metal_ciemny_m", "f": 0.003})
	var mi := B.instancja(cz, false)
	if duch:
		var n := Node3D.new()
		n.add_child(mi)
		return n
	var sb := StaticBody3D.new()
	sb.collision_layer = Balistyka.WARSTWA_SWIAT
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.3, 1.7, 0.4)
	cs.shape = bs
	cs.position.y = 0.85
	sb.add_child(cs)
	var bronie := Node3D.new()
	bronie.name = "Bronie"
	sb.add_child(bronie)
	return sb


## Broń ze skrytki na stojakach (po 4 na stojak, od najcenniejszej).
func odswiez_stojaki() -> void:
	var bronie: Array = Gra.skrytka.wszystkie().filter(func(p): return (p as Przedmiot).typ() == "bron")
	bronie.sort_custom(func(a, b): return (a as Przedmiot).wartosc() > (b as Przedmiot).wartosc())
	var k := 0
	for i in Gra.kryjowka.size():
		if String(Gra.kryjowka[i]["id"]) != "stojak_bron" or i >= _wezly.size() or not is_instance_valid(_wezly[i]):
			continue
		var miejsce: Node3D = (_wezly[i] as Node3D).get_node_or_null("Bronie")
		if miejsce == null:
			continue
		for c in miejsce.get_children():
			c.queue_free()
		for j in 4:
			if k >= bronie.size():
				break
			var w := ModelePrzedmiotow.wezel(bronie[k])
			miejsce.add_child(w)
			postaw_pionowo(w, Vector3(-0.45 + j * 0.3, 0.33, 0.03))
			k += 1


## Broń z ModelePrzedmiotow (leży na boku, lufa wzdłuż −Z) – pionowo, wylotem w górę, profilem do patrzącego (+Z);
## kolba stoi na wysokości „dol.y”.
static func postaw_pionowo(w: Node3D, dol: Vector3) -> void:
	w.rotation = Vector3(PI * 0.5, 0, 0)
	w.position = Vector3.ZERO
	var ab := AABB()
	var pierwszy := true
	var rodzic := (w.get_parent() as Node3D).global_transform.affine_inverse()
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var a := (rodzic * m.global_transform) * m.get_aabb()
		ab = a if pierwszy else ab.merge(a)
		pierwszy = false
	w.position = dol - Vector3(ab.get_center().x, ab.position.y, ab.get_center().z)


func _wezel(e: Dictionary, idx: int) -> Node3D:
	var id := String(e["id"])
	var kat := kat_wpisu(e)
	var pos := Vector3(float(e["x"]), 0.0, float(e["z"]))
	if id == "zarowka":
		var n := Node3D.new()
		add_child(n)
		n.position = Vector3(pos.x, wysokosc, pos.z)
		var model: Node3D = load("res://assets/models/meble/zarowka.glb").instantiate()
		n.add_child(model)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.74, 0.48)
		l.light_energy = 1.2
		l.omni_range = 6.0
		l.omni_attenuation = 0.9
		n.add_child(l)
		l.position.y = -0.7
		n.set_meta("idx_mebla", idx)
		# niewidzialny chwyt, żeby dało się ją wskazać w trybie budowy
		var sb := StaticBody3D.new()
		sb.collision_layer = Balistyka.WARSTWA_INTERAKCJE
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.25, 0.7, 0.25)
		cs.shape = bs
		cs.position.y = -0.35
		sb.add_child(cs)
		n.add_child(sb)
		sb.set_meta("idx_mebla", idx)
		return n
	var w: Node3D
	if id == "stol_mapa":
		w = _gen._mebel("stol", pos, deg_to_rad(kat), true)
		var plan := ModelePrzedmiotow.wezel(Przedmiot.nowy("mapa"))
		plan.scale = Vector3.ONE * 3.0
		w.add_child(plan)
		plan.position = Vector3(0, 0.76, 0)
		plan.rotation.y = 0.2
		var kmp := ModelePrzedmiotow.wezel(Przedmiot.nowy("radio"))
		w.add_child(kmp)
		kmp.position = Vector3(0.4, 0.76, -0.22)
	elif id == "stojak_bron":
		w = _stojak()
		add_child(w)
		w.position = pos
		w.rotation.y = deg_to_rad(kat)
	else:
		w = _gen._mebel(id, pos, deg_to_rad(kat), true)
	w.set_meta("idx_mebla", idx)
	# dywan i inne bez kolizji: obszar do wskazywania w trybie budowy
	if not (w is CollisionObject3D):
		var sb2 := StaticBody3D.new()
		sb2.collision_layer = Balistyka.WARSTWA_INTERAKCJE
		var cs2 := CollisionShape3D.new()
		var bs2 := BoxShape3D.new()
		var roz := MebleKryjowki.rozmiar(id)
		bs2.size = Vector3(roz.x, 0.04, roz.z)
		cs2.shape = bs2
		cs2.position.y = 0.02
		sb2.add_child(cs2)
		w.add_child(sb2)
		sb2.set_meta("idx_mebla", idx)
	var f := String(MebleKryjowki.KATALOG.get(id, {}).get("funkcja", ""))
	if f in ["skrytka", "warsztat", "odpoczynek", "kuchnia", "meldunki"]:
		var it := StaticBody3D.new()
		it.collision_layer = Balistyka.WARSTWA_INTERAKCJE
		it.set_meta("interakcja", _Funkcja.new(self, id, f))
		it.set_meta("idx_mebla", idx)
		var cs3 := CollisionShape3D.new()
		var bs3 := BoxShape3D.new()
		var roz2 := MebleKryjowki.rozmiar(id)
		bs3.size = Vector3(roz2.x + 0.06, maxf(0.3, roz2.y + 0.04), roz2.z + 0.06)
		cs3.shape = bs3
		cs3.position.y = bs3.size.y * 0.5
		it.add_child(cs3)
		w.add_child(it)
	return w


## Obrys mebla na podłodze (obrót co 90°, więc prostokąt osiowy).
## Kąt wpisu w stopniach (stare zapisy: "r" = obrót co 90°).
static func kat_wpisu(e: Dictionary) -> float:
	return float(e.get("kat", int(e.get("r", 0)) * 90))


## Obrys mebla na podłodze: prostokąt osiowy obejmujący obrócony mebel (przy 90° – dokładny).
static func obrys(id: String, x: float, z: float, kat: float) -> Rect2:
	var roz := MebleKryjowki.rozmiar(id)
	var a := deg_to_rad(kat)
	var c := absf(cos(a))
	var s := absf(sin(a))
	var sx := c * roz.x + s * roz.z
	var sz := s * roz.x + c * roz.z
	return Rect2(x - sx * 0.5, z - sz * 0.5, sx, sz)


## Pusty napis = można postawić; inaczej powód.
func powod_odmowy(id: String, x: float, z: float, kat: float, pomin := -1) -> String:
	var o := obrys(id, x, z, kat)
	var wn := granice.grow(-0.02)
	if not wn.encloses(o):
		return "nie mieści się w kryjówce"
	for prz in przeszkody:
		if o.intersects(prz):
			return "wchodzi w ścianę"
	if id == "zarowka":
		for i in Gra.kryjowka.size():
			var e: Dictionary = Gra.kryjowka[i]
			if i != pomin and String(e["id"]) == "zarowka" and Vector2(float(e["x"]), float(e["z"])).distance_to(Vector2(x, z)) < 0.6:
				return "za blisko innej żarówki"
		return ""
	if id != "dywan" and o.intersects(strefa_drzwi):
		return "zasłania przejście"
	for ws in wolne_strefy:
		if id != "dywan" and o.intersects(ws):
			return "zasłania przejście"
	if id != "dywan" and gracz:
		var gp := Vector2(gracz.global_position.x, gracz.global_position.z) - Vector2(global_position.x, global_position.z)
		if o.grow(0.3).has_point(gp):
			return "stoisz w tym miejscu"
	for i in Gra.kryjowka.size():
		if i == pomin:
			continue
		var e: Dictionary = Gra.kryjowka[i]
		var eid := String(e["id"])
		# żarówka wisi pod sufitem; dywan leży pod meblami (ale dwa dywany na sobie – nie)
		if eid == "zarowka" or ((id == "dywan") != (eid == "dywan")):
			continue
		if o.grow(-0.01).intersects(obrys(eid, float(e["x"]), float(e["z"]), kat_wpisu(e))):
			return "koliduje z: " + MebleKryjowki.nazwa(eid).to_lower()
	return ""


## Zabranie mebla do magazynu (odmowa, gdy skrytka by ucięła przedmioty).
func zabierz(idx: int) -> String:
	if idx < 0 or idx >= Gra.kryjowka.size():
		return "?"
	var e: Dictionary = Gra.kryjowka[idx]
	var po: Array = Gra.kryjowka.duplicate()
	po.remove_at(idx)
	if MebleKryjowki.wiersze_skrytki(po) < Gra.skrytka.zajete_wiersze():
		return "Najpierw opróżnij dolne rzędy skrytki (zabranie zmniejszy ją do %d rzędów)." % MebleKryjowki.wiersze_skrytki(po)
	Gra.kryjowka.remove_at(idx)
	var id := String(e["id"])
	Gra.meble_zapas[id] = int(Gra.meble_zapas.get(id, 0)) + 1
	odbuduj()
	Gra.zapisz()
	return ""


# ------------------------------------------------------------------ funkcje mebli

class _Funkcja:
	extends RefCounted
	var k: Kryjowka
	var id: String
	var f: String

	func _init(kr: Kryjowka, i: String, fu: String) -> void:
		k = kr
		id = i
		f = fu

	func tekst_interakcji(_g) -> String:
		if k.tryb != Kryjowka.Tryb.WYL:
			return ""
		match f:
			"skrytka":
				return "Skrytka (%d rzędów) i ekwipunek" % Gra.skrytka.h
			"warsztat":
				return "Stół roboczy (dodatki do broni)"
			"odpoczynek":
				return "Prześpij się (leczy połowę ran)" if Gra.odpoczynek else "Odpocząłeś – sen leczy raz po każdym powrocie ze strefy"
			"kuchnia":
				return "Ugotuj posiłek (konserwa / suchary + woda)"
			"meldunki":
				return "Przejrzyj meldunki przed rajdem"
		return ""

	func interakcja(_g) -> void:
		if k.tryb != Kryjowka.Tryb.WYL:
			return
		match f:
			"skrytka":
				k.baza.ekran_ekw.otworz_skrytke()
			"warsztat":
				k.baza.ekran_ekw.otworz_warsztat()
			"odpoczynek":
				k.odpocznij()
			"kuchnia":
				k.ugotuj()
			"meldunki":
				for linia in Gra.meldunki():
					k.baza.komunikat("Meldunek: " + linia)


## Sen na pryczy: połowa brakującego zdrowia każdej części, raz po każdym powrocie. Głód i pragnienie rosną.
func odpocznij() -> void:
	if not Gra.odpoczynek:
		baza.komunikat("Nie jesteś zmęczony. Sen leczy raz po każdym powrocie ze strefy.")
		return
	Gra.odpoczynek = false
	var nowe := {}
	var wyleczono := 0.0
	for cz in Cialo.MAX:
		var mx: float = Cialo.MAX[cz]
		var hp: float = float(Gra.zdrowie.get(cz, mx))
		var po := hp + (mx - hp) * 0.5
		wyleczono += po - hp
		if po < mx - 0.5:
			nowe[cz] = po
		if gracz and gracz.cialo and gracz.cialo.hp.has(cz):
			gracz.cialo.hp[cz] = po
	Gra.zdrowie = nowe
	Gra.potrzeby["glod"] = maxf(0.0, float(Gra.potrzeby["glod"]) - 6.0)
	Gra.potrzeby["pragnienie"] = maxf(0.0, float(Gra.potrzeby["pragnienie"]) - 8.0)
	Gra.ekw.zmieniony.emit()
	Gra.zapisz()
	_zaciemnienie()
	Dzwiek.graj("upadek_miekki", -10.0)
	baza.komunikat("Przespałeś kilka godzin. %s" % ("Rany się goją (+%d)." % int(wyleczono) if wyleczono >= 1.0 else "Byłeś zdrowy – przynajmniej się wyspałeś."))


## Kuchenka: najlepsze jedzenie ze skrytki/ekwipunku na ciepło (+50% sytości, bez pragnienia) i woda, jeśli jest.
func ugotuj() -> void:
	var jedzenie: Przedmiot = null
	var picie: Przedmiot = null
	# najpierw zapasy ze skrytki; prowiant z plecaka dopiero, gdy w skrytce nic nie ma
	for s in [Gra.skrytka] + Gra.ekw.siatki():
		if jedzenie != null and s != Gra.skrytka:
			break
		for p in (s as Siatka).wszystkie():
			var j: Dictionary = (p as Przedmiot).defn().get("jedzenie", {})
			if j.is_empty() or j.get("alkohol", false):
				continue
			if float(j.get("glod", 0)) > 0 and (jedzenie == null or float(j["glod"]) > float(jedzenie.defn()["jedzenie"]["glod"])):
				jedzenie = p
			elif j.get("picie", false) and picie == null:
				picie = p
	if jedzenie == null:
		baza.komunikat("Nie ma czego ugotować – potrzebna konserwa albo suchary (w skrytce lub przy sobie).")
		return
	var jd: Dictionary = jedzenie.defn()["jedzenie"]
	Gra.potrzeby["glod"] = clampf(float(Gra.potrzeby["glod"]) + float(jd["glod"]) * 1.5, 0.0, 100.0)
	_usun(jedzenie)
	var txt := "Ciepły posiłek: %s" % jedzenie.nazwa().to_lower()
	if picie:
		Gra.potrzeby["pragnienie"] = clampf(float(Gra.potrzeby["pragnienie"]) + float(picie.defn()["jedzenie"]["pragnienie"]) + 10.0, 0.0, 100.0)
		_usun(picie)
		txt += " i gorąca herbata"
	Gra.ekw.zmieniony.emit()
	Gra.zapisz()
	Dzwiek.graj("szelest_0", -6.0)
	baza.komunikat("%s. Sytość %d%%, nawodnienie %d%%." % [txt, int(Gra.potrzeby["glod"]), int(Gra.potrzeby["pragnienie"])])


func _usun(p: Przedmiot) -> void:
	if p.ilosc > 1:
		p.ilosc -= 1
		return
	if not Gra.skrytka.usun(p):
		Gra.ekw.usun_przedmiot(p)


func _zaciemnienie() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 30
	add_child(cl)
	var c := ColorRect.new()
	c.color = Color(0, 0, 0, 0)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(c)
	var tw := c.create_tween()
	tw.tween_property(c, "color:a", 1.0, 0.6)
	tw.tween_interval(0.8)
	tw.tween_property(c, "color:a", 0.0, 1.0)
	tw.tween_callback(cl.queue_free)


# ------------------------------------------------------------------ tryb budowy

func w_kryjowce(p: Vector3) -> bool:
	var l := p - global_position
	return granice.grow(0.6).has_point(Vector2(l.x, l.z))


func przelacz() -> void:
	if tryb == Tryb.WYL:
		otworz_liste()
	else:
		zamknij()


func otworz_liste() -> void:
	_porzuc_ducha()
	tryb = Tryb.LISTA
	_odswiez_liste()
	_panel.visible = true
	_podpis.visible = false
	Sterowanie.blokada = true
	Sterowanie.przechwyc(false)


func zamknij() -> void:
	_porzuc_ducha()
	_podswietl(-1)
	tryb = Tryb.WYL
	_panel.visible = false
	_podpis.visible = false
	Sterowanie.blokada = false
	Sterowanie.przechwyc(true)
	Gra.zapisz()


func _przeglad() -> void:
	_porzuc_ducha()
	tryb = Tryb.PRZEGLAD
	_panel.visible = false
	_podpis.visible = true
	Sterowanie.blokada = false
	Sterowanie.przechwyc(true)


func zacznij_stawianie(id: String, idx := -1) -> void:
	_porzuc_ducha()
	_podswietl(-1)
	_duch_id = id
	_duch_idx = idx
	_duch_kat = kat_wpisu(Gra.kryjowka[idx]) if idx >= 0 else 0.0
	if idx >= 0 and idx < _wezly.size() and is_instance_valid(_wezly[idx]):
		(_wezly[idx] as Node3D).visible = false
	_duch = _model_ducha(id)
	add_child(_duch)
	tryb = Tryb.STAWIANIE
	_panel.visible = false
	_podpis.visible = true
	Sterowanie.blokada = false
	Sterowanie.przechwyc(true)


func _model_ducha(id: String) -> Node3D:
	if id == "stojak_bron":
		return _stojak(true)
	if id == "stol_mapa":
		id = "stol"
	var path := "res://assets/models/meble/%s.glb" % id
	if not ResourceLoader.exists(path):
		path = "res://assets/models/%s.glb" % id
	var n: Node3D = load(path).instantiate()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


func _porzuc_ducha() -> void:
	if _duch and is_instance_valid(_duch):
		_duch.queue_free()
	_duch = null
	if _duch_idx >= 0 and _duch_idx < _wezly.size() and is_instance_valid(_wezly[_duch_idx]):
		(_wezly[_duch_idx] as Node3D).visible = true
	_duch_idx = -1
	_duch_id = ""


func _promien(maska: int) -> Dictionary:
	if gracz == null:
		return {}
	var od := gracz.kamera.global_position
	var q := PhysicsRayQueryParameters3D.create(od, od - gracz.kamera.global_basis.z * 6.0, maska)
	q.collide_with_areas = false
	q.exclude = [gracz.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func _physics_process(_d: float) -> void:
	match tryb:
		Tryb.STAWIANIE:
			_aktualizuj_ducha()
		Tryb.PRZEGLAD:
			var r := _promien(Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_INTERAKCJE)
			var idx := -1
			if not r.is_empty():
				var n: Node = r["collider"]
				while n and n != self:
					if n.has_meta("idx_mebla"):
						idx = int(n.get_meta("idx_mebla"))
						break
					n = n.get_parent()
			_podswietl(idx)
			_podpis.text = ("%s  ·  [LPM] przestaw   [X] do magazynu   " % MebleKryjowki.nazwa(String(Gra.kryjowka[idx]["id"]))) if idx >= 0 else ""
			_podpis.text += "[B] plan kryjówki   [Esc] koniec budowy"


func _aktualizuj_ducha() -> void:
	if _duch == null:
		return
	# punkt na podłodze pod celownikiem (dla żarówki – pod sufitem nad tym punktem)
	var od := gracz.kamera.global_position
	var kier := -gracz.kamera.global_basis.z
	var p := od + kier * 2.2
	if kier.y < -0.05:
		var t := (od.y - global_position.y) / -kier.y
		if t < 5.0:
			p = od + kier * t
	var l := p - global_position
	# siatka 0,1 m – równe ustawianie pod ścianą
	var x := snappedf(l.x, 0.1)
	var z := snappedf(l.z, 0.1)
	# dociągnięcie do ściany: mebel przy ścianie staje równo z nią
	var o := obrys(_duch_id, x, z, _duch_kat)
	if o.position.x < granice.position.x + 0.25:
		x += granice.position.x + 0.03 - o.position.x
	if o.end.x > granice.end.x - 0.25:
		x -= o.end.x - (granice.end.x - 0.03)
	if o.position.y < granice.position.y + 0.25:
		z += granice.position.y + 0.03 - o.position.y
	if o.end.y > granice.end.y - 0.25:
		z -= o.end.y - (granice.end.y - 0.03)
	_duch_pos = Vector2(x, z)
	_duch.position = Vector3(x, wysokosc if _duch_id == "zarowka" else 0.0, z)
	_duch.rotation.y = deg_to_rad(_duch_kat)
	var powod := powod_odmowy(_duch_id, x, z, _duch_kat, _duch_idx)
	_duch_ok = powod == ""
	for mi in _duch.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _mat_ok if _duch_ok else _mat_zle
	_podpis.text = "%s  ·  %s   [LPM] postaw   [R]/kółko obróć o 15° (Shift+R – 90°)   [PPM] anuluj" % [MebleKryjowki.nazwa(_duch_id), "można postawić" if _duch_ok else "nie: " + powod]


func _postaw() -> void:
	if not _duch_ok:
		Dzwiek.graj("sucho", -10.0)
		return
	var e := {"id": _duch_id, "x": snappedf(_duch_pos.x, 0.01), "z": snappedf(_duch_pos.y, 0.01), "kat": fposmod(_duch_kat, 360.0)}
	var id := _duch_id
	if _duch_idx >= 0:
		Gra.kryjowka[_duch_idx] = e
	else:
		Gra.kryjowka.append(e)
		Gra.meble_zapas[id] = int(Gra.meble_zapas.get(id, 0)) - 1
		if int(Gra.meble_zapas[id]) <= 0:
			Gra.meble_zapas.erase(id)
	_duch_idx = -1
	_porzuc_ducha()
	odbuduj()
	Gra.zapisz()
	Dzwiek.graj("upadek_miekki", -6.0)
	var f := String(MebleKryjowki.KATALOG.get(id, {}).get("funkcja", ""))
	if f == "skrytka":
		baza.komunikat("Skrytka: %d rzędów." % Gra.skrytka.h)
	# kolejny taki sam z magazynu – od razu w ręce
	if int(Gra.meble_zapas.get(id, 0)) > 0:
		zacznij_stawianie(id)
	else:
		_przeglad()


func _podswietl(idx: int) -> void:
	if idx == _wskazany:
		return
	if _wskazany >= 0 and _wskazany < _wezly.size():
		Rozlozenie3D.nakladka(_wezly[_wskazany], null)
	_wskazany = idx
	if idx >= 0 and idx < _wezly.size():
		Rozlozenie3D.nakladka(_wezly[idx], Rozlozenie3D.mat_podswietlenia())


## Wejście z głównego okna (świat 3D jest w SubViewport, do którego mysz nie trafia).
class Przekaznik:
	extends Node
	var cel

	func _unhandled_input(event: InputEvent) -> void:
		if is_instance_valid(cel):
			cel._wejscie(event)


func _wejscie(event: InputEvent) -> void:
	if tryb == Tryb.WYL:
		if event.is_action_pressed("tryb") and gracz and w_kryjowce(gracz.global_position) and not Sterowanie.blokada:
			otworz_liste()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pauza"):
		if tryb == Tryb.STAWIANIE:
			_porzuc_ducha()
			_przeglad()
		else:
			zamknij()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("tryb"):
		if tryb == Tryb.LISTA:
			zamknij()
		else:
			otworz_liste()
		get_viewport().set_input_as_handled()
		return
	if tryb == Tryb.STAWIANIE:
		if event.is_action_pressed("przeladuj"):
			_duch_kat = fposmod(_duch_kat + (90.0 if Input.is_key_pressed(KEY_SHIFT) else 15.0), 360.0)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_postaw()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_porzuc_ducha()
				_przeglad()
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_duch_kat = fposmod(_duch_kat + 15.0, 360.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_duch_kat = fposmod(_duch_kat - 15.0, 360.0)
			get_viewport().set_input_as_handled()
	elif tryb == Tryb.PRZEGLAD:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _wskazany >= 0:
			zacznij_stawianie(String(Gra.kryjowka[_wskazany]["id"]), _wskazany)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("przerwij") and _wskazany >= 0:
			var idx := _wskazany
			_podswietl(-1)
			var blad := zabierz(idx)
			baza.komunikat(blad if blad != "" else "Mebel w magazynie kwatery.")
			get_viewport().set_input_as_handled()
	if not w_kryjowce(gracz.global_position) and tryb != Tryb.LISTA:
		zamknij()


# ------------------------------------------------------------------ panel planu

func _buduj_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 18
	# panel w głównym oknie, nie w świecie 3D: świat jest w SubViewport bez wejścia myszy,
	# więc przyciski listy („Postaw: …”) nie dostawały kliknięć
	get_tree().root.add_child.call_deferred(_ui)
	var prz := Przekaznik.new()
	prz.cel = self
	_ui.add_child(prz)
	tree_exiting.connect(func():
		if is_instance_valid(_ui):
			_ui.queue_free())
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Motyw.motyw()
	_ui.add_child(root)
	_panel = PanelContainer.new()
	_panel.position = Vector2(24, 70)
	_panel.custom_minimum_size = Vector2(380, 0)
	_panel.visible = false
	root.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	v.add_child(Motyw.naglowek("Plan kryjówki"))
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 4)
	v.add_child(_lista)
	_podpis = Motyw.etykieta("", 16, Motyw.TEKST, Motyw.mono())
	_podpis.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_podpis.offset_left = -520
	_podpis.offset_right = 520
	_podpis.offset_top = -96
	_podpis.offset_bottom = -76
	_podpis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_podpis.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.03, 0.9))
	_podpis.add_theme_constant_override("outline_size", 4)
	_podpis.visible = false
	root.add_child(_podpis)


func _odswiez_liste() -> void:
	for c in _lista.get_children():
		c.queue_free()
	_lista.add_child(Motyw.etykieta("Skrytka: %d rzędów (zajęte: %d)" % [Gra.skrytka.h, Gra.skrytka.zajete_wiersze()], 14, Motyw.ZOLC, Motyw.mono_b()))
	var ids := Gra.meble_zapas.keys()
	if ids.is_empty():
		var l := Motyw.etykieta("Magazyn kwatery pusty. Meble sprzedaje Kwatermistrz w recepcji.", 13, Motyw.TEKST_CIEMNY)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lista.add_child(l)
	for id in ids:
		var b := Button.new()
		var m: Dictionary = MebleKryjowki.KATALOG.get(id, {})
		b.text = "Postaw: %s ×%d" % [MebleKryjowki.nazwa(id), int(Gra.meble_zapas[id])]
		b.tooltip_text = String(m.get("opis", ""))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var mid := String(id)
		b.pressed.connect(func(): zacznij_stawianie(mid))
		_lista.add_child(b)
	var pr := Button.new()
	pr.text = "Przestaw / zabierz postawione meble"
	pr.pressed.connect(_przeglad)
	_lista.add_child(pr)
	var zam := Button.new()
	zam.text = "Zamknij [B]"
	zam.pressed.connect(zamknij)
	_lista.add_child(zam)
