extends Node
## Autoload: podmienia materiały z importowanych modeli .glb na shader PS1.
## Tekstura bazowa jest brana z materiału zaimportowanego z glTF.
## Materiały o nazwie kończącej się na "_emit" dostają emisję i są unikalne per obiekt
## (żeby dało się nimi sterować, np. migotaniem lampy).

const PSX_SHADER := preload("res://shaders/psx.gdshader")

var _cache := {}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_apply_recursive(get_tree().root)


func _apply_recursive(n: Node) -> void:
	_on_node_added(n)
	for c in n.get_children():
		_apply_recursive(c)


func _on_node_added(n: Node) -> void:
	var mi := n as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i)
		if src is StandardMaterial3D:
			mi.set_surface_override_material(i, _psx_for(src))


func _psx_for(src: StandardMaterial3D) -> ShaderMaterial:
	var emit := src.resource_name.ends_with("_emit")
	if not emit and _cache.has(src):
		return _cache[src]
	var sm := ShaderMaterial.new()
	sm.shader = PSX_SHADER
	sm.resource_name = src.resource_name + "_psx"
	sm.set_shader_parameter("albedo_tex", src.albedo_texture)
	if emit:
		sm.set_shader_parameter("use_emission", true)
		sm.set_shader_parameter("emission_energy", 1.4)
	else:
		_cache[src] = sm
	return sm
