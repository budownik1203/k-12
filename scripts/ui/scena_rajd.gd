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
	var a := OS.get_cmdline_user_args()
	if a.has("--ziarno"):
		Gra.ziarno_rajdu = int(a[a.find("--ziarno") + 1])
	widok = Widok3D.zbuduj(self)
	swiat = widok["swiat"]
	gen = GeneratorBiomu.new()
	info = gen.generuj(Gra.ziarno_rajdu, swiat)
	await _nawigacja_ze_sprawdzeniem()
	# duża mapa: geometria dalej niż ~45 m nie jest rysowana (i tak ginie w mgle)
	for mi in swiat.find_children("*", "GeometryInstance3D", true, false):
		var gi := mi as GeometryInstance3D
		if gi.get_aabb().size.length() < 40.0:
			gi.visibility_range_end = 46.0
			gi.visibility_range_end_margin = 4.0
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
	elif args.has("--postacie"):
		_tryb_testu = "postacie"
		_zrzut_postaci.call_deferred(args[args.find("--postacie") + 1])
	elif args.has("--posterunek"):
		_tryb_testu = "posterunek"
		_zrzut_posterunku.call_deferred(args[args.find("--posterunek") + 1])
	elif args.has("--vm"):
		_tryb_testu = "vm"
		_zrzut_vm.call_deferred(args[args.find("--vm") + 1])
	elif args.has("--mutant"):
		_tryb_testu = "mutant"
		_test_mutanta.call_deferred(args[args.find("--mutant") + 1] if args.size() > args.find("--mutant") + 1 else "")
	elif args.has("--frakcje"):
		_tryb_testu = "frakcje"
		_test_frakcji.call_deferred()
	elif args.has("--test_bron"):
		_tryb_testu = "bron"
		_test_broni.call_deferred()


## Wypieka siatkę nawigacji i sprawdza, czy meble nie dzielą pomieszczeń; jeśli tak – usuwa mebel i powtarza.
func _nawigacja_ze_sprawdzeniem() -> void:
	var mapa := swiat.get_world_3d().navigation_map
	for proba in 8:
		var it0 := NavigationServer3D.map_get_iteration_id(mapa)
		var region := Widok3D.wypiecz_nawigacje(swiat)
		# czekamy, aż serwer nawigacji przeliczy mapę z nową siatką
		for f in 120:
			await get_tree().physics_frame
			if NavigationServer3D.map_get_iteration_id(mapa) != it0 and NavigationServer3D.map_get_closest_point(mapa, info["start"]).distance_to(info["start"]) < 1.0:
				break
		var naprawione := false
		for k in info["komorki"]:
			var pts: Array = gen.punkty_drzwi(k)
			for i in range(1, pts.size()):
				var q1 := NavigationServer3D.map_get_closest_point(mapa, pts[0])
				var q2 := NavigationServer3D.map_get_closest_point(mapa, pts[i])
				var sc := NavigationServer3D.map_get_path(mapa, q1, q2, true)
				if sc.is_empty() or sc[sc.size() - 1].distance_to(q2) > 0.35:
					if OS.get_cmdline_user_args().has("--test"):
						print("  naprawa: %s %s typ=%s q1=%s q2=%s koniec=%s" % [proba, k, info["komorki"][k]["typ"], q1, q2, sc[sc.size() - 1] if sc.size() > 0 else "brak"])
					if gen.usun_srodkowy_mebel(k):
						naprawione = true
					break
		if not naprawione:
			info["oslony"] = gen.oslony
			return
		region.get_parent().remove_child(region)
		region.queue_free()


var _cull_t := 0.0
var _start_ms := 0


func _process(delta: float) -> void:
	if koniec or gracz == null:
		return
	if _start_ms == 0:
		_start_ms = Time.get_ticks_msec()
	czas += delta
	# duża mapa: lampy daleko od gracza gasną w renderze (oszczędność), zostają dla logiki AI
	_cull_t -= delta
	if _cull_t <= 0.0:
		_cull_t = 0.3
		var gp := gracz.global_position
		var bliskie := []
		for l in info["lampy"]:
			if is_instance_valid(l):
				var d2 := (l as Node3D).global_position.distance_squared_to(gp)
				(l as Light3D).visible = d2 < 34.0 * 34.0
				if d2 < 16.0 * 16.0 and (l as Light3D).light_energy > 0.15:
					bliskie.append([d2, l])
				else:
					(l as Light3D).shadow_enabled = false
		# prawdziwe cienie od 3 najbliższych lamp (jak w Iron Blight: ławka i drzewo rzucają cień od latarni)
		bliskie.sort_custom(func(a, b): return a[0] < b[0])
		for i in bliskie.size():
			(bliskie[i][1] as Light3D).shadow_enabled = i < 3
	for w in info["wyjscia"]:
		(w as Ewakuacja).rajd_czas = czas
	if _tryb_testu == "test" and czas > 1.0 and czas - delta <= 1.0:
		# spójność siatki nawigacji: ścieżka od startu do każdego pomieszczenia
		var mapa := swiat.get_world_3d().navigation_map
		var ok := 0
		for k in info["komorki"]:
			var c := gen._srodek(k)
			var cel := NavigationServer3D.map_get_closest_point(mapa, c)
			var q := NavigationPathQueryParameters3D.new()
			q.map = mapa
			q.start_position = NavigationServer3D.map_get_closest_point(mapa, info["start"])
			q.target_position = cel
			q.path_search_max_polygons = 0
			q.path_search_max_distance = 0.0
			var wynik := NavigationPathQueryResult3D.new()
			NavigationServer3D.query_path(q, wynik)
			var sciezka := wynik.path
			var kon: Vector3 = sciezka[sciezka.size() - 1] if sciezka.size() > 0 else Vector3(-99, 0, -99)
			if (info["komorki"][k]["rect"] as Rect2).grow(0.4).has_point(Vector2(kon.x, kon.z)):
				ok += 1
			else:
				print("  nieosiągalne: %s typ=%s cel=%s koniec=%s" % [k, info["komorki"][k]["typ"], cel, sciezka[sciezka.size() - 1] if sciezka.size() > 0 else "brak"])
		print("NAWIGACJA: osiągalne pomieszczenia %d/%d (wielokąty: %d)" % [ok, info["komorki"].size(), (swiat.get_node("Nawigacja") as NavigationRegion3D).navigation_mesh.get_polygon_count()])
		var aa := OS.get_cmdline_user_args()
		if aa.has("--sciezka"):
			var i0 := aa.find("--sciezka")
			var pa := NavigationServer3D.map_get_closest_point(mapa, Vector3(float(aa[i0 + 1]), 0, float(aa[i0 + 2])))
			var pb := NavigationServer3D.map_get_closest_point(mapa, Vector3(float(aa[i0 + 3]), 0, float(aa[i0 + 4])))
			print("  sciezka %s -> %s: %s" % [pa, pb, NavigationServer3D.map_get_path(mapa, pa, pb, true)])
		if aa.has("--drzwi"):
			for kk in gen.krawedzie:
				var e: Dictionary = gen.krawedzie[kk]
				var p1: Vector3 = e["pa"]
				var p2: Vector3 = e["pb"]
				var q1 := NavigationServer3D.map_get_closest_point(mapa, p1)
				var q2 := NavigationServer3D.map_get_closest_point(mapa, p2)
				var sc := NavigationServer3D.map_get_path(mapa, q1, q2, true)
				var ok2: bool = sc.size() > 0 and sc[sc.size() - 1].distance_to(q2) < 0.3 and q1.distance_to(p1) < 0.8 and q2.distance_to(p2) < 0.8
				if not ok2:
					print("  DRZWI ZABLOKOWANE %s p1=%s->%s p2=%s->%s" % [kk, p1, q1, p2, q2])
		if aa.has("--pokoje"):
			for k in info["komorki"]:
				var pts: Array = gen.punkty_drzwi(k)
				for i in range(1, pts.size()):
					var q1 := NavigationServer3D.map_get_closest_point(mapa, pts[0])
					var q2 := NavigationServer3D.map_get_closest_point(mapa, pts[i])
					var sc := NavigationServer3D.map_get_path(mapa, q1, q2, true)
					if sc.is_empty() or sc[sc.size() - 1].distance_to(q2) > 0.3:
						print("  POKOJ PODZIELONY %s typ=%s %s -> %s (q %s -> %s)" % [k, info["komorki"][k]["typ"], pts[0], pts[i], q1, q2])
		if aa.has("--kolizje_w"):
			var i1 := aa.find("--kolizje_w")
			var kx := int(aa[i1 + 1])
			var kz := int(aa[i1 + 2])
			for n in swiat.get_children():
				if n is CollisionObject3D and (n.collision_layer & 1) and n.name != "Sciany":
					var gp: Vector3 = n.global_position
					if int(gp.x / GeneratorBiomu.C) == kx and int(gp.z / GeneratorBiomu.C) == kz:
						for c in n.get_children():
							if c is CollisionShape3D and c.shape is BoxShape3D:
								print("  KOLIZJA %s %s rot=%.2f size=%s" % [n.name, gp, n.rotation.y, (c.shape as BoxShape3D).size])
		if aa.has("--krawedzie"):
			for kk in gen.krawedzie:
				var e: Dictionary = gen.krawedzie[kk]
				print("  krawedz %s c=%.2f otwarte=%s" % [kk, e["c"], e["otwarte"]])
		if aa.has("--blizej"):
			var pp := Vector3(float(aa[aa.find("--blizej") + 1]), 0, float(aa[aa.find("--blizej") + 2]))
			for n in swiat.get_children():
				if n is Node3D and Vector2(n.global_position.x, n.global_position.z).distance_to(Vector2(pp.x, pp.z)) < 1.5:
					print("  obiekt: ", n.name, " ", n.get_class(), " ", n.global_position)
		if aa.has("--mapa"):
			zapisz_mape(aa[aa.find("--mapa") + 1])
	if _tryb_testu == "test" and OS.get_cmdline_user_args().has("--sluch"):
		# test słuchu: seria z karabinu przy starcie, potem stan wszystkich przeciwników
		if czas > 2.0 and czas - delta <= 2.0:
			var srodek := Vector3(GeneratorBiomu.GW * GeneratorBiomu.C * 0.5, 0, GeneratorBiomu.GH * GeneratorBiomu.C * 0.5)
			var naj := Vector2i.ZERO
			for k in info["komorki"]:
				if info["komorki"][k]["typ"] == "korytarz" and gen._srodek(k).distance_to(srodek) < gen._srodek(naj).distance_to(srodek):
					naj = k
			gracz.global_position = gen._srodek(naj) + Vector3.UP * 0.05
			for i in 5:
				Gra.emituj_halas(gracz.global_position, 46.0, gracz)
		if czas > 7.0 and czas - delta <= 7.0:
			var stany := {}
			for w in get_tree().get_nodes_in_group("wrogowie"):
				var klucz: String = ("%s/%s" % [w.get_class(), w.stan]) + ("/nasluch" if (w is Wrog and w._nasluch) else "") + ("/%dm" % int(w.global_position.distance_to(gracz.global_position)) if w.stan in ["szukanie", "walka", "poscig"] else "")
				stany[klucz] = stany.get(klucz, 0) + 1
			print("SLUCH: ", stany)
	if _tryb_testu == "test" and czas > 8.0:
		print("TEST RAJDU OK: czas %.1f s, pomieszczeń %d, wrogów %d, fps %d, start %d ms" % [czas, info["komorki"].size(), get_tree().get_nodes_in_group("wrogowie").size(), Engine.get_frames_per_second(), _start_ms])
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
	for f in 5:
		await get_tree().process_frame
	# zrzuty bez walki: przeciwnicy zamrożeni
	for w in get_tree().get_nodes_in_group("wrogowie"):
		w.set_physics_process(false)
	var kam := gracz.kamera
	var klucze: Array = info["komorki"].keys()
	klucze.sort_custom(func(a, b): return info["komorki"][a]["glebokosc"] < info["komorki"][b]["glebokosc"])
	var n := 0
	for k in klucze.slice(0, 8):
		var rr: Rect2 = info["komorki"][k]["rect"]
		var c := Vector3(rr.position.x + 0.9, 0.05, rr.position.y + 0.9)
		gracz.global_position = c
		gracz.rotation.y = -PI * 0.75
		if info["komorki"][k]["typ"] == "korytarz":
			# w korytarzu: z wejścia jednego ramienia wzdłuż korytarza
			var ram: Array = gen._ramiona(k)
			var d: Vector2i = ram[n % ram.size()]
			gracz.global_position = gen._srodek(k) + Vector3(-d.x * 1.2, 0.05, -d.y * 1.2)
			gracz.rotation.y = atan2(-float(d.x), -float(d.y))
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
	# postacie: pies i szabrownik w oświetlonym pomieszczeniu startowym
	gracz.global_position = info["start"]
	gracz.rotation.y = info["start_rot"]
	if not Gra.ekw.ma_wyposazenie("latarka"):
		Gra.ekw.sloty["util0"] = Przedmiot.nowy("latarka")
	if Gra.ekw.sloty["pistolet"] == null:
		Gra.ekw.sloty["pistolet"] = Gra.nowy_naladowany("pw9", "a_9x18")
	gracz.wez_latarke()
	var przod := -gracz.global_basis.z
	var pies := Fauna.new()
	swiat.add_child(pies)
	pies.global_position = gracz.global_position + przod * 2.6 + gracz.global_basis.x * -0.6
	pies.set_physics_process(false)
	pies._na_start()
	pies._kier = -przod
	for i in 30:
		pies._ustaw_orientacje(0.1)
		pies._animuj(0.05, 0.6)
	var wr: Node3D = null
	for w in get_tree().get_nodes_in_group("wrogowie"):
		if w is Wrog:
			wr = w
			break
	if wr:
		wr.global_position = gracz.global_position + przod * 4.0 + gracz.global_basis.x * 0.9
		wr.rotation.y = gracz.rotation.y + PI * 0.85
		wr.set_physics_process(false)
		wr.stan = "walka"
		for i in 10:
			wr._animuj(0.05)
	for f in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("postacie.png"))
	# akcje: napełnianie magazynka (kółko) i bandażowanie (animacja rąk)
	if pies:
		pies.queue_free()
	gracz.zacznij_akcje("Magazynek PW-9", 3.0, func(): pass, "magazynek", 8, func(): pass)
	for f in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("akcja_magazynek.png"))
	gracz.przerwij_akcje()
	gracz.zacznij_akcje("Bandaż → nogi", 3.0, func(): pass, "leczenie")
	for f in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("akcja_leczenie.png"))
	gracz.przerwij_akcje()
	# latarka w ciemności: gasimy lampy
	for l in info["lampy"]:
		(l as Node).set_process(false)
		(l as Light3D).light_energy = 0.0
	if wr:
		wr.queue_free()
	for f in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("latarka_pistolet.png"))
	gracz.wez_latarke(true)
	for f in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("latarka_sama.png"))
	gracz.cialo.obrazenia("nogi", 30.0)
	gracz.cialo.krwawienie["rece"] = 1
	# tryby ekwipunku: kamizelka (spojrzenie w dół) i rozpięty plecak
	if ekran_ekw:
		var e := Gra.ekw
		var kamz := Przedmiot.nowy("napiersnik")
		var stara: Przedmiot = e.zdejmij("kamizelka")
		e.zaloz("kamizelka", kamz)
		for m in [Gra.magazynek("mag_kb47", "a_762", 30), Gra.magazynek("mag_kb47", "a_762", 18), Przedmiot.nowy("a_762", 7), Przedmiot.nowy("bandaz")]:
			kamz.dane["siatka"].dodaj(m)
		e.zdejmij("plecak")
		var pl := Przedmiot.nowy("plecak_wojskowy")
		e.zaloz("plecak", pl)
		for q in [Przedmiot.nowy("a_9x18", 40), Przedmiot.nowy("a_9x18", 9), Przedmiot.nowy("kanister"), Przedmiot.nowy("telefon"), Przedmiot.nowy("konserwa"), Przedmiot.nowy("gasnica"), Przedmiot.nowy("kompas")]:
			pl.dane["siatka"].dodaj(q)
		if e.sloty["util1"] == null:
			e.sloty["util1"] = Przedmiot.nowy("mapa")
		ekran_ekw.otworz(null)
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("ekw_panel.png"))
		ekran_ekw.przelacz_pojemnik("kamizelka")
		await get_tree().create_timer(0.6).timeout
		ekran_ekw.przelacz_pojemnik("plecak")
		await get_tree().create_timer(0.7).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("ekw_otwieranie.png"))
		await get_tree().create_timer(1.4).timeout
		ekran_ekw.przelacz_pojemnik("bezpieczny")
		await get_tree().create_timer(1.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("ekw_kamizelka_plecak.png"))
		ekran_ekw.zamknij()
		await get_tree().create_timer(1.0).timeout
		ekran_ekw.otworz(null)
		ekran_ekw.szybka_kamizelka()
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("ekw_szybka_kamizelka.png"))
		ekran_ekw.zamknij()
		await get_tree().create_timer(0.6).timeout
	# ekran ekwipunku z pojemnikiem
	var pojemniki := swiat.get_children().filter(func(x): return x is Pojemnik)
	if not pojemniki.is_empty() and ekran_ekw:
		var pj: Pojemnik = pojemniki[0]
		pj.odkryte = 2
		gracz.global_position = pj.global_position + Vector3(0.8, 0.05, 0.8)
		ekran_ekw.otworz(pj)
		for f in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("ekwipunek.png"))
		ekran_ekw.zamknij()
	print("zrzuty: ", n)
	get_tree().quit()


## Zrzut przeciwników w różnych pozach (chód, celowanie, kucanie, przeładowanie, śmierć).
func _zrzut_postaci(plik: String) -> void:
	for f in 10:
		await get_tree().physics_frame
	var wrogowie := get_tree().get_nodes_in_group("wrogowie").filter(func(w): return w is Wrog)
	for w in get_tree().get_nodes_in_group("wrogowie"):
		w.set_physics_process(false)
		if not (w is Wrog):
			w.queue_free()
	gracz.sterowanie = false
	gracz.global_position = info["start"]
	gracz.rotation.y = info["start_rot"]
	var przod := -gracz.global_basis.z
	var bok := gracz.global_basis.x
	for l in info["lampy"]:
		(l as Node).set_process(false)
		(l as Light3D).light_energy = 1.6
	var swiatlo := OmniLight3D.new()
	swiatlo.omni_range = 9.0
	swiatlo.light_energy = 1.2
	swiat.add_child(swiatlo)
	swiatlo.global_position = gracz.global_position + przod * 2.0 + Vector3.UP * 2.4
	var pozy := ["patrol", "walka", "kucanie", "przeladowanie", "szukanie"]
	for i in mini(5, wrogowie.size()):
		var w: Wrog = wrogowie[i]
		w.global_position = gracz.global_position + przod * 4.2 + bok * (-2.2 + i * 1.1)
		w.rotation.y = gracz.rotation.y + PI + (0.6 if i % 2 == 0 else -0.5)
		w.ostatnia_pozycja = gracz.global_position
		match pozy[i]:
			"patrol":
				w.stan = "patrol"
				w.velocity = -w.global_basis.z * 1.5
			"walka":
				w.stan = "walka"
				w.rotation.y = gracz.rotation.y + PI + 0.15
			"kucanie":
				w.stan = "walka"
				w.kucanie = 1.0
			"przeladowanie":
				w.stan = "walka"
				w._przeladowanie_max = 2.0
				w._przeladowanie = 1.1
			"szukanie":
				w.stan = "szukanie"
				w.velocity = -w.global_basis.z * 0.8
		for f in 40:
			w._animuj(1.0 / 60.0)
	for f in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(plik)
	print("postacie: ", mini(5, wrogowie.size()))
	get_tree().quit()


## Zrzut posterunku wojska (z wejścia) i kilku korytarzy z rekwizytami.
func _zrzut_posterunku(katalog: String) -> void:
	DirAccess.make_dir_recursive_absolute(katalog)
	for f in 10:
		await get_tree().physics_frame
	for w in get_tree().get_nodes_in_group("wrogowie"):
		w.set_physics_process(false)
		if not (w is Wrog):
			w.queue_free()
	gracz.sterowanie = false
	var n := 0
	for pst in info.get("posterunki", []):
		var kier: Vector3 = pst["kier"]
		gracz.global_position = (pst["pos"] as Vector3) + kier * 4.2 + Vector3(0, 0.05, 0)
		gracz.rotation.y = atan2(kier.x, kier.z)
		for w in get_tree().get_nodes_in_group("wrogowie"):
			if w is Wrog and not w.posterunek.is_empty():
				for i in 30:
					w._animuj(1.0 / 60.0)
		for f in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("posterunek_%d.png" % n))
		n += 1
	var m := 0
	for k in info["komorki"]:
		if m >= 4 or info["komorki"][k]["typ"] != "korytarz" or info["komorki"][k]["ramiona"].is_empty():
			continue
		var ram: Array = info["komorki"][k]["ramiona"][0]
		var r: Rect2 = ram[1]
		var ax: Vector2i = ram[0]
		var c := gen._srodek(k)
		var cel := Vector3(r.get_center().x, 0, r.get_center().y)
		gracz.global_position = c - (cel - c).normalized() * 1.2 + Vector3(0, 0.05, 0)
		var d := cel - gracz.global_position
		gracz.rotation.y = atan2(-d.x, -d.z)
		for f in 25:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("korytarz_%d.png" % m))
		m += 1
	print("posterunki: %d, korytarze: %d" % [n, m])
	get_tree().quit()


## Zrzuty broni w rękach: fazy przeładowania i bieg.
func _zrzut_vm(katalog: String) -> void:
	DirAccess.make_dir_recursive_absolute(katalog)
	for w in get_tree().get_nodes_in_group("wrogowie"):
		w.queue_free()
	gracz.sterowanie = false
	if OS.get_cmdline_user_args().has("--animacje"):
		await _zrzut_animacji(katalog)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--tylko_bronie"):
		await _zrzut_broni(katalog)
		get_tree().quit()
		return
	Gra.ekw.sloty["glowna"] = Gra.nowy_naladowany("kb47", "a_762")
	Gra.ekw.kieszenie.dodaj(Gra.magazynek("mag_kb47", "a_762", 30))
	gracz._wybierz_bron("glowna")
	for f in 40:
		await get_tree().physics_frame
	gracz.bron._zacznij_przeladowanie(false)
	var tot: float = gracz.bron.stan_total
	var n := 0
	for frac in [0.1, 0.3, 0.55, 0.74, 0.9]:
		while gracz.bron.stan_t < tot * frac and gracz.bron.stan == "przeladowanie":
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("vm_%d.png" % n))
		n += 1
	for f in 60:
		await get_tree().process_frame
	gracz.bron._bieg = 1.0
	gracz.bron.aktualizuj(0.0, {"bieg": true, "moze": false})
	for f in 10:
		gracz.bron._bieg = 1.0
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("vm_bieg.png"))
	gracz.bron._bieg = 0.0
	# strzał: z biodra i przy celowaniu (płomień, światło)
	gracz.sterowanie = true
	for nazwa in ["vm_strzal_biodro", "vm_strzal_ads"]:
		if nazwa == "vm_strzal_ads":
			Input.action_press("celuj")
			for f in 50:
				await get_tree().process_frame
		gracz.bron.cooldown = 0.0
		gracz.bron.spust_puszczony = true
		var przed: Variant = gracz.bron.przedmiot.dane.get("komora")
		Engine.time_scale = 0.05
		gracz.bron._sprobuj_strzal({})
		for kl in 4:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(katalog.path_join(nazwa + "_%d.png" % kl))
		Engine.time_scale = 1.0
		for f in 30:
			await get_tree().process_frame
	Input.action_release("celuj")
	gracz.sterowanie = false
	# dodatki: KB-47 z kolimatorem, tłumikiem i latarką; potem luneta przy celowaniu
	var kb: Przedmiot = Gra.ekw.sloty["glowna"]
	kb.dane["dod_wylot"] = Przedmiot.nowy("tlumik_762")
	kb.dane["dod_celownik"] = Przedmiot.nowy("kolimator")
	kb.dane["dod_latarka"] = Przedmiot.nowy("latarka_taktyczna")
	kb.dane["dod_chwyt"] = Przedmiot.nowy("chwyt")
	gracz._wybierz_bron("glowna")
	gracz.latarka_broni_wl = true
	gracz._odswiez_latarke()
	for f in 50:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("vm_dodatki.png"))
	gracz.sterowanie = true
	Input.action_press("celuj")
	for f in 110:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("vm_kolimator.png"))
	Input.action_release("celuj")
	kb.dane["dod_celownik"] = Przedmiot.nowy("luneta")
	gracz._wybierz_bron("glowna")
	for f in 40:
		await get_tree().process_frame
	gracz.sterowanie = true
	Input.action_press("celuj")
	for f in 110:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("vm_luneta.png"))
	Input.action_release("celuj")
	for f in 40:
		await get_tree().process_frame
	# montaż polowy (animacja)
	var tl: Przedmiot = kb.dane["dod_wylot"]
	kb.dane["dod_wylot"] = null
	gracz._wybierz_bron("glowna")
	for f in 40:
		await get_tree().process_frame
	gracz.zacznij_akcje("Montaż: " + tl.nazwa(), 3.0, func(): kb.dane["dod_wylot"] = tl, "montaz")
	for f in 70:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("vm_montaz.png"))
	await _zrzut_broni(katalog)
	get_tree().quit()


func _zapisz(katalog: String, nazwa: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join(nazwa + ".png"))


func _klatki(n: int) -> void:
	for f in n:
		await get_tree().process_frame


## Animacje broni: blokada zamka, przeładowanie z pustą komorą, łamanie obrzyna, zegarek, dodatki.
func _zrzut_animacji(katalog: String) -> void:
	var b := gracz.bron
	if OS.get_cmdline_user_args().has("--ogladanie"):
		var kb: Przedmiot = Gra.nowy_naladowany("kb47", "a_762")
		Gra.ekw.sloty["glowna"] = kb
		Gra.ekw.sloty["plecak"] = Przedmiot.nowy("plecak_wojskowy")
		print("dodano: ", Gra.ekw.siatka_plecaka().dodaj(Przedmiot.nowy("tlumik_762")), " ", Gra.ekw.siatka_plecaka().dodaj(Przedmiot.nowy("latarka_taktyczna")))
		gracz._wybierz_bron("glowna")
		await _klatki(30)
		var ogl = ekran_ekw._ogl_ui
		ogl.otworz()
		await get_tree().create_timer(0.8).timeout
		await _zapisz(katalog, "og_0")
		for el in ogl._dostepne("wylot", ["tlumik_762"]):
			ekran_ekw._montuj(kb, el[0], {"typ": "siatka", "siatka": el[1]})
		await get_tree().create_timer(1.2).timeout
		await _zapisz(katalog, "og_1_nakladanie")
		await get_tree().create_timer(1.7).timeout
		await _zapisz(katalog, "og_2_nakrecanie")
		await get_tree().create_timer(1.6).timeout
		for el in ogl._dostepne("latarka", ["latarka_taktyczna"]):
			ekran_ekw._montuj(kb, el[0], {"typ": "siatka", "siatka": el[1]})
		await get_tree().create_timer(1.2).timeout
		await _zapisz(katalog, "og_3_latarka")
		await get_tree().create_timer(2.5).timeout
		gracz.bron.ogl_obrot = Vector2(0.9, 0.25)
		await get_tree().create_timer(0.6).timeout
		await _zapisz(katalog, "og_4_obrot")
		return
	if OS.get_cmdline_user_args().has("--plecaki"):
		for pid in ["worek", "plecak_turystyczny", "plecak_szturmowy", "chlebak", "plecak_wojskowy", "napiersnik", "kamizelka_lbv", "kamizelka_wedkarska", "kamizelka_mysliwska"]:
			var pr := Przedmiot.nowy(pid)
			var slot: String = pr.defn()["pojemnik"]["slot"]
			Gra.ekw.sloty[slot] = pr
			ekran_ekw.otworz(null)
			await _klatki(5)
			ekran_ekw.przelacz_pojemnik(slot)
			await _klatki(25)
			await _zapisz(katalog, "pl_%s_a" % pid)
			await get_tree().create_timer(2.4).timeout
			await _zapisz(katalog, "pl_%s_b" % pid)
			ekran_ekw.zamknij()
			await get_tree().create_timer(1.0).timeout
		return
	if OS.get_cmdline_user_args().has("--czynnosci"):
		gracz.sterowanie = false
		var tylko := ""
		var ar := OS.get_cmdline_user_args()
		if ar.has("--tylko"):
			tylko = ar[ar.find("--tylko") + 1]
		var lista := [["magazynek", "mag_kb47", "a_762", 3.0, 6], ["magazynek", "mag_pw9", "a_9x18", 2.4, 6],
			["magazynek", "mag_pm63", "a_9x18", 2.4, 6],
			["leczenie_bandaz", "bandaz", "", 3.0, 0], ["leczenie_opatrunek", "opatrunek", "", 5.0, 0],
			["leczenie_szyna", "szyna", "", 6.0, 0], ["leczenie_bolostop", "bolostop", "", 2.0, 0], ["leczenie_apteczka", "apteczka", "", 2.5, 0]]
		for el in lista:
			if tylko != "" and String(el[1]) != tylko:
				continue
			gracz.zacznij_akcje(String(el[0]), float(el[3]), func(): pass, String(el[0]), int(el[4]), func(): pass, {"id": el[1], "amun": el[2]})
			for fr in [0.2, 0.5, 0.8]:
				while not gracz.akcja.is_empty() and float(gracz.akcja["t"]) < float(el[3]) * fr:
					await get_tree().process_frame
				await _zapisz(katalog, "cz_%s_%s_%d" % [el[0], el[1], int(fr * 100)])
			gracz.przerwij_akcje()
			await _klatki(20)
		return
	if OS.get_cmdline_user_args().has("--tylko_zegarek"):
		Gra.ekw.sloty["glowna"] = Gra.nowy_naladowany("kb47", "a_762")
		gracz._wybierz_bron("glowna")
		await _klatki(30)
		Input.action_press("zegarek")
		gracz.sterowanie = true
		await _klatki(40)
		await _zapisz(katalog, "an_zegarek")
		return
	# PW-9: ostatni nabój -> zamek w tyle, potem przeładowanie
	var pw: Przedmiot = Gra.nowy_naladowany("pw9", "a_9x18")
	pw.dane["mag"].dane["naboje"] = 0
	Gra.ekw.sloty["pistolet"] = pw
	Gra.ekw.kieszenie.dodaj(Gra.magazynek("mag_pw9", "a_9x18", 8))
	gracz._wybierz_bron("pistolet")
	await _klatki(40)
	b.cooldown = 0.0
	b.spust_puszczony = true
	b._sprobuj_strzal({})
	await _klatki(12)
	await _zapisz(katalog, "an_pw9_zamek")
	b._zacznij_przeladowanie(false)
	var tot: float = b.stan_total
	print("PW9: ", b.stan)
	for fr in [0.3, 0.6, 0.95]:
		while b.stan == "przeladowanie" and b.stan_t < tot * fr:
			await get_tree().process_frame
		await _zapisz(katalog, "an_pw9_%d" % int(fr * 100))
	while b.stan != "gotowa":
		await get_tree().process_frame
	# KB-47: pusta komora -> rączka zamka
	var kb: Przedmiot = Gra.nowy_naladowany("kb47", "a_762")
	kb.dane["komora"] = ""
	kb.dane["mag"].dane["naboje"] = 0
	Gra.ekw.sloty["glowna"] = kb
	Gra.ekw.dodaj(Gra.magazynek("mag_kb47", "a_762", 30))
	gracz._wybierz_bron("glowna")
	await _klatki(40)
	b._zacznij_przeladowanie(false)
	print("KB47 przeladowanie: ", b.stan)
	tot = b.stan_total
	for fr in [0.4, 0.86, 0.9]:
		while b.stan == "przeladowanie" and b.stan_t < tot * fr:
			await get_tree().process_frame
		await _zapisz(katalog, "an_kb47_%d" % int(fr * 100))
	while b.stan != "gotowa":
		await get_tree().process_frame
	# obrzyn: ładowanie naboju
	var ob: Przedmiot = Gra.nowy_naladowany("obrzyn", "a_12")
	ob.dane["wewn"] = 0
	Gra.ekw.sloty["glowna"] = ob
	Gra.ekw.dodaj(Przedmiot.nowy("a_12", 6))
	gracz._wybierz_bron("glowna")
	await _klatki(40)
	b._zacznij_przeladowanie(false)
	tot = b.stan_total
	for fr in [0.3, 0.6, 0.85]:
		while b.stan == "ladowanie_wewn" and b.stan_t < tot * fr:
			await get_tree().process_frame
		await _zapisz(katalog, "an_obrzyn_%d" % int(fr * 100))
	await _klatki(90)
	# zegarek (H)
	Input.action_press("zegarek")
	gracz.sterowanie = true
	await _klatki(40)
	await _zapisz(katalog, "an_zegarek")
	Input.action_release("zegarek")
	gracz.sterowanie = false
	await _klatki(30)
	# KB-47 z dodatkami
	var kd: Przedmiot = Gra.nowy_naladowany("kb47", "a_762")
	kd.dane["dod_wylot"] = Przedmiot.nowy("tlumik_762")
	kd.dane["dod_celownik"] = Przedmiot.nowy("kolimator")
	kd.dane["dod_latarka"] = Przedmiot.nowy("latarka_taktyczna")
	kd.dane["dod_chwyt"] = Przedmiot.nowy("chwyt")
	Gra.ekw.sloty["glowna"] = kd
	gracz._wybierz_bron("glowna")
	await _klatki(40)
	await _zapisz(katalog, "an_kb47_dodatki")


## Każda broń z biodra i przy celowaniu (ręce, modele).
func _zrzut_broni(katalog: String) -> void:
	for bid in [["pw9", "a_9x18", "pistolet"], ["pm63", "a_9x18", "glowna"], ["kb47", "a_762", "glowna"], ["obrzyn", "a_12", "glowna"]]:
		Gra.ekw.sloty[bid[2]] = Gra.nowy_naladowany(bid[0], bid[1])
		gracz._wybierz_bron(bid[2])
		gracz.bron.ads = 0.0
		for f in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("vm_%s.png" % bid[0]))


## Test przełączania broni i latarki symulowanymi klawiszami.
func _test_broni() -> void:
	for w in get_tree().get_nodes_in_group("wrogowie"):
		w.queue_free()
	if Gra.ekw.sloty["pistolet"] == null:
		Gra.ekw.sloty["pistolet"] = Gra.nowy_naladowany("pw9", "a_9x18")
	if Gra.ekw.sloty["glowna"] == null:
		Gra.ekw.sloty["glowna"] = Gra.nowy_naladowany("kb47", "a_762")
	if not Gra.ekw.ma_wyposazenie("latarka"):
		Gra.ekw.sloty["util0"] = Przedmiot.nowy("latarka")
	var bledy := 0
	var gl: String = Gra.ekw.sloty["glowna"].id
	var kroki := [["bron1", gl, false], ["bron3", "", true], ["bron2", "pw9", true], ["bron2", "pw9", false],
		["bron3", "", true], ["bron1", gl, false], ["latarka", "pw9", true], ["bron3", "", true], ["bron3", gl, false],
		["bron2", "pw9", false], ["latarka", "pw9", true], ["latarka", "pw9", true]]
	for k in kroki:
		for f in 40:
			await get_tree().physics_frame
		var ev := InputEventAction.new()
		ev.action = k[0]
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var ev2 := InputEventAction.new()
		ev2.action = k[0]
		ev2.pressed = false
		Input.parse_input_event(ev2)
		for f in 5:
			await get_tree().physics_frame
		var p: Przedmiot = gracz.bron.przedmiot
		var id := p.id if p else ""
		var ok: bool = id == k[1] and gracz.latarka_w_rece == k[2]
		print("  %s -> bron=%s latarka=%s %s" % [k[0], id, gracz.latarka_w_rece, "OK" if ok else "BLAD (oczekiwano %s/%s)" % [k[1], k[2]]])
		if not ok:
			bledy += 1
	gracz.wez_latarke(true)
	for f in 60:
		await get_tree().process_frame
	print("  kamera przod=%s latarka przod=%s poz=%s" % [-gracz.kamera.global_basis.z, -gracz.latarka.global_basis.z, gracz.latarka.global_position - gracz.kamera.global_position])
	gracz.wez_latarke()
	for f in 60:
		await get_tree().process_frame
	print("  z pistoletem: latarka przod=%s poz=%s" % [-gracz.latarka.global_basis.z, gracz.latarka.global_position - gracz.kamera.global_position])
	# hełm: strzały w głowę z karabinu (obr. 56, pen. 34)
	Gra.ekw.sloty["helm"] = Przedmiot.nowy("helm_wz67")
	var glowa_y := gracz.global_position + Vector3.UP * 1.65
	for i in 4:
		gracz.trafiony(glowa_y, 56.0, 34.0, null)
		print("  strzał w głowę %d: hp głowy=%.0f hełm=%.0f martwy=%s ogłuszenie=%.1f" % [i + 1, gracz.cialo.hp["glowa"], float(Gra.ekw.sloty["helm"].dane["wytrz"]), gracz.cialo.martwy, gracz.oglusz])
		if gracz.cialo.martwy:
			break
	print("TEST BRONI: bledy %d" % bledy)
	get_tree().quit()


## Test walki: najbliższy oddział zostaje przeniesiony w pobliże gracza; gracz strzela do najbliższego wroga.
func _test_walki() -> void:
	for i in 20:
		await get_tree().physics_frame
	# test zawsze z tą samą bronią (zapis testowy bywa po zgonach)
	if true:
		gracz.ekw.sloty["glowna"] = Gra.nowy_naladowany("pm63", "a_9x18")
		gracz.ekw.dodaj(Gra.magazynek("mag_pm63", "a_9x18", 25))
		gracz.ekw.dodaj(Gra.magazynek("mag_pm63", "a_9x18", 25))
	gracz._wybierz_bron("glowna")
	var wrogowie := get_tree().get_nodes_in_group("wrogowie").filter(func(w): return w.frakcja == ("najemnik" if OS.get_cmdline_user_args().has("--najemnicy") else "szabrownik"))
	var start := gracz.global_position
	var n := 0
	for w in wrogowie:
		if n >= 2:
			break
		w.global_position = NavigationServer3D.map_get_closest_point(swiat.get_world_3d().navigation_map, start + Vector3(3.6 + n * 0.8, 0, -0.8 + 1.6 * n))
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
		var b := gracz.bron
		if b.przedmiot and b.stan == "gotowa":
			if b.przedmiot.dane["komora"] == "" and b.przedmiot.dane.get("wewn", 0) == 0:
				b._zacznij_przeladowanie(false)
			elif fmod(t, 0.25) < get_physics_process_delta_time():
				b.cooldown = 0.0
				b.spust_puszczony = true
				b._sprobuj_strzal({"kucanie": 0.0, "celnosc": 1.0})
				strzaly += 1
	print("  bron=%s stan=%s komora=%s mag=%s" % [gracz.bron.przedmiot.id if gracz.bron.przedmiot else "-", gracz.bron.stan, gracz.bron.przedmiot.dane.get("komora") if gracz.bron.przedmiot else "", gracz.bron.przedmiot.dane.get("mag") if gracz.bron.przedmiot else ""])
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


## Debug: mapa z góry – siatka nawigacji (zielony), kolizje (szary), drzwi i wyjścia.
func zapisz_mape(plik: String) -> void:
	var px := 10
	var img := Image.create(int(GeneratorBiomu.GW * GeneratorBiomu.C * px), int(GeneratorBiomu.GH * GeneratorBiomu.C * px), false, Image.FORMAT_RGB8)
	img.fill(Color(0.05, 0.05, 0.05))
	var reg: NavigationRegion3D = swiat.get_node("Nawigacja")
	var nm := reg.navigation_mesh
	var verts := nm.get_vertices()
	for i in nm.get_polygon_count():
		var poly := nm.get_polygon(i)
		var y0 := verts[poly[0]].y
		var kol := Color(0.15, 0.5, 0.2) if y0 < 0.3 else Color(0.5, 0.5, 0.1)
		for t in range(1, poly.size() - 1):
			_trojkat(img, verts[poly[0]], verts[poly[t]], verts[poly[t + 1]], px, kol)
	for n in swiat.get_children():
		if n is CollisionObject3D and (n.collision_layer & 1):
			for c in n.get_children():
				if c is CollisionShape3D and c.shape is BoxShape3D:
					var bs: BoxShape3D = c.shape
					var t: Transform3D = (c as Node3D).global_transform
					if t.origin.y + bs.size.y * 0.5 < 0.05:
						continue
					for xx in range(int(-bs.size.x * px / 2), int(bs.size.x * px / 2)):
						for zz in range(int(-bs.size.z * px / 2), int(bs.size.z * px / 2)):
							var p := t * Vector3(float(xx) / px, 0, float(zz) / px)
							var ix := int(p.x * px)
							var iz := int(p.z * px)
							if ix >= 0 and iz >= 0 and ix < img.get_width() and iz < img.get_height():
								img.set_pixel(ix, iz, Color(0.5, 0.5, 0.5) if n.name == "Sciany" else Color(0.7, 0.35, 0.2))
	for w in info["wyjscia"]:
		var p: Vector3 = (w as Node3D).global_position
		img.fill_rect(Rect2i(int(p.x * px) - 4, int(p.z * px) - 4, 8, 8), Color(0.2, 0.9, 1.0))
	var s: Vector3 = info["start"]
	img.fill_rect(Rect2i(int(s.x * px) - 4, int(s.z * px) - 4, 8, 8), Color(1, 1, 1))
	img.save_png(plik)


func _trojkat(img: Image, a: Vector3, b: Vector3, c: Vector3, px: int, kol: Color) -> void:
	var mnx := int(minf(a.x, minf(b.x, c.x)) * px)
	var mxx := int(maxf(a.x, maxf(b.x, c.x)) * px)
	var mnz := int(minf(a.z, minf(b.z, c.z)) * px)
	var mxz := int(maxf(a.z, maxf(b.z, c.z)) * px)
	for x in range(mnx, mxx + 1):
		for z in range(mnz, mxz + 1):
			var p := Vector2(float(x) / px, float(z) / px)
			if Geometry2D.point_is_inside_triangle(p, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)):
				if x >= 0 and z >= 0 and x < img.get_width() and z < img.get_height():
					img.set_pixel(x, z, kol)


## Test walk frakcji: szabrownik i najemnik w jednym pokoju, gracz daleko – mają się zwalczać sami.
func _test_frakcji() -> void:
	for i in 30:
		await get_tree().physics_frame
	var szab: Array = get_tree().get_nodes_in_group("wrogowie").filter(func(w): return w is Wrog and w.frakcja == "szabrownik")
	var naj: Array = get_tree().get_nodes_in_group("wrogowie").filter(func(w): return w is Wrog and w.frakcja != "szabrownik")
	if szab.is_empty() or naj.is_empty():
		print("TEST FRAKCJI: brak obu frakcji na mapie")
		get_tree().quit(1)
		return
	var a: Wrog = szab[0]
	var b: Wrog = naj[0]
	var mapa := swiat.get_world_3d().navigation_map
	var start := gracz.global_position
	a.posterunek = {}
	b.posterunek = {}
	a.global_position = NavigationServer3D.map_get_closest_point(mapa, start + Vector3(2.5, 0, -1.5))
	b.global_position = NavigationServer3D.map_get_closest_point(mapa, start + Vector3(2.5, 0, 2.0))
	a.look_at(b.global_position, Vector3.UP)
	b.look_at(a.global_position, Vector3.UP)
	# gracz poza zasięgiem: najdalszy punkt startowy
	gracz.global_position = start + Vector3(0, 60, 0)
	gracz.sterowanie = false
	gracz.set_physics_process(false)
	var t := 0.0
	while t < 30.0 and not (a.cialo.martwy or b.cialo.martwy):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	print("TEST FRAKCJI: czas %.1f, %s %s hp %.0f%% (cel %s), %s %s hp %.0f%% (cel %s)" % [t, a.frakcja, a.stan, a.cialo.procent() * 100.0, a.gracz.name if a.gracz else "-", b.frakcja, b.stan, b.cialo.procent() * 100.0, b.gracz.name if b.gracz else "-"])
	var ok := a.cialo.procent() < 1.0 or b.cialo.procent() < 1.0
	print("TEST FRAKCJI: ", "OK" if ok else "BRAK WALKI")
	get_tree().quit(0 if ok else 1)


## Test pełzacza: pojawia się pod sufitem kilka metrów od gracza, ma podpełznąć, zeskoczyć, gryźć i wrócić na ścianę.
func _test_mutanta(katalog: String) -> void:
	for i in 30:
		await get_tree().physics_frame
	for w in get_tree().get_nodes_in_group("wrogowie"):
		w.queue_free()
	await get_tree().physics_frame
	gracz.sterowanie = false
	var m := Fauna.new()
	swiat.add_child(m)
	m.global_position = gracz.global_position - gracz.global_basis.z * 5.5 + gracz.global_basis.x * 0.5
	var stany := {}
	var hp0 := gracz.cialo.procent()
	var t := 0.0
	var zrzut := 0
	if katalog != "":
		DirAccess.make_dir_recursive_absolute(katalog)
	while t < 25.0 and not gracz.cialo.martwy:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if m.stan != String(stany.get("_ost", "")):
			stany["_ost"] = m.stan
			stany[m.stan] = snappedf(t, 0.1)
			print("  pełzacz: ", m.stan, " t=", snappedf(t, 0.1), " y=", snappedf(m.global_position.y, 0.01))
			if katalog != "" and m.stan in ["sufit", "skok", "ziemia", "wspinaczka"]:
				# kamera na pełzacza
				var p: Vector3 = m.punkt_celu()
				gracz.look_at(Vector3(p.x, gracz.global_position.y, p.z), Vector3.UP)
				var dir := (p - gracz.kamera.global_position).normalized()
				gracz._pitch = asin(clampf(dir.y, -1, 1))
				gracz.glowa.rotation.x = gracz._pitch
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(katalog.path_join("mutant_%d_%s.png" % [zrzut, m.stan]))
				zrzut += 1
	print("TEST MUTANTA: stany %s, zdrowie gracza %.0f%% -> %.0f%%" % [stany, hp0 * 100.0, gracz.cialo.procent() * 100.0])
	var ok := stany.has("skok") and stany.has("ziemia") and gracz.cialo.procent() < hp0
	print("TEST MUTANTA: ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
