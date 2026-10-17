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
	var box := BoxMesh.new()
	box.size = Vector3(0.02, 0.02, 0.02)
	var m := StandardMaterial3D.new()
	m.albedo_color = kolor
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = m
	p.mesh = box
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
	l.light_energy = sila
	l.omni_range = 5.0
	rodzic.add_child(l)
	l.global_position = pos
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, 0.06)
	t.tween_callback(l.queue_free)
