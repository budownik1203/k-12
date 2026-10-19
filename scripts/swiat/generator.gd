class_name GeneratorBiomu
extends RefCounted
## Generator rajdu w biomie 1 (blokowisko). Siatka komórek 9x9 m: część to korytarze, część pomieszczenia.
## Każde pomieszczenie jest prostokątem wewnątrz swojej komórki, między pomieszczeniami stoi lity mur.
## Przejścia: korytarze (szerokie, pełnej wysokości) i drzwi w grubych ścianach. Meble ustawiane zestawami
## (ciągi przy ścianach, stół z krzesłami, rzędy biurek, regały, skupiska skrzyń), lampy, spawny i wyjścia.

const C := 9.0           # rozmiar komórki w metrach
const H := 3.0           # wysokość pomieszczeń
const STROP := 0.6       # grubość stropu między kondygnacjami (lity, kule nie przechodzą)
const PIETRO_H := H + STROP   # wysokość kondygnacji (podłoga do podłogi)
const T := 0.3           # grubość brył kolizji za licem ściany
const GRUB := 0.45       # grubość muru, w którym są drzwi z korytarza
const DRZWI_W := 1.2
const DRZWI_H := 2.1
const KW := 3.2          # szerokość korytarza
const MARGINES := 0.35   # minimalny odstęp pomieszczenia od granicy komórki
const GW := 11   # ok. 100 x 72 m: rajd na 25–40 minut zwiadu (skala jak mapa w Tarkovie, ale jedno piętro)
const GH := 8

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const ROT := {Vector2i(0, -1): 0.0, Vector2i(0, 1): PI, Vector2i(-1, 0): PI / 2.0, Vector2i(1, 0): -PI / 2.0}

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
# rozmiary pomieszczeń [min, max] boku
const ROZMIARY := {
	"klatka": [7.0, 7.8], "pokoj": [6.0, 8.2], "kuchnia": [5.6, 7.0], "administracja": [6.2, 8.3],
	"piwnica": [5.8, 8.0], "magazyn": [7.0, 8.3], "warsztat": [6.4, 8.3],
}
const MONTOWANE_NA_SCIANIE := ["hydrant", "tablica_ogloszen", "apteczka_scienna", "skrzynki_pocztowe", "kaloryfer", "znak_wyjscie"]
const BEZ_KOLIZJI := ["dywan", "zarowka", "hydrant", "tablica_ogloszen", "apteczka_scienna", "skrzynki_pocztowe", "znak_wyjscie", "kaloryfer"]
const WYSOKOSC_MONTAZU := {"hydrant": 0.9, "tablica_ogloszen": 1.3, "apteczka_scienna": 1.3, "skrzynki_pocztowe": 1.1, "kaloryfer": 0.12}

var rng := RandomNumberGenerator.new()
var swiat: Node3D
var meble := {}
var drzwi_miejsca: Array = []   # miejsca na skrzydła drzwi (stawiane po wypieczeniu nawigacji)
var komorki := {}        # Vector2i -> {"typ", "glebokosc", "rect", "otwory", "okna", "strefy", "zajete", "meble", "mats"}
var krawedzie := {}      # "a|b" -> {"a", "b", "otwarte", "c" (środek przejścia), "pa", "pb" (punkty po obu stronach)}
var bud := Kit.Budowniczy.new()
var cialo_scian: StaticBody3D
var oslony: Array = []   # {"pos": Vector3, "niska": bool, "mebel": Vector3}
var spawny: Array = []   # {"pos": Vector3, "komorka": Vector2i, "glebokosc": int}
var wyjscia: Array = []
var lampy: Array = []
var start_pos := Vector3.ZERO
var start_rot := 0.0
var okna: Array = []     # [komorka, strona, punkt na licu (Vector3)]
var _plan_wyjsc: Array = []
var posterunki: Array = []   # {"pos": Vector3, "kier": Vector3, "komorka": Vector2i, "miejsca": [Vector3, ...]}
var _plan_posterunkow := {}  # komórka -> true
var pietro := 0              # 0 – parter (wyjścia, start), 1 – piętro (bez wyjść)
var wym_sy := -1             # piętro: klatka w tym samym rzędzie co na parterze
var wym_rect_klatki := Rect2()
var schody := {}             # {"x0","x1","z0","z1","otwor": Rect2} – bieg schodów w klatce i otwór w stropie


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
	_prostokaty()
	_plan_schodow()
	_przejscia()
	_plan_okien()
	if pietro == 0:
		_zaplanuj_wyjscia()
	_zaplanuj_posterunki()
	# geometria osobno dla każdego pomieszczenia: renderer Compatibility oświetla obiekt
	# co najwyżej kilkoma światłami, więc jeden obiekt na cały poziom gasiłby dalsze lampy
	for k in komorki:
		bud = Kit.Budowniczy.new()
		if komorki[k]["typ"] == "korytarz":
			_korytarz(k)
		else:
			_pomieszczenie(k)
		var mi := MeshInstance3D.new()
		mi.name = "Pomieszczenie_%d_%d" % [k.x, k.y]
		mi.mesh = bud.zbuduj({"okno": 0.5})
		swiat.add_child(mi)
	for k in komorki:
		_wyposaz(k)
		_lampa(k)
	if pietro == 0:
		_wyjscia()
	else:
		_klucz_w_rajdzie()     # klucz do piwnicy leży na piętrze – powód, żeby iść na górę
	return {"start": start_pos, "start_rot": start_rot, "oslony": oslony, "spawny": spawny,
		"wyjscia": wyjscia, "komorki": komorki, "lampy": lampy, "posterunki": posterunki, "drzwi": drzwi_miejsca}


# ------------------------------------------------------------------ układ (graf)

func _k(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]


func _w_siatce(n: Vector2i) -> bool:
	return n.x >= 0 and n.y >= 0 and n.x < GW and n.y < GH


func _nowa(k: Vector2i, typ: String) -> void:
	komorki[k] = {"typ": typ, "glebokosc": 0, "zajete": [], "meble": []}


func _polacz(a: Vector2i, b: Vector2i) -> void:
	if not krawedzie.has(_k(a, b)):
		krawedzie[_k(a, b)] = {"a": a, "b": b, "otwarte": false}


func _rozlacz(a: Vector2i, b: Vector2i) -> void:
	krawedzie.erase(_k(a, b))


func _korytarz_w(k: Vector2i) -> bool:
	return komorki.has(k) and komorki[k]["typ"] == "korytarz"


## Kierunki, w których komórka ma przejście.
func _ramiona(k: Vector2i) -> Array:
	var out := []
	for d in DIRS:
		if komorki.has(k + d) and krawedzie.has(_k(k, k + d)):
			out.append(d)
	return out


## Sieć korytarzy (raz gęsta, raz skąpa), do niej doczepione pomieszczenia.
## Część pomieszczeń prowadzi dalej do kolejnych, czasem dwa sąsiednie pokoje łączą drzwi.
func _uklad() -> void:
	var sy := rng.randi_range(1, GH - 2)
	if wym_sy >= 0:
		sy = wym_sy
	var start := Vector2i(0, sy)
	_nowa(start, "klatka")
	var lacznie := rng.randi_range(52, 64)
	var udzial := rng.randf_range(0.3, 0.5)
	var cel_kor := int(round(lacznie * udzial))
	var k0 := Vector2i(1, sy)
	_nowa(k0, "korytarz")
	_polacz(start, k0)
	var kor: Array = [k0]
	var ostatni := k0
	var kier := Vector2i(1, 0)
	var proby := 0
	while kor.size() < cel_kor and proby < 3000:
		proby += 1
		var z: Vector2i = ostatni if rng.randf() < 0.6 else kor[rng.randi() % kor.size()]
		var d: Vector2i = kier if (z == ostatni and rng.randf() < 0.55) else DIRS[rng.randi() % 4]
		var n := z + d
		if not _w_siatce(n) or komorki.has(n):
			continue
		var inne := []
		for dd in DIRS:
			var m: Vector2i = n + dd
			if m != z and _korytarz_w(m):
				inne.append(m)
		if inne.size() > 1:
			continue
		if inne.size() == 1:
			var naroznik: Vector2i = z + inne[0] - n
			if _korytarz_w(naroznik) or rng.randf() > 0.3:
				continue
		_nowa(n, "korytarz")
		_polacz(z, n)
		for m in inne:
			_polacz(n, m)
		kor.append(n)
		ostatni = n
		kier = d
	var cel_pok := maxi(26, lacznie - kor.size())
	var pokoje: Array = []
	var kand: Array = []
	for c in kor:
		for d in DIRS:
			var n: Vector2i = c + d
			if _w_siatce(n) and not komorki.has(n) and not kand.has(n):
				kand.append(n)
	_tasuj(kand)
	for n in kand:
		if pokoje.size() >= cel_pok:
			break
		var przy := []
		for d in DIRS:
			if _korytarz_w(n + d):
				przy.append(n + d)
		_nowa(n, "")
		pokoje.append(n)
		_tasuj(przy)
		_polacz(n, przy[0])
		if przy.size() > 1 and rng.randf() < 0.2:
			_polacz(n, przy[1])
	var glebsze := rng.randi_range(1, 3)
	for proba in 60:
		if glebsze <= 0 or pokoje.is_empty():
			break
		var r: Vector2i = pokoje[rng.randi() % pokoje.size()]
		var n: Vector2i = r + DIRS[rng.randi() % 4]
		if not _w_siatce(n) or komorki.has(n):
			continue
		_nowa(n, "")
		pokoje.append(n)
		_polacz(r, n)
		glebsze -= 1
	for a in pokoje:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var b: Vector2i = a + d
			if komorki.has(b) and komorki[b]["typ"] == "" and not krawedzie.has(_k(a, b)) and rng.randf() < 0.18:
				_polacz(a, b)
	var zmiana := true
	while zmiana:
		zmiana = false
		for c in komorki.keys():
			if c == k0 or not _korytarz_w(c):
				continue
			var r := _ramiona(c)
			if r.size() <= 1:
				for d in r:
					_rozlacz(c, c + d)
				komorki.erase(c)
				zmiana = true
	for key in krawedzie:
		var e: Dictionary = krawedzie[key]
		if not _korytarz_w(e["a"]) and not _korytarz_w(e["b"]):
			e["otwarte"] = rng.randf() < 0.12 and komorki[e["a"]]["typ"] != "klatka" and komorki[e["b"]]["typ"] != "klatka"
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


func _tasuj(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _typy() -> void:
	var maxg := 1
	for a in komorki:
		maxg = maxi(maxg, komorki[a]["glebokosc"])
	for a in komorki:
		var f := float(komorki[a]["glebokosc"]) / maxg
		if komorki[a]["typ"] == "korytarz":
			komorki[a]["mats"] = ["cegla", "beton", "beton"] if f > 0.6 else MATERIALY["korytarz"]
			continue
		if komorki[a]["typ"] == "":
			var tab: Array
			if f < 0.45:
				tab = [["pokoj", 34], ["kuchnia", 22], ["administracja", 14], ["warsztat", 8], ["magazyn", 4]]
			else:
				tab = [["pokoj", 14], ["piwnica", 30], ["magazyn", 22], ["warsztat", 16], ["administracja", 12]]
			komorki[a]["typ"] = Dane.losuj(tab, rng)
			if pietro > 0 and komorki[a]["typ"] == "piwnica":
				komorki[a]["typ"] = "magazyn" if rng.randf() < 0.5 else "pokoj"
		komorki[a]["mats"] = MATERIALY[komorki[a]["typ"]]


## Prostokąty wnętrz: korytarz to kwadrat KW na środku komórki, pomieszczenie – losowy prostokąt,
## który zawsze obejmuje oś komórki (żeby drzwi z korytarza trafiały w ścianę).
func _prostokaty() -> void:
	for k in komorki:
		var ox: float = k.x * C
		var oz: float = k.y * C
		var r: Rect2
		if komorki[k]["typ"] == "korytarz":
			r = Rect2(ox + (C - KW) * 0.5, oz + (C - KW) * 0.5, KW, KW)
		else:
			var zakres: Array = ROZMIARY.get(komorki[k]["typ"], [6.0, 8.0])
			var wx := rng.randf_range(zakres[0], zakres[1])
			var wz := rng.randf_range(zakres[0], zakres[1])
			var x0 := rng.randf_range(maxf(MARGINES, C * 0.5 + 1.6 - wx), minf(C * 0.5 - 1.6, C - MARGINES - wx))
			var z0 := rng.randf_range(maxf(MARGINES, C * 0.5 + 1.6 - wz), minf(C * 0.5 - 1.6, C - MARGINES - wz))
			r = Rect2(ox + x0, oz + z0, wx, wz)
		komorki[k]["rect"] = r
		komorki[k]["otwory"] = {Vector2i(1, 0): [], Vector2i(-1, 0): [], Vector2i(0, 1): [], Vector2i(0, -1): []}
		komorki[k]["okna"] = []
		komorki[k]["strefy"] = []
		komorki[k]["ramiona"] = []
	var start := Vector2i(0, 0)
	for k in komorki:
		if komorki[k]["typ"] == "klatka":
			start = k
	if wym_rect_klatki.size.x > 0.0:
		komorki[start]["rect"] = wym_rect_klatki
	var rs: Rect2 = komorki[start]["rect"]
	start_pos = Vector3(rs.position.x + 1.3, 0.05, rs.get_center().y)
	start_rot = -PI / 2.0
	komorki[start]["strefy"].append(Rect2(start_pos.x - 1.0, start_pos.z - 1.0, 2.0, 2.0))


# ------------------------------------------------------------------ schody (klatka)

## Bieg schodów przy ścianie klatki dalszej od drzwi na korytarz; otwór w stropie nad górną częścią biegu.
func _plan_schodow() -> void:
	var k := _komorka_klatki()
	if k.x < 0:
		return
	var rs: Rect2 = komorki[k]["rect"]
	var c := k.y * C + C * 0.5            # oś komórki (drzwi na korytarz leżą na niej)
	var dl := minf(5.2, rs.size.x - 1.8)     # na dole 0,8 m dojścia, u góry ≥ 1 m podestu do ściany
	var x0 := rs.position.x + 0.8
	var szer := 1.25
	var z0: float
	if c - rs.position.y > rs.end.y - c:
		z0 = rs.position.y + 0.06
	else:
		z0 = rs.end.y - 0.06 - szer
	var x1 := x0 + dl
	var otw := Rect2(x0 + dl * 0.2, minf(z0, rs.position.y) if z0 - rs.position.y < 0.2 else z0 - 0.05, x1 - (x0 + dl * 0.2) + 0.04, 0.0)
	# otwór sięga do ściany po stronie biegu
	if z0 - rs.position.y < 0.2:
		otw = Rect2(x0 + dl * 0.2, rs.position.y, x1 + 0.04 - (x0 + dl * 0.2), z0 + szer + 0.08 - rs.position.y)
	else:
		otw = Rect2(x0 + dl * 0.2, z0 - 0.08, x1 + 0.04 - (x0 + dl * 0.2), rs.end.y - (z0 - 0.08))
	schody = {"x0": x0, "x1": x1, "z0": z0, "z1": z0 + szer, "otwor": otw, "k": k}
	komorki[k]["strefy"].append(Rect2(x0 - 0.3, z0 - 0.1, dl + 0.9, szer + 0.9) if z0 - rs.position.y < 0.2 else Rect2(x0 - 0.3, z0 - 0.8, dl + 0.9, szer + 0.9))


func _komorka_klatki() -> Vector2i:
	for k in komorki:
		if komorki[k]["typ"] == "klatka":
			return k
	return Vector2i(-1, -1)


## Prostokąt r bez prostokąta h (do 4 kawałków).
func _bez(r: Rect2, h: Rect2) -> Array:
	var i := r.intersection(h)
	if i.size.x <= 0.0 or i.size.y <= 0.0:
		return [r]
	var out := []
	if i.position.y > r.position.y:
		out.append(Rect2(r.position.x, r.position.y, r.size.x, i.position.y - r.position.y))
	if i.end.y < r.end.y:
		out.append(Rect2(r.position.x, i.end.y, r.size.x, r.end.y - i.end.y))
	if i.position.x > r.position.x:
		out.append(Rect2(r.position.x, i.position.y, i.position.x - r.position.x, i.size.y))
	if i.end.x < r.end.x:
		out.append(Rect2(i.end.x, i.position.y, r.end.x - i.end.x, i.size.y))
	return out


## Klatka: na parterze bieg schodów i otwór w suficie; na piętrze otwór w podłodze z balustradą
## i obramowaniem grubości stropu.
func _klatka_schody(k: Vector2i, mats: Array, r: Rect2) -> void:
	var otw: Rect2 = schody["otwor"]
	if pietro == 0:
		bud.plaszczyzna(mats[1], r.position.x, r.position.y, r.end.x, r.end.y, 0.0, true, 1.5, 1.0)
		for kaw in _bez(r, otw):
			bud.plaszczyzna(mats[2], kaw.position.x, kaw.position.y, kaw.end.x, kaw.end.y, H, false, 1.5, 1.0)
		_podloga(r, false)
		for kaw in _bez(r, otw):
			_sufit_kolizja(kaw)
		_bieg_schodow()
	else:
		for kaw in _bez(r, otw):
			bud.plaszczyzna(mats[1], kaw.position.x, kaw.position.y, kaw.end.x, kaw.end.y, 0.0, true, 1.5, 1.0)
		bud.plaszczyzna(mats[2], r.position.x, r.position.y, r.end.x, r.end.y, H, false, 1.5, 1.0)
		for kaw in _bez(r, otw):
			_podloga(kaw, false)
		_sufit_kolizja(r)
		# obramowanie otworu (grubość stropu widać z dołu) i balustrada
		var a := Vector2(otw.position.x, otw.position.y)
		var b := Vector2(otw.end.x, otw.position.y)
		var c2 := Vector2(otw.end.x, otw.end.y)
		var d := Vector2(otw.position.x, otw.end.y)
		for e in [[a, b, Vector2(0, 1)], [b, c2, Vector2(-1, 0)], [c2, d, Vector2(0, -1)], [d, a, Vector2(1, 0)]]:
			_scianka("beton", e[0], e[1], e[2], false, -STROP, 0.0)
		_balustrada(otw, r)


## Bieg schodów: stopnie z lastryka na żelbetowej płycie, policzek od strony pokoju, poręcz;
## kolizja – gładka rampa (dla nóg i nawigacji).
func _bieg_schodow() -> void:
	var B := preload("res://scripts/core/bryly.gd")
	var x0: float = schody["x0"]
	var x1: float = schody["x1"]
	var z0: float = schody["z0"]
	var z1: float = schody["z1"]
	var dl := x1 - x0
	var n := 18
	var stop := PIETRO_H / n
	var biez := dl / n
	var cz := []
	for i in n:
		var y := (i + 1) * stop
		cz.append({"t": "box", "c": Vector3(x0 + (i + 0.5) * biez, y - stop * 0.5 - 0.07, (z0 + z1) * 0.5), "s": Vector3(biez + 0.01, stop + 0.14, z1 - z0), "m": "lastryko_m", "k": Color(0.75, 0.72, 0.68), "f": 0.01})
	# płyta pod stopniami (skośna) i policzek
	var kat := atan2(PIETRO_H, dl)
	var dlp := sqrt(dl * dl + PIETRO_H * PIETRO_H)
	var srp := Vector3((x0 + x1) * 0.5, PIETRO_H * 0.5 - 0.22, (z0 + z1) * 0.5)
	cz.append({"t": "box", "c": srp, "s": Vector3(dlp, 0.16, z1 - z0), "m": "lastryko_m", "k": Color(0.6, 0.58, 0.55), "f": 0.0, "r": Vector3(0, 0, rad_to_deg(kat))})
	var zp := z1 if schody["z0"] - (komorki[schody["k"]]["rect"] as Rect2).position.y < 0.2 else z0
	# poręcz: słupki i pochwyt od strony pokoju
	for i in range(0, n + 1, 3):
		var x := x0 + i * biez
		var y := i * stop
		cz.append(B.walec(Vector3(x, y, zp), Vector3(x, y + 0.95, zp), 0.015, 0.015, "metal_ciemny_m", 6))
	cz.append(B.walec(Vector3(x0, 0.95, zp), Vector3(x1, PIETRO_H + 0.95, zp), 0.025, 0.025, "drewno_m", 8))
	var mi := B.instancja(cz, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	swiat.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(dlp + 0.1, 0.2, z1 - z0)
	cs.shape = bs
	cs.position = Vector3((x0 + x1) * 0.5, PIETRO_H * 0.5 - 0.1, (z0 + z1) * 0.5)
	cs.rotation.z = kat
	cialo_scian.add_child(cs)
	# podest u góry (krótki pas podłogi przy krawędzi stropu) dla płynnego wejścia
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(0.3, 0.2, z1 - z0)
	cs2.shape = bs2
	cs2.position = Vector3(x1 + 0.1, PIETRO_H - 0.1, (z0 + z1) * 0.5)
	cialo_scian.add_child(cs2)


## Balustrada wokół otworu na piętrze (od strony pokoju i od dołu biegu); wejście na schody zostaje wolne.
func _balustrada(otw: Rect2, r: Rect2) -> void:
	var B := preload("res://scripts/core/bryly.gd")
	var cz := []
	var przy_scianie_dol := otw.position.y - r.position.y < 0.1
	var zb := otw.end.y if przy_scianie_dol else otw.position.y     # bok od strony pokoju
	var odcinki := [[Vector2(otw.position.x, zb), Vector2(otw.end.x - 0.45, zb)],
		[Vector2(otw.position.x, otw.position.y), Vector2(otw.position.x, otw.end.y)]]
	for o in odcinki:
		var a: Vector2 = o[0]
		var b: Vector2 = o[1]
		var dlo := a.distance_to(b)
		var ile := int(dlo / 0.12)
		for i in ile + 1:
			var p := a.lerp(b, float(i) / maxf(1.0, ile))
			cz.append(B.walec(Vector3(p.x, 0, p.y), Vector3(p.x, 0.95, p.y), 0.008, 0.008, "metal_ciemny_m", 5))
		cz.append(B.walec(Vector3(a.x, 0.95, a.y), Vector3(b.x, 0.95, b.y), 0.025, 0.025, "drewno_m", 8))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(maxf(0.06, absf(b.x - a.x)), 1.0, maxf(0.06, absf(b.y - a.y)))
		cs.shape = bs
		cs.position = Vector3((a.x + b.x) * 0.5, 0.5, (a.y + b.y) * 0.5)
		cialo_scian.add_child(cs)
	var mi := B.instancja(cz, false)
	swiat.add_child(mi)


func _srodek(k: Vector2i) -> Vector3:
	var r: Rect2 = komorki[k]["rect"] if komorki.has(k) and komorki[k].has("rect") else Rect2(k.x * C, k.y * C, C, C)
	return Vector3(r.get_center().x, 0, r.get_center().y)


# ------------------------------------------------------------------ przejścia

## Miejsce na skrzydło drzwi: płaszczyzna otworu w f (oś przejścia), środek c, otwiera się w stronę `znak`
## (do pomieszczenia `pokoj`).
func _miejsce_drzwi(poziomo: bool, f: float, c: float, znak: float, pokoj: Vector2i, inny: Vector2i) -> Dictionary:
	var p := Vector3(f, 0, c) if poziomo else Vector3(c, 0, f)
	var nn := Vector3(znak, 0, 0) if poziomo else Vector3(0, 0, znak)
	return {"p": p, "n": nn, "w": DRZWI_W, "h": DRZWI_H, "pokoj": pokoj, "inny": inny}


## Dla każdej krawędzi grafu buduje przejście: odcinek korytarza i/lub otwór drzwiowy w grubym murze.
func _przejscia() -> void:
	for key in krawedzie:
		var e: Dictionary = krawedzie[key]
		var a: Vector2i = e["a"]
		var b: Vector2i = e["b"]
		if b.x < a.x or b.y < a.y:
			var t := a
			a = b
			b = t
		var poziomo := a.x != b.x
		var d := Vector2i(1, 0) if poziomo else Vector2i(0, 1)
		var ra: Rect2 = komorki[a]["rect"]
		var rb: Rect2 = komorki[b]["rect"]
		var fa := ra.end.x if poziomo else ra.end.y
		var fb := rb.position.x if poziomo else rb.position.y
		var lo_a := ra.position.y if poziomo else ra.position.x
		var hi_a := ra.end.y if poziomo else ra.end.x
		var lo_b := rb.position.y if poziomo else rb.position.x
		var hi_b := rb.end.y if poziomo else rb.end.x
		var ka := _korytarz_w(a)
		var kb := _korytarz_w(b)
		var c := (a.y * C if poziomo else a.x * C) + C * 0.5
		var bp := Kit.Budowniczy.new()
		var stary := bud
		bud = bp
		if ka and kb:
			_pasaz(poziomo, fa, fb, c, KW, H, komorki[a]["mats"], a)
			komorki[a]["otwory"][d].append([c - KW * 0.5, c + KW * 0.5, H, 0.0])
			komorki[b]["otwory"][-d].append([c - KW * 0.5, c + KW * 0.5, H, 0.0])
		elif ka or kb:
			# korytarz dochodzi do muru pomieszczenia, w murze drzwi
			var otw := [c - DRZWI_W * 0.5, c + DRZWI_W * 0.5, DRZWI_H, 0.0]
			if ka:
				drzwi_miejsca.append(_miejsce_drzwi(poziomo, fb - 0.07, c, 1.0, b, a))
				_pasaz(poziomo, fa, fb - GRUB, c, KW, H, komorki[a]["mats"], a)
				_pasaz(poziomo, fb - GRUB, fb, c, DRZWI_W, DRZWI_H, komorki[b]["mats"])
				_sciana_osiowa(komorki[a]["mats"][0], not poziomo, fb - GRUB, c - KW * 0.5, c + KW * 0.5, -Vector2(d), [otw])
				komorki[a]["otwory"][d].append([c - KW * 0.5, c + KW * 0.5, H, 0.0])
				komorki[b]["otwory"][-d].append(otw)
			else:
				drzwi_miejsca.append(_miejsce_drzwi(poziomo, fa + 0.07, c, -1.0, a, b))
				_pasaz(poziomo, fa, fa + GRUB, c, DRZWI_W, DRZWI_H, komorki[a]["mats"])
				_pasaz(poziomo, fa + GRUB, fb, c, KW, H, komorki[b]["mats"], b)
				_sciana_osiowa(komorki[b]["mats"][0], not poziomo, fa + GRUB, c - KW * 0.5, c + KW * 0.5, Vector2(d), [otw])
				komorki[a]["otwory"][d].append(otw)
				komorki[b]["otwory"][-d].append([c - KW * 0.5, c + KW * 0.5, H, 0.0])
		else:
			var w := DRZWI_W
			var h := DRZWI_H
			var lo := maxf(lo_a, lo_b) + 0.8
			var hi := minf(hi_a, hi_b) - 0.8
			if e["otwarte"] and hi - lo > 3.0:
				w = 2.4
				h = 2.5
			c = rng.randf_range(lo + w * 0.5, hi - w * 0.5) if hi - lo > w else (lo + hi) * 0.5
			if w <= DRZWI_W + 0.01:
				drzwi_miejsca.append(_miejsce_drzwi(poziomo, fb - 0.07, c, 1.0, b, a))
			_pasaz(poziomo, fa, fb, c, w, h, komorki[a]["mats"])
			komorki[a]["otwory"][d].append([c - w * 0.5, c + w * 0.5, h, 0.0])
			komorki[b]["otwory"][-d].append([c - w * 0.5, c + w * 0.5, h, 0.0])
		bud = stary
		var mi := MeshInstance3D.new()
		mi.name = "Przejscie_%s" % key.replace("|", "_").replace(",", "_")
		mi.mesh = bp.zbuduj({})
		swiat.add_child(mi)
		e["c"] = c
		e["a_dol"] = a
		e["pa"] = Vector3(fa - 0.8, 0, c) if poziomo else Vector3(c, 0, fa - 0.8)
		e["pb"] = Vector3(fb + 0.8, 0, c) if poziomo else Vector3(c, 0, fb + 0.8)


## Odcinek przejścia między f0 a f1 wzdłuż osi przejścia, środek c na osi poprzecznej.
## Podłoga, strop na wysokości h, ściany boczne z kolizją. Odcinki korytarza zapamiętuje jako ramiona.
func _pasaz(poziomo: bool, f0: float, f1: float, c: float, w: float, h: float, mats: Array, wlasciciel := Vector2i(-1, -1)) -> void:
	if f1 - f0 < 0.01:
		return
	var r := Rect2(f0, c - w * 0.5, f1 - f0, w) if poziomo else Rect2(c - w * 0.5, f0, w, f1 - f0)
	bud.plaszczyzna(mats[1], r.position.x, r.position.y, r.end.x, r.end.y, 0.0, true, 1.2, 1.0)
	bud.plaszczyzna(mats[2], r.position.x, r.position.y, r.end.x, r.end.y, h, false, 1.2, 1.0)
	if poziomo:
		_scianka(mats[0], Vector2(f0, c - w * 0.5), Vector2(f1, c - w * 0.5), Vector2(0, 1), true, 0.0, h)
		_scianka(mats[0], Vector2(f0, c + w * 0.5), Vector2(f1, c + w * 0.5), Vector2(0, -1), true, 0.0, h)
	else:
		_scianka(mats[0], Vector2(c - w * 0.5, f0), Vector2(c - w * 0.5, f1), Vector2(1, 0), true, 0.0, h)
		_scianka(mats[0], Vector2(c + w * 0.5, f0), Vector2(c + w * 0.5, f1), Vector2(-1, 0), true, 0.0, h)
	_podloga(r)
	if wlasciciel.x >= 0:
		komorki[wlasciciel]["ramiona"].append([Vector2i(1, 0) if poziomo else Vector2i(0, 1), r])


func _podloga(r: Rect2, sufit := true) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(r.size.x + 0.02, 0.4, r.size.y + 0.02)
	cs.shape = bs
	cs.position = Vector3(r.get_center().x, -0.2, r.get_center().y)
	cialo_scian.add_child(cs)
	if sufit:
		_sufit_kolizja(r)


## Lity sufit (strop): kule i odłamki z dołu nie przechodzą na piętro, pełzacz wisi pod nim.
func _sufit_kolizja(r: Rect2) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(r.size.x + 0.02, 0.3, r.size.y + 0.02)
	cs.shape = bs
	cs.position = Vector3(r.get_center().x, H + 0.15, r.get_center().y)
	cialo_scian.add_child(cs)


# ------------------------------------------------------------------ geometria

func _uv_sciany(u: float, y: float) -> Vector2:
	return Vector2(u, 1.0 - y / H)


## Ściana z punktu p do q (xz) zwrócona licem w stronę nrm; opcjonalnie z bryłą kolizji za licem.
func _scianka(mat: String, p: Vector2, q: Vector2, nrm: Vector2, kolizja: bool, y0 := 0.0, y1 := H) -> void:
	var dir := q - p
	if dir.length() < 0.02 or y1 - y0 < 0.01:
		return
	if Vector2(-dir.y, dir.x).dot(nrm) < 0.0:
		var t := p
		p = q
		q = t
	bud.sciana(mat, Vector3(p.x, 0, p.y), Vector3(q.x, 0, q.y), y0, y1, 0.75, _uv_sciany)
	if kolizja:
		_bryla(p, q, nrm, y0, y1)


func _bryla(p: Vector2, q: Vector2, nrm: Vector2, y0: float, y1: float) -> void:
	var dir := q - p
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var sr := (p + q) * 0.5 - nrm * (T * 0.5)
	var dl := p.distance_to(q) + 0.02
	bs.size = Vector3(dl if absf(dir.x) > 0.01 else T, y1 - y0, T if absf(dir.x) > 0.01 else dl)
	cs.shape = bs
	cs.position = Vector3(sr.x, (y0 + y1) * 0.5, sr.y)
	cialo_scian.add_child(cs)


## Ściana osiowa z otworami. wzdluz_x: ściana biegnie wzdłuż osi x (stala = z).
## otwory: [od, do, góra otworu, dół otworu] we współrzędnych wzdłuż ściany; dół > 0 = okno (zablokowane kolizją).
func _sciana_osiowa(mat: String, wzdluz_x: bool, stala: float, lo: float, hi: float, nrm: Vector2, otwory: Array) -> void:
	var lista := otwory.duplicate()
	lista.sort_custom(func(a, b): return a[0] < b[0])
	var cur := lo
	for o in lista:
		var o0: float = clampf(o[0], lo, hi)
		var o1: float = clampf(o[1], lo, hi)
		_scianka(mat, _pkt(wzdluz_x, stala, cur), _pkt(wzdluz_x, stala, o0), nrm, true)
		_scianka(mat, _pkt(wzdluz_x, stala, o0), _pkt(wzdluz_x, stala, o1), nrm, true, o[2], H)
		if o[3] > 0.0:
			_scianka(mat, _pkt(wzdluz_x, stala, o0), _pkt(wzdluz_x, stala, o1), nrm, true, 0.0, o[3])
			_bryla(_pkt(wzdluz_x, stala, o0), _pkt(wzdluz_x, stala, o1), nrm, o[3], o[2])
		cur = maxf(cur, o1)
	_scianka(mat, _pkt(wzdluz_x, stala, cur), _pkt(wzdluz_x, stala, hi), nrm, true)


func _pkt(wzdluz_x: bool, stala: float, u: float) -> Vector2:
	return Vector2(u, stala) if wzdluz_x else Vector2(stala, u)


## Parametry boku prostokąta: [wzdluz_x, stala, lo, hi, normalna do wnętrza].
func _bok(r: Rect2, d: Vector2i) -> Array:
	match d:
		Vector2i(0, -1): return [true, r.position.y, r.position.x, r.end.x, Vector2(0, 1)]
		Vector2i(0, 1): return [true, r.end.y, r.position.x, r.end.x, Vector2(0, -1)]
		Vector2i(-1, 0): return [false, r.position.x, r.position.y, r.end.y, Vector2(1, 0)]
		_: return [false, r.end.x, r.position.y, r.end.y, Vector2(-1, 0)]


## Punkt na licu ściany d pomieszczenia k w miejscu u (współrzędna wzdłuż ściany).
func _punkt_sciany(k: Vector2i, d: Vector2i, u: float) -> Vector3:
	var b := _bok(komorki[k]["rect"], d)
	var p := _pkt(b[0], b[1], u)
	return Vector3(p.x, 0, p.y)


func _pomieszczenie(k: Vector2i) -> void:
	var mats: Array = komorki[k]["mats"]
	var r: Rect2 = komorki[k]["rect"]
	if not schody.is_empty() and schody["k"] == k:
		_klatka_schody(k, mats, r)
	else:
		bud.plaszczyzna(mats[1], r.position.x, r.position.y, r.end.x, r.end.y, 0.0, true, 1.5, 1.0)
		bud.plaszczyzna(mats[2], r.position.x, r.position.y, r.end.x, r.end.y, H, false, 1.5, 1.0)
		_podloga(r)
	for d in DIRS:
		var b := _bok(r, d)
		var otw: Array = komorki[k]["otwory"][d].duplicate()
		for o in komorki[k]["okna"]:
			if o["d"] == d:
				otw.append([o["c"] - o["w"] * 0.5, o["c"] + o["w"] * 0.5, o["y1"], o["y0"]])
		_sciana_osiowa(mats[0], b[0], b[1], b[2], b[3], b[4], otw)
	for o in komorki[k]["okna"]:
		var a := _punkt_sciany(k, o["d"], o["c"] - o["w"] * 0.5)
		var bb := _punkt_sciany(k, o["d"], o["c"] + o["w"] * 0.5)
		_okno(a, bb, o["y0"], o["y1"], o["d"], komorki[k]["typ"] == "piwnica")
		okna.append([k, o["d"], (a + bb) * 0.5])


func _korytarz(k: Vector2i) -> void:
	var mats: Array = komorki[k]["mats"]
	var r: Rect2 = komorki[k]["rect"]
	bud.plaszczyzna(mats[1], r.position.x, r.position.y, r.end.x, r.end.y, 0.0, true, 1.2, 1.0)
	bud.plaszczyzna(mats[2], r.position.x, r.position.y, r.end.x, r.end.y, H, false, 1.2, 1.0)
	_podloga(r)
	for d in DIRS:
		if not komorki[k]["otwory"][d].is_empty():
			continue
		var b := _bok(r, d)
		_sciana_osiowa(mats[0], b[0], b[1], b[2], b[3], b[4], [])


## Okna na zewnętrznych ścianach pomieszczeń (nie w klatce).
func _plan_okien() -> void:
	for k in komorki:
		var typ: String = komorki[k]["typ"]
		if typ in ["korytarz", "klatka"]:
			continue
		var ile := 0
		var strony := DIRS.duplicate()
		_tasuj(strony)
		for d in strony:
			var n: Vector2i = k + d
			if ile >= 2 or not komorki[k]["otwory"][d].is_empty():
				continue
			var zewn := not _w_siatce(n) or not komorki.has(n)
			if not zewn or rng.randf() > (0.45 if typ != "piwnica" else 0.3):
				continue
			var b := _bok(komorki[k]["rect"], d)
			var w := 1.4 if typ != "piwnica" else 1.1
			var c := rng.randf_range(b[2] + 1.2, b[3] - 1.2)
			var y0 := 0.95 if typ != "piwnica" else 1.75
			var y1 := 2.25 if typ != "piwnica" else 2.45
			komorki[k]["okna"].append({"d": d, "c": c, "w": w, "y0": y0, "y1": y1})
			ile += 1


func _okno(a: Vector3, b: Vector3, y0: float, y1: float, d: Vector2i, krata: bool) -> void:
	var naz := Vector3(d.x, 0, d.y)
	var gl := naz * 0.35
	var pa := a + gl
	var pb := b + gl
	bud.quad("okno", [Vector3(pa.x, y0, pa.z), Vector3(pb.x, y0, pb.z), Vector3(pb.x, y1, pb.z), Vector3(pa.x, y1, pa.z)],
		[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	for pair in [[a, a + gl], [b + gl, b]]:
		var p: Vector3 = pair[0]
		var q: Vector3 = pair[1]
		bud.quad("tynk_bialy", [Vector3(p.x, y0, p.z), Vector3(q.x, y0, q.z), Vector3(q.x, y1, q.z), Vector3(p.x, y1, p.z)],
			[Vector2(0, 1), Vector2(0.3, 1), Vector2(0.3, 0), Vector2(0, 0)])
	bud.quad("lastryko", [Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z), Vector3(b.x + gl.x, y0, b.z + gl.z), Vector3(a.x + gl.x, y0, a.z + gl.z)],
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.3), Vector2(0, 0.3)])
	bud.quad("tynk_bialy", [Vector3(a.x + gl.x, y1, a.z + gl.z), Vector3(b.x + gl.x, y1, b.z + gl.z), Vector3(b.x, y1, b.z), Vector3(a.x, y1, a.z)],
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.3), Vector2(0, 0.3)])
	var srodek := (a + b) * 0.5
	if krata:
		_mebel("krata", srodek + gl * 0.3 + Vector3.UP * y0, atan2(-naz.x, -naz.z), false)
	var l := OmniLight3D.new()
	l.light_color = Color(0.45, 0.52, 0.8)
	l.light_energy = 0.3
	l.omni_range = 4.0
	swiat.add_child(l)
	l.global_position = srodek - naz * 0.8 + Vector3.UP * (y0 + y1) * 0.5


# ------------------------------------------------------------------ strefy i wolne miejsce

## Prostokąty przed drzwiami/przejściami pomieszczenia, które muszą zostać puste.
func _strefy_drzwi(k: Vector2i) -> Array:
	var out := []
	var r: Rect2 = komorki[k]["rect"]
	for d in DIRS:
		for o in komorki[k]["otwory"][d]:
			var a: float = o[0] - 0.4
			var b: float = o[1] + 0.4
			match d:
				Vector2i(1, 0): out.append(Rect2(r.end.x - 1.4, a, 1.4, b - a))
				Vector2i(-1, 0): out.append(Rect2(r.position.x, a, 1.4, b - a))
				Vector2i(0, 1): out.append(Rect2(a, r.end.y - 1.4, b - a, 1.4))
				Vector2i(0, -1): out.append(Rect2(a, r.position.y, b - a, 1.4))
	return out


## Strefy przed oknami: zakaz tylko dla wysokich mebli.
func _strefy_okien(k: Vector2i) -> Array:
	var out := []
	var r: Rect2 = komorki[k]["rect"]
	for o in komorki[k]["okna"]:
		var a: float = o["c"] - o["w"] * 0.5 - 0.1
		var b: float = o["c"] + o["w"] * 0.5 + 0.1
		match o["d"]:
			Vector2i(1, 0): out.append(Rect2(r.end.x - 0.8, a, 0.8, b - a))
			Vector2i(-1, 0): out.append(Rect2(r.position.x, a, 0.8, b - a))
			Vector2i(0, 1): out.append(Rect2(a, r.end.y - 0.8, b - a, 0.8))
			Vector2i(0, -1): out.append(Rect2(a, r.position.y, b - a, 0.8))
	return out


func _wolne(k: Vector2i, r: Rect2, dodatkowe: Array) -> bool:
	var inner: Rect2 = (komorki[k]["rect"] as Rect2).grow(-0.02)
	if not inner.encloses(r):
		return false
	for z in komorki[k]["zajete"]:
		if (z as Rect2).grow(0.06).intersects(r):
			return false
	for z in dodatkowe:
		if (z as Rect2).intersects(r):
			return false
	return true


func _rozmiar(id: String) -> Vector2:
	var roz: Array = meble[id]["rozmiar"]
	return Vector2(float(roz[0]), float(roz[2]))


func _slad(id: String, p: Vector2, rot: float) -> Rect2:
	var s := _rozmiar(id)
	if absf(sin(rot)) > 0.7:
		s = Vector2(s.y, s.x)
	return Rect2(p - s * 0.5, s)


## Stawia mebel, jeśli ślad jest wolny (drzwi, okna dla wysokich, inne meble). Zwraca powodzenie.
func _postaw(k: Vector2i, id: String, p: Vector2, rot: float, przy_scianie: bool) -> bool:
	if not meble.has(id):
		return false
	var r := _slad(id, p, rot)
	var strefy: Array = _strefy_drzwi(k) + komorki[k]["strefy"]
	var wysoki := float(meble[id]["rozmiar"][1]) > 1.0 or (id in MONTOWANE_NA_SCIANIE and id != "kaloryfer")
	if wysoki:
		strefy += _strefy_okien(k)
	if not _wolne(k, r, strefy):
		return false
	var montowany := id in MONTOWANE_NA_SCIANIE
	if id != "dywan":
		komorki[k]["zajete"].append(r)
	var y: float = WYSOKOSC_MONTAZU.get(id, 0.0)
	var node := _mebel(id, Vector3(p.x, y, p.y), rot, true, k)
	if id != "dywan" and not montowany:
		komorki[k]["meble"].append({"rect": r, "node": node, "przy_scianie": przy_scianie, "pos": Vector3(p.x, y, p.y)})
	return true


## Pozycja mebla dosuniętego tyłem do ściany d w miejscu u.
func _pozycja_przy_scianie(k: Vector2i, id: String, d: Vector2i, u: float) -> Vector2:
	var r: Rect2 = komorki[k]["rect"]
	var gl := _rozmiar(id).y * 0.5 + 0.03
	match d:
		Vector2i(0, -1): return Vector2(u, r.position.y + gl)
		Vector2i(0, 1): return Vector2(u, r.end.y - gl)
		Vector2i(-1, 0): return Vector2(r.position.x + gl, u)
		_: return Vector2(r.end.x - gl, u)


func _na_scianie(k: Vector2i, id: String, d: Vector2i, u: float) -> bool:
	return _postaw(k, id, _pozycja_przy_scianie(k, id, d, u), ROT[d], true)


## Próbuje postawić mebel gdziekolwiek przy ścianie d (albo dowolnej, gdy d = zero).
func _gdzies_przy_scianie(k: Vector2i, id: String, d := Vector2i.ZERO, proby := 16) -> bool:
	for i in proby:
		var dd: Vector2i = d if d != Vector2i.ZERO else DIRS[rng.randi() % 4]
		var b := _bok(komorki[k]["rect"], dd)
		var w := _rozmiar(id).x
		var u := rng.randf_range(b[2] + w * 0.5 + 0.05, b[3] - w * 0.5 - 0.05)
		if _na_scianie(k, id, dd, u):
			return true
	return false


## Ciąg mebli dosuniętych do siebie wzdłuż ściany d, od jednego narożnika. Omija drzwi.
func _ciag(k: Vector2i, ids: Array, d: Vector2i, od_konca: bool) -> int:
	var b := _bok(komorki[k]["rect"], d)
	var lo: float = b[2] + 0.04
	var hi: float = b[3] - 0.04
	var cur := hi if od_konca else lo
	var ile := 0
	for id in ids:
		if not meble.has(id):
			continue
		var w := _rozmiar(id).x
		while (cur - w >= lo) if od_konca else (cur + w <= hi):
			var u := cur - w * 0.5 if od_konca else cur + w * 0.5
			if _na_scianie(k, id, d, u):
				cur = cur - w - 0.02 if od_konca else cur + w + 0.02
				ile += 1
				break
			cur = cur - 0.2 if od_konca else cur + 0.2
	return ile


## Stół z krzesłami (i czasem dywanem) w wolnym miejscu pomieszczenia.
func _stol_z_krzeslami(k: Vector2i, krzesla: int, dywan: bool) -> void:
	var r: Rect2 = komorki[k]["rect"]
	var c := r.get_center()
	var strefy: Array = _strefy_drzwi(k)
	for proba in 30:
		var rot := 0.0 if rng.randf() < 0.5 else PI / 2.0
		var p := c + Vector2(rng.randf_range(-1, 1) * maxf(0.0, r.size.x * 0.5 - 1.8), rng.randf_range(-1, 1) * maxf(0.0, r.size.y * 0.5 - 1.8))
		var slad := _slad("stol", p, rot)
		if not _wolne(k, slad.grow(0.75), strefy):
			continue
		if dywan:
			_mebel("dywan", Vector3(p.x, 0, p.y), rot, false, k)
		_postaw(k, "stol", p, rot, false)
		# miejsca na krzesła: dłuższe boki, potem szczyty
		var dl := Vector2(1, 0) if rot == 0.0 else Vector2(0, 1)
		var pop := Vector2(0, 1) if rot == 0.0 else Vector2(1, 0)
		var miejsca := [
			[p - pop * 0.68 + dl * 0.28, pop], [p + pop * 0.68 - dl * 0.28, -pop],
			[p - pop * 0.68 - dl * 0.3, pop], [p - dl * 0.92, dl], [p + dl * 0.92, -dl],
		]
		var n := 0
		for m in miejsca:
			if n >= krzesla:
				break
			var kier: Vector2 = m[1]
			# krzesło przodem do stołu: obrót mapuje lokalne +z na kierunek kier
			var kr := atan2(kier.x, kier.y) + rng.randf_range(-0.3, 0.3)
			if _postaw(k, "krzeslo", m[0], kr, false):
				n += 1
		return


## Skupisko (skrzynie, beczki) w narożniku.
func _skupisko(k: Vector2i, ids: Array) -> void:
	var r: Rect2 = komorki[k]["rect"]
	var sx := -1 if rng.randf() < 0.5 else 1
	var sz := -1 if rng.randf() < 0.5 else 1
	var rog := Vector2(r.position.x if sx < 0 else r.end.x, r.position.y if sz < 0 else r.end.y)
	for id in ids:
		for proba in 14:
			var p := rog + Vector2(-sx * rng.randf_range(0.4, 1.9), -sz * rng.randf_range(0.4, 1.9))
			if _postaw(k, id, p, rng.randf_range(-0.25, 0.25) + (PI / 2.0 if rng.randf() < 0.3 else 0.0), false):
				break


## Wyspa: kilka mebli obok siebie w środkowej części pomieszczenia (osłona).
func _wyspa(k: Vector2i, ids: Array) -> void:
	var r: Rect2 = komorki[k]["rect"]
	for proba in 20:
		var rot := 0.0 if rng.randf() < 0.5 else PI / 2.0
		var dl := Vector2(1, 0) if rot == 0.0 else Vector2(0, 1)
		var p := r.get_center() + Vector2(rng.randf_range(-1, 1) * maxf(0.0, r.size.x * 0.5 - 2.2), rng.randf_range(-1, 1) * maxf(0.0, r.size.y * 0.5 - 2.2))
		var szer := 0.0
		for id in ids:
			szer += _rozmiar(id).x + 0.05
		var cur := p - dl * szer * 0.5
		var ok := true
		for id in ids:
			var w := _rozmiar(id).x
			if not _wolne(k, _slad(id, cur + dl * w * 0.5, rot).grow(0.6), _strefy_drzwi(k)):
				ok = false
				break
			cur += dl * (w + 0.05)
		if not ok:
			continue
		cur = p - dl * szer * 0.5
		for id in ids:
			var w := _rozmiar(id).x
			_postaw(k, id, cur + dl * w * 0.5, rot + rng.randf_range(-0.06, 0.06), false)
			cur += dl * (w + 0.05)
		return


# ------------------------------------------------------------------ wyposażenie

func _wyposaz(k: Vector2i) -> void:
	var typ: String = komorki[k]["typ"]
	if typ == "korytarz":
		_wyposaz_korytarz(k)
		return
	if _plan_posterunkow.has(k):
		_posterunek(k)
	var sciany := DIRS.duplicate()
	_tasuj(sciany)
	match typ:
		"pokoj":
			# strefa dzienna: wersalka i telewizor naprzeciw, meblościanka, łóżko, stół
			if _gdzies_przy_scianie(k, "wersalka", sciany[0]):
				_gdzies_przy_scianie(k, "telewizor", -sciany[0])
			if rng.randf() < 0.7:
				_ciag(k, ["meblosciana"] if rng.randf() < 0.6 else ["szafa", "szafa"], sciany[1], rng.randf() < 0.5)
			if rng.randf() < 0.55:
				_gdzies_przy_scianie(k, "lozko", sciany[2])
			if rng.randf() < 0.6:
				_stol_z_krzeslami(k, rng.randi_range(2, 3), rng.randf() < 0.6)
			elif rng.randf() < 0.5:
				_mebel("dywan", Vector3(_srodek(k).x, 0, _srodek(k).z), 0.0, false, k)
		"kuchnia":
			var ciag := ["lodowka", "szafka_kuchenna", "kuchenka", "szafka_kuchenna"]
			if rng.randf() < 0.4:
				ciag.pop_back()
			_ciag(k, ciag, sciany[0], rng.randf() < 0.5)
			if rng.randf() < 0.45:
				_ciag(k, ["szafka_kuchenna"], sciany[1], rng.randf() < 0.5)
			_stol_z_krzeslami(k, rng.randi_range(2, 4), false)
			if rng.randf() < 0.5:
				_gdzies_przy_scianie(k, "apteczka_scienna")
		"administracja":
			_ciag(k, ["szafka_metalowa", "szafka_metalowa", "szafa"], sciany[0], rng.randf() < 0.5)
			_biurka(k, rng.randi_range(1, 3))
			if rng.randf() < 0.5:
				_gdzies_przy_scianie(k, "tablica_ogloszen")
			if rng.randf() < 0.4:
				_gdzies_przy_scianie(k, "apteczka_scienna")
		"piwnica":
			_ciag(k, ["regal_metalowy", "regal_metalowy"], sciany[0], rng.randf() < 0.5)
			if rng.randf() < 0.5:
				_ciag(k, ["regal_metalowy"], sciany[1], rng.randf() < 0.5)
			_skupisko(k, ["skrzynia", "skrzynia", "beczka"].slice(0, rng.randi_range(1, 3)))
			if rng.randf() < 0.45:
				_wyspa(k, ["worki_piasek"])
		"magazyn":
			_ciag(k, ["regal_metalowy", "regal_metalowy", "regal_metalowy"], sciany[0], rng.randf() < 0.5)
			_ciag(k, ["regal_metalowy", "regal_metalowy"], sciany[1], rng.randf() < 0.5)
			_wyspa(k, ["skrzynia_wojskowa", "skrzynia_wojskowa"])
			if rng.randf() < 0.6:
				_wyspa(k, ["worki_piasek"])
			_skupisko(k, ["beczka", "beczka", "skrzynia"])
		"warsztat":
			_ciag(k, ["regal_metalowy", "stol_warsztatowy", "szafka_metalowa"], sciany[0], rng.randf() < 0.5)
			if rng.randf() < 0.5:
				_ciag(k, ["regal_metalowy"], sciany[1], rng.randf() < 0.5)
			_skupisko(k, ["beczka", "beczka"])
			if rng.randf() < 0.6:
				_wyspa(k, ["skrzynia"])
		"klatka":
			_gdzies_przy_scianie(k, "skrzynki_pocztowe")
			if rng.randf() < 0.6:
				_gdzies_przy_scianie(k, "tablica_ogloszen")
			if rng.randf() < 0.5:
				_gdzies_przy_scianie(k, "hydrant")
			for d in sciany:
				if komorki[k]["otwory"][d].is_empty() and rng.randf() < 0.7:
					_drzwi_dekoracyjne(k, d)
	# kaloryfery pod oknami
	for o in komorki[k]["okna"]:
		if typ != "piwnica" and rng.randf() < 0.8:
			_na_scianie(k, "kaloryfer", o["d"], o["c"])
	_zapewnij_przejscie(k)
	# punkty spawnu przeciwników
	if komorki[k]["glebokosc"] >= 2:
		var r: Rect2 = komorki[k]["rect"]
		for i in 3:
			for proba in 20:
				var p := Vector2(rng.randf_range(r.position.x + 0.8, r.end.x - 0.8), rng.randf_range(r.position.y + 0.8, r.end.y - 0.8))
				if _wolne(k, Rect2(p - Vector2(0.4, 0.4), Vector2(0.8, 0.8)), []):
					spawny.append({"pos": Vector3(p.x, 0.05, p.y), "komorka": k, "glebokosc": komorki[k]["glebokosc"]})
					break


## Rząd biurek z krzesłami (biuro administracji).
func _biurka(k: Vector2i, ile: int) -> void:
	var r: Rect2 = komorki[k]["rect"]
	var rot := 0.0 if rng.randf() < 0.5 else PI
	var z := r.get_center().y + rng.randf_range(-0.8, 0.8)
	var x := r.position.x + 1.4
	var zrobione := 0
	while x < r.end.x - 1.0 and zrobione < ile:
		if _postaw(k, "biurko", Vector2(x, z), rot + rng.randf_range(-0.05, 0.05), false):
			var za := -0.68 if rot == 0.0 else 0.68
			_postaw(k, "krzeslo", Vector2(x + rng.randf_range(-0.2, 0.2), z + za), rot + rng.randf_range(-0.4, 0.4), false)
			zrobione += 1
			x += 2.2
		else:
			x += 0.4


func _wyposaz_korytarz(k: Vector2i) -> void:
	var r: Rect2 = komorki[k]["rect"]
	var modele := ["drzwi_skaj_12", "drzwi_skaj_13", "drzwi_skaj_14"]
	var sciany := []   # [pozycja przy licu, kierunek ściany]
	for d in DIRS:
		if komorki[k]["otwory"][d].is_empty():
			var b := _bok(r, d)
			var p := _pkt(b[0], b[1], (b[2] + b[3]) * 0.5)
			sciany.append([Vector3(p.x, 0, p.y) - Vector3(d.x, 0, d.y) * 0.1, d])
	for ram in komorki[k]["ramiona"]:
		var ar: Rect2 = ram[1]
		var wzdl: Vector2i = ram[0]
		if maxf(ar.size.x, ar.size.y) < 1.8:
			continue
		var sr := ar.get_center()
		var poprz := Vector2i(wzdl.y, wzdl.x)
		for s in [-1, 1]:
			var d: Vector2i = poprz * s
			sciany.append([Vector3(sr.x + d.x * (KW * 0.5 - 0.1), 0, sr.y + d.y * (KW * 0.5 - 0.1)), d])
	_tasuj(sciany)
	var drzwi_n := 0
	var drzwi_poz := []
	for sc in sciany:
		if drzwi_n < 2 and rng.randf() < 0.45:
			var inst: Node3D = load("res://assets/models/%s.glb" % modele[rng.randi() % 3]).instantiate()
			swiat.add_child(inst)
			inst.position = sc[0]
			inst.rotation.y = ROT[sc[1]]
			drzwi_n += 1
			drzwi_poz.append(sc[0])
		elif rng.randf() < 0.25:
			var id: String = ["hydrant", "tablica_ogloszen", "kaloryfer"][rng.randi() % 3]
			_mebel(id, sc[0] + Vector3.UP * float(WYSOKOSC_MONTAZU[id]), ROT[sc[1]], true, k)
	_rekwizyty_korytarza(k, drzwi_poz)
	_detale_korytarza(k, drzwi_poz)
	# osłona w narożniku kwadratu, tylko między dwiema ślepymi ścianami
	var c := _srodek(k)
	for dx in [-1, 1]:
		for dz in [-1, 1]:
			if not komorki[k]["otwory"][Vector2i(dx, 0)].is_empty() or not komorki[k]["otwory"][Vector2i(0, dz)].is_empty() or rng.randf() > 0.4:
				continue
			var id2: String = ["beczka", "skrzynia", "beczka"][rng.randi() % 3]
			_postaw(k, id2, Vector2(c.x + dx * (KW * 0.5 - 0.4), c.z + dz * (KW * 0.5 - 0.4)), rng.randf_range(-0.2, 0.2), false)
	if komorki[k]["glebokosc"] >= 2 and rng.randf() < 0.5:
		spawny.append({"pos": c + Vector3(0, 0.05, 0), "komorka": k, "glebokosc": komorki[k]["glebokosc"]})


# ------------------------------------------------------------------ korytarze: rekwizyty i barykady

## Drobne detale korytarza (bez kolizji, jedna siatka na komórkę): rury i korytka kablowe pod sufitem
## z uchwytami, zwisające kable, włączniki i puszki, odpadający tynk i zacieki, śmieci na podłodze
## (kartki, szkło, liście, gruz), listwa przypodłogowa.
func _detale_korytarza(k: Vector2i, drzwi_poz: Array) -> void:
	var cz := []
	var B := preload("res://scripts/core/bryly.gd")
	var odcinki := []
	for ram in komorki[k]["ramiona"]:
		odcinki.append([ram[1], ram[0].x != 0])
	var rc: Rect2 = komorki[k]["rect"]
	odcinki.append([rc, odcinki[0][1] if not odcinki.is_empty() else true])
	var rura_strona := -1 if rng.randf() < 0.5 else 1
	var ma_rure := rng.randf() < 0.75
	for od in odcinki:
		var r: Rect2 = od[0]
		var poziomo: bool = od[1]
		var a0 := r.position.x if poziomo else r.position.y
		var a1 := r.end.x if poziomo else r.end.y
		var dl := a1 - a0
		if dl < 0.6:
			continue
		var pkt := func(u: float, w: float, y: float) -> Vector3:
			return Vector3(u, y, w) if poziomo else Vector3(w, y, u)
		var sciana_w := func(strona: int) -> float:
			return ((r.position.y if poziomo else r.position.x) if strona < 0 else (r.end.y if poziomo else r.end.x))
		var roz := func(wzdl: float, h: float, gl: float) -> Vector3:
			return Vector3(wzdl, h, gl) if poziomo else Vector3(gl, h, wzdl)
		# rury pod sufitem wzdłuż korytarza z uchwytami
		if ma_rure:
			var wz: float = sciana_w.call(rura_strona) - rura_strona * 0.16
			for i in 2:
				var ww := wz - rura_strona * i * 0.09
				var yy := H - 0.22 - i * 0.03
				cz.append(B.walec(pkt.call(a0, ww, yy), pkt.call(a1, ww, yy), 0.035 - i * 0.01, 0.035 - i * 0.01, "metal_ciemny_m", 8))
			var u := a0 + 0.4
			while u < a1:
				cz.append({"t": "box", "c": pkt.call(u, wz + rura_strona * 0.06, H - 0.12), "s": roz.call(0.02, 0.12, 0.2), "m": "metal_ciemny_m", "f": 0.003})
				u += 1.5
		# listwa przypodłogowa
		for st in [-1, 1]:
			cz.append({"t": "box", "c": pkt.call((a0 + a1) * 0.5, sciana_w.call(st) - st * 0.008, 0.05), "s": roz.call(dl, 0.1, 0.016), "m": "drewno_m", "k": Color(0.35, 0.26, 0.2), "f": 0.0})
		# rzeczy na ścianach i podłodze
		var ile := int(dl / 1.2)
		for i in ile:
			var u2 := rng.randf_range(a0 + 0.3, a1 - 0.3)
			var st2 := -1 if rng.randf() < 0.5 else 1
			var w2: float = sciana_w.call(st2)
			var p0: Vector3 = pkt.call(u2, w2, 0.0)
			if drzwi_poz.any(func(dp): return Vector2((dp as Vector3).x - p0.x, (dp as Vector3).z - p0.z).length() < 1.0):
				continue
			var los := rng.randf()
			if los < 0.18:
				# włącznik / gniazdko z puszką i rurką kablową w górę
				var y := 1.25 if rng.randf() < 0.6 else 0.3
				cz.append({"t": "box", "c": pkt.call(u2, w2 - st2 * 0.012, y), "s": roz.call(0.07, 0.07, 0.024), "m": "emalia_m", "k": Color(0.85, 0.82, 0.74), "f": 0.004})
				cz.append({"t": "box", "c": pkt.call(u2, w2 - st2 * 0.026, y), "s": roz.call(0.02, 0.03, 0.006), "m": "czern", "f": 0.0})
				cz.append(B.walec(pkt.call(u2, w2 - st2 * 0.012, y + 0.035), pkt.call(u2, w2 - st2 * 0.012, H - 0.05), 0.008, 0.008, "emalia_m", 6))
			elif los < 0.36:
				# odpadający tynk / zaciek
				var hy := rng.randf_range(0.6, 2.4)
				var sz := rng.randf_range(0.2, 0.6)
				var kol := Color(0.6, 0.55, 0.45) if rng.randf() < 0.5 else Color(0.32, 0.28, 0.22)
				cz.append({"t": "box", "c": pkt.call(u2, w2 - st2 * 0.004, hy), "s": roz.call(sz, sz * rng.randf_range(0.5, 1.6), 0.006), "m": "lastryko_m", "k": kol, "f": 0.0})
			elif los < 0.62:
				# kartki, gazety
				var pp: Vector3 = pkt.call(u2, w2 - st2 * rng.randf_range(0.2, 0.9), 0.006)
				for j in rng.randi_range(1, 3):
					cz.append({"t": "box", "c": pp + Vector3(rng.randf_range(-0.2, 0.2), j * 0.002, rng.randf_range(-0.2, 0.2)), "s": Vector3(0.21, 0.003, 0.29), "m": "opakowanie", "k": Color(0.9, 0.88, 0.8), "f": 0.0, "r": Vector3(0, rng.randf_range(0, 180), 0)})
			elif los < 0.78:
				# potłuczone szkło, kawałki tynku
				var pp2: Vector3 = pkt.call(u2, w2 - st2 * rng.randf_range(0.15, 0.6), 0.0)
				for j in 6:
					var szk := rng.randf() < 0.5
					cz.append({"t": "box", "c": pp2 + Vector3(rng.randf_range(-0.25, 0.25), 0.008, rng.randf_range(-0.25, 0.25)),
						"s": Vector3(rng.randf_range(0.02, 0.07), 0.012 if not szk else 0.004, rng.randf_range(0.02, 0.07)), "m": "lastryko_m" if not szk else "metal_jasny",
						"k": Color(0.7, 0.66, 0.6) if not szk else Color(0.6, 0.75, 0.75), "f": 0.002, "r": Vector3(0, rng.randf_range(0, 90), 0)})
			elif los < 0.88:
				# zwisający kabel z sufitu
				var pk: Vector3 = pkt.call(u2, (a0 + a1) * 0.0 + w2 - st2 * rng.randf_range(0.4, 1.0), H)
				cz.append(B.walec(pk, pk + Vector3(rng.randf_range(-0.1, 0.1), -rng.randf_range(0.5, 1.1), rng.randf_range(-0.1, 0.1)), 0.006, 0.006, "czern", 5))
			else:
				# liście naniesione z podwórza
				var pp3: Vector3 = pkt.call(u2, w2 - st2 * rng.randf_range(0.1, 0.4), 0.004)
				for j in 8:
					cz.append({"t": "box", "c": pp3 + Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3)), "s": Vector3(0.05, 0.003, 0.035), "m": "opakowanie",
						"k": [Color(0.55, 0.35, 0.12), Color(0.45, 0.4, 0.15), Color(0.35, 0.22, 0.1)][j % 3], "f": 0.0, "r": Vector3(0, rng.randf_range(0, 180), 0)})
	if cz.is_empty():
		return
	var mi := B.instancja(cz, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	swiat.add_child(mi)


## Rekwizyty w ramionach korytarza: beczki, skrzynie, przewrócona szafa, gruz, worki z piaskiem.
## Zawsze przy jednej ścianie (przejście zostaje), z punktami osłon wzdłuż korytarza.
func _rekwizyty_korytarza(k: Vector2i, drzwi_poz: Array) -> void:
	for ram in komorki[k]["ramiona"]:
		var r: Rect2 = ram[1]
		var ax: Vector2i = ram[0]
		var poziomo := ax.x != 0
		var dl := r.size.x if poziomo else r.size.y
		if dl < 2.4:
			continue
		# dłuższe ramiona dostają rekwizyty po obu stronach (z przesunięciem), krótsze po jednej
		var strony := [-1, 1] if dl > 4.2 else [(-1 if rng.randf() < 0.5 else 1)]
		for strona in strony:
			if rng.randf() > 0.8:
				continue
			_rekwizyt_w_ramieniu(k, r, poziomo, strona, drzwi_poz, -1.0 if strona < 0 else 1.0)
	# barykada w prostym korytarzu: worki w poprzek połowy przejścia
	var ot: Dictionary = komorki[k]["otwory"]
	var prosty_x: bool = not ot[Vector2i(1, 0)].is_empty() and not ot[Vector2i(-1, 0)].is_empty() and ot[Vector2i(0, 1)].is_empty() and ot[Vector2i(0, -1)].is_empty()
	var prosty_z: bool = not ot[Vector2i(0, 1)].is_empty() and not ot[Vector2i(0, -1)].is_empty() and ot[Vector2i(1, 0)].is_empty() and ot[Vector2i(-1, 0)].is_empty()
	if (prosty_x or prosty_z) and rng.randf() < 0.35:
		var c := _srodek(k)
		var s3 := -1.0 if rng.randf() < 0.5 else 1.0
		var pop := Vector3(0, 0, 1) if prosty_x else Vector3(1, 0, 0)
		var p := c + pop * s3 * (KW * 0.5 - 0.82)
		_mebel("worki_piasek", p, PI / 2.0 if prosty_x else 0.0, true, Vector2i(-1, -1))
		var wz := Vector3(1, 0, 0) if prosty_x else Vector3(0, 0, 1)
		for s4 in [-1.0, 1.0]:
			oslony.append({"pos": p + wz * s4 * 0.65 + Vector3(0, 0.05, 0), "niska": true, "mebel": p})


func _rekwizyt_w_ramieniu(k: Vector2i, r: Rect2, poziomo: bool, strona: int, drzwi_poz: Array, polowa: float) -> void:
	if true:
		var dl := r.size.x if poziomo else r.size.y
		var zestaw: String = ["beczki", "skrzynie", "szafa", "gruz", "worki", "beczki", "szafa", "gruz"][rng.randi() % 8]
		var dlug := {"beczki": 1.3, "skrzynie": 1.3, "szafa": 1.9, "gruz": 1.4, "worki": 1.6}[zestaw] as float
		var gl := {"beczki": 0.6, "skrzynie": 0.62, "szafa": 0.62, "gruz": 0.9, "worki": 0.5}[zestaw] as float
		var lo := (r.position.x if poziomo else r.position.y) + 0.8
		var hi := (r.end.x if poziomo else r.end.y) - 0.8 - dlug
		if dl > 4.2:
			# dwie strony: każda w innej połowie ramienia, żeby nie zwęzić przejścia w jednym miejscu
			var sr := (lo + hi) * 0.5
			if polowa < 0.0:
				hi = minf(hi, sr - dlug * 0.5)
			else:
				lo = maxf(lo, sr + dlug * 0.5)
		if hi < lo:
			return
		var u := rng.randf_range(lo, hi) + dlug * 0.5
		var sciana := (r.position.y if poziomo else r.position.x) if strona < 0 else (r.end.y if poziomo else r.end.x)
		var w_glab := sciana - strona * (gl * 0.5 + 0.03)
		var pos := Vector3(u, 0, w_glab) if poziomo else Vector3(w_glab, 0, u)
		if drzwi_poz.any(func(dp): return (dp as Vector3).distance_to(pos) < 1.6):
			return
		var d: Vector2i = (Vector2i(0, strona) if poziomo else Vector2i(strona, 0))
		var rot: float = ROT[d]
		var wzdl := Vector3(1, 0, 0) if poziomo else Vector3(0, 0, 1)
		match zestaw:
			"beczki":
				_mebel("beczka", pos - wzdl * 0.32, rng.randf_range(0, TAU), true, Vector2i(-1, -1))
				_mebel("beczka", pos + wzdl * 0.33, rng.randf_range(0, TAU), true, Vector2i(-1, -1))
			"skrzynie":
				_mebel("skrzynia", pos - wzdl * 0.33, rot + rng.randf_range(-0.15, 0.15), true, k)
				_mebel("skrzynia", pos + wzdl * 0.33, rot + rng.randf_range(-0.15, 0.15), true, k)
				if rng.randf() < 0.5:
					_mebel("skrzynia", pos + Vector3(0, 0.6, 0), rot + rng.randf_range(-0.4, 0.4), true, Vector2i(-1, -1))
			"szafa":
				_szafa_lezaca(pos, rot)
			"gruz":
				_gruz(pos, rot)
			"worki":
				_mebel("worki_piasek", pos, rot, true, Vector2i(-1, -1))
		# punkty osłony po obu końcach rekwizytu, przy ścianie
		for s2 in [-1.0, 1.0]:
			oslony.append({"pos": pos + wzdl * s2 * (dlug * 0.5 + 0.45) + Vector3(0, 0.05, 0), "niska": true, "mebel": pos})


## Szafa przewrócona na bok: długa, niska osłona.
func _szafa_lezaca(pos: Vector3, rot: float) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = Balistyka.WARSTWA_SWIAT
	sb.name = "SzafaLezaca"
	var inst: Node3D = load("res://assets/models/meble/szafa.glb").instantiate()
	var wezel := Node3D.new()
	wezel.add_child(inst)
	wezel.rotation.z = PI / 2.0
	wezel.position = Vector3(0.95, 0.5, 0)
	sb.add_child(wezel)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.9, 1.0, 0.6)
	cs.shape = bs
	cs.position = Vector3(0, 0.5, 0)
	sb.add_child(cs)
	swiat.add_child(sb)
	sb.position = pos
	sb.rotation.y = rot + rng.randf_range(-0.08, 0.08)


## Kupa gruzu: kawałki betonu, cegły i deski.
func _gruz(pos: Vector3, rot: float) -> void:
	var bryly := []
	var kolory := [Color(0.34, 0.33, 0.31), Color(0.42, 0.4, 0.37), Color(0.45, 0.22, 0.16), Color(0.3, 0.22, 0.14)]
	for i in 11:
		var r := rng.randf_range(0.12, 0.34)
		var x := rng.randf_range(-0.6, 0.6)
		var z := rng.randf_range(-0.35, 0.35)
		var y := r * 0.4 + (0.25 - absf(x) * 0.3) * rng.randf()
		var rozm := Vector3(r * rng.randf_range(0.8, 1.6), r * rng.randf_range(0.5, 1.0), r * rng.randf_range(0.8, 1.4))
		bryly.append([Vector3(x, y, z), rozm, kolory[rng.randi() % 4], Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 90), rng.randf_range(-20, 20))])
	bryly.append([Vector3(0.1, 0.18, 0.05), Vector3(1.3, 0.04, 0.16), kolory[3], Vector3(0, 12, 14)])
	var sb := StaticBody3D.new()
	sb.collision_layer = Balistyka.WARSTWA_SWIAT
	sb.name = "Gruz"
	var mi := Kit.instancja(bryly)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.3, 0.45, 0.8)
	cs.shape = bs
	cs.position = Vector3(0, 0.22, 0)
	sb.add_child(cs)
	swiat.add_child(sb)
	sb.position = pos
	sb.rotation.y = rot


# ------------------------------------------------------------------ posterunki wojska

## Jedno-dwa gniazda z worków w głębszych, dużych pomieszczeniach (nie tam, gdzie wyjścia).
func _zaplanuj_posterunki() -> void:
	var z_wyjsciem := {}
	for p in _plan_wyjsc:
		z_wyjsciem[p[0]] = true
	var kand := komorki.keys().filter(func(k): return komorki[k]["typ"] in ["magazyn", "administracja", "warsztat", "piwnica", "pokoj"] and komorki[k]["glebokosc"] >= 2 and not z_wyjsciem.has(k) and minf((komorki[k]["rect"] as Rect2).size.x, (komorki[k]["rect"] as Rect2).size.y) >= 6.6)
	_tasuj(kand)
	var ile := rng.randi_range(2, 4)
	for k in kand.slice(0, ile):
		_plan_posterunkow[k] = true


## Gniazdo z worków w kształcie podkowy, ok. 2,6 m przed drzwiami, otwarte do tyłu.
func _posterunek(k: Vector2i) -> void:
	var drzwi := []
	for d in DIRS:
		for o in komorki[k]["otwory"][d]:
			drzwi.append([d, (o[0] + o[1]) * 0.5])
	if drzwi.is_empty():
		return
	var wybor: Array = drzwi[rng.randi() % drzwi.size()]
	var d: Vector2i = wybor[0]
	var lico := _punkt_sciany(k, d, wybor[1])
	var naz := Vector3(d.x, 0, d.y)
	var wzdl := Vector3(-d.y, 0, d.x)
	var srodek := lico - naz * 2.7
	var r: Rect2 = komorki[k]["rect"]
	var slad := Rect2(Vector2(srodek.x, srodek.z) - Vector2(1.3, 1.3), Vector2(2.6, 2.6))
	if not r.grow(-0.1).encloses(slad):
		return
	var rot_przod := atan2(naz.x, naz.z)   # długi bok worka w poprzek wejścia
	var bryly := [
		[srodek, rot_przod],
		[srodek - naz * 0.6 + wzdl * 0.95, rot_przod + PI / 2.0],
		[srodek - naz * 0.6 - wzdl * 0.95, rot_przod + PI / 2.0],
	]
	for b in bryly:
		var p: Vector3 = b[0]
		var node := _mebel("worki_piasek", p, b[1], true, Vector2i(-1, -1))
		var rr := Rect2(Vector2(p.x, p.z) - Vector2(0.85, 0.85), Vector2(1.7, 1.7))
		komorki[k]["zajete"].append(rr)
		komorki[k]["meble"].append({"rect": rr, "node": node, "przy_scianie": true, "pos": p})
	# drugi rząd worków na froncie: wyższa osłona
	_mebel("worki_piasek", srodek + Vector3(0, 0.5, 0) - naz * 0.05, rot_przod + 0.04, true, Vector2i(-1, -1))
	var miejsca := [srodek - naz * 0.75 + wzdl * 0.4, srodek - naz * 0.75 - wzdl * 0.4]
	posterunki.append({"pos": srodek - naz * 0.75, "kier": naz, "komorka": k, "miejsca": miejsca})
	# skrzynia z amunicją w gnieździe
	_mebel("skrzynia_wojskowa", srodek - naz * 1.25 + wzdl * 0.6, rot_przod, true, k)


func _drzwi_dekoracyjne(k: Vector2i, d: Vector2i) -> void:
	var modele := ["drzwi_skaj_12", "drzwi_skaj_13", "drzwi_skaj_14"]
	var b := _bok(komorki[k]["rect"], d)
	for proba in 10:
		var u := rng.randf_range(b[2] + 0.9, b[3] - 0.9)
		var p := _pozycja_przy_scianie(k, "skrzynia", d, u)   # ślad ok. 0,6 m od ściany
		var slad := Rect2(p - Vector2(0.65, 0.65), Vector2(1.3, 1.3))
		if not _wolne(k, slad, _strefy_drzwi(k)):
			continue
		komorki[k]["zajete"].append(Rect2(p - Vector2(0.6, 0.3), Vector2(1.2, 0.6)) if d.y != 0 else Rect2(p - Vector2(0.3, 0.6), Vector2(0.6, 1.2)))
		var lico := _punkt_sciany(k, d, u)
		var inst: Node3D = load("res://assets/models/%s.glb" % modele[rng.randi() % 3]).instantiate()
		swiat.add_child(inst)
		inst.position = lico - Vector3(d.x, 0, d.y) * 0.1
		inst.rotation.y = ROT[d]
		return


## Usuwa meble, jeśli dzielą pomieszczenie tak, że nie da się przejść między drzwiami.
func _zapewnij_przejscie(k: Vector2i) -> void:
	var drzwi := _strefy_drzwi(k)
	if k == _komorka_startu():
		drzwi.append(Rect2(start_pos.x - 0.5, start_pos.z - 0.5, 1.0, 1.0))
	for proba in 8:
		if _spojne(k, drzwi):
			return
		if not usun_srodkowy_mebel(k):
			return


func _spojne(k: Vector2i, drzwi: Array) -> bool:
	var krok := 0.25
	var r: Rect2 = komorki[k]["rect"]
	var x0 := r.position.x
	var z0 := r.position.y
	var nx := int(r.size.x / krok)
	var nz := int(r.size.y / krok)
	var zablok := PackedByteArray()
	zablok.resize(nx * nz)
	for ix in nx:
		for iz in nz:
			var p := Vector2(x0 + (ix + 0.5) * krok, z0 + (iz + 0.5) * krok)
			for z in komorki[k]["zajete"]:
				if (z as Rect2).grow(0.45).has_point(p):
					zablok[iz * nx + ix] = 1
					break
	var punkty := []
	for d in drzwi:
		var c: Vector2 = (d as Rect2).get_center()
		punkty.append(Vector2i(clampi(int((c.x - x0) / krok), 0, nx - 1), clampi(int((c.y - z0) / krok), 0, nz - 1)))
	if punkty.size() < 2:
		return true
	var odw := PackedByteArray()
	odw.resize(nx * nz)
	var kol: Array = [punkty[0]]
	odw[punkty[0].y * nx + punkty[0].x] = 1
	while not kol.is_empty():
		var c2: Vector2i = kol.pop_back()
		for dd in DIRS:
			var nb: Vector2i = c2 + dd
			if nb.x < 0 or nb.y < 0 or nb.x >= nx or nb.y >= nz:
				continue
			var i := nb.y * nx + nb.x
			if odw[i] == 1 or zablok[i] == 1:
				continue
			odw[i] = 1
			kol.append(nb)
	for p in punkty:
		if odw[p.y * nx + p.x] == 0:
			return false
	return true


## Punkty w głąb pomieszczenia przy każdym przejściu (do sprawdzania spójności na siatce nawigacji).
func punkty_drzwi(k: Vector2i) -> Array:
	var pts := []
	for key in krawedzie:
		var e: Dictionary = krawedzie[key]
		if not e.has("pa"):
			continue
		var a: Vector2i = e["a_dol"]
		var inny: Vector2i = e["b"] if e["a"] == a else e["a"]
		if a == k:
			pts.append(e["pa"])
		elif inny == k:
			pts.append(e["pb"])
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
		# usunięcie z drzewa od razu: siatka nawigacji jest wypiekana jeszcze w tej klatce
		var nd: Node = m["node"]
		nd.get_parent().remove_child(nd)
		nd.queue_free()
	return true


func _komorka_startu() -> Vector2i:
	return Vector2i(int(start_pos.x / C), int(start_pos.z / C))


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
		var sw := 8
		var sh := 6
		match String(info["pojemnik"]):
			"skrzynia_wojskowa": sw = 10; sh = 6
			"szafa", "regal": sw = 10; sh = 8
			"apteczka_scienna": sw = 6; sh = 4
		pj.siatka = Siatka.new(sw, sh)
		pj.wypelnij(info["pojemnik"], rng.randi_range(1, 4), rng)
		if id in MONTOWANE_NA_SCIANIE:
			pj.collision_layer = Balistyka.WARSTWA_INTERAKCJE   # nie blokuje przejść
		pj.mebel_id = id
		pj.niski = float(roz[1]) < 1.0
		if ModeleMebli.ma(id):
			# mebel z ruchomymi drzwiami / szufladami / wiekiem zamiast statycznego modelu
			inst.free()
			var mm := ModeleMebli.zbuduj(id)
			inst = mm["wezel"]
			pj.mebel = mm
			# część skrzyń i szafek ubraniowych na kłódkę (lepszy łup, ale trzeba wyłamać)
			if id in ["skrzynia_wojskowa", "szafka_metalowa", "skrzynia"] and rng.randf() < 0.3:
				pj.zamkniety_kluczem = "klodka"
				pj.wypelnij(info["pojemnik"], 2, rng)
				mm["klodka"] = ModeleMebli.klodka(inst, id)
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


func _lampa(k: Vector2i) -> void:
	var typ: String = komorki[k]["typ"]
	var start := k == _komorka_startu()
	if not start and rng.randf() < 0.14:
		_swiatlo_awaryjne(k)
		return
	var gola: bool = typ in ["piwnica", "magazyn", "warsztat"] or (typ == "korytarz" and komorki[k]["mats"][0] == "cegla")
	var rozrzut := 0.5 if typ != "korytarz" else 0.0
	var pos := _srodek(k) + Vector3(rng.randf_range(-rozrzut, rozrzut), H, rng.randf_range(-rozrzut, rozrzut))
	var model: Node3D = load("res://assets/models/meble/zarowka.glb" if gola else "res://assets/models/plafon.glb").instantiate()
	swiat.add_child(model)
	model.position = pos
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.78, 0.52) if not gola else Color(1.0, 0.72, 0.45)
	l.light_energy = 1.6 if not gola else 1.4
	l.omni_range = 8.5 if typ != "korytarz" else 6.0
	l.omni_attenuation = 0.9
	l.shadow_enabled = false
	swiat.add_child(l)
	l.position = pos + Vector3(0, -0.45 if not gola else -0.7, 0)
	var awaria := 0.0
	var r := rng.randf()
	if not start:
		if r < 0.1:
			awaria = 1.0
		elif r < 0.42:
			awaria = rng.randf_range(0.25, 0.75)
		else:
			awaria = 0.04
	l.set_script(load("res://scripts/swiat/migotanie.gd"))
	l.set("awaria", awaria)
	l.set("plafon", l.get_path_to(model))
	lampy.append(l)
	# zepsuta albo bardzo zawodna lampa: obok świeci lampka awaryjna, żeby nie było całkiem ciemno
	if awaria >= 0.6:
		_swiatlo_awaryjne(k)


## Lampka awaryjna na ścianie: słabe, ciepłe albo czerwonawe światło z akumulatora.
func _swiatlo_awaryjne(k: Vector2i) -> void:
	var r: Rect2 = komorki[k]["rect"]
	var d: Vector2i = DIRS[rng.randi() % 4]
	var b := _bok(r, d)
	var u: float = rng.randf_range(b[2] + 0.6, b[3] - 0.6)
	var lico := _punkt_sciany(k, d, u)
	var naz := Vector3(d.x, 0, d.y)
	var czerwona := rng.randf() < 0.45
	var kol := Color(0.95, 0.3, 0.22) if czerwona else Color(1.0, 0.7, 0.4)
	var obudowa := Kit.instancja([[Vector3(0, 0, 0), Vector3(0.22, 0.1, 0.08), Color(0.2, 0.2, 0.19)],
		[Vector3(0, -0.01, -0.045), Vector3(0.17, 0.06, 0.01), kol]])
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	obudowa.material_override = m
	swiat.add_child(obudowa)
	obudowa.position = lico - naz * 0.05 + Vector3.UP * (H - 0.35)
	obudowa.rotation.y = ROT[d]
	var l := OmniLight3D.new()
	l.light_color = kol
	l.light_energy = 0.55 if czerwona else 0.5
	l.omni_range = 7.5 if typ_dla(k) != "korytarz" else 6.0
	l.omni_attenuation = 1.1
	l.shadow_enabled = false
	swiat.add_child(l)
	l.position = obudowa.position - naz * 0.4 - Vector3.UP * 0.2
	lampy.append(l)


func typ_dla(k: Vector2i) -> String:
	return komorki[k]["typ"]


# ------------------------------------------------------------------ wyjścia

## Wybór pomieszczeń i ścian z wyjściami przed ustawieniem mebli (strefa przed wyjściem zostaje pusta).
func _zaplanuj_wyjscia() -> void:
	var lista := komorki.keys().filter(func(k): return komorki[k]["typ"] not in ["korytarz", "klatka"])
	lista.sort_custom(func(a, b): return komorki[a]["glebokosc"] > komorki[b]["glebokosc"])
	if lista.is_empty():
		return
	var glowna: Vector2i = lista[0]
	var piwnica := Vector2i(-1, -1)
	for k in lista:
		if k != glowna and komorki[k]["typ"] == "piwnica":
			piwnica = k
			break
	if piwnica.x < 0 and lista.size() > 1:
		piwnica = lista[1]
		komorki[piwnica]["typ"] = "piwnica"
		komorki[piwnica]["mats"] = MATERIALY["piwnica"]
		komorki[piwnica]["okna"] = []
	_plan_wyjscia(glowna, "glowne", "Brama na podwórze", 8.0)
	if piwnica.x >= 0:
		_plan_wyjscia(piwnica, "klucz", "Piwnica nr 7", 5.0)


func _plan_wyjscia(k: Vector2i, typ: String, nazwa: String, czas: float) -> void:
	var strona := Vector2i.ZERO
	var strony := DIRS.duplicate()
	_tasuj(strony)
	for d in strony:
		if not komorki[k]["otwory"][d].is_empty():
			continue
		if komorki[k]["okna"].any(func(o): return o["d"] == d):
			continue
		strona = d
		if not komorki.has(k + d):
			break
	if strona == Vector2i.ZERO:
		# wszystkie ściany zajęte: wyjście zamiast okna
		strona = komorki[k]["okna"][0]["d"] if not komorki[k]["okna"].is_empty() else Vector2i(1, 0)
		komorki[k]["okna"] = komorki[k]["okna"].filter(func(o): return o["d"] != strona)
	var b := _bok(komorki[k]["rect"], strona)
	var u: float = (b[2] + b[3]) * 0.5
	var lico := _punkt_sciany(k, strona, u)
	var naz := Vector3(strona.x, 0, strona.y)
	var w := lico - naz * 1.0
	komorki[k]["strefy"].append(Rect2(w.x - 1.3, w.z - 1.3, 2.6, 2.6))
	_plan_wyjsc.append([k, strona, u, typ, nazwa, czas])


func _wyjscia() -> void:
	for p in _plan_wyjsc:
		_wyjscie_drzwi(p[0], p[1], p[2], p[3], p[4], p[5])
	var glowna: Vector2i = _plan_wyjsc[0][0] if not _plan_wyjsc.is_empty() else Vector2i(-1, -1)
	var piwnica: Vector2i = _plan_wyjsc[1][0] if _plan_wyjsc.size() > 1 else Vector2i(-1, -1)
	# wyjście czasowe przez okno na rusztowanie
	var kandydaci := okna.filter(func(o): return o[0] != glowna and o[0] != piwnica and komorki[o[0]]["glebokosc"] >= 2)
	if not kandydaci.is_empty():
		var o: Array = kandydaci[rng.randi() % kandydaci.size()]
		var ew := Ewakuacja.new()
		ew.nazwa = "Okno na rusztowanie"
		ew.typ = "czasowe"
		ew.czas_odliczania = 6.0
		ew.okno_od = rng.randf_range(600.0, 1500.0)
		ew.okno_do = ew.okno_od + 300.0
		var d: Vector2i = o[1]
		_strefa(ew, (o[2] as Vector3) - Vector3(d.x, 0, d.y) * 0.9, Vector3(2.2, 2.0, 2.2))
		wyjscia.append(ew)


func _wyjscie_drzwi(k: Vector2i, strona: Vector2i, u: float, typ: String, nazwa: String, czas: float) -> void:
	var naz := Vector3(strona.x, 0, strona.y)
	var poz_sciany := _punkt_sciany(k, strona, u)
	var rot := atan2(-naz.x, -naz.z)
	var inst: Node3D = load("res://assets/models/drzwi_piwnica.glb").instantiate()
	swiat.add_child(inst)
	inst.position = poz_sciany - naz * 0.1
	inst.rotation.y = rot
	var znak := _mebel("znak_wyjscie", poz_sciany - naz * 0.06 + Vector3.UP * 2.3, rot, false)
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


# ------------------------------------------------------------------ akustyka

const PODLOGA_DZWIEK := {"lastryko": "lastryko", "parkiet": "parkiet", "kafelki": "kafelki", "beton": "beton"}


## Komórka siatki pod punktem świata (albo Vector2i(-1,-1) poza mapą).
func komorka_w(p: Vector3) -> Vector2i:
	var k := Vector2i(floori(p.x / C), floori(p.z / C))
	return k if komorki.has(k) else Vector2i(-1, -1)


## Rodzaj podłoża pod punktem (do dźwięku kroków): lastryko / parkiet / kafelki / beton / gruz.
func podloze(p: Vector3) -> String:
	var k := komorka_w(p)
	if k.x < 0:
		return "gruz"
	var mats: Array = komorki[k].get("mats", [])
	var r: Rect2 = komorki[k].get("rect", Rect2())
	# w przejściu (poza prostokątem pokoju) – podłoga korytarza
	if komorki[k]["typ"] != "korytarz" and not r.grow(0.1).has_point(Vector2(p.x, p.z)):
		return "lastryko"
	if mats.size() > 1:
		return PODLOGA_DZWIEK.get(mats[1], "beton")
	return "beton"


## Akustyka miejsca: typ pomieszczenia i jego wielkość (m²) – do pogłosu.
func akustyka_w(p: Vector3) -> Dictionary:
	var k := komorka_w(p)
	if k.x < 0:
		return {"typ": "zewnatrz", "pole": 400.0}
	var r: Rect2 = komorki[k].get("rect", Rect2())
	var typ: String = komorki[k]["typ"]
	if typ != "korytarz" and not r.grow(0.1).has_point(Vector2(p.x, p.z)):
		typ = "korytarz"
	return {"typ": typ, "pole": r.get_area()}
