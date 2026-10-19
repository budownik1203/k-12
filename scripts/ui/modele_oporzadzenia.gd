class_name ModeleOporzadzenia
extends RefCounted
## Osobne modele 3D każdego plecaka, kamizelki i kontenera, z miękkiej tkaniny (Tkanina), każdy z własną
## sekwencją otwierania każdej kieszeni:
##  - worek po ziemniakach stoi: rozwiązanie sznurka, szyjka rozszerza się i wywija – zaglądasz z góry,
##  - plecak turystyczny stoi: odpięcie dwóch klamer, klapa odchyla się do tyłu, kołnierz ze ściągaczem
##    rozluźnia się; boczne kieszenie siatkowe ze ściągaczem, przednia kieszeń na zamek,
##  - plecak szturmowy leży na plecach: zamek obiega panel w kształcie U, panel odkłada się jak okładka;
##    górna kieszeń na zamek,
##  - chlebak stoi: sprzączka paska, długa klapa podnosi się z przodu i odchyla, kieszonki na rzep z przodu,
##  - zasobnik wojskowy stoi: dwie metalowe klamry, klapa, ściągacz; przyszyte z boku kieszenie z klapami
##    (rzep) i ładownica na manierkę,
##  - kamizelki przed kamerą: ładownice z klapkami (rzep, zatrzask, guzik) albo kieszenie na zamek,
##  - kontener bezpieczny: metalowa kaseta z zatrzaskami i wiekiem.
##
## Plecaki leżą/stoją na podłodze: otwór u góry (+Y), głębokość wzdłuż Z (d), szerokość X (w); +Z – do gracza.
## Kamizelka stoi przed kamerą: płyta w płaszczyźnie XY, przodem do +Z (w = szerokość, d = wysokość).
## Zwraca {"wezel", "gora" (środek wnętrza), "kroki": [], "kieszenie": [{"kroki", "dzwieki"}]} – kroki
## wykonywane po kolei, w kroku wszystkie zmiany równolegle; zamknięcie odwraca kolejność.

const B := preload("res://scripts/core/bryly.gd")
const T := preload("res://scripts/ui/tkanina.gd")

const KOM_M := 1.0 / 390.0          # jak Rozlozenie3D: metry na piksel siatki plecaka
const KOM_K := 1.0 / 1050.0         # kamizelka (przy kamerze)

const KOLORY := {
	"worek": Color(0.62, 0.55, 0.4), "plecak_turystyczny": Color(0.34, 0.42, 0.52), "plecak_szturmowy": Color(0.3, 0.33, 0.24),
	"chlebak": Color(0.46, 0.44, 0.32), "plecak_wojskowy": Color(0.29, 0.32, 0.21),
	"napiersnik": Color(0.33, 0.35, 0.25), "kamizelka_lbv": Color(0.3, 0.32, 0.24), "kamizelka_wedkarska": Color(0.6, 0.56, 0.42),
	"kamizelka_mysliwska": Color(0.46, 0.34, 0.2),
}
const KAMIZELKI := ["napiersnik", "kamizelka_lbv", "kamizelka_wedkarska", "kamizelka_mysliwska"]
const TYP_LADOWNIC := {"napiersnik": "rzep", "kamizelka_lbv": "zatrzask", "kamizelka_wedkarska": "zamek", "kamizelka_mysliwska": "guzik"}
const SKORA := Color(0.32, 0.2, 0.11)
const TASMA := Color(0.14, 0.14, 0.12)


static func _mi(rodzic: Node3D, cz: Array) -> MeshInstance3D:
	var mi := B.instancja(cz)
	rodzic.add_child(mi)
	return mi


static func _t(c: Vector3, s: Vector3, k: Color, f := 0.01, rot := Vector3.ZERO) -> Dictionary:
	return {"t": "box", "c": c, "s": s, "m": "tkanina", "k": k, "f": f, "r": rot}


static func _wezel(rodzic: Node3D, poz: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = poz
	rodzic.add_child(n)
	return n


static func _dodaj(rodzic: Node3D, mi: Node3D, poz := Vector3.ZERO) -> Node3D:
	mi.position = poz
	rodzic.add_child(mi)
	return mi


# ------------------------------------------------------------------ wymiary i kieszenie

## Wymiary modelu w metrach z siatki (plecak: szer. x głęb.; kamizelka: szer. x wys.).
static func wymiary(id: String, s: Siatka) -> Vector2:
	if id in KAMIZELKI:
		return Vector2(s.w * SiatkaUI.KOM * KOM_K + 0.06, s.h * SiatkaUI.KOM * KOM_K + 0.06)
	return Vector2(s.w * SiatkaUI.KOM * KOM_M + 0.09, s.h * SiatkaUI.KOM * KOM_M / 0.82 + 0.1)


## Kieszenie w metrach modelu: plecak – Rect2(x, z, szer, gł.), kamizelka – Rect2(x lewej, y górnej, szer, wys).
static func kieszenie_m(id: String, s: Siatka) -> Array:
	var out := []
	var kz := kieszenie_dla(id, s)
	if id in KAMIZELKI:
		var kv := SiatkaUI.KOM * KOM_K
		for e in kz:
			var r: Rect2i = e["r"]
			out.append({"r": Rect2(Vector2(-s.w * kv * 0.5 + r.position.x * kv, s.h * kv * 0.5 - r.position.y * kv), Vector2(r.size.x * kv, r.size.y * kv)),
				"typ": TYP_LADOWNIC.get(id, "rzep"), "nazwa": e["nazwa"]})
		return out
	var kx := SiatkaUI.KOM * KOM_M
	var kzz := kx / 0.82
	var o := Vector2(-s.w * kx * 0.5, -s.h * kzz * 0.5)
	for e in kz:
		var r: Rect2i = e["r"]
		out.append({"r": Rect2(o + Vector2(r.position.x * kx, r.position.y * kzz), Vector2(r.size.x * kx, r.size.y * kzz)).grow(-0.004),
			"typ": e["typ"], "nazwa": e["nazwa"]})
	return out


static func zbuduj(id: String, w := -1.0, d := -1.0, kieszenie: Array = []) -> Dictionary:
	if w < 0.0 or kieszenie.is_empty():
		var pj: Dictionary = Dane.def(id).get("pojemnik", {}) if id not in ["kontener", "bezpieczny"] else {"sw": 2, "sh": 2}
		var s := Siatka.z_definicji(pj) if not pj.is_empty() else Siatka.new(2, 2)
		var wd := wymiary(id, s)
		if w < 0.0:
			w = wd.x
			d = wd.y
		if kieszenie.is_empty():
			kieszenie = kieszenie_m(id, s)
	if id in KAMIZELKI:
		return _kamizelka(id, w, d, kieszenie)
	match id:
		"worek":
			return _worek(w, d, kieszenie)
		"plecak_turystyczny", "plecak_wojskowy":
			return _plecak_stojacy(id, w, d, kieszenie)
		"plecak_szturmowy":
			return _szturmowy(w, d, kieszenie)
		"chlebak":
			return _chlebak(w, d, kieszenie)
	return _kontener(w, d, kieszenie)


## Kieszenie pojemnika: z definicji ("kieszenie": [x, y, szer, wys, nazwa, typ]), z przegródek układu
## albo cała siatka jako jedna komora.
static func kieszenie_dla(id: String, s: Siatka) -> Array:
	var out := []
	var d: Dictionary = Dane.def(id).get("pojemnik", {}) if id not in ["kontener", "bezpieczny"] else {}
	if d.has("kieszenie"):
		for e in d["kieszenie"]:
			out.append({"r": Rect2i(int(e[0]), int(e[1]), int(e[2]), int(e[3])), "nazwa": String(e[4]), "typ": String(e[5])})
		return out
	if not s.maska.is_empty():
		# ładownice / przegródki: spójne grupy pól układu
		var odw := {}
		for y in s.h:
			for x in s.w:
				if not s.dostepna(x, y) or odw.has(Vector2i(x, y)):
					continue
				var stos := [Vector2i(x, y)]
				odw[Vector2i(x, y)] = true
				var mn := Vector2i(x, y)
				var mx := Vector2i(x, y)
				while not stos.is_empty():
					var c: Vector2i = stos.pop_back()
					mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
					mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
					for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nb: Vector2i = c + dv
						if nb.x >= 0 and nb.y >= 0 and nb.x < s.w and nb.y < s.h and s.dostepna(nb.x, nb.y) and not odw.has(nb):
							odw[nb] = true
							stos.append(nb)
				out.append({"r": Rect2i(mn, mx - mn + Vector2i.ONE), "nazwa": "Ładownica", "typ": TYP_LADOWNIC.get(id, "rzep")})
		return out
	var typ := "wieko" if id in ["kontener", "bezpieczny"] else "klapa"
	out.append({"r": Rect2i(0, 0, s.w, s.h), "nazwa": "Kontener" if typ == "wieko" else "Komora", "typ": typ})
	return out


static func _glowna(kieszenie: Array) -> int:
	var best := 0
	for i in kieszenie.size():
		if (kieszenie[i]["r"] as Rect2).get_area() > (kieszenie[best]["r"] as Rect2).get_area():
			best = i
	return best


# ------------------------------------------------------------------ torba (worek, komora, kieszeń)

## Miękka torba z otworem u góry i drugim kształtem "otw" (blend shape): a, b – półosie przekroju,
## h – wysokość. o: "zx","zz" – ściśnięcie wylotu po zamknięciu, "kryza" – zebrany kołnierz nad szyjką,
## "mankiet" – promień wywinięcia brzegu po otwarciu, "opad" – osiadanie po otwarciu, "grudy" – nierówna
## zawartość, "sup" – kanciastość przekroju, "ziarno".
static func torba(a: float, b: float, h: float, k: Color, o := {}) -> MeshInstance3D:
	var zx: float = o.get("zx", 0.8)
	var zz: float = o.get("zz", 0.6)
	var kryza: bool = o.get("kryza", false)
	var mank: float = o.get("mankiet", 0.0)
	var opad: float = o.get("opad", 0.06)
	var grudy: float = o.get("grudy", 0.03)
	var sup: float = o.get("sup", 5.0)
	var fz: float = float(o.get("ziarno", 0))
	var rr := minf(minf(a, b) * 0.45, h * 0.18)
	var ai := maxf(0.004, a - rr)
	var bi := maxf(0.004, b - rr)
	var kszt := func(u: float, v: float, otw: bool) -> Vector3:
		var th := u * TAU
		var s := 1.0
		var y := 0.0
		var rz := rr
		var sx := 1.0
		var sz := 1.0
		var fald := 0.0
		var sc := 1.0 - (opad if otw else 0.0)
		if v < 0.15:
			s = v / 0.15
			rz = 0.0
		elif v < 0.3:
			var al := (v - 0.15) / 0.15 * PI * 0.5
			y = rr * (1.0 - cos(al))
			rz = rr * sin(al)
		elif v < 0.62:
			var t := (v - 0.3) / 0.32
			y = lerpf(rr, h * 0.7 * sc, t)
			fald = grudy * sin(t * PI) * (0.6 + 0.4 * sin(th * 3.0 + fz) * sin(t * 5.0 + fz))
		elif v < 0.84:
			var t2 := (v - 0.62) / 0.22
			y = lerpf(h * 0.7 * sc, h * 0.93 * sc, t2)
			if not otw:
				var e := smoothstep(0.0, 1.0, t2)
				sx = lerpf(1.0, zx, e)
				sz = lerpf(1.0, zz, e)
				fald = 0.16 * e * sin(th * 13.0 + fz) * (1.0 - minf(zx, zz))
			else:
				fald = 0.02 * sin(th * 7.0 + fz)
		else:
			var t3 := (v - 0.84) / 0.16
			if not otw:
				sx = zx
				sz = zz
				y = lerpf(h * 0.93, h, t3)
				if kryza:
					# zebrany kołnierz nad ściągaczem: tym bujniejszy, im mocniej ściągnięty
					sx = lerpf(zx, minf(zx * 1.9, zx + 0.22), t3)
					sz = lerpf(zz, minf(zz * 1.9, zz + 0.22), t3)
					y -= 0.025 * t3 * t3
					fald = 0.3 * (1.0 - zx) * sin(th * 9.0 + v * 3.0 + fz) * t3
				else:
					# usta: brzegi schodzą się do szwu (zamek / ściągnięty brzeg)
					fald = 0.05 * sin(th * 6.0 + fz)
			elif mank > 0.0:
				var fi := t3 * PI * 1.25
				y = h * 0.93 * sc + mank * sin(fi)
				rz = rr + mank * (1.0 - cos(fi))
				fald = 0.04 * sin(th * 6.0 + fz)
			else:
				y = lerpf(h * 0.93 * sc, h * sc, t3)
				sx = 1.0 + 0.04 * t3
				sz = 1.0 + 0.04 * t3
				fald = 0.03 * sin(th * 5.0 + fz)
		var q := T.przekroj(th, ai, bi, sup) * s * (1.0 + fald)
		var p := Vector3(q.x + cos(th) * rz * (1.0 + fald), y, q.y + sin(th) * rz * (1.0 + fald))
		return Vector3(p.x * sx, p.y, p.z * sz)
	return T.powierzchnia(36, 24, func(u, v): return kszt.call(u, v, false), func(u, v): return kszt.call(u, v, true), k,
		{"podszewka": o.get("podszewka", k.darkened(0.3)), "ao": func(_u, v): return lerpf(0.68, 1.0, clampf(v * 3.5, 0.0, 1.0)) * (0.85 if v > 0.84 else 1.0)})


## Przekrój wylotu torby (do sznurka i szwu): punkt obwodu po zamknięciu / otwarciu na wysokości brzegu.
static func _wylot(th: float, a: float, b: float, zx: float, zz: float) -> Vector2:
	var q := T.przekroj(th, a, b, 5.0)
	return Vector2(q.x * zx, q.y * zz)


## Sznurek ściągacza wokół szyjki (blend: zaciśnięty -> luźny) z blokadą i końcówkami z przodu.
static func _sznur(n: Node3D, srodek: Vector3, a: float, b: float, y_z: float, y_o: float, zx: float, zz: float, kol: Color) -> Dictionary:
	var rc := 0.005
	var f := func(u: float, v: float, otw: bool) -> Vector3:
		var th := u * TAU
		var q := _wylot(th, a + 0.004, b + 0.004, 1.02 if otw else zx, 1.02 if otw else zz)
		var dirv := Vector3(q.x, 0, q.y).normalized() if q.length() > 0.001 else Vector3.RIGHT
		var ps := v * TAU
		return srodek + Vector3(q.x, y_o if otw else y_z, q.y) + (dirv * cos(ps) + Vector3.UP * sin(ps)) * rc
	var mi := T.powierzchnia(40, 6, func(u, v): return f.call(u, v, false), func(u, v): return f.call(u, v, true), kol, {})
	n.add_child(mi)
	# blokada sznurka i dwa końce zwisające z przodu
	var bl := _wezel(n, srodek + Vector3(0, y_z, b * zz + 0.012))
	_mi(bl, [{"t": "box", "c": Vector3(0, -0.012, 0.004), "s": Vector3(0.018, 0.026, 0.014), "m": "bakelit", "f": 0.005},
		{"t": "box", "c": Vector3(0, -0.001, 0.004), "s": Vector3(0.008, 0.004, 0.016), "m": "metal_jasny", "f": 0.001},
		B.walec(Vector3(-0.004, -0.025, 0.004), Vector3(-0.006, -0.075, 0.012), 0.004, 0.004, "bandaz", 5),
		B.walec(Vector3(0.004, -0.025, 0.004), Vector3(0.008, -0.068, 0.01), 0.004, 0.004, "bandaz", 5)])
	return {"sznur": mi, "blokada": bl, "bl_otw": srodek + Vector3(0, y_o - 0.004, b * 1.02 + 0.014)}


## Linia zębów zamka błyskawicznego wzdłuż łamanej (punkty w układzie węzła).
static func _zeby(n: Node3D, pts: Array, kol := Color(0.1, 0.1, 0.09)) -> void:
	var cz := []
	for i in pts.size() - 1:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var c := (p0 + p1) * 0.5
		var dl := p0.distance_to(p1)
		var kat := atan2(p1.x - p0.x, p1.z - p0.z)
		cz.append({"t": "box", "c": c, "s": Vector3(0.006, 0.004, dl + 0.004), "m": "czern", "k": kol, "f": 0.0, "r": Vector3(0, rad_to_deg(kat), 0)})
	_mi(n, cz)


## Suwak zamka z zawieszką.
static func _suwak(n: Node3D, poz: Vector3) -> Node3D:
	var s := _wezel(n, poz)
	_mi(s, [{"t": "box", "c": Vector3(0, 0, 0), "s": Vector3(0.014, 0.008, 0.02), "m": "metal_jasny", "f": 0.003},
		_t(Vector3(0, -0.002, 0.022), Vector3(0.008, 0.004, 0.024), TASMA, 0.0),
		{"t": "box", "c": Vector3(0, -0.002, 0.036), "s": Vector3(0.012, 0.006, 0.01), "m": "guma", "f": 0.002}])
	return s


## Klamra plastikowa (część żeńska na korpusie, męska na pasku).
static func _klamra_cz(c: Vector3, meska := false) -> Dictionary:
	return {"t": "box", "c": c, "s": Vector3(0.036, 0.03 if meska else 0.034, 0.012 if meska else 0.014), "m": "bakelit", "f": 0.004}


# ------------------------------------------------------------------ ładownica / kieszeń z zamknięciem

## Kieszeń przyszyta (plecak albo kamizelka): torba o dnie w `dno`, wylot do góry, przód do +Z.
## typ: rzep / zatrzask / guzik (klapa w dwóch częściach nad wylotem i na przodzie), zamek (płaska kieszeń,
## suwak w poprzek wylotu), sciagacz (siatka/elastyk ze sznurkiem). Zwraca {"kroki", "dzwieki"}.
static func _ladownica(n: Node3D, dno: Vector3, a: float, b: float, h: float, k: Color, typ: String, ziarno := 0, odchyl := -2.3) -> Dictionary:
	match typ:
		"zamek":
			var tb := torba(a, b, h, k, {"zx": 1.0, "zz": 0.18, "grudy": 0.05, "ziarno": ziarno, "opad": 0.03})
			_dodaj(n, tb, dno)
			var y := dno.y + h + 0.002
			_zeby(n, [Vector3(dno.x - a * 0.9, y, dno.z), Vector3(dno.x + a * 0.9, y, dno.z)])
			var su := _suwak(n, Vector3(dno.x - a * 0.85, y + 0.004, dno.z + 0.004))
			su.scale = Vector3.ONE * clampf(a * 9.0, 0.35, 1.0)
			return {"kroki": [[[su, "position:x", dno.x + a * 0.85, clampf(a * 3.0, 0.18, 0.55)]], [[tb, "blend_shapes/otw", 1.0, 0.3]]],
				"dzwieki": ["zamek", "plecak"]}
		"sciagacz":
			var zx := 0.72
			var zz := 0.5
			var tb2 := torba(a, b, h, k.lightened(0.05), {"zx": zx, "zz": zz, "kryza": true, "grudy": 0.06, "ziarno": ziarno})
			_dodaj(n, tb2, dno)
			var rr := minf(minf(a, b) * 0.45, h * 0.18)
			var sz := _sznur(n, dno, a - rr * 0.0, b, h * 0.93, h * 0.92, zx, zz, Color(0.75, 0.72, 0.62))
			var bl: Node3D = sz["blokada"]
			return {"kroki": [[[bl, "position:y", bl.position.y + 0.025, 0.22]],
				[[tb2, "blend_shapes/otw", 1.0, 0.45], [sz["sznur"], "blend_shapes/otw", 1.0, 0.45], [bl, "position", sz["bl_otw"], 0.45]]],
				"dzwieki": ["plecak", "plecak"]}
	# klapa: górna część nad wylotem (zawias z tyłu), przednia zwisa na przód kieszeni
	var tb3 := torba(a, b, h, k, {"zx": 0.92, "zz": 0.55, "grudy": 0.06, "ziarno": ziarno})
	_dodaj(n, tb3, dno)
	var g := clampf(minf(a, b) * 0.16, 0.003, 0.012)
	var top := dno.y + h
	var zaw := _wezel(n, Vector3(dno.x, top + g * 0.4, dno.z - b - 0.004))
	var dl1 := 2.0 * b + 0.01
	var p1 := T.plat(2.0 * a + 0.01, dl1, g, k.lightened(0.04), 0.002, g * 0.6, ziarno)
	zaw.add_child(p1)
	var przod := _wezel(zaw, Vector3(0, 0, dl1))
	przod.rotation.x = PI * 0.5
	var dl2 := clampf(h * 0.42, 0.012, 0.12)
	var p2 := T.plat(2.0 * a + 0.01, dl2, g, k.lightened(0.04), 0.001, g * 0.4, ziarno + 3)
	przod.add_child(p2)
	var dz := "rzep"
	match typ:
		"guzik":
			_mi(przod, [B.walec(Vector3(0, g * 0.6, dl2 * 0.72), Vector3(0, g * 0.6 + 0.004, dl2 * 0.72), minf(0.008, a * 0.2), minf(0.008, a * 0.2), "bakelit", 8)])
			dz = "klik"
		"zatrzask":
			_mi(przod, [B.walec(Vector3(0, g * 0.6, dl2 * 0.7), Vector3(0, g * 0.6 + 0.003, dl2 * 0.7), minf(0.006, a * 0.18), minf(0.006, a * 0.18), "metal_jasny", 8)])
			dz = "klik"
		_:
			# rzep: szorstka łata pod klapą (widać po odchyleniu)
			_mi(n, [_t(Vector3(dno.x, top - dl2 * 0.5, dno.z + b * 0.55 + 0.002), Vector3(a * 1.0, dl2 * 0.6, 0.003), k.darkened(0.35), 0.0)])
	return {"kroki": [[[przod, "rotation:x", 0.25, 0.16]], [[zaw, "rotation:x", odchyl, 0.3]], [[tb3, "blend_shapes/otw", 1.0, 0.3]]],
		"dzwieki": [dz, "plecak", "plecak"]}


# ------------------------------------------------------------------ worek

static func _worek(w: float, d: float, kieszenie: Array) -> Dictionary:
	var n := Node3D.new()
	var k: Color = KOLORY["worek"]
	var a := w * 0.5 + 0.01
	var b := d * 0.5 + 0.01
	var h := 0.4
	var zx := 0.16
	var zz := 0.16
	var tb := torba(a, b, h, k, {"zx": zx, "zz": zz, "kryza": true, "mankiet": 0.035, "opad": 0.1, "grudy": 0.08, "sup": 3.2, "ziarno": 7})
	n.add_child(tb)
	# zszyte boki (szew juty) i nadruk
	_mi(n, [_t(Vector3(0, h * 0.4, b * 1.02 + 0.004), Vector3(a * 0.9, h * 0.22, 0.002), k.darkened(0.35), 0.0)])
	var sz := _sznur(n, Vector3.ZERO, a, b, h * 0.93, h * 0.9 * 0.93, zx, zz, Color(0.78, 0.72, 0.55))
	var bl: Node3D = sz["blokada"]
	var kz := [{"kroki": [[[bl, "position:y", bl.position.y + 0.03, 0.3]],
		[[tb, "blend_shapes/otw", 1.0, 0.7], [sz["sznur"], "blend_shapes/otw", 1.0, 0.7], [bl, "position", sz["bl_otw"], 0.7]]],
		"dzwieki": ["plecak", "plecak"]}]
	while kz.size() < kieszenie.size():
		kz.append({"kroki": [], "dzwieki": []})
	return {"wezel": n, "gora": Vector3(0, h * 0.86, 0), "kroki": [], "kieszenie": kz}


# ------------------------------------------------------------------ plecak stojący (turystyczny, zasobnik)

static func _plecak_stojacy(id: String, w: float, d: float, kieszenie: Array) -> Dictionary:
	var n := Node3D.new()
	var k: Color = KOLORY.get(id, Color(0.3, 0.33, 0.24))
	var wojsk := id == "plecak_wojskowy"
	var gi := _glowna(kieszenie)
	var rm: Rect2 = kieszenie[gi]["r"]
	# korpus wypełnia też szczeliny między kieszeniami (przyszyte bezpośrednio do ścian)
	var x0 := rm.position.x
	var x1 := rm.end.x
	for i in kieszenie.size():
		if i == gi:
			continue
		var r: Rect2 = kieszenie[i]["r"]
		if r.end.x <= rm.position.x + 0.001:
			x0 = minf(x0, r.end.x + 0.006)
		elif r.position.x >= rm.end.x - 0.001:
			x1 = maxf(x1, r.position.x - 0.006)
	var cx := (x0 + x1) * 0.5
	var cz := rm.get_center().y
	var a := (x1 - x0) * 0.5
	var b := rm.size.y * 0.5 + 0.01
	var h := 0.48 if wojsk else 0.42
	var zx := 0.78
	var zz := 0.7
	var tb := torba(a, b, h, k, {"zx": zx, "zz": zz, "kryza": true, "opad": 0.04, "grudy": 0.05, "ziarno": 3})
	_dodaj(n, tb, Vector3(cx, 0, cz))
	# plecy: usztywniony panel i szelki od strony dalszej
	var plecy := T.poduszka(a * 2.0 - 0.02, 0.03, h * 0.85, k.darkened(0.3), 0.08, 2)
	plecy.rotation.x = -PI * 0.5
	_dodaj(n, plecy, Vector3(cx, h * 0.08, cz - b - 0.012))
	var cz2 := []
	for sx in [-0.5, 0.5]:
		cz2.append(_t(Vector3(cx + sx * a, h * 0.5, cz - b - 0.04), Vector3(0.05, h * 0.8, 0.02), k.darkened(0.4), 0.008))
	# uchwyt i pasy kompresyjne po bokach
	cz2.append(_t(Vector3(cx, h + 0.012, cz - b + 0.01), Vector3(0.07, 0.01, 0.02), TASMA, 0.003))
	for sx in [-1.0, 1.0]:
		for y in ([0.3, 0.6] if wojsk else [0.45]):
			cz2.append(_t(Vector3(cx + sx * (a + 0.004), h * y, cz), Vector3(0.006, 0.02, b * 1.6), TASMA, 0.0))
	_mi(n, cz2)
	var sz := _sznur(n, Vector3(cx, 0, cz), a, b, h * 0.93, h * 0.92 * 0.96, zx, zz, Color(0.2, 0.2, 0.18) if wojsk else Color(0.75, 0.3, 0.2))
	var bl: Node3D = sz["blokada"]
	# klapa z dwoma paskami i klamrami (zasobnik: skórzane paski z metalowymi sprzączkami)
	var hk := 0.07
	var zaw := _wezel(n, Vector3(cx, h + 0.004, cz - b - 0.01))
	var dkl := 2.0 * b + 0.04
	var klapa := T.poduszka(a * 2.0 + 0.03, hk, dkl, k.lightened(0.04), 0.05, 5)
	_dodaj(zaw, klapa, Vector3(0, -0.012, dkl * 0.5))
	var paski := []
	for sx in [-0.42, 0.42]:
		var p := _wezel(zaw, Vector3(sx * a, 0.02, dkl + 0.004))
		var dlp := 0.15
		_mi(p, [_t(Vector3(0, -dlp * 0.5, 0.004), Vector3(0.03, dlp, 0.006), SKORA if wojsk else TASMA, 0.0),
			{"t": "box", "c": Vector3(0, -dlp, 0.008), "s": Vector3(0.03, 0.026, 0.006), "m": "metal_jasny" if wojsk else "bakelit", "f": 0.003}])
		paski.append(p)
		# część klamry na korpusie
		_mi(n, [_klamra_cz(Vector3(cx + sx * a, h - 0.17, cz + b * zz * 0.0 + b + 0.01)), _t(Vector3(cx + sx * a, h - 0.22, cz + b + 0.005), Vector3(0.03, 0.08, 0.004), TASMA, 0.0)])
	var kz := []
	for i in kieszenie.size():
		var e: Dictionary = kieszenie[i]
		if i == gi:
			kz.append({"kroki": [[[paski[0], "rotation:x", -1.3, 0.2]], [[paski[1], "rotation:x", -1.3, 0.2]],
				[[zaw, "rotation:x", -3.25, 0.55]], [[bl, "position:y", bl.position.y + 0.03, 0.2]],
				[[tb, "blend_shapes/otw", 1.0, 0.5], [sz["sznur"], "blend_shapes/otw", 1.0, 0.5], [bl, "position", sz["bl_otw"], 0.5]]],
				"dzwieki": ["klik", "klik", "plecak", "plecak", "plecak"]})
			continue
		var r: Rect2 = e["r"]
		var typ := String(e["typ"])
		var przednia := r.position.y >= rm.end.y - 0.01
		var hp := h * (0.55 if przednia else 0.58)
		var y0 := h * (0.08 if przednia else 0.22)
		var bz := r.size.y * 0.5
		var zc := r.get_center().y
		if przednia:
			bz = minf(bz, 0.05)
			zc = rm.end.y + 0.012 + bz
		kz.append(_ladownica(n, Vector3(r.get_center().x, y0, zc), r.size.x * 0.5, bz, hp, k.darkened(0.05) if typ != "sciagacz" else k.lightened(0.08), typ, i * 5 + 1))
	return {"wezel": n, "gora": Vector3(cx, h * 0.9, cz), "kroki": [], "kieszenie": kz}


# ------------------------------------------------------------------ plecak szturmowy (leży, panel na zamek U)

static func _szturmowy(w: float, d: float, kieszenie: Array) -> Dictionary:
	var n := Node3D.new()
	var k: Color = KOLORY["plecak_szturmowy"]
	var gi := _glowna(kieszenie)
	var rm: Rect2 = kieszenie[gi]["r"]
	var cx := rm.get_center().x
	var cz := rm.get_center().y
	var a := rm.size.x * 0.5 + 0.012
	var b := rm.size.y * 0.5 + 0.012
	var h := 0.15
	# wanna korpusu (otwarta) z podszewką
	var rr := 0.035
	var ai := a - rr
	var bi := b - rr
	var prof := func(v: float) -> Vector3: return T.prof_skrzynki(v, h, rr, true)
	var fald := func(th: float, v: float) -> float: return 0.03 * sin(th * 4.0 + 1.0) * clampf((v - 0.4) * 2.0, 0.0, 1.0)
	var tw := T.powierzchnia(32, 14, T.obrotowa(ai, bi, 8.0, prof, fald), Callable(), k, {"podszewka": k.darkened(0.3),
		"ao": func(_u, v): return lerpf(0.7, 1.0, clampf(v * 3.0, 0.0, 1.0))})
	_dodaj(n, tw, Vector3(cx, 0, cz))
	# szelki pod spodem, uchwyt, pasy kompresyjne
	var cz2 := []
	for sx in [-0.3, 0.3]:
		cz2.append(_t(Vector3(cx + sx * a * 2.0, 0.008, cz), Vector3(0.05, 0.016, b * 1.7), k.darkened(0.35), 0.006))
	for sz2 in [-0.35, 0.35]:
		for sx2 in [-1.0, 1.0]:
			cz2.append(_t(Vector3(cx + sx2 * (a + 0.004), h * 0.55, cz + sz2 * b), Vector3(0.006, 0.02, 0.06), TASMA, 0.0))
			cz2.append(_klamra_cz(Vector3(cx + sx2 * (a + 0.01), h * 0.55, cz + sz2 * b)))
	_mi(n, cz2)
	# panel przedni (okładka) z taśmami MOLLE, zawias na dalszej krawędzi
	var zaw := _wezel(n, Vector3(cx, h - 0.004, cz - b))
	var panel := T.poduszka(a * 2.0 + 0.008, 0.045, b * 2.0 + 0.006, k.lightened(0.03), 0.06, 9)
	_dodaj(zaw, panel, Vector3(0, -0.01, b))
	var molle := []
	for i in 4:
		molle.append(_t(Vector3(0, 0.042 + 0.006, b * 0.45 + i * b * 0.32), Vector3(a * 1.6, 0.004, 0.022), TASMA, 0.0))
	_mi(zaw, molle)
	# zamek w kształcie U po brzegu panelu i suwak, który go obiega
	var y := h + 0.03
	var A := Vector3(cx - a + 0.01, y, cz - b + 0.02)
	var Bp := Vector3(cx - a + 0.01, y, cz + b - 0.01)
	var C := Vector3(cx + a - 0.01, y, cz + b - 0.01)
	var D := Vector3(cx + a - 0.01, y, cz - b + 0.02)
	_zeby(n, [A, Bp, C, D])
	var su := _suwak(n, A + Vector3(0, 0.004, 0))
	var kz := []
	for i in kieszenie.size():
		if i == gi:
			kz.append({"kroki": [[[su, "position", Bp + Vector3(0, 0.004, 0), 0.3]], [[su, "position", C + Vector3(0, 0.004, 0), 0.3]],
				[[su, "position", D + Vector3(0, 0.004, 0), 0.3]], [[zaw, "rotation:x", -2.9, 0.45]]],
				"dzwieki": ["zamek", "zamek", "zamek", "plecak"]})
			continue
		var r: Rect2 = kieszenie[i]["r"]
		kz.append(_ladownica(n, Vector3(r.get_center().x, 0, r.get_center().y), r.size.x * 0.5, r.size.y * 0.5, h + 0.01, k.darkened(0.04), String(kieszenie[i]["typ"]), i * 3 + 2))
	return {"wezel": n, "gora": Vector3(cx, h * 0.7, cz), "kroki": [], "kieszenie": kz}


# ------------------------------------------------------------------ chlebak (stoi, długa klapa)

static func _chlebak(w: float, d: float, kieszenie: Array) -> Dictionary:
	var n := Node3D.new()
	var k: Color = KOLORY["chlebak"]
	var gi := _glowna(kieszenie)
	var rm: Rect2 = kieszenie[gi]["r"]
	var cx := rm.get_center().x
	var cz := rm.get_center().y
	var a := rm.size.x * 0.5 + 0.01
	var b := rm.size.y * 0.5 + 0.01
	var h := 0.26
	var tb := torba(a, b, h, k, {"zx": 1.0, "zz": 0.45, "grudy": 0.04, "opad": 0.03, "ziarno": 11})
	_dodaj(n, tb, Vector3(cx, 0, cz))
	# pas nośny zwinięty z boku
	_mi(n, [_t(Vector3(cx + a + 0.012, h * 0.55, cz), Vector3(0.014, 0.035, b * 1.8), SKORA.lightened(0.15), 0.0)])
	# klapa: wierzch nad wylotem + długi przód; pasek ze sprzączką
	var g := 0.012
	var zaw := _wezel(n, Vector3(cx, h + 0.006, cz - b - 0.004))
	var dl1 := 2.0 * b + 0.012
	zaw.add_child(T.plat(2.0 * a + 0.02, dl1, g, k.lightened(0.05), 0.002, 0.012, 4))
	var przod := _wezel(zaw, Vector3(0, 0, dl1))
	przod.rotation.x = PI * 0.5
	var dl2 := 0.12
	przod.add_child(T.plat(2.0 * a + 0.02, dl2, g, k.lightened(0.05), 0.003, 0.006, 6))
	var pas := _wezel(przod, Vector3(0, g, dl2 - 0.01))
	_mi(pas, [_t(Vector3(0, 0.003, 0.03), Vector3(0.02, 0.004, 0.07), SKORA, 0.0)])
	_mi(n, [{"t": "box", "c": Vector3(cx, h - dl2 - 0.04, cz + b + 0.012), "s": Vector3(0.026, 0.022, 0.006), "m": "metal_jasny", "f": 0.002},
		_t(Vector3(cx, h - dl2 - 0.065, cz + b + 0.006), Vector3(0.02, 0.04, 0.004), SKORA, 0.0)])
	var kz := []
	for i in kieszenie.size():
		if i == gi:
			kz.append({"kroki": [[[pas, "rotation:x", -1.4, 0.2]], [[przod, "rotation:x", 0.2, 0.3]], [[zaw, "rotation:x", -2.95, 0.45]],
				[[tb, "blend_shapes/otw", 1.0, 0.35]]], "dzwieki": ["klik", "plecak", "plecak", "plecak"]})
			continue
		var r: Rect2 = kieszenie[i]["r"]
		var bz := 0.03
		kz.append(_ladownica(n, Vector3(r.get_center().x, 0.03, rm.end.y + 0.012 + bz), r.size.x * 0.5, bz, 0.11, k.darkened(0.05), String(kieszenie[i]["typ"]), i * 7))
	return {"wezel": n, "gora": Vector3(cx, h * 0.85, cz + 0.02), "kroki": [], "kieszenie": kz}


# ------------------------------------------------------------------ kontener bezpieczny (kaseta)

static func _kontener(w: float, d: float, kieszenie: Array) -> Dictionary:
	var n := Node3D.new()
	var h := 0.09
	_mi(n, [{"t": "box", "c": Vector3(0, h * 0.5, 0), "s": Vector3(w, h, d), "m": "metal", "f": 0.008},
		{"t": "box", "c": Vector3(0, h - 0.004, 0), "s": Vector3(w - 0.03, 0.01, d - 0.03), "m": "czern", "f": 0.0},
		{"t": "box", "c": Vector3(0, h * 0.5, d * 0.5 + 0.004), "s": Vector3(w * 0.3, 0.012, 0.008), "m": "metal_jasny", "f": 0.003}])
	var kz := []
	for e in kieszenie:
		var r: Rect2 = e["r"]
		var cx := r.get_center().x
		var wieko := _wezel(n, Vector3(cx, h, r.position.y))
		_mi(wieko, [{"t": "box", "c": Vector3(0, 0.012, r.size.y * 0.5), "s": Vector3(r.size.x + 0.01, 0.024, r.size.y + 0.01), "m": "metal", "f": 0.006}])
		var zat := []
		for sx in [-0.3, 0.3]:
			var z := _wezel(n, Vector3(cx + sx * r.size.x, h - 0.02, r.end.y + 0.004))
			_mi(z, [{"t": "box", "c": Vector3(0, 0.015, 0.004), "s": Vector3(0.03, 0.035, 0.008), "m": "metal_jasny", "f": 0.003}])
			zat.append(z)
		kz.append({"kroki": [[[zat[0], "rotation:x", 1.6, 0.16]], [[zat[1], "rotation:x", 1.6, 0.16]], [[wieko, "rotation:x", -2.0, 0.34]]],
			"dzwieki": ["klik", "klik", "plecak"]})
	return {"wezel": n, "gora": Vector3(0, h, 0), "kroki": [], "kieszenie": kz}


# ------------------------------------------------------------------ kamizelki

static func _kamizelka(id: String, w: float, d: float, kieszenie: Array) -> Dictionary:
	var k: Color = KOLORY.get(id, Color(0.3, 0.32, 0.24))
	var n := Node3D.new()
	var W2 := w * 0.5 + 0.016
	var H2 := d * 0.5 + 0.02
	var ram := 0.045 if id != "napiersnik" else 0.07
	# sylwetka: przód z podkrojami pach, szelki nad barkami, wycięcie pod szyję
	var pts := [Vector2(-W2, -H2 + 0.01), Vector2(-W2 + 0.01, -H2), Vector2(W2 - 0.01, -H2), Vector2(W2, -H2 + 0.01), Vector2(W2, H2 - 0.01),
		Vector2(w * 0.47, H2 + ram * 0.35), Vector2(w * 0.42, H2 + ram * 0.8), Vector2(w * 0.38, H2 + ram), Vector2(w * 0.24, H2 + ram),
		Vector2(w * 0.2, H2 + ram * 0.55), Vector2(w * 0.12, H2 + ram * 0.1), Vector2(0.0, H2 - 0.004),
		Vector2(-w * 0.12, H2 + ram * 0.1), Vector2(-w * 0.2, H2 + ram * 0.55), Vector2(-w * 0.24, H2 + ram), Vector2(-w * 0.38, H2 + ram),
		Vector2(-w * 0.42, H2 + ram * 0.8), Vector2(-w * 0.47, H2 + ram * 0.35), Vector2(-W2, H2 - 0.01)]
	var cz := [B.profil(pts, 0.012, "tkanina", 0.004, 0.0, Vector3(0, 0, -0.008), Vector3(0, 90, 0), k.darkened(0.15))]
	match id:
		"kamizelka_wedkarska":
			cz.append(_t(Vector3(0, 0, 0.0), Vector3(0.005, d + 0.04, 0.004), Color(0.2, 0.2, 0.18), 0.0))   # zamek z przodu
			cz.append({"t": "box", "c": Vector3(0.006, H2 - 0.01, 0.002), "s": Vector3(0.006, 0.008, 0.004), "m": "metal_jasny", "f": 0.001})
		"kamizelka_lbv":
			for y in [-0.36, 0.0, 0.36]:
				cz.append(_t(Vector3(0, y * d, -0.0005), Vector3(w + 0.03, 0.012, 0.004), k.darkened(0.35), 0.0))  # taśmy
		"kamizelka_mysliwska":
			cz.append(_t(Vector3(0, H2 - 0.012, -0.0005), Vector3(w + 0.03, 0.018, 0.004), Color(0.85, 0.42, 0.1), 0.002))  # pomarańczowy pas
			cz.append(_t(Vector3(0, 0, -0.0005), Vector3(0.004, d + 0.03, 0.004), k.darkened(0.4), 0.0))
		"napiersnik":
			# szelki krzyżowe za plecy i boczne taśmy
			for sx in [-1.0, 1.0]:
				cz.append(_t(Vector3(sx * W2, 0, -0.004), Vector3(0.012, 0.012, 0.004), TASMA, 0.0))
				cz.append(_klamra_cz(Vector3(sx * (W2 + 0.012), 0.0, -0.002)))
	_mi(n, cz)
	var kz := []
	for i in kieszenie.size():
		var e: Dictionary = kieszenie[i]
		var r: Rect2 = e["r"]
		var hh := r.size.y - 0.004
		var a := r.size.x * 0.5 - 0.002
		var bz := clampf(a * 0.35, 0.008, 0.016) if TYP_LADOWNIC.get(id, "rzep") != "zamek" else 0.006
		# dno ładownicy: środek dolnej krawędzi; ładownica stoi na płycie (przód +Z)
		kz.append(_ladownica(n, Vector3(r.get_center().x, r.position.y - r.size.y + 0.002, bz + 0.002), a, bz, hh, k.lightened(0.02), String(e["typ"]), i * 3 + 1, -1.75))
	return {"wezel": n, "gora": Vector3(0, 0, 0.01), "kroki": [], "kieszenie": kz}
