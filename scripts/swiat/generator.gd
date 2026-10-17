class_name GeneratorBiomu
extends RefCounted
## Generator rajdu w biomie 1 (blokowisko): losowy graf pomieszczeń na siatce, ściany z drzwiami i oknami,
## meble i osłony, kontenery z łupem, lampy (część zepsuta), punkty spawnu i wyjścia.

const C := 6.0           # rozmiar komórki (pomieszczenia) w metrach
const H := 2.8           # wysokość pomieszczeń
const T := 0.2           # grubość ściany
const DRZWI_W := 1.2
const DRZWI_H := 2.1
const GW := 6
const GH := 5

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const MATERIALY := {
	"klatka": ["sciana_lamperia", "lastryko", "tynk_bialy"],
	"korytarz": ["sciana_lamperia", "lastryko", "tynk_bialy"],
	"pokoj": ["tapeta_zielona", "parkiet", "tynk_bialy"],
	"kuchnia": ["tapeta_brazowa", "kafelki", "tynk_bialy"],
	"administracja": ["sciana_lamperia", "parkiet", "tynk_bialy"],
	"piwnica": ["cegla", "beton", "beton"],
	"magazyn": ["beton_sciana", "beton", "beton"],
	"warsztat": ["beton_sciana", "beton", "tynk_bialy"],
}
const NAZWY_TYPOW := {
	"klatka": "Klatka schodowa", "korytarz": "Korytarz", "pokoj": "Mieszkanie", "kuchnia": "Kuchnia",
	"administracja": "Administracja", "piwnica": "Piwnica", "magazyn": "Magazyn", "warsztat": "Warsztat",
}

# szablony wyposażenia: [mebel, przy_scianie, min, max]
const WYPOSAZENIE := {
	"klatka": [["skrzynki_pocztowe", true, 1, 1], ["tablica_ogloszen", true, 0, 1], ["beczka", false, 0, 1], ["hydrant", true, 0, 1]],
	"korytarz": [["beczka", false, 0, 2], ["skrzynia", false, 0, 2], ["szafka_metalowa", true, 0, 1], ["hydrant", true, 0, 1], ["tablica_ogloszen", true, 0, 1], ["worki_piasek", false, 0, 1]],
	"pokoj": [["meblosciana", true, 0, 1], ["szafa", true, 0, 1], ["wersalka", true, 0, 1], ["lozko", true, 0, 1], ["stol", false, 0, 1], ["krzeslo", false, 0, 2], ["telewizor", true, 0, 1], ["dywan", false, 0, 1], ["kaloryfer", true, 0, 1]],
	"kuchnia": [["kuchenka", true, 1, 1], ["lodowka", true, 0, 1], ["szafka_kuchenna", true, 1, 2], ["stol", false, 0, 1], ["krzeslo", false, 0, 2], ["apteczka_scienna", true, 0, 1]],
	"administracja": [["biurko", false, 1, 2], ["krzeslo", false, 1, 2], ["szafa", true, 0, 1], ["szafka_metalowa", true, 0, 2], ["apteczka_scienna", true, 0, 1]],
	"piwnica": [["regal_metalowy", true, 1, 2], ["skrzynia", false, 1, 3], ["beczka", false, 0, 2], ["worki_piasek", false, 0, 1]],
	"magazyn": [["skrzynia_wojskowa", false, 1, 3], ["regal_metalowy", true, 1, 2], ["worki_piasek", false, 1, 2], ["skrzynia", false, 0, 2]],
	"warsztat": [["stol_warsztatowy", true, 1, 1], ["regal_metalowy", true, 0, 2], ["szafka_metalowa", true, 0, 1], ["beczka", false, 0, 2], ["skrzynia", false, 0, 1]],
}
const MONTOWANE_NA_SCIANIE := ["hydrant", "tablica_ogloszen", "apteczka_scienna", "skrzynki_pocztowe", "kaloryfer", "znak_wyjscie"]
const BEZ_KOLIZJI := ["dywan", "zarowka", "hydrant", "tablica_ogloszen", "apteczka_scienna", "skrzynki_pocztowe", "znak_wyjscie", "kaloryfer"]

var rng := RandomNumberGenerator.new()
var swiat: Node3D
var meble := {}
var komorki := {}        # Vector2i -> {"typ", "glebokosc", "zajete": Array[Rect2], "id"}
var krawedzie := {}      # klucz "a|b" -> {"a", "b", "drzwi": float (offset), "otwarte": bool}
var bud := Kit.Budowniczy.new()
var cialo_scian: StaticBody3D
var oslony: Array = []   # {"pos": Vector3, "niska": bool}
var spawny: Array = []   # {"pos": Vector3, "komorka": Vector2i, "glebokosc": int}
var wyjscia: Array = []
var lampy: Array = []
var start_pos := Vector3.ZERO
var start_rot := 0.0
var okna: Array = []     # [komorka, strona]


func generuj(ziarno: int, rodzic: Node3D) -> Dictionary:
	rng.seed = ziarno
	swiat = rodzic
	meble = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dane/meble.json"))
	cialo_scian = StaticBody3D.new()
	cialo_scian.name = "Sciany"
	cialo_scian.collision_layer = Balistyka.WARSTWA_SWIAT
	swiat.add_child(cialo_scian)
	_uklad()
	_typy()
	for k in komorki:
		_pomieszczenie(k)
	_sciany_wspolne()
	var mi := MeshInstance3D.new()
	mi.name = "Geometria"
	mi.mesh = bud.zbuduj({"okno": 0.5})
	swiat.add_child(mi)
	_podloga_kolizja()
	for k in komorki:
		_wyposaz(k)
		_lampa(k)
	_wyjscia()
	_klucz_w_rajdzie()
	return {"start": start_pos, "start_rot": start_rot, "oslony": oslony, "spawny": spawny,
		"wyjscia": wyjscia, "komorki": komorki, "lampy": lampy}


# ------------------------------------------------------------------ układ

func _k(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]


func _uklad() -> void:
	var start := Vector2i(0, rng.randi_range(1, GH - 2))
	komorki[start] = {"typ": "klatka", "glebokosc": 0, "zajete": [], "meble": []}
	var cel := rng.randi_range(14, 18)
	var lista: Array = [start]
	var proby := 0
	while komorki.size() < cel and proby < 2000:
		proby += 1
		var z: Vector2i = lista[rng.randi() % lista.size()]
		var d: Vector2i = DIRS[rng.randi() % 4]
		var n := z + d
		if n.x < 0 or n.y < 0 or n.x >= GW or n.y >= GH or komorki.has(n):
			continue
		komorki[n] = {"typ": "", "glebokosc": 0, "zajete": [], "meble": []}
		lista.append(n)
		krawedzie[_k(z, n)] = {"a": z, "b": n, "drzwi": 0.0, "otwarte": false}
	# pętle: dodatkowe przejścia między sąsiadami
	for a in komorki:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var b: Vector2i = a + d
			if komorki.has(b) and not krawedzie.has(_k(a, b)) and rng.randf() < 0.22:
				krawedzie[_k(a, b)] = {"a": a, "b": b, "drzwi": 0.0, "otwarte": false}
	for key in krawedzie:
		krawedzie[key]["drzwi"] = rng.randf_range(1.0, C - DRZWI_W - 1.0)
	# głębokość (BFS)
	var kol := [start]
	var odw := {start: 0}
	while not kol.is_empty():
		var a: Vector2i = kol.pop_front()
		for d in DIRS:
			var b: Vector2i = a + d
			if komorki.has(b) and krawedzie.has(_k(a, b)) and not odw.has(b):
				odw[b] = odw[a] + 1
				kol.append(b)
	for a in komorki:
		komorki[a]["glebokosc"] = odw.get(a, 0)
	start_pos = _srodek(start) + Vector3(-1.8, 0.05, 0)
	start_rot = -PI / 2.0


func _typy() -> void:
	var maxg := 1
	for a in komorki:
		maxg = maxi(maxg, komorki[a]["glebokosc"])
	for a in komorki:
		if komorki[a]["typ"] != "":
			continue
		var f := float(komorki[a]["glebokosc"]) / maxg
		var tab: Array
		if f < 0.45:
			tab = [["korytarz", 26], ["pokoj", 30], ["kuchnia", 20], ["administracja", 12], ["warsztat", 8]]
		else:
			tab = [["pokoj", 14], ["piwnica", 30], ["magazyn", 22], ["warsztat", 16], ["administracja", 12], ["korytarz", 8]]
		komorki[a]["typ"] = Dane.losuj(tab, rng)
	# korytarze łączą się szeroko
	for key in krawedzie:
		var e: Dictionary = krawedzie[key]
		var ta: String = komorki[e["a"]]["typ"]
		var tb: String = komorki[e["b"]]["typ"]
		if ta in ["korytarz", "klatka"] and tb in ["korytarz", "klatka"] and rng.randf() < 0.5:
			e["otwarte"] = true


func _srodek(k: Vector2i) -> Vector3:
	return Vector3(k.x * C + C * 0.5, 0, k.y * C + C * 0.5)


# ------------------------------------------------------------------ geometria

func _uv_sciany(u: float, y: float) -> Vector2:
	return Vector2(u, 1.0 - y / H)


func _pomieszczenie(k: Vector2i) -> void:
	var typ: String = komorki[k]["typ"]
	var mats: Array = MATERIALY[typ]
	var x0 := k.x * C + T * 0.5
	var z0 := k.y * C + T * 0.5
	var x1 := (k.x + 1) * C - T * 0.5
	var z1 := (k.y + 1) * C - T * 0.5
	bud.plaszczyzna(mats[1], x0, z0, x1, z1, 0.0, true, 1.5, 1.0)
	bud.plaszczyzna(mats[2], x0, z0, x1, z1, H, false, 1.5, 1.0)
	# cztery ściany: [kierunek, punkt a, punkt b] tak, by przód patrzył do wnętrza
	var strony := [
		[Vector2i(0, -1), Vector3(x0, 0, z0), Vector3(x1, 0, z0)],
		[Vector2i(0, 1), Vector3(x1, 0, z1), Vector3(x0, 0, z1)],
		[Vector2i(-1, 0), Vector3(x0, 0, z1), Vector3(x0, 0, z0)],
		[Vector2i(1, 0), Vector3(x1, 0, z0), Vector3(x1, 0, z1)],
	]
	for s in strony:
		var d: Vector2i = s[0]
		var n := k + d
		var a: Vector3 = s[1]
		var b: Vector3 = s[2]
		var key := _k(k, n)
		if komorki.has(n) and krawedzie.has(key):
			var e: Dictionary = krawedzie[key]
			if e["otwarte"]:
				# szerokie przejście z filarami po bokach
				_odcinek(mats[0], a, a.lerp(b, 0.12))
				_odcinek(mats[0], a.lerp(b, 0.88), b)
				_nadproze(mats[0], a.lerp(b, 0.12), a.lerp(b, 0.88), 2.45)
			else:
				var off: float = e["drzwi"]
				var pa := _punkt_na_krawedzi(a, b, off)
				var pb := _punkt_na_krawedzi(a, b, off + DRZWI_W)
				var p_lo := pa if a.distance_to(pa) < a.distance_to(pb) else pb
				var p_hi := pb if p_lo == pa else pa
				_odcinek(mats[0], a, p_lo)
				_odcinek(mats[0], p_hi, b)
				_nadproze(mats[0], p_lo, p_hi, DRZWI_H)
		else:
			# ściana pełna – na zewnątrz czasem okno
			var zewn := n.x < 0 or n.y < 0 or n.x >= GW or n.y >= GH or not komorki.has(n)
			if zewn and typ != "klatka" and rng.randf() < (0.35 if typ != "piwnica" else 0.25):
				var y0 := 0.95 if typ != "piwnica" else 1.7
				var y1 := 2.2 if typ != "piwnica" else 2.35
				var p1 := a.lerp(b, 0.4)
				var p2 := a.lerp(b, 0.6)
				_odcinek(mats[0], a, p1)
				_odcinek(mats[0], p2, b)
				_nadproze(mats[0], p1, p2, y1)
				_parapet(mats[0], p1, p2, y0)
				_okno(p1, p2, y0, y1, d, typ == "piwnica")
				okna.append([k, d])
			else:
				_odcinek(mats[0], a, b)


func _koord(a: Vector3, b: Vector3) -> float:
	return a.x if absf(a.x - b.x) > 0.01 else a.z


func _lo_wzdluz(a: Vector3, b: Vector3) -> float:
	return minf(a.x, b.x) if absf(a.x - b.x) > 0.01 else minf(a.z, b.z)


## Punkt na krawędzi w odległości "off" od początku komórki (niezależnie od kierunku a->b).
func _punkt_na_krawedzi(a: Vector3, b: Vector3, off: float) -> Vector3:
	if absf(a.x - b.x) > 0.01:
		var base: float = floor(minf(a.x, b.x) / C) * C
		return Vector3(base + off, 0, a.z)
	var base_z: float = floor(minf(a.z, b.z) / C) * C
	return Vector3(a.x, 0, base_z + off)


func _odcinek(mat: String, a: Vector3, b: Vector3) -> void:
	if a.distance_to(b) < 0.02:
		return
	bud.sciana(mat, a, b, 0.0, H, 0.75, _uv_sciany)


func _nadproze(mat: String, a: Vector3, b: Vector3, y0: float) -> void:
	bud.sciana(mat, a, b, y0, H, 0.75, _uv_sciany)


func _parapet(mat: String, a: Vector3, b: Vector3, y1: float) -> void:
	bud.sciana(mat, a, b, 0.0, y1, 0.75, _uv_sciany)


func _okno(a: Vector3, b: Vector3, y0: float, y1: float, d: Vector2i, krata: bool) -> void:
	var naz := Vector3(d.x, 0, d.y)
	var gl := naz * (T * 0.5 + 0.05)
	# szyba (lekko świecąca: noc za oknem)
	var pa := a + gl
	var pb := b + gl
	bud.quad("okno", [Vector3(pa.x, y0, pa.z), Vector3(pb.x, y0, pb.z), Vector3(pb.x, y1, pb.z), Vector3(pa.x, y1, pa.z)],
		[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	# ościeża
	for pair in [[a, a + gl], [b + gl, b]]:
		var p: Vector3 = pair[0]
		var q: Vector3 = pair[1]
		bud.quad("tynk_bialy", [Vector3(p.x, y0, p.z), Vector3(q.x, y0, q.z), Vector3(q.x, y1, q.z), Vector3(p.x, y1, p.z)],
			[Vector2(0, 1), Vector2(0.2, 1), Vector2(0.2, 0), Vector2(0, 0)])
	bud.quad("lastryko", [Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z), Vector3(b.x + gl.x, y0, b.z + gl.z), Vector3(a.x + gl.x, y0, a.z + gl.z)],
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.2), Vector2(0, 0.2)])
	bud.quad("tynk_bialy", [Vector3(a.x + gl.x, y1, a.z + gl.z), Vector3(b.x + gl.x, y1, b.z + gl.z), Vector3(b.x, y1, b.z), Vector3(a.x, y1, a.z)],
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.2), Vector2(0, 0.2)])
	var srodek := (a + b) * 0.5
	if krata:
		_mebel("krata", srodek + gl * 0.3 + Vector3.UP * y0, atan2(-naz.x, -naz.z), false)
	# zimne światło księżyca
	var l := OmniLight3D.new()
	l.light_color = Color(0.45, 0.52, 0.8)
	l.light_energy = 0.25
	l.omni_range = 3.5
	swiat.add_child(l)
	l.global_position = srodek - naz * 0.8 + Vector3.UP * (y0 + y1) * 0.5


## Kolizje ścian: dla każdej granicy komórek jeden zestaw brył (z otworami na drzwi).
func _sciany_wspolne() -> void:
	var granice := {}
	for k in komorki:
		for d in DIRS:
			var n: Vector2i = k + d
			var key := _k(k, n)
			if granice.has(key):
				continue
			granice[key] = true
			var pionowa: bool = d.x != 0   # granica wzdłuż osi z
			var stala: float = (k.x + (1 if d.x > 0 else 0)) * C if pionowa else (k.y + (1 if d.y > 0 else 0)) * C
			var base: float = (k.y * C) if pionowa else (k.x * C)
			var otwory := []
			if komorki.has(n) and krawedzie.has(key):
				var e: Dictionary = krawedzie[key]
				if e["otwarte"]:
					otwory.append([0.12 * C, 0.88 * C, 2.45])
				else:
					otwory.append([e["drzwi"], e["drzwi"] + DRZWI_W, DRZWI_H])
			_bryly_granicy(pionowa, stala, base, otwory)


func _bryly_granicy(pionowa: bool, stala: float, base: float, otwory: Array) -> void:
	var odcinki := []  # [od, do, y0]
	var pos := 0.0
	for o in otwory:
		odcinki.append([pos, o[0], 0.0])
		odcinki.append([o[0], o[1], o[2]])
		pos = o[1]
	odcinki.append([pos, C, 0.0])
	for od in odcinki:
		var dl: float = od[1] - od[0]
		if dl < 0.01:
			continue
		var y0: float = od[2]
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		var srodek_wzdl: float = base + (od[0] + od[1]) * 0.5
		if pionowa:
			bs.size = Vector3(T, H - y0, dl)
			cs.position = Vector3(stala, y0 + (H - y0) * 0.5, srodek_wzdl)
		else:
			bs.size = Vector3(dl, H - y0, T)
			cs.position = Vector3(srodek_wzdl, y0 + (H - y0) * 0.5, stala)
		cs.shape = bs
		cialo_scian.add_child(cs)


func _podloga_kolizja() -> void:
	for k in komorki:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(C, 0.4, C)
		cs.shape = bs
		cs.position = _srodek(k) + Vector3(0, -0.2, 0)
		cialo_scian.add_child(cs)


# ------------------------------------------------------------------ wyposażenie

func _drzwi_w_komorce(k: Vector2i) -> Array:
	## Prostokąty (xz) przed drzwiami/przejściami, które muszą zostać puste.
	var out := []
	for d in DIRS:
		var n: Vector2i = k + d
		var key := _k(k, n)
		if not (komorki.has(n) and krawedzie.has(key)):
			continue
		var e: Dictionary = krawedzie[key]
		var a: float = e["drzwi"] - 0.4
		var b: float = e["drzwi"] + DRZWI_W + 0.4
		if e["otwarte"]:
			a = 0.0
			b = C
		var x0 := k.x * C
		var z0 := k.y * C
		match d:
			Vector2i(1, 0): out.append(Rect2(x0 + C - 1.7, z0 + a, 1.7, b - a))
			Vector2i(-1, 0): out.append(Rect2(x0, z0 + a, 1.7, b - a))
			Vector2i(0, 1): out.append(Rect2(x0 + a, z0 + C - 1.7, b - a, 1.7))
			Vector2i(0, -1): out.append(Rect2(x0 + a, z0, b - a, 1.7))
	return out


func _wolne(k: Vector2i, r: Rect2, dodatkowe: Array) -> bool:
	var inner := Rect2(k.x * C + T, k.y * C + T, C - 2 * T, C - 2 * T)
	if not inner.encloses(r):
		return false
	for z in komorki[k]["zajete"]:
		if (z as Rect2).grow(0.12).intersects(r):
			return false
	for z in dodatkowe:
		if (z as Rect2).intersects(r):
			return false
	return true


func _wyposaz(k: Vector2i) -> void:
	var typ: String = komorki[k]["typ"]
	var drzwi := _drzwi_w_komorce(k)
	if k == _komorka_startu():
		drzwi.append(Rect2(start_pos.x - 1.0, start_pos.z - 1.0, 2.0, 2.0))
	for szablon in WYPOSAZENIE.get(typ, []):
		var ile := rng.randi_range(szablon[2], szablon[3])
		for i in ile:
			_umiesc(k, szablon[0], szablon[1], drzwi)
	_zapewnij_przejscie(k, drzwi)
	# dekoracyjne drzwi do zamkniętych mieszkań na ścianach korytarzy
	if typ in ["klatka", "korytarz"]:
		for d in DIRS:
			var n: Vector2i = k + d
			if komorki.has(n) and krawedzie.has(_k(k, n)):
				continue
			if rng.randf() < 0.6:
				_drzwi_dekoracyjne(k, d, drzwi)
	# punkty spawnu przeciwników
	if komorki[k]["glebokosc"] >= 2:
		for i in 3:
			for proba in 20:
				var p := Vector2(k.x * C + rng.randf_range(1.0, C - 1.0), k.y * C + rng.randf_range(1.0, C - 1.0))
				if _wolne(k, Rect2(p - Vector2(0.4, 0.4), Vector2(0.8, 0.8)), []):
					spawny.append({"pos": Vector3(p.x, 0.05, p.y), "komorka": k, "glebokosc": komorki[k]["glebokosc"]})
					break


## Usuwa meble, jeśli dzielą pomieszczenie tak, że nie da się przejść między drzwiami.
func _zapewnij_przejscie(k: Vector2i, drzwi: Array) -> void:
	for proba in 8:
		if _spojne(k, drzwi):
			return
		var lista: Array = komorki[k]["meble"]
		if lista.is_empty():
			return
		# najpierw usuwane meble stojące na środku
		var idx := -1
		for i in range(lista.size() - 1, -1, -1):
			if not lista[i]["przy_scianie"]:
				idx = i
				break
		if idx < 0:
			idx = lista.size() - 1
		var m: Dictionary = lista[idx]
		lista.remove_at(idx)
		komorki[k]["zajete"].erase(m["rect"])
		if is_instance_valid(m["node"]):
			# usunięcie z drzewa od razu: siatka nawigacji jest wypiekana jeszcze w tej klatce
			var nd: Node = m["node"]
			nd.get_parent().remove_child(nd)
			nd.queue_free()
		oslony = oslony.filter(func(o): return o["mebel"].distance_to(m["pos"]) > 0.01)


func _spojne(k: Vector2i, drzwi: Array) -> bool:
	var krok := 0.25
	var x0 := k.x * C + T
	var z0 := k.y * C + T
	var n := int((C - 2 * T) / krok)
	var zablok := PackedByteArray()
	zablok.resize(n * n)
	for ix in n:
		for iz in n:
			var p := Vector2(x0 + (ix + 0.5) * krok, z0 + (iz + 0.5) * krok)
			for r in komorki[k]["zajete"]:
				if (r as Rect2).grow(0.5).has_point(p):
					zablok[iz * n + ix] = 1
					break
	# punkty wejść: środki stref przed drzwiami
	var punkty := []
	for d in drzwi:
		var c: Vector2 = (d as Rect2).get_center()
		var ix := clampi(int((c.x - x0) / krok), 0, n - 1)
		var iz := clampi(int((c.y - z0) / krok), 0, n - 1)
		punkty.append(Vector2i(ix, iz))
	if punkty.size() < 2:
		return true
	var odw := PackedByteArray()
	odw.resize(n * n)
	var kol: Array = [punkty[0]]
	odw[punkty[0].y * n + punkty[0].x] = 1
	while not kol.is_empty():
		var c2: Vector2i = kol.pop_back()
		for dd in DIRS:
			var nb: Vector2i = c2 + dd
			if nb.x < 0 or nb.y < 0 or nb.x >= n or nb.y >= n:
				continue
			var i := nb.y * n + nb.x
			if odw[i] == 1 or zablok[i] == 1:
				continue
			odw[i] = 1
			kol.append(nb)
	for p in punkty:
		if odw[p.y * n + p.x] == 0:
			return false
	return true


## Punkty 1 m za każdymi drzwiami w głąb pomieszczenia (do sprawdzania spójności na siatce nawigacji).
func punkty_drzwi(k: Vector2i) -> Array:
	var pts := []
	for d in DIRS:
		var n: Vector2i = k + d
		var key := _k(k, n)
		if not krawedzie.has(key):
			continue
		var e: Dictionary = krawedzie[key]
		var srodek: float = (C * 0.5) if e["otwarte"] else (e["drzwi"] + DRZWI_W * 0.5)
		var c := Vector3(k.x * C, 0, k.y * C)
		match d:
			Vector2i(1, 0): pts.append(c + Vector3(C - 1.0, 0, srodek))
			Vector2i(-1, 0): pts.append(c + Vector3(1.0, 0, srodek))
			Vector2i(0, 1): pts.append(c + Vector3(srodek, 0, C - 1.0))
			Vector2i(0, -1): pts.append(c + Vector3(srodek, 0, 1.0))
	if k == _komorka_startu():
		pts.append(start_pos)
	return pts


## Usuwa mebel najbliżej środka pomieszczenia (naprawa podzielonego pomieszczenia). Zwraca false, gdy nie ma co usuwać.
func usun_srodkowy_mebel(k: Vector2i) -> bool:
	var lista: Array = komorki[k]["meble"]
	if lista.is_empty():
		return false
	var srodek := _srodek(k)
	var best := 0
	var bd := INF
	for i in lista.size():
		var d: float = (lista[i]["pos"] as Vector3).distance_to(srodek) + (2.0 if lista[i]["przy_scianie"] else 0.0)
		if d < bd:
			bd = d
			best = i
	var m: Dictionary = lista[best]
	lista.remove_at(best)
	komorki[k]["zajete"].erase(m["rect"])
	oslony = oslony.filter(func(o): return o["mebel"].distance_to(m["pos"]) > 0.01)
	if is_instance_valid(m["node"]):
		var nd: Node = m["node"]
		nd.get_parent().remove_child(nd)
		nd.queue_free()
	return true


func _komorka_startu() -> Vector2i:
	return Vector2i(int(start_pos.x / C), int(start_pos.z / C))


func _umiesc(k: Vector2i, id: String, przy_scianie: bool, drzwi: Array) -> void:
	if not meble.has(id):
		return
	var roz: Array = meble[id]["rozmiar"]
	var w := float(roz[0])
	var dgl := float(roz[2])
	for proba in 30:
		var rot := 0.0
		var pos := Vector2.ZERO
		var fw := w
		var fd := dgl
		if przy_scianie:
			var d: Vector2i = DIRS[rng.randi() % 4]
			var wzdl := rng.randf_range(T + w * 0.5 + 0.1, C - T - w * 0.5 - 0.1)
			var odsc := T + dgl * 0.5 + 0.02
			match d:
				Vector2i(0, -1):
					pos = Vector2(k.x * C + wzdl, k.y * C + odsc); rot = 0.0
				Vector2i(0, 1):
					pos = Vector2(k.x * C + wzdl, (k.y + 1) * C - odsc); rot = PI
				Vector2i(-1, 0):
					pos = Vector2(k.x * C + odsc, k.y * C + wzdl); rot = PI / 2.0
				Vector2i(1, 0):
					pos = Vector2((k.x + 1) * C - odsc, k.y * C + wzdl); rot = -PI / 2.0
			if d.x != 0:
				fw = dgl
				fd = w
		else:
			pos = Vector2(k.x * C + rng.randf_range(1.2, C - 1.2), k.y * C + rng.randf_range(1.2, C - 1.2))
			if rng.randf() < 0.5:
				rot = PI / 2.0
				fw = dgl
				fd = w
			rot += rng.randf_range(-0.12, 0.12) if id in ["skrzynia", "beczka", "krzeslo", "worki_piasek"] else 0.0
		var r := Rect2(pos - Vector2(fw, fd) * 0.5, Vector2(fw, fd))
		var montowany := id in MONTOWANE_NA_SCIANIE
		if not _wolne(k, r, [] if montowany else drzwi):
			continue
		if montowany and _koliduje_z_otworem(k, r):
			continue
		if id != "dywan":
			komorki[k]["zajete"].append(r)
		var y := 0.0
		match id:
			"hydrant": y = 0.9
			"tablica_ogloszen": y = 1.25
			"apteczka_scienna": y = 1.3
			"skrzynki_pocztowe": y = 1.1
			"kaloryfer": y = 0.12
		var node := _mebel(id, Vector3(pos.x, y, pos.y), rot, true, k)
		if id != "dywan" and not montowany:
			komorki[k]["meble"].append({"rect": r, "node": node, "przy_scianie": przy_scianie, "pos": Vector3(pos.x, y, pos.y)})
		return


func _koliduje_z_otworem(k: Vector2i, r: Rect2) -> bool:
	for z in _drzwi_w_komorce(k):
		if (z as Rect2).grow(0.15).intersects(r):
			return true
	return false


func _mebel(id: String, pos: Vector3, rot: float, z_kolizja := true, k := Vector2i(-1, -1)) -> Node3D:
	var path := "res://assets/models/meble/%s.glb" % id
	if not ResourceLoader.exists(path):
		path = "res://assets/models/%s.glb" % id
	var inst: Node3D = load(path).instantiate()
	var info: Dictionary = meble.get(id, {"rozmiar": [0.5, 0.5, 0.5], "oslona": null, "pojemnik": null, "nazwa": id})
	var roz: Array = info["rozmiar"]
	var korzen: Node3D
	if info.get("pojemnik") != null and z_kolizja and k.x >= 0:
		var pj := Pojemnik.new()
		pj.nazwa = info["nazwa"]
		var sw := 4
		var sh := 3
		match String(info["pojemnik"]):
			"skrzynia_wojskowa": sw = 5; sh = 3
			"szafa", "regal": sw = 5; sh = 4
			"apteczka_scienna": sw = 3; sh = 2
		pj.siatka = Siatka.new(sw, sh)
		pj.wypelnij(info["pojemnik"], rng.randi_range(1, 4), rng)
		if id in MONTOWANE_NA_SCIANIE:
			pj.collision_layer = Balistyka.WARSTWA_INTERAKCJE   # nie blokuje przejść
		korzen = pj
	elif z_kolizja and id not in BEZ_KOLIZJI:
		var sb := StaticBody3D.new()
		sb.collision_layer = Balistyka.WARSTWA_SWIAT
		korzen = sb
	else:
		korzen = Node3D.new()
	korzen.name = id.to_pascal_case()
	korzen.add_child(inst)
	if korzen is CollisionObject3D:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(float(roz[0]), maxf(0.1, float(roz[1])), float(roz[2]))
		cs.shape = bs
		cs.position = Vector3(0, float(roz[1]) * 0.5, 0)
		korzen.add_child(cs)
	swiat.add_child(korzen)
	korzen.position = pos
	korzen.rotation.y = rot
	# punkty osłon wokół mebli dających osłonę
	if info.get("oslona") != null and k.x >= 0:
		var niska: bool = info["oslona"] == "niska"
		var basis := Basis(Vector3.UP, rot)
		for off in [Vector3(0, 0, float(roz[2]) * 0.5 + 0.45), Vector3(0, 0, -float(roz[2]) * 0.5 - 0.45),
				Vector3(float(roz[0]) * 0.5 + 0.45, 0, 0), Vector3(-float(roz[0]) * 0.5 - 0.45, 0, 0)]:
			var p: Vector3 = pos + basis * off
			var r := Rect2(Vector2(p.x, p.z) - Vector2(0.25, 0.25), Vector2(0.5, 0.5))
			if _wolne(k, r, []):
				oslony.append({"pos": Vector3(p.x, 0.05, p.z), "niska": niska, "mebel": pos})
	return korzen


func _drzwi_dekoracyjne(k: Vector2i, d: Vector2i, drzwi: Array) -> void:
	var modele := ["drzwi_skaj_12", "drzwi_skaj_13", "drzwi_skaj_14"]
	for proba in 10:
		var wzdl := rng.randf_range(0.9, C - 0.9)
		var pos: Vector3
		var rot := 0.0
		var r: Rect2
		match d:
			Vector2i(0, -1):
				pos = Vector3(k.x * C + wzdl, 0, k.y * C + T * 0.5 + 0.1); rot = 0.0
				r = Rect2(pos.x - 0.6, pos.z, 1.2, 0.5)
			Vector2i(0, 1):
				pos = Vector3(k.x * C + wzdl, 0, (k.y + 1) * C - T * 0.5 - 0.1); rot = PI
				r = Rect2(pos.x - 0.6, pos.z - 0.5, 1.2, 0.5)
			Vector2i(-1, 0):
				pos = Vector3(k.x * C + T * 0.5 + 0.1, 0, k.y * C + wzdl); rot = PI / 2.0
				r = Rect2(pos.x, pos.z - 0.6, 0.5, 1.2)
			Vector2i(1, 0):
				pos = Vector3((k.x + 1) * C - T * 0.5 - 0.1, 0, k.y * C + wzdl); rot = -PI / 2.0
				r = Rect2(pos.x - 0.5, pos.z - 0.6, 0.5, 1.2)
		if not _wolne(k, r, []):
			continue
		komorki[k]["zajete"].append(r)
		var inst: Node3D = load("res://assets/models/%s.glb" % modele[rng.randi() % 3]).instantiate()
		swiat.add_child(inst)
		inst.position = pos
		inst.rotation.y = rot
		return


func _lampa(k: Vector2i) -> void:
	var typ: String = komorki[k]["typ"]
	var start := k == _komorka_startu()
	if not start and rng.randf() < 0.25:
		return
	var gola := typ in ["piwnica", "magazyn", "warsztat"]
	var pos := _srodek(k) + Vector3(rng.randf_range(-0.5, 0.5), H, rng.randf_range(-0.5, 0.5))
	var model: Node3D = load("res://assets/models/meble/zarowka.glb" if gola else "res://assets/models/plafon.glb").instantiate()
	swiat.add_child(model)
	model.position = pos
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.78, 0.52) if not gola else Color(1.0, 0.72, 0.45)
	l.light_energy = 1.5 if not gola else 1.3
	l.omni_range = 7.0
	l.omni_attenuation = 0.9
	l.shadow_enabled = false
	swiat.add_child(l)
	l.position = pos + Vector3(0, -0.45 if not gola else -0.7, 0)
	var awaria := 0.0
	var r := rng.randf()
	if not start:
		if r < 0.18:
			awaria = 1.0
		elif r < 0.45:
			awaria = rng.randf_range(0.25, 0.75)
		else:
			awaria = 0.04
	l.set_script(load("res://scripts/swiat/migotanie.gd"))
	l.set("awaria", awaria)
	l.set("plafon", l.get_path_to(model))
	lampy.append(l)


# ------------------------------------------------------------------ wyjścia

func _wyjscia() -> void:
	# komórki posortowane od najgłębszej
	var lista := komorki.keys()
	lista.sort_custom(func(a, b): return komorki[a]["glebokosc"] > komorki[b]["glebokosc"])
	var glowna: Vector2i = lista[0]
	_wyjscie_drzwi(glowna, "glowne", "Brama na podwórze", 8.0)
	# wyjście przez piwnicę na klucz
	var piwnica := Vector2i(-1, -1)
	for k in lista:
		if k != glowna and komorki[k]["typ"] == "piwnica":
			piwnica = k
			break
	if piwnica.x < 0:
		piwnica = lista[mini(1, lista.size() - 1)]
		komorki[piwnica]["typ"] = "piwnica"
	_wyjscie_drzwi(piwnica, "klucz", "Piwnica nr 7", 5.0)
	# wyjście czasowe przez okno na rusztowanie
	var kandydaci := okna.filter(func(o): return o[0] != glowna and o[0] != piwnica and komorki[o[0]]["glebokosc"] >= 2)
	if not kandydaci.is_empty():
		var o: Array = kandydaci[rng.randi() % kandydaci.size()]
		var ew := Ewakuacja.new()
		ew.nazwa = "Okno na rusztowanie"
		ew.typ = "czasowe"
		ew.czas_odliczania = 6.0
		ew.okno_od = rng.randf_range(240.0, 540.0)
		ew.okno_do = ew.okno_od + 150.0
		_strefa(ew, _srodek(o[0]) + Vector3(o[1].x, 0, o[1].y) * (C * 0.5 - 1.0), Vector3(2.2, 2.0, 2.2))
		wyjscia.append(ew)


func _wyjscie_drzwi(k: Vector2i, typ: String, nazwa: String, czas: float) -> void:
	# ściana bez przejścia, najlepiej zewnętrzna
	var strona := Vector2i.ZERO
	for d in DIRS:
		var n: Vector2i = k + d
		if not (komorki.has(n) and krawedzie.has(_k(k, n))):
			strona = d
			if not komorki.has(n):
				break
	if strona == Vector2i.ZERO:
		strona = Vector2i(1, 0)
	var srodek := _srodek(k)
	var naz := Vector3(strona.x, 0, strona.y)
	var poz_sciany := srodek + naz * (C * 0.5 - T * 0.5)
	var rot := atan2(-naz.x, -naz.z)
	# drzwi (model) wysunięte ze ściany
	var model := "drzwi_piwnica"
	var inst: Node3D = load("res://assets/models/%s.glb" % model).instantiate()
	swiat.add_child(inst)
	inst.position = poz_sciany - naz * 0.1
	inst.rotation.y = rot
	var znak := _mebel("znak_wyjscie", poz_sciany - naz * 0.06 + Vector3.UP * 2.25, rot, false)
	var zielone := OmniLight3D.new()
	zielone.light_color = Color(0.3, 1.0, 0.45)
	zielone.light_energy = 0.5
	zielone.omni_range = 3.0
	swiat.add_child(zielone)
	zielone.global_position = znak.global_position - naz * 0.4
	var ew := Ewakuacja.new()
	ew.nazwa = nazwa
	ew.typ = typ
	ew.czas_odliczania = czas
	_strefa(ew, poz_sciany - naz * 1.1, Vector3(2.4, 2.2, 2.4))
	wyjscia.append(ew)
	if typ == "klucz":
		ew.otwarte = false
		ew.wymagany_klucz = "wyjscie_piwnica"
		var dk := Ewakuacja.DrzwiNaKlucz.new()
		dk.wyjscie = ew
		dk.klucz = "klucz_piwnica"
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.2, 2.2, 0.3)
		cs.shape = bs
		cs.position.y = 1.1
		dk.add_child(cs)
		swiat.add_child(dk)
		dk.position = poz_sciany - naz * 0.3
		dk.rotation.y = rot
		inst.reparent(dk)
		# wejście do strefy blokuje dopiero otwarcie: strefa za drzwiami
		ew.position = poz_sciany - naz * 1.1


func _strefa(ew: Ewakuacja, pos: Vector3, rozmiar: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = rozmiar
	cs.shape = bs
	cs.position.y = rozmiar.y * 0.5
	ew.add_child(cs)
	swiat.add_child(ew)
	ew.position = pos


## Gwarantuje (z dużym prawdopodobieństwem) jeden klucz do piwnicy w pojemniku biurowym lub szafie.
func _klucz_w_rajdzie() -> void:
	if rng.randf() > 0.75:
		return
	var kandydaci := []
	for n in swiat.get_children():
		if n is Pojemnik and n.nazwa in ["Biurko", "Szafa", "Szafka ubraniowa", "Meblościanka"]:
			kandydaci.append(n)
	if kandydaci.is_empty():
		return
	var pj: Pojemnik = kandydaci[rng.randi() % kandydaci.size()]
	pj.siatka.dodaj(Przedmiot.nowy("klucz_piwnica"))
