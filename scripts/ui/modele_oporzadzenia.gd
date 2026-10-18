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


static func zbuduj(id: String, w: float, d: float) -> Dictionary:
	match id:
		"worek":
			return _worek(w, d)
		"plecak_turystyczny":
			return _turystyczny(w, d)
		"plecak_szturmowy":
			return _szturmowy(w, d)
		"chlebak":
			return _chlebak(w, d)
		"plecak_wojskowy":
			return _wojskowy(w, d)
		"bezpieczny", "kontener":
			return _kontener(w, d)
		"napiersnik", "kamizelka_lbv", "kamizelka_wedkarska", "kamizelka_mysliwska":
			return _kamizelka(id, w, d)
	return _turystyczny(w, d)


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


static func _worek(w: float, d: float) -> Dictionary:
	var k: Color = KOLORY["worek"]
	var n := Node3D.new()
	var h := 0.12
	_korpus(n, w, d, h, k, 0.03)
	# brzegi worka zebrane ściągaczem: dwie połowy kołnierza rozchylane na boki, sznurek z zaciskiem
	var lz := _zawias(n, Vector3(-w * 0.5 + 0.02, h, 0))
	_mi(lz, [_t(Vector3(w * 0.25, 0.012, 0), Vector3(w * 0.5, 0.02, d * 0.95), k.lightened(0.05), 0.008)])
	lz.rotation.z = 1.3
	var pz := _zawias(n, Vector3(w * 0.5 - 0.02, h, 0))
	_mi(pz, [_t(Vector3(-w * 0.25, 0.012, 0), Vector3(w * 0.5, 0.02, d * 0.95), k.lightened(0.05), 0.008)])
	pz.rotation.z = -1.3
	var sznur := Node3D.new()
	sznur.position = Vector3(0, h + 0.03, d * 0.42)
	n.add_child(sznur)
	_mi(sznur, [B.walec(Vector3(0, 0, 0), Vector3(0, 0.03, 0.02), 0.004, 0.004, "bandaz", 6),
		{"t": "box", "c": Vector3(0, 0.035, 0.022), "s": Vector3(0.016, 0.022, 0.016), "m": "bakelit", "f": 0.004}])
	return {"wezel": n, "gora": Vector3(0, h, 0), "kroki": [
		[[sznur, "position:y", h + 0.08, 0.3]],
		[[lz, "rotation:z", -0.45, 0.35], [pz, "rotation:z", 0.45, 0.35]],
	]}


static func _turystyczny(w: float, d: float) -> Dictionary:
	var k: Color = KOLORY["plecak_turystyczny"]
	var n := Node3D.new()
	var h := 0.13
	_korpus(n, w, d, h, k)
	# stelaż (rurki) po bokach i kieszenie boczne
	var cz := []
	for sx in [-1.0, 1.0]:
		cz.append(B.walec(Vector3(sx * (w * 0.5 + 0.012), 0.03, d * 0.5), Vector3(sx * (w * 0.5 + 0.012), 0.03, -d * 0.5), 0.008, 0.008, "metal_jasny", 6))
		cz.append(_t(Vector3(sx * (w * 0.5 + 0.03), h * 0.42, 0.0), Vector3(0.05, h * 0.75, d * 0.45), k.darkened(0.15), 0.014))
	_mi(n, cz)
	# klapa z dwoma paskami; paski z klamrami najpierw odpinane
	var klapa := _zawias(n, Vector3(0, h, -d * 0.5))
	_mi(klapa, [_t(Vector3(0, 0.02, d * 0.5 + 0.01), Vector3(w + 0.02, 0.04, d + 0.02), k.lightened(0.06), 0.016),
		_t(Vector3(0, 0.045, d * 0.6), Vector3(w * 0.5, 0.012, d * 0.3), k.darkened(0.1), 0.006)])
	var paski := []
	for sx in [-0.28, 0.28]:
		var p := _zawias(n, Vector3(sx * w, h + 0.03, d * 0.5 + 0.005))
		_mi(p, [_t(Vector3(0, -0.03, 0.008), Vector3(0.035, 0.07, 0.006), Color(0.12, 0.12, 0.1), 0.0), _klamra(Vector3(0, -0.04, 0.014), Vector3(90, 0, 0))])
		paski.append(p)
	return {"wezel": n, "gora": Vector3(0, h, 0), "kroki": [
		[[paski[0], "rotation:x", -1.9, 0.22]],
		[[paski[1], "rotation:x", -1.9, 0.22]],
		[[klapa, "rotation:x", -2.75, 0.4]],
	]}


static func _szturmowy(w: float, d: float) -> Dictionary:
	var k: Color = KOLORY["plecak_szturmowy"]
	var n := Node3D.new()
	var h := 0.11
	_korpus(n, w, d, h, k)
	# zamek dookoła: suwak obiega bliższą krawędź i boki, potem panel przedni (z molle) opada do tyłu
	var suwak := Node3D.new()
	suwak.position = Vector3(-w * 0.5, h + 0.004, d * 0.5)
	n.add_child(suwak)
	_mi(suwak, [{"t": "box", "c": Vector3(0, 0.006, 0.012), "s": Vector3(0.016, 0.01, 0.03), "m": "metal_jasny", "f": 0.003}])
	var panel := _zawias(n, Vector3(0, h, -d * 0.5))
	var cz := [_t(Vector3(0, 0.018, d * 0.5), Vector3(w, 0.034, d), k.lightened(0.04), 0.014)]
	for i in 4:
		cz.append(_t(Vector3(0, 0.037, d * (0.25 + i * 0.17)), Vector3(w * 0.8, 0.005, 0.02), k.darkened(0.25), 0.0))
	_mi(panel, cz)
	return {"wezel": n, "gora": Vector3(0, h, 0), "kroki": [
		[[suwak, "position:x", w * 0.5, 0.45]],
		[[panel, "rotation:x", -2.9, 0.38]],
	]}


static func _chlebak(w: float, d: float) -> Dictionary:
	var k: Color = KOLORY["chlebak"]
	var n := Node3D.new()
	var h := 0.09
	_korpus(n, w, d, h, k, 0.025)
	var klapa := _zawias(n, Vector3(0, h, -d * 0.5))
	_mi(klapa, [_t(Vector3(0, 0.012, d * 0.62), Vector3(w + 0.03, 0.022, d * 1.24), k.lightened(0.07), 0.012)])
	var sprzaczka := _zawias(klapa, Vector3(0, 0.024, d * 1.18))
	_mi(sprzaczka, [_t(Vector3(0, 0, 0.02), Vector3(0.03, 0.006, 0.05), Color(0.2, 0.15, 0.1), 0.0),
		{"t": "box", "c": Vector3(0, 0.004, 0.035), "s": Vector3(0.03, 0.006, 0.02), "m": "metal_jasny", "f": 0.002}])
	return {"wezel": n, "gora": Vector3(0, h, 0), "kroki": [
		[[sprzaczka, "rotation:x", -2.2, 0.22]],
		[[klapa, "rotation:x", -3.0, 0.42]],
	]}


static func _wojskowy(w: float, d: float) -> Dictionary:
	var k: Color = KOLORY["plecak_wojskowy"]
	var n := Node3D.new()
	var h := 0.15
	_korpus(n, w, d, h, k, 0.04)
	# boczne ładownice z klapkami
	var boczne := []
	for sx in [-1.0, 1.0]:
		_mi(n, [_t(Vector3(sx * (w * 0.5 + 0.035), h * 0.4, -d * 0.1), Vector3(0.06, h * 0.7, d * 0.35), k.darkened(0.12), 0.012)])
		var kl := _zawias(n, Vector3(sx * (w * 0.5 + 0.035), h * 0.78, -d * 0.1 - d * 0.175))
		_mi(kl, [_t(Vector3(0, 0.006, d * 0.175), Vector3(0.065, 0.012, d * 0.36), k, 0.005)])
		boczne.append(kl)
	var klapa := _zawias(n, Vector3(0, h, -d * 0.5))
	_mi(klapa, [_t(Vector3(0, 0.022, d * 0.52), Vector3(w + 0.03, 0.044, d + 0.04), k.lightened(0.05), 0.018)])
	var klamry := []
	for sx in [-0.3, 0.3]:
		var p := _zawias(n, Vector3(sx * w, h + 0.04, d * 0.5 + 0.02))
		_mi(p, [_t(Vector3(0, -0.035, 0.008), Vector3(0.03, 0.08, 0.006), k.darkened(0.3), 0.0), _klamra(Vector3(0, -0.06, 0.014), Vector3(90, 0, 0))])
		klamry.append(p)
	return {"wezel": n, "gora": Vector3(0, h, 0), "kroki": [
		[[klamry[0], "rotation:x", -1.9, 0.2], [klamry[1], "rotation:x", -1.9, 0.26]],
		[[klapa, "rotation:x", -2.7, 0.42], [boczne[0], "rotation:x", -1.4, 0.3], [boczne[1], "rotation:x", -1.4, 0.34]],
	]}


static func _kontener(w: float, d: float) -> Dictionary:
	var n := Node3D.new()
	var h := 0.09
	var met := [
		{"t": "box", "c": Vector3(0, h * 0.5, 0), "s": Vector3(w, h, d), "m": "metal", "f": 0.008},
		{"t": "box", "c": Vector3(0, h - 0.004, 0), "s": Vector3(w - 0.03, 0.01, d - 0.03), "m": "czern", "f": 0.0},
	]
	_mi(n, met)
	var wieko := _zawias(n, Vector3(0, h, -d * 0.5))
	_mi(wieko, [{"t": "box", "c": Vector3(0, 0.012, d * 0.5), "s": Vector3(w + 0.01, 0.024, d + 0.01), "m": "metal", "f": 0.006}])
	var zatrzaski := []
	for sx in [-0.3, 0.3]:
		var z := _zawias(n, Vector3(sx * w, h - 0.02, d * 0.5 + 0.004))
		_mi(z, [{"t": "box", "c": Vector3(0, 0.015, 0.004), "s": Vector3(0.03, 0.035, 0.008), "m": "metal_jasny", "f": 0.003}])
		zatrzaski.append(z)
	return {"wezel": n, "gora": Vector3(0, h, 0), "kroki": [
		[[zatrzaski[0], "rotation:x", 1.6, 0.14]],
		[[zatrzaski[1], "rotation:x", 1.6, 0.14]],
		[[wieko, "rotation:x", -2.0, 0.32]],
	]}


## Kamizelki: płyta z ładownicami; klapki ładownic odchylane po kolei (rzepy / zatrzaski).
static func _kamizelka(id: String, w: float, d: float) -> Dictionary:
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
