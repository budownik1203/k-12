extends Node3D
## Podgląd modeli (ręce, broń) do zrzutów: godot --path . res://tests/podglad.tscn -- <katalog> <tryb>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var kat: String = args[0] if args.size() > 0 else "build/podglad"
	var tryb: String = args[1] if args.size() > 1 else "rece"
	DirAccess.make_dir_recursive_absolute(kat)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.6)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sw := DirectionalLight3D.new()
	sw.rotation = Vector3(-0.8, 0.6, 0)
	sw.light_energy = 1.2
	add_child(sw)
	var kam := Camera3D.new()
	kam.fov = 50
	add_child(kam)
	match tryb:
		"rece":
			var poz := ["otwarta", "pistolet", "lozysko", "piesc"]
			for i in poz.size():
				var r := Reka.new(true, true, poz[i], 0.06)
				r.position = Vector3(i * 1.0, 0, 0)
				add_child(r)
			for i in poz.size():
				for kk in 2:
					var p0 := Vector3(i * 1.0, 0, -0.05)
					kam.position = p0 + (Vector3(0.22, -0.04, 0.06) if kk == 0 else Vector3(-0.12, -0.2, 0.1))
					kam.look_at(p0)
					for f in 6:
						await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(kat.path_join("reka_%d_%d.png" % [i, kk]))
			get_tree().quit()
			return
		"bronie":
			var lista := ["pw9", "pm63", "kb47", "obrzyn"]
			for i in lista.size():
				var md := Modele.bron(lista[i])
				var n := Node3D.new()
				n.position = Vector3(i * 6.0, 0, 0)
				add_child(n)
				n.add_child(Bryly.instancja(md["cialo3"]))
				if "--dodatki" in OS.get_cmdline_user_args():
					var pr := Przedmiot.nowy(lista[i])
					var dozw: Dictionary = pr.defn()["bron"].get("dodatki", {})
					for sl in dozw:
						var wyb: Array = dozw[sl]
						var idd: String = wyb[wyb.size() - 1] if sl == "celownik" and "--luneta" in OS.get_cmdline_user_args() else wyb[0]
						pr.dane["dod_" + sl] = Przedmiot.nowy(idd)
					var bb = load("res://scripts/gracz/bron.gd").new()
					bb.md = md
					var dod: Array = bb._zastosuj_dodatki(pr)
					if not dod.is_empty():
						n.add_child(Bryly.instancja(dod))
					bb.free()
				if not (md["mag3"] as Array).is_empty():
					n.add_child(Bryly.instancja(md["mag3"]))
			kam.fov = 30
			for i in lista.size():
				var dl := 0.55 if lista[i] == "pw9" else (1.0 if lista[i] == "pm63" else (1.3 if lista[i] == "kb47" else 1.2))
				var sr := Vector3(i * 6.0, 0.0, -0.18 if lista[i] == "kb47" else -0.08)
				for kk in 2:
					kam.position = sr + (Vector3(dl, 0.02, 0.0) if kk == 0 else Vector3(-dl * 0.55, dl * 0.35, dl * 0.6))
					kam.look_at(sr)
					for f in 4:
						await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(kat.path_join("bron_%s_%d.png" % [lista[i], kk]))
			get_tree().quit()
			return
	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(kat.path_join(tryb + ".png"))
	# drugi kąt
	kam.position = Vector3(0.25, 0.35, 0.3)
	kam.look_at(Vector3(0, 0, 0.0))
	for f in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(kat.path_join(tryb + "_2.png"))
	get_tree().quit()
