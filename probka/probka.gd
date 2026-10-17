extends Node3D
## Scena próbki. Z argumentem "-- --zrzuty <katalog>" robi serię zrzutów ekranu z ustalonych ujęć i kończy.

const UJECIA := [
	# nazwa, pozycja kamery, punkt, na który patrzy, latarka
	["01_parter_wejscie", Vector3(1.45, 1.6, 2.35), Vector3(0.0, 1.0, 0.4), false],
	["02_parter_schody", Vector3(0.9, 1.6, 0.75), Vector3(4.0, 2.3, 0.6), false],
	["03_spocznik_okno", Vector3(4.25, 3.0, 2.25), Vector3(5.4, 2.6, 0.9), false],
	["04_bieg_w_gore", Vector3(4.3, 3.0, 1.85), Vector3(1.0, 3.8, 2.0), false],
	["05_podest_drzwi", Vector3(1.55, 4.4, 1.9), Vector3(0.0, 3.85, 0.6), false],
	["06_dusza_klatki", Vector3(1.25, 7.25, 0.55), Vector3(3.3, 3.0, 1.3), true],
	["07_spocznik_rupiecie", Vector3(4.2, 5.8, 1.2), Vector3(5.4, 4.7, 1.4), false],
	["08_ciemne_pietro", Vector3(4.5, 5.85, 1.9), Vector3(0.6, 6.6, 1.3), true],
]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--zrzuty")
	if i >= 0:
		var dir: String = args[i + 1] if args.size() > i + 1 else "user://zrzuty"
		_zrzuty.call_deferred(dir)


func _zrzuty(dir: String) -> void:
	seed(7)
	DirAccess.make_dir_recursive_absolute(dir)
	var gracz := $Gracz
	gracz.controls_enabled = false
	var cam: Camera3D = gracz.get_node("Glowa/Kamera")
	var lat: SpotLight3D = cam.get_node("Latarka")
	# kamera odłączona od gracza, żeby ustawiać ją swobodnie
	var free_cam := Camera3D.new()
	free_cam.fov = cam.fov
	add_child(free_cam)
	lat.reparent(free_cam, false)
	free_cam.make_current()
	for u in UJECIA:
		free_cam.global_position = u[1]
		free_cam.look_at(u[2], Vector3.UP)
		lat.visible = u[3]
		for f in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir.path_join(u[0] + ".png"))
		print("zrzut: ", u[0])
	get_tree().quit()
