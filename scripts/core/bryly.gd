class_name Bryly
extends RefCounted
## Bryły do modeli w stylu Iron Blight: prostopadłościany z fazą, walce/stożki o n bokach, każda część
## z własnym materiałem (tekstura w niskiej rozdzielczości, ostre piksele) i mapowaniem UV w metrach,
## żeby gęstość tekseli była stała niezależnie od rozmiaru części.
##
## Część to słownik: {"t": "box"|"walec", ...}
##   box:   "c" środek, "s" rozmiar, "f" faza (m), "r" obrót w stopniach, "m" materiał
##   walec: "a" początek osi, "b" koniec osi, "r0"/"r1" promienie, "n" boki, "m" materiał, "kat" obrót wokół osi

const SHADER := preload("res://shaders/psx.gdshader")
## materiał -> [tekstura, metry na powtórzenie tekstury, chropowatość, połysk, emisja]
const MATERIALY := {
	"skora": ["skora", 0.09, 0.75, 0.3, 0.16],
	"paznokiec": ["skora", 0.09, 0.4, 0.5, 0.18],
	"rekaw": ["rekaw", 0.12, 0.95, 0.1, 0.12],
	"mankiet": ["rekaw", 0.08, 0.95, 0.1, 0.1],
	"metal": ["metal_bron", 0.2, 0.62, 0.35, 0.14],
	"metal_jasny": ["metal_jasny", 0.12, 0.5, 0.45, 0.16],
	"drewno": ["drewno_bron", 0.2, 0.6, 0.4, 0.14],
	"bakelit": ["bakelit", 0.12, 0.7, 0.35, 0.13],
	"okladzina": ["okladzina", 0.05, 0.8, 0.25, 0.13],
	"czern": ["bakelit", 0.3, 0.9, 0.2, 0.0],
	"guma": ["bakelit", 0.08, 0.95, 0.1, 0.1],
	"zegarek": ["metal_jasny", 0.05, 0.3, 0.8, 0.2],
	"tarcza": ["tarcza_zegarka", 0.034, 0.5, 0.5, 0.35],
	"pasek": ["pasek_zegarka", 0.06, 0.9, 0.15, 0.12],
	"latarka": ["metal_bron", 0.12, 0.55, 0.5, 0.14],
	# postacie (kolor nadaje "k" – odcień tkaniny frakcji)
	"tkanina": ["tkanina_npc", 0.25, 0.95, 0.1, 0.0],
	"skora_npc": ["skora_npc", 0.2, 0.8, 0.25, 0.0],
	"twarz": ["twarz", 1.0, 0.8, 0.25, 0.0],
	"twarz_maska": ["twarz_maska", 1.0, 0.9, 0.1, 0.0],
	"but": ["bakelit", 0.2, 0.7, 0.3, 0.0],
}

static var _mat := {}


static func material(nazwa: String, vm := true, tint := Color.WHITE) -> ShaderMaterial:
	var k := "%s|%s|%s" % [nazwa, vm, tint.to_html()]
	if _mat.has(k):
		return _mat[k]
	var d: Array = MATERIALY.get(nazwa, MATERIALY["metal"])
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo_tex", load("res://assets/textures/%s.png" % d[0]))
	m.set_shader_parameter("chropowatosc", d[2])
	m.set_shader_parameter("polysk", d[3])
	m.set_shader_parameter("tint", tint)
	if vm:
		# broń i ręce lekko podświetlone, żeby były czytelne w ciemności (jak w Iron Blight)
		m.set_shader_parameter("use_emission", true)
		m.set_shader_parameter("emission_energy", d[4])
	_mat[k] = m
	return m


static func skala_uv(nazwa: String) -> float:
	var d: Array = MATERIALY.get(nazwa, MATERIALY["metal"])
	return 1.0 / float(d[1])


## Buduje siatkę z listy części; jedna powierzchnia na materiał.
static func siatka(czesci: Array, vm := true) -> ArrayMesh:
	var grupy := {}
	var mat_grup := {}
	for c in czesci:
		var m: String = c.get("m", "metal")
		var tint: Color = c.get("k", Color.WHITE)
		var klucz := m + "|" + tint.to_html()
		if not grupy.has(klucz):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			grupy[klucz] = st
			mat_grup[klucz] = material(m, vm, tint)
		match String(c.get("t", "box")):
			"box":
				_box(grupy[klucz], c, skala_uv(m))
			"walec":
				_walec(grupy[klucz], c, skala_uv(m))
			"quad":
				_quad_uv(grupy[klucz], c)
			"profil":
				_profil(grupy[klucz], c, skala_uv(m))
	var mesh := ArrayMesh.new()
	for klucz in grupy:
		var st: SurfaceTool = grupy[klucz]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat_grup[klucz])
	return mesh


## Czworokąt z pełnym UV 0..1 (twarz, naszywki): środek c, rozmiar s (szer, wys), zwrócony w stronę n.
static func quad(c: Vector3, s: Vector2, n: Vector3, m: String, k := Color.WHITE) -> Dictionary:
	return {"t": "quad", "c": c, "s": s, "n": n, "m": m, "k": k}


static func _quad_uv(st: SurfaceTool, c: Dictionary) -> void:
	var n: Vector3 = (c["n"] as Vector3).normalized()
	var gora := Vector3.UP if absf(n.y) < 0.95 else Vector3.FORWARD
	var prawo := gora.cross(n).normalized()
	gora = n.cross(prawo).normalized()
	var s: Vector2 = c["s"]
	var o: Vector3 = c["c"]
	var p := [o - prawo * s.x * 0.5 - gora * s.y * 0.5, o + prawo * s.x * 0.5 - gora * s.y * 0.5,
		o + prawo * s.x * 0.5 + gora * s.y * 0.5, o - prawo * s.x * 0.5 + gora * s.y * 0.5]
	var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	_tri(st, [p[0], p[1], p[2]], [uv[0], uv[1], uv[2]], n)
	_tri(st, [p[0], p[2], p[3]], [uv[0], uv[2], uv[3]], n)


static func instancja(czesci: Array, vm := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = siatka(czesci, vm)
	mi.set_meta("bryly", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ------------------------------------------------------------------ prymitywy

static func box(c: Vector3, s: Vector3, m: String, faza := 0.0, rot := Vector3.ZERO) -> Dictionary:
	return {"t": "box", "c": c, "s": s, "m": m, "f": faza, "r": rot}


static func walec(a: Vector3, b: Vector3, r0: float, r1: float, m: String, n := 8, kat := 0.0) -> Dictionary:
	return {"t": "walec", "a": a, "b": b, "r0": r0, "r1": r1, "m": m, "n": n, "kat": kat}


static func _tri(st: SurfaceTool, p: Array, uv: Array, n: Vector3) -> void:
	# Godot: przód trójkąta = wierzchołki zgodnie ze wskazówkami zegara patrząc od zewnątrz
	if (p[1] - p[0]).cross(p[2] - p[0]).dot(n) > 0.0:
		p = [p[0], p[2], p[1]]
		uv = [uv[0], uv[2], uv[1]]
	for i in 3:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(p[i])


static func _poly(st: SurfaceTool, pts: Array, n: Vector3, sk: float) -> void:
	# wielokąt wypukły (wachlarz), UV z rzutu na płaszczyznę ściany
	var u: Vector3 = ((pts[1] as Vector3) - (pts[0] as Vector3)).normalized()
	var v: Vector3 = n.cross(u).normalized()
	var uvs := []
	for p in pts:
		var pp: Vector3 = (p as Vector3) - (pts[0] as Vector3)
		uvs.append(Vector2(pp.dot(u), pp.dot(v)) * sk)
	for i in range(1, pts.size() - 1):
		_tri(st, [pts[0], pts[i], pts[i + 1]], [uvs[0], uvs[i], uvs[i + 1]], n)


## Prostopadłościan z fazą na wszystkich krawędziach (ścięte narożniki = 26 ścian).
static func _box(st: SurfaceTool, c: Dictionary, sk: float) -> void:
	var s: Vector3 = c["s"]
	var h := s * 0.5
	var f: float = minf(float(c.get("f", 0.0)), minf(h.x, minf(h.y, h.z)) * 0.9)
	var b := Basis.from_euler(Vector3(c.get("r", Vector3.ZERO)) * PI / 180.0)
	var o: Vector3 = c["c"]
	var P := func(x: float, y: float, z: float) -> Vector3: return o + b * Vector3(x, y, z)
	if f <= 0.0001:
		var faces := [
			[Vector3(1, 0, 0), [Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)]],
			[Vector3(-1, 0, 0), [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)]],
			[Vector3(0, 1, 0), [Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
			[Vector3(0, -1, 0), [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)]],
			[Vector3(0, 0, 1), [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
			[Vector3(0, 0, -1), [Vector3(1, -1, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1)]],
		]
		for fc in faces:
			var pts := []
			for v in fc[1]:
				pts.append(P.call(v.x * h.x, v.y * h.y, v.z * h.z))
			_poly(st, [pts[0], pts[3], pts[2], pts[1]], (b * fc[0]).normalized(), sk)
		return
	# fazowany: każda ściana główna pomniejszona o f, między nimi skośne pasy, w narożnikach trójkąty
	var X := h.x
	var Y := h.y
	var Z := h.z
	var dirs := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	for d in dirs:
		var pts := _sciana_glowna(d, X, Y, Z, f)
		var wp := []
		for p in pts:
			wp.append(P.call(p.x, p.y, p.z))
		_poly(st, wp, (b * d).normalized(), sk)
	# 12 krawędzi
	for i in range(3):
		for sa in [-1.0, 1.0]:
			for sb in [-1.0, 1.0]:
				var e := _krawedz(i, sa, sb, X, Y, Z, f)
				var wp := []
				for p in e[0]:
					wp.append(P.call(p.x, p.y, p.z))
				_poly(st, wp, (b * (e[1] as Vector3)).normalized(), sk)
	# 8 narożników
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var a := Vector3(sx * X, sy * (Y - f), sz * (Z - f))
				var bb := Vector3(sx * (X - f), sy * Y, sz * (Z - f))
				var cc := Vector3(sx * (X - f), sy * (Y - f), sz * Z)
				var n := Vector3(sx, sy, sz).normalized()
				var tri := [a, bb, cc]
				if (bb - a).cross(cc - a).dot(n) < 0.0:
					tri = [a, cc, bb]
				var wp := []
				for p in tri:
					wp.append(P.call(p.x, p.y, p.z))
				_poly(st, wp, (b * n).normalized(), sk)


static func _sciana_glowna(d: Vector3, X: float, Y: float, Z: float, f: float) -> Array:
	# cztery wierzchołki ściany prostopadłej do d, pomniejszonej o fazę, w kolejności CCW patrząc od zewnątrz
	var pts: Array
	if d.x != 0.0:
		var x := d.x * X
		pts = [Vector3(x, -(Y - f), -(Z - f)), Vector3(x, Y - f, -(Z - f)), Vector3(x, Y - f, Z - f), Vector3(x, -(Y - f), Z - f)]
	elif d.y != 0.0:
		var y := d.y * Y
		pts = [Vector3(-(X - f), y, -(Z - f)), Vector3(-(X - f), y, Z - f), Vector3(X - f, y, Z - f), Vector3(X - f, y, -(Z - f))]
	else:
		var z := d.z * Z
		pts = [Vector3(-(X - f), -(Y - f), z), Vector3(X - f, -(Y - f), z), Vector3(X - f, Y - f, z), Vector3(-(X - f), Y - f, z)]
	if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(d) < 0.0:
		pts.reverse()
	return pts


static func _krawedz(os: int, sa: float, sb: float, X: float, Y: float, Z: float, f: float) -> Array:
	# pas fazy wzdłuż osi os (0=x,1=y,2=z) w ćwiartce (sa, sb) pozostałych dwóch osi
	var pts: Array
	var n: Vector3
	match os:
		0:
			pts = [Vector3(-(X - f), sa * Y, sb * (Z - f)), Vector3(X - f, sa * Y, sb * (Z - f)), Vector3(X - f, sa * (Y - f), sb * Z), Vector3(-(X - f), sa * (Y - f), sb * Z)]
			n = Vector3(0, sa, sb).normalized()
		1:
			pts = [Vector3(sa * X, -(Y - f), sb * (Z - f)), Vector3(sa * X, Y - f, sb * (Z - f)), Vector3(sa * (X - f), Y - f, sb * Z), Vector3(sa * (X - f), -(Y - f), sb * Z)]
			n = Vector3(sa, 0, sb).normalized()
		_:
			pts = [Vector3(sa * X, sb * (Y - f), -(Z - f)), Vector3(sa * X, sb * (Y - f), Z - f), Vector3(sa * (X - f), sb * Y, Z - f), Vector3(sa * (X - f), sb * Y, -(Z - f))]
			n = Vector3(sa, sb, 0).normalized()
	if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(n) < 0.0:
		pts.reverse()
	return [pts, n]


## Walec / stożek ścięty o n bokach z denkami, cieniowanie gładkie na bokach.
static func _walec(st: SurfaceTool, c: Dictionary, sk: float) -> void:
	var a: Vector3 = c["a"]
	var b: Vector3 = c["b"]
	var os := b - a
	var dl := os.length()
	if dl < 0.0001:
		return
	var w := os / dl
	var u := w.cross(Vector3.UP if absf(w.y) < 0.95 else Vector3.RIGHT).normalized()
	var v := w.cross(u)
	var n: int = int(c.get("n", 8))
	var kat: float = float(c.get("kat", 0.0))
	var r0: float = c["r0"]
	var r1: float = c["r1"]
	var obw := TAU * maxf(r0, r1)
	var nachyl := (r0 - r1) / dl
	for i in n:
		var t0 := kat + TAU * float(i) / n
		var t1 := kat + TAU * float(i + 1) / n
		var d0 := u * cos(t0) + v * sin(t0)
		var d1 := u * cos(t1) + v * sin(t1)
		var p00 := a + d0 * r0
		var p01 := a + d1 * r0
		var p10 := b + d0 * r1
		var p11 := b + d1 * r1
		var n0 := (d0 + w * nachyl).normalized()
		var n1 := (d1 + w * nachyl).normalized()
		var u0 := obw * float(i) / n * sk
		var u1 := obw * float(i + 1) / n * sk
		var vb := dl * sk
		# dwa trójkąty boku (normalne per wierzchołek – gładko)
		for tr in [[p00, p11, p10, n0, n1, n0, Vector2(u0, 0), Vector2(u1, vb), Vector2(u0, vb)],
				[p00, p01, p11, n0, n1, n1, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, vb)]]:
			var kol := [0, 1, 2]
			var sr: Vector3 = ((tr[0] as Vector3) + (tr[1] as Vector3) + (tr[2] as Vector3)) / 3.0
			var naz: Vector3 = (sr - a) - w * (sr - a).dot(w)
			if ((tr[1] as Vector3) - tr[0]).cross((tr[2] as Vector3) - tr[0]).dot(naz) > 0.0:
				kol = [0, 2, 1]
			for k in kol:
				st.set_normal(tr[3 + k])
				st.set_uv(tr[6 + k])
				st.add_vertex(tr[k])
		# denka
		if r0 > 0.0005:
			_tri(st, [a, p00, p01], [Vector2(0.5, 0.5), Vector2(0.5, 0.5) + Vector2(cos(t0), sin(t0)) * r0 * sk, Vector2(0.5, 0.5) + Vector2(cos(t1), sin(t1)) * r0 * sk], -w)
		if r1 > 0.0005:
			_tri(st, [b, p11, p10], [Vector2(0.5, 0.5), Vector2(0.5, 0.5) + Vector2(cos(t1), sin(t1)) * r1 * sk, Vector2(0.5, 0.5) + Vector2(cos(t0), sin(t0)) * r1 * sk], w)



## Profil: wielokąt sylwetki z boku (punkty (z, y), w metrach) wyciągnięty na szerokość w wzdłuż osi X,
## z fazą f na krawędziach. Pozwala robić prawdziwe kształty broni: zamek, chwyt, kolbę, łoże, magazynek.
## Opcje: "x" środek w osi X, "o" przesunięcie, "r" obrót w stopniach.
static func profil(punkty: Array, w: float, m: String, faza := 0.0, x := 0.0, o := Vector3.ZERO, rot := Vector3.ZERO, k := Color.WHITE) -> Dictionary:
	return {"t": "profil", "p": punkty, "w": w, "m": m, "f": faza, "x": x, "o": o, "r": rot, "k": k}


static func _wsuniety(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	# odsunięcie wierzchołków do środka o d (miter), z ograniczeniem przy ostrych kątach
	var n := pts.size()
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var a := pts[(i - 1 + n) % n]
		var b := pts[i]
		var c := pts[(i + 1) % n]
		var e1 := (b - a).normalized()
		var e2 := (c - b).normalized()
		var n1 := Vector2(-e1.y, e1.x)
		var n2 := Vector2(-e2.y, e2.x)
		var bis := (n1 + n2)
		if bis.length() < 0.001:
			bis = n1
		bis = bis.normalized()
		var cosk := maxf(0.35, bis.dot(n1))
		out[i] = b + bis * (d / cosk)
	return out


static func _profil(st: SurfaceTool, c: Dictionary, sk: float) -> void:
	var pts := PackedVector2Array()
	for p in c["p"]:
		pts.append(p)
	if pts.size() < 3:
		return
	# wnętrze po lewej stronie krawędzi = wielokąt przeciwnie do wskazówek zegara
	if Geometry2D.is_polygon_clockwise(pts):
		pts.reverse()
	var w: float = c["w"]
	var f: float = minf(float(c.get("f", 0.0)), w * 0.45)
	var x0: float = c.get("x", 0.0)
	var b := Basis.from_euler(Vector3(c.get("r", Vector3.ZERO)) * PI / 180.0)
	var o: Vector3 = c.get("o", Vector3.ZERO)
	var P := func(p2: Vector2, x: float) -> Vector3: return o + b * Vector3(x0 + x, p2.y, p2.x)
	var N := func(v: Vector3) -> Vector3: return (b * v).normalized()
	var wew := _wsuniety(pts, f) if f > 0.0001 else pts
	var h := w * 0.5
	var hs := h - f
	# denka (boki broni) z wsuniętego wielokąta
	var tr := Geometry2D.triangulate_polygon(wew)
	for sx in [-1.0, 1.0]:
		var n3: Vector3 = N.call(Vector3(sx, 0, 0))
		for i in range(0, tr.size(), 3):
			var q := [wew[tr[i]], wew[tr[i + 1]], wew[tr[i + 2]]]
			var p3 := [P.call(q[0], sx * h), P.call(q[1], sx * h), P.call(q[2], sx * h)]
			var uv := [Vector2(q[0].x, -q[0].y) * sk, Vector2(q[1].x, -q[1].y) * sk, Vector2(q[2].x, -q[2].y) * sk]
			_tri(st, p3, uv, n3)
	# ściana boczna (obwód) i pasy fazy
	var n := pts.size()
	var obw := 0.0
	for i in n:
		var a := pts[i]
		var bb := pts[(i + 1) % n]
		var e := bb - a
		var dl := e.length()
		if dl < 0.00001:
			continue
		var nn := Vector2(e.y, -e.x).normalized()   # na zewnątrz (CCW)
		var n3: Vector3 = N.call(Vector3(0, nn.y, nn.x))
		var u0 := obw * sk
		var u1 := (obw + dl) * sk
		obw += dl
		var A0: Vector3 = P.call(a, -hs)
		var A1: Vector3 = P.call(a, hs)
		var B0: Vector3 = P.call(bb, -hs)
		var B1: Vector3 = P.call(bb, hs)
		_tri(st, [A0, B0, B1], [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, w * sk)], n3)
		_tri(st, [A0, B1, A1], [Vector2(u0, 0), Vector2(u1, w * sk), Vector2(u0, w * sk)], n3)
		if f > 0.0001:
			var wa := wew[i]
			var wb := wew[(i + 1) % n]
			for sx in [-1.0, 1.0]:
				var nf: Vector3 = N.call(Vector3(sx * 0.7, nn.y * 0.7, nn.x * 0.7))
				var C0: Vector3 = P.call(a, sx * hs)
				var C1: Vector3 = P.call(bb, sx * hs)
				var D0: Vector3 = P.call(wa, sx * h)
				var D1: Vector3 = P.call(wb, sx * h)
				_tri(st, [C0, C1, D1], [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, f * sk)], nf)
				_tri(st, [C0, D1, D0], [Vector2(u0, 0), Vector2(u1, f * sk), Vector2(u0, f * sk)], nf)
