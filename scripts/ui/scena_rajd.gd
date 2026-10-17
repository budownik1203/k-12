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


func _process(delta: float) -> void:
	if koniec or gracz == null:
		return
	czas += delta
	for w in info["wyjscia"]:
		(w as Ewakuacja).rajd_czas = czas
	if _tryb_testu == "test" and czas > 1.0 and czas - delta <= 1.0:
		# spójność siatki nawigacji: ścieżka od startu do każdego pomieszczenia
		var mapa := swiat.get_world_3d().navigation_map
		var ok := 0
		for k in info["komorki"]:
			var c := Vector3(k.x * GeneratorBiomu.C + 3.0, 0.0, k.y * GeneratorBiomu.C + 3.0)
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
			if int(kon.x / GeneratorBiomu.C) == k.x and int(kon.z / GeneratorBiomu.C) == k.y:
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
				var a: Vector2i = e["a"]
				var b: Vector2i = e["b"]
				var srodek: float = (GeneratorBiomu.C * 0.5) if e["otwarte"] else (e["drzwi"] + GeneratorBiomu.DRZWI_W * 0.5)
				var p1: Vector3
				var p2: Vector3
				if a.x != b.x:
					var x := maxi(a.x, b.x) * GeneratorBiomu.C
					var z := a.y * GeneratorBiomu.C + srodek
					p1 = Vector3(x - 1.0, 0, z)
					p2 = Vector3(x + 1.0, 0, z)
				else:
					var z2 := maxi(a.y, b.y) * GeneratorBiomu.C
					var x2 := a.x * GeneratorBiomu.C + srodek
					p1 = Vector3(x2, 0, z2 - 1.0)
					p2 = Vector3(x2, 0, z2 + 1.0)
				var q1 := NavigationServer3D.map_get_closest_point(mapa, p1)
				var q2 := NavigationServer3D.map_get_closest_point(mapa, p2)
				var sc := NavigationServer3D.map_get_path(mapa, q1, q2, true)
				var ok2: bool = sc.size() > 0 and sc[sc.size() - 1].distance_to(q2) < 0.3 and q1.distance_to(p1) < 0.8 and q2.distance_to(p2) < 0.8
				if not ok2:
					print("  DRZWI ZABLOKOWANE %s p1=%s->%s p2=%s->%s" % [kk, p1, q1, p2, q2])
		if aa.has("--pokoje"):
			for k in info["komorki"]:
				var pts := []
				for d in GeneratorBiomu.DIRS:
					var n: Vector2i = k + d
					var kk2 := gen._k(k, n)
					if not gen.krawedzie.has(kk2):
						continue
					var e: Dictionary = gen.krawedzie[kk2]
					var srodek: float = (GeneratorBiomu.C * 0.5) if e["otwarte"] else (e["drzwi"] + GeneratorBiomu.DRZWI_W * 0.5)
					var c := Vector3(k.x * GeneratorBiomu.C, 0, k.y * GeneratorBiomu.C)
					match d:
						Vector2i(1, 0): pts.append(c + Vector3(GeneratorBiomu.C - 1.0, 0, srodek))
						Vector2i(-1, 0): pts.append(c + Vector3(1.0, 0, srodek))
						Vector2i(0, 1): pts.append(c + Vector3(srodek, 0, GeneratorBiomu.C - 1.0))
						Vector2i(0, -1): pts.append(c + Vector3(srodek, 0, 1.0))
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
				print("  krawedz %s drzwi=%.2f otwarte=%s" % [kk, e["drzwi"], e["otwarte"]])
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
		if info["komorki"][k]["typ"] == "korytarz":
			# w korytarzu: z wejścia jednego ramienia wzdłuż korytarza
			var ram: Array = gen._ramiona(k)
			var d: Vector2i = ram[n % ram.size()]
			gracz.global_position = Vector3(k.x * GeneratorBiomu.C + 3.0 - d.x * 2.6, 0.05, k.y * GeneratorBiomu.C + 3.0 - d.y * 2.6)
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
	gracz.latarka.visible = true
	var przod := -gracz.global_basis.z
	var pies := Fauna.new()
	swiat.add_child(pies)
	pies.global_position = gracz.global_position + przod * 2.6 + gracz.global_basis.x * -0.6
	pies.rotation.y = gracz.rotation.y + 2.4
	pies.set_physics_process(false)
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


## Test walki: najbliższy oddział zostaje przeniesiony w pobliże gracza; gracz strzela do najbliższego wroga.
func _test_walki() -> void:
	for i in 20:
		await get_tree().physics_frame
	if gracz.ekw.sloty["glowna"] == null:
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
		var b := gracz.bron
		if b.przedmiot and b.stan == "gotowa":
			if b.przedmiot.dane["komora"] == "" and b.przedmiot.dane.get("wewn", 0) == 0:
				b._zacznij_przeladowanie(false)
			elif fmod(t, 0.25) < get_physics_process_delta_time():
				b.cooldown = 0.0
				b.spust_puszczony = true
				b._sprobuj_strzal({"kucanie": 0.0, "celnosc": 1.0})
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
