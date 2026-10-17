extends Node
## Menu główne. W tle klatka schodowa z wolno płynącą kamerą.

var _kamera: Camera3D
var _t := 0.0
var _root: Control
var _potw: Control


func _ready() -> void:
	var w := Widok3D.zbuduj(self, 0.08, 0.05)
	var swiat: Node3D = w["swiat"]
	var klatka: Node3D = load("res://assets/models/klatka_schodowa.glb").instantiate()
	swiat.add_child(klatka)
	for p in [Vector3(0.8, 2.6, 1.3), Vector3(4.75, 4.0, 1.3)]:
		var lampa: Node3D = load("res://assets/models/plafon.glb").instantiate()
		swiat.add_child(lampa)
		lampa.position = p
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.55)
		l.light_energy = 0.9
		l.omni_range = 5.0
		swiat.add_child(l)
		l.position = p + Vector3(0, -0.35, 0)
		if p.y > 3.0:
			l.set_script(load("res://scripts/swiat/migotanie.gd"))
			l.set("awaria", 0.4)
			l.set("plafon", l.get_path_to(lampa))
	var okno := OmniLight3D.new()
	okno.light_color = Color(0.5, 0.56, 0.85)
	okno.light_energy = 0.35
	okno.omni_range = 3.2
	swiat.add_child(okno)
	okno.position = Vector3(4.9, 2.9, 1.3)
	_kamera = Camera3D.new()
	_kamera.fov = 70
	swiat.add_child(_kamera)
	_kamera.current = true
	Sterowanie.przechwyc(false)
	Sterowanie.blokada = true
	_ui()
	if OS.get_cmdline_user_args().has("--test"):
		Gra.rozpocznij_rajd.call_deferred()
	elif OS.get_cmdline_user_args().has("--zrzuty"):
		var k: String = OS.get_cmdline_user_args()[OS.get_cmdline_user_args().find("--zrzuty") + 1]
		_zrzut.call_deferred(k)


func _ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = Motyw.motyw()
	cl.add_child(_root)
	var v := VBoxContainer.new()
	v.position = Vector2(80, 150)
	v.add_theme_constant_override("separation", 10)
	_root.add_child(v)
	v.add_child(Motyw.etykieta("STREFA K-12", 64, Motyw.TEKST, Motyw.mono_b()))
	v.add_child(Motyw.etykieta("Protokół kwarantanny nr 12  ·  dostęp wyłącznie dla personelu kontraktowego", 15, Motyw.TEKST_CIEMNY))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 30)
	v.add_child(sp)
	if Gra.istnieje_zapis():
		_przycisk(v, "Kontynuuj", func(): Gra.idz_do_bazy())
	_przycisk(v, "Nowa gra", _nowa_gra)
	_przycisk(v, "Wyjście", func(): get_tree().quit())
	var stopka := Motyw.etykieta("Demo grywalne · biom 1: Blokowisko · Godot 4.6", 12, Motyw.TEKST_CIEMNY, Motyw.mono())
	stopka.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stopka.offset_left = 80
	stopka.offset_top = -40
	_root.add_child(stopka)
	var sterowanie := Motyw.etykieta(
		"WSAD ruch · Shift bieg · Ctrl kucanie · Q/E wychylenie · Spacja skok\n" +
		"LPM strzał · PPM celowanie · R przeładowanie (przytrzymaj: upuść magazynek) · B tryb ognia · T sprawdź amunicję\n" +
		"F interakcja · Tab ekwipunek · G napełnij magazynki · L latarka · O wyjścia · 1/2 broń\n" +
		"4 bandaż · 5 opatrunek · 6 apteczka · 7 szyna · 8 środek przeciwbólowy", 13, Motyw.TEKST_CIEMNY, Motyw.mono())
	sterowanie.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	sterowanie.offset_left = 80
	sterowanie.offset_top = -140
	_root.add_child(sterowanie)


func _przycisk(v: Control, t: String, f: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(260, 40)
	b.pressed.connect(f)
	b.pressed.connect(func(): Dzwiek.graj("klik", -6.0))
	v.add_child(b)


func _nowa_gra() -> void:
	if not Gra.istnieje_zapis():
		Gra.nowa_gra()
		Gra.idz_do_bazy()
		return
	if _potw:
		return
	_potw = PanelContainer.new()
	_potw.position = Vector2(380, 290)
	var v := VBoxContainer.new()
	_potw.add_child(v)
	v.add_child(Motyw.etykieta("Nowa gra usunie obecny zapis (skrytkę, bony, statystyki).", 15))
	var h := HBoxContainer.new()
	v.add_child(h)
	var t := Button.new()
	t.text = "Usuń i zacznij od nowa"
	t.pressed.connect(func():
		Gra.usun_zapis()
		Gra.nowa_gra()
		Gra.idz_do_bazy())
	h.add_child(t)
	var n := Button.new()
	n.text = "Anuluj"
	n.pressed.connect(func():
		_potw.queue_free()
		_potw = null)
	h.add_child(n)
	_root.add_child(_potw)


func _process(delta: float) -> void:
	_t += delta * 0.08
	var p := Vector3(0.55 + sin(_t) * 0.12, 1.55 + sin(_t * 0.7) * 0.06, 0.75 + sin(_t * 0.9) * 0.1)
	_kamera.position = p
	_kamera.look_at(Vector3(4.2, 2.3 + sin(_t * 0.5) * 0.4, 0.7 + sin(_t * 0.3) * 0.5), Vector3.UP)


func _zrzut(k: String) -> void:
	DirAccess.make_dir_recursive_absolute(k)
	for f in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(k.path_join("menu.png"))
	get_tree().quit()
