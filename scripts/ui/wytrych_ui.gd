class_name WytrychUI
extends CanvasLayer
## Otwieranie zamka wytrychem (zbliżenie dziurki od klucza): ruch myszy w poziomie ustawia kąt haczyka,
## przytrzymany LPM napina zamek napinaczem. Im bliżej właściwego kąta, tym dalej obraca się bębenek;
## w złym miejscu haczyk się napręża (drży, trzeszczy) i po chwili pęka. Pełny obrót – zamek otwarty.
## Esc / PPM / X – odejście od drzwi. Trafienie przerywa.

signal skonczone(otwarte: bool)

var drzwi: Node            # drzwi (na_klucz, rodzaj, srodek(), _slodki_kat) – albo poniższe pola dla kłódki
var zamkniete: Callable    # () -> bool
var odblokuj: Callable     # ()
var tolerancja := 12.0
var slodki := 90.0
var punkt := Vector3.ZERO
var gracz: Node
var wytrych: Przedmiot

var _kat := 90.0           # kąt haczyka 0..180
var _obrot := 0.0          # obrót bębenka 0..90
var _napiecie := 0.0       # 0..1 – naprężenie haczyka w złym miejscu
var _dzw_t := 0.0
var _root: Control
var _rys: Control
var _koniec := false
var test_napinaj := false   # testy automatyczne: napięcie bez myszy


func _ready() -> void:
	layer = 25
	add_to_group("ekran_ekwipunku")      # trafienie przerywa (zerwij_sie)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var tlo := ColorRect.new()
	tlo.color = Color(0, 0, 0, 0.55)
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	tlo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(tlo)
	_rys = Control.new()
	_rys.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rys.draw.connect(_rysuj)
	_root.add_child(_rys)
	var l := Motyw.etykieta("Ruch myszy w bok – kąt haczyka  ·  LPM (przytrzymaj) – napnij zamek  ·  Esc / PPM – przerwij", 14, Motyw.TEKST, Motyw.mono())
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.offset_top = -80
	l.offset_left = -400
	l.offset_right = 400
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(l)
	Sterowanie.blokada = true
	Dzwiek.graj("wytrych", -12.0)


func _zakoncz(otw: bool) -> void:
	if _koniec:
		return
	_koniec = true
	skonczone.emit(otw)
	_root.visible = false
	# LPM trzymany przy napinaniu: sterowanie wraca dopiero po puszczeniu przycisku (inaczej broń od razu strzela)
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_inside_tree():
		await get_tree().process_frame
	Sterowanie.blokada = false
	if gracz and gracz.get("bron"):
		gracz.bron.spust_puszczony = true
	queue_free()


func zerwij_sie(_powod: String) -> void:
	if gracz:
		gracz.komunikat.emit("Wytrych wypada z zamka – musisz się bronić")
	_zakoncz(false)


func _input(event: InputEvent) -> void:
	if _koniec:
		return
	if event.is_action_pressed("pauza") or event.is_action_pressed("przerwij") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()
		_zakoncz(false)
		return
	if event is InputEventMouseMotion and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var stary := _kat
		_kat = clampf(_kat + (event as InputEventMouseMotion).relative.x * 0.22, 0.0, 180.0)
		_dzw_t -= absf(_kat - stary)
		if _dzw_t <= 0.0:
			_dzw_t = 9.0
			Dzwiek.graj("klik", -24.0, randf_range(2.2, 2.8))
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _koniec:
		return
	if drzwi != null:
		if not is_instance_valid(drzwi):
			_zakoncz(false)
			return
		tolerancja = 7.0 if drzwi.rodzaj == "metal" else 12.0
		slodki = float(drzwi._slodki_kat)
		punkt = drzwi.srodek()
	var zamk: bool = drzwi.na_klucz if drzwi != null else (zamkniete.call() if zamkniete.is_valid() else false)
	if not zamk:
		_zakoncz(false)
		return
	var tol := tolerancja
	var odl := absf(_kat - slodki)
	var max_obrot := 90.0 * clampf(1.0 - (odl - tol) / 34.0, 0.0, 1.0)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or test_napinaj:
		if _obrot < max_obrot - 1.0:
			_obrot = move_toward(_obrot, max_obrot, delta * 60.0)
			_napiecie = maxf(0.0, _napiecie - delta)
		else:
			# opór: haczyk się napręża
			_napiecie += delta * (1.2 if max_obrot < 85.0 else 0.0)
			if randf() < delta * 6.0:
				Dzwiek.graj("klik", -16.0, randf_range(1.4, 1.8))
			if _napiecie >= 1.0:
				_peka()
				return
		if _obrot >= 89.0:
			Dzwiek.graj("zamek_pist", -10.0, 0.8)
			if drzwi != null:
				Dzwiek.graj_3d("klik", drzwi.srodek(), drzwi.get_parent(), -4.0, 0.7)
				drzwi.na_klucz = false
			elif odblokuj.is_valid():
				odblokuj.call()
			if gracz:
				gracz.komunikat.emit("Zamek puścił")
			_zakoncz(true)
			return
	else:
		_obrot = move_toward(_obrot, 0.0, delta * 120.0)
		_napiecie = maxf(0.0, _napiecie - delta * 2.0)
	_rys.queue_redraw()


func _peka() -> void:
	Dzwiek.graj("klik", -4.0, 3.0)
	Gra.emituj_halas(gracz.global_position, 3.0, gracz)
	_napiecie = 0.0
	_obrot = 0.0
	if wytrych:
		var z := int(wytrych.dane.get("zlamane", 0)) + 1
		wytrych.dane["zlamane"] = z
		if z >= 3:
			gracz.ekw.usun_przedmiot(wytrych)
			gracz.komunikat.emit("Pękł ostatni haczyk – wytrychy do wyrzucenia")
			_zakoncz(false)
			return
		gracz.komunikat.emit("Haczyk pękł (zostało %d)" % (3 - z))


func _rysuj() -> void:
	var c := _rys.size * 0.5
	var drz := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _napiecie * 3.0
	var r := 120.0
	# szyld i bębenek
	_rys.draw_circle(c, r + 26, Color(0.32, 0.27, 0.16))
	_rys.draw_circle(c, r + 18, Color(0.55, 0.46, 0.26))
	_rys.draw_circle(c, r, Color(0.66, 0.56, 0.32))
	var a := deg_to_rad(_obrot)
	var kier := Vector2(sin(a), -cos(a))
	var bok := Vector2(cos(a), sin(a))
	# dziurka od klucza obraca się razem z bębenkiem
	var pts := PackedVector2Array([c + kier * 34 - bok * 9, c + kier * 34 + bok * 9, c + kier * 6 + bok * 5, c - kier * 52 + bok * 5, c - kier * 52 - bok * 5, c + kier * 6 - bok * 5])
	_rys.draw_colored_polygon(pts, Color(0.05, 0.04, 0.03))
	_rys.draw_circle(c + kier * 30, 14, Color(0.05, 0.04, 0.03))
	# napinacz (na dole dziurki)
	var nap := c - kier * 46 + drz
	_rys.draw_line(nap, nap + Vector2(140, 60).rotated(a * 0.3), Color(0.55, 0.56, 0.58), 5.0)
	# haczyk: od środka w stronę kąta
	var ak := deg_to_rad(180.0 - _kat)
	var hk := Vector2(cos(ak), -sin(ak))
	var start := c + kier * 22 + drz
	_rys.draw_line(start, start + hk * 210, Color(0.75, 0.76, 0.78), 4.0)
	_rys.draw_line(start, start + hk * 14 + hk.orthogonal() * 7, Color(0.75, 0.76, 0.78), 3.0)
	# naprężenie – czerwone drżenie
	if _napiecie > 0.05:
		_rys.draw_arc(c, r + 34, 0, TAU, 64, Color(0.9, 0.2, 0.1, _napiecie * 0.6), 4.0)
	_rys.draw_string(Motyw.mono_b(), c + Vector2(-60, r + 70), "OBRÓT %d°" % int(_obrot), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.85, 0.7))
