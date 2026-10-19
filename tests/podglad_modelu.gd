extends Node3D
## Podgląd modelu z kilku stron: godot --path . tests/podglad_modelu.tscn --rendering-driver opengl3 -- katalog fauna|wrog:frakcja

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var kat := a[0]
	var co := a[1] if a.size() > 1 else "fauna"
	DirAccess.make_dir_recursive_absolute(kat)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.3, 0.32)
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sl := DirectionalLight3D.new()
	sl.rotation = Vector3(-0.8, 0.6, 0)
	add_child(sl)
	var podl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	podl.mesh = pm
	add_child(podl)
	var kam := Camera3D.new()
	kam.fov = 45.0
	add_child(kam)
	var obiekty := []
	var ile := 1
	if co.begins_with("wrog"):
		ile = 4
	for i in ile:
		var n: Node3D
		if co == "fauna":
			n = load("res://scripts/ai/fauna.gd").new()
		else:
			n = load("res://scripts/ai/wrog.gd").new()
			var fr := co.split(":")[1] if co.contains(":") else "szabrownik"
			var rng := RandomNumberGenerator.new()
			rng.seed = i * 13 + 5
			var zest: Array = Dane.frakcje[fr]["zestawy"]
			n.przygotuj(fr, zest[i % zest.size()], rng)
		add_child(n)
		n.position = Vector3((i - (ile - 1) * 0.5) * 0.9, 0, 0)
		obiekty.append(n)
	await get_tree().process_frame
	for k in 20:
		await get_tree().process_frame
	for n in obiekty:
		n.set_physics_process(false)
		n.set_process(false)
		if co == "fauna":
			n.global_position = Vector3.ZERO
			n.get("_model").global_basis = Basis.IDENTITY
	var sr := Vector3(0, 0.35 if co == "fauna" else 0.9, 0)
	var odl := 1.5 if co == "fauna" else 3.4
	var widoki := {"przod": Vector3(0.0, 0.25, -1.0), "bok": Vector3(1.0, 0.3, 0.0), "skos": Vector3(0.7, 0.6, 0.7), "gora": Vector3(0.2, 1.0, 0.3)}
	for w in widoki:
		kam.position = sr + (widoki[w] as Vector3).normalized() * odl
		kam.look_at(sr)
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [kat, co.replace(":", "_"), w])
	get_tree().quit()
