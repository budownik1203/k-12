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
var _siatki: Array[SiatkaUI] = []
var _sloty: Array[SlotUI] = []

var _drag := {}                  # {"p", "z": źródło, "off": Vector2, "rot": bool}
var _pojemnik: Pojemnik = null
var _szukanie_t := 0.0
var _prawa_siatka: Siatka = null
var _prawa_ui: SiatkaUI = null


func _ready() -> void:
	layer = 20
	ekw = Gra.ekw
	_buduj()
	_root.visible = false
	ekw.zmieniony.connect(_odswiez)


func _buduj() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = Motyw.motyw()
	add_child(_root)
	var tlo := ColorRect.new()
	tlo.color = Color(0, 0, 0, 0.72)
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	tlo.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(tlo)
	var marg := MarginContainer.new()
	marg.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		marg.add_theme_constant_override("margin_" + s, 24)
	_root.add_child(marg)
	var kol := VBoxContainer.new()
	marg.add_child(kol)
	var gora := HBoxContainer.new()
	gora.add_child(Motyw.etykieta("KARTA EWIDENCYJNA OPERATORA  ·  formularz K-12/E", 18, Motyw.TEKST, Motyw.mono_b()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gora.add_child(spacer)
	_info_bony = Motyw.etykieta("", 16, Motyw.ZOLC, Motyw.mono_b())
	gora.add_child(_info_bony)
	kol.add_child(gora)
	var rzad := HBoxContainer.new()
	rzad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rzad.add_theme_constant_override("separation", 18)
	kol.add_child(rzad)
	# lewy: sloty i zdrowie
	var lp := PanelContainer.new()
	lp.custom_minimum_size = Vector2(330, 0)
	rzad.add_child(lp)
	_panele.append(lp)
	_lewy = VBoxContainer.new()
	_lewy.add_theme_constant_override("separation", 6)
	lp.add_child(_lewy)
	# środek: kieszenie, kamizelka, plecak
	var sp := PanelContainer.new()
	sp.custom_minimum_size = Vector2(300, 0)
	rzad.add_child(sp)
	_panele.append(sp)
	var ss := ScrollContainer.new()
	ss.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sp.add_child(ss)
	_srodek = VBoxContainer.new()
	_srodek.add_theme_constant_override("separation", 6)
	ss.add_child(_srodek)
	# prawy: pojemnik / skrytka
	var pp := PanelContainer.new()
	pp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rzad.add_child(pp)
	_panele.append(pp)
	_prawy = VBoxContainer.new()
	pp.add_child(_prawy)
	_prawy_tytul = Motyw.naglowek("")
	_prawy.add_child(_prawy_tytul)
	_prawy_scroll = ScrollContainer.new()
	_prawy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prawy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_prawy.add_child(_prawy_scroll)
	# dół: podpowiedzi i pasek postępu
	var dol := HBoxContainer.new()
	dol.add_child(Motyw.etykieta("[LPM] przeciągnij (poza okno = wyrzuć, lek na ciało = lecz)  [R] obróć  [Ctrl+LPM] przenieś  [PPM] menu  [Del] wyrzuć  [G] napełnij  [X] przerwij  [Tab] zamknij", 12, Motyw.TEKST_CIEMNY, Motyw.mono()))
	kol.add_child(dol)
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

func otworz(pojemnik: Pojemnik = null) -> void:
	_pojemnik = pojemnik
	_prawa_siatka = pojemnik.siatka if pojemnik else null
	_szukanie_t = 0.0
	_pokaz()


func otworz_skrytke() -> void:
	_pojemnik = null
	_prawa_siatka = Gra.skrytka
	_pokaz()


func _pokaz() -> void:
	otwarty = true
	_root.visible = true
	Sterowanie.blokada = true
	Sterowanie.przechwyc(false)
	_przebuduj()
	Dzwiek.graj("plecak", -8.0)


func zamknij() -> void:
	if not otwarty:
		return
	_upusc_drag(true)
	otwarty = false
	_root.visible = false
	_menu.hide()
	_tooltip.visible = false
	Sterowanie.blokada = false
	Sterowanie.przechwyc(true)
	_pojemnik = null
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
	_siatki.clear()
	_sloty.clear()
	# lewy panel
	_lewy.add_child(Motyw.naglowek("Wyposażenie osobiste"))
	var g1 := GridContainer.new()
	g1.columns = 4
	g1.add_theme_constant_override("h_separation", 8)
	g1.add_theme_constant_override("v_separation", 4)
	_lewy.add_child(g1)
	for para in [["helm", Vector2i(2, 2)], ["pancerz", Vector2i(2, 2)], ["kamizelka", Vector2i(2, 2)], ["plecak", Vector2i(2, 2)]]:
		g1.add_child(_slot(para[0], para[1]))
	var bronie := HBoxContainer.new()
	bronie.add_theme_constant_override("separation", 8)
	_lewy.add_child(bronie)
	bronie.add_child(_slot("glowna", Vector2i(6, 2)))
	bronie.add_child(_slot("pistolet", Vector2i(3, 2)))
	_lewy.add_child(Motyw.naglowek("Stan zdrowia – przeciągnij lek na część ciała"))
	_info_zdrowie = VBoxContainer.new()
	_lewy.add_child(_info_zdrowie)
	_panel_ciala = PanelCiala.new()
	_panel_ciala.cialo = gracz.cialo if gracz else Cialo.new(Gra.zdrowie)
	_info_zdrowie.add_child(_panel_ciala)
	_opis_ciala = Motyw.etykieta("", 12, Motyw.TEKST, Motyw.cond())
	_opis_ciala.autowrap_mode = TextServer.AUTOWRAP_WORD
	_opis_ciala.custom_minimum_size = Vector2(300, 18)
	_info_zdrowie.add_child(_opis_ciala)
	_info_waga = Motyw.etykieta("", 14, Motyw.TEKST, Motyw.mono())
	_lewy.add_child(_info_waga)
	# środek
	_srodek.add_child(Motyw.naglowek("Kieszenie"))
	_srodek.add_child(_siatka_ui(ekw.kieszenie, "kieszenie"))
	_srodek.add_child(Motyw.naglowek("Kamizelka" + _opis_red(ekw.sloty["kamizelka"])))
	_srodek.add_child(_siatka_ui(ekw.siatka_kamizelki(), "kamizelka"))
	_srodek.add_child(Motyw.naglowek("Plecak" + _opis_red(ekw.sloty["plecak"])))
	_srodek.add_child(_siatka_ui(ekw.siatka_plecaka(), "plecak"))
	_srodek.add_child(Motyw.naglowek("Kontener bezpieczny (przeżywa śmierć)"))
	_srodek.add_child(_siatka_ui(ekw.bezpieczny, "bezpieczny"))
	# prawy
	if _prawa_siatka != null:
		var naz := "Skrytka" if _pojemnik == null else _pojemnik.nazwa
		_prawy_tytul.text = naz.to_upper()
		_prawa_ui = _siatka_ui(_prawa_siatka, "prawy")
		if _pojemnik != null:
			_prawa_ui.widoczne = _pojemnik.odkryte
		_prawy_scroll.add_child(_prawa_ui)
	else:
		_prawy_tytul.text = "BRAK OTWARTEGO POJEMNIKA"
		_prawa_ui = null
		var l := Motyw.etykieta("Podejdź do szafki, skrzyni lub zwłok i naciśnij [F], aby przeszukać.", 14, Motyw.TEKST_CIEMNY)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(300, 0)
		_prawy_scroll.add_child(l)
	_odswiez()


func _opis_red(p: Przedmiot) -> String:
	if p == null:
		return " (brak)"
	return "  · redukcja wagi %d%%" % int(p.defn()["pojemnik"]["redukcja"] * 100)


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
	if Input.is_action_just_pressed("ekwipunek") and not Sterowanie.blokada_menu():
		if otwarty:
			zamknij()
		elif gracz == null or not gracz.cialo.martwy:
			if tryb_bazy:
				otworz_skrytke()
			else:
				otworz(null)
	if not otwarty:
		return
	# przeszukiwanie: stopniowe odkrywanie zawartości
	if _pojemnik != null and _prawa_ui != null and not _pojemnik.przeszukany():
		_szukanie_t += delta
		if _szukanie_t >= _pojemnik.czas_na_przedmiot:
			_szukanie_t = 0.0
			_pojemnik.odkryte += 1
			_prawa_ui.widoczne = _pojemnik.odkryte
			_prawa_ui.queue_redraw()
			Dzwiek.graj("szukanie", -12.0)
		if gracz and gracz.global_position.distance_to(_pojemnik.global_position) > 3.0:
			zamknij()
			return
	elif _pojemnik != null and _prawa_ui:
		_pojemnik.odkryte = _pojemnik.siatka.items.size()
		_prawa_ui.widoczne = -1
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


func przeciagany() -> Przedmiot:
	return _drag.get("p")


# ------------------------------------------------------------------ kliknięcia

func _klik_siatka(ui: SiatkaUI, p: Przedmiot, przycisk: int, pos: Vector2) -> void:
	if p == null:
		return
	var z := {"typ": "siatka", "ui": ui, "siatka": ui.siatka}
	if przycisk == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_CTRL):
			_szybkie_przeniesienie(p, z)
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
		_drag = {"p": p, "z": z, "off": Vector2(16, 16), "rot": p.obrot}
	elif przycisk == MOUSE_BUTTON_RIGHT:
		_pokaz_menu(p, z, pos)


func _input(event: InputEvent) -> void:
	if not otwarty:
		return
	if event.is_action_pressed("pauza"):
		zamknij()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _drag.is_empty():
		_upusc_drag(false)
		get_viewport().set_input_as_handled()


func _upusc_drag(anuluj: bool) -> void:
	if _drag.is_empty():
		return
	var d := _drag
	_drag = {}
	if anuluj:
		_odswiez()
		return
	var mysz := _root.get_global_mouse_position()
	var p: Przedmiot = d["p"]
	# cel: część ciała (leczenie wybranej części)
	if _panel_ciala and p.typ() == "med" and gracz and not tryb_bazy:
		var cz := _panel_ciala.czesc_pod(mysz)
		if cz != "":
			var szybki := true
			if d["z"]["typ"] == "siatka":
				szybki = ekw.czy_szybka(d["z"]["siatka"])
			gracz.uzyj_leku(p, szybki, cz)
			_odswiez()
			return
	# poza oknami: wyrzucenie na ziemię
	var nad_panelem := false
	for pn in _panele:
		if pn.get_global_rect().has_point(mysz):
			nad_panelem = true
	if not nad_panelem:
		if not tryb_bazy and gracz and not (d["z"]["typ"] == "siatka" and d["z"]["siatka"] == _prawa_siatka):
			_usun_ze_zrodla(p, d["z"])
			gracz.upusc(p)
			Dzwiek.graj("odloz", -8.0)
			_po_zmianie()
		else:
			_odswiez()
		return
	# cel: slot
	for s in _sloty:
		if s.get_global_rect().has_point(mysz):
			_na_slot(p, d["z"], s.slot)
			_po_zmianie()
			return
	# cel: siatka
	for ui in _siatki:
		if ui.siatka == null or not ui.get_global_rect().has_point(mysz):
			continue
		var pod := ui.komorka_pod(mysz - ui.global_position)
		var q := ui.siatka.przedmiot_w(pod.x, pod.y)
		if q != null and q != p and _polacz(p, d["z"], q, ui):
			_po_zmianie()
			return
		var tl: Vector2 = mysz - d["off"] - ui.global_position
		var kom := Vector2i(roundi(tl.x / SiatkaUI.KOM), roundi(tl.y / SiatkaUI.KOM))
		if d["rot"] != p.obrot:
			kom = pod
		if p.typ() == "pojemnik" and p.dane["siatka"] == ui.siatka:
			return
		if ui.siatka.moze(p, kom.x, kom.y, d["rot"], p):
			_usun_ze_zrodla(p, d["z"])
			ui.siatka.poloz(p, kom.x, kom.y, d["rot"])
			Dzwiek.graj("odloz", -10.0)
			_po_zmianie()
		return
	_odswiez()


func _po_zmianie() -> void:
	ekw.zmieniony.emit()
	if tryb_bazy:
		Gra.zapisz()
	# zmiana kamizelki/plecaka zmienia układ siatek
	_przebuduj()


func _usun_ze_zrodla(p: Przedmiot, z: Dictionary) -> void:
	if z["typ"] == "siatka":
		(z["siatka"] as Siatka).usun(p)
	elif z["typ"] == "slot":
		ekw.zdejmij(z["slot"])


func _na_slot(p: Przedmiot, z: Dictionary, slot: String) -> void:
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
func _polacz(p: Przedmiot, z: Dictionary, q: Przedmiot, ui: SiatkaUI) -> bool:
	if p.id == q.id and p.stos_max() > 1 and q.ilosc < q.stos_max():
		var ile: int = mini(p.ilosc, q.stos_max() - q.ilosc)
		q.ilosc += ile
		p.ilosc -= ile
		if p.ilosc <= 0:
			_usun_ze_zrodla(p, z)
		return true
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
	var z_prawej: bool = z["typ"] == "siatka" and z["siatka"] == _prawa_siatka
	if z_prawej:
		_usun_ze_zrodla(p, z)
		if not ekw.dodaj(p):
			_prawa_siatka.dodaj(p)
			_komunikat("Brak miejsca w ekwipunku")
		else:
			Dzwiek.graj("podnies", -8.0)
	elif _prawa_siatka != null:
		var m := _prawa_siatka.wolne_miejsce(p)
		if m.is_empty():
			_komunikat("Brak miejsca: " + _prawy_tytul.text.to_lower())
			return
		_usun_ze_zrodla(p, z)
		_prawa_siatka.poloz(p, m["x"], m["y"], m["rot"])
		Dzwiek.graj("odloz", -8.0)
	_po_zmianie()


# ------------------------------------------------------------------ menu kontekstowe

enum { M_UZYJ, M_ROZLADUJ, M_NAPELNIJ, M_WYJMIJ_MAG, M_ZALOZ, M_ZDEJMIJ, M_WYRZUC, M_WEZ, M_SPRZEDAJ, M_LATARKA }


func _pokaz_menu(p: Przedmiot, z: Dictionary, pos: Vector2) -> void:
	_menu.clear()
	_menu_p = p
	_menu_zrodlo = z
	var t := p.typ()
	if t == "med" and not tryb_bazy and gracz:
		_menu.add_item("Użyj", M_UZYJ)
	if t == "latarka" and not tryb_bazy and gracz:
		_menu.add_item("Weź do ręki [L]", M_LATARKA)
	if t == "magazynek":
		_menu.add_item("Napełnij", M_NAPELNIJ)
		if p.dane["naboje"] > 0:
			_menu.add_item("Rozładuj", M_ROZLADUJ)
	if t == "bron":
		if p.dane.get("mag") != null:
			_menu.add_item("Wyjmij magazynek", M_WYJMIJ_MAG)
		if p.dane.get("wewn", 0) > 0 or p.dane.get("komora", "") != "":
			_menu.add_item("Rozładuj", M_ROZLADUJ)
	if z["typ"] == "slot":
		_menu.add_item("Zdejmij", M_ZDEJMIJ)
	elif Ekwipunek.slot_dla(p) != "":
		_menu.add_item("Załóż", M_ZALOZ)
	if z["typ"] == "siatka" and z["siatka"] == _prawa_siatka and _prawa_siatka != null:
		_menu.add_item("Weź", M_WEZ)
	if not tryb_bazy and gracz and not (z["typ"] == "siatka" and z["siatka"] == _prawa_siatka):
		_menu.add_item("Wyrzuć", M_WYRZUC)
	if _menu.item_count == 0:
		return
	_menu.position = Vector2i(pos)
	_menu.reset_size()
	_menu.popup()


func _menu_akcja(id: int) -> void:
	var p := _menu_p
	var z := _menu_zrodlo
	if p == null:
		return
	match id:
		M_UZYJ:
			var szybki: bool = not (z["typ"] == "siatka" and z["siatka"] == ekw.siatka_plecaka())
			gracz.uzyj_leku(p, szybki)
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
		M_WEZ:
			_szybkie_przeniesienie(p, z)
			return
		M_WYRZUC:
			_usun_ze_zrodla(p, z)
			gracz.upusc(p)
	_po_zmianie()


# ------------------------------------------------------------------ amunicja

## Napełnia magazynek: z podanego stosu albo z dowolnej pasującej amunicji w ekwipunku (i skrytce w bazie).
func _napelnij(mag: Przedmiot, stos: Przedmiot, z_stosu: Dictionary) -> bool:
	if gracz != null and not tryb_bazy and not gracz.akcja.is_empty():
		_komunikat("Najpierw skończ: " + String(gracz.akcja["nazwa"]) + "  [X] przerywa")
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
	# z ekwipunku / skrytki
	var zrodla := ekw.siatki()
	if tryb_bazy:
		zrodla.append(Gra.skrytka)
	var typ: String = mag.dane["amunicja"] if mag.dane["naboje"] > 0 else ""
	for s in zrodla:
		for e in (s as Siatka).items:
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
		Dzwiek.graj("klik", -12.0, randf_range(1.1, 1.3))
		ekw.zmieniony.emit()
	var koniec := func():
		Dzwiek.graj("napelnianie", -10.0)
		if _seria_mag:
			napelnij_wszystkie()
	gracz.zacznij_akcje(mag.nazwa(), 0.36 * ile, koniec, "magazynek", ile, na_krok)


func napelnij_wszystkie() -> void:
	var mags := []
	var zrodla := ekw.siatki()
	if tryb_bazy:
		zrodla.append(Gra.skrytka)
	for s in zrodla:
		for e in (s as Siatka).items:
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
		p.dane["naboje"] = 0
	elif p.typ() == "bron":
		if p.dane["wewn"] > 0:
			amun = p.dane["wewn_typ"]
			n = p.dane["wewn"]
			p.dane["wewn"] = 0
		if p.dane["komora"] != "":
			amun = p.dane["komora"]
			n += 1
			p.dane["komora"] = ""
	if n <= 0 or amun == "":
		return
	var a := Przedmiot.nowy(amun, n)
	if not ekw.dodaj(a) and not (_prawa_siatka and _prawa_siatka.dodaj(a)):
		if gracz:
			gracz.upusc(a)
	Dzwiek.graj("klik", -10.0)


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
	_usun_ze_zrodla(p, z)
	gracz.upusc(p)
	_hover_p = null
	_tooltip.visible = false
	Dzwiek.graj("odloz", -8.0)
	_po_zmianie()


func _hover(p: Przedmiot) -> void:
	_hover_p = p
	if p == null:
		_tooltip.visible = false
		return
	_tooltip_txt.text = opis_przedmiotu(p)
	_tooltip.visible = true
	_tooltip.reset_size()


static func opis_przedmiotu(p: Przedmiot) -> String:
	var d := p.defn()
	var t := "[b]%s[/b]\n" % p.nazwa()
	var typy := {"bron": "Broń", "magazynek": "Magazynek", "amunicja": "Amunicja", "med": "Środek medyczny",
		"pojemnik": "Pojemnik", "pancerz": "Ochrona", "lup": "Łup", "klucz": "Klucz", "latarka": "Wyposażenie"}
	t += "[color=#8c8670]%s · %.2f kg · %d bonów[/color]\n" % [typy.get(d.get("typ", ""), ""), p.waga(), p.wartosc()]
	match d.get("typ", ""):
		"bron":
			var b: Dictionary = d["bron"]
			t += "Kaliber %s · %d strz./min · %s\n" % [b["kaliber"], b["rpm"], ", ".join(b["tryby"].map(func(x): return "ciągły" if x == "auto" else "pojedynczy"))]
			if b.has("wewnetrzny"):
				t += "Ładowana pojedynczo (%d)\n" % b["wewnetrzny"]
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
		"pojemnik":
			var pj: Dictionary = d["pojemnik"]
			t += "Siatka %dx%d · redukcja wagi %d%%\n" % [pj["sw"], pj["sh"], int(pj["redukcja"] * 100)]
		"med":
			var m: Dictionary = d["med"]
			t += "Czas użycia %.1f s\n" % m["czas"]
	if p.dane.get("ubezp", false):
		t += "[color=#6f9a68]UBEZPIECZONY – wróci do skrytki po śmierci[/color]\n"
	t += "[i][color=#a49d86]%s[/color][/i]" % d.get("opis", "")
	return t


func _komunikat(t: String) -> void:
	if gracz:
		gracz.komunikat.emit(t)
	else:
		get_tree().call_group("hud", "komunikat", t)


# ------------------------------------------------------------------ duch przeciąganego przedmiotu

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
