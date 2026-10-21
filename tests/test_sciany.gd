extends Node3D
## Test generatora: rzeczy montowane na ścianie (tablice, hydranty, apteczki, skrzynki, kaloryfery, znaki)
## muszą mieć za plecami ścianę – nie mogą wisieć w powietrzu. Do tego kadry okien od środka (każdy kierunek
## ściany), żeby było widać, czy szyba i ościeża są od wnętrza.
## Uruchomienie: godot --path . tests/test_sciany.tscn -- [--kadry DIR] [--ziarna N]

const NAZWY := ["Hydrant", "TablicaOgloszen", "ApteczkaScienna", "SkrzynkiPocztowe", "Kaloryfer", "ZnakWyjscie"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var kadry := ""
	var ile := 12
	for i in args.size():
		if args[i] == "--kadry" and i + 1 < args.size():
			kadry = args[i + 1]
		if args[i] == "--ziarna" and i + 1 < args.size():
			ile = int(args[i + 1])
	if kadry != "":
		DirAccess.make_dir_recursive_absolute(kadry)
	var bledy := 0
	var sprawdzone := 0
	var okna_kier := {}
	for z in range(1, ile + 1):
		var swiat := Node3D.new()
		add_child(swiat)
		var parter := Node3D.new()
		swiat.add_child(parter)
		var gen := GeneratorBiomu.new()
		gen.generuj(z * 7 + 1, parter)
		var pn := Node3D.new()
		swiat.add_child(pn)
		pn.position = Vector3(0, GeneratorBiomu.PIETRO_H, 0)
		var gen_p := GeneratorBiomu.new()
		gen_p.pietro = 1
		var kl := gen._komorka_klatki()
		gen_p.wym_sy = kl.y
		gen_p.wym_rect_klatki = gen.komorki[kl]["rect"]
		gen_p.generuj(z * 91 + 5, pn)
		for _i in 3:
			await get_tree().physics_frame
		var space := get_world_3d().direct_space_state
		for n in swiat.find_children("*", "", true, false):
			var nazwa := String(n.name)
			var baza := ""
			for nz in NAZWY:
				if nazwa == nz or nazwa.begins_with(nz):
					baza = nz
			if baza == "" or not (n is Node3D):
				continue
			sprawdzone += 1
			var p: Vector3 = (n as Node3D).global_position + Vector3.UP * 0.25
			var tyl: Vector3 = (n as Node3D).global_basis.z * -1.0
			var trafiony := false
			for kier in [tyl, -tyl, Vector3(tyl.z, 0, -tyl.x), Vector3(-tyl.z, 0, tyl.x)]:
				var q := PhysicsRayQueryParameters3D.create(p, p + (kier as Vector3).normalized() * 0.5, Balistyka.WARSTWA_SWIAT)
				if not space.intersect_ray(q).is_empty():
					trafiony = true
					break
			if not trafiony:
				bledy += 1
				var komorka: GeneratorBiomu = gen if parter.is_ancestor_of(n) else gen_p
				var k: Vector2i = komorka.komorka_w((n as Node3D).global_position - (Vector3.ZERO if parter.is_ancestor_of(n) else pn.position))
				print("  BŁĄD: %s wisi w powietrzu – ziarno %d, %s, komórka %s (%s), poz %s" % [baza, z, "parter" if parter.is_ancestor_of(n) else "piętro", k, komorka.komorki[k]["typ"] if komorka.komorki.has(k) else "?", (n as Node3D).global_position])
		if kadry != "":
			for g in [gen]:
				for o in g.okna:
					var d: Vector2i = o[1]
					if okna_kier.has(d):
						continue
					okna_kier[d] = true
					var pkt: Vector3 = o[2]
					var naz := Vector3(d.x, 0, d.y)
					var kam := Camera3D.new()
					swiat.add_child(kam)
					kam.global_position = pkt - naz * 2.4 + Vector3.UP * 1.6
					kam.look_at(pkt + Vector3.UP * 1.6)
					kam.current = true
					var sw := OmniLight3D.new()
					sw.omni_range = 6.0
					sw.light_energy = 1.5
					swiat.add_child(sw)
					sw.global_position = kam.global_position
					for _f in 4:
						await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(kadry.path_join("okno_%d_%d.png" % [d.x, d.y]))
					kam.queue_free()
					sw.queue_free()
		if args.has("--przeglad") and kadry != "" and z <= 2:
			# przegląd korytarzy: z każdego kwadratu korytarza w cztery strony (do obejrzenia na arkuszu)
			var kam2 := Camera3D.new()
			swiat.add_child(kam2)
			kam2.current = true
			var sw2 := OmniLight3D.new()
			sw2.omni_range = 14.0
			sw2.light_energy = 0.8
			kam2.add_child(sw2)
			var nr := 0
			for g2 in [gen, gen_p]:
				var off := Vector3.ZERO if g2 == gen else pn.position
				for k in g2.komorki:
					if g2.komorki[k]["typ"] != "korytarz":
						continue
					for d in GeneratorBiomu.DIRS:
						var c: Vector3 = g2._srodek(k) + off + Vector3.UP * 1.6
						kam2.global_position = c - Vector3(d.x, 0, d.y) * 1.2
						kam2.look_at(c + Vector3(d.x, 0, d.y) * 4.0)
						for _f in 3:
							await get_tree().process_frame
						await RenderingServer.frame_post_draw
						var im := get_viewport().get_texture().get_image()
						im.resize(480, 270)
						im.save_png(kadry.path_join("kor_%d_%03d_%s_%d_%d_%d_%d.png" % [z, nr, "p" if g2 == gen else "g", k.x, k.y, d.x, d.y]))
						nr += 1
		swiat.queue_free()
		await get_tree().process_frame
	print("TEST ŚCIAN: sprawdzonych %d, kierunków okien %d, błędów %d" % [sprawdzone, okna_kier.size(), bledy])
	get_tree().quit()
