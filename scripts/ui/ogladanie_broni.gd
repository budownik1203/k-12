extends CanvasLayer
## Podgląd broni z bliska (J albo PPM na broni → „Oglądaj / dodatki”): broń trzymana bokiem przed sobą,
## obracana myszą (przeciąganie), po prawej lista slotów dodatków – co jest założone i co pasuje
## z ekwipunku. Założenie / zdjęcie odgrywa animację montażu na modelu (nakręcanie tłumika,
## wsuwanie celownika na szynę, zatrzask latarki). Dodatki warsztatowe tylko przy stole roboczym.

var ekran                    # ekran ekwipunku (logika montażu)
var gracz: Gracz
var otwarty := false
var _root: Control
var _lista: VBoxContainer
var _tytul: Label
var _opis: Label
var _ciagnie := false
var _klatka := 0

const NAZWY_SLOTOW := {"wylot": "Wylot lufy", "celownik": "Celownik", "chwyt": "Chwyt przedni", "latarka": "Latarka"}


func _ready() -> void:
	layer = 21
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = Motyw.motyw()
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", RamkaStyl.new(false, 12.0))
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -360
	panel.offset_right = -24
	panel.offset_top = 60
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	_tytul = Motyw.etykieta("", 16, Motyw.ZOLC, Motyw.mono_b())
	v.add_child(_tytul)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 4)
	v.add_child(_lista)
	_opis = Motyw.etykieta("", 12, Motyw.TEKST_CIEMNY, Motyw.cond())
	_opis.autowrap_mode = TextServer.AUTOWRAP_WORD
	_opis.custom_minimum_size = Vector2(300, 0)
	v.add_child(_opis)
	var podp := Motyw.etykieta("[LPM + ruch] obróć broń   [J / Esc] odłóż", 12, Motyw.TEKST_CIEMNY, Motyw.mono())
	podp.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	podp.offset_top = -40
	podp.offset_left = -200
	podp.offset_right = 200
	podp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(podp)
	_root.visible = false


func otworz() -> void:
	if gracz == null or gracz.bron.przedmiot == null:
		return
	otwarty = true
	_klatka = Engine.get_process_frames()
	_root.visible = true
	gracz.bron.ogladanie = true
	gracz.bron.ogl_obrot = Vector2.ZERO
	Sterowanie.blokada = true
	Sterowanie.przechwyc(false)
	get_tree().call_group("hud", "ukryj", true)
	Dzwiek.graj("klik", -10.0, 0.7)
	odswiez()


func zamknij() -> void:
	if not otwarty:
		return
	if not gracz.akcja.is_empty() and String(gracz.akcja.get("typ", "")) == "montaz":
		gracz.przerwij_akcje(true)
	otwarty = false
	_root.visible = false
	gracz.bron.ogladanie = false
	Sterowanie.blokada = false
	Sterowanie.przechwyc(true)
	get_tree().call_group("hud", "ukryj", false)


func _dostepne(slot: String, dozw: Array) -> Array:
	var out := []
	var siatki: Array = gracz.ekw.siatki()
	if ekran.tryb_bazy:
		siatki.append(Gra.skrytka)
	for s in siatki:
		for e in (s as Siatka).items:
			var p: Przedmiot = e["p"]
			if p.typ() == "dodatek" and p.id in dozw and p.defn()["dodatek"]["slot"] == slot:
				out.append([p, s])
	return out


func odswiez() -> void:
	for c in _lista.get_children():
		c.queue_free()
	var b: Przedmiot = gracz.bron.przedmiot
	if b == null:
		zamknij()
		return
	_tytul.text = b.nazwa().to_upper()
	var dozw_all: Dictionary = b.defn()["bron"].get("dodatki", {})
	if dozw_all.is_empty():
		_lista.add_child(Motyw.etykieta("Ta broń nie przyjmuje dodatków.", 13, Motyw.TEKST, Motyw.cond()))
	for slot in Przedmiot.SLOTY_DODATKOW:
		if not dozw_all.has(slot):
			continue
		_lista.add_child(Motyw.naszywka(NAZWY_SLOTOW.get(slot, slot)))
		var akt: Przedmiot = b.dodatek(slot)
		if akt:
			var h := HBoxContainer.new()
			h.add_child(Motyw.etykieta(akt.nazwa(), 13, Motyw.TEKST, Motyw.cond()))
			var sp := Control.new()
			sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(sp)
			var bt := Button.new()
			bt.text = "Zdejmij"
			var warsz: bool = akt.defn()["dodatek"]["montaz"] == "warsztat"
			bt.disabled = warsz and not ekran._warsztat and not ekran.tryb_bazy
			if bt.disabled:
				bt.tooltip_text = "Tylko na stole roboczym"
			var sl: String = slot
			bt.pressed.connect(func():
				ekran._zdejmij_dodatek(b, sl)
				_po_akcji())
			h.add_child(bt)
			_lista.add_child(h)
		else:
			var dost := _dostepne(slot, dozw_all[slot])
			if dost.is_empty():
				_lista.add_child(Motyw.etykieta("— wolny (brak pasującego dodatku)", 12, Motyw.TEKST_CIEMNY, Motyw.cond()))
			for el in dost:
				var d: Przedmiot = el[0]
				var h := HBoxContainer.new()
				h.add_child(Motyw.etykieta(d.nazwa(), 13, Motyw.TEKST, Motyw.cond()))
				var sp := Control.new()
				sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(sp)
				var bt := Button.new()
				bt.text = "Załóż"
				var warsz: bool = d.defn()["dodatek"]["montaz"] == "warsztat"
				bt.disabled = warsz and not ekran._warsztat and not ekran.tryb_bazy
				if bt.disabled:
					bt.tooltip_text = "Tylko na stole roboczym"
				var zr := {"typ": "siatka", "siatka": el[1]}
				bt.pressed.connect(func():
					ekran._montuj(b, d, zr)
					_po_akcji())
				h.add_child(bt)
				_lista.add_child(h)
	_opis.text = "Dodatki polowe zakłada się na miejscu (zajmuje to chwilę), warsztatowe – kolimator, luneta, chwyt – tylko przy stole roboczym w schronie."


func _po_akcji() -> void:
	# lista odświeża się po zakończeniu montażu (dodatek trafia na broń / do ekwipunku)
	var t := get_tree().create_timer(0.1)
	t.timeout.connect(_czekaj_na_koniec)


func _czekaj_na_koniec() -> void:
	if not otwarty:
		return
	if not gracz.akcja.is_empty():
		get_tree().create_timer(0.2).timeout.connect(_czekaj_na_koniec)
		return
	odswiez()


func _process(_delta: float) -> void:
	if not otwarty:
		return
	if Engine.get_process_frames() > _klatka + 1 and (Input.is_action_just_pressed("ogladaj") or Input.is_action_just_pressed("ekwipunek")):
		zamknij()
		Sterowanie.blokuj_tab_do = Engine.get_process_frames() + 2
	if gracz.cialo.martwy:
		zamknij()


func _input(event: InputEvent) -> void:
	if not otwarty:
		return
	if event.is_action_pressed("pauza"):
		zamknij()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var nad_panelem := false
		for c in _root.get_children():
			if c is PanelContainer and (c as Control).get_global_rect().has_point(event.position):
				nad_panelem = true
		_ciagnie = event.pressed and not nad_panelem
	elif event is InputEventMouseMotion and _ciagnie:
		var o: Vector2 = gracz.bron.ogl_obrot
		o.x += event.relative.x * 0.008
		o.y = clampf(o.y + event.relative.y * 0.006, -0.8, 0.8)
		gracz.bron.ogl_obrot = o
