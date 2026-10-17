extends Node
## Test interfejsu ekwipunku: przeciąganie przedmiotu ze skrytki do kieszeni i na slot.
## godot --headless --path . res://tests/test_ui.tscn

var bledy := 0


func _ready() -> void:
	Gra.nowa_gra()
	var ekran = load("res://scripts/ui/ekran_ekwipunku.gd").new()
	ekran.tryb_bazy = true
	add_child(ekran)
	await get_tree().process_frame
	ekran.otworz_skrytke()
	for i in 5:
		await get_tree().process_frame
	var skrytka_ui: SiatkaUI = null
	var kieszenie_ui: SiatkaUI = null
	for ui in ekran._siatki:
		if ui.siatka == Gra.skrytka:
			skrytka_ui = ui
		elif ui.siatka == Gra.ekw.kieszenie:
			kieszenie_ui = ui
	_ok(skrytka_ui != null and kieszenie_ui != null, "siatki skrytki i kieszeni istnieją")
	# bandaż ze skrytki do kieszeni
	var bandaz: Przedmiot = null
	for e in Gra.skrytka.items:
		if e["p"].id == "bandaz":
			bandaz = e["p"]
			break
	var poz := Gra.skrytka.pozycja(bandaz)
	var start := skrytka_ui.global_position + (Vector2(poz) + Vector2(0.5, 0.5)) * SiatkaUI.KOM
	var cel := kieszenie_ui.global_position + Vector2(2.5, 0.5) * SiatkaUI.KOM
	await _przeciagnij(start, cel)
	_ok(Gra.ekw.kieszenie.zawiera(bandaz), "bandaż przeciągnięty do kieszeni")
	_ok(not Gra.skrytka.zawiera(bandaz), "bandaż zniknął ze skrytki")
	# obrzyn ze skrytki na slot broni głównej
	var obrzyn: Przedmiot = null
	for e in Gra.skrytka.items:
		if e["p"].id == "obrzyn":
			obrzyn = e["p"]
	for ui in ekran._siatki:
		if is_instance_valid(ui) and ui.siatka == Gra.skrytka:
			skrytka_ui = ui
	var slot_ui: SlotUI = null
	for s in ekran._sloty:
		if s.slot == "glowna":
			slot_ui = s
	poz = Gra.skrytka.pozycja(obrzyn)
	start = skrytka_ui.global_position + (Vector2(poz) + Vector2(0.5, 0.5)) * SiatkaUI.KOM
	await _przeciagnij(start, slot_ui.get_global_rect().get_center())
	_ok(Gra.ekw.sloty["glowna"] == obrzyn, "obrzyn założony jako broń główna")
	# amunicja 12/70 ze skrytki na... (napełnianie magazynka PW-9 9x18 z opcji G)
	var mag: Przedmiot = null
	for e in Gra.skrytka.items:
		if e["p"].id == "mag_pw9":
			mag = e["p"]
	ekran.napelnij_wszystkie()
	_ok(mag.dane["naboje"] == 8, "napełnianie magazynków w bazie (jest %d)" % mag.dane["naboje"])
	print("BLEDY UI: ", bledy)
	get_tree().quit(bledy)


func _przeciagnij(a: Vector2, b: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = a
	m.global_position = a
	Input.parse_input_event(m)
	await get_tree().process_frame
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = a
	d.global_position = a
	Input.parse_input_event(d)
	await get_tree().process_frame
	await get_tree().process_frame
	var m2 := InputEventMouseMotion.new()
	m2.position = b
	m2.global_position = b
	Input.parse_input_event(m2)
	Input.warp_mouse(b)
	await get_tree().process_frame
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = b
	u.global_position = b
	Input.parse_input_event(u)
	await get_tree().process_frame
	await get_tree().process_frame


func _ok(w: bool, opis: String) -> void:
	print(("OK   " if w else "FAIL ") + opis)
	if not w:
		bledy += 1
