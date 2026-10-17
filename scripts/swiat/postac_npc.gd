class_name PostacNPC
extends StaticBody3D
## Postać w bazie (handlarz). Prosta bryłowa sylwetka z oddychaniem i obracaniem głowy do gracza.

var nazwa := "Handlarz"
var id_handlarza := ""
var kolory := {"ubranie": Color(0.3, 0.3, 0.28), "spodnie": Color(0.2, 0.2, 0.2), "dodatek": Color(0.5, 0.5, 0.45)}
var wariant := "zbrojmistrz"
var _glowa: Node3D
var _tulow: Node3D
var _t := 0.0


func _ready() -> void:
	collision_layer = Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_INTERAKCJE
	set_meta("interakcja", self)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	var skora := Color(0.62, 0.48, 0.4)
	var u: Color = kolory["ubranie"]
	var s: Color = kolory["spodnie"]
	var d: Color = kolory["dodatek"]
	var nogi := Kit.instancja([
		[Vector3(-0.11, 0.47, 0), Vector3(0.16, 0.94, 0.17), s], [Vector3(0.11, 0.47, 0), Vector3(0.16, 0.94, 0.17), s],
		[Vector3(-0.11, 0.04, -0.05), Vector3(0.15, 0.08, 0.26), Color(0.1, 0.09, 0.08)], [Vector3(0.11, 0.04, -0.05), Vector3(0.15, 0.08, 0.26), Color(0.1, 0.09, 0.08)],
	])
	add_child(nogi)
	_tulow = Node3D.new()
	_tulow.position.y = 0.95
	add_child(_tulow)
	var bryly := [
		[Vector3(0, 0.3, 0), Vector3(0.46, 0.6, 0.27), u],
		[Vector3(-0.28, 0.27, 0), Vector3(0.13, 0.56, 0.13), u, Vector3(0, 0, -8)],
		[Vector3(0.28, 0.27, 0), Vector3(0.13, 0.56, 0.13), u, Vector3(0, 0, 8)],
		[Vector3(-0.3, -0.04, 0), Vector3(0.1, 0.1, 0.1), skora], [Vector3(0.3, -0.04, 0), Vector3(0.1, 0.1, 0.1), skora],
	]
	match wariant:
		"zbrojmistrz":
			bryly.append([Vector3(0, 0.3, -0.14), Vector3(0.48, 0.5, 0.04), d])  # kamizelka
		"medyk":
			bryly.append([Vector3(0, 0.18, -0.14), Vector3(0.5, 0.8, 0.04), Color(0.78, 0.78, 0.72)])  # fartuch
		"posrednik":
			bryly.append([Vector3(0, 0.36, -0.14), Vector3(0.48, 0.44, 0.05), d])  # marynarka
	_tulow.add_child(Kit.instancja(bryly))
	_glowa = Node3D.new()
	_glowa.position.y = 0.62
	_tulow.add_child(_glowa)
	var gl := [[Vector3(0, 0.13, 0), Vector3(0.22, 0.26, 0.24), skora], [Vector3(0, 0.25, 0.02), Vector3(0.24, 0.06, 0.26), Color(0.2, 0.17, 0.14)]]
	match wariant:
		"zbrojmistrz":
			gl.append([Vector3(0, 0.29, 0), Vector3(0.3, 0.07, 0.3), Color(0.22, 0.26, 0.18)])  # furażerka
			gl.append([Vector3(0, 0.05, -0.12), Vector3(0.16, 0.06, 0.02), Color(0.3, 0.26, 0.22)])  # wąsy
		"medyk":
			gl.append([Vector3(0, 0.15, -0.125), Vector3(0.2, 0.04, 0.02), Color(0.7, 0.75, 0.8)])  # okulary
		"posrednik":
			gl.append([Vector3(0, 0.31, 0), Vector3(0.34, 0.03, 0.34), Color(0.12, 0.12, 0.12)])
			gl.append([Vector3(0, 0.36, 0), Vector3(0.22, 0.09, 0.22), Color(0.12, 0.12, 0.12)])  # kapelusz
	_glowa.add_child(Kit.instancja(gl))
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	_tulow.scale.y = 1.0 + sin(_t * 1.6) * 0.012
	var g := get_tree().get_first_node_in_group("gracz") as Node3D
	if g:
		var lok := to_local(g.global_position)
		var kat := clampf(atan2(-lok.x, -lok.z), -0.9, 0.9)
		_glowa.rotation.y = lerp_angle(_glowa.rotation.y, kat, delta * 3.0)


func tekst_interakcji(_g) -> String:
	return "Rozmawiaj: " + nazwa


func interakcja(_g) -> void:
	get_tree().call_group("ui_bazy", "otworz_handel", id_handlarza)
