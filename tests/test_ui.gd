extends Node
## Test interfejsu ekwipunku: przeciąganie przedmiotu ze skrytki do kieszeni i na slot.
## godot --headless --path . res://tests/test_ui.tscn

var bledy := 0


func _ready() -> void:
	Gra.ZAPIS = "user://zapis_test.json"
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
	# dodatki: kolimator (warsztatowy) bez stołu – odmowa, przy stole – montaż; tłumik polowy na PW-9
	var pm := Przedmiot.nowy("pm63")
	var kol := Przedmiot.nowy("kolimator")
	Gra.skrytka.dodaj(kol)
	var zr := {"typ": "siatka", "siatka": Gra.skrytka}
	ekran._warsztat = false
	ekran._montuj(pm, kol, zr)
	_ok(pm.dodatek("celownik") == null, "kolimator bez stołu roboczego nie montuje się")
	ekran._warsztat = true
	ekran._montuj(pm, kol, zr)
	_ok(pm.dodatek("celownik") == kol and not Gra.skrytka.zawiera(kol), "kolimator zamontowany przy stole")
	var tl := Przedmiot.nowy("tlumik_762")
	Gra.skrytka.dodaj(tl)
	ekran._montuj(pm, tl, zr)
	_ok(pm.dodatek("wylot") == null and Gra.skrytka.zawiera(tl), "tłumik 7,62 nie pasuje do PM-63")
	ekran._zdejmij_dodatek(pm, "celownik")
	_ok(pm.dodatek("celownik") == null, "kolimator zdjęty")
	var t9 := Przedmiot.nowy("tlumik_9")
	Gra.skrytka.dodaj(t9)
	ekran._montuj(pm, t9, zr)
	_ok(pm.dodatek("wylot") == t9, "tłumik 9 mm na PM-63")
	var kopia := Przedmiot.from_dict(pm.to_dict())
	_ok(kopia.dodatek("wylot") != null and kopia.dodatek("wylot").id == "tlumik_9", "dodatek przetrwał zapis")
	_ok(pm.waga() > Przedmiot.nowy("pm63").waga(), "dodatek zwiększa wagę broni")
	await _test_zamiany(ekran)
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



## Obrót i odłożenie w to samo miejsce, zamiana miejscami, podświetlenie celu interakcji.
func _test_zamiany(ekran) -> void:
	var sk: Siatka = Gra.skrytka
	var ui: SiatkaUI = null
	for u in ekran._siatki:
		if is_instance_valid(u) and u.siatka == sk:
			ui = u
	# wolny obszar 6x6
	var x0 := -1
	var y0 := -1
	var pr := Przedmiot.nowy("konserwa")
	for y in range(0, sk.h - 6):
		for x in range(3, sk.w - 6):
			var ok := true
			for yy in 6:
				for xx in 6:
					if sk.przedmiot_w(x + xx, y + yy) != null:
						ok = false
			if ok:
				x0 = x
				y0 = y
				break
		if x0 >= 0:
			break
	_ok(x0 >= 0, "wolne miejsce w skrytce na test")
	if x0 < 0:
		return
	var K := SiatkaUI.KOM
	# 1) szyna 1x4 podniesiona, obrócona [R] i odłożona na swoje miejsce (środek w środku dawnego obrysu)
	var szyna := Przedmiot.nowy("szyna")
	sk.poloz(szyna, x0 + 2, y0, false)
	ekran._drag = {"p": szyna, "z": {"typ": "siatka", "siatka": sk}, "off": Vector2(0.5, 2.0) * K, "rot": false}
	ekran._drag["rot"] = true
	ekran._drag["off"] = Vector2(4, 1) * K * 0.5
	var m := ui.global_position + Vector2(x0 + 2.5, y0 + 2.0) * K
	ekran._upusc_drag(false, m)
	await get_tree().process_frame
	for u in ekran._siatki:
		if is_instance_valid(u) and u.siatka == sk:
			ui = u
	var pz := sk.pozycja(szyna)
	_ok(szyna.obrot and sk.zawiera(szyna), "obrócona szyna odłożona w swoje miejsce (pozycja %s)" % pz)
	sk.usun(szyna)
	# 2) zamiana: wytrych upuszczony na konserwę – zamieniają się miejscami
	var kons := Przedmiot.nowy("konserwa")
	var wytr := Przedmiot.nowy("wytrych")
	sk.poloz(kons, x0, y0, false)
	sk.poloz(wytr, x0 + 4, y0 + 1, false)
	ekran._drag = {"p": wytr, "z": {"typ": "siatka", "siatka": sk}, "off": Vector2(0.5, 1.0) * K, "rot": false}
	ekran._upusc_drag(false, ui.global_position + Vector2(x0 + 1.0, y0 + 1.0) * K)
	await get_tree().process_frame
	for u in ekran._siatki:
		if is_instance_valid(u) and u.siatka == sk:
			ui = u
	var pk := sk.pozycja(kons)
	var pw := sk.pozycja(wytr)
	_ok(sk.zawiera(kons) and sk.zawiera(wytr) and pk != Vector2i(x0, y0) and pw.x <= x0 + 1, "zamiana miejscami: konserwa %s, wytrych %s" % [pk, pw])
	sk.usun(kons)
	sk.usun(wytr)
	# 3) podświetlenie celu: amunicja nad magazynkiem – niebieskie, amunicja nad tą samą – pomarańczowe
	var mag := Przedmiot.nowy("mag_pw9")
	var am := Przedmiot.nowy("a_9x18", 10)
	var am2 := Przedmiot.nowy("a_9x18", 10)
	sk.poloz(mag, x0, y0, false)
	sk.poloz(am2, x0 + 3, y0, false)
	ekran._po_zmianie()
	await get_tree().process_frame
	for u in ekran._siatki:
		if is_instance_valid(u) and u.siatka == sk:
			ui = u
	var c1: Dictionary = ekran.cel_interakcji_przeciagania(am, ui.global_position + Vector2(x0 + 0.5, y0 + 0.5) * K)
	var c2: Dictionary = ekran.cel_interakcji_przeciagania(am, ui.global_position + Vector2(x0 + 3.5, y0 + 0.5) * K)
	_ok(not c1.is_empty() and (c1["kolor"] as Color).b > 0.9 and (c1["kolor"] as Color).r < 0.6, "podświetlenie: amunicja nad magazynkiem – %s" % c1.get("opis", "-"))
	_ok(not c2.is_empty() and (c2["kolor"] as Color).r > 0.9 and (c2["kolor"] as Color).b < 0.4, "podświetlenie: stos nad stosem – %s" % c2.get("opis", "-"))
	if OS.get_cmdline_user_args().has("--zrzut"):
		sk.poloz(am, x0 + 6, y0 + 4, false)
		ekran._po_zmianie()
		await get_tree().process_frame
		ekran._drag = {"p": am, "z": {"typ": "siatka", "siatka": sk}, "off": Vector2(0.5, 0.5) * K, "rot": false}
		for u in ekran._siatki:
			if is_instance_valid(u) and u.siatka == sk:
				ui = u
		Input.warp_mouse(ui.global_position + Vector2(x0 + 0.5, y0 + 0.5) * K)
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/b15/podswietlenie.png")
	sk.usun(mag)
	sk.usun(am2)
	ekran._drag = {}
