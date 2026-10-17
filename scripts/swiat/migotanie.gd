extends OmniLight3D
## Migocząca świetlówka/żarówka. Steruje też emisją klosza lampy (plafon), jeśli podano węzeł.

@export var plafon: NodePath
@export var base_energy := 1.0
@export var awaria := 0.35  # 0 = stabilna, 0.9 = ciągle gaśnie, 1 = zepsuta (nie świeci)

var _t := 0.0
var _next := 0.0
var _on := true
var _mats: Array[ShaderMaterial] = []


func _ready() -> void:
	base_energy = light_energy
	_collect.call_deferred()


func _collect() -> void:
	var p := get_node_or_null(plafon)
	if p == null:
		return
	for mi in p.find_children("*", "MeshInstance3D", true, false):
		for i in mi.get_surface_override_material_count():
			var m: Material = (mi as MeshInstance3D).get_surface_override_material(i)
			if m is ShaderMaterial and m.get_shader_parameter("use_emission"):
				_mats.append(m)


func _process(delta: float) -> void:
	_t += delta
	if awaria >= 1.0:
		_on = false
	elif _t >= _next:
		_t = 0.0
		if _on:
			_on = randf() > awaria
			_next = randf_range(0.05, 1.6) if _on else randf_range(0.03, 0.25) + awaria * awaria * randf_range(1.0, 4.0)
		else:
			_on = true
			_next = randf_range(0.05, 0.9)
	var e := base_energy * (randf_range(0.85, 1.0) if _on else 0.04)
	light_energy = e
	for m in _mats:
		m.set_shader_parameter("emission_energy", 1.4 * e / max(base_energy, 0.001))
