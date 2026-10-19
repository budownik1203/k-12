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
var _kolko: KolkoPostepu
var _pasek: Control
var _bron_t := 3.0
var _bron_ost := ""
var _pasek_t := 4.0
var _pasek_ost := ""
var _znacznik := 0.0          # znacznik trafienia przy celowniku
var _znacznik_zabity := false
var _pomoc: PanelContainer
var _oglusz_blysk := 0.0
var _biel: ColorRect
var _kompas: Control
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
	_stan = _lbl(Vector2(92, -150), 14, Motyw.CZERWIEN, Control.PRESET_BOTTOM_LEFT)
	_stan.add_theme_font_override("font", Motyw.mono_b())
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
	_bron.offset_left = -380
	_bron.offset_top = -78
	_bron.offset_right = -24
	_bron.offset_bottom = -20
	_bron.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bron.add_theme_font_override("font", Motyw.mono_b())
	_bron.add_theme_font_size_override("font_size", 14)
	_bron.add_theme_color_override("font_color", Motyw.TEKST)
	_root.add_child(_bron)
	# środek: interakcja pod celownikiem, kółko postępu akcji, pasek szybkiego dostępu na dole
	_interakcja = Label.new()
	_interakcja.set_anchors_preset(Control.PRESET_CENTER)
	_interakcja.offset_left = -300
	_interakcja.offset_right = 300
	_interakcja.offset_top = 34
	_interakcja.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interakcja.add_theme_font_override("font", Motyw.cond())
	_interakcja.add_theme_font_size_override("font_size", 16)
	_interakcja.add_theme_color_override("font_color", Motyw.TEKST)
	_interakcja.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_interakcja.add_theme_constant_override("shadow_offset_x", 1)
	_interakcja.add_theme_constant_override("shadow_offset_y", 1)
	_root.add_child(_interakcja)
	_kolko = KolkoPostepu.new()
	_kolko.set_anchors_preset(Control.PRESET_CENTER)
	_kolko.offset_top = 80
	_kolko.visible = false
	_root.add_child(_kolko)
	_kompas = Kompas.new()
	_kompas.hud = self
	_kompas.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_kompas.offset_left = -200
	_kompas.offset_right = 200
	_kompas.offset_top = 10
	_kompas.offset_bottom = 40
	_root.add_child(_kompas)
	_pasek = Pasek.new()
	_pasek.hud = self
	_pasek.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_pasek.offset_left = -240
	_pasek.offset_right = 240
	_pasek.offset_top = -64
	_pasek.offset_bottom = -12
	_root.add_child(_pasek)
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
	_napisy.offset_top = -250
	_napisy.offset_bottom = -170
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
	_biel = ColorRect.new()
	_biel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_biel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_biel.color = Color(1, 0.98, 0.92, 0.0)
	_root.add_child(_biel)
	_pomoc = PanelContainer.new()
	_pomoc.set_anchors_preset(Control.PRESET_CENTER)
	_pomoc.offset_left = -300
	_pomoc.offset_right = 300
	_pomoc.offset_top = -230
	_pomoc.offset_bottom = 230
	_pomoc.add_theme_stylebox_override("panel", Motyw.styl_kieszeni(true))
	var lp := Motyw.etykieta("\n".join([
		"STEROWANIE",
		"WSAD · Shift bieg · Ctrl kucanie · Spacja skok · Q/E wychylenie",
		"LPM strzał · PPM celowanie · R przeładowanie (przytrzymaj: szybkie)",
		"B tryb ognia · T sprawdź magazynek",
		"1 broń główna · 2 pistolet (2x: z latarką) · 3 sama latarka · L latarka wł/wył",
		"4–9 leki z kamizelki i kieszeni · X przerwij leczenie/napełnianie",
		"F interakcja · Tab ekwipunek · G napełnij magazynki · O wyjścia",
		"",
		"EKWIPUNEK",
		"przeciągnij lek na część ciała – leczy ją",
		"przeciągnij poza sloty albo Del – wyrzuca na ziemię",
		"amunicja na magazynek – napełnia nabój po naboju",
		"R obraca · Ctrl+LPM szybko przenosi · PPM menu",
		"",
		"F1 zamyka",
	]), 15, Motyw.TEKST, Motyw.mono())
	_pomoc.add_child(lp)
	_pomoc.visible = false
	_root.add_child(_pomoc)
	komunikat("Wyjścia: [O]. Ekwipunek: [Tab]. Sterowanie: [F1].")
	for k in Gra.kontrakty.get("aktywne", []):
		komunikat("Zlecenie: %s" % k["opis"])


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
	if Input.is_action_just_pressed("pomoc"):
		_pomoc.visible = not _pomoc.visible
	var c := gracz.cialo
	# stany
	var st := []
	var k := c.krwawi()
	if k == 2:
		st.append("CIĘŻKIE KRWAWIENIE")
	elif k == 1:
		st.append("KRWAWIENIE")
	if c.zlamanie["nogi"] or c.zlamanie["rece"]:
		st.append("ZŁAMANIE")
	if c.bol():
		st.append("BÓL")
	if c.przeciwbol > 0.0:
		st.append("bólostop %ds" % int(c.przeciwbol))
	_stan.text = "\n".join(st)
	_wytrz.value = gracz.wytrzymalosc
	_wytrz.visible = gracz.wytrzymalosc < 99.0
	var prog := gracz.prog_obciazenia()
	_waga.text = "%.1f kg%s" % [gracz.waga(), ["", " · obciążony", " · PRZECIĄŻONY", " · KRYTYCZNE OBCIĄŻENIE"][prog]]
	# broń
	var b := gracz.bron
	var linie_b := []
	if b.przedmiot:
		var tryb := ""
		var tryby: Array = b.bd["tryby"]
		if tryby.size() > 1:
			tryb = "  [%s]" % ("CIĄGŁY" if tryby[b.przedmiot.dane["tryb"]] == "auto" else "POJ.")
		linie_b.append(b.przedmiot.nazwa() + tryb)
		if b.bd.has("magazynki"):
			var pod_reka := 0
			for s in gracz.ekw.siatki(true):
				for e in (s as Siatka).items:
					var m: Przedmiot = e["p"]
					if m.id in b.bd["magazynki"] and m.dane["naboje"] > 0:
						pod_reka += 1
			linie_b.append("zapas: %d mag. pod ręką" % pod_reka)
		if b.stan == "przeladowanie":
			linie_b.append("przeładowanie...")
		elif b.stan == "ladowanie_wewn":
			linie_b.append("ładowanie...")
	else:
		linie_b.append("latarka w ręce" if gracz.latarka_w_rece else "bez broni")
	if gracz.latarka_w_rece:
		linie_b.append("latarka: " + ("WŁ" if gracz.latarka_wlaczona else "wył") + "  [L]")
	elif gracz.bron.ma_latarke_broni():
		linie_b.append("latarka na broni: " + ("WŁ" if gracz.latarka_broni_wl else "wył") + "  [L]")
	# bez stałego HUD-u (jak w Iron Blight): opis broni i pasek pojawiają się na chwilę po zmianie,
	# zdrowie pokazuje zegarek na lewym nadgarstku
	var tekst_b := "\n".join(linie_b)
	if tekst_b != _bron_ost:
		_bron_ost = tekst_b
		_bron_t = 2.5
	_bron.text = tekst_b
	_bron_t = maxf(0.0, _bron_t - delta)
	_bron.modulate.a = clampf(_bron_t / 0.6, 0.0, 1.0)
	var klucz_p := "%s|%s" % [gracz.aktywny_slot, gracz.latarka_w_rece]
	for a in ["bron1", "bron2", "bron3", "pasek1", "pasek2", "pasek3", "pasek4", "pasek5", "pasek6"]:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			_pasek_t = 3.0
	if klucz_p != _pasek_ost:
		_pasek_ost = klucz_p
		_pasek_t = 3.0
	_pasek_t = maxf(0.0, _pasek_t - delta)
	_pasek.modulate.a = clampf(_pasek_t / 0.6, 0.0, 1.0)
	_cialo.visible = false
	_waga.visible = prog >= 2
	# interakcja
	_interakcja.text = ("[F]  " + gracz.tekst_interakcji) if gracz.tekst_interakcji != "" and not Sterowanie.blokada else ""
	# akcja: kółko pod celownikiem (w ekwipunku kółko jest przy kursorze)
	if not Sterowanie.blokada:
		_kolko.ustaw_z_gracza(gracz)
	else:
		_kolko.visible = false
	_znacznik = maxf(0.0, _znacznik - delta * (2.5 if _znacznik_zabity else 5.0))
	_pasek.queue_redraw()
	_kompas.visible = gracz.ekw.ma_wyposazenie("kompas") and not Sterowanie.blokada
	if _kompas.visible:
		_kompas.queue_redraw()
	# czas rajdu
	if rajd:
		var t: float = rajd.czas
		_czas.text = "RAJD %d:%02d" % [int(t) / 60, int(t) % 60]
		# wyjścia
		if Input.is_action_just_pressed("wyjscia") and not Sterowanie.blokada:
			_wyjscia_t = 8.0
		_wyjscia_t -= delta
		_czas.visible = _wyjscia_t > 0.0
		if _wyjscia_t > 0.0:
			var linie := ["WYJŚCIA ZE STREFY:"]
			for w in rajd.info["wyjscia"]:
				var ew: Ewakuacja = w
				var d := ew.global_position - gracz.global_position
				var kier := _kierunek(d)
				# z mapą na slocie wyposażenia: dokładna odległość; bez mapy tylko ogólny kierunek
				if gracz.ekw.ma_wyposazenie("mapa"):
					linie.append("%s — %s  (%s, ~%d m)" % [ew.nazwa, ew.opis_stanu(), kier, int(d.length())])
				else:
					linie.append("%s — %s  (%s)" % [ew.nazwa, ew.opis_stanu(), kier])
			if not gracz.ekw.ma_wyposazenie("mapa"):
				linie.append("(bez mapy – odległości nieznane)")
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
		_mat.set_shader_parameter("rozmycie_bol", maxf(1.2 if c.bol() else (_trafienie * 2.0), minf(3.0, gracz.oglusz * 1.2)))
	_oglusz_blysk = maxf(0.0, _oglusz_blysk - delta * 0.7)
	_biel.color.a = _oglusz_blysk * _oglusz_blysk
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


## Ogłuszenie: biały błysk i rozmycie, które powoli schodzą.
## Ekwipunek otwarty: HUD znika, żeby nie nachodził na panele (świat dalej widać).
func ukryj(t: bool) -> void:
	_root.visible = not t


func ogluszenie(sila: float) -> void:
	_oglusz_blysk = maxf(_oglusz_blysk, 0.35 + sila * 0.6)


## Znacznik trafienia przy celowniku (wołany przez broń gracza).
func znacznik_trafienia(zabity: bool, glowa := false) -> void:
	_znacznik = 1.0
	_znacznik_zabity = zabity
	Dzwiek.graj("klik", -6.0 if zabity else -12.0, 2.2 if not glowa else 2.8)


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
		var c := get_viewport_rect().size * 0.5
		if g.przygniecenie > 0.02:
			# przygniecenie ogniem: ciemne obrzeża kadru (tunel widzenia)
			var vs := get_viewport_rect().size
			for i in 8:
				var a := g.przygniecenie * 0.11 * (1.0 - i / 8.0)
				var m := vs * (0.02 + i * 0.03)
				draw_rect(Rect2(0, 0, vs.x, m.y), Color(0, 0, 0, a))
				draw_rect(Rect2(0, vs.y - m.y, vs.x, m.y), Color(0, 0, 0, a))
				draw_rect(Rect2(0, m.y, m.x, vs.y - 2 * m.y), Color(0, 0, 0, a))
				draw_rect(Rect2(vs.x - m.x, m.y, m.x, vs.y - 2 * m.y), Color(0, 0, 0, a))
		if g.bron.ma_lunete() and g.bron.ads > 0.85:
			_luneta(c, clampf((g.bron.ads - 0.85) / 0.15, 0.0, 1.0))
		if g.bron.ads > 0.6 and g.bron.podparcie > 0.6 and not g.bron.ma_lunete():
			draw_string(ThemeDB.fallback_font, c + Vector2(-34, 90), "podparta", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.82, 0.7, 0.55))
		if g.bron.ads < 0.5 and g.bron.przedmiot != null:
			draw_rect(Rect2(c - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.85, 0.82, 0.7, 0.7))
		if hud._znacznik > 0.0:
			var kz := Color(0.9, 0.15, 0.1, hud._znacznik) if hud._znacznik_zabity else Color(0.95, 0.92, 0.85, hud._znacznik)
			var r1 := 6.0
			var r2 := 13.0 if hud._znacznik_zabity else 10.0
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * r1, c + d * r2, kz, 2.0)
		if hud._trafienie > 0.0:
			var a: float = hud._trafienie_kier
			var p := c + Vector2(sin(a), -cos(a)) * 110.0
			var kol := Color(0.8, 0.1, 0.05, hud._trafienie)
			draw_line(p - Vector2(cos(a), sin(a)) * 26, p + Vector2(cos(a), sin(a)) * 26, kol, 4.0)


	## Nakładka lunety (PSO): czarne pole wokół okularu, siatka z szewronami i skalą boczną.
	func _luneta(c: Vector2, a: float) -> void:
		var vs := get_viewport_rect().size
		var r := minf(vs.x, vs.y) * 0.44
		var diag := vs.length()
		var czern := Color(0.0, 0.0, 0.0, a)
		var n := 72
		for i in n:
			var a0 := TAU * float(i) / n
			var a1 := TAU * float(i + 1) / n
			var d0 := Vector2(cos(a0), sin(a0))
			var d1 := Vector2(cos(a1), sin(a1))
			draw_colored_polygon(PackedVector2Array([c + d0 * r, c + d0 * diag, c + d1 * diag, c + d1 * r]), czern)
		draw_arc(c, r, 0.0, TAU, 128, Color(0.05, 0.05, 0.04, a), 6.0)
		draw_arc(c, r - 10.0, 0.0, TAU, 128, Color(0.0, 0.0, 0.0, a * 0.35), 18.0)
		var k := Color(0.05, 0.05, 0.04, a * 0.95)
		var ch := r * 0.035
		for i in 3:
			var y := float(i) * r * 0.16
			draw_line(c + Vector2(-ch, y + ch), c + Vector2(0, y), k, 2.0)
			draw_line(c + Vector2(ch, y + ch), c + Vector2(0, y), k, 2.0)
		draw_line(c + Vector2(0, r * 0.38), c + Vector2(0, r), k, 2.0)
		draw_line(c + Vector2(-r, 0), c + Vector2(-r * 0.3, 0), k, 2.0)
		for i in range(1, 6):
			var x := r * 0.3 + float(i) * r * 0.1
			draw_line(c + Vector2(-x, 0), c + Vector2(-x, -r * 0.03), k, 1.5)
			draw_line(c + Vector2(x, 0), c + Vector2(x, -r * 0.03), k, 1.5)
		draw_line(c + Vector2(r * 0.3, 0), c + Vector2(r, 0), k, 2.0)


## Kompas (gdy jest na slocie wyposażenia): pasek kierunków, przy liście [O] także znaczniki wyjść.
class Kompas:
	extends Control
	var hud

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var g: Gracz = hud.gracz
		if g == null:
			return
		var f := Motyw.mono_b()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		# kierunek patrzenia: 0 = północ (-Z)
		var przod := -g.global_basis.z
		var azymut := fposmod(rad_to_deg(atan2(przod.x, -przod.z)), 360.0)
		var px_na_stopien := size.x / 120.0
		for st in range(0, 360, 15):
			var dlt := wrapf(float(st) - azymut, -180.0, 180.0)
			if absf(dlt) > 60.0:
				continue
			var x := size.x * 0.5 + dlt * px_na_stopien
			var nazwa: String = {0: "N", 90: "E", 180: "S", 270: "W"}.get(st, "")
			if nazwa != "":
				draw_string(f, Vector2(x - 5, 22), nazwa, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.85, 0.5) if nazwa == "N" else Motyw.TEKST)
			else:
				draw_line(Vector2(x, 4), Vector2(x, 12 if st % 45 else 16), Motyw.TEKST_CIEMNY, 1.0)
		draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, 6), Color(0.95, 0.4, 0.25), 2.0)
		if hud._wyjscia_t > 0.0 and hud.rajd:
			for w in hud.rajd.info["wyjscia"]:
				var d: Vector3 = (w as Node3D).global_position - g.global_position
				var az := fposmod(rad_to_deg(atan2(d.x, -d.z)), 360.0)
				var dl := wrapf(az - azymut, -180.0, 180.0)
				if absf(dl) <= 60.0:
					var x2 := size.x * 0.5 + dl * px_na_stopien
					draw_rect(Rect2(x2 - 3, size.y - 7, 6, 6), Motyw.ZIELEN)


## Pasek szybkiego dostępu: [1] broń główna, [2] pistolet, [3] latarka, [4-9] leki z kamizelki i kieszeni.
class Pasek:
	extends Control
	var hud
	const S := 46.0
	const ODST := 6.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var g: Gracz = hud.gracz
		if g == null or g.cialo.martwy:
			return
		var wpisy := []
		wpisy.append([1, g.ekw.sloty["glowna"].id if g.ekw.sloty["glowna"] else "", 0, g.bron.przedmiot != null and g.bron.przedmiot == g.ekw.sloty["glowna"]])
		wpisy.append([2, g.ekw.sloty["pistolet"].id if g.ekw.sloty["pistolet"] else "", 0, g.bron.przedmiot != null and g.bron.przedmiot == g.ekw.sloty["pistolet"]])
		wpisy.append([3, "latarka" if not not g.ekw.ma_wyposazenie("latarka") else "", 0, g.latarka_w_rece])
		var pasek: Array = g.ekw.pasek()
		for i in 6:
			if i < pasek.size():
				wpisy.append([i + 4, pasek[i]["id"], pasek[i]["ilosc"], false])
			else:
				wpisy.append([i + 4, "", 0, false])
		var szer := wpisy.size() * S + (wpisy.size() - 1) * ODST + 10.0
		var x := (size.x - szer) * 0.5
		var f := Motyw.mono_b()
		for i in wpisy.size():
			var w: Array = wpisy[i]
			if i == 3:
				x += 10.0   # przerwa między bronią a lekami
			var r := Rect2(x, 0, S, S)
			var pusty: bool = w[1] == ""
			draw_rect(r, Color(0.05, 0.05, 0.045, 0.55 if pusty else 0.78))
			draw_rect(r, Color(0.86, 0.72, 0.36) if w[3] else Color(0.35, 0.33, 0.28, 0.8), false, 2.0 if w[3] else 1.0)
			if not pusty:
				var tex: Texture2D = Dane.ikona(w[1])
				if tex:
					var ts := tex.get_size()
					var sk := minf((S - 8.0) / ts.x, (S - 8.0) / ts.y)
					var rozm := ts * sk
					draw_texture_rect(tex, Rect2(r.position + (r.size - rozm) * 0.5, rozm), false)
				if int(w[2]) > 1:
					draw_string(f, r.position + Vector2(S - 16, S - 4), "x%d" % int(w[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.92, 0.8))
			draw_string(f, r.position + Vector2(3, 12), str(w[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.86, 0.72, 0.36) if not pusty else Color(0.4, 0.38, 0.33))
			x += S + ODST


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
