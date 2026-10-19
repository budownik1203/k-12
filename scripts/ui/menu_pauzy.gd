extends CanvasLayer
## Menu pauzy (Esc). W rajdzie gra NIE zatrzymuje się (jak w grach extraction) – tylko blokuje sterowanie.

var w_rajdzie := true
var otwarte := false
var _root: Control
var _ustawienia: VBoxContainer


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = Motyw.motyw()
	_root.visible = false
	add_child(_root)
	var tlo := ColorRect.new()
	tlo.color = Color(0, 0, 0, 0.75)
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(tlo)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(c)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(420, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(Motyw.etykieta("PRZERWA W SŁUŻBIE", 22, Motyw.TEKST, Motyw.mono_b()))
	if w_rajdzie:
		var info := Motyw.etykieta("Strefa nie czeka. Czas rajdu płynie dalej.", 13, Motyw.TEKST_CIEMNY)
		v.add_child(info)
	_przycisk(v, "Wznów", zamknij)
	_przycisk(v, "Ustawienia", func(): _ustawienia.visible = not _ustawienia.visible)
	_ustawienia = VBoxContainer.new()
	_ustawienia.visible = false
	v.add_child(_ustawienia)
	_suwak(_ustawienia, "Czułość myszy", "czulosc", 0.2, 3.0, 0.05)
	_suwak(_ustawienia, "Pole widzenia (FOV)", "fov", 60.0, 100.0, 1.0)
	_suwak(_ustawienia, "Głośność", "glosnosc", 0.0, 1.0, 0.05)
	_suwak(_ustawienia, "Głośność tła", "glosnosc_tla", 0.0, 1.0, 0.05)
	_suwak(_ustawienia, "Kołysanie kamery", "kolysanie", 0.0, 1.0, 0.05)
	_suwak(_ustawienia, "Skala renderu (wydajność)", "skala_renderu", 0.5, 1.0, 0.05)
	_przelacznik(_ustawienia, "Odwróć oś Y myszy", "odwroc_y")
	_przelacznik(_ustawienia, "Cienie od lamp", "cienie")
	_przelacznik(_ustawienia, "Wygładzanie krawędzi", "wygladzanie")
	_przelacznik(_ustawienia, "Wskazówki samouczka", "samouczek")
	_przelacznik(_ustawienia, "Licznik klatek (FPS)", "pokaz_fps")
	var rs := Button.new()
	rs.text = "Pokaż wskazówki od nowa"
	rs.pressed.connect(func():
		Gra.ustawienia["samouczek_widziane"] = []
		Gra.ustawienia["samouczek"] = true)
	_ustawienia.add_child(rs)
	if w_rajdzie:
		_przycisk(v, "Opuść rajd (zaginięcie w akcji)", func():
			zamknij()
			get_tree().call_group("ui_rajdu", "opusc_rajd"))
	else:
		_przycisk(v, "Menu główne", func():
			zamknij()
			Gra.zapisz()
			Gra.idz_do_menu())
	_przycisk(v, "Wyjdź z gry", func():
		if not w_rajdzie:
			Gra.zapisz()
		get_tree().quit())


func _przycisk(v: Control, t: String, f: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.pressed.connect(f)
	b.pressed.connect(func(): Dzwiek.graj("klik", -8.0))
	v.add_child(b)


func _suwak(v: Control, t: String, klucz: String, mn: float, mx: float, krok: float) -> void:
	var h := HBoxContainer.new()
	var l := Motyw.etykieta(t, 14)
	l.custom_minimum_size = Vector2(170, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = krok
	s.value = float(Gra.ustawienia.get(klucz, mn))
	s.custom_minimum_size = Vector2(180, 20)
	var w := Motyw.etykieta("%.2f" % s.value, 13, Motyw.TEKST_CIEMNY, Motyw.mono())
	s.value_changed.connect(func(x):
		Gra.ustawienia[klucz] = x
		w.text = "%.2f" % x
		Gra.ustawienia_zmiana.emit())
	h.add_child(s)
	h.add_child(w)
	v.add_child(h)


func _przelacznik(v: Control, t: String, klucz: String) -> void:
	var c := CheckButton.new()
	c.text = t
	c.button_pressed = bool(Gra.ustawienia.get(klucz, false))
	c.toggled.connect(func(x):
		Gra.ustawienia[klucz] = x
		Gra.ustawienia_zmiana.emit())
	v.add_child(c)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pauza"):
		get_viewport().set_input_as_handled()
		if otwarte:
			zamknij()
		elif not Sterowanie.blokada:
			otworz()


func otworz() -> void:
	otwarte = true
	_root.visible = true
	Sterowanie.blokada = true
	Sterowanie.menu_otwarte = true
	Sterowanie.przechwyc(false)


func zamknij() -> void:
	if otwarte and not w_rajdzie:
		Gra.zapisz()
	otwarte = false
	_root.visible = false
	Sterowanie.blokada = false
	Sterowanie.menu_otwarte = false
	Sterowanie.przechwyc(true)
