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


static func slad(rodzic: Node3D, pos: Vector3, normal: Vector3) -> void:
	if rodzic == null or not rodzic.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	var s := randf_range(0.035, 0.055)
	q.size = Vector2(s, s)
	mi.mesh = q
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
