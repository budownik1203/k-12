extends CanvasLayer
## HUD rajdu: minimalny. Kropka celownika, stan ciała, broń i tryb (bez licznika naboi),
## wytrzymałość, waga i hałas, podpowiedź interakcji, postęp akcji, komunikaty, napisy wrogów,
## lista wyjść [O], odliczanie ewakuacji, wskaźnik trafienia.

var rajd: Node
var gracz: Gracz

var _root: Control
var _kropka: Control
var _cialo: Control
var _stan: Label
var _bron: Label
var _wytrz: ProgressBar
var _waga: Label
var _interakcja: Label
var _akcja: ProgressBar
var _akcja_txt: Label
var _komunikaty: VBoxContainer
var _napisy: VBoxContainer
var _wyjscia: Label
var _wyjscia_t := 10.0
var _odliczanie: Label
var _czas: Label
var _trafienie := 0.0
var _trafienie_kier := 0.0
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 10
	add_to_group("hud")
	gracz = rajd.gracz if rajd else null
	_mat = rajd.widok["material"] if rajd else null
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Motyw.motyw()
	add_child(_root)
	_kropka = Kropka.new()
	_kropka.hud = self
	_root.add_child(_kropka)
	# lewy dół: sylwetka ciała i stany
	_cialo = Sylwetka.new()
	_cialo.hud = self
	_cialo.position = Vector2(24, 0)
	_cialo.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_cialo.offset_top = -150
	_cialo.offset_left = 24
	_root.add_child(_cialo)
	_stan = _lbl(Vector2(92, -150), 13, Motyw.CZERWIEN, Control.PRESET_BOTTOM_LEFT)
	_wytrz = ProgressBar.new()
	_wytrz.show_percentage = false
	_wytrz.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_wytrz.offset_left = 92
	_wytrz.offset_top = -40
	_wytrz.offset_right = 232
	_wytrz.offset_bottom = -32
	_wytrz.max_value = 100
	_root.add_child(_wytrz)
	_waga = _lbl(Vector2(92, -30), 12, Motyw.TEKST_CIEMNY, Control.PRESET_BOTTOM_LEFT)
	# prawy dół: broń
	_bron = Label.new()
	_bron.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_bron.offset_left = -360
	_bron.offset_top = -58
	_bron.offset_right = -24
	_bron.offset_bottom = -20
	_bron.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bron.add_theme_font_override("font", Motyw.mono_b())
	_bron.add_theme_font_size_override("font_size", 14)
	_bron.add_theme_color_override("font_color", Motyw.TEKST)
	_root.add_child(_bron)
	# środek dół: interakcja i postęp
	_interakcja = _lbl_srodek(-130, 16, Motyw.TEKST)
	_akcja_txt = _lbl_srodek(-100, 13, Motyw.ZOLC)
	_akcja = ProgressBar.new()
	_akcja.show_percentage = false
	_akcja.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_akcja.offset_left = -110
	_akcja.offset_right = 110
	_akcja.offset_top = -80
	_akcja.offset_bottom = -72
	_akcja.visible = false
	_root.add_child(_akcja)
	# komunikaty (lewa góra)
	_komunikaty = VBoxContainer.new()
	_komunikaty.position = Vector2(24, 20)
	_komunikaty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_komunikaty)
	# napisy wrogów (dół, nad środkiem)
	_napisy = VBoxContainer.new()
	_napisy.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_napisy.offset_left = -300
	_napisy.offset_right = 300
	_napisy.offset_top = -230
	_napisy.offset_bottom = -150
	_napisy.alignment = BoxContainer.ALIGNMENT_END
	_napisy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_napisy)
	# wyjścia (prawa góra) i czas
	_czas = Label.new()
	_czas.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_czas.offset_left = -260
	_czas.offset_right = -24
	_czas.offset_top = 18
	_czas.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_czas.add_theme_font_override("font", Motyw.mono())
	_czas.add_theme_font_size_override("font_size", 13)
	_czas.add_theme_color_override("font_color", Motyw.TEKST_CIEMNY)
	_root.add_child(_czas)
	_wyjscia = Label.new()
	_wyjscia.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wyjscia.offset_left = -460
	_wyjscia.offset_right = -24
	_wyjscia.offset_top = 40
	_wyjscia.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wyjscia.add_theme_font_override("font", Motyw.mono())
	_wyjscia.add_theme_font_size_override("font_size", 14)
	_wyjscia.add_theme_color_override("font_color", Motyw.TEKST)
	_root.add_child(_wyjscia)
	_odliczanie = _lbl_srodek(-420, 30, Motyw.ZIELEN)
	_odliczanie.add_theme_font_override("font", Motyw.mono_b())
	if gracz:
		gracz.komunikat.connect(komunikat)
		gracz.trafiony_sygnal.connect(_trafiony)
	komunikat("Kontrakt aktywny. Wyjścia: [O]. Ekwipunek: [Tab].")


func _lbl(pos: Vector2, rozm: int, kol: Color, preset: int) -> Label:
	var l := Label.new()
	l.set_anchors_preset(preset)
	l.offset_left = pos.x
	l.offset_top = pos.y
	l.add_theme_font_override("font", Motyw.mono())
	l.add_theme_font_size_override("font_size", rozm)
	l.add_theme_color_override("font_color", kol)
	_root.add_child(l)
	return l


func _lbl_srodek(y: float, rozm: int, kol: Color) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.offset_left = -400
	l.offset_right = 400
	l.offset_top = y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Motyw.cond())
	l.add_theme_font_size_override("font_size", rozm)
	l.add_theme_color_override("font_color", kol)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	_root.add_child(l)
	return l


func _process(delta: float) -> void:
	if gracz == null:
		return
	var c := gracz.cialo
	# stany
	var st := []
	var k := c.krwawi()
	if k == 2:
		st.append("CIĘŻKIE KRWAWIENIE [5]")
	elif k == 1:
		st.append("KRWAWIENIE [4]")
	if c.zlamanie["nogi"] or c.zlamanie["rece"]:
		st.append("ZŁAMANIE [7]")
	if c.bol():
		st.append("BÓL [8]")
	_stan.text = "\n".join(st)
	_wytrz.value = gracz.wytrzymalosc
	_wytrz.visible = gracz.wytrzymalosc < 99.0
	var prog := gracz.prog_obciazenia()
	_waga.text = "%.1f kg%s" % [gracz.waga(), ["", " · obciążony", " · PRZECIĄŻONY", " · KRYTYCZNE OBCIĄŻENIE"][prog]]
	# broń
	var b := gracz.bron
	if b.przedmiot:
		var tryb := ""
		var tryby: Array = b.bd["tryby"]
		if tryby.size() > 1:
			tryb = "  [%s]" % ("CIĄGŁY" if tryby[b.przedmiot.dane["tryb"]] == "auto" else "POJ.")
		_bron.text = b.przedmiot.nazwa() + tryb + ("\nprzeładowanie..." if b.stan == "przeladowanie" else "")
	else:
		_bron.text = "bez broni"
	# interakcja
	_interakcja.text = ("[F] " + gracz.tekst_interakcji) if gracz.tekst_interakcji != "" and not Sterowanie.blokada else ""
	# akcja
	if not gracz.akcja.is_empty():
		_akcja.visible = true
		_akcja.max_value = gracz.akcja["czas"]
		_akcja.value = gracz.akcja["t"]
		_akcja_txt.text = gracz.akcja["nazwa"]
	else:
		_akcja.visible = false
		_akcja_txt.text = ""
	# czas rajdu
	if rajd:
		var t: float = rajd.czas
		_czas.text = "RAJD %d:%02d" % [int(t) / 60, int(t) % 60]
		# wyjścia
		if Input.is_action_just_pressed("wyjscia") and not Sterowanie.blokada:
			_wyjscia_t = 8.0
		_wyjscia_t -= delta
		if _wyjscia_t > 0.0:
			var linie := ["WYJŚCIA ZE STREFY:"]
			for w in rajd.info["wyjscia"]:
				var ew: Ewakuacja = w
				var d := ew.global_position - gracz.global_position
				var kier := _kierunek(d)
				linie.append("%s — %s  (%s, ~%d m)" % [ew.nazwa, ew.opis_stanu(), kier, int(d.length())])
			_wyjscia.text = "\n".join(linie)
		else:
			_wyjscia.text = ""
		# odliczanie ewakuacji
		var odl := ""
		for w in rajd.info["wyjscia"]:
			var ew2: Ewakuacja = w
			if ew2.odliczanie >= 0.0:
				odl = "EWAKUACJA ZA %.1f" % ew2.odliczanie
			elif ew2._gracz != null and not ew2.aktywne():
				odl = ew2.nazwa + ": " + ew2.opis_stanu()
		_odliczanie.text = odl
	# efekty na obrazie: trafienie, ból, niskie zdrowie
	_trafienie = maxf(0.0, _trafienie - delta * 1.6)
	if _mat:
		var niskie := clampf(1.0 - c.procent() * 1.6, 0.0, 0.6)
		_mat.set_shader_parameter("kolor_bolu", Color(0.5, 0.0, 0.0, maxf(_trafienie * 0.7, niskie)))
		_mat.set_shader_parameter("rozmycie_bol", 1.2 if c.bol() else (_trafienie * 2.0))
	_kropka.queue_redraw()
	_cialo.queue_redraw()


func _kierunek(d: Vector3) -> String:
	# kierunek względem patrzenia gracza
	var lok := gracz.global_basis.inverse() * d
	var kat := rad_to_deg(atan2(lok.x, -lok.z))
	if absf(kat) < 25.0:
		return "przed tobą"
	if absf(kat) > 155.0:
		return "za tobą"
	if kat > 0.0:
		return "w prawo" if kat < 110.0 else "w prawo, za tobą"
	return "w lewo" if kat > -110.0 else "w lewo, za tobą"


func komunikat(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", Motyw.cond())
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Motyw.TEKST)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	_komunikaty.add_child(l)
	while _komunikaty.get_child_count() > 6:
		_komunikaty.get_child(0).queue_free()
		_komunikaty.remove_child(_komunikaty.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func napis_wroga(kto: String, tekst: String, pos: Vector3) -> void:
	if gracz == null or gracz.global_position.distance_to(pos) > 22.0:
		return
	var l := Label.new()
	l.text = "%s: %s" % [kto, tekst]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Motyw.cond())
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.86, 0.76, 0.5))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	_napisy.add_child(l)
	while _napisy.get_child_count() > 3:
		var c := _napisy.get_child(0)
		_napisy.remove_child(c)
		c.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _trafiony(kier: Vector3, _czesc: String) -> void:
	_trafienie = 1.0
	var lok := gracz.global_basis.inverse() * kier
	_trafienie_kier = atan2(lok.x, -lok.z)


class Kropka:
	extends Control
	var hud

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var g: Gracz = hud.gracz
		if g == null or g.cialo.martwy or Sterowanie.blokada:
			return
		var c := size * 0.5
		if g.bron.ads < 0.5:
			draw_rect(Rect2(c - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.85, 0.82, 0.7, 0.7))
		if hud._trafienie > 0.0:
			var a: float = hud._trafienie_kier
			var p := c + Vector2(sin(a), -cos(a)) * 110.0
			var kol := Color(0.8, 0.1, 0.05, hud._trafienie)
			draw_line(p - Vector2(cos(a), sin(a)) * 26, p + Vector2(cos(a), sin(a)) * 26, kol, 4.0)


class Sylwetka:
	extends Control
	var hud

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(60, 130)

	func _draw() -> void:
		var g: Gracz = hud.gracz
		if g == null:
			return
		var c: Cialo = g.cialo
		var t := Time.get_ticks_msec() / 1000.0
		var czesci := {
			"glowa": [Rect2(22, 0, 16, 18)], "klatka": [Rect2(16, 20, 28, 26)], "brzuch": [Rect2(18, 47, 24, 18)],
			"rece": [Rect2(4, 20, 10, 44), Rect2(46, 20, 10, 44)], "nogi": [Rect2(18, 67, 11, 56), Rect2(31, 67, 11, 56)],
		}
		for cz in czesci:
			var f: float = c.hp[cz] / Cialo.MAX[cz]
			var kol := Color(0.35, 0.36, 0.3).lerp(Color(0.75, 0.2, 0.12), 1.0 - f)
			if f <= 0.0:
				kol = Color(0.08, 0.08, 0.08)
			if c.krwawienie[cz] > 0 and fmod(t, 0.8) < 0.4:
				kol = Color(0.9, 0.1, 0.05)
			for r in czesci[cz]:
				draw_rect(r, Color(kol, 0.85))
				draw_rect(r, Color(0, 0, 0, 0.6), false, 1.0)
			if c.zlamanie[cz]:
				for r in czesci[cz]:
					draw_line(r.position, r.end, Color(1, 0.9, 0.6), 2.0)
