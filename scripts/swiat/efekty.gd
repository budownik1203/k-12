class_name Efekty
extends RefCounted
## Krótkie efekty wizualne: ślady po kulach, pył, krew, błysk wylotowy.

static var _slady: Array = []
static var _mat_slad: StandardMaterial3D


static func _material_sladu() -> StandardMaterial3D:
	if _mat_slad == null:
		_mat_slad = StandardMaterial3D.new()
		_mat_slad.albedo_color = Color(0.03, 0.03, 0.03)
		_mat_slad.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _mat_slad


static var _mat_krew: StandardMaterial3D


static var material_sciany_fn: Callable      # (pozycja) -> "tynk" / "cegla" / "kafelki" / "beton" (ustawia rajd)
static var _otwory: Array = []
const PYL := {"tynk": Color(0.66, 0.63, 0.57), "cegla": Color(0.6, 0.3, 0.22), "kafelki": Color(0.76, 0.76, 0.72), "beton": Color(0.5, 0.48, 0.44)}


## Trafienie kulą w ścianę: dziura z odpryskiem i pył w kolorze materiału (tynk, cegła, kafelki, beton),
## dźwięk wg materiału. Dziury zostają do końca rajdu (najwyżej 200 najnowszych).
static func trafienie_sciany(rodzic: Node3D, pos: Vector3, normal: Vector3) -> void:
	if rodzic == null or not rodzic.is_inside_tree():
		return
	var mat := "beton"
	if material_sciany_fn.is_valid() and absf(normal.y) < 0.6:
		mat = String(material_sciany_fn.call(pos + normal * 0.3))
	elif normal.y >= 0.6:
		mat = "beton"
	var el: Dictionary = Naklejki.dane()["elementy"]
	var id := "otwor_%s_%d" % [mat, randi() % 2]
	if el.has(id):
		var e: Dictionary = el[id]
		var A := float(Naklejki.dane()["atlas"])
		var re: Array = e["rect"]
		var s := randf_range(0.1, 0.14)
		var qm := QuadMesh.new()
		qm.size = Vector2(s, s)
		var u0 := float(re[0]) / A
		var v0 := float(re[1]) / A
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts := [Vector3(-s * 0.5, -s * 0.5, 0), Vector3(s * 0.5, -s * 0.5, 0), Vector3(s * 0.5, s * 0.5, 0), Vector3(-s * 0.5, s * 0.5, 0)]
		var du := float(re[2]) / A
		var dv := float(re[3]) / A
		var uv := [Vector2(u0, v0 + dv), Vector2(u0 + du, v0 + dv), Vector2(u0 + du, v0), Vector2(u0, v0)]
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.BACK)
			st.set_uv(uv[i])
			st.add_vertex(pts[i])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = Naklejki.material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rodzic.add_child(mi)
		mi.global_position = pos + normal * 0.004
		var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
		mi.look_at(mi.global_position - normal, up)
		mi.rotate_object_local(Vector3.BACK, randf() * TAU)
		_otwory.append(mi)
		while _otwory.size() > 200:
			var old = _otwory.pop_front()
			if is_instance_valid(old):
				old.queue_free()
	var kol: Color = PYL.get(mat, PYL["beton"])
	czastki(rodzic, pos, normal, kol, 14 if mat != "kafelki" else 10, 3.2)
	if mat in ["beton", "kafelki"] and randf() < 0.4:
		czastki(rodzic, pos, normal, Color(1.0, 0.8, 0.4), 3, 5.0)
	var wys: float = float({"tynk": 0.9, "cegla": 0.8, "kafelki": 1.35, "beton": 1.0}.get(mat, 1.0)) * randf_range(0.93, 1.07)
	Dzwiek.graj_3d("trafienie_beton", pos, rodzic, -6.0, wys)


static func slad(rodzic: Node3D, pos: Vector3, normal: Vector3, krew := false) -> void:
	if rodzic == null or not rodzic.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	var s := randf_range(0.035, 0.055) if not krew else randf_range(0.25, 0.5)
	q.size = Vector2(s, s * (1.0 if not krew else randf_range(0.6, 1.4)))
	mi.mesh = q
	if krew:
		if _mat_krew == null:
			_mat_krew = StandardMaterial3D.new()
			_mat_krew.albedo_color = Color(0.22, 0.01, 0.01, 0.85)
			_mat_krew.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = _mat_krew
	else:
		mi.material_override = _material_sladu()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rodzic.add_child(mi)
	mi.global_position = pos + normal * 0.005
	var up := Vector3.UP if abs(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	mi.look_at(mi.global_position - normal, up)
	_slady.append(mi)
	while _slady.size() > 80:
		var old = _slady.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static var _mesh_czastek := {}


## Wspólna siatka drobinki na kolor (zamiast nowego materiału przy każdym trafieniu).
static func _mesh_czastki(kolor: Color, iskra: bool) -> BoxMesh:
	var k := kolor.to_html(false) + ("i" if iskra else "")
	if _mesh_czastek.has(k):
		return _mesh_czastek[k]
	var box := BoxMesh.new()
	var bok := 0.02 if iskra else 0.014
	box.size = Vector3(bok, bok, bok)
	var m := StandardMaterial3D.new()
	m.albedo_color = kolor if iskra else kolor.darkened(0.12)
	m.roughness = 1.0
	if iskra:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = m
	_mesh_czastek[k] = box
	return box


## Zwolnienie zasobów współdzielonych (wyjście z gry).
static func sprzataj() -> void:
	_mesh_czastek.clear()
	_slady.clear()
	_otwory.clear()
	material_sciany_fn = Callable()


static func czastki(rodzic: Node3D, pos: Vector3, normal: Vector3, kolor: Color, ile := 10, predkosc := 2.2) -> void:
	if rodzic == null or not rodzic.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = ile
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 35.0
	p.initial_velocity_min = predkosc * 0.5
	p.initial_velocity_max = predkosc
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	# iskry (ciepła żółć) świecą same; pył, drzazgi i krew biorą światło sceny – w ciemnym pokoju nie bieleją
	var iskra := kolor.r > 0.95 and kolor.g > 0.7 and kolor.b < 0.5
	if not iskra:
		p.scale_amount_min = 0.45
		p.scale_amount_max = 1.0
	p.mesh = _mesh_czastki(kolor, iskra)
	rodzic.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## Łuska wyrzucona z broni: leci w bok i w górę, spada pod wpływem grawitacji.
static func luska(rodzic: Node3D, pos: Vector3, w_prawo: Vector3, srut := false) -> void:
	if rodzic == null or not rodzic.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 1
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = (w_prawo + Vector3.UP * 0.8).normalized()
	p.spread = 12.0
	p.initial_velocity_min = 2.2
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -9.8, 0)
	p.angular_velocity_min = 400.0
	p.angular_velocity_max = 900.0
	var box := BoxMesh.new()
	box.size = Vector3(0.012, 0.012, 0.03) if not srut else Vector3(0.02, 0.02, 0.06)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.55, 0.2) if not srut else Color(0.6, 0.1, 0.08)
	m.metallic = 0.6
	m.emission_enabled = true
	m.emission = m.albedo_color * 0.25
	box.material = m
	p.mesh = box
	rodzic.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	# brzęk łuski o podłogę (strzałowa – głuchy plastik)
	var tree := rodzic.get_tree()
	var gdzie := pos + w_prawo * 0.6
	var space := rodzic.get_world_3d().direct_space_state
	var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(gdzie, gdzie + Vector3.DOWN * 3.0, Balistyka.WARSTWA_SWIAT))
	var spad := 1.3
	if not r.is_empty():
		gdzie = r["position"]
		spad = pos.y - gdzie.y
	tree.create_timer(clampf(0.22 + sqrt(maxf(0.0, spad) / 4.9), 0.25, 0.9)).timeout.connect(func():
		if is_instance_valid(rodzic) and rodzic.is_inside_tree():
			Dzwiek.graj_3d("luska_srut" if srut else Dzwiek.wariant("luska"), gdzie, rodzic, -12.0, randf_range(0.92, 1.08), 14.0))


static var _mat_plomien: StandardMaterial3D
static var _mat_smuga: StandardMaterial3D


## Płomień wylotowy widziany z zewnątrz (krótki, migający czworokąt zwrócony do kamery).
static func plomien(rodzic: Node3D, pos: Vector3) -> void:
	if rodzic == null or not rodzic.is_inside_tree():
		return
	if _mat_plomien == null:
		_mat_plomien = StandardMaterial3D.new()
		_mat_plomien.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_plomien.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_plomien.albedo_color = Color(1.0, 0.7, 0.3)
		_mat_plomien.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	var s := randf_range(0.22, 0.34)
	q.size = Vector2(s, s)
	mi.mesh = q
	mi.material_override = _mat_plomien
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rodzic.add_child(mi)
	mi.global_position = pos
	var t := mi.create_tween()
	t.tween_interval(0.05)
	t.tween_callback(mi.queue_free)


## Smuga pocisku: cienka świecąca kreska od wylotu do celu, gaśnie w ułamku sekundy.
static func smuga(rodzic: Node3D, od: Vector3, do_: Vector3) -> void:
	if rodzic == null or not rodzic.is_inside_tree() or od.distance_to(do_) < 1.0:
		return
	if _mat_smuga == null:
		_mat_smuga = StandardMaterial3D.new()
		_mat_smuga.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_smuga.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_smuga.albedo_color = Color(1.0, 0.75, 0.4)
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	var dl := od.distance_to(do_)
	b.size = Vector3(0.012, 0.012, minf(dl, 6.0))
	mi.mesh = b
	mi.material_override = _mat_smuga
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rodzic.add_child(mi)
	var kier := (do_ - od).normalized()
	var start := od + kier * minf(dl, 6.0) * 0.5
	mi.global_position = start
	mi.look_at(do_, Vector3.UP if absf(kier.y) < 0.95 else Vector3.RIGHT)
	var t := mi.create_tween()
	t.tween_property(mi, "global_position", do_ - kier * minf(dl, 6.0) * 0.5, minf(0.12, dl / 300.0 + 0.02))
	t.tween_callback(mi.queue_free)


static func blysk(rodzic: Node3D, pos: Vector3, sila := 2.5) -> void:
	if rodzic == null or not rodzic.is_inside_tree():
		return
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.light_energy = sila * randf_range(1.1, 1.4)
	l.omni_range = 7.0
	l.omni_attenuation = 1.4
	l.light_specular = 0.15
	rodzic.add_child(l)
	l.global_position = pos
	# pełny błysk przez klatkę (inaczej przy 60 kl./s ledwo widać), potem szybkie wygaszanie
	var t := l.create_tween()
	t.tween_interval(0.022)
	t.tween_property(l, "light_energy", 0.0, 0.075).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(l.queue_free)


# ------------------------------------------------------------------ płomień wylotowy

static var _tex_gwiazdy: Array = []      # [pełne..., puste środkiem...]
static var _tex_bok: ImageTexture
static var _tex_dym: ImageTexture
static var _mat_gw: Array = []
static var _mat_gw_puste: Array = []
static var _mat_bok: StandardMaterial3D
static var _mat_dym: StandardMaterial3D


## Gwiazda płomienia patrzona od przodu: jasny rdzeń i 4–6 nieregularnych płatków. "pusty" = bez środka
## (przy celowaniu linia wzroku przechodzi przez wylot, więc środek musi zostać przezroczysty).
static func _gwiazda(ziarno: int, pusty: bool) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = ziarno
	var n := rng.randi_range(4, 6)
	var faza := rng.randf() * TAU
	var dl := []
	for i in n:
		dl.append(rng.randf_range(0.55, 1.0))
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var p := Vector2(x + 0.5, y + 0.5) / 32.0 - Vector2.ONE
			var r := p.length()
			var a := atan2(p.y, p.x) + faza
			var sek := fposmod(a / TAU * n, 1.0)
			var idx := int(fposmod(a / TAU * n, float(n)))
			var platek := pow(maxf(0.0, 1.0 - absf(sek - 0.5) * 2.0), 2.2) * float(dl[idx])
			var zasieg := 0.16 + 0.8 * platek
			var v := clampf(1.0 - r / maxf(0.01, zasieg), 0.0, 1.0)
			v = pow(v, 0.9)
			var rdzen := clampf(1.0 - r / 0.22, 0.0, 1.0)
			var jas := maxf(v, rdzen)
			if pusty:
				jas *= smoothstep(0.2, 0.42, r)
			var kol := Color(1.0, 0.95, 0.8).lerp(Color(1.0, 0.5, 0.12), clampf(r * 1.3, 0.0, 1.0))
			img.set_pixel(x, y, Color(kol.r * jas, kol.g * jas, kol.b * jas, jas))
	return ImageTexture.create_from_image(img)


## Płomień z boku: język ognia od wylotu (dół tekstury) do czubka (góra), z wcięciami.
static func _bok() -> ImageTexture:
	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var v := 1.0 - (y + 0.5) / 64.0          # 0 = wylot, 1 = czubek
		var szer := 0.5 * pow(1.0 - v, 0.55) * (0.75 + 0.25 * sin(v * 19.0))
		if v < 0.12:
			szer *= 0.55 + v * 3.7
		for x in 32:
			var u := absf((x + 0.5) / 32.0 - 0.5)
			var jas := clampf(1.0 - u / maxf(0.01, szer), 0.0, 1.0)
			jas = pow(jas, 1.2) * (1.0 - v * 0.55)
			var kol := Color(1.0, 0.93, 0.75).lerp(Color(1.0, 0.45, 0.1), clampf(v * 1.4 + u, 0.0, 1.0))
			img.set_pixel(x, y, Color(kol.r * jas, kol.g * jas, kol.b * jas, jas))
	return ImageTexture.create_from_image(img)


static func _dym() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var r := (Vector2(x + 0.5, y + 0.5) / 16.0 - Vector2.ONE).length()
			var a := clampf(1.0 - r, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.62, 0.6, 0.56, a * a))
	return ImageTexture.create_from_image(img)


static func _mat_add(t: Texture2D, billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = t
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return m


static func _przygotuj_plomien() -> void:
	if _mat_bok != null:
		return
	for i in 3:
		_mat_gw.append(_mat_add(_gwiazda(17 + i * 31, false), true))
		_mat_gw_puste.append(_mat_add(_gwiazda(17 + i * 31, true), true))
	_mat_bok = _mat_add(_bok(), false)
	_mat_dym = StandardMaterial3D.new()
	_mat_dym.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_dym.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_dym.albedo_texture = _dym()
	_mat_dym.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat_dym.vertex_color_use_as_albedo = false


## Płomień wylotowy: gwiazda od przodu + dwa skrzyżowane języki ognia wzdłuż lufy (-Z w xf), trwa ~2 klatki.
## xf w przestrzeni rodzica. celowanie > 0.5: gwiazda bez środka i mniejsza (nie zasłania celu).
static func plomien_wylotu(rodzic: Node3D, xf: Transform3D, skala := 1.0, celowanie := 0.0) -> void:
	if rodzic == null or not rodzic.is_inside_tree():
		return
	_przygotuj_plomien()
	var n := Node3D.new()
	rodzic.add_child(n)
	n.transform = xf
	var i := randi() % 3
	var gw := MeshInstance3D.new()
	var q := QuadMesh.new()
	var s := 0.2 * skala * randf_range(0.85, 1.2) * (0.72 if celowanie > 0.5 else 1.0)
	q.size = Vector2(s, s)
	gw.mesh = q
	gw.material_override = _mat_gw_puste[i] if celowanie > 0.5 else _mat_gw[i]
	gw.position = Vector3(0, 0, -0.01 * skala)
	n.add_child(gw)
	var dl := 0.32 * skala * randf_range(0.8, 1.25)
	for k in 2:
		var b := MeshInstance3D.new()
		var qb := QuadMesh.new()
		qb.size = Vector2(dl * 0.36, dl)
		b.mesh = qb
		b.material_override = _mat_bok
		b.rotation = Vector3(-PI * 0.5, 0, 0)
		var piv := Node3D.new()
		piv.rotation.z = (PI * 0.5) * k + randf_range(-0.3, 0.3)
		n.add_child(piv)
		piv.add_child(b)
		b.position = Vector3(0, 0, -dl * 0.5)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var t := n.create_tween()
	t.tween_interval(0.017)
	t.tween_property(n, "scale", Vector3(0.5, 0.5, 1.35), 0.04)
	t.tween_callback(n.queue_free)


## Smużka dymu z lufy po strzale (świat): rośnie, wznosi się i rozwiewa.
static func dym_wylotu(rodzic: Node3D, pos: Vector3, kier: Vector3, sila := 1.0) -> void:
	if rodzic == null or not rodzic.is_inside_tree():
		return
	_przygotuj_plomien()
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	mi.mesh = q
	var m: StandardMaterial3D = _mat_dym.duplicate()
	m.albedo_color = Color(1, 1, 1, 0.22 * sila)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rodzic.add_child(mi)
	mi.global_position = pos + kier * 0.08
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * 3.5, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(mi, "global_position", mi.global_position + kier * 0.35 + Vector3(0, 0.25, 0), 0.9)
	t.tween_property(m, "albedo_color:a", 0.0, 0.9)
	t.chain().tween_callback(mi.queue_free)


## Kurz: kilka miękkich kłębów przy podłodze (upadek przedmiotu, otwarcie starej szafy, wyłamanie kłódki).
static func kurz(rodzic: Node3D, pos: Vector3, sila := 1.0, kolor := Color(0.55, 0.5, 0.42)) -> void:
	if rodzic == null or not rodzic.is_inside_tree():
		return
	_przygotuj_plomien()
	var n := int(clampf(2.0 + sila * 3.0, 2.0, 7.0))
	for i in n:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.16, 0.16) * (0.7 + sila * 0.3)
		mi.mesh = q
		var m: StandardMaterial3D = _mat_dym.duplicate()
		m.albedo_color = Color(kolor.r, kolor.g, kolor.b, 0.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rodzic.add_child(mi)
		var kat := randf() * TAU
		var r := randf_range(0.02, 0.1) * sila
		mi.global_position = pos + Vector3(cos(kat) * r, 0.03 + randf() * 0.04, sin(kat) * r)
		var cel := mi.global_position + Vector3(cos(kat), 0.0, sin(kat)) * randf_range(0.08, 0.25) * sila + Vector3(0, randf_range(0.05, 0.18), 0)
		var dl := randf_range(0.9, 1.6)
		var t := mi.create_tween().set_parallel(true)
		t.tween_property(m, "albedo_color:a", 0.5 * minf(1.0, 0.4 + sila * 0.6), 0.1)
		t.tween_property(mi, "scale", Vector3.ONE * randf_range(2.5, 4.0), dl).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t.tween_property(mi, "global_position", cel, dl).set_ease(Tween.EASE_OUT)
		t.tween_property(m, "albedo_color:a", 0.0, dl * 0.8).set_delay(dl * 0.2)
		t.chain().tween_callback(mi.queue_free)


## Iskry (metal o metal: wyłamana kłódka, łom, rykoszet): świecące odpryski z grawitacją.
static func iskry(rodzic: Node3D, pos: Vector3, kier: Vector3, ile := 14) -> void:
	if rodzic == null or not rodzic.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = ile
	p.lifetime = 0.5
	p.explosiveness = 0.95
	p.direction = kier
	p.spread = 55.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var box := BoxMesh.new()
	box.size = Vector3(0.012, 0.012, 0.045)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.75, 0.35)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.2)
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = m
	p.mesh = box
	p.particle_flag_align_y = true
	rodzic.add_child(p)
	p.global_position = pos
	p.emitting = true
	var sw := OmniLight3D.new()
	sw.light_color = Color(1.0, 0.7, 0.35)
	sw.light_energy = 1.2
	sw.omni_range = 1.2
	rodzic.add_child(sw)
	sw.global_position = pos
	sw.create_tween().tween_property(sw, "light_energy", 0.0, 0.18)
	p.finished.connect(func():
		p.queue_free()
		if is_instance_valid(sw):
			sw.queue_free())


## Zawiesina kurzu w powietrzu po serii w ciasnym pomieszczeniu: kilka dużych, bladych kłębów
## na wysokości oczu, które powoli opadają i rzedną (chwilę gorzej widać).
static func zawiesina(rodzic: Node3D, pos: Vector3, sila := 1.0) -> void:
	if rodzic == null or not rodzic.is_inside_tree():
		return
	_przygotuj_plomien()
	for i in 7:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE * randf_range(1.4, 2.4)
		mi.mesh = q
		var m: StandardMaterial3D = _mat_dym.duplicate()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.albedo_color = Color(0.5, 0.47, 0.42, 0.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rodzic.add_child(mi)
		mi.global_position = pos + Vector3(randf_range(-1.6, 1.6), randf_range(-0.5, 0.6), randf_range(-1.6, 1.6))
		var dl := randf_range(6.0, 9.0)
		var t := mi.create_tween().set_parallel(true)
		t.tween_property(m, "albedo_color:a", 0.16 * sila, 1.2)
		t.tween_property(mi, "global_position", mi.global_position + Vector3(randf_range(-0.3, 0.3), -0.5, randf_range(-0.3, 0.3)), dl)
		t.tween_property(m, "albedo_color:a", 0.0, dl * 0.6).set_delay(dl * 0.4)
		t.chain().tween_callback(mi.queue_free)
