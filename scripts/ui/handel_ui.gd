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
		# sprzęt wyższej klasy (kl. 4, BP, tłumiki, celowniki, plecak wojskowy) – u przedstawicieli frakcji, za reputację
		"oferta": [["pw9", 1], ["obrzyn", 1], ["pm63", 1], ["kb47", 1], ["mag_pw9", 1], ["mag_pm63", 1], ["mag_kb47", 1],
			["a_9x18", 50], ["a_12", 20], ["a_762", 60], ["kamizelka_kl2", 1], ["helm_wz67", 1], ["hamulec", 1], ["latarka_taktyczna", 1],
			["zestaw_czyszczacy", 1], ["napiersnik", 1], ["plecak_turystyczny", 1]],
		"skupuje": ["bron", "magazynek", "amunicja", "pancerz", "pojemnik", "dodatek", "granat"], "skup": 0.45,
	},
	"medyk": {
		"nazwa": "Medyk", "opis": "zmęczony lekarz-uciekinier z kompleksu",
		"powitania": ["Znowu ty. Co tym razem przestało działać?", "Nie pytaj, co jest w tabletkach. Ja też nie pytałem.", "Krwawisz mi na podłogę. Podłoga też jest na kartki."],
		"oferta": [["bandaz", 1], ["opatrunek", 1], ["szyna", 1], ["bolostop", 1], ["apteczka", 1]],
		"skupuje": ["med"], "skup": 0.5,
	},
	"posrednik": {
		"nazwa": "Pośrednik", "opis": "skup i sprzedaż, znajomości u Szabrowników",
		"powitania": ["Wszystko ma swoją cenę. Ty też, ale na razie kupuję zegarki.", "Pochodzenie towaru mnie nie interesuje. Stan – owszem.", "Dla stałych klientów rabat. Ty jeszcze nie jesteś stały. Ani żywy na dłużej."],
		"oferta": [["worek", 1], ["chlebak", 1], ["kamizelka_wedkarska", 1], ["kamizelka_mysliwska", 1], ["latarka", 1], ["mapa", 1], ["kompas", 1], ["klucz_piwnica", 1], ["konserwa", 1], ["suchary", 1], ["woda", 1], ["papierosy", 1]],
		"skupuje": ["lup", "klucz", "latarka", "mapa", "kompas", "med", "pojemnik", "bron", "magazynek", "amunicja", "pancerz"], "skup": 0.4, "skup_lup": 0.6,
	},
	"kwatermistrz": {
		"nazwa": "Kwatermistrz", "opis": "zaopatrzenie kwater placówki",
		"powitania": ["Meble z przydziału. Przydział jest, mebli mało. Płać.", "Kwatera to nie hotel. Ale prycza się należy. Za opłatą.", "Szafka metalowa – klasyk. Kłódka osobno. Żartuję, jest w cenie."],
		"oferta": [], "skupuje": [], "skup": 0.0,
	},
}

## Skup u przedstawicieli frakcji (każdy bierze swoje).
const SKUP_FRAKCJI := {"szabrownik": [["lup", "klucz", "mapa"], 0.55], "najemnik": [["med", "dodatek", "amunicja"], 0.45], "wojskowy": [["bron", "magazynek", "pancerz", "granat"], 0.45]}


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
	if FrakcjeBazy.DANE.has(id):
		var fd: Dictionary = FrakcjeBazy.DANE[id]
		var wrogi := FrakcjeBazy.rep(id) <= FrakcjeBazy.PROG_WROGOSCI
		handlarz = {"nazwa": fd["przedstawiciel"], "opis": "%s · reputacja %+d (%s)" % [fd["opis"], FrakcjeBazy.rep(id), FrakcjeBazy.opis_rep(FrakcjeBazy.rep(id))],
			"powitania": fd["wrogie"] if wrogi else fd["powitania"], "oferta": fd["oferta"], "frakcja": id, "wrogi": wrogi,
			"skupuje": [] if wrogi else SKUP_FRAKCJI[id][0], "skup": SKUP_FRAKCJI[id][1]}
	else:
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


## Zlecenia Pośrednika: oferty do przyjęcia (najwyżej dwa naraz) i przyjęte z postępem; dostawę oddaje się
## ze skrytki.
func _panel_zlecen(od := "") -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var akt: Array = Gra.kontrakty.get("aktywne", [])
	v.add_child(Motyw.naglowek("Zlecenia  (przyjęte: %d/%d)" % [akt.size(), Gra.MAX_ZLECEN]))
	for k in akt:
		if String(k.get("od", "")) != od:
			continue
		var r := HBoxContainer.new()
		var post := "" if k["typ"] in ["dostawa", "wyjscie", "zwiad"] else "  [%d/%d]" % [int(k["postep"]), int(k["ile"])]
		r.add_child(Motyw.etykieta("✔ " + String(k["opis"]) + post + "  ·  %d bonów" % int(k["nagroda"]), 14, Motyw.ZOLC))
		if k["typ"] == "dostawa":
			var b := Button.new()
			b.text = "Oddaj"
			var ma := Gra.skrytka.items.filter(func(e): return (e["p"] as Przedmiot).id == k["cel"]).size()
			b.disabled = ma < int(k["ile"])
			b.tooltip_text = "Przedmioty muszą być w skrytce (%d/%d)." % [ma, int(k["ile"])]
			b.pressed.connect(func():
				if Gra.oddaj_dostawe(k):
					Dzwiek.graj("kasa", -4.0)
					_powitanie.text = "„Interes z tobą to przyjemność. Prawie.”"
					_skrytka_ui.queue_redraw()
					_przebuduj())
			r.add_child(b)
		v.add_child(r)
	var of: Array = Gra.kontrakty.get("oferty", []) if od == "" else (Gra.kontrakty.get("frakcje", {}) as Dictionary).get(od, [])
	for i in of.size():
		var k2: Dictionary = of[i]
		var r2 := HBoxContainer.new()
		r2.add_child(Motyw.etykieta("• " + String(k2["opis"]) + "  ·  %d bonów" % int(k2["nagroda"]) + ("  · rep. +%d" % int(k2["rep"]) if k2.has("rep") else ""), 14))
		var b2 := Button.new()
		b2.text = "Przyjmij"
		b2.disabled = akt.size() >= Gra.MAX_ZLECEN or bool(handlarz.get("wrogi", false))
		var idx := i
		b2.pressed.connect(func():
			if Gra.przyjmij_kontrakt(idx, od):
				Dzwiek.graj("pieczatka", -4.0)
				_powitanie.text = "„Umowa ustna, ale wiążąca. Bardziej niż myślisz.”"
				_przebuduj())
		r2.add_child(b2)
		v.add_child(r2)
	if akt.filter(func(k): return String(k.get("od", "")) == od).is_empty() and of.is_empty():
		v.add_child(Motyw.etykieta("Na razie nic. Wróć po następnym wyjściu.", 14, Motyw.TEKST_CIEMNY))
	return v


func _przebuduj() -> void:
	for c in _oferta.get_children():
		c.queue_free()
	for c in _dodatki.get_children():
		c.queue_free()
	if handlarz["id"] == "kwatermistrz":
		_oferta_mebli()
	var fr := String(handlarz.get("frakcja", ""))
	for o in handlarz["oferta"]:
		var pid: String = o[0]
		var ile: int = o[1]
		var prog: int = int(o[2]) if o.size() > 2 else -999
		var d := Dane.def(pid)
		var cena := int(d["cena"]) * ile
		if fr != "":
			cena = int(cena * FrakcjeBazy.mnoznik_ceny(fr))
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
		var wrogi := bool(handlarz.get("wrogi", false))
		var zablok := fr != "" and ((prog > 0 and FrakcjeBazy.rep(fr) < prog) or wrogi)
		b.text = ("rep. %+d" % prog) if zablok and not wrogi else "Kup"
		b.disabled = Gra.bony < cena or zablok
		if zablok:
			n.modulate = Color(1, 1, 1, 0.45)
			b.tooltip_text = "Dostępne od reputacji %+d (masz %+d)." % [prog, FrakcjeBazy.rep(fr)]
		b.pressed.connect(func(): _kup(pid, ile, cena))
		r.add_child(b)
		_oferta.add_child(r)
	if fr != "":
		_dodatki.add_child(_panel_frakcji(fr))
		_dodatki.add_child(_panel_zlecen(fr))
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
			_dodatki.add_child(_panel_zlecen())
			var ub := VBoxContainer.new()
			ub.add_theme_constant_override("separation", 4)
			ub.add_child(Motyw.naglowek("Ubezpieczenie"))
			_dodatki.add_child(ub)
			for sl in ["glowna", "pistolet", "pancerz", "helm", "kamizelka", "plecak"]:
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
				ub.add_child(bu)
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


## Reputacja u frakcji: poziom, rozejm w strefie, ceny.
func _panel_frakcji(fr: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.add_child(Motyw.naglowek("Reputacja"))
	var r := FrakcjeBazy.rep(fr)
	v.add_child(Motyw.etykieta("%s: %+d (%s)" % [FrakcjeBazy.DANE[fr]["nazwa"], r, FrakcjeBazy.opis_rep(r)], 14, Motyw.ZOLC, Motyw.mono_b()))
	var pr := FrakcjeBazy.prog_rozejmu(fr)
	v.add_child(Motyw.etykieta(("W strefie nie strzelają pierwsi (rozejm do twojego strzału)." if r >= pr else "Rozejm w strefie od reputacji %+d." % pr), 13, Motyw.TEKST_CIEMNY))
	v.add_child(Motyw.etykieta("Ceny: %+d%%  ·  zabity ich człowiek: %d" % [int(round((FrakcjeBazy.mnoznik_ceny(fr) - 1.0) * 100.0)), FrakcjeBazy.ZABICIE], 13, Motyw.TEKST_CIEMNY))
	return v


## Kwatermistrz: meble do kryjówki (trafiają do magazynu kwatery, stawia się je w kryjówce – [B]).
func _oferta_mebli() -> void:
	var naglowek := Motyw.etykieta("Meble trafiają do magazynu kwatery – w kryjówce [B] otwiera plan i stawianie.", 13, Motyw.TEKST_CIEMNY)
	naglowek.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_oferta.add_child(naglowek)
	for id in MebleKryjowki.KATALOG:
		var m: Dictionary = MebleKryjowki.KATALOG[id]
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		var postawione := Gra.kryjowka.filter(func(e): return String(e["id"]) == id).size()
		var zapas := int(Gra.meble_zapas.get(id, 0))
		var n := Motyw.etykieta(MebleKryjowki.nazwa(id) + ("   [%d+%d]" % [postawione, zapas] if postawione + zapas > 0 else ""), 15)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.mouse_filter = Control.MOUSE_FILTER_STOP
		n.tooltip_text = String(m["opis"]) + "\n[postawione + w magazynie]"
		r.add_child(n)
		var cena := int(m["cena"])
		r.add_child(Motyw.etykieta("%d" % cena, 15, Motyw.ZOLC, Motyw.mono_b()))
		var b := Button.new()
		b.text = "Kup"
		b.disabled = Gra.bony < cena
		b.pressed.connect(func():
			if Gra.bony < cena:
				return
			Gra.dodaj_bony(-cena)
			Gra.meble_zapas[id] = int(Gra.meble_zapas.get(id, 0)) + 1
			Dzwiek.graj("kasa", -6.0)
			_powitanie.text = "„%s – wydane. Postaw sobie sam, tragarzy nie mamy.”" % MebleKryjowki.nazwa(id)
			Gra.zapisz()
			_przebuduj())
		r.add_child(b)
		_oferta.add_child(r)


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
	if p.dane.get("przydzial", false):
		return 0
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
