extends Node
## Baza między rajdami: schron poza kordonem. Handlarze, skrytka, kryjówka i wyjście do strefy.
## Gracz chodzi w pierwszej osobie, bez broni w rękach.

var widok: Dictionary
var swiat: Node3D
var gracz: Gracz
var ekran_ekw: Node
var handel: Node
var _wyjscie_ui: Control
var _wyjscie_root: CanvasLayer
var _hud_prompt: Label
var _hud_info: Label
var _komunikaty: VBoxContainer

const SZER := 16.0
const GLEB := 10.0
const WYS := 3.0


func _ready() -> void:
	add_to_group("ui_bazy")
	add_to_group("hud")
	widok = Widok3D.zbuduj(self, 0.06, 0.16)
	swiat = widok["swiat"]
	_buduj_schron()
	gracz = Gracz.new()
	gracz.tryb_bazy = true
	swiat.add_child(gracz)
	gracz.global_position = Vector3(8.0, 0.05, 7.2)
	gracz.rotation.y = 0.0
	gracz.komunikat.connect(komunikat)
	ekran_ekw = load("res://scripts/ui/ekran_ekwipunku.gd").new()
	ekran_ekw.gracz = gracz
	ekran_ekw.tryb_bazy = true
	add_child(ekran_ekw)
	handel = load("res://scripts/ui/handel_ui.gd").new()
	add_child(handel)
	var pauza = load("res://scripts/ui/menu_pauzy.gd").new()
	pauza.w_rajdzie = false
	add_child(pauza)
	_hud()
	_ekran_wyjscia()
	Dzwiek.ambient("ambient_baza", self, -6.0)
	Sterowanie.przechwyc(true)
	Sterowanie.blokada = false
	Sterowanie.menu_otwarte = false
	komunikat("Baza. [F] rozmowa/użycie, [Tab] ekwipunek i skrytka.")
	if not Gra.zdrowie.is_empty():
		komunikat("Masz nieleczone urazy. Medyk przyjmuje (odpłatnie).")
	var args := OS.get_cmdline_user_args()
	if args.has("--zrzuty"):
		_zrzuty.call_deferred(args[args.find("--zrzuty") + 1])


func _buduj_schron() -> void:
	var b := Kit.Budowniczy.new()
	var uv := func(u: float, y: float) -> Vector2: return Vector2(u, 1.0 - y / 2.8)
	b.plaszczyzna("beton", 0, 0, SZER, GLEB, 0.0, true, 2.0, 1.0)
	b.plaszczyzna("beton", 0, 0, SZER, GLEB, WYS, false, 2.0, 1.0)
	b.sciana("beton_sciana", Vector3(0, 0, 0), Vector3(SZER, 0, 0), 0.0, WYS, 1.0, uv)
	b.sciana("beton_sciana", Vector3(SZER, 0, GLEB), Vector3(0, 0, GLEB), 0.0, WYS, 1.0, uv)
	b.sciana("beton_sciana", Vector3(0, 0, GLEB), Vector3(0, 0, 0), 0.0, WYS, 1.0, uv)
	b.sciana("beton_sciana", Vector3(SZER, 0, 0), Vector3(SZER, 0, GLEB), 0.0, WYS, 1.0, uv)
	# przegrody między stanowiskami handlarzy
	for x in [5.5, 10.5]:
		b.sciana("cegla", Vector3(x - 0.1, 0, 3.0), Vector3(x - 0.1, 0, 0.0), 0.0, WYS, 1.0, uv)
		b.sciana("cegla", Vector3(x + 0.1, 0, 0.0), Vector3(x + 0.1, 0, 3.0), 0.0, WYS, 1.0, uv)
	var mi := MeshInstance3D.new()
	mi.mesh = b.zbuduj()
	swiat.add_child(mi)
	var sb := StaticBody3D.new()
	sb.collision_layer = Balistyka.WARSTWA_SWIAT
	swiat.add_child(sb)
	for box in [[Vector3(SZER / 2, -0.2, GLEB / 2), Vector3(SZER, 0.4, GLEB)],
			[Vector3(SZER / 2, 1.5, -0.1), Vector3(SZER, 3, 0.2)], [Vector3(SZER / 2, 1.5, GLEB + 0.1), Vector3(SZER, 3, 0.2)],
			[Vector3(-0.1, 1.5, GLEB / 2), Vector3(0.2, 3, GLEB)], [Vector3(SZER + 0.1, 1.5, GLEB / 2), Vector3(0.2, 3, GLEB)],
			[Vector3(5.5, 1.5, 1.5), Vector3(0.2, 3, 3)], [Vector3(10.5, 1.5, 1.5), Vector3(0.2, 3, 3)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = box[1]
		cs.shape = bs
		cs.position = box[0]
		sb.add_child(cs)
	var gen := GeneratorBiomu.new()
	gen.swiat = swiat
	gen.meble = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dane/meble.json"))
	# stanowiska handlarzy
	_handlarz("zbrojmistrz", "Zbrojmistrz", Vector3(2.75, 0, 0.9), {"ubranie": Color(0.26, 0.29, 0.22), "spodnie": Color(0.2, 0.22, 0.18), "dodatek": Color(0.2, 0.24, 0.16)})
	gen._mebel("stol_warsztatowy", Vector3(2.75, 0, 2.1), PI, true)
	gen._mebel("regal_metalowy", Vector3(1.0, 0, 0.35), 0.0, true)
	gen._mebel("skrzynia_wojskowa", Vector3(4.4, 0, 0.45), 0.0, true)
	gen._mebel("worki_piasek", Vector3(4.4, 0, 2.6), PI / 2.0, true)
	_handlarz("medyk", "Medyk", Vector3(8.0, 0, 0.9), {"ubranie": Color(0.5, 0.52, 0.5), "spodnie": Color(0.3, 0.3, 0.32), "dodatek": Color(0.8, 0.8, 0.75)})
	gen._mebel("biurko", Vector3(8.0, 0, 2.1), PI, true)
	gen._mebel("lozko", Vector3(6.6, 0, 0.6), 0.0, true)
	gen._mebel("apteczka_scienna", Vector3(9.5, 1.3, 0.15), 0.0, false)
	gen._mebel("szafka_metalowa", Vector3(10.0, 0, 0.35), 0.0, true)
	_handlarz("posrednik", "Pośrednik", Vector3(13.25, 0, 0.9), {"ubranie": Color(0.24, 0.2, 0.18), "spodnie": Color(0.15, 0.14, 0.13), "dodatek": Color(0.3, 0.24, 0.2)})
	gen._mebel("stol", Vector3(13.25, 0, 2.1), 0.0, true)
	gen._mebel("regal_metalowy", Vector3(11.4, 0, 0.35), 0.0, true)
	gen._mebel("regal_metalowy", Vector3(15.0, 0, 0.35), 0.0, true)
	gen._mebel("tablica_ogloszen", Vector3(14.6, 1.3, 2.9), PI / 2.0 + PI, false)
	# skrytka (szafki przy lewej ścianie)
	for i in 3:
		var sz := gen._mebel("szafka_metalowa", Vector3(0.35, 0, 5.4 + i * 0.55), PI / 2.0, true)
		var it := StaticBody3D.new()
		it.collision_layer = Balistyka.WARSTWA_INTERAKCJE
		it.set_meta("interakcja", self)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.6, 1.8, 0.6)
		cs.shape = bs
		cs.position.y = 0.9
		it.add_child(cs)
		swiat.add_child(it)
		it.position = sz.position
	# kryjówka
	gen._mebel("dywan", Vector3(13.0, 0, 7.5), 0.0, false)
	gen._mebel("wersalka", Vector3(13.0, 0, 9.5), PI, true)
	gen._mebel("stol", Vector3(13.0, 0, 7.4), 0.0, true)
	gen._mebel("krzeslo", Vector3(12.2, 0, 7.4), PI / 2.0, true)
	gen._mebel("telewizor", Vector3(15.6, 0, 7.5), -PI / 2.0, true)
	gen._mebel("szafa", Vector3(15.6, 0, 9.3), -PI / 2.0, true)
	gen._mebel("stol_warsztatowy", Vector3(0.45, 0, 8.6), PI / 2.0, true)
	# wyjście do strefy
	var drzwi: Node3D = load("res://assets/models/drzwi_piwnica.glb").instantiate()
	swiat.add_child(drzwi)
	drzwi.position = Vector3(8.0, 0, GLEB - 0.1)
	drzwi.rotation.y = PI
	gen._mebel("znak_wyjscie", Vector3(8.0, 2.3, GLEB - 0.05), PI, false)
	var w := StaticBody3D.new()
	w.collision_layer = Balistyka.WARSTWA_INTERAKCJE
	w.set_meta("interakcja", _Wyjscie.new(self))
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(1.2, 2.2, 0.4)
	cs2.shape = bs2
	cs2.position.y = 1.1
	w.add_child(cs2)
	swiat.add_child(w)
	w.position = Vector3(8.0, 0, GLEB - 0.2)
	# światło: ciepłe, stabilne (baza jest bezpieczna)
	for p in [Vector3(2.75, WYS, 2.0), Vector3(8.0, WYS, 2.0), Vector3(13.25, WYS, 2.0), Vector3(4.0, WYS, 7.0), Vector3(12.5, WYS, 7.5)]:
		var lampa: Node3D = load("res://assets/models/plafon.glb").instantiate()
		swiat.add_child(lampa)
		lampa.position = p
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.6)
		l.light_energy = 1.4
		l.omni_range = 7.5
		l.omni_attenuation = 0.9
		swiat.add_child(l)
		l.position = p + Vector3(0, -0.4, 0)


func _handlarz(id: String, nazwa: String, pos: Vector3, kol: Dictionary) -> void:
	var n := PostacNPC.new()
	n.nazwa = nazwa
	n.id_handlarza = id
	n.wariant = id
	n.kolory = kol
	swiat.add_child(n)
	n.position = pos
	n.rotation.y = PI


# --- interakcja ze skrytką (szafki)
func tekst_interakcji(_g) -> String:
	return "Skrytka i ekwipunek"


func interakcja(_g) -> void:
	ekran_ekw.otworz_skrytke()


func otworz_handel(id: String) -> void:
	handel.otworz(id)


class _Wyjscie:
	extends RefCounted
	var baza

	func _init(b) -> void:
		baza = b

	func tekst_interakcji(_g) -> String:
		return "Wyjdź do strefy (rajd)"

	func interakcja(_g) -> void:
		baza.pokaz_wyjscie()


# ------------------------------------------------------------------ HUD bazy

func _hud() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Motyw.motyw()
	cl.add_child(root)
	_hud_prompt = Label.new()
	_hud_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hud_prompt.offset_left = -400
	_hud_prompt.offset_right = 400
	_hud_prompt.offset_top = -130
	_hud_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_prompt.add_theme_font_size_override("font_size", 17)
	root.add_child(_hud_prompt)
	_hud_info = Label.new()
	_hud_info.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud_info.offset_left = -420
	_hud_info.offset_right = -24
	_hud_info.offset_top = 20
	_hud_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_info.add_theme_font_override("font", Motyw.mono())
	_hud_info.add_theme_font_size_override("font_size", 14)
	root.add_child(_hud_info)
	_komunikaty = VBoxContainer.new()
	_komunikaty.position = Vector2(24, 20)
	root.add_child(_komunikaty)
	var kropka := ColorRect.new()
	kropka.color = Color(0.85, 0.82, 0.7, 0.6)
	kropka.set_anchors_preset(Control.PRESET_CENTER)
	kropka.offset_left = -1.5
	kropka.offset_top = -1.5
	kropka.offset_right = 1.5
	kropka.offset_bottom = 1.5
	root.add_child(kropka)


func _process(_d: float) -> void:
	_hud_prompt.text = ("[F] " + gracz.tekst_interakcji) if gracz.tekst_interakcji != "" and not Sterowanie.blokada else ""
	var s: Dictionary = Gra.statystyki
	_hud_info.text = "BONY: %d\nRajdy: %d · przeżyte: %d · zgony: %d" % [Gra.bony, s["rajdy"], s["przezyte"], s["zgony"]]


func komunikat(t: String) -> void:
	var l := Motyw.etykieta(t, 15)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_komunikaty.add_child(l)
	while _komunikaty.get_child_count() > 5:
		var c := _komunikaty.get_child(0)
		_komunikaty.remove_child(c)
		c.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ ekran wyjścia na rajd

func _ekran_wyjscia() -> void:
	_wyjscie_root = CanvasLayer.new()
	_wyjscie_root.layer = 25
	add_child(_wyjscie_root)
	_wyjscie_ui = Control.new()
	_wyjscie_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wyjscie_ui.theme = Motyw.motyw()
	_wyjscie_ui.visible = false
	_wyjscie_root.add_child(_wyjscie_ui)


func pokaz_wyjscie() -> void:
	for c in _wyjscie_ui.get_children():
		c.queue_free()
	var tlo := ColorRect.new()
	tlo.color = Color(0, 0, 0, 0.8)
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wyjscie_ui.add_child(tlo)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wyjscie_ui.add_child(cc)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(560, 0)
	p.add_theme_stylebox_override("panel", Motyw.panel(Color(0.78, 0.74, 0.62), Color(0.3, 0.26, 0.2), 2))
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var ciemny := Color(0.15, 0.13, 0.1)
	v.add_child(Motyw.etykieta("ROZKAZ WYJŚCIA DO STREFY NR %d/K-12" % (Gra.statystyki["rajdy"] + 1), 20, ciemny, Motyw.mono_b()))
	v.add_child(Motyw.etykieta("Obszar: Biom 1 – Blokowisko (przedmieścia, osiedle z wielkiej płyty)", 14, ciemny))
	v.add_child(Motyw.etykieta("Cel: wejść, zebrać, wyjść. Kolejność nie podlega negocjacji.", 14, ciemny))
	var e: Ekwipunek = Gra.ekw
	var bronie := []
	for sl in ["glowna", "pistolet"]:
		if e.sloty[sl]:
			bronie.append(e.sloty[sl].nazwa())
	var bron := ", ".join(bronie) if not bronie.is_empty() else "brak"
	v.add_child(Motyw.etykieta("Broń: %s" % bron, 14, ciemny, Motyw.mono()))
	v.add_child(Motyw.etykieta("Wartość wyposażenia (ryzykowana): %d bonów" % e.wartosc(), 14, ciemny, Motyw.mono()))
	v.add_child(Motyw.etykieta("Waga efektywna: %.1f kg" % e.waga(), 14, ciemny, Motyw.mono()))
	var ostrz := []
	if not Gra.ma_bron():
		ostrz.append("BRAK BRONI. Zbrojmistrz wyda darmowy zestaw startowy.")
	if not Gra.zdrowie.is_empty():
		ostrz.append("Nieleczone urazy (koszt u Medyka: %d bonów)." % load("res://scripts/ui/handel_ui.gd").koszt_leczenia())
	var mags := 0
	for s in e.siatki():
		for it in (s as Siatka).items:
			if it["p"].typ() == "magazynek" and it["p"].dane["naboje"] > 0:
				mags += 1
	if Gra.ma_bron() and mags == 0 and (e.sloty["glowna"] == null or not e.sloty["glowna"].defn()["bron"].has("wewnetrzny")):
		ostrz.append("Brak zapasowych załadowanych magazynków.")
	for o in ostrz:
		v.add_child(Motyw.etykieta("⚠ " + o, 14, Color(0.55, 0.1, 0.06), Motyw.mono_b()))
	v.add_child(Motyw.etykieta("Wszystko, co masz przy sobie, możesz stracić.", 13, Color(0.35, 0.3, 0.25)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var go := Button.new()
	go.text = "Wejdź do strefy"
	go.pressed.connect(func():
		Gra.zapisz()
		Dzwiek.graj("drzwi", 0.0)
		Gra.rozpocznij_rajd())
	h.add_child(go)
	if not Gra.ma_bron():
		var zs := Button.new()
		zs.text = "Pobierz zestaw startowy"
		zs.pressed.connect(func():
			Gra.wydaj_zestaw_startowy()
			pokaz_wyjscie())
		h.add_child(zs)
	var an := Button.new()
	an.text = "Jeszcze nie"
	an.pressed.connect(_ukryj_wyjscie)
	h.add_child(an)
	_wyjscie_ui.visible = true
	Sterowanie.blokada = true
	Sterowanie.przechwyc(false)


func _ukryj_wyjscie() -> void:
	_wyjscie_ui.visible = false
	Sterowanie.blokada = false
	Sterowanie.przechwyc(true)


func _input(event: InputEvent) -> void:
	if _wyjscie_ui and _wyjscie_ui.visible and event.is_action_pressed("pauza"):
		_ukryj_wyjscie()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ test wizualny

func _zrzuty(katalog: String) -> void:
	DirAccess.make_dir_recursive_absolute(katalog)
	gracz.sterowanie = false
	var ujecia := [[Vector3(8.0, 0.05, 7.5), 0.0], [Vector3(6.0, 0.05, 4.5), 0.45], [Vector3(11.0, 0.05, 5.0), -1.2], [Vector3(4.0, 0.05, 4.5), PI * 0.75]]
	var n := 0
	for u in ujecia:
		gracz.global_position = u[0]
		gracz.rotation.y = u[1]
		for f in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("baza_%d.png" % n))
		n += 1
	handel.otworz("zbrojmistrz")
	for f in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("baza_handel.png"))
	handel.zamknij()
	pokaz_wyjscie()
	for f in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("baza_wyjscie.png"))
	print("zrzuty bazy: ", n)
	get_tree().quit()
