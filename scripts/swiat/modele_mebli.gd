class_name ModeleMebli
extends RefCounted
## Meble-pojemniki z ruchomymi częściami (zamiast statycznych .glb): szafa i szafka ubraniowa z drzwiami
## na zawiasach, meblościanka z szafką, szafka kuchenna z dwojgiem drzwiczek, lodówka ze światłem
## w środku, biurko z szufladami, skrzynie z wiekiem i zatrzaskami, apteczka ścienna.
## Pusty korpus z ciemnym wnętrzem i półkami – po otwarciu widać, co jest w środku (kafelki siatki
## rzutowane są na „wnetrze”).
## Układ jak w .glb: początek na podłodze pośrodku, przód mebla w stronę +Z.
## Zwraca {"wezel", "kroki" (jak ModeleOporzadzenia), "wnetrze": Vector3, "niski": bool,
##         "dzwiek": "drzwi"|"szuflada"|"wieko", "swiatlo": OmniLight3D|null}

const B := preload("res://scripts/core/bryly.gd")

const TYLKO_PATRZ := ["regal_metalowy", "stol_warsztatowy"]   # otwarte półki: bez ruchomych części


static func ma(id: String) -> bool:
	return id in ["szafa", "szafka_metalowa", "meblosciana", "szafka_kuchenna", "lodowka", "biurko",
		"skrzynia_wojskowa", "skrzynia", "apteczka_scienna"]


static func _b(c: Vector3, s: Vector3, m: String, k := Color.WHITE, f := 0.006) -> Dictionary:
	return {"t": "box", "c": c, "s": s, "m": m, "f": f, "k": k, "r": Vector3.ZERO}


static func _mi(rodzic: Node3D, cz: Array) -> MeshInstance3D:
	var mi := B.instancja(cz, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rodzic.add_child(mi)
	return mi


static func _wezel(rodzic: Node3D, poz: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = poz
	rodzic.add_child(n)
	return n


## Pusty korpus: boki, góra, dno, plecy; wnętrze przyciemnione. x0..x1, y0..y1, z0 (tył)..z1 (przód).
static func _korpus(cz: Array, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, m: String, g := 0.018) -> void:
	var w := x1 - x0
	var h := y1 - y0
	var d := z1 - z0
	var cx := (x0 + x1) * 0.5
	var cy := (y0 + y1) * 0.5
	var cz_ := (z0 + z1) * 0.5
	cz.append(_b(Vector3(x0 + g * 0.5, cy, cz_), Vector3(g, h, d), m))
	cz.append(_b(Vector3(x1 - g * 0.5, cy, cz_), Vector3(g, h, d), m))
	cz.append(_b(Vector3(cx, y1 - g * 0.5, cz_), Vector3(w, g, d), m))
	cz.append(_b(Vector3(cx, y0 + g * 0.5, cz_), Vector3(w, g, d), m))
	cz.append(_b(Vector3(cx, cy, z0 + 0.004), Vector3(w - g * 2.0, h - g * 2.0, 0.008), m, Color(0.32, 0.3, 0.28), 0.0))


static func _polka(cz: Array, x0: float, x1: float, y: float, z0: float, z1: float, m: String) -> void:
	cz.append(_b(Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.016, z1 - z0), m, Color(0.6, 0.58, 0.55), 0.002))


## Drzwi na zawiasie: zawias w (hx, y0..y1, z), skrzydło w stronę `kier` (+1: w prawo od zawiasu).
static func _drzwi(n: Node3D, hx: float, y0: float, y1: float, z: float, szer: float, kier: float, m: String, gr := 0.018, uchwyt := true) -> Node3D:
	var zaw := _wezel(n, Vector3(hx, 0, z))
	var cz := [_b(Vector3(kier * szer * 0.5, (y0 + y1) * 0.5, gr * 0.5), Vector3(szer - 0.004, y1 - y0, gr), m)]
	# wewnętrzna strona drzwi (ciemniejsza)
	cz.append(_b(Vector3(kier * szer * 0.5, (y0 + y1) * 0.5, -0.001), Vector3(szer - 0.03, y1 - y0 - 0.03, 0.002), m, Color(0.55, 0.52, 0.5), 0.0))
	if uchwyt:
		var uy := clampf((y0 + y1) * 0.5, y0 + 0.08, y0 + 1.0)
		cz.append(_b(Vector3(kier * (szer - 0.045), uy, gr + 0.012), Vector3(0.016, 0.11, 0.016), "metal_ciemny_m", Color.WHITE, 0.004))
	_mi(zaw, cz)
	return zaw


static func zbuduj(id: String) -> Dictionary:
	match id:
		"szafa":
			return _szafa(1.0, 1.9, 0.6, "fornir_m", true)
		"szafka_metalowa":
			return _szafa(0.5, 1.8, 0.45, "szafka_m", false)
		"meblosciana":
			return _meblosciana()
		"szafka_kuchenna":
			return _kuchenna()
		"lodowka":
			return _lodowka()
		"biurko":
			return _biurko()
		"skrzynia_wojskowa":
			return _skrzynia(1.0, 0.5, 0.56, "metal_zielony_m", true)
		"skrzynia":
			return _skrzynia(0.6, 0.6, 0.6, "drewno_m", false)
		"apteczka_scienna":
			return _apteczka()
	return {}


## Szafa dwudrzwiowa (fornir) albo szafka ubraniowa (blacha, jedne drzwi z żaluzją).
static func _szafa(w: float, h: float, d: float, m: String, dwoje: bool) -> Dictionary:
	var n := Node3D.new()
	var cz := []
	var z0 := -d * 0.5
	var z1 := d * 0.5 - 0.02
	_korpus(cz, -w * 0.5, w * 0.5, 0.0, h, z0, z1, m)
	_polka(cz, -w * 0.5 + 0.02, w * 0.5 - 0.02, h * 0.72, z0 + 0.01, z1 - 0.02, m)
	_polka(cz, -w * 0.5 + 0.02, w * 0.5 - 0.02, h * 0.3, z0 + 0.01, z1 - 0.02, m)
	# drążek na ubrania
	cz.append(B.walec(Vector3(-w * 0.5 + 0.02, h * 0.66, 0.0), Vector3(w * 0.5 - 0.02, h * 0.66, 0.0), 0.012, 0.012, "metal_ciemny_m", 8))
	_mi(n, cz)
	var kroki := []
	if dwoje:
		var l := _drzwi(n, -w * 0.5, 0.02, h - 0.02, z1, w * 0.5, 1.0, m)
		var p := _drzwi(n, w * 0.5, 0.02, h - 0.02, z1, w * 0.5, -1.0, m)
		kroki = [[[p, "rotation:y", 1.75, 0.45]], [[l, "rotation:y", -1.6, 0.45]]]
	else:
		var dz := _drzwi(n, -w * 0.5, 0.02, h - 0.02, z1, w, 1.0, m)
		kroki = [[[dz, "rotation:y", -1.85, 0.55]]]
	return {"wezel": n, "kroki": kroki, "wnetrze": Vector3(0, h * 0.5, 0.0), "niski": false, "dzwiek": "drzwi", "swiatlo": null}


static func _meblosciana() -> Dictionary:
	var w := 2.4
	var h := 2.0
	var d := 0.5
	var n := Node3D.new()
	var cz := []
	var m := "fornir_m"
	# boczne kolumny pełne, środek: u góry przeszklona witryna (półki), na dole szafka z dwojgiem drzwiczek
	cz.append(_b(Vector3(-0.8, h * 0.5, 0), Vector3(0.8, h, d), m))
	cz.append(_b(Vector3(0.8, h * 0.5, 0), Vector3(0.8, h, d), m))
	cz.append(_b(Vector3(0, h - 0.15, 0), Vector3(0.8, 0.3, d), m))
	cz.append(_b(Vector3(0, 0.88, 0), Vector3(0.8, 0.04, d), m))
	cz.append({"t": "quad", "c": Vector3(0, 1.3, d * 0.5 - 0.02), "s": Vector2(0.8, 0.8), "n": Vector3(0, 0, 1), "m": "regal_polki_q", "k": Color.WHITE})
	cz.append(_b(Vector3(0, 1.3, d * 0.5 - 0.06), Vector3(0.8, 0.8, 0.01), m, Color(0.3, 0.28, 0.26), 0.0))
	_korpus(cz, -0.4, 0.4, 0.0, 0.86, -d * 0.5, d * 0.5 - 0.02, m)
	_polka(cz, -0.38, 0.38, 0.43, -d * 0.5 + 0.01, d * 0.5 - 0.05, m)
	for x in [-0.8, 0.8]:
		cz.append(_b(Vector3(x, 0.55, d * 0.5 + 0.012), Vector3(0.04, 0.1, 0.024), "metal_ciemny_m", Color.WHITE, 0.004))
	_mi(n, cz)
	var l := _drzwi(n, -0.4, 0.02, 0.86, d * 0.5 - 0.02, 0.4, 1.0, m)
	var p := _drzwi(n, 0.4, 0.02, 0.86, d * 0.5 - 0.02, 0.4, -1.0, m)
	return {"wezel": n, "kroki": [[[l, "rotation:y", -1.7, 0.4]], [[p, "rotation:y", 1.7, 0.4]]],
		"wnetrze": Vector3(0, 0.45, 0.0), "niski": true, "dzwiek": "drzwi", "swiatlo": null}


static func _kuchenna() -> Dictionary:
	var n := Node3D.new()
	var cz := []
	var m := "fornir_m"
	_korpus(cz, -0.6, 0.6, 0.08, 0.85, -0.3, 0.28, m)
	_polka(cz, -0.58, 0.58, 0.45, -0.29, 0.25, m)
	cz.append(_b(Vector3(0, 0.0, 0) + Vector3(0, 0.87, 0.005), Vector3(1.24, 0.04, 0.63), "lastryko_m", Color.WHITE, 0.006))
	cz.append(_b(Vector3(0, 0.04, -0.01), Vector3(1.16, 0.08, 0.54), "metal_ciemny_m", Color.WHITE, 0.0))
	_mi(n, cz)
	var l := _drzwi(n, -0.6, 0.1, 0.83, 0.28, 0.6, 1.0, m)
	var p := _drzwi(n, 0.6, 0.1, 0.83, 0.28, 0.6, -1.0, m)
	return {"wezel": n, "kroki": [[[l, "rotation:y", -1.65, 0.38], [p, "rotation:y", 1.65, 0.42]]],
		"wnetrze": Vector3(0, 0.45, 0.0), "niski": true, "dzwiek": "drzwi", "swiatlo": null}


static func _lodowka() -> Dictionary:
	var n := Node3D.new()
	var cz := []
	var m := "emalia_m"
	_korpus(cz, -0.3, 0.3, 0.0, 1.5, -0.3, 0.27, m, 0.03)
	# wnętrze lodówki jasne (biała emalia), druciane półki, zamrażalnik u góry
	cz.append(_b(Vector3(0, 0.75, -0.26), Vector3(0.52, 1.42, 0.01), m, Color(0.85, 0.85, 0.82), 0.0))
	for y in [0.45, 0.8]:
		cz.append(_b(Vector3(0, y, 0.0), Vector3(0.52, 0.01, 0.5), "metal_jasny", Color(0.8, 0.8, 0.8), 0.0))
	cz.append(_b(Vector3(0, 1.22, 0.0), Vector3(0.5, 0.2, 0.46), m, Color(0.8, 0.82, 0.85), 0.01))
	_mi(n, cz)
	var dz := _drzwi(n, -0.3, 0.02, 1.48, 0.27, 0.6, 1.0, m, 0.05, false)
	_mi(dz, [_b(Vector3(0.5, 0.95, 0.07), Vector3(0.025, 0.28, 0.03), "metal_ciemny_m", Color.WHITE, 0.006),
		_b(Vector3(0.3, 1.1, 0.05), Vector3(0.6, 0.012, 0.004), "metal_ciemny_m", Color.WHITE, 0.0),
		# półeczki na drzwiach od środka
		_b(Vector3(0.3, 0.5, -0.04), Vector3(0.46, 0.06, 0.06), m, Color(0.85, 0.85, 0.82), 0.004),
		_b(Vector3(0.3, 0.9, -0.04), Vector3(0.46, 0.06, 0.06), m, Color(0.85, 0.85, 0.82), 0.004)])
	var sw := OmniLight3D.new()
	sw.position = Vector3(0, 1.0, 0.05)
	sw.omni_range = 1.2
	sw.light_color = Color(0.9, 0.95, 1.0)
	sw.light_energy = 0.0
	sw.shadow_enabled = false
	n.add_child(sw)
	return {"wezel": n, "kroki": [[[dz, "rotation:y", -1.75, 0.5]], [[sw, "light_energy", 0.7, 0.08]]],
		"wnetrze": Vector3(0, 0.8, 0.0), "niski": false, "dzwiek": "drzwi", "swiatlo": sw}


static func _biurko() -> Dictionary:
	var n := Node3D.new()
	var cz := []
	var m := "fornir_m"
	cz.append(_b(Vector3(0, 0.74, 0), Vector3(1.3, 0.04, 0.7), m))
	cz.append(_b(Vector3(-0.605, 0.36, 0), Vector3(0.05, 0.72, 0.66), m))
	cz.append(_b(Vector3(-0.19, 0.51, -0.315), Vector3(0.78, 0.42, 0.03), m))
	# kontener szuflad: pusty korpus (szuflady wysuwają się z niego)
	_korpus(cz, 0.2, 0.63, 0.0, 0.72, -0.33, 0.33, m)
	_mi(n, cz)
	var szuf := []
	var ys := [[0.5, 0.7], [0.27, 0.48], [0.03, 0.25]]
	for yy in ys:
		var s := _wezel(n, Vector3(0.415, 0, 0))
		var y0: float = yy[0]
		var y1: float = yy[1]
		var hc := y1 - y0
		var sc := [
			_b(Vector3(0, (y0 + y1) * 0.5, 0.33), Vector3(0.42, hc, 0.02), m),                    # front
			_b(Vector3(0, y0 + 0.02, 0.06), Vector3(0.38, 0.012, 0.52), m, Color(0.5, 0.48, 0.45), 0.0),   # dno
			_b(Vector3(-0.185, y0 + hc * 0.4, 0.06), Vector3(0.012, hc * 0.7, 0.52), m, Color(0.6, 0.58, 0.55), 0.0),
			_b(Vector3(0.185, y0 + hc * 0.4, 0.06), Vector3(0.012, hc * 0.7, 0.52), m, Color(0.6, 0.58, 0.55), 0.0),
			_b(Vector3(0, y0 + hc * 0.4, -0.2), Vector3(0.38, hc * 0.7, 0.012), m, Color(0.6, 0.58, 0.55), 0.0),
			_b(Vector3(0, (y0 + y1) * 0.5 + 0.02, 0.35), Vector3(0.07, 0.02, 0.02), "metal_ciemny_m", Color.WHITE, 0.004),
		]
		_mi(s, sc)
		szuf.append(s)
	# górna szuflada wysuwa się, potem druga (przeszukuje się obie)
	return {"wezel": n, "kroki": [[[szuf[0], "position:z", 0.3, 0.3]], [[szuf[1], "position:z", 0.26, 0.3]]],
		"wnetrze": Vector3(0.415, 0.52, 0.42), "niski": true, "dzwiek": "szuflada", "swiatlo": null}


static func _skrzynia(w: float, h: float, d: float, m: String, wojskowa: bool) -> Dictionary:
	var n := Node3D.new()
	var cz := []
	var g := 0.025
	_korpus(cz, -w * 0.5, w * 0.5, 0.0, h - 0.06, -d * 0.5, d * 0.5, m, g)
	# korpus ma przód: _korpus robi tylko plecy, dokładamy przednią ścianę
	cz.append(_b(Vector3(0, (h - 0.06) * 0.5, d * 0.5 - g * 0.5), Vector3(w, h - 0.06, g), m))
	# wnętrze ciemne + dno
	cz.append(_b(Vector3(0, 0.03, 0), Vector3(w - g * 2, 0.01, d - g * 2), m, Color(0.3, 0.3, 0.28), 0.0))
	if not wojskowa:
		for y in [0.15, 0.35]:
			cz.append(_b(Vector3(0, y, d * 0.5 + 0.004), Vector3(w + 0.006, 0.08, 0.01), m, Color(0.8, 0.75, 0.7), 0.003))
	else:
		for sx in [-1.0, 1.0]:
			cz.append(_b(Vector3(sx * (w * 0.5 + 0.012), h * 0.55, 0), Vector3(0.024, 0.04, 0.16), "metal_ciemny_m", Color.WHITE, 0.004))
	_mi(n, cz)
	var wieko := _wezel(n, Vector3(0, h - 0.06, -d * 0.5))
	_mi(wieko, [_b(Vector3(0, 0.03, d * 0.5), Vector3(w + 0.01, 0.06, d + 0.01), m),
		_b(Vector3(0, -0.002, d * 0.5), Vector3(w - 0.06, 0.004, d - 0.06), m, Color(0.45, 0.43, 0.4), 0.0)])
	var kroki := []
	if wojskowa:
		# dwa zatrzaski odchylane po kolei, potem wieko
		var zat := []
		for x in [-0.38, 0.38]:
			var z := _wezel(n, Vector3(x * w, h - 0.08, d * 0.5 + 0.006))
			_mi(z, [_b(Vector3(0, -0.03, 0.006), Vector3(0.07, 0.07, 0.012), "metal_ciemny_m", Color.WHITE, 0.004)])
			zat.append(z)
		kroki = [[[zat[0], "rotation:x", 1.5, 0.15]], [[zat[1], "rotation:x", 1.5, 0.15]], [[wieko, "rotation:x", -1.85, 0.5]]]
	else:
		kroki = [[[wieko, "rotation:x", -1.95, 0.55]]]
	return {"wezel": n, "kroki": kroki, "wnetrze": Vector3(0, h * 0.6, 0.0), "niski": true, "dzwiek": "wieko", "swiatlo": null}


static func _apteczka() -> Dictionary:
	# wisi na ścianie: plecy w z = 0, przód w z = 0.14
	var n := Node3D.new()
	var cz := []
	var m := "emalia_m"
	_korpus(cz, -0.2, 0.2, 0.0, 0.45, 0.0, 0.12, m, 0.014)
	_polka(cz, -0.19, 0.19, 0.22, 0.01, 0.11, m)
	_mi(n, cz)
	var zaw := _wezel(n, Vector3(-0.2, 0, 0.12))
	_mi(zaw, [_b(Vector3(0.2, 0.225, 0.01), Vector3(0.4, 0.45, 0.02), m),
		{"t": "quad", "c": Vector3(0.2, 0.225, 0.0205), "s": Vector2(0.38, 0.43), "n": Vector3(0, 0, 1), "m": "apteczka_sciana_q", "k": Color.WHITE}])
	return {"wezel": n, "kroki": [[[zaw, "rotation:y", -1.9, 0.35]]], "wnetrze": Vector3(0, 0.22, 0.07),
		"niski": false, "dzwiek": "drzwi", "swiatlo": null}


## Wartości początkowe (do zamknięcia) – odczytane z węzłów przed animacją.
static func wartosci_startowe(kroki: Array) -> Array:
	var out := []
	for krok in kroki:
		var k2 := []
		for zm in krok:
			k2.append((zm[0] as Node).get_indexed(NodePath(String(zm[1]))))
		out.append(k2)
	return out
