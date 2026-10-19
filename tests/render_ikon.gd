extends Node
## Rendery do ikon-szkiców: każdy przedmiot (i warianty stosu) z modelu 3D, rzut z góry pod kątem,
## dwa przebiegi – normalne (krawędzie, kreskowanie) i głębia (krawędzie nachodzących części).
## Uruchomienie (z xvfb): godot --path . res://tests/render_ikon.tscn --rendering-driver opengl3 -- <katalog> [id ...]
## Potem: python3 narzedzia/ikony_szkic.py <katalog>

const PX := 68          # pikseli na kratkę siatki w renderze (4x końcowej)

var _vp: SubViewport
var _kam: Camera3D
var _mat: ShaderMaterial


func _ready() -> void:
	var ar := OS.get_cmdline_user_args()
	var kat := ar[0] if ar.size() > 0 else "user://ikony"
	DirAccess.make_dir_recursive_absolute(kat)
	var tylko := ar.slice(1)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_vp)
	var sw := Node3D.new()
	_vp.add_child(sw)
	# światło i otoczenie dla przebiegu w kolorze (materiały: nadruki, naklejki, drewno / metal)
	var sl := DirectionalLight3D.new()
	sl.rotation = Vector3(-1.0, -0.6, 0.0)
	sl.light_energy = 1.2
	sw.add_child(sl)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.ambient_light_energy = 0.9
	we.environment = env
	sw.add_child(we)
	_kam = Camera3D.new()
	_kam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_kam.keep_aspect = Camera3D.KEEP_HEIGHT
	_kam.near = 0.01
	_kam.far = 50.0
	sw.add_child(_kam)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform int tryb = 0;
uniform float d0 = 0.0;
uniform float d1 = 1.0;
void fragment() {
	if (tryb == 0) {
		vec3 nn = FRONT_FACING ? NORMAL : -NORMAL;
		ALBEDO = nn * 0.5 + 0.5;
	} else {
		float d = clamp((-VERTEX.z - d0) / max(0.0001, d1 - d0), 0.0, 1.0);
		ALBEDO = vec3(d, fract(d * 255.0), 0.0);
	}
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	var meta := {}
	for id in Dane.przedmioty:
		var defn: Dictionary = Dane.przedmioty[id]
		if not tylko.is_empty() and not tylko.has(id):
			continue
		var war := [[id, int(defn.get("w", 1)), int(defn.get("h", 1)), int(defn.get("stos", 1))]]
		for r in defn.get("rozmiary_stosu", []):
			war.append([id + String(r[3]), int(r[1]), int(r[2]), int(r[0])])
		for w in war:
			var p := Przedmiot.nowy(id, int(w[3]))
			if defn.get("typ", "") == "bron" and defn["bron"].has("magazynki"):
				p.dane["mag"] = Przedmiot.nowy(String(defn["bron"]["magazynki"][0]))
			await _renderuj(sw, p, String(w[0]), int(w[1]), int(w[2]), kat)
			meta[w[0]] = {"w": w[1], "h": w[2], "typ": defn.get("typ", ""), "nazwa": defn.get("nazwa", id)}
	var f := FileAccess.open(kat.path_join("meta.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	f.close()
	print("RENDER IKON: %d" % meta.size())
	get_tree().quit()


func _nadpisz(n: Node, mat: Material = null) -> void:
	if n is Decal or n is Sprite3D or n is Label3D or (n is Light3D and n.get_parent() != null and not n.get_parent() is SubViewport) or n is GPUParticles3D or n is CPUParticles3D:
		if not n is DirectionalLight3D:
			(n as Node3D).visible = false
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_nadpisz(c, mat)


func _renderuj(sw: Node3D, p: Przedmiot, nazwa: String, w: int, h: int, kat: String) -> void:
	var n := ModelePrzedmiotow.wezel(p, false)
	var ab: AABB = n.get_meta("aabb", AABB(Vector3(-0.05, 0, -0.05), Vector3(0.1, 0.1, 0.1)))
	var obr := Node3D.new()
	sw.add_child(obr)
	obr.add_child(n)
	# najdłuższa oś w poziomie ikony (broń: wylotem w prawo); ikona pionowa – najdłuższa oś w pionie
	var dl_x := ab.size.x
	var dl_z := ab.size.z
	var pozioma := w >= h
	if (dl_z > dl_x) == pozioma:
		obr.rotation.y = -PI * 0.5
	n.position = -ab.get_center()
	_nadpisz(n, _mat)
	# kamera: z góry, pochylona ku widzowi (widać wierzch i przód) – jak rysunek aksonometryczny w instrukcji
	var kier := Vector3(0.0, 1.0, 0.62).normalized()
	_kam.global_position = kier * 8.0
	_kam.look_at(Vector3.ZERO, Vector3(0, 0, -1))
	await get_tree().process_frame
	# zasięg rzutu
	var inv := _kam.global_transform.affine_inverse()
	var mn := Vector3(INF, INF, INF)
	var mx := -mn
	var gab := AABB(-ab.size * 0.5, ab.size)
	for i in 8:
		var c := obr.global_transform * gab.get_endpoint(i)
		var v := inv * c
		mn = mn.min(v)
		mx = mx.max(v)
	var W := maxi(8, w * PX)
	var H := maxi(8, h * PX)
	_vp.size = Vector2i(W, H)
	var ex := (mx.x - mn.x)
	var ey := (mx.y - mn.y)
	# małe przedmioty ciaśniej (żeby rysunek nie był kropką), duże z marginesem na adnotacje
	_kam.size = maxf(ey, ex * float(H) / float(W)) * (1.06 if w * h <= 2 else 1.18)
	_kam.global_position += _kam.global_basis.x * (mn.x + mx.x) * 0.5 + _kam.global_basis.y * (mn.y + mx.y) * 0.5
	_mat.set_shader_parameter("d0", -mx.z)
	_mat.set_shader_parameter("d1", -mn.z)
	for tryb in 3:
		if tryb < 2:
			_mat.set_shader_parameter("tryb", tryb)
		else:
			_nadpisz(n, null)          # własne materiały: barwy i nadruki
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.save_png(kat.path_join("%s_%s.png" % [nazwa, ["n", "d", "c"][tryb]]))
	obr.queue_free()
	await get_tree().process_frame
