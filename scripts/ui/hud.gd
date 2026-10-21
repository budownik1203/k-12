extends CanvasLayer
## HUD rajdu: minimalny. Kropka celownika, stan ciała, broń i tryb (bez licznika naboi),
## wytrzymałość, waga i hałas, podpowiedź interakcji, postęp akcji, komunikaty, napisy wrogów,
## stan wyjść na mapie [O], czas na zegarku [H], odliczanie ewakuacji.

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
	_mapa = MapaStrefy.new()
	_mapa.hud = self
	_mapa.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_mapa.offset_left = -470
	_mapa.offset_right = -24
	_mapa.offset_top = -170
	_mapa.offset_bottom = 170
	_mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mapa.visible = false
	_root.add_child(_mapa)
	_napisy = VBoxContainer.new()
	_napisy.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_napisy.offset_left = -300
	_napisy.offset_right = 300
	_napisy.offset_top = -78
	_napisy.offset_bottom = -54
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
	_pomoc.offset_left = -360
	_pomoc.offset_right = 360
	_pomoc.offset_top = -250
	_pomoc.offset_bottom = 250
	_pomoc.add_theme_stylebox_override("panel", Motyw.styl_kieszeni(true))
	var lp := Motyw.etykieta("\n".join([
		"STEROWANIE",
		"WSAD · Shift bieg · Ctrl kucanie · Spacja skok · Q/E wychylenie",
		"LPM strzał · PPM celowanie · R przeładowanie (przytrzymaj: szybkie)",
		"B tryb ognia · T sprawdź magazynek",
		"1 broń główna · 2 pistolet (2x: z latarką) · 3 sama latarka · L latarka wł/wył",
		"4–9 leki z kamizelki i kieszeni · X przerwij leczenie/napełnianie",
		"F interakcja · przytrzymaj F + mysz: drzwi, skrzynie, beczki (ręką)",
		"Z ciągnij ciało · Alt ostrożny krok · V broń nisko · J obejrzyj broń",
		"Tab ekwipunek · G granat / napełnianie · O mapa · H zegarek (czas, zdrowie)",
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
	komunikat("Zegarek: [H] (czas, zdrowie). Mapa: [O]. Ekwipunek: [Tab]. Sterowanie: [F1].")
	Gra.wskazowka("start", "WSAD – ruch, Shift – bieg, Ctrl – kucanie, F – interakcja (przytrzymaj F – chwyt: drzwi, skrzynie), Tab – ekwipunek, H – zegarek, F1 – pełne sterowanie. Wyjdź żywy przez jedno z wyjść – łup przepada razem z tobą.")
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
	_wskazowki(delta)
	if gracz == null:
		return
	_odswiez(delta)
	_ukryj_przy_ekranie()


func _odswiez(delta: float) -> void:
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
		elif b.stan == "ladowanie_wewn" or b.stan == "lamanie":
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
	_interakcja.text = (("" if "[F]" in gracz.tekst_interakcji else "[F]  ") + gracz.tekst_interakcji) if gracz.tekst_interakcji != "" and not Sterowanie.blokada else ""
	# akcja: kółko pod celownikiem (w ekwipunku kółko jest przy kursorze)
	if not Sterowanie.blokada and not gracz.akcja.get("mapa", false) and not gracz.akcja.get("ciagniecie", false):
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
		# zegarek w ekwipunku: dokładny czas; bez niego – na oko (co 5 minut, po świetle i zmęczeniu)
		_zeg_t -= delta
		if _zeg_t <= 0.0:
			_zeg_t = 1.0
			_ma_zegarek = gracz.ekw.ma_przedmiot("zegarek")
		if _ma_zegarek:
			_czas.text = "RAJD %d:%02d" % [int(t) / 60, int(t) % 60]
		else:
			_czas.text = "bez zegarka: w strefie ok. %d min" % maxi(5, int(round(t / 300.0)) * 5)
		# wyjścia
		# bez pływającej listy: czas rajdu i okna wyjść widać na zegarku ([H]), stan wyjść – na mapie w rękach ([O])
		var na_zegarku: bool = gracz.bron != null and float(gracz.bron.get("_zegarek")) > 0.85
		_wyjscia_t = 0.0
		_czas.visible = na_zegarku
		if _mapa:
			# plan widać tylko z mapą w rękach (wyjęcie trwa; z bronią w rękach nic nie widać)
			_mapa.visible = bool(gracz.akcja.get("mapa", false)) and float(gracz.akcja.get("t", 0.0)) > 0.75
			if _mapa.visible:
				_wyjscia_t = 0.2
				_mapa.queue_redraw()
		if _wyjscia_t > 0.0 or na_zegarku:
			var linie := ["WYJŚCIA ZE STREFY:" if _wyjscia_t > 0.0 else "OKNA CZASOWE:"]
			for w in rajd.info["wyjscia"]:
				var ew: Ewakuacja = w
				# bez kierunku i odległości: drogę trzeba znać (strzałki na ścianach, mapa w rękach, kompas)
				if _wyjscia_t > 0.0 or ew.typ == "czasowe":
					linie.append("%s — %s" % [ew.nazwa, _opis_wyjscia(ew)])
			_wyjscia.text = "\n".join(linie) if linie.size() > 1 else ""
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
		_kula_t = maxf(0.0, _kula_t - delta * 4.0)
		var stres: float = gracz.stres
		_mat.set_shader_parameter("rozmycie_bol", maxf(maxf(1.2 if c.bol() else (_trafienie * 2.0), minf(3.0, gracz.oglusz * 1.2)), _kula_t * _kula_sila * 2.2 + maxf(0.0, stres - 0.6) * 1.2))
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


var _wsk: PanelContainer
var _wsk_lbl: Label
var _wsk_kolejka: Array = []
var _wsk_t := 0.0
var _fps: Label


## Wskazówka samouczka: ramka nad paskiem szybkiego dostępu, kilka sekund, po kolei.
func pokaz_wskazowke(t: String) -> void:
	_wsk_kolejka.append(t)


## Przy otwartym ekwipunku, łupie czy wytrychu wskaźniki HUD-u (broń, pasek, wyjścia, celownik, wskazówki)
## znikają – nie nakładają się na rozłożone pojemniki i podpisy. Komunikaty zostają.
var _ekran_otwarty := false


func _ukryj_przy_ekranie() -> void:
	# ekran ekwipunku jest w grupie cały czas – liczy się tylko, gdy naprawdę otwarty (wytrych: gdy widoczny)
	var ekran := get_tree().get_nodes_in_group("ekran_ekwipunku").any(func(n): return bool(n.get("otwarty")) if "otwarty" in n else (n is CanvasItem and (n as CanvasItem).visible) or (n is CanvasLayer and (n as CanvasLayer).visible))
	for n in [_bron, _pasek, _wyjscia, _czas, _kropka, _stan, _interakcja, _wytrz, _waga, _kompas, _odliczanie, _fps]:
		if n == null:
			continue
		if ekran:
			n.visible = false
		elif _ekran_otwarty and n in [_bron, _pasek, _wyjscia, _kropka, _stan, _interakcja, _odliczanie]:
			n.visible = true
	_ekran_otwarty = ekran


func _wskazowki(delta: float) -> void:
	if _wsk == null:
		_wsk = PanelContainer.new()
		_wsk.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_wsk.offset_top = -190
		_wsk.offset_bottom = -92
		_wsk.offset_left = -330
		_wsk.offset_right = 330
		_wsk.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_wsk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.06, 0.06, 0.05, 0.86)
		st.border_color = Motyw.ZOLC
		st.border_width_left = 3
		st.content_margin_left = 12
		st.content_margin_right = 12
		st.content_margin_top = 8
		st.content_margin_bottom = 8
		_wsk.add_theme_stylebox_override("panel", st)
		_wsk_lbl = Label.new()
		_wsk_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_wsk_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wsk_lbl.add_theme_font_override("font", Motyw.cond())
		_wsk_lbl.add_theme_font_size_override("font_size", 15)
		_wsk_lbl.add_theme_color_override("font_color", Motyw.TEKST)
		_wsk.add_child(_wsk_lbl)
		_wsk.visible = false
		_root.add_child(_wsk)
	if _ekran_otwarty:
		# wskazówka czeka, aż ekran się zamknie
		_wsk.visible = false
	elif _wsk_t > 0.0:
		_wsk.visible = true
		_wsk_t -= delta
		_wsk.modulate.a = clampf(_wsk_t / 0.6, 0.0, 1.0)
		if _wsk_t <= 0.0:
			_wsk.visible = false
	elif not _wsk_kolejka.is_empty():
		_wsk_lbl.text = "WSKAZÓWKA · " + String(_wsk_kolejka.pop_front())
		_wsk.visible = true
		_wsk.modulate.a = 1.0
		_wsk_t = 9.0
	# licznik klatek
	if bool(Gra.ustawienia.get("pokaz_fps", false)):
		if _fps == null:
			_fps = _lbl(Vector2(8, 4), 12, Motyw.TEKST_CIEMNY, Control.PRESET_TOP_LEFT)
			_fps.position = Vector2(8, 100)
		_fps.visible = true
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	elif _fps:
		_fps.visible = false


var _ramka_cel: Object = null
var _ramka_aabb := AABB()


## Prostokąt na ekranie obejmujący obiekt, na który patrzy gracz (do podświetlenia interakcji).
func ramka_celu() -> Rect2:
	var cel = gracz.cel_interakcji if gracz else null
	if cel == null or not is_instance_valid(cel) or not (cel is Node3D) or gracz.tekst_interakcji == "":
		return Rect2()
	var n := cel as Node3D
	if cel != _ramka_cel:
		_ramka_cel = cel
		_ramka_aabb = AABB()
		var pierwszy := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			_ramka_aabb = a if pierwszy else _ramka_aabb.merge(a)
			pierwszy = false
		if pierwszy:
			_ramka_aabb = AABB(n.global_position - Vector3(0.25, 0, 0.25), Vector3(0.5, 1.6, 0.5))
		_ramka_aabb = AABB(n.global_transform.affine_inverse() * _ramka_aabb.position, _ramka_aabb.size)
	var kam := gracz.kamera
	var vp := kam.get_viewport()
	var skala := Vector2.ONE
	if vp is SubViewport:
		var kont := vp.get_parent() as Control
		if kont:
			skala = Widok3D.skala_ekranu(vp)
	# AABB zapamiętany w układzie obiektu (drzwi się obracają, ale ramka i tak przybliżona)
	var ab := _ramka_aabb
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in 8:
		var p := n.global_transform * (ab.position + Vector3(ab.size.x * (i & 1), ab.size.y * ((i >> 1) & 1), ab.size.z * ((i >> 2) & 1)))
		if kam.is_position_behind(p):
			return Rect2()
		var sp := kam.unproject_position(p) * skala
		mn = mn.min(sp)
		mx = mx.max(sp)
	var r := Rect2(mn, mx - mn).grow(4.0)
	var ekran := Rect2(Vector2.ZERO, _root.size)
	if r.size.x > ekran.size.x * 0.8 or r.size.y > ekran.size.y * 0.9:
		return Rect2()
	return r


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
	l.add_theme_font_size_override("font_size", 14)
	# jeden okrzyk naraz, przy dolnej krawędzi – nowy zastępuje stary (bez stosu napisów na środku)
	for c in _napisy.get_children():
		_napisy.remove_child(c)
		c.queue_free()
	_napisy.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.2)
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
	# bez znacznika i bez „kliku” trafienia: o skutku mówi tylko cel (drgnięcie, krzyk, upadek)
	pass


## Kula tuż obok głowy: smuga przez kadr, krótkie rozmycie i szarpnięcie obrazu.
var _kula_a := Vector3.ZERO
var _kula_b := Vector3.ZERO
var _kula_t := 0.0
var _kula_sila := 0.0


func blisko_kuli(a: Vector3, b: Vector3, sila: float) -> void:
	_kula_a = a
	_kula_b = b
	_kula_t = 1.0
	_kula_sila = clampf(sila, 0.2, 1.0)


func _trafiony(kier: Vector3, _czesc: String) -> void:
	_trafienie = 1.0
	var lok := gracz.global_basis.inverse() * kier
	_trafienie_kier = atan2(lok.x, -lok.z)


var _mapa: MapaStrefy
var _zeg_t := 0.0
var _ma_zegarek := false


## Stan wyjścia; okno czasowe dokładnie tylko z zegarkiem, bez niego z grubsza.
func _opis_wyjscia(ew: Ewakuacja) -> String:
	if ew.typ != "czasowe" or _ma_zegarek:
		return ew.opis_stanu()
	var tt: float = ew.rajd_czas
	if tt < ew.okno_od:
		return "jeszcze nie (za ok. %d min)" % maxi(5, int(round((ew.okno_od - tt) / 300.0)) * 5)
	if tt <= ew.okno_do:
		return "chyba teraz – bez zegarka nie wiesz, jak długo"
	return "chyba już po"


## Szkic planu z mapy strefy ([O] z mapą na slocie wyposażenia): kondygnacja gracza, odwiedzone pomieszczenia
## zamalowane, wyjścia, widziane strzałki (też te fałszywe – mapa nie wie, kto kłamie), znaki gracza, gracz z kierunkiem.
class MapaStrefy:
	extends Control
	var hud

	func _draw() -> void:
		var rajd = hud.rajd
		if rajd == null or rajd.gen == null:
			return
		var g: Node3D = hud.gracz
		var pietro := 1 if g.global_position.y > GeneratorBiomu.PIETRO_H - 0.6 else 0
		var gen: GeneratorBiomu = rajd.gen_p if pietro == 1 else rajd.gen
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		for k in gen.komorki:
			var r: Rect2 = gen.komorki[k]["rect"]
			mn = mn.min(r.position)
			mx = mx.max(r.end)
		var obszar := Rect2(Vector2(8, 26), size - Vector2(16, 34))
		var sk := minf(obszar.size.x / maxf(1.0, mx.x - mn.x), obszar.size.y / maxf(1.0, mx.y - mn.y))
		var off := obszar.position + (obszar.size - (mx - mn) * sk) * 0.5
		var na_ekran := func(p: Vector3) -> Vector2: return off + (Vector2(p.x, p.z) - mn) * sk
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.84, 0.8, 0.68, 0.93))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.2, 0.15), false, 2.0)
		draw_string(Motyw.mono_b(), Vector2(10, 18), "PLAN – %s" % ("PIĘTRO" if pietro == 1 else "PARTER"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.25, 0.2, 0.15))
		for k in gen.komorki:
			var r: Rect2 = gen.komorki[k]["rect"]
			var rr := Rect2(off + (r.position - mn) * sk, r.size * sk)
			if rajd.odwiedzone_k.has(Vector3i(k.x, k.y, pietro)):
				draw_rect(rr, Color(0.55, 0.48, 0.36, 0.55))
			draw_rect(rr, Color(0.3, 0.25, 0.2, 0.9), false, 1.0)
		var kol := {"brama": Color(0.95, 0.95, 0.9), "piwnica": Color(0.85, 0.7, 0.15), "okno": Color(0.75, 0.15, 0.1)}
		for w in rajd.info["wyjscia"]:
			var e := w as Ewakuacja
			if (e.global_position.y > GeneratorBiomu.PIETRO_H - 0.6) != (pietro == 1):
				continue
			var c: Color = kol["brama"] if e.nazwa.contains("Brama") else (kol["piwnica"] if e.nazwa.contains("Piwnica") else kol["okno"])
			var sp: Vector2 = na_ekran.call(e.global_position)
			draw_circle(sp, 6.0, Color(0.15, 0.12, 0.1))
			draw_circle(sp, 4.5, c)
		for i in rajd.widziane_strzalki:
			var ps: Array = Naklejki.pozycje[i]
			var pp: Vector3 = ps[0]
			if (pp.y > GeneratorBiomu.PIETRO_H - 0.6) != (pietro == 1):
				continue
			var nrm: Vector3 = ps[1]
			var prawo := Vector3.UP.cross(nrm).normalized() * (1.0 if String(ps[2]).ends_with("_p") else -1.0)
			var s0: Vector2 = na_ekran.call(pp)
			var kier := Vector2(prawo.x, prawo.z)
			var c2: Color = kol.get(String(ps[2]).split("_")[1], Color.WHITE)
			draw_line(s0 - kier * 5.0, s0 + kier * 5.0, c2.darkened(0.3), 2.0)
			draw_colored_polygon(PackedVector2Array([s0 + kier * 7.0, s0 + kier * 2.0 + kier.orthogonal() * 3.0, s0 + kier * 2.0 - kier.orthogonal() * 3.0]), c2.darkened(0.3))
		for z in Naklejki.znaki_gracza:
			var zp: Vector3 = z[0]
			if (zp.y > GeneratorBiomu.PIETRO_H - 0.6) != (pietro == 1):
				continue
			draw_circle(na_ekran.call(zp), 3.0, Color(0.92, 0.47, 0.11))
		var gp: Vector2 = na_ekran.call(g.global_position)
		var f := -g.global_basis.z
		var fv := Vector2(f.x, f.z).normalized()
		draw_colored_polygon(PackedVector2Array([gp + fv * 9.0, gp - fv * 5.0 + fv.orthogonal() * 5.0, gp - fv * 5.0 - fv.orthogonal() * 5.0]), Color(0.1, 0.35, 0.15))


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
		var ramka: Rect2 = hud.ramka_celu()
		if ramka.size.x > 2.0:
			# podświetlenie tego, z czym można coś zrobić: narożniki wokół
			var kz := Color(0.95, 0.88, 0.6, 0.55)
			var dl := clampf(minf(ramka.size.x, ramka.size.y) * 0.25, 5.0, 16.0)
			for nar in [[ramka.position, Vector2(1, 1)], [Vector2(ramka.end.x, ramka.position.y), Vector2(-1, 1)], [Vector2(ramka.position.x, ramka.end.y), Vector2(1, -1)], [ramka.end, Vector2(-1, -1)]]:
				var pp: Vector2 = nar[0]
				var kk: Vector2 = nar[1]
				draw_line(pp, pp + Vector2(kk.x * dl, 0), kz, 1.5)
				draw_line(pp, pp + Vector2(0, kk.y * dl), kz, 1.5)
		# (bez napisu „podparta” – podparcie czuć po tym, że broń przestaje się kołysać)
		# (kropka celownika usunięta – mierzy się przyrządami albo „z biodra” na wyczucie)
		# (znacznik trafienia usunięty – o trafieniu mówi tylko to, co widać i słychać)
		# ikonka przy celowniku: otwarta dłoń – można coś zrobić; zaciśnięta – można chwycić i przesunąć
		var rodz: String = g.rodzaj_celu
		if rodz != "" and g.bron.ads < 0.5:
			_ikona_dloni(c + Vector2(0, 18), rodz == "chwyt")
		if hud._kula_t > 0.0:
			# smuga kuli: odcinek toru rzutowany na ekran, jasny i szybko gasnący
			var kam := get_viewport().get_camera_3d()
			if kam == null and g.kamera:
				kam = g.kamera
			if kam:
				var a3: Vector3 = hud._kula_a
				var b3: Vector3 = hud._kula_b
				var srodek: Vector3 = kam.global_position
				var t0 := clampf((srodek - a3).dot(b3 - a3) / maxf((b3 - a3).length_squared(), 0.0001), 0.0, 1.0)
				var bliski := a3.lerp(b3, t0)
				var kier := (b3 - a3).normalized()
				var p1 := bliski - kier * 1.5
				var p2 := bliski + kier * 0.6
				if not kam.is_position_behind(p1) and not kam.is_position_behind(p2):
					var skala := Widok3D.skala_ekranu(kam.get_viewport()) if kam.get_viewport() is SubViewport else Vector2.ONE
					var s1 := kam.unproject_position(p1) * skala
					var s2 := kam.unproject_position(p2) * skala
					var al: float = hud._kula_t * hud._kula_sila
					draw_line(s1, s2, Color(1.0, 0.92, 0.7, al * 0.55), 2.5)
					draw_line(s1.lerp(s2, 0.5), s2, Color(1.0, 0.97, 0.85, al * 0.8), 1.2)
			draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.9, 0.88, 0.8, hud._kula_t * hud._kula_sila * 0.08))
		if hud._trafienie > 0.0:
			var a: float = hud._trafienie_kier
			var p := c + Vector2(sin(a), -cos(a)) * 110.0
			var kol := Color(0.8, 0.1, 0.05, hud._trafienie)
			draw_line(p - Vector2(cos(a), sin(a)) * 26, p + Vector2(cos(a), sin(a)) * 26, kol, 4.0)


	## Mała dłoń (12 px): otwarta (interakcja) albo zaciśnięta ze strzałkami (chwyć i przesuń).
	func _ikona_dloni(p: Vector2, chwyt: bool) -> void:
		var kol := Color(0.92, 0.88, 0.74, 0.85)
		var cien := Color(0, 0, 0, 0.5)
		for przes in [Vector2(1, 1), Vector2.ZERO]:
			var k: Color = cien if przes != Vector2.ZERO else kol
			var o: Vector2 = p + przes
			if chwyt:
				draw_rect(Rect2(o + Vector2(-5, -3), Vector2(10, 8)), k)
				for i in 4:
					draw_rect(Rect2(o + Vector2(-5 + i * 2.6, -5.5), Vector2(2.0, 3.0)), k)
				draw_rect(Rect2(o + Vector2(-7, -1), Vector2(2.5, 4)), k)
				# strzałki: przesuń
				draw_line(o + Vector2(-13, 1), o + Vector2(-9, 1), k, 1.5)
				draw_line(o + Vector2(-13, 1), o + Vector2(-11, -1), k, 1.5)
				draw_line(o + Vector2(-13, 1), o + Vector2(-11, 3), k, 1.5)
				draw_line(o + Vector2(9, 1), o + Vector2(13, 1), k, 1.5)
				draw_line(o + Vector2(13, 1), o + Vector2(11, -1), k, 1.5)
				draw_line(o + Vector2(13, 1), o + Vector2(11, 3), k, 1.5)
			else:
				draw_rect(Rect2(o + Vector2(-4, -1), Vector2(8, 7)), k)
				for i in 4:
					var h: float = [6.0, 7.5, 7.0, 5.5][i]
					draw_rect(Rect2(o + Vector2(-4 + i * 2.2, -1 - h), Vector2(1.6, h)), k)
				draw_line(o + Vector2(-4, 3), o + Vector2(-7, -1), k, 1.8)


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


## Kompas (gdy jest na slocie wyposażenia): pasek kierunków, z mapą w rękach także znaczniki wyjść (mapa + kompas = namiar).
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
