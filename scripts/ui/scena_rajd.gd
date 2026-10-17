extends Node
## Scena rajdu: generuje biom, ustawia gracza, przeciwników, HUD i obsługuje koniec rajdu.

var widok: Dictionary
var swiat: Node3D
var gen: GeneratorBiomu
var info: Dictionary
var gracz: Gracz
var hud: Node
var ekran_ekw: Node
var czas := 0.0
var zabici: Array = []
var zdarzenia: Array = []
var wartosc_poczatkowa := 0
var koniec := false
var _tryb_testu := ""


func _ready() -> void:
	add_to_group("ui_rajdu")
	widok = Widok3D.zbuduj(self)
	swiat = widok["swiat"]
	gen = GeneratorBiomu.new()
	info = gen.generuj(Gra.ziarno_rajdu, swiat)
	Widok3D.wypiecz_nawigacje(swiat)
	gracz = Gracz.new()
	swiat.add_child(gracz)
	gracz.global_position = info["start"]
	gracz.rotation.y = info["start_rot"]
	gracz.zginal.connect(_smierc)
	for w in info["wyjscia"]:
		(w as Ewakuacja).ewakuowano.connect(_ewakuacja)
	wartosc_poczatkowa = Gra.ekw.wartosc()
	if ResourceLoader.exists("res://scripts/ai/menedzer_wrogow.gd"):
		var mw = load("res://scripts/ai/menedzer_wrogow.gd").new()
		mw.name = "Wrogowie"
		add_child(mw)
		mw.rozstaw(self)
	if ResourceLoader.exists("res://scripts/ui/hud.gd"):
		hud = load("res://scripts/ui/hud.gd").new()
		hud.rajd = self
		add_child(hud)
	if ResourceLoader.exists("res://scripts/ui/ekran_ekwipunku.gd"):
		ekran_ekw = load("res://scripts/ui/ekran_ekwipunku.gd").new()
		ekran_ekw.gracz = gracz
		add_child(ekran_ekw)
	var pauza = load("res://scripts/ui/menu_pauzy.gd").new()
	pauza.w_rajdzie = true
	add_child(pauza)
	Sterowanie.przechwyc(true)
	Sterowanie.blokada = false
	Sterowanie.menu_otwarte = false
	Dzwiek.graj("start_rajdu", -6.0)
	Dzwiek.ambient("ambient_rajd", self, -4.0)
	var args := OS.get_cmdline_user_args()
	if args.has("--zrzuty"):
		_tryb_testu = "zrzuty"
		_zrzuty.call_deferred(args[args.find("--zrzuty") + 1])
	elif args.has("--test"):
		_tryb_testu = "test"
	elif args.has("--ewakuacja"):
		_tryb_testu = "ewakuacja"
		_test_ewakuacji.call_deferred()
	elif args.has("--walka"):
		_tryb_testu = "walka"
		_test_walki.call_deferred()


func _process(delta: float) -> void:
	if koniec:
		return
	czas += delta
	for w in info["wyjscia"]:
		(w as Ewakuacja).rajd_czas = czas
	if _tryb_testu == "test" and czas > 8.0:
		print("TEST RAJDU OK: czas %.1f s, pomieszczeń %d, wrogów %d" % [czas, info["komorki"].size(), get_tree().get_nodes_in_group("wrogowie").size()])
		get_tree().quit()


func dodaj_zdarzenie(t: String) -> void:
	zdarzenia.append({"czas": czas, "tekst": t})


func zabity_wrog(w: Node) -> void:
	zabici.append({"frakcja": w.frakcja, "nazwa": w.nazwa_jednostki, "oddzial_nazwa": String(w.get_meta("oddzial_nazwa", ""))})


func _ewakuacja(nazwa: String) -> void:
	if koniec:
		return
	koniec = true
	_zakoncz({"przezyl": true, "wyjscie": nazwa, "przyczyna": ""})


func _smierc(przyczyna: String) -> void:
	if koniec:
		return
	koniec = true
	await get_tree().create_timer(2.5).timeout
	_zakoncz({"przezyl": false, "przyczyna": przyczyna, "wyjscie": ""})


func _zakoncz(w: Dictionary) -> void:
	w["czas"] = czas
	w["zabici"] = zabici
	w["zdarzenia"] = zdarzenia
	w["wartosc_poczatkowa"] = wartosc_poczatkowa
	w["zdrowie"] = gracz.cialo.stan_do_zapisu()
	w["zabojca"] = gracz.get_meta("zabojca", "")
	Sterowanie.przechwyc(false)
	Gra.koniec_rajdu(w)


func opusc_rajd() -> void:
	if koniec:
		return
	koniec = true
	_zakoncz({"przezyl": false, "przyczyna": "zaginiecie", "wyjscie": ""})


## Otwiera ekran ekwipunku z przeszukiwanym pojemnikiem (wołane przez Pojemnik).
func otworz_pojemnik(p: Node) -> void:
	if ekran_ekw:
		ekran_ekw.otworz(p)


# ------------------------------------------------------------------ test wizualny

func _zrzuty(katalog: String) -> void:
	DirAccess.make_dir_recursive_absolute(katalog)
	gracz.sterowanie = false
	var kam := gracz.kamera
	var klucze: Array = info["komorki"].keys()
	klucze.sort_custom(func(a, b): return info["komorki"][a]["glebokosc"] < info["komorki"][b]["glebokosc"])
	var n := 0
	for k in klucze.slice(0, 8):
		var c := Vector3(k.x * GeneratorBiomu.C + 0.9, 0.05, k.y * GeneratorBiomu.C + 0.9)
		gracz.global_position = c
		gracz.rotation.y = -PI * 0.75
		gracz.latarka.visible = n % 3 == 2
		if n == 3:
			Gra.ekw.sloty["glowna"] = Gra.nowy_naladowany("kb47", "a_762")
			gracz._wybierz_bron("glowna")
		if n == 6:
			Gra.ekw.sloty["glowna"] = Gra.nowy_naladowany("pm63", "a_9x18")
			gracz._wybierz_bron("glowna")
		for f in 45:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(katalog.path_join("rajd_%02d_%s.png" % [n, info["komorki"][k]["typ"]]))
		n += 1
	# ekran ekwipunku z pojemnikiem
	var pojemniki := swiat.get_children().filter(func(x): return x is Pojemnik)
	if not pojemniki.is_empty() and ekran_ekw:
		var pj: Pojemnik = pojemniki[0]
		pj.odkryte = 2
		ekran_ekw.otworz(pj)
		for f in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("ekwipunek.png"))
		ekran_ekw.zamknij()
	print("zrzuty: ", n)
	get_tree().quit()


## Test walki: najbliższy oddział zostaje przeniesiony w pobliże gracza; gracz strzela do najbliższego wroga.
func _test_walki() -> void:
	for i in 20:
		await get_tree().physics_frame
	var wrogowie := get_tree().get_nodes_in_group("wrogowie").filter(func(w): return w.frakcja == ("najemnik" if OS.get_cmdline_user_args().has("--najemnicy") else "szabrownik"))
	var start := gracz.global_position
	var n := 0
	for w in wrogowie:
		if n >= 2:
			break
		w.global_position = NavigationServer3D.map_get_closest_point(swiat.get_world_3d().navigation_map, start + Vector3(6.0 + n, 0, 0.8 * n))
		n += 1
	var t := 0.0
	var strzaly := 0
	while t < 25.0 and not gracz.cialo.martwy:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var cel: Node3D = null
		var best := 999.0
		for w in get_tree().get_nodes_in_group("wrogowie"):
			if w.cialo.martwy:
				continue
			var d: float = w.global_position.distance_to(gracz.global_position)
			if d < best:
				best = d
				cel = w
		if cel == null:
			break
		# celuj w klatkę piersiową
		var p := cel.global_position + Vector3.UP * 1.3
		gracz.look_at(Vector3(p.x, gracz.global_position.y, p.z), Vector3.UP)
		var dir := (p - gracz.kamera.global_position).normalized()
		gracz._pitch = asin(clampf(dir.y, -1, 1))
		gracz.glowa.rotation.x = gracz._pitch
		if fmod(t, 0.5) < get_physics_process_delta_time() and gracz.bron.przedmiot:
			gracz.bron.cooldown = 0.0
			gracz.bron.spust_puszczony = true
			gracz.bron._sprobuj_strzal({"kucanie": 0.0, "celnosc": 1.0})
			strzaly += 1
	var zywi := get_tree().get_nodes_in_group("wrogowie").filter(func(w): return not w.cialo.martwy).size()
	for w in get_tree().get_nodes_in_group("wrogowie").slice(0, 3):
		print("  wróg %s stan=%s widzi=%s wykrycie=%.2f hp=%.0f%% dyst=%.1f" % [w.nazwa_jednostki, w.stan, w.widzi, w.wykrycie, w.cialo.procent() * 100, w.global_position.distance_to(gracz.global_position)])
	if OS.get_cmdline_user_args().has("--pelny") and gracz.cialo.martwy:
		print("TEST WALKI: gracz zginął, czekam na raport")
		return
	print("TEST WALKI: czas %.1f, strzały gracza %d, zdrowie gracza %.0f%%, martwy %s, zabici %d, żywi wrogowie %d" % [t, strzaly, gracz.cialo.procent() * 100.0, gracz.cialo.martwy, zabici.size(), zywi])
	get_tree().quit()


func _test_ewakuacji() -> void:
	for i in 10:
		await get_tree().physics_frame
	for w in get_tree().get_nodes_in_group("wrogowie"):
		w.queue_free()
	var ew: Ewakuacja = info["wyjscia"][0]
	gracz.global_position = ew.global_position + Vector3.UP * 0.1
	print("TEST EWAKUACJI: gracz w strefie %s" % ew.nazwa)
