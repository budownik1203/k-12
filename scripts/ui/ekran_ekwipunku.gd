extends CanvasLayer
## Ekran ekwipunku: sloty na ciele, kieszenie, kamizelka, plecak, stan zdrowia i waga,
## plus prawy panel: przeszukiwany pojemnik (rajd) albo skrytka (baza).
## Przeciąganie myszą, R obraca, Ctrl+klik przenosi szybko, PPM menu, G napełnia magazynki.

signal zamkniety

var gracz: Gracz                # może być null (np. w testach)
var ekw: Ekwipunek
var tryb_bazy := false
var otwarty := false

var _root: Control
var _lewy: VBoxContainer
var _srodek: VBoxContainer
var _prawy: VBoxContainer
var _prawy_tytul: Label
var _prawy_scroll: ScrollContainer
var _info_zdrowie: VBoxContainer
var _info_waga: Label
var _info_bony: Label
var _tooltip: PanelContainer
var _tooltip_txt: RichTextLabel
var _menu: PopupMenu
var _menu_p: Przedmiot
var _menu_zrodlo := {}
var _kolko: KolkoPostepu
var _panel_ciala: PanelCiala
var _opis_ciala: Label
var _panele: Array[Control] = []
var _hover_p: Przedmiot = null
var _seria_mag := false        # napełnianie wszystkich magazynków po kolei
## Otwarte pojemniki na środku (kolejność otwierania): kieszenie, kamizelka, plecak, bezpieczny.
var otwarte: Array = []
var _otwieranie := ""          # pojemnik w trakcie otwierania (czas, animacja)
var _otw_t := 0.0
var _otw_czas := 0.0
var _kolko_otw: KolkoPostepu
var _swiezy := ""              # właśnie otwarty pojemnik: jego ramka dostaje animację wejścia
var _ramki := {}               # pojemnik -> ramka na środku
var _zamykany := ""
var _r3d: Rozlozenie3D = null    # rajd: pojemniki rozłożone w świecie przed graczem
var _warstwa: Control            # rajd: siatki pojemników nad ich modelami 3D
var _szybki := false             # 2x Tab: tylko kamizelka (szybki dostęp)
var _pokaz_ms := 0
var _kolko_otw_poz := Vector2.ZERO
var _warsztat := false          # otwarte przy stole roboczym: wolno montować dodatki warsztatowe
var _tlo: TextureRect
var _lp: PanelContainer
var _sp: PanelContainer
var _pp: PanelContainer
var _ss: ScrollContainer
var _rzad: HBoxContainer
var _gora: HBoxContainer
var _dol: HBoxContainer
var _odstep_g: Control
var _odstep_d: Control
var _siatki: Array[SiatkaUI] = []
var _sloty: Array[SlotUI] = []

var _drag := {}                  # {"p", "z": źródło, "off": Vector2, "rot": bool}
var _pojemnik: Pojemnik = null
var _szukanie_t := 0.0
var _prawa_siatka: Siatka = null
var _prawa_ui: SiatkaUI = null
var _ramka_poj: PanelContainer = null   # rajd: siatka przeszukiwanego pojemnika nad jego wnętrzem w świecie
var _etyk_szuk: Label = null
var _prawe_ui: Array = []      # [SiatkaUI, indeks części pojemnika]
var _swiatlo_szuk := -1.0
## Przekładanie trwa (rajd): ręka przenosi przedmiot – czas wg rozmiaru i wagi; Ctrl+klik ustawia kolejkę.
var _kolejka: Array = []       # [{"p", "z"}]
var _zajete_t := 0.0
var _zajete_calk := 0.0
var _kolko_przel: KolkoPostepu
var _ucieczka_t := 0.0
## Kieszenie zdjętego plecaka / wyjętego kontenera (rajd): co -> [{"r", "nazwa", "otwarta", "w_toku"}]
var _kieszenie := {}
## Przenoszenie ręką (rajd): dłoń bierze przedmiot i odkłada; dopóki nie skończy – czekasz.
var _przekl := {}               # {"p", "z", "wykonaj": Callable, "dz": bool}
var _duch: TextureRect           # przekładany przedmiot w drodze (ikona)
var _podp_ucieczka: Label


func _ready() -> void:
	layer = 20
	add_to_group("ekran_ekwipunku")
	ekw = Gra.ekw
	_buduj()
	_root.visible = false
	ekw.zmieniony.connect(_odswiez)
	_ogl_ui = load("res://scripts/ui/ogladanie_broni.gd").new()
	_ogl_ui.ekran = self
	_ogl_ui.gracz = gracz
	add_child(_ogl_ui)


func _buduj() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = Motyw.motyw()
	add_child(_root)
	# wnętrze rozpiętego oporządzenia: płótno na całym ekranie, przyciemnione brzegi
	var tlo := TextureRect.new()
	_tlo = tlo
	tlo.texture = Motyw.tekstura("plotno")
	tlo.stretch_mode = TextureRect.STRETCH_TILE
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	tlo.mouse_filter = Control.MOUSE_FILTER_STOP
	tlo.modulate = Color(1, 1, 1, 0)   # bez tła: łapie tylko mysz (upuszczenie poza celami = wyrzuć)
	_root.add_child(tlo)
	var cien := ColorRect.new()
	cien.set_anchors_preset(Control.PRESET_FULL_RECT)
	cien.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ vec2 q = UV - 0.5; COLOR = vec4(0.0, 0.0, 0.0, 0.18 + 0.4 * smoothstep(0.1, 0.6, dot(q, q) * 1.6)); }"
	sm.shader = sh
	cien.material = sm
	_root.add_child(cien)
	var marg := MarginContainer.new()
	marg.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		marg.add_theme_constant_override("margin_" + s, 24)
	_root.add_child(marg)
	var kol := VBoxContainer.new()
	marg.add_child(kol)
	var gora := HBoxContainer.new()
	gora.add_child(Motyw.naszywka("Oporządzenie operatora  ·  K-12/E", 14))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gora.add_child(spacer)
	_info_bony = Motyw.etykieta("", 16, Motyw.ZOLC, Motyw.mono_b())
	gora.add_child(_info_bony)
	kol.add_child(gora)
	_gora = gora
	_odstep_g = Control.new()
	_odstep_g.visible = false
	kol.add_child(_odstep_g)
	var rzad := HBoxContainer.new()
	_rzad = rzad
	rzad.alignment = BoxContainer.ALIGNMENT_CENTER
	rzad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rzad.add_theme_constant_override("separation", 18)
	kol.add_child(rzad)
	# lewy: sloty i zdrowie
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", RamkaStyl.new())
	lp.custom_minimum_size = Vector2(350, 0)
	rzad.add_child(lp)
	_lp = lp
	_panele.append(lp)
	_lewy = VBoxContainer.new()
	_lewy.add_theme_constant_override("separation", 6)
	lp.add_child(_lewy)
	# środek: otwarte pojemniki, każdy we własnej ramce; w rajdzie na środku ekranu
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	sp.custom_minimum_size = Vector2(340, 0)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tryb_bazy:
		rzad.add_child(sp)
	else:
		var odst := Control.new()
		odst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		odst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rzad.add_child(odst)
		sp.anchor_left = 0.5
		sp.anchor_right = 0.5
		sp.anchor_bottom = 1.0
		sp.offset_left = -185
		sp.offset_right = 185
		sp.offset_top = 64
		sp.offset_bottom = -44
	_sp = sp
	_panele.append(sp)
	var ss := ScrollContainer.new()
	ss.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ss.mouse_filter = Control.MOUSE_FILTER_PASS
	sp.add_child(ss)
	_ss = ss
	_srodek = VBoxContainer.new()
	_srodek.add_theme_constant_override("separation", 10)
	_srodek.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ss.add_child(_srodek)
	# prawy: pojemnik / skrytka
	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", RamkaStyl.new(true))
	if tryb_bazy:
		pp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		pp.custom_minimum_size = Vector2(330, 0)
	rzad.add_child(pp)
	_pp = pp
	_panele.append(pp)
	_prawy = VBoxContainer.new()
	pp.add_child(_prawy)
	_prawy_tytul = Motyw.naglowek("")
	_prawy_tytul.add_theme_color_override("font_color", Color(0.86, 0.8, 0.6))
	_prawy.add_child(_prawy_tytul)
	_prawy_scroll = ScrollContainer.new()
	_prawy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prawy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_prawy.add_child(_prawy_scroll)
	# dół: podpowiedzi i pasek postępu
	_odstep_d = Control.new()
	_odstep_d.visible = false
	kol.add_child(_odstep_d)
	var dol := HBoxContainer.new()
	_dol = dol
	var podp := Motyw.etykieta("[LPM] przeciągnij (też z ziemi i na ziemię pod kursorem; lek na ciało = lecz; dodatek na broń = montaż)  [R] obróć  [Ctrl+LPM] przenieś  [Shift+LPM] podziel  [PPM] menu  [Del] wyrzuć  [G] napełnij  [X] przerwij  [Tab] zamknij", 12, Motyw.TEKST_CIEMNY, Motyw.mono())
	podp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	podp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	podp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# obrys – pasek klawiszy czytelny także nad modelem plecaka/kamizelki w tle
	podp.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.03, 0.9))
	podp.add_theme_constant_override("outline_size", 4)
	dol.add_child(podp)
	kol.add_child(dol)
	if not tryb_bazy:
		_root.add_child(sp)
		sp.visible = false
		_warstwa = Control.new()
		_warstwa.set_anchors_preset(Control.PRESET_FULL_RECT)
		_warstwa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_warstwa)
	# tooltip i menu
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.custom_minimum_size = Vector2(300, 0)
	_tooltip.visible = false
	_tooltip_txt = RichTextLabel.new()
	_tooltip_txt.bbcode_enabled = true
	_tooltip_txt.fit_content = true
	_tooltip_txt.custom_minimum_size = Vector2(290, 0)
	_tooltip_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_txt.add_theme_font_override("normal_font", Motyw.cond())
	_tooltip_txt.add_theme_font_override("bold_font", Motyw.mono_b())
	_tooltip_txt.add_theme_font_size_override("normal_font_size", 14)
	_tooltip_txt.add_theme_font_size_override("bold_font_size", 15)
	_tooltip.add_child(_tooltip_txt)
	_root.add_child(_tooltip)
	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_menu_akcja)
	_root.add_child(_menu)
	var duch := Duch.new()
	duch.ekran = self
	_root.add_child(duch)
	_kolko = KolkoPostepu.new()
	_kolko.visible = false
	_root.add_child(_kolko)


# ------------------------------------------------------------------ otwieranie

const NAZWY_POJ := {"kieszenie": "Kieszenie", "kamizelka": "Kamizelka", "plecak": "Plecak", "bezpieczny": "Kontener bezpieczny"}
## Czas otwarcia w rajdzie: sięgnięcie do kieszeni, spojrzenie w dół na ładownice, zdjęcie i rozpięcie plecaka.
const CZAS_OTW := {"kieszenie": 0.25, "kamizelka": 0.4, "plecak": 1.4, "bezpieczny": 0.9}


func _siatka_pojemnika(co: String) -> Siatka:
	match co:
		"kieszenie": return ekw.kieszenie
		"kamizelka": return ekw.siatka_kamizelki()
		"plecak": return ekw.siatka_plecaka()
		"bezpieczny": return ekw.bezpieczny
	return null


## Otwiera (albo zamyka, jeśli otwarty) pojemnik na środku ekranu. W rajdzie trwa to chwilę i rusza kamerą.
func przelacz_pojemnik(co: String) -> void:
	if co in otwarte:
		if _zamykany != "":
			return
		Dzwiek.graj("plecak", -12.0, 1.3)
		var r: Control = _ramki.get(co)
		var dokoncz := func():
			_zamykany = ""
			otwarte.erase(co)
			_ustaw_widok()
			_przebuduj()
		if r == null or not is_instance_valid(r) or not r.is_visible_in_tree():
			dokoncz.call()
			return
		_zamykany = co
		if _r3d:
			var otw := 0
			_r3d.zamknij(co, 0.5)
			_kieszenie.erase(co)
			var twr := r.create_tween()
			twr.tween_property(r, "modulate:a", 0.0, 0.12)
			twr.tween_interval(0.35 + otw * 0.3)
			twr.tween_callback(dokoncz)
			if co in ["plecak", "bezpieczny"]:
				gracz.komunikat.emit("Zapinasz kieszenie i zakładasz plecak..." if co == "plecak" else "Zamykasz i chowasz kontener...")
			return
		r.pivot_offset = Vector2(r.size.x * 0.5, 0.0 if co == "plecak" else r.size.y)
		var tw := r.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(r, "modulate:a", 0.0, 0.16)
		if co == "plecak":
			tw.tween_property(r, "scale:y", 0.05, 0.18)
		else:
			tw.tween_property(r, "position:y", r.position.y + 50.0, 0.16)
		tw.chain().tween_callback(dokoncz)
		return
	if _otwieranie != "" or _siatka_pojemnika(co) == null:
		if _siatka_pojemnika(co) == null:
			_komunikat("Nie masz: " + NAZWY_POJ[co].to_lower())
		return
	var czas: float = 0.0 if (tryb_bazy or gracz == null) else float(CZAS_OTW[co])
	if czas <= 0.0:
		otwarte.append(co)
		_swiezy = co
		_przebuduj()
		return
	if _szybki and co == "kamizelka":
		czas = 0.22
	if co == "plecak" and czas > 0.0:
		# pełny plecak zdejmuje się i kładzie wolniej (i głośniej)
		var m := _siatka_pojemnika(co).masa()
		czas += clampf(m * 0.06, 0.0, 1.4)
		if m > 12.0:
			gracz.komunikat.emit("Ciężki plecak – zdejmujesz go powoli")
			Gra.emituj_halas(gracz.global_position, 6.0 + m * 0.2, gracz)
	_otwieranie = co
	_otw_t = 0.0
	_otw_czas = czas
	if gracz and co != "kamizelka":
		gracz.ruch_z_ekwipunkiem = false
	if _r3d:
		_r3d.otworz(co, _siatka_pojemnika(co), czas)
		_r3d.ustaw_stan(co, ekw.stan_kieszeni(co))
	if co in ["kamizelka", "plecak", "bezpieczny"]:
		var na_ziemi := co != "kamizelka" or "plecak" in otwarte or "bezpieczny" in otwarte
		gracz.widok_ekwipunku("plecak" if na_ziemi else "kamizelka")
	Dzwiek.graj("plecak", -6.0 if co == "plecak" else -11.0, 0.8 if co == "plecak" else 1.1)
	if co == "plecak":
		Gra.emituj_halas(gracz.global_position, 4.0, gracz)
	_przebuduj()


## 2x Tab w rajdzie: szybki dostęp do kamizelki (zerknięcie w dół, bez panelu oporządzenia).
func szybka_kamizelka() -> void:
	_szybki = true
	if gracz:
		gracz.ruch_z_ekwipunkiem = true
	_lp.visible = false
	_gora.visible = false
	if not "kamizelka" in otwarte and _otwieranie == "":
		przelacz_pojemnik("kamizelka")


func _ustaw_widok() -> void:
	if gracz == null or tryb_bazy:
		return
	var poza := "plecak" if ("plecak" in otwarte or "bezpieczny" in otwarte) else ("kamizelka" if "kamizelka" in otwarte else "")
	gracz.widok_ekwipunku(poza)


func _domyslnie_otwarte() -> Array:
	return ["kieszenie", "kamizelka", "plecak", "bezpieczny"] if tryb_bazy else []


func otworz(pojemnik: Pojemnik = null) -> void:
	_pojemnik = pojemnik
	_podswietl_pojemnik(true)
	_prawa_siatka = pojemnik.siatka if pojemnik else null
	_szukanie_t = 0.0
	_pokaz()
	if pojemnik != null and gracz and not tryb_bazy:
		gracz.bron.animacja_akcji("schowaj")   # obie ręce w szafce / przy zwłokach


## Lekka poświata przeszukiwanych zwłok (całe ciało) albo mebla – widać, co jest przeszukiwane.
func _podswietl_pojemnik(wl: bool) -> void:
	if _pojemnik == null or not is_instance_valid(_pojemnik) or tryb_bazy:
		return
	var cel: Node = _pojemnik.get_meta("ragdoll") if _pojemnik.has_meta("ragdoll") else _pojemnik
	if cel == null or not is_instance_valid(cel):
		return
	Rozlozenie3D.nakladka(cel, Rozlozenie3D.mat_lekki() if wl else null)


func otworz_skrytke() -> void:
	_pojemnik = null
	_prawa_siatka = Gra.skrytka
	_pokaz()


func _pokaz() -> void:
	if not otwarty:
		otwarte = _domyslnie_otwarte()
		_otwieranie = ""
		_szybki = false
		_pokaz_ms = Time.get_ticks_msec()
		_lp.visible = true
		_gora.visible = true
		if not tryb_bazy and gracz and _r3d == null:
			_r3d = Rozlozenie3D.new()
			gracz.get_parent().add_child(_r3d)
			_r3d.przygotuj(gracz)
	otwarty = true
	_root.visible = true
	get_tree().call_group("hud", "ukryj", true)
	# otwarcie: rozpinany plecak wjeżdża od dołu
	_root.modulate.a = 0.0
	_root.position.y = 26.0
	var tw := _root.create_tween().set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, 0.14)
	tw.tween_property(_root, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Sterowanie.blokada = true
	Sterowanie.przechwyc(false)
	_przebuduj()
	Dzwiek.graj("plecak", -8.0)


var _chowanie := false
var _ogl_ui


## Zamknięcie z pakowaniem: najpierw trzeba zapiąć i założyć plecak, schować kontener, puścić kamizelkę
## (tyle trwa, ile ich jest otwartych); dopiero potem ekran znika i rusza ewentualna czynność `po`.
func zamknij_animowany(po := Callable()) -> void:
	if not otwarty:
		if po.is_valid():
			po.call()
		return
	if _chowanie:
		return
	var czas := 0.0
	if gracz and not tryb_bazy:
		if "plecak" in otwarte:
			czas += 0.95
			if ekw.siatka_plecaka():
				czas += clampf(ekw.siatka_plecaka().masa() * 0.05, 0.0, 1.2)
		if "bezpieczny" in otwarte:
			czas += 0.55
		if "kamizelka" in otwarte and czas == 0.0:
			czas = 0.3
		if _otwieranie != "":
			czas = maxf(czas, 0.4)
	if czas <= 0.0:
		zamknij()
		if po.is_valid():
			po.call()
		return
	_chowanie = true
	_upusc_drag(true)
	_menu.hide()
	_tooltip.visible = false
	_root.visible = false
	if gracz:
		var co := []
		if "bezpieczny" in otwarte:
			co.append("kontener")
		if "plecak" in otwarte:
			co.append("plecak")
		if not co.is_empty():
			gracz.komunikat.emit("Pakujesz " + " i ".join(co) + "...")
	if _r3d:
		_r3d.zamknij_wszystko(czas * 0.9)
		_r3d = null
	if "plecak" in otwarte:
		Dzwiek.graj("plecak", -8.0, 1.1)
	get_tree().create_timer(czas).timeout.connect(func():
		_chowanie = false
		zamknij()
		if po.is_valid():
			po.call())


## Czynność wymagająca obu rąk (napełnianie, leczenie) z otwartego ekwipunku: najpierw schowaj sprzęt.
func _po_schowaniu(cb: Callable) -> void:
	if otwarty and not tryb_bazy and gracz:
		zamknij_animowany(cb)
	else:
		cb.call()
		_odswiez()


func zamknij() -> void:
	if _lup_hover and is_instance_valid(_lup_hover):
		Rozlozenie3D.nakladka(_lup_hover, null)
	_lup_hover = null
	if _kursor != Input.CURSOR_ARROW:
		_kursor = Input.CURSOR_ARROW
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if not otwarty:
		return
	_upusc_drag(true)
	otwarty = false
	_root.visible = false
	get_tree().call_group("hud", "ukryj", false)
	_menu.hide()
	_tooltip.visible = false
	Sterowanie.blokada = false
	Sterowanie.przechwyc(true)
	_podswietl_pojemnik(false)
	if _pojemnik != null and is_instance_valid(_pojemnik):
		_pojemnik.zamknij_mebel()
		if gracz and not tryb_bazy:
			gracz.widok_ekwipunku("")
	_pojemnik = null
	_ramka_poj = null
	_prawe_ui.clear()
	_swiatlo_szuk = -1.0
	_kolejka.clear()
	_zajete_t = 0.0
	_warsztat = false
	if gracz and not tryb_bazy and ("kamizelka" in otwarte or "plecak" in otwarte or "bezpieczny" in otwarte or _otwieranie != ""):
		gracz.widok_ekwipunku("")
		if "plecak" in otwarte:
			Dzwiek.graj("plecak", -8.0, 1.1)
	_otwieranie = ""
	otwarte = []
	_kieszenie.clear()
	ekw.plecak_rozlozony = false
	ekw.bezp_rozlozony = false
	ekw.zakryte.clear()
	if not _przekl.is_empty():
		_przekl = {}
		if _duch and is_instance_valid(_duch):
			_duch.visible = false
	_szybki = false
	_ucieczka_t = 0.0
	if gracz:
		gracz.ruch_z_ekwipunkiem = false
	if _r3d:
		_r3d.zamknij_wszystko(0.4)
		_r3d = null
	if _warstwa:
		for c in _warstwa.get_children():
			c.queue_free()
	zamkniety.emit()
	if tryb_bazy:
		Gra.zapisz()


func _przebuduj() -> void:
	for c in _lewy.get_children():
		c.queue_free()
	for c in _srodek.get_children():
		c.queue_free()
	for c in _prawy_scroll.get_children():
		c.queue_free()
	if _warstwa:
		for c in _warstwa.get_children():
			c.queue_free()
	_siatki.clear()
	_sloty.clear()
	# lewy panel: oporządzenie na sylwetce, przy pojemnikach przyciski otwierania
	_lewy.add_child(Motyw.naszywka("Operator"))
	var postac := HBoxContainer.new()
	postac.add_theme_constant_override("separation", 10)
	_lewy.add_child(postac)
	var kol_l := VBoxContainer.new()
	kol_l.add_theme_constant_override("separation", 10)
	postac.add_child(kol_l)
	kol_l.add_child(_slot("helm", Vector2i(2, 2)))
	kol_l.add_child(_slot("pancerz", Vector2i(2, 3)))
	_info_zdrowie = VBoxContainer.new()
	postac.add_child(_info_zdrowie)
	_panel_ciala = PanelCiala.new()
	_panel_ciala.cialo = gracz.cialo if gracz else Cialo.new(Gra.zdrowie)
	_info_zdrowie.add_child(_panel_ciala)
	var kol_p := VBoxContainer.new()
	kol_p.add_theme_constant_override("separation", 4)
	postac.add_child(kol_p)
	kol_p.add_child(_slot("kamizelka", Vector2i(2, 2)))
	kol_p.add_child(_przycisk_otw("kamizelka"))
	kol_p.add_child(_slot("plecak", Vector2i(2, 2)))
	kol_p.add_child(_przycisk_otw("plecak"))
	var bronie := HBoxContainer.new()
	bronie.add_theme_constant_override("separation", 8)
	_lewy.add_child(bronie)
	bronie.add_child(_slot("glowna", Vector2i(6, 2)))
	bronie.add_child(_slot("pistolet", Vector2i(3, 2)))
	_lewy.add_child(_rzad_utility())
	var inne := HBoxContainer.new()
	inne.add_theme_constant_override("separation", 8)
	if tryb_bazy:
		inne.add_child(_przycisk_otw("kieszenie"))
	inne.add_child(_przycisk_otw("bezpieczny"))
	_lewy.add_child(inne)
	if not tryb_bazy:
		# kieszenie są na ciele: zawsze pod ręką w panelu
		_lewy.add_child(Motyw.naszywka("Kieszenie"))
		_lewy.add_child(_siatka_ui(ekw.kieszenie, "kieszenie"))
	_opis_ciala = Motyw.etykieta("", 12, Motyw.TEKST, Motyw.cond())
	_opis_ciala.autowrap_mode = TextServer.AUTOWRAP_WORD
	_opis_ciala.custom_minimum_size = Vector2(320, 18)
	_lewy.add_child(_opis_ciala)
	_info_waga = Motyw.etykieta("", 13, Motyw.TEKST, Motyw.mono())
	_lewy.add_child(_info_waga)
	# środek: otwarte pojemniki, każdy we własnej ramce (bez tła – pod spodem widać świat)
	_ramki.clear()
	for co in otwarte:
		var siatka := _siatka_pojemnika(co)
		if siatka == null:
			continue
		var ramka := PanelContainer.new()
		if _warstwa:
			# w świecie: same kafelki we wnętrzu pojemnika, nad nimi drobny napis – bez okna
			ramka.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		else:
			ramka.add_theme_stylebox_override("panel", RamkaStyl.new(false, 8.0))
		ramka.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var wn := VBoxContainer.new()
		wn.add_theme_constant_override("separation", 4)
		ramka.add_child(wn)
		var nag := HBoxContainer.new()
		var tytul: String = NAZWY_POJ[co]
		if co in ["kamizelka", "plecak"] and ekw.sloty[co] != null:
			tytul = ekw.sloty[co].nazwa() + _opis_red(ekw.sloty[co])
		if co == "bezpieczny":
			tytul += "  · zawartość przetrwa śmierć"
		if _warstwa:
			var lt := Motyw.etykieta(tytul.to_upper(), 11, Color(0.86, 0.8, 0.62, 0.85), Motyw.mono_b())
			lt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			lt.add_theme_constant_override("shadow_offset_x", 1)
			lt.add_theme_constant_override("shadow_offset_y", 1)
			nag.add_child(lt)
		else:
			nag.add_child(Motyw.naszywka(tytul))
		var sp2 := Control.new()
		sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp2.custom_minimum_size = Vector2(8, 0)
		nag.add_child(sp2)
		var x := Button.new()
		x.text = "✕"
		x.tooltip_text = "Zamknij"
		x.custom_minimum_size = Vector2(26, 22) if not _warstwa else Vector2(20, 16)
		if _warstwa:
			x.add_theme_font_size_override("font_size", 10)
			x.flat = true
		var c2: String = co
		x.pressed.connect(func(): przelacz_pojemnik(c2))
		nag.add_child(x)
		wn.add_child(nag)
		if co == "plecak" and not _warstwa:
			wn.add_child(Zamek.new())
		if co == "kamizelka" and _szybki and _warstwa and ekw.siatka_plecaka() != null:
			# szybkie zerknięcie: co (mniej więcej) zostało w plecaku – czy warto go zdejmować
			wn.add_child(_napis_swiat(_podsumowanie_plecaka(), 10, Color(0.8, 0.76, 0.62, 0.8), false))
		var gui := _siatka_ui(siatka, co)
		if _warstwa and _kieszenie.has(co):
			gui.kieszenie = _kieszenie[co]
			gui.kieszen.connect(_klik_kieszeni.bind(co))
			gui.gest_start.connect(_gest_start.bind(co))
			gui.gest_ruch.connect(_gest_ruch.bind(co))
			gui.gest_koniec.connect(_gest_koniec.bind(co))
			for i in (_kieszenie[co] as Array).size():
				_podpowiedz(_kieszenie[co][i], co, i)
		ramka.set_meta("siatka_ui", gui)
		gui.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		wn.add_child(gui)
		if _warstwa:
			_warstwa.add_child(ramka)
			ramka.visible = false        # pozycję nada _process (nad modelem 3D)
		else:
			_srodek.add_child(ramka)
		_ramki[co] = ramka
		if co == _swiezy:
			_animuj_wejscie.call_deferred(ramka, co)
	_swiezy = ""
	if _otwieranie != "":
		var ramka_o := PanelContainer.new()
		ramka_o.add_theme_stylebox_override("panel", RamkaStyl.new(true, 10.0))
		ramka_o.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var wo := VBoxContainer.new()
		wo.alignment = BoxContainer.ALIGNMENT_CENTER
		ramka_o.add_child(wo)
		var l := Motyw.etykieta({"kieszenie": "Sięgasz do kieszeni...", "kamizelka": "Spoglądasz na ładownice...", "plecak": "Zdejmujesz plecak i kładziesz przed sobą...", "bezpieczny": "Wyjmujesz kontener i stawiasz obok..."}[_otwieranie], 14, Motyw.ZOLC, Motyw.cond())
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wo.add_child(l)
		_kolko_otw = KolkoPostepu.new()
		_kolko_otw.custom_minimum_size = Vector2(220, 64)
		_kolko_otw.promien = 18.0
		_kolko_otw.podpowiedz = false
		_kolko_otw.srodkuj = true
		wo.add_child(_kolko_otw)
		if _warstwa:
			_warstwa.add_child(ramka_o)
			ramka_o.set_meta("otwieranie", true)
			ramka_o.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		else:
			_srodek.add_child(ramka_o)
	elif otwarte.is_empty() and _warstwa == null:
		var l2 := Motyw.etykieta("Otwórz pojemnik przyciskiem przy slocie.", 14, Motyw.TEKST_CIEMNY, Motyw.cond())
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_srodek.add_child(l2)
	# prawy: przeszukiwany pojemnik / skrytka
	if _btn_sort and is_instance_valid(_btn_sort):
		_btn_sort.queue_free()
		_btn_sort = null
	if _prawa_siatka != null:
		var naz := ("Skrytka · stół roboczy (montaż dodatków)" if _warsztat else "Skrytka") if _pojemnik == null else _pojemnik.nazwa
		_prawy_tytul.text = naz.to_upper()
		_prawa_ui = _siatka_ui(_prawa_siatka, "prawy")
		if tryb_bazy and _pojemnik == null:
			var bs := Button.new()
			bs.text = "Sortuj skrytkę"
			bs.add_theme_font_size_override("font_size", 12)
			bs.pressed.connect(func():
				if not _prawa_siatka.sortuj():
					_komunikat("Nie da się ułożyć – za ciasno")
				_odswiez())
			_sortuj_btn(bs)
		if _pojemnik != null:
			_prawa_ui.znane = _pojemnik.lista_czesci()[0]["znane"]
		if _warstwa and _pojemnik != null:
			# rajd: kafelki we wnętrzu otwartego mebla / przy zwłokach, bez okna; zwłoki – części po kolei
			_ramka_poj = PanelContainer.new()
			_ramka_poj.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			var wn := VBoxContainer.new()
			wn.add_theme_constant_override("separation", 3)
			_ramka_poj.add_child(wn)
			wn.add_child(_napis_swiat(naz.to_upper(), 11, Color(0.86, 0.8, 0.62, 0.85), true))
			_etyk_szuk = _napis_swiat("", 11, Color(0.75, 0.72, 0.6, 0.8), false)
			wn.add_child(_etyk_szuk)
			_prawe_ui.clear()
			var cz_l: Array = _pojemnik.lista_czesci()
			var kol := HBoxContainer.new()
			kol.add_theme_constant_override("separation", 26)
			wn.add_child(kol)
			for i in cz_l.size():
				var c: Dictionary = cz_l[i]
				var gui: SiatkaUI = _prawa_ui if i == 0 and c["siatka"] == _prawa_siatka else _siatka_ui(c["siatka"], "prawy")
				gui.znane = c["znane"]
				var bl := VBoxContainer.new()
				bl.add_theme_constant_override("separation", 2)
				if String(c["nazwa"]) != "":
					bl.add_child(_napis_swiat(String(c["nazwa"]) + ("  · kliknij, by zdjąć" if c.get("zdejmowane", false) else ""), 10, Color(0.8, 0.76, 0.62, 0.8), false))
				gui.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				bl.add_child(gui)
				kol.add_child(bl)
				_prawe_ui.append([gui, i])
			_prawa_ui.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_ramka_poj.set_meta("siatka_ui", kol)
			_ramka_poj.visible = false
			_warstwa.add_child(_ramka_poj)
			_pp.visible = false
		else:
			_prawy_scroll.add_child(_prawa_ui)
			_pp.visible = true
	else:
		_prawy_tytul.text = ""
		_prawa_ui = null
		_pp.visible = false
	_odswiez()


## Wejście ramki pojemnika: kamizelka wjeżdża od dołu (spojrzenie w dół), plecak rozwija się jak rozpinany zamek,
## kieszenie i kontener – krótkie rozwinięcie.
func _animuj_wejscie(r: Control, co: String) -> void:
	if not is_instance_valid(r):
		return
	var tw := r.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	r.modulate.a = 0.0
	if _warstwa:
		# rajd: kafelki pojawiają się we wnętrzu rozłożonego pojemnika
		r.pivot_offset = r.size * 0.5
		r.scale = Vector2(0.94, 0.94)
		tw.tween_property(r, "modulate:a", 1.0, 0.2)
		tw.tween_property(r, "scale", Vector2.ONE, 0.2)
		return
	match co:
		"plecak":
			r.pivot_offset = Vector2(r.size.x * 0.5, 0.0)
			r.scale = Vector2(0.92, 0.04)
			tw.tween_property(r, "modulate:a", 1.0, 0.12)
			tw.tween_property(r, "scale", Vector2.ONE, 0.32)
		"kamizelka":
			r.pivot_offset = r.size * 0.5
			r.scale = Vector2(1.06, 1.06)
			var y0 := r.position.y
			r.position.y = y0 + 90.0
			tw.tween_property(r, "modulate:a", 1.0, 0.18)
			tw.tween_property(r, "position:y", y0, 0.26)
			tw.tween_property(r, "scale", Vector2.ONE, 0.26)
		_:
			r.pivot_offset = r.size * 0.5
			r.scale = Vector2(0.9, 0.9)
			tw.tween_property(r, "modulate:a", 1.0, 0.12)
			tw.tween_property(r, "scale", Vector2.ONE, 0.16)


## Przycisk otwierania pojemnika przy slocie (stan: otwórz / zamknij / otwieranie).
func _przycisk_otw(co: String) -> Button:
	var b := Button.new()
	var ma := _siatka_pojemnika(co) != null
	var swiat := not tryb_bazy and gracz != null
	if co == _otwieranie:
		b.text = {"plecak": "zdejmowanie...", "bezpieczny": "wyjmowanie..."}.get(co, "otwieranie...") if swiat else "otwieranie..."
		b.disabled = true
	elif co in otwarte:
		if swiat and co == "plecak":
			b.text = "◂ Załóż"
		elif swiat and co == "bezpieczny":
			b.text = "◂ Schowaj kontener"
		else:
			b.text = "◂ Zamknij" if co in ["kamizelka", "plecak"] else "◂ " + NAZWY_POJ[co]
	else:
		if swiat and co == "plecak":
			b.text = "Zdejmij ▸"
		elif swiat and co == "bezpieczny":
			b.text = "Wyjmij kontener ▸"
		else:
			b.text = "Otwórz ▸" if co in ["kamizelka", "plecak"] else NAZWY_POJ[co] + " ▸"
		b.disabled = not ma
	b.add_theme_font_size_override("font_size", 12)
	b.custom_minimum_size = Vector2(76 if co in ["kamizelka", "plecak"] else 150, 24)
	b.pressed.connect(func(): przelacz_pojemnik(co))
	return b


## Sloty wyposażenia dodatkowego (latarka, mapa, kompas): pas + tyle, ile daje kamizelka.
func _rzad_utility() -> Control:
	var v := VBoxContainer.new()
	v.add_child(Motyw.naszywka("Wyposażenie · %d/%d" % [ekw.liczba_utility(), Ekwipunek.MAX_UTILITY]))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	for i in Ekwipunek.MAX_UTILITY:
		h.add_child(_slot("util%d" % i, Vector2i(2, 1)))
	return v


func _opis_red(p: Przedmiot) -> String:
	if p == null:
		return " (brak)"
	return "  · -%d%% wagi" % int(p.defn()["pojemnik"]["redukcja"] * 100)


func _slot(nazwa: String, rozmiar: Vector2i) -> SlotUI:
	var s := SlotUI.new()
	s.ustaw(ekw, nazwa, rozmiar)
	s.kontroler = self
	s.klik.connect(_klik_slot)
	s.najechano.connect(_hover)
	_sloty.append(s)
	return s


func _siatka_ui(s: Siatka, zrodlo: String) -> SiatkaUI:
	var ui := SiatkaUI.new()
	ui.kontroler = self
	ui.zrodlo = zrodlo
	ui.ustaw(s)
	ui.klik.connect(_klik_siatka)
	ui.najechano.connect(_hover)
	_siatki.append(ui)
	return ui


func _odswiez() -> void:
	if not otwarty:
		return
	_info_bony.text = "%d bonów" % Gra.bony if tryb_bazy else ""
	if _panel_ciala:
		_panel_ciala.queue_redraw()
	var w := ekw.waga()
	var progi := ["lekki", "obciążony", "przeciążony", "krytyczny"]
	var p := 0 if w < 18.0 else (1 if w < 28.0 else (2 if w < 40.0 else 3))
	_info_waga.text = "Waga efektywna: %.1f kg (%s)" % [w, progi[p]]
	_info_waga.add_theme_color_override("font_color", [Motyw.TEKST, Motyw.ZOLC, Motyw.CZERWIEN, Motyw.CZERWIEN][p])
	for s in _siatki:
		s.queue_redraw()


# ------------------------------------------------------------------ pętla

func _process(delta: float) -> void:
	# rozłożony plecak / worek / kontener przed sobą: świat słychać głucho (zerknięcie na kamizelkę – nie)
	if not tryb_bazy:
		Dzwiek.przytlum_ekwipunek(otwarty and otwarte.any(func(c): return c != "kamizelka"))
	if _chowanie:
		return
	if not otwarty and gracz and not _ogl_ui.otwarty and not Sterowanie.blokada and Input.is_action_just_pressed("ogladaj") \
			and gracz.bron.przedmiot != null and gracz.akcja.is_empty():
		_ogl_ui.otworz()
		return
	if _ogl_ui and _ogl_ui.otwarty:
		return
	if Input.is_action_just_pressed("ekwipunek") and not Sterowanie.blokada_menu() and Engine.get_process_frames() > Sterowanie.blokuj_tab_do:
		if otwarty and not _przekl.is_empty():
			_komunikat("Najpierw odłóż: " + (_przekl["p"] as Przedmiot).nazwa())
		elif otwarty and not tryb_bazy and not _szybki and Time.get_ticks_msec() - _pokaz_ms < 320 and _pojemnik == null:
			szybka_kamizelka()
		elif otwarty:
			zamknij_animowany()
		elif gracz == null or not gracz.cialo.martwy:
			if tryb_bazy or gracz == null:
				otworz_skrytke()
			else:
				otworz(null)
	if not otwarty:
		return
	# otwieranie pojemnika w toku
	if _otwieranie != "":
		_otw_t += delta
		if _kolko_otw and is_instance_valid(_kolko_otw):
			_kolko_otw.visible = true
			_kolko_otw.postep = clampf(_otw_t / _otw_czas, 0.0, 1.0)
			_kolko_otw.calosc = _kolko_otw.postep
			_kolko_otw.tekst = ""
			_kolko_otw.queue_redraw()
		if _otw_t >= _otw_czas:
			var co := _otwieranie
			_otwieranie = ""
			if _siatka_pojemnika(co) != null:
				otwarte.append(co)
				_swiezy = co
				if _r3d and co in ["plecak", "bezpieczny", "kamizelka"]:
					# położony przed sobą, zapięty: kieszenie otwiera się każdą osobno (kamizelka: klapki ładownic)
					var idp := "kontener" if co == "bezpieczny" else (ekw.sloty[co] as Przedmiot).id
					var lst := []
					var st := ekw.stan_kieszeni(co)
					var defs := ModeleOporzadzenia.kieszenie_dla(idp, _siatka_pojemnika(co))
					for j in defs.size():
						var e: Dictionary = defs[j]
						var otw: bool = j < st.size() and bool(st[j])
						lst.append({"r": e["r"], "nazwa": e["nazwa"], "otwarta": otw, "w_toku": false})
					_kieszenie[co] = lst
				if co == "plecak":
					Dzwiek.graj("plecak", -9.0, 1.3)
			_przebuduj()
	# rajd: siatki pojemników nad ich modelami w świecie
	if _warstwa and _r3d:
		for co in _ramki:
			var r: Control = _ramki[co]
			if not is_instance_valid(r):
				continue
			var pk: Variant = _r3d.punkt_ekranu(co)
			if pk == null:
				r.visible = false
				continue
			# środek kafelków (nie całej ramki z napisem) w środku wnętrza modelu
			var g: Control = r.get_meta("siatka_ui", null)
			var off := r.size * 0.5
			if g and is_instance_valid(g):
				off = g.global_position - r.global_position + g.size * 0.5
			var cel: Vector2 = (pk as Vector2) - off
			cel.x = clampf(cel.x, 4.0, _root.size.x - r.size.x - 4.0)
			cel.y = clampf(cel.y, 4.0, _root.size.y - r.size.y - 30.0)
			if not r.visible:
				r.visible = true
				r.position = cel
			r.position = r.position.lerp(cel, 0.5)
		_hover_ziemi()
		_uchwyty_kieszeni()
		for c in _warstwa.get_children():
			if c.has_meta("otwieranie") and c is Control:
				var pk2: Variant = _r3d.punkt_ekranu(_otwieranie) if _otwieranie != "" else null
				var cc := _root.size * 0.5 if pk2 == null else (pk2 as Vector2)
				c.position = cc - (c as Control).size * 0.5
	_synchronizuj_dostep()
	_przekl_krok()
	_kolejka_krok(delta)
	if _warstwa:
		var cel_a := 0.55 if not _przekl.is_empty() else 1.0
		_warstwa.modulate.a = move_toward(_warstwa.modulate.a, cel_a, delta * 3.0)
		_lp.modulate.a = move_toward(_lp.modulate.a, cel_a, delta * 3.0)
	# ucieczka od rozłożonego plecaka: przytrzymany ruch porzuca go na ziemi
	var plecak_rozl := not tryb_bazy and gracz != null and ("plecak" in otwarte or _otwieranie == "plecak")
	if _podp_ucieczka == null and not tryb_bazy:
		_podp_ucieczka = Motyw.etykieta("[W/S/A/D – przytrzymaj] zerwij się i uciekaj (plecak zostaje na ziemi)", 12, Color(0.85, 0.6, 0.4, 0.85), Motyw.mono())
		_podp_ucieczka.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_podp_ucieczka.offset_top = -102
		_podp_ucieczka.offset_bottom = -84
		_podp_ucieczka.offset_left = -330
		_podp_ucieczka.offset_right = 330
		_podp_ucieczka.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_podp_ucieczka.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.03, 0.9))
		_podp_ucieczka.add_theme_constant_override("outline_size", 4)
		_root.add_child(_podp_ucieczka)
	if _podp_ucieczka:
		_podp_ucieczka.visible = plecak_rozl
	if plecak_rozl:
		var rusza := Input.is_action_pressed("przod") or Input.is_action_pressed("tyl") or Input.is_action_pressed("lewo") or Input.is_action_pressed("prawo")
		_ucieczka_t = _ucieczka_t + delta if rusza else 0.0
		if _ucieczka_t > 0.35:
			_ucieczka_t = 0.0
			zerwij_sie("ucieczka")
			return
	if _kolko_przel == null:
		_kolko_przel = KolkoPostepu.new()
		_kolko_przel.promien = 9.0
		_kolko_przel.podpowiedz = false
		_root.add_child(_kolko_przel)
	_kolko_przel.visible = (_zajete_t > 0.0 or not _kolejka.is_empty()) and not tryb_bazy
	if _kolko_przel.visible:
		_kolko_przel.calosc = 1.0 - clampf(_zajete_t / maxf(0.01, _zajete_calk), 0.0, 1.0)
		_kolko_przel.tekst = ("w kolejce: %d" % _kolejka.size()) if not _kolejka.is_empty() else ""
		_kolko_przel.position = _root.get_local_mouse_position() + Vector2(20, -18)
		_kolko_przel.queue_redraw()
	# przy przeszukiwaniu broń stale opuszczona (obie ręce zajęte)
	if _pojemnik != null and gracz and not tryb_bazy and gracz.akcja.is_empty() and gracz.bron._anim_akcji != "schowaj":
		gracz.bron.animacja_akcji("schowaj")
	# rajd: siatka przeszukiwanego pojemnika nad jego wnętrzem w świecie
	if _ramka_poj and is_instance_valid(_ramka_poj) and _pojemnik != null and is_instance_valid(_pojemnik):
		var pk3: Variant = _rzut(_pojemnik.punkt_wnetrza())
		if pk3 == null:
			_ramka_poj.visible = false
		else:
			var g3: Control = _ramka_poj.get_meta("siatka_ui", null)
			var off3 := _ramka_poj.size * 0.5
			if g3 and is_instance_valid(g3):
				off3 = g3.global_position - _ramka_poj.global_position + g3.size * 0.5
			var cel3: Vector2 = (pk3 as Vector2) - off3
			cel3.x = clampf(cel3.x, 392.0, maxf(392.0, _root.size.x - _ramka_poj.size.x - 4.0))
			cel3.y = clampf(cel3.y, 4.0, maxf(4.0, _root.size.y - _ramka_poj.size.y - 30.0))
			if not _ramka_poj.visible:
				_ramka_poj.visible = true
				_ramka_poj.position = cel3
			_ramka_poj.position = _ramka_poj.position.lerp(cel3, 0.5)
		if _etyk_szuk and is_instance_valid(_etyk_szuk):
			var ic: int = _pojemnik.czesc_szukana()
			var ciem := _swiatlo_szuk >= 0.0 and _swiatlo_szuk < 0.35
			if ic >= 0:
				var nz := String(_pojemnik.lista_czesci()[ic]["nazwa"]).to_lower()
				_etyk_szuk.text = ("przeszukujesz po omacku" if ciem else "przeszukujesz") + (": " + nz if nz != "" else "") + "..."
			else:
				_etyk_szuk.text = "pusto" if _pojemnik.pusty() else ""
	# przeszukiwanie: stopniowe odkrywanie zawartości (czas wg rozmiaru przedmiotu i światła), szelest słychać
	if _pojemnik != null and _prawa_ui != null and not _pojemnik.przeszukany():
		var swiatlo := _szuk_swiatlo() if not tryb_bazy else 1.0
		var i_cz: int = _pojemnik.szukaj(delta, swiatlo)
		if i_cz >= 0:
			for el in _prawe_ui:
				if int(el[1]) == i_cz and is_instance_valid(el[0]):
					(el[0] as SiatkaUI).ciemno = swiatlo < 0.35
					(el[0] as SiatkaUI).queue_redraw()
			if _prawe_ui.is_empty():
				_prawa_ui.queue_redraw()
			Dzwiek.graj("szukanie", -12.0, randf_range(0.9, 1.15))
			if gracz:
				Gra.emituj_halas(_pojemnik.global_position, 3.5, gracz)
		if gracz and gracz.global_position.distance_to(_pojemnik.global_position) > 3.0:
			zamknij()
			return
	elif _pojemnik != null and _prawa_ui and tryb_bazy:
		_pojemnik.odkryj_wszystko()
		_prawa_ui.queue_redraw()
	# postęp akcji gracza: kółko przy kursorze
	_kolko.ustaw_z_gracza(gracz)
	_kolko.position = _root.get_local_mouse_position() + Vector2(-34, -34)
	# panel ciała: opis części pod kursorem, podświetlenie przy przeciąganiu leku
	if _panel_ciala:
		var pod := _panel_ciala.czesc_pod(_root.get_global_mouse_position())
		var lek: bool = not _drag.is_empty() and (_drag["p"] as Przedmiot).typ() == "med"
		var nowe := pod if lek else ""
		if nowe != _panel_ciala.podswietl:
			_panel_ciala.podswietl = nowe
			_panel_ciala.queue_redraw()
		_opis_ciala.text = _panel_ciala.opis_czesci(pod) if pod != "" else "Najedź na część ciała, żeby zobaczyć urazy."
		if Engine.get_process_frames() % 10 == 0:
			_panel_ciala.queue_redraw()
	if Input.is_action_just_pressed("napelnij"):
		napelnij_wszystkie()
	if Input.is_action_just_pressed("wyrzuc") and _drag.is_empty() and _hover_p != null:
		_wyrzuc(_hover_p)
	if not _drag.is_empty():
		if Input.is_action_just_pressed("przeladuj"):
			_drag["rot"] = not _drag["rot"]
		_root.queue_redraw()
	_tooltip.position = _root.get_local_mouse_position() + Vector2(18, 14)
	if _tooltip.position.x + _tooltip.size.x > _root.size.x:
		_tooltip.position.x -= _tooltip.size.x + 36
	if _tooltip.position.y + _tooltip.size.y > _root.size.y:
		_tooltip.position.y = _root.size.y - _tooltip.size.y - 4


## Punkt świata na ekranie (piksele okna) albo null, gdy za kamerą.
func _rzut(p: Vector3) -> Variant:
	if gracz == null:
		return null
	var kam: Camera3D = gracz.kamera
	if kam.is_position_behind(p):
		return null
	var vp := kam.get_viewport()
	var skala := Vector2(Widok3D.POMNIEJSZENIE, Widok3D.POMNIEJSZENIE)
	if vp is SubViewport:
		var kont := vp.get_parent() as Control
		if kont:
			skala = Widok3D.skala_ekranu(vp)
	return kam.unproject_position(p) * skala


func przeciagany() -> Przedmiot:
	if not _przekl.is_empty():
		return _przekl["p"]
	return _drag.get("p")


func _w_swiecie() -> bool:
	return not tryb_bazy and gracz != null and _warstwa != null


## Rzeczy na ziemi w ekwipunku: chwytanie myszą (promień z kamery w punkt ekranu) i odkładanie tam,
## gdzie wskazuje kursor – jak fizycznie, w zasięgu ręki.
const ZASIEG_ZIEMI := 2.1


func _promien(m: Vector2) -> Array:
	var kam: Camera3D = gracz.kamera
	var pv := m / _skala_ekranu()
	return [kam.project_ray_origin(pv), kam.project_ray_normal(pv)]


func _lup_pod(m: Vector2) -> LupNaZiemi:
	if not _w_swiecie():
		return null
	var pr := _promien(m)
	var q := PhysicsRayQueryParameters3D.create(pr[0], pr[0] + pr[1] * 4.0, Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_INTERAKCJE)
	q.collide_with_areas = true
	var wykl: Array[RID] = [gracz.get_rid()]
	q.exclude = wykl
	var r := gracz.get_world_3d().direct_space_state.intersect_ray(q)
	# bryły ragdolla nie zasłaniają przedmiotów leżących na/pod ciałem
	for _i in 6:
		if r.is_empty() or not (r["collider"] is RigidBody3D and (r["collider"] as Node).get_parent() is Ragdoll):
			break
		wykl.append((r["collider"] as CollisionObject3D).get_rid())
		q.exclude = wykl
		r = gracz.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty() or not (r["collider"] is LupNaZiemi):
		return null
	var l := r["collider"] as LupNaZiemi
	if l.przedmiot == null or l.is_queued_for_deletion() or _poziomo(l.global_position) > ZASIEG_ZIEMI:
		return null
	return l


func _poziomo(p: Vector3) -> float:
	return Vector2(p.x - gracz.global_position.x, p.z - gracz.global_position.z).length()


## Punkt na podłodze / blacie pod kursorem (w zasięgu ręki) albo null.
func _ziemia_pod(m: Vector2) -> Variant:
	if not _w_swiecie():
		return null
	var pr := _promien(m)
	var q := PhysicsRayQueryParameters3D.create(pr[0], pr[0] + pr[1] * 4.0, Balistyka.WARSTWA_SWIAT)
	q.exclude = [gracz.get_rid()]
	var r := gracz.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty() or (r["normal"] as Vector3).y < 0.6:
		return null
	var p: Vector3 = r["position"]
	if _poziomo(p) > ZASIEG_ZIEMI or absf(p.y - gracz.global_position.y) > 1.3:
		return null
	return p


var _lup_hover: LupNaZiemi = null


## Podświetlenie rzeczy na ziemi pod kursorem (lekka poświata, jak zapięcia).
func _hover_ziemi() -> void:
	var l: LupNaZiemi = null
	if _drag.is_empty() and _przekl.is_empty() and _gest.is_empty() and not nad_celem(_root.get_global_mouse_position()):
		l = _lup_pod(_root.get_global_mouse_position())
	if l == _lup_hover:
		return
	if _lup_hover and is_instance_valid(_lup_hover):
		Rozlozenie3D.nakladka(_lup_hover, null)
	_lup_hover = l
	if l:
		Rozlozenie3D.nakladka(l, Rozlozenie3D.mat_podswietlenia())


func _skala_ekranu() -> Vector2:
	var vp := gracz.kamera.get_viewport()
	var skala := Vector2(Widok3D.POMNIEJSZENIE, Widok3D.POMNIEJSZENIE)
	if vp is SubViewport:
		var kont := vp.get_parent() as Control
		if kont:
			skala = Widok3D.skala_ekranu(vp)
	return skala


## Punkt ekranu -> punkt w układzie kamery, tam gdzie sięga dłoń: na rozłożonym sprzęcie / w meblu,
## a panel operatora po lewej to własne ciało (kieszenie, pas) – blisko i nisko.
func _ekran_na_kamere(scr: Vector2) -> Vector3:
	var kam: Camera3D = gracz.kamera
	var vp_pos := scr / _skala_ekranu()
	var od := kam.project_ray_origin(vp_pos)
	var kier := kam.project_ray_normal(vp_pos)
	var dl := 0.62
	if scr.x < 380.0:
		# kieszenie, pas, sloty na ciele: dłoń schodzi poniżej kadru (do biodra / piersi)
		var wys := clampf(scr.y / maxf(1.0, _root.size.y), 0.0, 1.0)
		return Vector3(-0.16 + wys * 0.06, -0.3 - wys * 0.16, -0.3)
	var q := PhysicsRayQueryParameters3D.create(od, od + kier * 1.6, Balistyka.WARSTWA_SWIAT)
	q.exclude = [gracz.get_rid()]
	var r := gracz.get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		# zasięg ręki: dalej sięga się pochyleniem – dłoń zostaje na promieniu widzenia (trafia w kafelek)
		dl = clampf(od.distance_to(r["position"]) - 0.12, 0.3, 0.68)
	return kam.to_local(od + kier * dl)


## Środek przedmiotu na ekranie (siatka albo slot).
func _ekran_przedmiotu(p: Przedmiot, z: Dictionary) -> Vector2:
	if z.get("typ") == "siatka":
		for ui in _siatki:
			if is_instance_valid(ui) and ui.siatka == z["siatka"] and ui.is_visible_in_tree():
				var poz: Vector2i = ui.siatka.pozycja(p)
				return ui.global_position + (Vector2(poz) + Vector2(p.szer(), p.wys()) * 0.5) * SiatkaUI.KOM
	elif z.get("typ") == "slot":
		for sl in _sloty:
			if is_instance_valid(sl) and sl.slot == z["slot"]:
				return sl.get_global_rect().get_center()
	elif z.get("typ") == "ziemia" and is_instance_valid(z["wezel"]):
		var pz = _rzut((z["wezel"] as Node3D).global_position)
		if pz != null:
			return pz
	return _root.get_global_mouse_position()


## Co jest pod ręką dla automatów (przeładowanie, leki, napełnianie, podnoszenie): rozłożony plecak
## i otwarte kieszenie.
func _synchronizuj_dostep() -> void:
	if tryb_bazy or gracz == null:
		return
	ekw.plecak_rozlozony = otwarty and "plecak" in otwarte and _r3d != null
	ekw.bezp_rozlozony = otwarty and "bezpieczny" in otwarte and _r3d != null
	ekw.zakryte.clear()
	for co in _kieszenie:
		var st := ekw.stan_kieszeni(co)
		for j in mini(st.size(), (_kieszenie[co] as Array).size()):
			var e0: Dictionary = _kieszenie[co][j]
			if bool(st[j]) and not bool(e0["otwarta"]) and not bool(e0.get("w_toku", false)) and not bool(e0.get("zamyk", false)):
				# postać sama otworzyła (np. magazynek przy przeładowaniu)
				e0["otwarta"] = true
				e0.erase("postep")
				if _r3d:
					var stany := []
					for jj in st.size():
						stany.append(jj == j)
					_r3d.ustaw_stan(co, stany)
				if _ramki.has(co) and is_instance_valid(_ramki[co]):
					var g: SiatkaUI = _ramki[co].get_meta("siatka_ui", null)
					if g:
						g.queue_redraw()
		var s := _siatka_pojemnika(co)
		if s == null or co == "kamizelka":
			continue   # ładownice na ciele: przeładowanie sięga do nich i tak
		var zam := []
		for e in _kieszenie[co]:
			if not bool(e["otwarta"]):
				zam.append(e["r"])
		if not zam.is_empty():
			ekw.zakryte[s] = zam


## Przełożenie (bez animowanej dłoni): przedmiot przesuwa się po ekranie od miejsca do miejsca w czasie
## zależnym od wagi, rozmiaru i odległości; dopiero po nim `wykonaj`. Trafienie w trakcie – wypada.
func _animuj(p: Przedmiot, z: Dictionary, cel_scr: Vector2, wykonaj: Callable) -> void:
	if not _w_swiecie():
		wykonaj.call()
		return
	var od_scr := _ekran_przedmiotu(p, z)
	var czas := 0.35 + od_scr.distance_to(cel_scr) / 2200.0 + p.waga() * 0.05 + p.szer() * p.wys() * 0.025
	czas = clampf(czas, 0.35, 1.5)
	if _duch == null or not is_instance_valid(_duch):
		_duch = TextureRect.new()
		_duch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_duch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_duch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_duch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_root.add_child(_duch)
	_duch.texture = Dane.ikona(p.id)
	_duch.size = Vector2(p.szer(), p.wys()) * SiatkaUI.KOM
	_duch.pivot_offset = _duch.size * 0.5
	_duch.visible = true
	_duch.modulate = Color(1, 1, 1, 0.85)
	_przekl = {"p": p, "z": z, "wykonaj": wykonaj, "chwyt": false, "odl": false, "t0": Time.get_ticks_msec(), "czas": czas, "od": od_scr, "do": cel_scr}
	Dzwiek.graj("podnies", -15.0, randf_range(1.1, 1.3))
	_odswiez()


func _przekl_krok() -> void:
	if _przekl.is_empty():
		if _duch and is_instance_valid(_duch):
			_duch.visible = false
		return
	var f := clampf((Time.get_ticks_msec() - int(_przekl["t0"])) / 1000.0 / float(_przekl["czas"]), 0.0, 1.0)
	if _duch and is_instance_valid(_duch):
		var e := f * f * (3.0 - 2.0 * f)
		var srodek: Vector2 = (_przekl["od"] as Vector2).lerp(_przekl["do"], e) - Vector2(0, sin(f * PI) * 18.0)
		_duch.global_position = srodek - _duch.size * 0.5
		_duch.scale = Vector2.ONE * (1.0 + sin(f * PI) * 0.08)
	if f > 0.85 and not _przekl["odl"]:
		_przekl["odl"] = true
		Dzwiek.graj("odloz", -12.0, clampf(1.3 - (_przekl["p"] as Przedmiot).waga() * 0.06, 0.7, 1.3))
	if f >= 1.0:
		var w: Callable = _przekl["wykonaj"]
		_przekl = {}
		if _duch and is_instance_valid(_duch):
			_duch.visible = false
		if w.is_valid():
			w.call()
		_po_zmianie()


## Trafienie / zerwanie w trakcie przekładania: przedmiot wypada z ręki na ziemię.
func _upusc_z_reki() -> void:
	if _przekl.is_empty():
		return
	var p: Przedmiot = _przekl["p"]
	var z: Dictionary = _przekl["z"]
	_przekl = {}
	if _duch and is_instance_valid(_duch):
		_duch.visible = false
	if _w_zrodle(p, z):
		_usun_ze_zrodla(p, z)
		gracz.upusc(p)
		gracz.komunikat.emit("Wypada ci z ręki: " + p.nazwa())


## Czy siatka należy do przeszukiwanego pojemnika / skrytki (prawa strona).
func _jest_prawa(s) -> bool:
	if s == null:
		return false
	if s == _prawa_siatka:
		return true
	if _pojemnik != null and is_instance_valid(_pojemnik):
		for c in _pojemnik.lista_czesci():
			if c["siatka"] == s:
				return true
	return false


func _czesc_zdejmowana(s) -> bool:
	if _pojemnik == null or not is_instance_valid(_pojemnik):
		return false
	for c in _pojemnik.lista_czesci():
		if c["siatka"] == s:
			return bool(c.get("zdejmowane", false))
	return false


## Zdjęcie przedmiotu z ciała (pancerz, hełm, kamizelka z zawartością, plecak): odpinanie trwa.
func _zdejmij_z_ciala(p: Przedmiot, s: Siatka) -> void:
	if gracz == null or tryb_bazy:
		return
	if not gracz.akcja.is_empty():
		_komunikat("Najpierw skończ: " + String(gracz.akcja["nazwa"]))
		return
	var czas: float = {"pancerz": 4.0, "pojemnik": 3.2}.get(p.typ(), 2.0)
	if p.typ() == "pancerz" and p.defn()["pancerz"]["slot"] == "helm":
		czas = 1.6
	czas += p.waga() * 0.15
	var poj := _pojemnik
	var koniec := func():
		if not s.zawiera(p):
			return
		s.usun(p)
		if is_instance_valid(poj) and poj.get_parent().has_method("zdjeto"):
			poj.get_parent().zdjeto(p)
		if not ekw.dodaj(p):
			# brak miejsca: kładzie obok zwłok
			var l := LupNaZiemi.new()
			l.przedmiot = p
			poj.get_parent().add_child(l)
			l.global_position = poj.global_position + Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5))
			gracz.komunikat.emit("Brak miejsca – położono obok: " + p.nazwa())
		Dzwiek.graj("rzep", -8.0, 0.9)
		_przebuduj()
	Dzwiek.graj("rzep", -10.0)
	gracz.zacznij_akcje("Zdejmowanie: " + p.nazwa(), czas, koniec, "zdejmowanie", 0, Callable(), {"id": p.id})


var _btn_sort: Button = null


func _sortuj_btn(b: Button) -> void:
	if _btn_sort and is_instance_valid(_btn_sort):
		_btn_sort.queue_free()
	_btn_sort = b
	_prawy.add_child(b)
	_prawy.move_child(b, 1)


func _podsumowanie_plecaka() -> String:
	var lic := {}
	for e in ekw.siatka_plecaka().items:
		var p: Przedmiot = e["p"]
		var k := ""
		match p.typ():
			"magazynek":
				k = "mag. " + p.nazwa().get_slice(" ", 1)
			"amunicja":
				k = "amunicja " + String(p.defn()["amunicja"]["kaliber"])
			"med":
				k = p.nazwa().to_lower()
		if k != "":
			lic[k] = int(lic.get(k, 0)) + (p.ilosc if p.typ() == "amunicja" else 1)
	if lic.is_empty():
		return "W plecaku: nic do walki ani leczenia"
	var cz := []
	for k in lic:
		cz.append("%s ×%d" % [k, lic[k]] if not String(k).begins_with("amunicja") else "%s (%d szt.)" % [k, lic[k]])
	return "W plecaku (trzeba zdjąć): " + ", ".join(cz)


func _napis_swiat(t: String, rozm: int, k: Color, gruby: bool) -> Label:
	var l := Motyw.etykieta(t, rozm, k, Motyw.mono_b() if gruby else Motyw.cond())
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


## Zerwanie się od rozłożonego sprzętu (trafienie, ucieczka): bez pakowania – plecak zostaje na ziemi.
func zerwij_sie(powod: String) -> void:
	if not otwarty or tryb_bazy or gracz == null or _chowanie:
		return
	if powod == "trafienie":
		_upusc_z_reki()
	var plecak_otw := "plecak" in otwarte or _otwieranie == "plecak"
	if not plecak_otw and _pojemnik == null and not ("bezpieczny" in otwarte):
		if powod == "trafienie" and ("kamizelka" in otwarte or _otwieranie != ""):
			zamknij()
		return
	if plecak_otw and ekw.sloty["plecak"] != null:
		var pl: Przedmiot = ekw.sloty["plecak"]
		var gdzie: Vector3 = gracz.global_position - gracz.global_basis.z * 0.7
		if _r3d and _r3d.ma("plecak"):
			var w: Node3D = _r3d._modele["plecak"]["wezel"]
			if is_instance_valid(w):
				gdzie = w.global_position
		ekw.sloty["plecak"] = null
		ekw.zmieniony.emit()
		if _r3d:
			_r3d._usun("plecak")
		var l := LupNaZiemi.new()
		l.przedmiot = pl
		gracz.get_parent().add_child(l)
		l.global_position = gdzie + Vector3.UP * 0.2
		gracz.komunikat.emit(("Trafiony! " if powod == "trafienie" else "") + "Plecak zostaje na ziemi – [F] przy nim, żeby założyć")
	zamknij()


func _szuk_swiatlo() -> float:
	if _pojemnik == null or not is_instance_valid(_pojemnik):
		return 1.0
	if Engine.get_process_frames() % 20 == 0 or _swiatlo_szuk < 0.0:
		var sc = get_tree().get_first_node_in_group("ui_rajdu")
		_swiatlo_szuk = sc.oswietlenie(_pojemnik.punkt_wnetrza()) if sc and sc.has_method("oswietlenie") else 1.0
	return _swiatlo_szuk


# ------------------------------------------------------------------ kliknięcia

func _klik_siatka(ui: SiatkaUI, p: Przedmiot, przycisk: int, pos: Vector2) -> void:
	if p == null:
		return
	var z := {"typ": "siatka", "ui": ui, "siatka": ui.siatka}
	if przycisk == MOUSE_BUTTON_LEFT and _czesc_zdejmowana(ui.siatka):
		_zdejmij_z_ciala(p, ui.siatka)
		return
	if przycisk == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_CTRL):
			_szybkie_przeniesienie(p, z)
			return
		if Input.is_key_pressed(KEY_SHIFT) and p.stos_max() > 1 and p.ilosc > 1:
			_podziel(p, ui.siatka)
			return
		if _zajete():
			return
		var poz := ui.siatka.pozycja(p)
		_drag = {"p": p, "z": z, "off": pos - (ui.global_position + Vector2(poz) * SiatkaUI.KOM), "rot": p.obrot}
		Dzwiek.graj("klik", -14.0)
	elif przycisk == MOUSE_BUTTON_RIGHT:
		_pokaz_menu(p, z, pos)


func _klik_slot(ui: SlotUI, p: Przedmiot, przycisk: int, pos: Vector2) -> void:
	if p == null:
		return
	var z := {"typ": "slot", "slot": ui.slot}
	if przycisk == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_CTRL):
			_szybkie_przeniesienie(p, z)
			return
		if _zajete():
			return
		_drag = {"p": p, "z": z, "off": Vector2(16, 16), "rot": p.obrot}
	elif przycisk == MOUSE_BUTTON_RIGHT:
		_pokaz_menu(p, z, pos)


func _input(event: InputEvent) -> void:
	if not otwarty or _chowanie:
		return
	if event.is_action_pressed("pauza"):
		zamknij_animowany()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _drag.is_empty():
		_upusc_drag(false)
		get_viewport().set_input_as_handled()
		return
	# rzecz z ziemi: chwyt myszą i przeciągnięcie do plecaka, kieszeni, slotu albo w inne miejsce na ziemi
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _drag.is_empty() \
			and _przekl.is_empty() and _gest.is_empty() and _w_swiecie() and not nad_celem(_root.get_global_mouse_position()) \
			and _uchwyt_pod(_root.get_global_mouse_position()).is_empty():
		var l := _lup_pod(_root.get_global_mouse_position())
		if l != null and not _zajete():
			var pz: Przedmiot = l.przedmiot
			_drag = {"p": pz, "z": {"typ": "ziemia", "wezel": l}, "off": Vector2(pz.szer(), pz.wys()) * SiatkaUI.KOM * 0.5, "rot": pz.obrot}
			l.visible = false          # w dłoni (wraca na miejsce, jeśli puszczony donikąd)
			Dzwiek.graj("podnies", -16.0, 1.2)
			get_viewport().set_input_as_handled()
			return
	# zapięcia kieszeni: chwyt za podświetlony suwak / klamrę / brzeg klapy i przeciągnięcie go
	if not _proste() and _drag.is_empty() and _przekl.is_empty():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _gest.is_empty():
				if _chwyc_uchwyt(_root.get_global_mouse_position()):
					get_viewport().set_input_as_handled()
			elif not event.pressed and not _gest.is_empty():
				_pusc_uchwyt()
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and not _gest.is_empty():
			_ciagnij_uchwyt(_root.get_global_mouse_position())
			get_viewport().set_input_as_handled()


func _upusc_drag(anuluj: bool, mysz_test := Vector2(-1, -1)) -> void:
	if _drag.is_empty():
		return
	var d := _drag
	_drag = {}
	if d["z"]["typ"] == "ziemia" and is_instance_valid(d["z"]["wezel"]):
		(d["z"]["wezel"] as Node3D).visible = true
	if anuluj:
		_odswiez()
		return
	var mysz := _root.get_global_mouse_position() if mysz_test.x < 0.0 else mysz_test
	var p: Przedmiot = d["p"]
	# cel: część ciała (leczenie wybranej części)
	if _panel_ciala and p.typ() == "med" and gracz and not tryb_bazy:
		var cz := _panel_ciala.czesc_pod(mysz)
		if cz != "":
			var szybki := true
			if d["z"]["typ"] == "siatka":
				szybki = ekw.czy_szybka(d["z"]["siatka"])
			_po_schowaniu(func(): gracz.uzyj_leku(p, szybki, cz))
			return
	# poza slotami i siatkami: odłożenie na ziemię tam, gdzie wskazuje kursor (w zasięgu ręki),
	# dalej – wyrzucenie przed siebie
	if not nad_celem(mysz):
		var gdzie = _ziemia_pod(mysz)
		if d["z"]["typ"] == "ziemia":
			var lw: LupNaZiemi = d["z"]["wezel"]
			if gdzie != null and is_instance_valid(lw):
				var tw := lw.create_tween()
				tw.tween_property(lw, "global_position", (gdzie as Vector3) + Vector3.UP * 0.004, 0.25).set_trans(Tween.TRANS_QUAD)
				Dzwiek.graj("odloz", -12.0)
			_odswiez()
			return
		if not tryb_bazy and gracz and not (d["z"]["typ"] == "siatka" and _jest_prawa(d["z"]["siatka"])):
			if gdzie != null:
				_odloz_na_ziemie(p, d["z"], gdzie)
			else:
				_wyrzuc_reka(p, d["z"])
		else:
			_odswiez()
		return
	# cel: slot
	for s in _sloty:
		if s.get_global_rect().has_point(mysz):
			var w: Przedmiot = ekw.sloty.get(s.slot)
			if p.typ() == "dodatek" and w != null and w.typ() == "bron":
				_montuj(w, p, d["z"])
				_odswiez()
				return
			var slot_n: String = s.slot
			var zr: Dictionary = d["z"]
			_animuj(p, zr, s.get_global_rect().get_center(), func():
				if _w_zrodle(p, zr):
					_na_slot(p, zr, slot_n)
				_po_zmianie())
			return
	# cel: siatka
	for ui in _siatki:
		if ui.siatka == null or not ui.get_global_rect().has_point(mysz):
			continue
		var pod := ui.komorka_pod(mysz - ui.global_position)
		var q := ui.siatka.przedmiot_w(pod.x, pod.y)
		if q != null and ui.ukryty(q):
			q = null
		if q != null and q != p:
			var akcja: bool = (p.typ() == "dodatek" and q.typ() == "bron") or (p.typ() == "amunicja" and q.typ() == "magazynek")
			if akcja or not _w_swiecie():
				if _polacz(p, d["z"], q, ui):
					_po_zmianie()
					return
			elif _polacz_mozliwe(p, q, ui.siatka):
				# dołożenie do stosu, magazynek do broni, do pojemnika – ręką
				var zq: Dictionary = d["z"]
				var sq: Siatka = ui.siatka
				var cel_q := _ekran_przedmiotu(q, {"typ": "siatka", "siatka": sq})
				_animuj(p, zq, cel_q, func():
					if _w_zrodle(p, zq) and sq.zawiera(q):
						var tmp := SiatkaUI.new()
						tmp.siatka = sq
						_polacz(p, zq, q, tmp)
						tmp.free()
					_po_zmianie())
				return
		var tl: Vector2 = mysz - d["off"] - ui.global_position
		var kom := Vector2i(roundi(tl.x / SiatkaUI.KOM), roundi(tl.y / SiatkaUI.KOM))
		if d["rot"] != p.obrot:
			kom = pod
		if p.typ() == "pojemnik" and p.dane["siatka"] == ui.siatka:
			return
		var sw := p.szer()
		var sh := p.wys()
		if d["rot"] != p.obrot:
			var tmp := sw
			sw = sh
			sh = tmp
		if ui.zakryty_obszar(kom.x, kom.y, sw, sh):
			_komunikat("Ta kieszeń jest zapięta – kliknij ją, żeby otworzyć")
			_odswiez()
			return
		if ui.siatka.moze(p, kom.x, kom.y, d["rot"], p):
			var sg: Siatka = ui.siatka
			var zr2: Dictionary = d["z"]
			var rot: bool = d["rot"]
			var cel_scr := ui.global_position + (Vector2(kom) + Vector2(sw, sh) * 0.5) * SiatkaUI.KOM
			_animuj(p, zr2, cel_scr, func():
				if _w_zrodle(p, zr2) and sg.moze(p, kom.x, kom.y, rot, p):
					_usun_ze_zrodla(p, zr2)
					sg.poloz(p, kom.x, kom.y, rot)
					if _pojemnik and is_instance_valid(_pojemnik):
						_pojemnik.poznaj(p)
					if not _w_swiecie():
						Dzwiek.graj("odloz", -10.0)
				_po_zmianie())
		return
	_odswiez()


## Czy pod kursorem jest coś, na co można upuścić przedmiot (slot, siatka, panel ciała).
func nad_celem(mysz: Vector2) -> bool:
	for s in _sloty:
		if s.is_visible_in_tree() and s.get_global_rect().grow(4).has_point(mysz):
			return true
	for ui in _siatki:
		if ui.is_visible_in_tree() and ui.get_global_rect().grow(4).has_point(mysz):
			return true
	if _panel_ciala and _panel_ciala.get_global_rect().has_point(mysz):
		return true
	return false


func _po_zmianie() -> void:
	ekw.zmieniony.emit()
	if tryb_bazy:
		Gra.zapisz()
	# zmiana kamizelki/plecaka zmienia układ siatek
	_przebuduj()


func _usun_ze_zrodla(p: Przedmiot, z: Dictionary) -> void:
	if z["typ"] == "ziemia":
		var lw: LupNaZiemi = z["wezel"]
		if is_instance_valid(lw):
			lw.przedmiot = null
			lw.queue_free()
		return
	if z["typ"] == "siatka":
		(z["siatka"] as Siatka).usun(p)
	elif z["typ"] == "slot":
		ekw.zdejmij(z["slot"])


func _na_slot(p: Przedmiot, z: Dictionary, slot: String) -> void:
	if slot == "util":
		slot = ekw.wolny_util()
		if slot == "":
			_komunikat("Brak wolnego slotu wyposażenia – kamizelka daje więcej")
			return
	if slot.begins_with("util") and not ekw.util_aktywny(slot):
		_komunikat("Ten slot daje dopiero lepsza kamizelka")
		return
	if not Ekwipunek.pasuje(slot, p):
		_komunikat("To nie pasuje do: " + Ekwipunek.NAZWY_SLOTOW[slot])
		return
	if z["typ"] == "slot" and z["slot"] == slot:
		return
	var stary: Przedmiot = ekw.sloty[slot]
	_usun_ze_zrodla(p, z)
	if stary != null:
		ekw.zdejmij(slot)
	ekw.zaloz(slot, p)
	if stary != null:
		var ok := false
		if z["typ"] == "siatka":
			ok = (z["siatka"] as Siatka).dodaj(stary)
		elif z["typ"] == "slot" and Ekwipunek.pasuje(z["slot"], stary):
			ok = ekw.zaloz(z["slot"], stary)
		if not ok:
			ok = ekw.dodaj(stary) or (_prawa_siatka != null and _prawa_siatka.dodaj(stary))
		if not ok:
			# cofnij
			ekw.zdejmij(slot)
			ekw.zaloz(slot, stary)
			if z["typ"] == "siatka":
				(z["siatka"] as Siatka).dodaj(p)
			_komunikat("Brak miejsca na zdjęty przedmiot")
			return
	Dzwiek.graj("zaloz", -8.0)


## Interakcje przedmiot-na-przedmiot: stos amunicji, amunicja do magazynka, magazynek do broni, przedmiot do pojemnika.
func _polacz_mozliwe(p: Przedmiot, q: Przedmiot, s: Siatka) -> bool:
	if p.id == q.id and p.stos_max() > 1 and q.ilosc < q.stos_max():
		return s.ile_zmiesci(q, mini(p.ilosc, q.stos_max() - q.ilosc)) > 0
	if p.typ() == "magazynek" and q.typ() == "bron":
		return p.id in q.defn()["bron"].get("magazynki", []) and q.dane["mag"] == null
	if q.typ() == "pojemnik" and p != q and p.typ() != "pojemnik":
		return not (q.dane["siatka"] as Siatka).wolne_miejsce(p).is_empty()
	return false


func _polacz(p: Przedmiot, z: Dictionary, q: Przedmiot, ui: SiatkaUI) -> bool:
	if p.id == q.id and p.stos_max() > 1 and q.ilosc < q.stos_max():
		# stos rośnie (garść -> pudełko): dokładamy tyle, ile się zmieści
		var ile: int = ui.siatka.ile_zmiesci(q, mini(p.ilosc, q.stos_max() - q.ilosc))
		if ile <= 0:
			_komunikat("Pudełko się tu nie zmieści")
			return false
		q.ilosc += ile
		p.ilosc -= ile
		if p.ilosc <= 0:
			_usun_ze_zrodla(p, z)
		return true
	if p.typ() == "dodatek" and q.typ() == "bron":
		return _montuj(q, p, z)
	if p.typ() == "amunicja" and q.typ() == "magazynek":
		_seria_mag = false
		return _napelnij(q, p, z)
	if p.typ() == "magazynek" and q.typ() == "bron":
		var bd: Dictionary = q.defn()["bron"]
		if p.id in bd.get("magazynki", []) and q.dane["mag"] == null:
			_usun_ze_zrodla(p, z)
			q.dane["mag"] = p
			if q.dane["komora"] == "" and p.dane["naboje"] > 0:
				q.dane["komora"] = p.dane["amunicja"]
				p.dane["naboje"] -= 1
			Dzwiek.graj("przeladowanie", -8.0)
			return true
	if q.typ() == "pojemnik" and p != q and p.typ() != "pojemnik":
		var s: Siatka = q.dane["siatka"]
		var m := s.wolne_miejsce(p)
		if not m.is_empty():
			_usun_ze_zrodla(p, z)
			s.poloz(p, m["x"], m["y"], m["rot"])
			_komunikat("Włożono do: " + q.nazwa())
			return true
	return false


func _szybkie_przeniesienie(p: Przedmiot, z: Dictionary) -> void:
	if not tryb_bazy and gracz:
		# w rajdzie: do kolejki – dłoń przenosi po kolei
		for e in _kolejka:
			if e["p"] == p:
				return
		if z["typ"] == "siatka" and _czesc_zdejmowana(z["siatka"]):
			_zdejmij_z_ciala(p, z["siatka"])
			return
		if _prawa_siatka == null and not (z["typ"] == "siatka" and _jest_prawa(z["siatka"])):
			return
		_kolejka.append({"p": p, "z": z})
		_odswiez()
		return
	_przenies_teraz(p, z)


## Otwarcie kieszeni rozłożonego plecaka / kontenera: animacja na modelu, chwila czasu, szelest.
func _klik_kieszeni(ui: SiatkaUI, i: int, co: String) -> void:
	if not _kieszenie.has(co) or i < 0 or i >= (_kieszenie[co] as Array).size():
		return
	var e: Dictionary = _kieszenie[co][i]
	if bool(e["otwarta"]) or bool(e["w_toku"]):
		return
	for x in _kieszenie[co]:
		if bool(x["w_toku"]):
			return     # jedna kieszeń naraz – obie ręce przy zamku
	if gracz and not gracz.akcja.is_empty():
		return
	var czas: float = _r3d.otworz_kieszen(co, i) if _r3d else 0.3
	e["w_toku"] = true
	ui.queue_redraw()
	_zajmij(czas)
	if gracz:
		Gra.emituj_halas(gracz.global_position, 3.0, gracz)
	get_tree().create_timer(maxf(0.1, czas)).timeout.connect(func():
		e["w_toku"] = false
		e["otwarta"] = true
		e.erase("postep")
		ekw.ustaw_kieszen(co, i, true)
		if is_instance_valid(ui):
			ui.queue_redraw())


# ------------------------------------------------------------------ gesty przy kieszeniach

var _gest := {}


## Uchwyty zapięć: dla każdej kieszeni bieżący krok (otwieranie zamkniętej, zapinanie otwartej), jego
## punkt na ekranie i kierunek, w którym trzeba go przeciągnąć. SiatkaUI rysuje je jako podświetlenie.
func _uchwyty_kieszeni() -> void:
	var t := Time.get_ticks_msec()
	var podsw := []
	for co in _kieszenie:
		var gui: SiatkaUI = null
		if _ramki.has(co) and is_instance_valid(_ramki[co]) and (_ramki[co] as Control).visible:
			gui = _ramki[co].get_meta("siatka_ui", null)
		var lst: Array = _kieszenie[co]
		for i in lst.size():
			var e: Dictionary = lst[i]
			e.erase("uchwyt")
			if gui == null or _proste() or _r3d == null or not _r3d.ma(co) or bool(e.get("w_toku", false)):
				continue
			var zam := bool(e["otwarta"]) or bool(e.get("zamyk", false))
			var pg := _postep(e, co, i)
			var k := -1
			if zam:
				for q in range(pg.size() - 1, -1, -1):
					if float(pg[q]) > 0.0:
						k = q
						break
			else:
				for q in pg.size():
					if float(pg[q]) < 1.0:
						k = q
						break
			if k < 0:
				continue
			var pe = _r3d.uchwyt_ekran(co, i, k)
			if pe == null:
				continue
			var rodz: String = _r3d.rodzaj_kroku(co, i, k)
			var kl := "kier_%d" % k
			if not e.has(kl) or t - int(e.get(kl + "_t", 0)) > 600:
				if _gest.is_empty() or _gest["co"] != co or int(_gest["i"]) != i:
					e[kl] = _droga(co, i, k, float(pg[k]), rodz, e)
					e[kl + "_t"] = t
			var kier: Vector2 = e.get(kl, Vector2(0, -110))
			if bool(e["otwarta"]):
				# otwarta kieszeń: uchwyt zapinania nie może leżeć na jej slotach (brzeg torby / klapy wypadał
				# w pierwszym rzędzie) – przesunięty tuż nad górną krawędź siatki
				var rk := _rect_kieszeni(gui, e)
				if rk.grow(-2.0).has_point(pe):
					pe = Vector2(clampf((pe as Vector2).x, rk.position.x + 6.0, rk.end.x - 6.0), rk.position.y - 7.0)
			# żaden uchwyt (też zapiętej sąsiedniej kieszeni) nie leży na slotach otwartej kieszeni
			for _q in 4:
				var pod_r := _otwarte_sloty_pod(pe)
				if pod_r.size.x <= 0.0:
					break
				pe = Vector2((pe as Vector2).x, pod_r.position.y - 7.0)
			e["uchwyt"] = pe
			e["uchwyt_k"] = k
			e["uchwyt_l"] = gui.get_global_transform().affine_inverse() * (pe as Vector2)
			e["uchwyt_kier"] = (-kier if zam else kier).normalized()
			e["uchwyt_rodz"] = rodz
			e["uchwyt_akt"] = not _gest.is_empty() and _gest["co"] == co and int(_gest["i"]) == i
			e["obszar"] = _r3d.obszar_ekran(co, i, k)
			podsw.append([co, i, k, e["uchwyt_akt"]])
		if gui:
			gui.proste_kieszenie = _proste()
			gui.queue_redraw()
	# pod kursorem: element jaśniej i kursor „ręki” (bez znaczników – tylko sam element się świeci)
	var m := _root.get_global_mouse_position()
	var pod := _uchwyt_pod(m)
	for el in podsw:
		if not pod.is_empty() and el[0] == pod["co"] and el[1] == pod["i"]:
			el[3] = true
	if _r3d:
		_r3d.podswietl(podsw)
	var kursor := Input.CURSOR_ARROW
	if not _gest.is_empty():
		kursor = Input.CURSOR_DRAG
	elif not pod.is_empty() or (_lup_hover != null and is_instance_valid(_lup_hover)):
		kursor = Input.CURSOR_POINTING_HAND
	if kursor != _kursor:
		_kursor = kursor
		Input.set_default_cursor_shape(kursor)


var _kursor := Input.CURSOR_ARROW


## Uchwyt pod kursorem: w obszarze elementu albo blisko jego punktu chwytu (najbliższy wygrywa).
func _uchwyt_pod(m: Vector2) -> Dictionary:
	var best := {}
	var bd := INF
	var nad_slotami := _nad_otwartymi_slotami(m)
	for co in _kieszenie:
		var lst: Array = _kieszenie[co]
		for i in lst.size():
			var e: Dictionary = lst[i]
			if not e.has("uchwyt"):
				continue
			var d := (e["uchwyt"] as Vector2).distance_to(m)
			# obszar elementu (klapa, torba) chwyta tylko przy zapiętej kieszeni – przy otwartej obejmował całą
			# torbę razem ze slotami i każde kliknięcie w przedmiot zaczynało zapinanie
			var w_obszarze: bool = not bool(e["otwarta"]) and (e.get("obszar", Rect2()) as Rect2).grow(5.0).has_point(m)
			# nad slotami otwartej kieszeni (tej albo sąsiedniej) uchwyt łapie tylko dokładne trafienie w pierścień
			if nad_slotami:
				continue
			if (d < 26.0 or w_obszarze) and d < bd:
				bd = d
				best = {"co": co, "i": i}
	return best


## Prostokąt slotów kieszeni na ekranie.
func _rect_kieszeni(gui: SiatkaUI, e: Dictionary) -> Rect2:
	var rr: Rect2i = e["r"]
	var r := Rect2(Vector2(rr.position) * SiatkaUI.KOM, Vector2(rr.size) * SiatkaUI.KOM)
	var t := gui.get_global_transform()
	return Rect2(t * r.position, t.basis_xform(r.size))


## Czy kursor jest nad slotami którejś otwartej kieszeni (każdy pojemnik: plecaki, worek, kamizelki).
func _nad_otwartymi_slotami(m: Vector2) -> bool:
	return _otwarte_sloty_pod(m).size.x > 0.0


## Prostokąt (ekran) slotów otwartej kieszeni pod punktem albo pusty.
func _otwarte_sloty_pod(m: Vector2) -> Rect2:
	for co in _kieszenie:
		if not _ramki.has(co) or not is_instance_valid(_ramki[co]) or not (_ramki[co] as Control).visible:
			continue
		var gui: SiatkaUI = _ramki[co].get_meta("siatka_ui", null)
		if gui == null:
			continue
		for e in _kieszenie[co]:
			var rk := _rect_kieszeni(gui, e)
			if bool(e["otwarta"]) and rk.grow(-1.0).has_point(m):
				return rk
	return Rect2()


## Droga uchwytu na ekranie dla kroku (zamknięte -> otwarte); gdy model jej nie pokazuje (worek, blend shape) –
## domyślna: suwak w bok na szerokość kieszeni, klapa w górę.
func _droga(co: String, i: int, k: int, f: float, rodz: String, e: Dictionary) -> Vector2:
	var d: Vector2 = _r3d.droga_kroku(co, i, k, f)
	if d.length() >= 36.0:
		return d.limit_length(260.0)
	if rodz == "x":
		var rr: Rect2i = e["r"]
		return Vector2(maxf(70.0, rr.size.x * SiatkaUI.KOM * 0.9), 0)
	return Vector2(0, -110)


## Kliknięcie: czy trafiło w uchwyt którejś kieszeni (do 24 px). Klamra – klik i gotowe; suwak / klapa – chwyt.
func _chwyc_uchwyt(m: Vector2) -> bool:
	var best := _uchwyt_pod(m)
	if best.is_empty():
		return false
	var co: String = best["co"]
	var i: int = best["i"]
	var e: Dictionary = _kieszenie[co][i]
	for x in _kieszenie[co]:
		if bool(x.get("w_toku", false)):
			return true
	if gracz and not gracz.akcja.is_empty():
		return true
	var zam := bool(e["otwarta"]) or bool(e.get("zamyk", false))
	if zam and bool(e["otwarta"]):
		# zapinanie: zawartość już niedostępna
		e["otwarta"] = false
		_r3d.oznacz(co, i, false)
	e["zamyk"] = zam
	var k := int(e.get("uchwyt_k", _krok_akt(e, co, i)))
	var pg: Array = _postep(e, co, i)
	var rodz: String = _r3d.rodzaj_kroku(co, i, k)
	var gui: SiatkaUI = _ramki[co].get_meta("siatka_ui", null) if _ramki.has(co) else null
	if rodz == "klik":
		pg[k] = 0.0 if zam else 1.0
		_r3d.krok_anim(co, i, k, not zam)
		Dzwiek.graj("klik", -8.0, randf_range(0.7, 0.85))
		if gracz:
			Gra.emituj_halas(gracz.global_position, 2.5, gracz)
		_sprawdz_koniec(gui, e, co, i)
		_podpowiedz(e, co, i)
		e.erase("kier_%d" % k)
		return true
	var kier := _droga(co, i, k, float(pg[k]), rodz, e)
	_gest = {"co": co, "i": i, "k": k, "zam": zam, "m0": m, "f0": float(pg[k]), "kier": kier, "t": Time.get_ticks_msec(), "ui": gui}
	_r3d.ustaw_krok(co, i, k, float(pg[k]))     # dłoń idzie do uchwytu
	Dzwiek.graj("szelest_0", -20.0, 1.3)
	return true


## Przeciąganie chwyconego uchwytu: postęp kroku to rzut ruchu myszy na drogę uchwytu. Tylko w jedną
## stronę (otwieranie dalej otwiera, zapinanie dalej zapina) – przeciągnięcie za daleko niczego nie cofa;
## dojście do końca kończy krok (dźwięk), następny krok trzeba chwycić osobno.
func _ciagnij_uchwyt(m: Vector2) -> void:
	var g := _gest
	var co: String = g["co"]
	var i: int = g["i"]
	var k: int = g["k"]
	var e: Dictionary = _kieszenie[co][i]
	var pg: Array = e["postep"]
	var kier: Vector2 = g["kier"]
	var f := float(g["f0"]) + (m - (g["m0"] as Vector2)).dot(kier) / maxf(1.0, kier.length_squared())
	var stary := float(pg[k])
	var zam: bool = g["zam"]
	f = minf(stary, clampf(f, 0.0, 1.0)) if zam else maxf(stary, clampf(f, 0.0, 1.0))
	if zam and f < 0.03:
		f = 0.0
	elif not zam and f > 0.97:
		f = 1.0
	if is_equal_approx(f, stary):
		return
	pg[k] = f
	_r3d.ustaw_krok(co, i, k, f)
	# dźwięk i hałas zależne od szybkości ruchu (rzep szarpnięty – głośno, powoli – cicho)
	var teraz := Time.get_ticks_msec()
	var dt := maxf(0.008, (teraz - int(g["t"])) / 1000.0)
	g["t"] = teraz
	var szybkosc := absf(f - stary) * kier.length() / dt
	e["dz_acc"] = float(e.get("dz_acc", 0.0)) + absf(f - stary)
	var dz: String = _r3d.dzwiek_kroku(co, i, k)
	if float(e["dz_acc"]) > 0.2:
		e["dz_acc"] = 0.0
		var gl := lerpf(-20.0, -5.0, clampf(szybkosc / 1500.0, 0.0, 1.0))
		match dz:
			"zamek":
				Dzwiek.graj("zamek", gl, randf_range(0.9, 1.15))
			"rzep":
				Dzwiek.graj("rzep", gl + 2.0, randf_range(0.9, 1.1))
			_:
				Dzwiek.graj("plecak", gl - 4.0, randf_range(1.1, 1.4))
		if gracz:
			Gra.emituj_halas(gracz.global_position, (1.0 + szybkosc / 300.0) * (1.6 if dz == "rzep" else 1.0), gracz)
	var koniec := (f >= 1.0 and not zam) or (f <= 0.0 and zam)
	if koniec:
		# krok domknięty: wyraźny dźwięk końca (suwak dojechał, klapa przylgnęła), chwyt puszczony
		match dz:
			"zamek":
				Dzwiek.graj("klik", -12.0, 1.35)
			"rzep":
				Dzwiek.graj("rzep", -9.0, 0.8)
			_:
				Dzwiek.graj("plecak", -11.0, 0.95)
		e.erase("kier_%d" % k)
		_gest = {}
		_sprawdz_koniec(g["ui"], e, co, i)
	_podpowiedz(e, co, i)
	if g["ui"] and is_instance_valid(g["ui"]):
		(g["ui"] as SiatkaUI).queue_redraw()


func _pusc_uchwyt() -> void:
	var g := _gest
	_gest = {}
	if g.has("ui") and g["ui"] and is_instance_valid(g["ui"]):
		(g["ui"] as SiatkaUI).queue_redraw()


## Tryb prosty (ustawienia): kliknięcie otwiera/zamyka całą kieszeń animacją, wolniej niż gestem.
func _proste() -> bool:
	return bool(Gra.ustawienia.get("proste_kieszenie", false)) or _r3d == null


func _postep(e: Dictionary, co: String, i: int) -> Array:
	if not e.has("postep"):
		var n: int = _r3d.liczba_krokow(co, i) if _r3d else 0
		var a := []
		for k in n:
			a.append(1.0 if bool(e["otwarta"]) else 0.0)
		e["postep"] = a
	return e["postep"]


func _krok_akt(e: Dictionary, co: String, i: int) -> int:
	var pg := _postep(e, co, i)
	if bool(e.get("zamyk", false)):
		for k in range(pg.size() - 1, -1, -1):
			if float(pg[k]) > 0.0:
				return k
	else:
		for k in pg.size():
			if float(pg[k]) < 1.0:
				return k
	return -1


func _podpowiedz(e: Dictionary, co: String, i: int) -> void:
	if _proste():
		e["podpowiedz"] = "kliknij – otwórz"
		return
	var k := _krok_akt(e, co, i)
	var zam: bool = e.get("zamyk", false)
	var t := "kliknij – otwórz"
	if k >= 0 and _r3d:
		match _r3d.rodzaj_kroku(co, i, k):
			"klik":
				t = "kliknij klamrę – zapnij" if zam else "kliknij klamrę – rozepnij"
			"x":
				t = "chwyć suwak i przeciągnij"
			_:
				t = "chwyć brzeg i dociśnij" if zam else "chwyć brzeg i odciągnij"
	e["podpowiedz"] = t
	var pg: Array = e.get("postep", [])
	var suma := 0.0
	for v in pg:
		suma += float(v)
	e["postep_calk"] = suma / maxf(1.0, pg.size())


func _gest_start(ui: SiatkaUI, i: int, zamykanie: bool, co: String) -> void:
	if not _kieszenie.has(co) or i < 0 or i >= (_kieszenie[co] as Array).size():
		return
	var e: Dictionary = _kieszenie[co][i]
	if bool(e.get("w_toku", false)):
		return
	if not _proste():
		# zapięcia otwiera się chwytając podświetlony uchwyt (suwak, klamrę, brzeg klapy), nie całą kieszeń
		ui._gest = -1
		_komunikat("Chwyć podświetlony suwak / klamrę i przeciągnij")
		return
	if _proste():
		if zamykanie:
			_zamknij_prosto(ui, i, co)
		else:
			_klik_kieszeni(ui, i, co)
		return
	_postep(e, co, i)
	if not zamykanie and bool(e.get("zamyk", false)):
		zamykanie = true
	e["zamyk"] = zamykanie
	if zamykanie and bool(e["otwarta"]):
		# zapinanie: zawartość już niedostępna
		e["otwarta"] = false
		if _r3d:
			_r3d.oznacz(co, i, false)
	_gest = {"co": co, "i": i, "t": Time.get_ticks_msec()}
	# krok „klik” (klamra, zatrzask) wykonuje się samym kliknięciem
	var k := _krok_akt(e, co, i)
	if k >= 0 and _r3d and _r3d.rodzaj_kroku(co, i, k) == "klik":
		e["postep"][k] = 0.0 if zamykanie else 1.0
		_r3d.krok_anim(co, i, k, not zamykanie)
		Dzwiek.graj("klik", -9.0, randf_range(0.7, 0.85))
		if gracz:
			Gra.emituj_halas(gracz.global_position, 2.5, gracz)
		_sprawdz_koniec(ui, e, co, i)
	_podpowiedz(e, co, i)
	ui.queue_redraw()


func _gest_ruch(ui: SiatkaUI, i: int, rel: Vector2, co: String) -> void:
	if _gest.is_empty() or _gest["co"] != co or _gest["i"] != i or _r3d == null:
		return
	var e: Dictionary = _kieszenie[co][i]
	var k := _krok_akt(e, co, i)
	if k < 0:
		return
	var rodz: String = _r3d.rodzaj_kroku(co, i, k)
	if rodz == "klik":
		return
	var zam: bool = e.get("zamyk", false)
	var dl := 110.0
	var amt := 0.0
	if rodz == "x":
		var rr: Rect2i = e["r"]
		dl = maxf(70.0, rr.size.x * SiatkaUI.KOM * 0.9)
		amt = absf(rel.x) / dl * (-1.0 if zam else 1.0)
	else:
		amt = -rel.y / dl
	var pg: Array = e["postep"]
	var stary := float(pg[k])
	pg[k] = clampf(stary + amt, 0.0, 1.0)
	_r3d.ustaw_krok(co, i, k, pg[k])
	# dźwięk i hałas zależne od szybkości ruchu (rzep szarpnięty – głośno, powoli – cicho)
	var teraz := Time.get_ticks_msec()
	var dt := maxf(0.008, (teraz - int(_gest["t"])) / 1000.0)
	_gest["t"] = teraz
	var szybkosc := rel.length() / dt
	e["dz_acc"] = float(e.get("dz_acc", 0.0)) + absf(float(pg[k]) - stary)
	if float(e["dz_acc"]) > 0.22:
		e["dz_acc"] = 0.0
		var dz: String = _r3d.dzwiek_kroku(co, i, k)
		var gl := lerpf(-20.0, -5.0, clampf(szybkosc / 1500.0, 0.0, 1.0))
		match dz:
			"zamek":
				Dzwiek.graj("zamek", gl, randf_range(0.9, 1.15))
			"rzep":
				Dzwiek.graj("rzep", gl + 2.0, randf_range(0.9, 1.1))
			_:
				Dzwiek.graj("plecak", gl - 4.0, randf_range(1.1, 1.4))
		if gracz:
			Gra.emituj_halas(gracz.global_position, (1.0 + szybkosc / 300.0) * (1.6 if dz == "rzep" else 1.0), gracz)
	_sprawdz_koniec(ui, e, co, i)
	_podpowiedz(e, co, i)
	ui.queue_redraw()


func _gest_koniec(ui: SiatkaUI, i: int, co: String) -> void:
	_gest = {}
	if is_instance_valid(ui):
		ui.queue_redraw()


func _sprawdz_koniec(ui: SiatkaUI, e: Dictionary, co: String, i: int) -> void:
	var pg: Array = e["postep"]
	var wszystkie := true
	var zadne := true
	for v in pg:
		if float(v) < 1.0:
			wszystkie = false
		if float(v) > 0.0:
			zadne = false
	if not bool(e.get("zamyk", false)) and wszystkie and not bool(e["otwarta"]):
		e["otwarta"] = true
		ekw.ustaw_kieszen(co, i, true)
		if _r3d:
			_r3d.oznacz(co, i, true)
		Dzwiek.graj("plecak", -10.0, 1.3)
		_gest = {}
		_komunikat(String(e["nazwa"]) + " – otwarta")
	elif bool(e.get("zamyk", false)) and zadne:
		e["zamyk"] = false
		ekw.ustaw_kieszen(co, i, false)
		Dzwiek.graj("plecak", -10.0, 1.05)
		Dzwiek.graj("klik", -15.0, 1.1)
		_gest = {}
		_komunikat(String(e["nazwa"]) + " – zapięta")


## Tryb prosty: zamknięcie całej kieszeni animacją (trwa).
func _zamknij_prosto(ui: SiatkaUI, i: int, co: String) -> void:
	var e: Dictionary = _kieszenie[co][i]
	if not bool(e["otwarta"]) or bool(e["w_toku"]):
		return
	e["otwarta"] = false
	e["w_toku"] = true
	var czas: float = _r3d.zamknij_kieszen(co, i) * 1.3 if _r3d else 0.3
	_zajmij(czas)
	ui.queue_redraw()
	get_tree().create_timer(maxf(0.1, czas)).timeout.connect(func():
		e["w_toku"] = false
		e.erase("postep")
		ekw.ustaw_kieszen(co, i, false)
		if is_instance_valid(ui):
			ui.queue_redraw())


func w_kolejce(p: Przedmiot) -> bool:
	for e in _kolejka:
		if e["p"] == p:
			return true
	return false


func _zajete() -> bool:
	return (_zajete_t > 0.0 or not _przekl.is_empty()) and not tryb_bazy


func _zajmij(t: float) -> void:
	if tryb_bazy or gracz == null:
		return
	_zajete_t = t
	_zajete_calk = t


## Czas przełożenia: drobiazg ułamek sekundy, karabin czy pancerz dłużej; zapinane ładownice wolniej.
func _koszt_przelozenia(p: Przedmiot, z: Dictionary, cel) -> float:
	var t := 0.14 + 0.045 * p.szer() * p.wys() + p.waga() * 0.025
	var kam := ekw.siatka_kamizelki()
	if kam != null and (cel == kam or (z.get("siatka") == kam)):
		t += 0.12
	if _jest_prawa(z.get("siatka")) and _pojemnik != null and String(_pojemnik.nazwa).begins_with("Zwłoki"):
		t += 0.1
	return clampf(t, 0.15, 1.1)


func _kolejka_krok(delta: float) -> void:
	if _zajete_t > 0.0:
		_zajete_t -= delta
	if _zajete_t > 0.0 or _kolejka.is_empty() or not _drag.is_empty() or not _przekl.is_empty():
		return
	var e: Dictionary = _kolejka.pop_front()
	var p: Przedmiot = e["p"]
	if not _w_zrodle(p, e["z"]):
		_odswiez()
		return
	var z: Dictionary = e["z"]
	var do_pojemnika := not _jest_prawa(z.get("siatka"))
	var cel_scr := _cel_kolejki(do_pojemnika)
	_animuj(p, z, cel_scr, func():
		if _w_zrodle(p, z):
			_przenies_teraz(p, z))
	if not _w_swiecie():
		_zajmij(_koszt_przelozenia(p, z, null))


## Gdzie na ekranie odkłada dłoń przy Ctrl+klik: do mebla / zwłok albo do własnego sprzętu.
func _cel_kolejki(do_pojemnika: bool) -> Vector2:
	if do_pojemnika:
		if _ramka_poj and is_instance_valid(_ramka_poj) and _ramka_poj.visible:
			return _ramka_poj.get_global_rect().get_center()
		return _pp.get_global_rect().get_center()
	for co in ["plecak", "kamizelka"]:
		var r: Control = _ramki.get(co)
		if r and is_instance_valid(r) and r.visible:
			return r.get_global_rect().get_center()
	for ui in _siatki:
		if is_instance_valid(ui) and ui.siatka == ekw.kieszenie:
			return ui.get_global_rect().get_center()
	return Vector2(200, 500)


## Odłożenie przedmiotu w konkretne miejsce na ziemi (kursor): leci tam z ręki i ląduje bez rzutu.
func _odloz_na_ziemie(p: Przedmiot, z: Dictionary, gdzie: Vector3) -> void:
	if _zajete():
		return
	if p.dane.get("oznaczony", false):
		_komunikat("★ Oznaczony – odznacz go (PPM), żeby odłożyć")
		_odswiez()
		return
	var cel_scr = _rzut(gdzie)
	_animuj(p, z, cel_scr if cel_scr != null else _root.get_global_mouse_position(), func():
		if _w_zrodle(p, z):
			_usun_ze_zrodla(p, z)
			gracz.poloz_na_ziemi(p, gdzie)
		_po_zmianie())


## Wyrzucenie: dłoń bierze przedmiot i upuszcza go przed sobą (spada z ręki na ziemię).
func _wyrzuc_reka(p: Przedmiot, z: Dictionary) -> void:
	if _zajete():
		return
	if p.dane.get("oznaczony", false):
		_komunikat("★ Oznaczony – odznacz go (PPM), żeby wyrzucić")
		_odswiez()
		return
	var cel := Vector2(_root.size.x * 0.62, _root.size.y * 0.92)
	_animuj(p, z, cel, func():
		if _w_zrodle(p, z):
			_usun_ze_zrodla(p, z)
			gracz.upusc(p)
		_po_zmianie())


## Narzędzie pod ręką (a w schronie także w skrytce).
func _znajdz_narzedzie(pid: String) -> Przedmiot:
	var zr: Array = ekw.siatki_pod_reka()
	if tryb_bazy:
		zr.append(Gra.skrytka)
	for s2 in zr:
		for e in (s2 as Siatka).items:
			if (e["p"] as Przedmiot).id == pid:
				return e["p"]
	return null


## Czynność z narzędziem (czyszczenie broni, owijanie taśmą): zużywa jedno użycie, trwa, z animacją.
func _uzyj_narzedzia(p: Przedmiot, pid: String, czas: float, nazwa: String, efekt: Callable) -> void:
	var n := _znajdz_narzedzie(pid)
	if n == null:
		_komunikat("Brak: " + Dane.nazwa(pid).to_lower())
		return
	var zuzyj := func():
		var u := int(n.dane.get("uzycia", int(n.defn().get("uzycia", 1)))) - 1
		n.dane["uzycia"] = u
		if u <= 0:
			if not ekw.usun_przedmiot(n) and tryb_bazy:
				Gra.skrytka.usun(n)
			_komunikat(n.nazwa() + " – zużyte")
		efekt.call()
		ekw.zmieniony.emit()
		_odswiez()
	if tryb_bazy or gracz == null:
		zuzyj.call()
		return
	if not gracz.akcja.is_empty() or _zajete():
		return
	gracz.zacznij_akcje(nazwa + ": " + p.nazwa(), czas, zuzyj, "ogladaj", 0, Callable(), {"id": p.id})


## Obejrzenie nieznanego przedmiotu: dłoń obraca go przed oczami (trwa), po ciemku się nie da.
func _obejrzyj(p: Przedmiot) -> void:
	if not p.nieznany():
		return
	if tryb_bazy or gracz == null:
		p.dane.erase("nieznany")
		_odswiez()
		return
	if not gracz.akcja.is_empty() or _zajete():
		return
	var sc = get_tree().get_first_node_in_group("ui_rajdu")
	var swiatlo: float = sc.oswietlenie(gracz.kamera.global_position - gracz.kamera.global_basis.z * 0.4) if sc and sc.has_method("oswietlenie") else 1.0
	if swiatlo < 0.3:
		_komunikat("Za ciemno – poświeć latarką, żeby obejrzeć")
		return
	var czas := 1.2 + p.szer() * p.wys() * 0.15
	gracz.zacznij_akcje("Oglądanie: " + p.nazwa(), czas, func():
		p.dane.erase("nieznany")
		gracz.komunikat.emit("To " + p.nazwa().to_lower() + " (%d bonów)" % p.wartosc())
		Dzwiek.graj("klik", -12.0, 0.9)
		_odswiez()
		, "ogladaj", 0, Callable(), {"id": p.id})


## Podział stosu na pół (Shift+klik): druga połowa w wolnym miejscu tej samej siatki.
func _podziel(p: Przedmiot, s: Siatka) -> void:
	var n := p.ilosc / 2
	if n <= 0:
		return
	var q := Przedmiot.nowy(p.id, n)
	var m := s.wolne_miejsce(q)
	if m.is_empty():
		_komunikat("Brak miejsca na podział stosu")
		return
	p.ilosc -= n
	s.poloz(q, m["x"], m["y"], m["rot"])
	Dzwiek.graj("klik", -12.0, 1.2)
	_po_zmianie()


## Do własnego ekwipunku, ale przy rozłożonym plecaku tylko do otwartych kieszeni (zapiętych nie widać).
func _dodaj_do_otwartych(p: Przedmiot) -> bool:
	_synchronizuj_dostep()
	return ekw.dodaj(p)

func _przenies_teraz(p: Przedmiot, z: Dictionary) -> void:
	var z_prawej: bool = z["typ"] == "siatka" and _jest_prawa(z["siatka"])
	if z_prawej and _czesc_zdejmowana(z["siatka"]):
		_zdejmij_z_ciala(p, z["siatka"])
		return
	if z_prawej:
		_usun_ze_zrodla(p, z)
		if not _dodaj_do_otwartych(p):
			(z["siatka"] as Siatka).dodaj(p)
			_komunikat("Brak miejsca pod ręką – zdejmij plecak i otwórz kieszeń, żeby włożyć do środka" if ekw.ograniczony and not ekw.plecak_rozlozony and ekw.siatka_plecaka() != null else "Brak miejsca w ekwipunku")
		else:
			Dzwiek.graj("podnies", -8.0)
	elif _prawa_siatka != null:
		# do mebla / zwłok: pierwsza część z miejscem (kieszenie kurtki, spodni, chlebak – nie „na ciele”)
		var cele := [_prawa_siatka]
		if _pojemnik != null and is_instance_valid(_pojemnik):
			cele = _pojemnik.lista_czesci().filter(func(c): return not c.get("zdejmowane", false)).map(func(c): return c["siatka"])
		for sg in cele:
			var m := (sg as Siatka).wolne_miejsce(p)
			if m.is_empty():
				continue
			_usun_ze_zrodla(p, z)
			(sg as Siatka).poloz(p, m["x"], m["y"], m["rot"])
			if _pojemnik and is_instance_valid(_pojemnik):
				_pojemnik.poznaj(p)
			if not _w_swiecie():
				Dzwiek.graj("odloz", -8.0)
			_po_zmianie()
			return
		_komunikat("Brak miejsca: " + (_pojemnik.nazwa if _pojemnik else _prawy_tytul.text).to_lower())
		return
	_po_zmianie()


# ------------------------------------------------------------------ menu kontekstowe

enum { M_UZYJ, M_ROZLADUJ, M_NAPELNIJ, M_WYJMIJ_MAG, M_ZALOZ, M_ZDEJMIJ, M_WYRZUC, M_WEZ, M_SPRZEDAJ, M_LATARKA, M_OGLADAJ, M_PODZIEL, M_OBEJRZYJ, M_OZNACZ, M_SPRAWDZ, M_CZYSC, M_TASMA, M_JEDZ }
const M_DOD := 100
const M_ELAB := 200          # + indeks przepisu
const M_NAPRAW_PANC := 300
const M_SPRAY := 400         # + rodzaj znaku
const M_PULAPKA := 500
const M_POTYKACZ := 510
const ZNAKI_SPRAYU := [["Maluj na ścianie: strzałka →", "gracz_strzalka_p"], ["Maluj na ścianie: ← strzałka", "gracz_strzalka_l"],
	["Maluj na ścianie: krzyżyk (tu byłem)", "gracz_krzyzyk"], ["Maluj na ścianie: wykrzyknik (uwaga)", "gracz_wykrzyknik"]]

## Elaboracja przy stole roboczym: [kaliber (amunicja), sztuk, puszek prochu].
const PRZEPISY := [["a_9x18", 20, 1], ["a_12", 10, 1], ["a_762", 15, 2]]


func _pokaz_menu(p: Przedmiot, z: Dictionary, pos: Vector2) -> void:
	_menu.clear()
	_menu_p = p
	_menu_zrodlo = z
	var t := p.typ()
	if p.nieznany():
		_menu.add_item("Obejrzyj", M_OBEJRZYJ)
	if t == "med" and not tryb_bazy and gracz:
		_menu.add_item("Użyj", M_UZYJ)
	if p.defn().has("jedzenie") and not p.nieznany() and (gracz or tryb_bazy):
		_menu.add_item("Wypij" if p.defn()["jedzenie"].get("picie", false) else "Zjedz", M_JEDZ)
	if t == "latarka" and not tryb_bazy and gracz:
		_menu.add_item("Weź do ręki [L]", M_LATARKA)
	if t == "magazynek":
		_menu.add_item("Napełnij", M_NAPELNIJ)
		if p.dane["naboje"] > 0:
			_menu.add_item("Rozładuj", M_ROZLADUJ)
	if p.stos_max() > 1 and p.ilosc > 1 and z["typ"] == "siatka":
		_menu.add_item("Podziel stos [Shift]", M_PODZIEL)
	if t == "magazynek" and not bool(p.dane.get("sprawdzony", true)):
		_menu.add_item("Przelicz naboje", M_SPRAWDZ)
	_menu.add_item("Odznacz ★" if p.dane.get("oznaczony", false) else "Oznacz ★", M_OZNACZ)
	if t == "bron" and float(p.dane.get("stan", 100.0)) < 99.0:
		_menu.add_item("Wyczyść (zestaw)" if _znajdz_narzedzie("zestaw_czyszczacy") != null else "Wyczyść (brak zestawu)", M_CZYSC)
	if (t in Ekwipunek.METAL_LUZEM or p.id in Ekwipunek.METAL_LUP) and not p.dane.get("wyciszony", false) and t != "bron":
		_menu.add_item("Owiń taśmą" if _znajdz_narzedzie("tasma") != null else "Owiń taśmą (brak taśmy)", M_TASMA)
	if t == "bron" and gracz:
		_menu.add_item("Oglądaj / dodatki", M_OGLADAJ)
	if t == "bron":
		if p.dane.get("mag") != null:
			_menu.add_item("Wyjmij magazynek", M_WYJMIJ_MAG)
		for i in Przedmiot.SLOTY_DODATKOW.size():
			var dd: Przedmiot = p.dodatek(Przedmiot.SLOTY_DODATKOW[i])
			if dd != null:
				var warsz: bool = dd.defn()["dodatek"]["montaz"] == "warsztat"
				_menu.add_item("Zdejmij: %s%s" % [dd.nazwa(), " (stół roboczy)" if warsz and not _warsztat else ""], M_DOD + i)
		if p.dane.get("wewn", 0) > 0 or p.dane.get("komora", "") != "":
			_menu.add_item("Rozładuj", M_ROZLADUJ)
	# granat + szklanka: pułapka na klamce zamkniętych drzwi przed sobą
	if p.id == "granat_f1" and not tryb_bazy and gracz:
		_menu.add_item("Zastaw pułapkę na drzwiach (szklanka)" if _znajdz_narzedzie("szklanka") != null else "Pułapka na drzwiach (brak szklanki)", M_PULAPKA)
		_menu.set_item_disabled(_menu.item_count - 1, _znajdz_narzedzie("szklanka") == null)
		_menu.add_item("Rozciągnij potykacz w poprzek przejścia (drut)" if _znajdz_narzedzie("drut") != null else "Potykacz (brak drutu)", M_POTYKACZ)
		_menu.set_item_disabled(_menu.item_count - 1, _znajdz_narzedzie("drut") == null)
	# puszka sprayu: znak na ścianie przed sobą (w rajdzie)
	if p.id == "farba_spray" and not tryb_bazy and gracz:
		for i in ZNAKI_SPRAYU.size():
			_menu.add_item(ZNAKI_SPRAYU[i][0], M_SPRAY + i)
	# stół roboczy: elaboracja (na prasie) i naprawa pancerza (tkaniną balistyczną)
	if p.id == "prasa_elaboracyjna":
		for i in PRZEPISY.size():
			var pr: Array = PRZEPISY[i]
			_menu.add_item("Elaboruj: %s ×%d (%d × proch)" % [Dane.nazwa(pr[0]), pr[1], pr[2]], M_ELAB + i)
			_menu.set_item_disabled(_menu.item_count - 1, not _warsztat or _ile_materialu("proch") < int(pr[2]))
		if not _warsztat:
			_menu.add_item("(elaboracja tylko przy stole roboczym)", M_ELAB + 99)
			_menu.set_item_disabled(_menu.item_count - 1, true)
	if t == "pancerz" and float(p.dane.get("wytrz", 0.0)) < _maks_pancerza(p) - 0.5:
		_menu.add_item("Napraw (tkanina balistyczna)%s" % ("" if _warsztat else " – przy stole roboczym"), M_NAPRAW_PANC)
		_menu.set_item_disabled(_menu.item_count - 1, not _warsztat or _ile_materialu("tkanina_balistyczna") < 1)
	if z["typ"] == "slot":
		_menu.add_item("Zdejmij", M_ZDEJMIJ)
	elif Ekwipunek.slot_dla(p) != "":
		_menu.add_item("Załóż", M_ZALOZ)
	if z["typ"] == "siatka" and _jest_prawa(z["siatka"]):
		_menu.add_item("Zdejmij z ciała" if _czesc_zdejmowana(z["siatka"]) else "Weź", M_WEZ)
	if not tryb_bazy and gracz and not (z["typ"] == "siatka" and _jest_prawa(z["siatka"])):
		_menu.add_item("Wyrzuć", M_WYRZUC)
	if _menu.item_count == 0:
		return
	_menu.position = Vector2i(pos)
	_menu.reset_size()
	_menu.popup()


## Ile sztuk materiału jest pod ręką (w bazie: także w skrytce).
func _ile_materialu(pid: String) -> int:
	var n := 0
	var zr: Array = ekw.siatki_pod_reka()
	if tryb_bazy:
		zr.append(Gra.skrytka)
	for s2 in zr:
		n += (s2 as Siatka).policz(pid)
	return n


func _zabierz_material(pid: String, ile: int) -> bool:
	if _ile_materialu(pid) < ile:
		return false
	var zr: Array = ekw.siatki_pod_reka()
	if tryb_bazy:
		zr.insert(0, Gra.skrytka)
	for s2 in zr:
		ile -= (s2 as Siatka).zabierz(pid, ile)
		if ile <= 0:
			break
	return true


## Pułapka: zamknięte drzwi na wprost (do 1,8 m), granat i szklanka pod ręką. Zawleczka wyciągnięta na końcu –
## przerwanie wcześniej nic nie psuje.
func _zastaw_pulapke(granat: Przedmiot) -> void:
	var kam: Camera3D = gracz.kamera
	var od := kam.global_position
	var q := PhysicsRayQueryParameters3D.create(od, od - kam.global_basis.z * 1.8, Balistyka.WARSTWA_SWIAT)
	var r := gracz.get_world_3d().direct_space_state.intersect_ray(q)
	var d: Drzwi = (r["collider"] as Node).get_meta("drzwi") if not r.is_empty() and (r["collider"] as Node).has_meta("drzwi") else null
	if d == null or not d.zamkniete() or d.wywazone:
		_komunikat("Stań przy zamkniętych drzwiach, przodem do klamki.")
		return
	if d.pulapka != null:
		_komunikat("Na tej klamce już coś wisi.")
		return
	var szk := _znajdz_narzedzie("szklanka")
	if szk == null:
		_komunikat("Potrzebna szklanka.")
		return
	if not gracz.akcja.is_empty() or _zajete():
		return
	var strona := 1.0 if (gracz.global_position - d.global_position).dot(d.global_basis.z) > 0.0 else -1.0
	zamknij()
	# szkło o klamkę, zawleczka: cicho, ale słychać (kucając ciszej)
	Gra.emituj_halas(gracz.global_position, 1.5 if gracz.kucanie > 0.5 else 3.0, gracz)
	gracz.zacznij_akcje("Pułapka: granat w szklance", 5.0, func():
		if d.pulapka != null or not d.zamkniete():
			_komunikat("Drzwi się ruszyły – nie da się.")
			return
		if not ekw.usun_przedmiot(granat) or not ekw.usun_przedmiot(szk):
			return
		Dzwiek.graj_3d("zawleczka", d.global_position + Vector3.UP, gracz.get_parent(), -8.0)
		Pulapka.zastaw(d, gracz, strona)
		_komunikat("Zawleczka w kieszeni. Ktokolwiek otworzy te drzwi, zrzuci szklankę."), "otwieranie", 0, Callable(), {"id": "drzwi"})


## Potykacz: drut w poprzek przejścia tuż przed graczem (kołki przy obu ścianach, do 4,5 m), granat przy lewym kołku.
func _rozciagnij_potykacz(granat: Przedmiot) -> void:
	var drut := _znajdz_narzedzie("drut")
	if drut == null:
		_komunikat("Drut z kołkami musi być pod ręką.")
		return
	if not gracz.akcja.is_empty() or _zajete():
		return
	var space := gracz.get_world_3d().direct_space_state
	var przod := -gracz.global_basis.z
	przod.y = 0.0
	przod = przod.normalized()
	var bok := przod.cross(Vector3.UP).normalized()
	var o := gracz.global_position + przod * 0.7 + Vector3.UP * 0.15
	var konce := []
	for s in [-1.0, 1.0]:
		var q := PhysicsRayQueryParameters3D.create(o, o + bok * s * 2.6, Balistyka.WARSTWA_SWIAT)
		var r := space.intersect_ray(q)
		if r.is_empty():
			_komunikat("Potykacz rozciąga się między ścianami – tu nie ma o co zaczepić (najwyżej 5 m przejścia).")
			return
		konce.append((r["position"] as Vector3) + (r["normal"] as Vector3) * 0.04 + Vector3.DOWN * 0.15)
	var a: Vector3 = konce[0]
	var b: Vector3 = konce[1]
	if a.distance_to(b) < 0.6:
		_komunikat("Za ciasno na drut.")
		return
	zamknij()
	Gra.emituj_halas(gracz.global_position, 2.0 if gracz.kucanie > 0.5 else 4.0, gracz)   # kołki wbijane w szczeliny
	gracz.zacznij_akcje("Potykacz: kołki, drut, zawleczka", 7.0, func():
		if not ekw.usun_przedmiot(granat) or not ekw.usun_przedmiot(drut):
			return
		Dzwiek.graj_3d("zawleczka", a + Vector3.UP * 0.1, gracz.get_parent(), -10.0)
		Potykacz.rozciagnij(gracz.get_parent(), a, b, gracz)
		_komunikat("Drut napięty na wysokości kostek – teraz uważaj, którędy wracasz."), "otwieranie", 0, Callable(), {"id": "drzwi"})


## Spray: ściana na wprost (do 2,6 m) – znak zostaje do końca rajdu. Trwa chwilę i syczy (słychać).
func _maluj(id: String) -> void:
	var kam: Camera3D = gracz.kamera
	var od := kam.global_position
	var q := PhysicsRayQueryParameters3D.create(od, od - kam.global_basis.z * 2.6, Balistyka.WARSTWA_SWIAT)
	var r := gracz.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty() or not String((r["collider"] as Node).name).begins_with("Sciany") or absf((r["normal"] as Vector3).y) > 0.3:
		_komunikat("Stań przodem do ściany (najwyżej 2,5 m).")
		return
	var pos: Vector3 = r["position"]
	var nrm: Vector3 = r["normal"]
	var puszka := _znajdz_narzedzie("farba_spray")
	if puszka == null:
		_komunikat("Puszka musi być pod ręką (kamizelka, kieszenie).")
		return
	_uzyj_narzedzia(puszka, "farba_spray", 1.6, "Malowanie", func():
		var warstwy := 0
		var sr = get_tree().get_first_node_in_group("ui_rajdu")
		if sr and sr.has_method("warstwy_dla"):
			warstwy = sr.warstwy_dla(pos)
		Naklejki.znak_gracza(gracz.get_parent(), pos, nrm, id, warstwy)
		Gra.emituj_halas(pos, 4.0, gracz)
		Dzwiek.graj_3d("szelest_1", pos, gracz.get_parent(), -2.0, 1.4)
		_komunikat("Namalowane."))


## Górna granica wytrzymałości pancerza: każda naprawa tkaniną zabiera 10% (łata nigdy nie jest jak nowa).
static func _maks_pancerza(p: Przedmiot) -> float:
	return float(p.dane.get("maks_wytrz", float(p.defn()["pancerz"]["wytrzymalosc"])))


func _elaboruj(prasa: Przedmiot, i: int) -> void:
	var pr: Array = PRZEPISY[i]
	if not _warsztat or not _zabierz_material("proch", int(pr[2])):
		_komunikat("Za mało prochu.")
		return
	var u := int(prasa.dane.get("uzycia", int(prasa.defn().get("uzycia", 1)))) - 1
	prasa.dane["uzycia"] = u
	if u <= 0:
		if not ekw.usun_przedmiot(prasa):
			Gra.skrytka.usun(prasa)
		_komunikat("Prasa się rozsypała – matryce do wymiany.")
	var naboje := Przedmiot.nowy(String(pr[0]), int(pr[1]))
	if not Gra.skrytka.dodaj(naboje) and not ekw.dodaj(naboje):
		_komunikat("Brak miejsca na naboje.")
		return
	Dzwiek.graj("naboj_wloz", -4.0)
	_komunikat("Elaboracja: %s ×%d do skrytki." % [Dane.nazwa(pr[0]), int(pr[1])])
	ekw.zmieniony.emit()
	_odswiez()


func _napraw_pancerz(p: Przedmiot) -> void:
	if not _warsztat or not _zabierz_material("tkanina_balistyczna", 1):
		_komunikat("Brak tkaniny balistycznej.")
		return
	var nowe_maks := _maks_pancerza(p) * 0.9
	p.dane["maks_wytrz"] = nowe_maks
	p.dane["wytrz"] = nowe_maks
	Dzwiek.graj("rzep", -4.0)
	_komunikat("%s połatany: %d/%d." % [p.nazwa(), int(nowe_maks), int(p.defn()["pancerz"]["wytrzymalosc"])])
	ekw.zmieniony.emit()
	_odswiez()


func _menu_akcja(id: int) -> void:
	var p := _menu_p
	var z := _menu_zrodlo
	if p == null:
		return
	if id >= M_ELAB and id < M_ELAB + PRZEPISY.size():
		_elaboruj(p, id - M_ELAB)
		return
	if id == M_NAPRAW_PANC:
		_napraw_pancerz(p)
		return
	if id == M_PULAPKA:
		_zastaw_pulapke(p)
		return
	if id == M_POTYKACZ:
		_rozciagnij_potykacz(p)
		return
	if id >= M_SPRAY and id < M_SPRAY + ZNAKI_SPRAYU.size():
		_maluj(String(ZNAKI_SPRAYU[id - M_SPRAY][1]))
		return
	match id:
		M_JEDZ:
			if tryb_bazy or gracz == null:
				var opis := Gra.spozyj(p)
				if z["typ"] == "siatka":
					(z["siatka"] as Siatka).usun(p)
				else:
					ekw.usun_przedmiot(p)
				Dzwiek.graj("odloz", -10.0, 1.3)
				if gracz:
					gracz.komunikat.emit(opis)
				_odswiez()
			else:
				_po_schowaniu(func(): gracz.spozyj(p))
		M_UZYJ:
			var szybki: bool = not (z["typ"] == "siatka" and z["siatka"] == ekw.siatka_plecaka())
			_po_schowaniu(func(): gracz.uzyj_leku(p, szybki))
		M_NAPELNIJ:
			_seria_mag = false
			_napelnij(p, null, {})
		M_LATARKA:
			if gracz:
				gracz.wez_latarke()
				zamknij()
				return
		M_ROZLADUJ:
			_rozladuj(p)
		M_DOD, M_DOD + 1, M_DOD + 2, M_DOD + 3:
			_zdejmij_dodatek(p, Przedmiot.SLOTY_DODATKOW[id - M_DOD])
			return
		M_OGLADAJ:
			# broń do rąk (jeśli jest w slocie), schowanie sprzętu, potem podgląd z bliska
			for sl in ["glowna", "pistolet"]:
				if ekw.sloty[sl] == p and gracz.bron.przedmiot != p:
					gracz.latarka_w_rece = false
					gracz._wybierz_bron(sl)
			if gracz.bron.przedmiot == p:
				zamknij_animowany(func(): _ogl_ui.otworz())
			else:
				_komunikat("Załóż broń na slot, żeby ją obejrzeć")
			return
		M_WYJMIJ_MAG:
			var m: Przedmiot = p.dane["mag"]
			p.dane["mag"] = null
			if not ekw.dodaj(m) and not (_prawa_siatka and _prawa_siatka.dodaj(m)):
				p.dane["mag"] = m
				_komunikat("Brak miejsca na magazynek")
		M_ZALOZ:
			var slot := Ekwipunek.slot_dla(p)
			if slot == "pistolet" and ekw.sloty["pistolet"] != null and ekw.sloty["glowna"] == null:
				slot = "glowna"
			_na_slot(p, z, slot)
		M_ZDEJMIJ:
			var sl: String = z["slot"]
			ekw.zdejmij(sl)
			if not ekw.dodaj(p) and not (_prawa_siatka and _prawa_siatka.dodaj(p)):
				ekw.zaloz(sl, p)
				_komunikat("Brak miejsca")
		M_PODZIEL:
			_podziel(p, z["siatka"])
			return
		M_OBEJRZYJ:
			_obejrzyj(p)
			return
		M_CZYSC:
			_uzyj_narzedzia(p, "zestaw_czyszczacy", 6.0, "Czyszczenie", func():
				p.dane["stan"] = minf(100.0, float(p.dane.get("stan", 100.0)) + 45.0)
				p.dane["brud"] = 0.0
				p.dane["zaciecie"] = false
				_komunikat("Broń wyczyszczona: %d%%" % int(p.dane["stan"])))
			return
		M_TASMA:
			_uzyj_narzedzia(p, "tasma", 2.0, "Owijanie taśmą", func():
				p.dane["wyciszony"] = true
				ekw._brzek = -1.0
				_komunikat("Owinięte taśmą – nie będzie brzęczeć"))
			return
		M_OZNACZ:
			if p.dane.get("oznaczony", false):
				p.dane.erase("oznaczony")
			else:
				p.dane["oznaczony"] = true
			_odswiez()
			return
		M_SPRAWDZ:
			if tryb_bazy or gracz == null:
				p.dane["sprawdzony"] = true
				_odswiez()
				return
			if not gracz.akcja.is_empty():
				return
			gracz.zacznij_akcje("Przeliczanie: " + p.nazwa(), 1.4, func():
				p.dane["sprawdzony"] = true
				gracz.komunikat.emit("%s: %d nab." % [p.nazwa(), int(p.dane["naboje"])])
				_odswiez()
				, "rozladowanie", 0, Callable(), {"id": p.id, "amun": String(p.dane.get("amunicja", "a_762"))})
			return
		M_WEZ:
			if z["typ"] == "siatka" and _czesc_zdejmowana(z["siatka"]):
				_zdejmij_z_ciala(p, z["siatka"])
				return
			_szybkie_przeniesienie(p, z)
			return
		M_WYRZUC:
			_wyrzuc_reka(p, z)
			return
	_po_zmianie()


# ------------------------------------------------------------------ amunicja

## Napełnia magazynek: z podanego stosu albo z dowolnej pasującej amunicji w ekwipunku (i skrytce w bazie).
func _napelnij(mag: Przedmiot, stos: Przedmiot, z_stosu: Dictionary) -> bool:
	if gracz != null and not tryb_bazy and not gracz.akcja.is_empty():
		gracz.zaplanuj(mag.nazwa(), func(): _napelnij(mag, stos, z_stosu))
		return true
	var md: Dictionary = mag.defn()["magazynek"]
	var wolne: int = int(md["pojemnosc"]) - int(mag.dane["naboje"])
	if wolne <= 0:
		_komunikat("Magazynek jest pełny")
		return true
	var kal: String = md["kaliber"]
	if stos != null:
		if stos.defn()["amunicja"]["kaliber"] != kal:
			_komunikat("Niewłaściwy kaliber (%s)" % kal)
			return true
		if mag.dane["naboje"] > 0 and mag.dane["amunicja"] != stos.id:
			_komunikat("W magazynku jest inna amunicja – najpierw rozładuj")
			return true
		var ile: int = mini(wolne, stos.ilosc)
		_zaplanuj_ladowanie(mag, stos.id, ile, func(n: int) -> int:
			var w: int = mini(n, stos.ilosc)
			stos.ilosc -= w
			if stos.ilosc <= 0:
				_usun_ze_zrodla(stos, z_stosu)
			return w)
		return true
	# z ekwipunku / skrytki (w rajdzie tylko spod ręki: kamizelka, kieszenie, otwarte kieszenie plecaka)
	var zrodla := ekw.siatki_pod_reka()
	if tryb_bazy:
		zrodla.append(Gra.skrytka)
	var typ: String = mag.dane["amunicja"] if mag.dane["naboje"] > 0 else ""
	for s in zrodla:
		for e in (s as Siatka).items:
			if not ekw.odkryty(s, e):
				continue
			var a: Przedmiot = e["p"]
			if a.typ() == "amunicja" and a.defn()["amunicja"]["kaliber"] == kal and (typ == "" or a.id == typ):
				var ile2: int = mini(wolne, a.ilosc)
				var siatka_a: Siatka = s
				_zaplanuj_ladowanie(mag, a.id, ile2, func(n: int) -> int:
					return siatka_a.zabierz(a.id, n))
				return true
	_komunikat("Brak amunicji %s" % kal)
	return true


## Ładowanie nabój po naboju (jak w Wardogs): każdy nabój to krok akcji z dźwiękiem.
## Przerwanie zostawia w magazynku to, co już włożono. zabierz(n) -> ile faktycznie zabrano.
func _zaplanuj_ladowanie(mag: Przedmiot, amun: String, ile: int, zabierz: Callable) -> void:
	if tryb_bazy or gracz == null:
		var w: int = zabierz.call(ile)
		mag.dane["amunicja"] = amun
		mag.dane["naboje"] += w
		ekw.zmieniony.emit()
		_odswiez()
		Dzwiek.graj("klik", -10.0)
		return
	var na_krok := func():
		if int(zabierz.call(1)) <= 0:
			gracz.przerwij_akcje(true)
			return
		mag.dane["amunicja"] = amun
		mag.dane["naboje"] += 1
		mag.dane["sprawdzony"] = true     # liczysz wkładane naboje
		Dzwiek.graj("klik", -12.0, randf_range(1.1, 1.3))
		ekw.zmieniony.emit()
	var koniec := func():
		Dzwiek.graj("napelnianie", -10.0)
		if _seria_mag:
			napelnij_wszystkie()
	var start := func():
		gracz.zacznij_akcje(mag.nazwa(), 0.42 * ile, koniec, "magazynek", ile, na_krok, {"id": mag.id, "amun": amun})
	_po_schowaniu(start)


func napelnij_wszystkie() -> void:
	var mags := []
	var zrodla := ekw.siatki_pod_reka()
	if tryb_bazy:
		zrodla.append(Gra.skrytka)
	for s in zrodla:
		for e in (s as Siatka).items:
			if not ekw.odkryty(s, e):
				continue
			var m: Przedmiot = e["p"]
			if m.typ() == "magazynek" and m.dane["naboje"] < int(m.defn()["magazynek"]["pojemnosc"]):
				mags.append(m)
	if mags.is_empty():
		_komunikat("Wszystkie magazynki są pełne")
		return
	if tryb_bazy or gracz == null:
		for m in mags:
			_napelnij(m, null, {})
		_odswiez()
		return
	# w rajdzie: po kolei, każdy jako akcja; kolejny startuje po zakończeniu poprzedniego
	if gracz.akcja.is_empty():
		_seria_mag = true
		_napelnij(mags[0], null, {})
		if gracz.akcja.is_empty():
			_seria_mag = false


func _rozladuj(p: Przedmiot) -> void:
	var amun := ""
	var n := 0
	if p.typ() == "magazynek":
		amun = p.dane["amunicja"]
		n = p.dane["naboje"]
	elif p.typ() == "bron":
		if p.dane["wewn"] > 0:
			amun = p.dane["wewn_typ"]
			n = p.dane["wewn"]
		if p.dane["komora"] != "":
			amun = p.dane["komora"]
			n += 1
	if n <= 0 or amun == "":
		return
	if tryb_bazy or gracz == null:
		_wyjmij_naboje(p, n)
		var a := Przedmiot.nowy(amun, n)
		if not ekw.dodaj(a) and not (_prawa_siatka and _prawa_siatka.dodaj(a)):
			if gracz:
				gracz.upusc(a)
		Dzwiek.graj("klik", -10.0)
		_odswiez()
		return
	if not gracz.akcja.is_empty():
		_komunikat("Najpierw skończ: " + String(gracz.akcja["nazwa"]) + "  [X] przerywa")
		return
	# w rajdzie: nabój po naboju (kciuk zsuwa nabój z wargi magazynka), szybciej niż napełnianie;
	# przerwanie zostawia resztę w magazynku. Naboje do ekwipunku, a gdy brak miejsca – pod nogi.
	var stan := {"ziemia": null}
	var prawa: Siatka = null
	var na_krok := func():
		var typ_n: String = amun
		if p.typ() == "magazynek":
			if int(p.dane["naboje"]) <= 0:
				gracz.przerwij_akcje()
				return
			p.dane["naboje"] = int(p.dane["naboje"]) - 1
			p.dane["sprawdzony"] = true
			if int(p.dane["naboje"]) <= 0:
				p.dane["amunicja"] = ""
		else:
			if p.dane["komora"] != "":
				typ_n = p.dane["komora"]
				p.dane["komora"] = ""
			elif int(p.dane["wewn"]) > 0:
				typ_n = p.dane["wewn_typ"]
				p.dane["wewn"] = int(p.dane["wewn"]) - 1
			else:
				gracz.przerwij_akcje()
				return
		var a := Przedmiot.nowy(typ_n, 1)
		if not ekw.dodaj(a) and not (prawa and prawa.dodaj(a)):
			var lz = stan["ziemia"]
			if lz != null and is_instance_valid(lz) and (lz as LupNaZiemi).przedmiot.id == typ_n:
				(lz as LupNaZiemi).przedmiot.ilosc += 1
			else:
				stan["ziemia"] = gracz.upusc(a)
		Dzwiek.graj("klik", -14.0, randf_range(1.3, 1.5))
		ekw.zmieniony.emit()
	var koniec := func():
		Dzwiek.graj("klik", -10.0, 0.9)
	var start := func():
		gracz.zacznij_akcje("Rozładowywanie: " + p.nazwa(), 0.24 * n if p.typ() == "magazynek" else 0.4 * n, koniec, "rozladowanie", n, na_krok, {"id": p.id, "amun": amun})
	_po_schowaniu(start)


func _wyjmij_naboje(p: Przedmiot, _n: int) -> void:
	if p.typ() == "magazynek":
		p.dane["naboje"] = 0
		p.dane["amunicja"] = ""
	else:
		p.dane["wewn"] = 0
		p.dane["komora"] = ""


# ------------------------------------------------------------------ podpowiedzi

## Wyrzuca przedmiot na ziemię (rajd). Szuka, gdzie leży.
func _wyrzuc(p: Przedmiot) -> void:
	if tryb_bazy or gracz == null:
		_komunikat("W schronie nic nie wyrzucasz – sprzedaj handlarzowi")
		return
	var z := {}
	for sl in Ekwipunek.SLOTY:
		if ekw.sloty[sl] == p:
			z = {"typ": "slot", "slot": sl}
	for s in ekw.siatki():
		if (s as Siatka).zawiera(p):
			z = {"typ": "siatka", "siatka": s}
	if z.is_empty():
		return
	_hover_p = null
	_tooltip.visible = false
	_wyrzuc_reka(p, z)
	_po_zmianie()


func _hover(p: Przedmiot) -> void:
	_hover_p = p
	if p == null:
		_tooltip.visible = false
		return
	_tooltip_txt.text = opis_przedmiotu(p)
	# łup w meblu / na zwłokach: ile będziesz dźwigać po wzięciu
	if _pojemnik != null and not tryb_bazy:
		var w0 := ekw.waga()
		var w1 := w0 + p.waga()
		var progi := [18.0, 28.0, 40.0]
		var nazwy := ["lekki", "obciążony", "przeciążony", "krytyczny"]
		var pr0 := progi.filter(func(x): return w0 >= x).size()
		var pr1 := progi.filter(func(x): return w1 >= x).size()
		var kol := "#d9c27a" if pr1 > pr0 else "#8c8670"
		_tooltip_txt.text += "\n[color=%s]Po wzięciu: %.1f kg (%s)%s[/color]" % [kol, w1, nazwy[pr1], "  ▲ próg obciążenia" if pr1 > pr0 else ""]
	if p.dane.get("oznaczony", false):
		_tooltip_txt.text += "\n[color=#d9c27a]★ oznaczony – nie wyrzucisz go przypadkiem[/color]"
	_tooltip.visible = true
	_tooltip.reset_size()


## Porównanie z tym, co gracz ma na sobie w tym samym slocie (pancerz, hełm, broń, plecak, kamizelka).
static func _porownanie(p: Przedmiot) -> String:
	if Gra.ekw == null:
		return ""
	var sl := Ekwipunek.slot_dla(p)
	if sl == "" or not Gra.ekw.sloty.has(sl):
		return ""
	var nos: Przedmiot = Gra.ekw.sloty[sl]
	if nos == null or nos == p:
		return ""
	var r := []
	var fmt := func(nazwa: String, d: float, lepiej_wiecej: bool, f := "%+.0f") -> void:
		if absf(d) < 0.01:
			return
		var dobrze := (d > 0) == lepiej_wiecej
		r.append("[color=%s]%s %s[/color]" % ["#7fae6a" if dobrze else "#c8674f", nazwa, f % d])
	match p.typ():
		"pancerz":
			var a: Dictionary = p.defn()["pancerz"]
			var b: Dictionary = nos.defn()["pancerz"]
			fmt.call("klasa", float(a["klasa"]) - float(b["klasa"]), true)
			fmt.call("wytrz.", float(p.dane.get("wytrz", 0)) - float(nos.dane.get("wytrz", 0)), true)
		"bron":
			var a2: Dictionary = p.defn()["bron"]
			var b2: Dictionary = nos.defn()["bron"]
			fmt.call("rozrzut", (float(a2["rozrzut_ads"]) - float(b2["rozrzut_ads"])) * 100.0 / maxf(0.01, float(b2["rozrzut_ads"])), false, "%+.0f%%")
			fmt.call("odrzut", (float(a2["odrzut"]) - float(b2["odrzut"])) * 100.0 / maxf(0.01, float(b2["odrzut"])), false, "%+.0f%%")
			fmt.call("szybkostrz.", float(a2["rpm"]) - float(b2["rpm"]), true)
			fmt.call("stan", float(p.dane.get("stan", 100.0)) - float(nos.dane.get("stan", 100.0)), true, "%+.0f%%")
		"pojemnik":
			var a3: Dictionary = p.defn()["pojemnik"]
			var b3: Dictionary = nos.defn()["pojemnik"]
			fmt.call("miejsce", float(int(a3["sw"]) * int(a3["sh"]) - int(b3["sw"]) * int(b3["sh"])), true, "%+.0f kratek")
			fmt.call("odciążenie", (float(a3.get("redukcja", 0)) - float(b3.get("redukcja", 0))) * 100.0, true, "%+.0f%%")
	fmt.call("waga", p.waga() - nos.waga(), false, "%+.1f kg")
	if r.is_empty():
		return ""
	return "[color=#8c8670]wzgl. noszonego (%s):[/color] %s\n" % [nos.nazwa(), ", ".join(r)]


static func opis_przedmiotu(p: Przedmiot) -> String:
	if p.nieznany():
		return "[b]%s[/b]\n[color=#8c8670]%.1f kg · wartość nieznana[/color]\nNie wiesz, co to jest. [PPM] Obejrzyj – trzeba światła." % [p.nazwa(), p.waga()]
	var d := p.defn()
	var t := "[b]%s[/b]\n" % p.nazwa()
	var typy := {"bron": "Broń", "magazynek": "Magazynek", "amunicja": "Amunicja", "med": "Środek medyczny",
		"pojemnik": "Pojemnik", "pancerz": "Ochrona", "lup": "Łup", "klucz": "Klucz", "latarka": "Wyposażenie"}
	t += "[color=#8c8670]%s · %.2f kg · %d bonów[/color]\n" % [typy.get(d.get("typ", ""), ""), p.waga(), p.wartosc()]
	if p.typ() == "bron":
		var st := float(p.dane.get("stan", 100.0))
		t += "[color=%s]Stan: %d%%%s[/color]\n" % ["#8c8670" if st > 60 else "#d9a35a", int(st), "" if st > 60 else (" – brudna, zacina się częściej" if st > 25 else " – zapuszczona, wyczyść ją")]
	if p.dane.get("przeterminowany", false):
		t += "[color=#d9a35a]Przeterminowany (data ważności: %d) – działa opornie, czasem wcale[/color]\n" % int(p.dane.get("rok", 1979))
	if p.dane.get("wyciszony", false):
		t += "[color=#8c8670]Owinięty taśmą – nie brzęczy[/color]\n"
	match d.get("typ", ""):
		"bron":
			var b: Dictionary = d["bron"]
			t += "Kaliber %s · %d strz./min · %s\n" % [b["kaliber"], b["rpm"], ", ".join(b["tryby"].map(func(x): return "ciągły" if x == "auto" else "pojedynczy"))]
			if b.has("wewnetrzny"):
				t += "Ładowana pojedynczo (%d)\n" % b["wewnetrzny"]
			if float(p.dane.get("brud", 0.0)) >= 1.0:
				t += "[color=#d9a35a]Zabrudzona po rajdzie (kurz, pył) – częściej się zacina; wyczyść zestawem[/color]\n"
			var dozw: Dictionary = b.get("dodatki", {})
			if not dozw.is_empty():
				var linie := []
				for sl in Przedmiot.SLOTY_DODATKOW:
					if not dozw.has(sl):
						continue
					var dd: Przedmiot = p.dodatek(sl)
					linie.append("%s: %s" % [NAZWY_SLOTOW_DOD[sl], dd.nazwa() if dd else "[color=#7a7564]wolny[/color]"])
				t += "Dodatki – " + " · ".join(linie) + "\n"
		"dodatek":
			var dd2: Dictionary = d["dodatek"]
			t += "Slot: %s · montaż: %s\n" % [NAZWY_SLOTOW_DOD[dd2["slot"]], ("w terenie, %.0f s" % float(dd2["czas"])) if dd2["montaz"] == "polowy" else "[color=#c8a050]tylko stół roboczy[/color]"]
			var ef := []
			if dd2.has("odrzut"):
				ef.append("odrzut %+d%%" % int((float(dd2["odrzut"]) - 1.0) * 100))
			if dd2.has("halas"):
				ef.append("hałas %+d%%" % int((float(dd2["halas"]) - 1.0) * 100))
			if dd2.has("rozrzut_ads"):
				ef.append("rozrzut przy celowaniu %+d%%" % int((float(dd2["rozrzut_ads"]) - 1.0) * 100))
			if dd2.has("rozrzut_biodro"):
				ef.append("rozrzut z biodra %+d%%" % int((float(dd2["rozrzut_biodro"]) - 1.0) * 100))
			if dd2.has("zoom"):
				ef.append("powiększenie %.0fx" % float(dd2["zoom"]))
			if dd2.get("plomien", true) == false:
				ef.append("bez płomienia")
			if dd2["slot"] == "latarka":
				ef.append("świeci tam, gdzie celujesz [L]")
			if not ef.is_empty():
				t += ", ".join(ef) + "\n"
			var pasuje := []
			for b2 in ["pw9", "pm63", "kb47", "obrzyn"]:
				if p.id in Dane.def(b2)["bron"].get("dodatki", {}).get(dd2["slot"], []):
					pasuje.append(Dane.nazwa(b2))
			t += "Pasuje do: " + ", ".join(pasuje) + "\n"
		"amunicja":
			var a: Dictionary = d["amunicja"]
			t += "Obrażenia %d%s · penetracja %d\n" % [a["obrazenia"], (" x%d" % a["srut"]) if a.has("srut") else "", a["penetracja"]]
		"magazynek":
			t += "Kaliber %s · %d/%d" % [d["magazynek"]["kaliber"], p.dane["naboje"], d["magazynek"]["pojemnosc"]]
			if p.dane["naboje"] > 0:
				t += " (%s)" % Dane.nazwa(p.dane["amunicja"])
			t += "\n"
		"pancerz":
			t += "Klasa %d · wytrzymałość %d/%d · chroni: %s\n" % [d["pancerz"]["klasa"], int(p.dane["wytrz"]), d["pancerz"]["wytrzymalosc"], ", ".join(d["pancerz"]["strefy"])]
			if p.dane.has("maks_wytrz"):
				t += "[color=#d9a35a]Łatany – najwyżej %d (każda łata −10%%)[/color]\n" % int(p.dane["maks_wytrz"])
		"pojemnik":
			var pj: Dictionary = d["pojemnik"]
			t += "Siatka %dx%d · redukcja wagi %d%%\n" % [pj["sw"], pj["sh"], int(pj["redukcja"] * 100)]
		"med":
			var m: Dictionary = d["med"]
			t += "Czas użycia %.1f s\n" % m["czas"]
	if p.dane.get("ubezp", false):
		t += "[color=#6f9a68]UBEZPIECZONY – wróci do skrytki po śmierci[/color]\n"
	if p.dane.get("przydzial", false):
		t += "[color=#8c8670]Z przydziału (zestaw startowy) – nikt tego nie odkupi[/color]\n"
	t += _porownanie(p)
	t += "[i][color=#a49d86]%s[/color][/i]" % d.get("opis", "")
	return t


const NAZWY_SLOTOW_DOD := {"wylot": "wylot lufy", "celownik": "celownik", "chwyt": "chwyt", "latarka": "latarka"}


func _w_zrodle(p: Przedmiot, z: Dictionary) -> bool:
	if z.get("typ") == "ziemia":
		var lw = z["wezel"]
		return is_instance_valid(lw) and not (lw as Node).is_queued_for_deletion() and lw.przedmiot == p
	if z.get("typ") == "siatka":
		return (z["siatka"] as Siatka).zawiera(p)
	if z.get("typ") == "slot":
		return ekw.sloty.get(z["slot"]) == p
	return false


## Montaż dodatku na broni. Polowe w rajdzie trwają (akcja z animacją), warsztatowe tylko przy stole roboczym.
func _montuj(bron: Przedmiot, dod: Przedmiot, z: Dictionary) -> bool:
	var dd: Dictionary = dod.defn()["dodatek"]
	var slot: String = dd["slot"]
	var dozw: Array = bron.defn()["bron"].get("dodatki", {}).get(slot, [])
	if dod.id not in dozw:
		_komunikat("%s nie pasuje do: %s" % [dod.nazwa(), bron.nazwa()])
		return true
	if bron.dodatek(slot) != null:
		_komunikat("Na broni jest już %s – najpierw zdejmij (PPM na broni)" % bron.dodatek(slot).nazwa())
		return true
	if dd["montaz"] == "warsztat" and not _warsztat:
		_komunikat("%s: montaż tylko na stole roboczym w schronie" % dod.nazwa())
		return true
	var wykonaj := func():
		if not _w_zrodle(dod, z) or bron.dodatek(slot) != null:
			return
		_usun_ze_zrodla(dod, z)
		bron.dane["dod_" + slot] = dod
		Dzwiek.graj("przeladowanie", -8.0, 1.3)
		_komunikat("Zamontowano: " + dod.nazwa())
		_po_montazu(bron)
	var czas := float(dd.get("czas", 0.0))
	var podglad := gracz != null and gracz.bron.ogladanie and gracz.bron.przedmiot == bron
	if podglad:
		czas = maxf(czas if not tryb_bazy else 0.0, 1.6)     # w podglądzie montaż zawsze z animacją
	if gracz == null or (czas <= 0.0) or (tryb_bazy and not podglad):
		wykonaj.call()
		return true
	if not gracz.akcja.is_empty():
		_komunikat("Najpierw skończ: " + String(gracz.akcja["nazwa"]))
		return true
	gracz.zacznij_akcje("Montaż: " + dod.nazwa(), czas, wykonaj, "montaz", 0, Callable(), {"dod": dod, "zdejmij": false})
	Dzwiek.graj("klik", -8.0, 0.7)
	return true


func _zdejmij_dodatek(bron: Przedmiot, slot: String) -> void:
	var dod: Przedmiot = bron.dodatek(slot)
	if dod == null:
		return
	var dd: Dictionary = dod.defn()["dodatek"]
	if dd["montaz"] == "warsztat" and not _warsztat:
		_komunikat("%s: zdjąć można tylko na stole roboczym w schronie" % dod.nazwa())
		return
	var wykonaj := func():
		if bron.dodatek(slot) != dod:
			return
		bron.dane["dod_" + slot] = null
		if not ekw.dodaj(dod) and not (_prawa_siatka != null and _prawa_siatka.dodaj(dod)):
			if gracz:
				gracz.upusc(dod)
		Dzwiek.graj("klik", -8.0, 0.8)
		_po_montazu(bron)
	var czas := float(dd.get("czas", 0.0)) * 0.8
	var podglad := gracz != null and gracz.bron.ogladanie and gracz.bron.przedmiot == bron
	if podglad:
		czas = maxf(czas if not tryb_bazy else 0.0, 1.4)
	if gracz == null or czas <= 0.0 or (tryb_bazy and not podglad):
		wykonaj.call()
		return
	if not gracz.akcja.is_empty():
		_komunikat("Najpierw skończ: " + String(gracz.akcja["nazwa"]))
		return
	gracz.zacznij_akcje("Demontaż: " + dod.nazwa(), czas, wykonaj, "montaz", 0, Callable(), {"dod": dod, "zdejmij": true})


## Po zmianie dodatków: broń w rękach przebudowana (model, celownik, latarka), ekran odświeżony.
func _po_montazu(bron: Przedmiot) -> void:
	if gracz and gracz.bron.przedmiot == bron:
		gracz._wybierz_bron(gracz.aktywny_slot)
	ekw.zmieniony.emit()
	if otwarty:
		_przebuduj()
	if tryb_bazy:
		Gra.zapisz()


## Skrytka przy stole roboczym (baza): montaż i demontaż wszystkich dodatków.
func otworz_warsztat() -> void:
	_warsztat = true
	otworz_skrytke()


func _komunikat(t: String) -> void:
	if gracz:
		gracz.komunikat.emit(t)
	else:
		get_tree().call_group("hud", "komunikat", t)


# ------------------------------------------------------------------ duch przeciąganego przedmiotu

## Rozpięty zamek plecaka nad komorą główną.
class Zamek:
	extends Control
	func _ready() -> void:
		custom_minimum_size = Vector2(0, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x
		for i in int(w / 6.0):
			var x := i * 6.0
			var y := 2.0 + (4.0 if i % 2 == 0 else 0.0) + sin(i * 0.4) * 1.5
			draw_rect(Rect2(x, y, 4, 4), Color(0.55, 0.53, 0.45))
		draw_rect(Rect2(w * 0.5 - 6, 0, 12, 12), Color(0.7, 0.68, 0.6))


class Duch:
	extends Control
	var ekran

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var d: Dictionary = ekran._drag
		if d.is_empty():
			return
		var p: Przedmiot = d["p"]
		var stary := p.obrot
		p.obrot = d["rot"]
		var m := get_local_mouse_position()
		var tl: Vector2 = m - d["off"] if d["rot"] == stary else m - Vector2(16, 16)
		var r := Rect2(tl, Vector2(p.szer(), p.wys()) * SiatkaUI.KOM)
		# podświetlenie miejsca docelowego
		for ui in ekran._siatki:
			if ui.siatka == null or not ui.get_global_rect().has_point(get_global_mouse_position()):
				continue
			var lok: Vector2 = tl + global_position - ui.global_position
			var kom := Vector2i(roundi(lok.x / SiatkaUI.KOM), roundi(lok.y / SiatkaUI.KOM))
			var ok: bool = ui.siatka.moze(p, kom.x, kom.y, d["rot"], p)
			var cel := Rect2(ui.global_position - global_position + Vector2(kom) * SiatkaUI.KOM, r.size)
			draw_rect(cel, Color(0.3, 0.7, 0.3, 0.25) if ok else Color(0.8, 0.2, 0.15, 0.25))
		modulate.a = 0.85
		SiatkaUI.rysuj_przedmiot(self, p, r, true)
		p.obrot = stary
		if not ekran.tryb_bazy and not ekran.nad_celem(get_global_mouse_position()):
			if ekran._ziemia_pod(get_global_mouse_position()) != null:
				draw_rect(r, Color(0.55, 0.5, 0.3, 0.18))
				draw_string(Motyw.cond(), r.position + Vector2(0, r.size.y + 13), "odłóż tutaj", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.8, 0.62, 0.8))
			else:
				draw_rect(r, Color(0.8, 0.15, 0.1, 0.35))
			draw_rect(r, Color(0.95, 0.3, 0.2), false, 2.0)
			draw_string(Motyw.mono_b(), r.position + Vector2(0, -6), "WYRZUĆ NA ZIEMIĘ", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.45, 0.3))


func _exit_tree() -> void:
	Dzwiek.przytlum_ekwipunek(false)
