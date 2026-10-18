class_name ModeleOporzadzenia
extends RefCounted
## Osobne modele 3D każdego plecaka, kamizelki i kontenera z własną sekwencją otwierania:
## worek ze ściągaczem (rozluźnienie sznurka, rozchylenie brzegów), plecak turystyczny (dwa paski
## z klamrami, potem klapa), szturmowy (zamek błyskawiczny obiega krawędź, panel opada), chlebak
## (sprzączka, długa klapa), wojskowy (klamry, klapa, boczne kieszenie), kontener (dwa zatrzaski, wieko),
## kamizelki (klapki ładownic na rzepy odchylane kolejno).
##
## Plecaki i kontener leżą na podłodze: otwór u góry (+Y), głębokość wzdłuż Z (d), szerokość X (w).
## Kamizelka stoi przed kamerą: płyta w płaszczyźnie XY, przodem do +Z (w = szerokość, d = wysokość).
## Zwraca {"wezel", "gora" (środek wnętrza), "kroki": [[[węzeł, właściwość, wartość, czas], ...], ...]}
## – kroki wykonywane po kolei, w kroku wszystkie zmiany równolegle; zamknięcie odwraca kolejność.

const B := preload("res://scripts/core/bryly.gd")

const KOLORY := {
	"worek": Color(0.62, 0.56, 0.42), "plecak_turystyczny": Color(0.36, 0.42, 0.5), "plecak_szturmowy": Color(0.3, 0.33, 0.24),
	"chlebak": Color(0.44, 0.42, 0.3), "plecak_wojskowy": Color(0.28, 0.31, 0.21),
	"napiersnik": Color(0.33, 0.35, 0.25), "kamizelka_lbv": Color(0.3, 0.32, 0.24), "kamizelka_wedkarska": Color(0.6, 0.56, 0.42),
	"kamizelka_mysliwska": Color(0.5, 0.36, 0.2),
}


static func _mi(rodzic: Node3D, cz: Array) -> MeshInstance3D:
	var mi := B.instancja(cz)
	rodzic.add_child(mi)
	return mi


static func _t(c: Vector3, s: Vector3, k: Color, f := 0.01, rot := Vector3.ZERO) -> Dictionary:
	return {"t": "box", "c": c, "s": s, "m": "tkanina", "k": k, "f": f, "r": rot}


static func _zawias(rodzic: Node3D, poz: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = poz
	rodzic.add_child(n)
	return n


static func zbuduj(id: String, w: float, d: float, kieszenie: Array = []) -> Dictionary:
	match id:
		"napiersnik", "kamizelka_lbv", "kamizelka_wedkarska", "kamizelka_mysliwska":
			return _kamizelka(id, w, d, kieszenie)
	if kieszenie.is_empty():
		# bez podziału (np. model leżący na ziemi): jedna zamknięta komora
		var typ := "wieko" if id in ["kontener", "bezpieczny"] else ("sciagacz" if id == "worek" else "klapa")
		kieszenie = [{"r": Rect2(-w * 0.5 + 0.02, -d * 0.5 + 0.02, w - 0.04, d - 0.04), "typ": typ}]
	return _plecak(id, w, d, kieszenie)


## Korpus leżącego plecaka: dno, ściany, ciemne wnętrze.
static func _korpus(n: Node3D, w: float, d: float, h: float, k: Color, gr := 0.035) -> void:
	var cz := [
		_t(Vector3(0, 0.02, 0), Vector3(w, 0.04, d), k, 0.015),
		_t(Vector3(-w * 0.5 + gr * 0.5, h * 0.5, 0), Vector3(gr, h, d), k, 0.012),
		_t(Vector3(w * 0.5 - gr * 0.5, h * 0.5, 0), Vector3(gr, h, d), k, 0.012),
		_t(Vector3(0, h * 0.5, d * 0.5 - gr * 0.5), Vector3(w, h, gr), k, 0.012),
		_t(Vector3(0, h * 0.5, -d * 0.5 + gr * 0.5), Vector3(w, h, gr), k, 0.012),
		_t(Vector3(0, h - 0.025, 0), Vector3(w - gr * 2.0, 0.008, d - gr * 2.0), k.darkened(0.7), 0.0),
	]
	_mi(n, cz)


static func _klamra(c: Vector3, rot := Vector3.ZERO) -> Dictionary:
	return {"t": "box", "c": c, "s": Vector3(0.04, 0.008, 0.03), "m": "bakelit", "f": 0.003, "r": rot}


## Korpus plecaka (bez klap – te nakłada _kieszen na każdą kieszeń z osobna).
static func _cialo(id: String, w: float, d: float) -> Array:
	var n := Node3D.new()
	var k: Color = KOLORY.get(id, Color(0.3, 0.33, 0.24))
	var h := 0.12
	match id:
		"worek":
			h = 0.12
			_korpus(n, w, d, h, k, 0.03)
		"plecak_turystyczny":
			h = 0.13
			_korpus(n, w, d, h, k)
			var cz := []
			for sx in [-1.0, 1.0]:
				cz.append(B.walec(Vector3(sx * (w * 0.5 + 0.012), 0.03, d * 0.5), Vector3(sx * (w * 0.5 + 0.012), 0.03, -d * 0.5), 0.008, 0.008, "metal_jasny", 6))
				cz.append(_t(Vector3(sx * (w * 0.5 + 0.03), h * 0.42, 0.0), Vector3(0.05, h * 0.75, d * 0.45), k.darkened(0.15), 0.014))
			_mi(n, cz)
		"plecak_szturmowy":
			h = 0.11
			_korpus(n, w, d, h, k)
			var cz2 := []
			for sx in [-1.0, 1.0]:
				for i in 3:
					cz2.append(_t(Vector3(sx * (w * 0.5 + 0.004), h * 0.5, -d * 0.3 + i * d * 0.3), Vector3(0.008, 0.02, 0.05), k.darkened(0.3), 0.0))
			_mi(n, cz2)
		"chlebak":
			h = 0.09
			_korpus(n, w, d, h, k, 0.025)
			_mi(n, [_t(Vector3(w * 0.5 + 0.01, h * 0.6, 0), Vector3(0.012, 0.03, d * 0.9), Color(0.25, 0.2, 0.12), 0.0)])
		"plecak_wojskowy":
			h = 0.15
			_korpus(n, w, d, h, k, 0.04)
			var cz3 := []
			# stelaż i pasy nośne pod spodem
			for sx in [-0.32, 0.32]:
				cz3.append(_t(Vector3(sx * w, 0.012, d * 0.1), Vector3(0.05, 0.02, d * 0.85), k.darkened(0.35), 0.006))
			_mi(n, cz3)
		_:
			# kontener bezpieczny: metalowa kaseta
			h = 0.09
			_mi(n, [{"t": "box", "c": Vector3(0, h * 0.5, 0), "s": Vector3(w, h, d), "m": "metal", "f": 0.008},
				{"t": "box", "c": Vector3(0, h - 0.004, 0), "s": Vector3(w - 0.03, 0.01, d - 0.03), "m": "czern", "f": 0.0}])
	return [n, h, k]


## Klapa / zamek / rzep / ściągacz / wieko jednej kieszeni nad prostokątem `r` (x, z w metrach modelu).
## Zwraca {"kroki": [...], "dzwieki": [...]} – kroki jak w otwieraniu całego pojemnika.
static func _kieszen(n: Node3D, h: float, r: Rect2, typ: String, k: Color) -> Dictionary:
	var x0 := r.position.x
	var z0 := r.position.y
	var wx := r.size.x
	var dz := r.size.y
	var cx := x0 + wx * 0.5
	var z1 := z0 + dz
	var kol := k.lightened(0.05)
	match typ:
		"sciagacz":
			var lz := _zawias(n, Vector3(x0 + 0.02, h, z0 + dz * 0.5))
			_mi(lz, [_t(Vector3(wx * 0.25, 0.012, 0), Vector3(wx * 0.5, 0.02, dz * 0.95), kol, 0.008)])
			var pz := _zawias(n, Vector3(x0 + wx - 0.02, h, z0 + dz * 0.5))
			_mi(pz, [_t(Vector3(-wx * 0.25, 0.012, 0), Vector3(wx * 0.5, 0.02, dz * 0.95), kol, 0.008)])
			var sznur := Node3D.new()
			sznur.position = Vector3(cx, h + 0.03, z1 - 0.02)
			n.add_child(sznur)
			_mi(sznur, [B.walec(Vector3(0, 0, 0), Vector3(0, 0.03, 0.02), 0.004, 0.004, "bandaz", 6),
				{"t": "box", "c": Vector3(0, 0.035, 0.022), "s": Vector3(0.016, 0.022, 0.016), "m": "bakelit", "f": 0.004}])
			return {"kroki": [[[sznur, "position:y", h + 0.08, 0.35]], [[lz, "rotation:z", 1.75, 0.4], [pz, "rotation:z", -1.75, 0.4]]],
				"dzwieki": ["plecak", "plecak"]}
		"wieko":
			var wieko := _zawias(n, Vector3(cx, h, z0))
			_mi(wieko, [{"t": "box", "c": Vector3(0, 0.012, dz * 0.5), "s": Vector3(wx + 0.01, 0.024, dz + 0.01), "m": "metal", "f": 0.006}])
			var zat := []
			for sx in [-0.3, 0.3]:
				var z := _zawias(n, Vector3(cx + sx * wx, h - 0.02, z1 + 0.004))
				_mi(z, [{"t": "box", "c": Vector3(0, 0.015, 0.004), "s": Vector3(0.03, 0.035, 0.008), "m": "metal_jasny", "f": 0.003}])
				zat.append(z)
			return {"kroki": [[[zat[0], "rotation:x", 1.6, 0.16]], [[zat[1], "rotation:x", 1.6, 0.16]], [[wieko, "rotation:x", -2.0, 0.34]]],
				"dzwieki": ["klik", "klik", "plecak"]}
		"zamek":
			var panel := _zawias(n, Vector3(cx, h, z0))
			_mi(panel, [_t(Vector3(0, 0.014, dz * 0.5), Vector3(wx + 0.006, 0.026, dz + 0.006), kol, 0.01),
				_t(Vector3(0, 0.028, dz - 0.006), Vector3(wx * 0.96, 0.004, 0.006), Color(0.1, 0.1, 0.09), 0.0)])
			var suwak := Node3D.new()
			suwak.position = Vector3(x0 + 0.01, h + 0.03, z1)
			n.add_child(suwak)
			_mi(suwak, [{"t": "box", "c": Vector3(0, 0.0, 0.01), "s": Vector3(0.016, 0.01, 0.026), "m": "metal_jasny", "f": 0.003},
				_t(Vector3(0, -0.004, 0.03), Vector3(0.01, 0.004, 0.02), Color(0.12, 0.12, 0.1), 0.0)])
			return {"kroki": [[[suwak, "position:x", x0 + wx - 0.01, clampf(wx * 1.4, 0.2, 0.55)]], [[panel, "rotation:x", -2.85, 0.36]]],
				"dzwieki": ["zamek", "plecak"]}
		"rzep":
			var kl := _zawias(n, Vector3(cx, h + 0.002, z0))
			_mi(kl, [_t(Vector3(0, 0.01, dz * 0.5), Vector3(wx + 0.004, 0.018, dz + 0.004), kol.darkened(0.08), 0.008),
				_t(Vector3(0, 0.02, dz * 0.85), Vector3(wx * 0.5, 0.003, dz * 0.2), k.darkened(0.3), 0.0)])
			return {"kroki": [[[kl, "rotation:x", -2.4, 0.2]]], "dzwieki": ["rzep"]}
	# klapa z paskiem i klamrą
	var klapa := _zawias(n, Vector3(cx, h, z0))
	_mi(klapa, [_t(Vector3(0, 0.02, dz * 0.5 + 0.01), Vector3(wx + 0.02, 0.04, dz + 0.02), kol, 0.016),
		_t(Vector3(0, 0.042, dz * 0.62), Vector3(wx * 0.5, 0.01, dz * 0.28), k.darkened(0.1), 0.006)])
	var paski := []
	for sx in ([-0.28, 0.28] if wx > 0.2 else [0.0]):
		var p := _zawias(n, Vector3(cx + sx * wx, h + 0.04, z1 + 0.012))
		_mi(p, [_t(Vector3(0, -0.035, 0.008), Vector3(0.032, 0.08, 0.006), Color(0.12, 0.12, 0.1), 0.0), _klamra(Vector3(0, -0.05, 0.014), Vector3(90, 0, 0))])
		paski.append(p)
	var kroki := []
	var dzw := []
	for p in paski:
		kroki.append([[p, "rotation:x", -1.9, 0.2]])
		dzw.append("klik")
	kroki.append([[klapa, "rotation:x", -2.75, 0.42]])
	dzw.append("plecak")
	return {"kroki": kroki, "dzwieki": dzw}


## Plecak / kontener z osobnymi kieszeniami. kieszenie: [{"r": Rect2 (x, z, szer, gł. w metrach), "typ"}]
static func _plecak(id: String, w: float, d: float, kieszenie: Array) -> Dictionary:
	var c := _cialo(id, w, d)
	var n: Node3D = c[0]
	var h: float = c[1]
	var k: Color = c[2]
	var kz := []
	for e in kieszenie:
		kz.append(_kieszen(n, h, e["r"], String(e["typ"]), k))
	return {"wezel": n, "gora": Vector3(0, h, 0), "kroki": [], "kieszenie": kz}


## Kieszenie pojemnika: z definicji ("kieszenie": [x, y, szer, wys, nazwa, typ]), z przegródek układu
## albo cała siatka jako jedna komora.
static func kieszenie_dla(id: String, s: Siatka) -> Array:
	var out := []
	var d: Dictionary = Dane.def(id).get("pojemnik", {})
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
				out.append({"r": Rect2i(mn, mx - mn + Vector2i.ONE), "nazwa": "Ładownica", "typ": "rzep"})
		return out
	var typ := "wieko" if id in ["kontener", "bezpieczny"] else "klapa"
	out.append({"r": Rect2i(0, 0, s.w, s.h), "nazwa": "Kontener" if typ == "wieko" else "Komora", "typ": typ})
	return out


## Kamizelki: płyta z ładownicami; klapki ładownic odchylane po kolei (rzepy / zatrzaski).
static func _kamizelka(id: String, w: float, d: float, kieszenie: Array = []) -> Dictionary:
	var k: Color = KOLORY.get(id, Color(0.3, 0.32, 0.24))
	var n := Node3D.new()
	var cz := [_t(Vector3(0, 0, -0.012), Vector3(w + 0.04, d + 0.05, 0.03), k.darkened(0.15), 0.012)]
	# szelki / pasy barkowe
	for sx in [-0.32, 0.32]:
		cz.append(_t(Vector3(sx * w, d * 0.5 + 0.035, -0.04), Vector3(0.04, 0.07, 0.015), k.darkened(0.2), 0.005, Vector3(-55, 0, 0)))
	match id:
		"kamizelka_wedkarska":
			cz.append(_t(Vector3(0, 0, 0.004), Vector3(0.006, d + 0.04, 0.004), Color(0.2, 0.2, 0.18), 0.0))    # zamek z przodu
		"kamizelka_lbv":
			for y in [-0.3, 0.0, 0.3]:
				cz.append(_t(Vector3(0, y * d, 0.004), Vector3(w + 0.06, 0.018, 0.008), k.darkened(0.3), 0.0))  # taśmy
		"kamizelka_mysliwska":
			cz.append(_t(Vector3(0, d * 0.42, 0.004), Vector3(w + 0.04, 0.03, 0.008), Color(0.85, 0.42, 0.1), 0.004))  # pomarańczowy pas
	_mi(n, cz)
	if not kieszenie.is_empty():
		# osobna klapka na rzep nad każdą ładownicą (r: x lewej krawędzi, y górnej, szer., wys.)
		var kz := []
		for e in kieszenie:
			var r: Rect2 = e["r"]
			var cx := r.position.x + r.size.x * 0.5
			var kl := _zawias(n, Vector3(cx, r.position.y, 0.014))
			var hgt := r.size.y
			_mi(kl, [_t(Vector3(0, -hgt * 0.5, 0.007), Vector3(r.size.x * 0.96, hgt, 0.014), k.lightened(0.04), 0.005),
				_t(Vector3(0, -hgt * 0.82, 0.015), Vector3(minf(0.03, r.size.x * 0.5), hgt * 0.12, 0.004), k.darkened(0.3), 0.0)])
			# korpus ładownicy pod klapką
			_mi(n, [_t(Vector3(cx, r.position.y - hgt * 0.5, 0.004), Vector3(r.size.x * 0.98, hgt, 0.01), k.darkened(0.1), 0.004)])
			kz.append({"kroki": [[[kl, "rotation:x", -2.3, 0.14]]], "dzwieki": ["rzep"]})
		return {"wezel": n, "gora": Vector3(0, 0, 0.01), "kroki": [], "kieszenie": kz}
	# klapki: tyle co kolumn ładownic (pas u góry płyty)
	var ile := 4 if id in ["napiersnik", "kamizelka_lbv"] else 3
	var kroki := []
	var grupa := []
	for i in ile:
		var x := lerpf(-w * 0.5 + w / ile * 0.5, w * 0.5 - w / ile * 0.5, float(i) / maxf(1.0, ile - 1))
		var kl := _zawias(n, Vector3(x, d * 0.5, 0.012))
		_mi(kl, [_t(Vector3(0, -0.025, 0.006), Vector3(w / ile * 0.85, 0.05, 0.012), k, 0.006),
			_t(Vector3(0, -0.045, 0.013), Vector3(0.02, 0.012, 0.004), k.darkened(0.3), 0.0)])
		grupa.append([kl, "rotation:x", -2.2, 0.12 + i * 0.04])
	kroki.append(grupa)
	return {"wezel": n, "gora": Vector3(0, 0, 0.01), "kroki": kroki}
