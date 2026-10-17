class_name Kit
extends RefCounted
## Proceduralne siatki low poly: bryły z kolorem wierzchołków (broń, postacie) oraz
## teksturowane czworokąty (ściany, podłogi). Wszystko korzysta z shadera PS1.

const PSX := preload("res://shaders/psx.gdshader")

static var _mat_vc: ShaderMaterial
static var _tex_mats := {}


static func material_kolor() -> ShaderMaterial:
	if _mat_vc == null:
		_mat_vc = ShaderMaterial.new()
		_mat_vc.shader = PSX
		_mat_vc.set_shader_parameter("albedo_tex", load("res://assets/textures/szum.png"))
		_mat_vc.set_shader_parameter("use_vertex_color", true)
	return _mat_vc


static var _mat_vm: ShaderMaterial


## Materiał broni w rękach: lekko podświetlony, żeby broń była czytelna w ciemności.
static func material_kolor_vm() -> ShaderMaterial:
	if _mat_vm == null:
		_mat_vm = material_kolor().duplicate()
		_mat_vm.set_shader_parameter("use_emission", true)
		_mat_vm.set_shader_parameter("emission_energy", 0.34)
	return _mat_vm


static func material_tex(nazwa: String, emisja := 0.0) -> ShaderMaterial:
	var key := "%s|%s" % [nazwa, emisja]
	if not _tex_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = PSX
		m.set_shader_parameter("albedo_tex", load("res://assets/textures/%s.png" % nazwa))
		if emisja > 0.0:
			m.set_shader_parameter("use_emission", true)
			m.set_shader_parameter("emission_energy", emisja)
		_tex_mats[key] = m
	return _tex_mats[key]


## Dodaje prostopadłościan do SurfaceTool. rot w stopniach (Euler XYZ).
static func box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, rot := Vector3.ZERO) -> void:
	var b := Basis.from_euler(rot * PI / 180.0)
	var h := s * 0.5
	var faces := [
		[Vector3(1, 0, 0), [Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)]],
		[Vector3(-1, 0, 0), [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)]],
		[Vector3(0, 1, 0), [Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
		[Vector3(0, -1, 0), [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)]],
		[Vector3(0, 0, 1), [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
		[Vector3(0, 0, -1), [Vector3(1, -1, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1)]],
	]
	for f in faces:
		var n: Vector3 = b * f[0]
		var shade: float = 0.82 + 0.18 * clampf(n.y * 0.6 + n.x * 0.2 + 0.4, 0.0, 1.0)
		var cc := Color(col.r * shade, col.g * shade, col.b * shade)
		var pts := []
		for v in f[1]:
			pts.append(c + b * (Vector3(v.x * h.x, v.y * h.y, v.z * h.z)))
		_quad(st, pts, n, cc)


static func _quad(st: SurfaceTool, pts: Array, n: Vector3, col: Color) -> void:
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_color(col)
		st.set_normal(n)
		var p: Vector3 = pts[i]
		st.set_uv(Vector2(p.x + p.z, p.y) * 3.0 + uvs[i] * 0.1)
		st.add_vertex(p)


## boxes: [[środek, rozmiar, kolor, (rot)], ...]
static func mesh(boxes: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bx in boxes:
		box(st, bx[0], bx[1], bx[2], bx[3] if bx.size() > 3 else Vector3.ZERO)
	var m := st.commit()
	m.surface_set_material(0, material_kolor())
	return m


static func instancja(boxes: Array) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(boxes)
	return mi


# ------------------------------------------------------------ teksturowane powierzchnie

## Zbiera czworokąty pogrupowane po materiale i buduje z nich jedną siatkę wielomateriałową.
class Budowniczy:
	var grupy := {}   # nazwa materiału -> SurfaceTool

	func _st(mat: String) -> SurfaceTool:
		if not grupy.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			grupy[mat] = st
		return grupy[mat]

	## Czworokąt p0..p3 przeciwnie do wskazówek zegara patrząc od przodu.
	func quad(mat: String, p: Array, uv: Array, col := Color.WHITE) -> void:
		var st := _st(mat)
		var n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_color(col)
			st.set_normal(n)
			st.set_uv(uv[i])
			st.add_vertex(p[i])

	## Pozioma lub pionowa płaszczyzna podzielona na kafle (dla oświetlenia per wierzchołek).
	func sciana(mat: String, a: Vector3, b: Vector3, y0: float, y1: float, krok := 0.75, uv_fn := Callable()) -> void:
		var dlug := a.distance_to(b)
		var nx := maxi(1, int(ceil(dlug / krok)))
		var ny := maxi(1, int(ceil((y1 - y0) / krok)))
		for i in nx:
			for j in ny:
				var t0 := float(i) / nx
				var t1 := float(i + 1) / nx
				var ya := y0 + (y1 - y0) * float(j) / ny
				var yb := y0 + (y1 - y0) * float(j + 1) / ny
				var pa := a.lerp(b, t0)
				var pb := a.lerp(b, t1)
				var pts := [Vector3(pa.x, ya, pa.z), Vector3(pb.x, ya, pb.z), Vector3(pb.x, yb, pb.z), Vector3(pa.x, yb, pa.z)]
				var u0 := t0 * dlug
				var u1 := t1 * dlug
				var uvs: Array
				if uv_fn.is_valid():
					uvs = [uv_fn.call(u0, ya), uv_fn.call(u1, ya), uv_fn.call(u1, yb), uv_fn.call(u0, yb)]
				else:
					uvs = [Vector2(u0, -ya), Vector2(u1, -ya), Vector2(u1, -yb), Vector2(u0, -yb)]
				quad(mat, pts, uvs)

	## Prostokąt poziomy (podłoga gdy w_gore=true, sufit gdy false), kafelkowany.
	func plaszczyzna(mat: String, x0: float, z0: float, x1: float, z1: float, y: float, w_gore: bool, krok := 1.0, skala := 1.0) -> void:
		var nx := maxi(1, int(ceil((x1 - x0) / krok)))
		var nz := maxi(1, int(ceil((z1 - z0) / krok)))
		for i in nx:
			for j in nz:
				var xa := x0 + (x1 - x0) * float(i) / nx
				var xb := x0 + (x1 - x0) * float(i + 1) / nx
				var za := z0 + (z1 - z0) * float(j) / nz
				var zb := z0 + (z1 - z0) * float(j + 1) / nz
				var pts: Array
				if w_gore:
					pts = [Vector3(xa, y, zb), Vector3(xb, y, zb), Vector3(xb, y, za), Vector3(xa, y, za)]
				else:
					pts = [Vector3(xa, y, za), Vector3(xb, y, za), Vector3(xb, y, zb), Vector3(xa, y, zb)]
				var uvs := []
				for p in pts:
					uvs.append(Vector2(p.x, p.z) * skala)
				quad(mat, pts, uvs)

	func zbuduj(emisje := {}) -> ArrayMesh:
		var m := ArrayMesh.new()
		for mat in grupy:
			var st: SurfaceTool = grupy[mat]
			st.commit(m)
			m.surface_set_material(m.get_surface_count() - 1, Kit.material_tex(mat, emisje.get(mat, 0.0)))
		return m
