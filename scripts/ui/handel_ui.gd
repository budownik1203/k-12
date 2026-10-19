extends CanvasLayer
## Ekran handlu: oferta handlarza po lewej, skrytka gracza po prawej (sprzedaż: PPM lub Ctrl+LPM).

var handlarz := {}       # definicja z HANDLARZE
var otwarty := false
var _root: Control
var _oferta: VBoxContainer
var _skrytka_ui: SiatkaUI
var _bony: Label
var _tytul: Label
var _powitanie: Label
var _dodatki: HBoxContainer
var _tooltip: PanelContainer
var _tooltip_txt: RichTextLabel
var _menu: PopupMenu
var _menu_p: Przedmiot

const HANDLARZE := {
	"zbrojmistrz": {
		"nazwa": "Zbrojmistrz", "opis": "cyniczny były kwatermistrz",
		"powitania": ["Broń jest. Amunicji też trochę. Sumienia brak na stanie.", "Zwrotów nie przyjmuję. Zwłaszcza od nieboszczyków.", "Podpisz tu, tu i tu. Nie, nie czytaj."],
		"oferta": [["pw9", 1], ["obrzyn", 1], ["pm63", 1], ["kb47", 1], ["mag_pw9", 1], ["mag_pm63", 1], ["mag_kb47", 1],
			["a_9x18", 50], ["a_12", 20], ["a_762", 60], ["a_762bp", 30], ["kamizelka_kl2", 1], ["helm_wz67", 1],
			["tlumik_9", 1], ["tlumik_762", 1], ["hamulec", 1], ["kolimator", 1], ["luneta", 1], ["chwyt", 1], ["latarka_taktyczna", 1],
			["kamizelka_kl4", 1], ["kamizelka_lbv", 1], ["napiersnik", 1], ["plecak_szturmowy", 1], ["plecak_turystyczny", 1], ["plecak_wojskowy", 1]],
		"skupuje": ["bron", "magazynek", "amunicja", "pancerz", "pojemnik", "dodatek"], "skup": 0.5,
	},
	"medyk": {
		"nazwa": "Medyk", "opis": "zmęczony lekarz-uciekinier z kompleksu",
		"powitania": ["Znowu ty. Co tym razem przestało działać?", "Nie pytaj, co jest w tabletkach. Ja też nie pytałem.", "Krwawisz mi na podłogę. Podłoga też jest na kartki."],
		"oferta": [["bandaz", 1], ["opatrunek", 1], ["szyna", 1], ["bolostop", 1], ["apteczka", 1]],
		"skupuje": ["med"], "skup": 0.55,
	},
	"posrednik": {
		"nazwa": "Pośrednik", "opis": "skup i sprzedaż, znajomości u Szabrowników",
		"powitania": ["Wszystko ma swoją cenę. Ty też, ale na razie kupuję zegarki.", "Pochodzenie towaru mnie nie interesuje. Stan – owszem.", "Dla stałych klientów rabat. Ty jeszcze nie jesteś stały. Ani żywy na dłużej."],
		"oferta": [["worek", 1], ["chlebak", 1], ["kamizelka_wedkarska", 1], ["kamizelka_mysliwska", 1], ["latarka", 1], ["mapa", 1], ["kompas", 1], ["klucz_piwnica", 1], ["konserwa", 1], ["suchary", 1], ["woda", 1], ["papierosy", 1]],
		"skupuje": ["lup", "klucz", "latarka", "mapa", "kompas", "med", "pojemnik", "bron", "magazynek", "amunicja", "pancerz"], "skup": 0.45, "skup_lup": 0.7,
	},
}


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = Motyw.motyw()
	_root.visible = false
	add_child(_root)
	var tlo := ColorRect.new()
	tlo.color = Color(0, 0, 0, 0.78)
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(tlo)
	var marg := MarginContainer.new()
	marg.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		marg.add_theme_constant_override("margin_" + s, 28)
	_root.add_child(marg)
	var kol := VBoxContainer.new()
	kol.add_theme_constant_override("separation", 8)
	marg.add_child(kol)
	var gora := HBoxContainer.new()
	_tytul = Motyw.etykieta("", 22, Motyw.TEKST, Motyw.mono_b())
	gora.add_child(_tytul)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gora.add_child(sp)
	_bony = Motyw.etykieta("", 18, Motyw.ZOLC, Motyw.mono_b())
	gora.add_child(_bony)
	kol.add_child(gora)
	_powitanie = Motyw.etykieta("", 15, Motyw.TEKST_CIEMNY)
	kol.add_child(_powitanie)
	_dodatki = HBoxContainer.new()
	_dodatki.add_theme_constant_override("separation", 10)
	kol.add_child(_dodatki)
	var rzad := HBoxContainer.new()
	rzad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rzad.add_theme_constant_override("separation", 18)
	kol.add_child(rzad)
	var lp := PanelContainer.new()
	lp.custom_minimum_size = Vector2(560, 0)
	rzad.add_child(lp)
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	lv.add_child(Motyw.naglowek("Oferta"))
	var ls := ScrollContainer.new()
	ls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(ls)
	_oferta = VBoxContainer.new()
	_oferta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ls.add_child(_oferta)
	var pp := PanelContainer.new()
	pp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rzad.add_child(pp)
	var pv := VBoxContainer.new()
	pp.add_child(pv)
	pv.add_child(Motyw.naglowek("Skrytka  ·  sprzedaż: [PPM] lub [Ctrl+LPM]"))
	var ps := ScrollContainer.new()
	ps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(ps)
	_skrytka_ui = SiatkaUI.new()
	_skrytka_ui.ustaw(Gra.skrytka)
	_skrytka_ui.klik.connect(_klik_skrytka)
	_skrytka_ui.najechano.connect(_hover)
	ps.add_child(_skrytka_ui)
	var dol := HBoxContainer.new()
	var zam := Button.new()
	zam.text = "Zamknij [Esc]"
	zam.pressed.connect(zamknij)
	dol.add_child(zam)
	kol.add_child(dol)
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	_tooltip_txt = RichTextLabel.new()
	_tooltip_txt.bbcode_enabled = true
	_tooltip_txt.fit_content = true
	_tooltip_txt.custom_minimum_size = Vector2(290, 0)
	_tooltip_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_txt.add_theme_font_override("bold_font", Motyw.mono_b())
	_tooltip.add_child(_tooltip_txt)
	_root.add_child(_tooltip)
	_menu = PopupMenu.new()
	_menu.id_pressed.connect(func(_i): _sprzedaj(_menu_p))
	_root.add_child(_menu)


func otworz(id: String) -> void:
	handlarz = HANDLARZE[id].duplicate(true)
	handlarz["id"] = id
	otwarty = true
	_root.visible = true
	Sterowanie.blokada = true
	Sterowanie.przechwyc(false)
	_tytul.text = "%s  ·  %s" % [handlarz["nazwa"].to_upper(), handlarz["opis"]]
	_powitanie.text = "„%s”" % handlarz["powitania"].pick_random()
	_przebuduj()


func zamknij() -> void:
	otwarty = false
	_root.visible = false
	_tooltip.visible = false
	Sterowanie.blokada = false
	Sterowanie.przechwyc(true)
	Gra.zapisz()


func _input(event: InputEvent) -> void:
	if otwarty and (event.is_action_pressed("pauza") or event.is_action_pressed("ekwipunek")):
		zamknij()
		# ten sam Tab nie może od razu otworzyć skrytki
		Sterowanie.blokuj_tab_do = Engine.get_process_frames() + 3
		get_viewport().set_input_as_handled()


func _process(_d: float) -> void:
	if not otwarty:
		return
	_bony.text = "%d bonów" % Gra.bony
	_tooltip.position = _root.get_local_mouse_position() + Vector2(18, 14)
	if _tooltip.position.x + _tooltip.size.x > _root.size.x:
		_tooltip.position.x -= _tooltip.size.x + 36


func _przebuduj() -> void:
	for c in _oferta.get_children():
		c.queue_free()
	for c in _dodatki.get_children():
		c.queue_free()
	for o in handlarz["oferta"]:
		var pid: String = o[0]
		var ile: int = o[1]
		var d := Dane.def(pid)
		var cena := int(d["cena"]) * ile
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		var ik := TextureRect.new()
		ik.texture = Dane.ikona(pid)
		ik.custom_minimum_size = Vector2(64, 34)
		ik.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ik.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ik.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.add_child(ik)
		var n := Motyw.etykieta(d["nazwa"] + (" ×%d" % ile if ile > 1 else ""), 15)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.mouse_filter = Control.MOUSE_FILTER_STOP
		n.mouse_entered.connect(func(): _hover(Przedmiot.nowy(pid, ile)))
		n.mouse_exited.connect(func(): _hover(null))
		r.add_child(n)
		r.add_child(Motyw.etykieta("%d" % cena, 15, Motyw.ZOLC, Motyw.mono_b()))
		var b := Button.new()
		b.text = "Kup"
		b.disabled = Gra.bony < cena
		b.pressed.connect(func(): _kup(pid, ile, cena))
		r.add_child(b)
		_oferta.add_child(r)
	match handlarz["id"]:
		"medyk":
			var koszt := koszt_leczenia()
			var b := Button.new()
			b.text = "Pełne leczenie (%d bonów)" % koszt if koszt > 0 else "Jesteś zdrowy (formalnie)"
			b.disabled = koszt <= 0 or Gra.bony < koszt
			b.pressed.connect(func():
				Gra.dodaj_bony(-koszt)
				Gra.zdrowie = {}
				for g in get_tree().get_nodes_in_group("gracz"):
					(g as Gracz).cialo.wylecz()
				Gra.ekw.zmieniony.emit()
				Dzwiek.graj("leczenie", -4.0)
				_powitanie.text = "„Gotowe. Blizny w cenie.”"
				_przebuduj())
			_dodatki.add_child(b)
		"posrednik":
			for sl in ["glowna", "pistolet", "pancerz", "helm", "plecak"]:
				var p: Przedmiot = Gra.ekw.sloty[sl]
				if p == null or p.dane.get("ubezp", false):
					continue
				var koszt := Gra.koszt_ubezpieczenia(p)
				var bu := Button.new()
				bu.text = "Ubezpiecz: %s (%d)" % [p.nazwa(), koszt]
				bu.disabled = Gra.bony < koszt
				bu.tooltip_text = "Po śmierci przedmiot (pusty) wróci do skrytki."
				bu.pressed.connect(func():
					Gra.dodaj_bony(-koszt)
					p.dane["ubezp"] = true
					_powitanie.text = "„Ubezpieczone. Gdyby co, przyjdzie pocztą. Bez naboi, bez sentymentów.”"
					Dzwiek.graj("pieczatka", -4.0)
					_przebuduj())
				_dodatki.add_child(bu)
		"zbrojmistrz":
			var b2 := Button.new()
			b2.text = "Darmowy zestaw startowy"
			b2.disabled = Gra.ma_bron()
			b2.tooltip_text = "PW-9 z magazynkiem, amunicja i bandaż. Wydawany, gdy nie masz broni."
			b2.pressed.connect(func():
				if Gra.wydaj_zestaw_startowy():
					_powitanie.text = "„Masz. Oddasz, jak wrócisz. Ha. Ha.”"
					Dzwiek.graj("zaloz", -4.0)
				_przebuduj())
			_dodatki.add_child(b2)


static func koszt_leczenia() -> int:
	var c := Cialo.new(Gra.zdrowie)
	var brak := 0.0
	for cz in Cialo.MAX:
		brak += Cialo.MAX[cz] - c.hp[cz]
	return int(brak * 18.0)


func _kup(pid: String, ile: int, cena: int) -> void:
	if Gra.bony < cena:
		return
	var p := Przedmiot.nowy(pid, ile)
	if not Gra.skrytka.dodaj(p):
		_powitanie.text = "„Nie mam gdzie ci tego włożyć. Zrób miejsce w skrytce.”"
		return
	Gra.dodaj_bony(-cena)
	Dzwiek.graj("kasa", -6.0)
	_przebuduj()


func cena_skupu(p: Przedmiot) -> int:
	var t := p.typ()
	if t not in handlarz["skupuje"]:
		return 0
	var m: float = handlarz.get("skup_lup", handlarz["skup"]) if t == "lup" else handlarz["skup"]
	return int(p.wartosc() * m)


func _klik_skrytka(_ui: SiatkaUI, p: Przedmiot, przycisk: int, pos: Vector2) -> void:
	if p == null:
		return
	if przycisk == MOUSE_BUTTON_RIGHT:
		var c := cena_skupu(p)
		_menu.clear()
		if c > 0:
			_menu.add_item("Sprzedaj za %d bonów" % c, 0)
		else:
			_menu.add_item("%s tego nie kupi" % handlarz["nazwa"], 1)
			_menu.set_item_disabled(0, true)
		_menu_p = p
		_menu.position = Vector2i(pos)
		_menu.reset_size()
		_menu.popup()
	elif przycisk == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_CTRL):
		_sprzedaj(p)


func _sprzedaj(p: Przedmiot) -> void:
	if p == null:
		return
	var c := cena_skupu(p)
	if c <= 0:
		return
	Gra.skrytka.usun(p)
	Gra.dodaj_bony(c)
	Dzwiek.graj("kasa", -6.0)
	_tooltip.visible = false
	_przebuduj()


func _hover(p: Przedmiot) -> void:
	if p == null:
		_tooltip.visible = false
		return
	var t := preload("res://scripts/ui/ekran_ekwipunku.gd").opis_przedmiotu(p)
	if handlarz.size() > 0 and Gra.skrytka.zawiera(p):
		var c := cena_skupu(p)
		t += "\n[color=#c9a54a]Skup: %s[/color]" % (("%d bonów" % c) if c > 0 else "nie kupuje")
	_tooltip_txt.text = t
	_tooltip.visible = true
	_tooltip.reset_size()
