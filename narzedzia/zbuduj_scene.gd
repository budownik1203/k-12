extends SceneTree
## Składa scenę próbki z wygenerowanych modeli i zapisuje ją jako scenes/probka.tscn.
## Uruchomienie (w katalogu projektu):  godot --headless --script res://narzedzia/zbuduj_scene.gd

const H := 2.8
const PIETRA := 2
const M := "res://assets/models/"

var scena: Node3D


func _init() -> void:
	scena = Node3D.new()
	scena.name = "Probka"
	scena.set_script(load("res://scripts/probka.gd"))

	_srodowisko()
	_dodaj("klatka_schodowa", Vector3.ZERO, 0, "KlatkaSchodowa")

	# drzwi: [model, pozycja, obrót]
	var drzwi := [
		["drzwi_piwnica", Vector3(0, 0, 1.3), 90],
		["drzwi_skaj_12", Vector3(0.75, 0, 2.6), 180],
		["drzwi_skaj_13", Vector3(0, H, 1.3), 90],
		["drzwi_skaj_12", Vector3(0.75, H, 0), 0],
		["drzwi_skaj_14", Vector3(0.75, H, 2.6), 180],
		["drzwi_skaj_14", Vector3(0, 2 * H, 1.3), 90],
		["drzwi_skaj_13", Vector3(0.75, 2 * H, 0), 0],
		["drzwi_skaj_12", Vector3(0.75, 2 * H, 2.6), 180],
	]
	for d in drzwi:
		_dodaj(d[0], d[1], d[2])

	_dodaj("skrzynki_pocztowe", Vector3(0.8, 1.15, 0), 0)
	_dodaj("beczka", Vector3(0.36, 0, 0.36), 0)
	_dodaj("hydrant", Vector3(4.75, H / 2 + 0.9, 0), 0)
	_dodaj("tablica_ogloszen", Vector3(4.8, H / 2 + 1.25, 2.6), 180)
	for k in PIETRA:
		_dodaj("kaloryfer", Vector3(5.4, k * H + H / 2 + 0.1, 1.3), -90)
	_dodaj("szafka", Vector3(5.05, H + H / 2, 0), 0)
	_dodaj("skrzynia", Vector3(5.0, H + H / 2, 2.6), 180)

	# lampy: pozycja mocowania, energia, awaria (0 = sprawna, -1 = bez skryptu migotania)
	var lampy := [
		[Vector3(0.8, H - 0.2, 1.3), 0.75, 0.08],
		[Vector3(4.75, H + 1.2, 1.3), 0.6, 0.45],
		[Vector3(0.8, 2 * H - 0.2, 1.3), 0.65, 0.7],
		[Vector3(4.75, 3 * H, 1.3), 0.6, 1.0],
		[Vector3(0.8, 3 * H, 1.3), 0.6, 1.0],
	]
	var i := 0
	for l in lampy:
		var p := _dodaj("plafon", l[0], 0, "Plafon%d" % i)
		var light := OmniLight3D.new()
		light.name = "Swiatlo%d" % i
		light.position = l[0] + Vector3(0, -0.3, 0)
		light.light_color = Color(1.0, 0.8, 0.58)
		light.light_energy = l[1]
		light.omni_range = 3.6
		light.omni_attenuation = 2.0
		if l[2] >= 0.0:
			light.set_script(load("res://scripts/migotanie.gd"))
			light.set("awaria", l[2])
			light.set("plafon", NodePath("../" + p.name))
		_own(light)
		i += 1

	# chłodne światło zza okien
	for k in PIETRA:
		var w := OmniLight3D.new()
		w.name = "Okno%d" % k
		w.position = Vector3(4.9, k * H + H / 2 + 1.5, 1.3)
		w.light_color = Color(0.5, 0.56, 0.85)
		w.light_energy = 0.2
		w.omni_range = 3.2
		_own(w)

	_gracz()
	_post()

	var ps := PackedScene.new()
	var err := ps.pack(scena)
	if err == OK:
		err = ResourceSaver.save(ps, "res://scenes/probka.tscn")
	print("zapis sceny: ", error_string(err))
	quit()


func _own(n: Node, parent: Node = null) -> Node:
	(parent if parent else scena).add_child(n)
	n.owner = scena
	return n


func _dodaj(model: String, pos: Vector3, rot_deg: float, nazwa := "") -> Node3D:
	var inst: Node3D = load(M + model + ".glb").instantiate()
	inst.name = nazwa if nazwa != "" else model.to_pascal_case()
	inst.position = pos
	inst.rotation_degrees.y = rot_deg
	scena.add_child(inst, true)
	inst.owner = scena
	return inst


func _srodowisko() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.005, 0.005, 0.008)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.44, 0.52)
	env.ambient_light_energy = 0.045
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.012, 0.012, 0.016)
	env.fog_density = 0.2
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "Srodowisko"
	we.environment = env
	_own(we)


func _gracz() -> void:
	var g := CharacterBody3D.new()
	g.name = "Gracz"
	g.set_script(load("res://scripts/gracz.gd"))
	g.position = Vector3(0.8, 0.05, 1.9)
	g.rotation_degrees.y = -90
	_own(g)
	var col := CollisionShape3D.new()
	col.name = "Ksztalt"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.875
	_own(col, g)
	var head := Node3D.new()
	head.name = "Glowa"
	head.position.y = 1.62
	_own(head, g)
	var cam := Camera3D.new()
	cam.name = "Kamera"
	cam.fov = 75
	cam.near = 0.05
	cam.far = 60
	cam.current = true
	_own(cam, head)
	var fl := SpotLight3D.new()
	fl.name = "Latarka"
	fl.position = Vector3(0.12, -0.12, 0)
	fl.light_color = Color(1.0, 0.95, 0.82)
	fl.light_energy = 2.4
	fl.spot_range = 14.0
	fl.spot_angle = 24.0
	fl.spot_attenuation = 0.8
	fl.shadow_enabled = true
	fl.visible = false
	_own(fl, cam)


func _post() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PostPSX"
	_own(layer)
	var rect := ColorRect.new()
	rect.name = "Dither"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/psx_post.gdshader")
	rect.material = mat
	_own(rect, layer)
