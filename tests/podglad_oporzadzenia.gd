extends Node3D
## Podgląd modeli oporządzenia: zamknięty i otwarty (wszystkie kieszenie), zrzuty do katalogu z argumentu.
## godot --path . tests/podglad_oporzadzenia.tscn --rendering-driver opengl3 -- katalog [id,id...]

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var kat := a[0] if a.size() > 0 else "/tmp/podglad"
	DirAccess.make_dir_recursive_absolute(kat)
	var ids := ["worek", "plecak_turystyczny", "plecak_szturmowy", "chlebak", "plecak_wojskowy", "napiersnik", "kamizelka_lbv", "kamizelka_wedkarska", "kamizelka_mysliwska", "kontener"]
	if a.size() > 1:
		ids = a[1].split(",")
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.25, 0.27)
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sl := DirectionalLight3D.new()
	sl.rotation = Vector3(-0.9, 0.5, 0)
	add_child(sl)
	var kam := Camera3D.new()
	add_child(kam)
	var podl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4, 4)
	podl.mesh = pm
	add_child(podl)
	for id in ids:
		var kamz: bool = id in ModeleOporzadzenia.KAMIZELKI
		var m := ModeleOporzadzenia.zbuduj(id)
		var w: Node3D = m["wezel"]
		add_child(w)
		podl.visible = not kamz
		var ab: AABB = ModelePrzedmiotow._aabb(w, Transform3D.IDENTITY)
		var sr := ab.get_center()
		var r := ab.size.length()
		if kamz:
			kam.position = sr + Vector3(0.15, 0.2, 1.0).normalized() * r * 1.3
		else:
			kam.position = sr + Vector3(0.25, 1.0, 0.75).normalized() * r * 1.5
		kam.look_at(sr)
		await _klatki(3)
		get_viewport().get_texture().get_image().save_png("%s/%s_a.png" % [kat, id])
		var czas := 0.0
		kam.fov = 50.0
		for kz in m["kieszenie"]:
			for krok in kz["kroki"]:
				for zm in krok:
					var tw := create_tween()
					tw.tween_property(zm[0], NodePath(String(zm[1])), zm[2], float(zm[3])).set_delay(czas)
				var dl := 0.0
				for zm in krok:
					dl = maxf(dl, float(zm[3]))
				czas += dl
		await get_tree().create_timer(czas * 0.5).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s_b.png" % [kat, id])
		await get_tree().create_timer(czas * 0.5 + 0.2).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s_c.png" % [kat, id])
		w.queue_free()
	get_tree().quit()


func _klatki(n: int) -> void:
	for i in n:
		await get_tree().process_frame
