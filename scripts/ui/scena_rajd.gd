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
	Gra.ekw.ograniczony = true      # plecak na plecach: bez zdjęcia nic z niego nie wyjmiesz
	var a := OS.get_cmdline_user_args()
	if a.has("--ziarno"):
		Gra.ziarno_rajdu = int(a[a.find("--ziarno") + 1])
	widok = Widok3D.zbuduj(self)
	Widok3D.zastosuj(widok)
	Gra.ustawienia_zmiana.connect(func(): Widok3D.zastosuj(widok))
	swiat = widok["swiat"]
	gen = GeneratorBiomu.new()
	info = gen.generuj(Gra.ziarno_rajdu, swiat)
	await _nawigacja_ze_sprawdzeniem()
	_postaw_drzwi()
	_zaplanuj_zdarzenia()
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
	for p in Gra.ekw.wszystkie():
		_start_ids[(p as Przedmiot).get_instance_id()] = true
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
	# akustyka: kroki wg podłoża, pogłos wg pomieszczenia, wiatr w tle, napięcie przy wrogach
	Dzwiek.podloze_fn = gen.podloze
	Dzwiek.akustyka_fn = gen.akustyka_w
	Dzwiek.ambient("wiatr", self, -22.0)
	_napiecie = Dzwiek.ambient("napiecie", self, -60.0)
	for i in 3:
		var bz := Dzwiek.petla_3d("brzeczenie", swiat, -16.0, 7.0)
		if bz:
			bz.stream_paused = true
			_brzeczenie.append(bz)
	_tlo_t = randf_range(6.0, 14.0)
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
	elif args.has("--drzwi_ai"):
		_tryb_testu = "drzwi_ai"
		_test_drzwi_ai.call_deferred()
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


# ------------------------------------------------------------------ zdarzenia w strefie

var _plan_zdarzen: Array = []
var _start_ids := {}           # przedmioty wniesione do strefy (do podsumowania łupu)
var odwiedzone := {}           # typy pomieszczeń, w których był gracz (zlecenia zwiadu)
var _odw_t := 0.0
var awaria_pradu := false


## Losowe zdarzenia rajdu: awaria prądu, obława wojska, zrzut zaopatrzenia (godziny losowe, nie w testach).
func _zaplanuj_zdarzenia() -> void:
	var a := OS.get_cmdline_user_args()
	if a.has("--test") or a.has("--walka") or a.has("--frakcje") or a.has("--mutant") or a.has("--ewakuacja") or a.has("--vm") or a.has("--zrzuty"):
		if a.has("--zdarzenia"):
			_plan_zdarzen = [{"t": 2.0, "typ": "awaria"}, {"t": 4.0, "typ": "zrzut"}, {"t": 6.0, "typ": "oblawa"}]
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = Gra.ziarno_rajdu * 7 + 3
	if rng.randf() < 0.4:
		_plan_zdarzen.append({"t": rng.randf_range(300.0, 900.0), "typ": "awaria"})
	if rng.randf() < 0.3:
		_plan_zdarzen.append({"t": rng.randf_range(420.0, 1200.0), "typ": "oblawa"})
	if rng.randf() < 0.3:
		_plan_zdarzen.append({"t": rng.randf_range(480.0, 1100.0), "typ": "zrzut"})


func _zdarzenia_strefy() -> void:
	for z in _plan_zdarzen.duplicate():
		if czas >= float(z["t"]):
			_plan_zdarzen.erase(z)
			if OS.get_cmdline_user_args().has("--zdarzenia"):
				print("ZDARZENIE: %s (%.1f s)" % [z["typ"], czas])
			match String(z["typ"]):
				"awaria":
					_awaria_pradu()
				"oblawa":
					_oblawa()
				"zrzut":
					_zrzut()


## Gasną wszystkie lampy na 60–100 s (trzask przekaźnika), potem wracają z migotaniem.
func _awaria_pradu() -> void:
	awaria_pradu = true
	Dzwiek.graj("prad", -4.0, 0.9)
	gracz.komunikat.emit("Trzasnęło w rozdzielni – zgasło światło w całym budynku.")
	dodaj_zdarzenie("Awaria prądu.")
	for l in info["lampy"]:
		if not is_instance_valid(l):
			continue
		if l.get("awaria") != null:
			l.set_meta("awaria0", l.awaria)
			l.awaria = 1.0
		else:
			l.set_meta("e0", (l as Light3D).light_energy)
			(l as Light3D).light_energy = 0.0
	for bz in _brzeczenie:
		(bz as AudioStreamPlayer3D).volume_db = -80.0
	get_tree().create_timer(randf_range(60.0, 100.0)).timeout.connect(func():
		if koniec:
			return
		awaria_pradu = false
		Dzwiek.graj("prad", -8.0, 1.1)
		gracz.komunikat.emit("Prąd wrócił.")
		for l in info["lampy"]:
			if not is_instance_valid(l):
				continue
			if l.has_meta("awaria0"):
				l.awaria = l.get_meta("awaria0")
			elif l.has_meta("e0"):
				(l as Light3D).light_energy = l.get_meta("e0")
		for bz in _brzeczenie:
			(bz as AudioStreamPlayer3D).volume_db = -16.0 + linear_to_db(Gra.ustawienia.get("glosnosc", 0.8)))


## Obława: oddział wojska wchodzi do strefy z daleka i przeczesuje okolicę gracza.
func _oblawa() -> void:
	var mw := get_node_or_null("Wrogowie")
	if mw == null:
		return
	var kand: Array = info["spawny"].filter(func(s): return (s["pos"] as Vector3).distance_to(gracz.global_position) > 35.0)
	if kand.is_empty():
		return
	var s0: Dictionary = kand[randi() % kand.size()]
	var przed: int = mw.oddzialy.size()
	mw._oddzial("wojskowy", [s0], 3, przed)
	if mw.oddzialy.size() > przed:
		for w in mw.oddzialy[mw.oddzialy.size() - 1].czlonkowie:
			w.stan = "szukanie"
			w.ostatnia_pozycja = gracz.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
	Dzwiek.graj("strzaly_daleko_1", -14.0, 0.8)
	gracz.komunikat.emit("Gdzieś przy wejściu słychać komendy i tupot butów – wojsko przeczesuje strefę.")
	dodaj_zdarzenie("Obława wojska.")


## Zrzut: przelot samolotu, skrzynia spada przez dziurę w stropie w odległym pomieszczeniu, świeci raca.
func _zrzut() -> void:
	var kand := []
	for k in info["komorki"]:
		if info["komorki"][k]["typ"] in ["pokoj", "magazyn", "administracja", "warsztat"] and gen._srodek(k).distance_to(gracz.global_position) > 28.0:
			kand.append(k)
	if kand.is_empty():
		return
	var k: Vector2i = kand[randi() % kand.size()]
	var mapa := swiat.get_world_3d().navigation_map
	var pos := NavigationServer3D.map_get_closest_point(mapa, gen._srodek(k) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	Dzwiek.graj("samolot", -6.0)
	gracz.komunikat.emit("Nad budynkiem przeleciał samolot. Coś spadło – w oddali świeci raca.")
	dodaj_zdarzenie("Zrzut zaopatrzenia.")
	get_tree().create_timer(6.5).timeout.connect(func():
		if koniec:
			return
		var pj: Node3D = gen._mebel("skrzynia_wojskowa", pos + Vector3.UP * 2.4, randf() * TAU, true, k)
		if pj is Pojemnik:
			(pj as Pojemnik).nazwa = "Skrzynia zrzutowa"
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			(pj as Pojemnik).wypelnij("skrzynia_wojskowa", 4, rng)
		var tw := pj.create_tween()
		tw.tween_property(pj, "position:y", pos.y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			Dzwiek.graj_3d("drzwi_kopniak", pos, swiat, 4.0, 0.6, 60.0)
			Efekty.kurz(swiat, pos + Vector3.UP * 0.3, 2.5)
			Gra.emituj_halas(pos, 45.0, null))
		# czerwona raca obok skrzyni
		var raca := OmniLight3D.new()
		raca.light_color = Color(1.0, 0.15, 0.08)
		raca.light_energy = 2.5
		raca.omni_range = 7.0
		swiat.add_child(raca)
		raca.global_position = pos + Vector3(0.6, 0.3, 0.0)
		info["lampy"].append(raca)
		var tr := raca.create_tween().set_loops(240)
		tr.tween_property(raca, "light_energy", 1.6, 0.25)
		tr.tween_property(raca, "light_energy", 2.6, 0.25)
		get_tree().create_timer(120.0).timeout.connect(func():
			if is_instance_valid(raca):
				info["lampy"].erase(raca)
				raca.queue_free()))


## Skrzydła drzwi w otworach (po wypieczeniu nawigacji – ścieżki prowadzą przez otwory, a wrogowie
## otwierają drzwi po drodze). Rodzaj wg pomieszczenia, część zamknięta, część uchylona, ślepe pokoje
## czasem zamknięte na klucz.
func _postaw_drzwi() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Gra.ziarno_rajdu * 31 + 7
	var start := gen.komorka_w(info["start"])
	var bez_testu := not (OS.get_cmdline_user_args().has("--test") or OS.get_cmdline_user_args().has("--walka") or OS.get_cmdline_user_args().has("--frakcje") or OS.get_cmdline_user_args().has("--mutant"))
	for m in info.get("drzwi", []):
		if rng.randf() > 0.8:
			continue
		var pk: Vector2i = m["pokoj"]
		var typ: String = info["komorki"][pk]["typ"] if info["komorki"].has(pk) else "pokoj"
		var rodz := "fornir"
		match typ:
			"pokoj":
				rodz = "skaj" if rng.randf() < 0.5 else "fornir"
			"kuchnia", "administracja":
				rodz = "emalia" if rng.randf() < 0.7 else "fornir"
			"piwnica", "magazyn", "warsztat":
				rodz = "metal" if rng.randf() < 0.5 else "fornir"
		var d := Drzwi.new()
		d.ustaw(m, rodz)
		swiat.add_child(d)
		var los := rng.randf()
		if not bez_testu:
			d.ustaw_kat(KAT_TESTU)
		elif los < 0.45:
			d.ustaw_kat(0.0)
			var otwory := 0
			for kier in info["komorki"][pk]["otwory"]:
				otwory += (info["komorki"][pk]["otwory"][kier] as Array).size()
			if otwory <= 1 and pk != start and rng.randf() < 0.4:
				d.na_klucz = true
		elif los < 0.7:
			d.ustaw_kat(-rng.randf_range(0.25, 0.6))
		else:
			d.ustaw_kat(Drzwi.KAT_PELNY)


const KAT_TESTU := -1.62
var _brzeczenie: Array = []
var _napiecie: AudioStreamPlayer
var _napiecie_cel := 0.0
var _tlo_t := 10.0


func _exit_tree() -> void:
	Dzwiek.podloze_fn = Callable()
	Dzwiek.akustyka_fn = Callable()


## Odgłosy strefy: kapanie, skrzypienie budynku, odległe strzelaniny i wycie – losowo, z różnych stron.
func _tlo_strefy(delta: float) -> void:
	_tlo_t -= delta
	if _tlo_t > 0.0:
		return
	_tlo_t = randf_range(9.0, 26.0)
	var gp := gracz.global_position
	var ak: Dictionary = gen.akustyka_w(gp)
	var los := randf()
	var kier := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	if los < 0.35:
		# kapanie blisko (piwnice, klatki i magazyny częściej)
		var ile := 3 if ak["typ"] in ["piwnica", "klatka", "magazyn"] else 1
		for i in ile:
			var p := gp + kier * randf_range(2.0, 6.0) + Vector3.UP * 2.2
			get_tree().create_timer(i * randf_range(0.6, 1.4)).timeout.connect(func():
				if is_instance_valid(swiat):
					Dzwiek.graj_3d(Dzwiek.wariant("kapanie"), p, swiat, -10.0, randf_range(0.9, 1.1), 12.0))
	elif los < 0.6:
		Dzwiek.graj_3d("skrzyp_budynku", gp + kier * randf_range(6.0, 14.0) + Vector3.UP * 3.0, swiat, -6.0, randf_range(0.8, 1.1), 30.0)
	elif los < 0.88:
		# odległa wymiana ognia gdzieś w strefie (2D, ściszona – za wiele ścian na okluzję)
		Dzwiek.graj(Dzwiek.wariant("strzaly_daleko"), randf_range(-24.0, -15.0), randf_range(0.9, 1.05))
	else:
		Dzwiek.graj("wycie", randf_range(-26.0, -18.0), randf_range(0.85, 1.1))


## Dron napięcia: narasta, gdy wrogowie w pobliżu są czujni lub walczą.
func _napiecie_tick(delta: float) -> void:
	if _napiecie == null:
		return
	var gp := gracz.global_position
	var n := 0.0
	for w in get_tree().get_nodes_in_group("wrogowie"):
		if not is_instance_valid(w) or str(w.get("stan")) == "martwy":
			continue
		var d := (w as Node3D).global_position.distance_to(gp)
		if d > 30.0:
			continue
		var czujnosc := clampf(float(w.get("wykrycie") if w.get("wykrycie") != null else 0.0), 0.0, 1.0)
		if str(w.get("stan")) in ["walka", "atak", "skok", "poscig"]:
			czujnosc = 1.0
		n = maxf(n, (1.0 - d / 30.0) * (0.35 + czujnosc * 0.65))
	_napiecie_cel = n
	var db := lerpf(-50.0, -10.0, _napiecie_cel) + linear_to_db(Gra.ustawienia.get("glosnosc", 0.8))
	_napiecie.volume_db = move_toward(_napiecie.volume_db, db, delta * (12.0 if db > _napiecie.volume_db else 4.0))


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
			(bliskie[i][1] as Light3D).shadow_enabled = i < (3 if bool(Gra.ustawienia.get("cienie", true)) else 0)
		# brzęczenie świetlówek: 3 najbliższe świecące lampy
		for i in _brzeczenie.size():
			var bz: AudioStreamPlayer3D = _brzeczenie[i]
			if i < bliskie.size() and bliskie[i][0] < 8.0 * 8.0:
				bz.global_position = (bliskie[i][1] as Node3D).global_position
				bz.stream_paused = false
			else:
				bz.stream_paused = true
		_napiecie_tick(0.3)
	_tlo_strefy(delta)
	_zdarzenia_strefy()
	_odw_t -= delta
	if _odw_t <= 0.0:
		_odw_t = 1.0
		var kk := gen.komorka_w(gracz.global_position)
		if kk.x >= 0:
			var typ: String = info["komorki"][kk]["typ"]
			if not odwiedzone.has(typ):
				odwiedzone[typ] = true
				for k in Gra.kontrakty.get("aktywne", []):
					if k["typ"] == "zwiad" and k["cel"] == typ:
						gracz.komunikat.emit("Zlecenie: dotarłeś na miejsce – teraz wróć żywy.")
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
	w["odwiedzone"] = odwiedzone.keys()
	if w.get("przezyl", false):
		var nowe := []
		for p in Gra.ekw.wszystkie():
			if not _start_ids.has((p as Przedmiot).get_instance_id()):
				nowe.append({"nazwa": (p as Przedmiot).nazwa(), "wartosc": (p as Przedmiot).wartosc()})
		nowe.sort_custom(func(a, b): return a["wartosc"] > b["wartosc"])
		w["wyniesione"] = nowe
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
## Oświetlenie punktu 0..1 (lampy w pobliżu, latarka gracza skierowana w tę stronę).
func oswietlenie(punkt: Vector3) -> float:
	var best := 0.12
	if gracz and gracz.latarka and gracz.latarka.visible:
		var d := punkt - gracz.latarka.global_position
		if d.length() < 6.0 and (-gracz.latarka.global_basis.z).dot(d.normalized()) > 0.7:
			return 1.0
	for l in info.get("lampy", []):
		if not is_instance_valid(l) or (l as Light3D).light_energy < 0.3:
			continue
		var r: float = (l as OmniLight3D).omni_range if l is OmniLight3D else 6.0
		var dd: float = (l as Node3D).global_position.distance_to(punkt)
		if dd < r * 0.8:
			best = maxf(best, 1.0 - dd / (r * 0.8) * 0.65)
	return best


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
var _wrog_testowy = null


## Spójność siatki: przedmioty bez nakładania i w dostępnych polach.
func _siatka_ok(sg: Siatka) -> bool:
	var zajete := {}
	for e in sg.items:
		var p: Przedmiot = e["p"]
		for y in p.wys():
			for x in p.szer():
				var k := Vector2i(int(e["x"]) + x, int(e["y"]) + y)
				if zajete.has(k) or not sg.dostepna(k.x, k.y):
					return false
				zajete[k] = true
	return true


func _wszystkie_przedmioty(pj: Pojemnik) -> Array:
	var out: Array = Gra.ekw.wszystkie()
	if pj:
		for c in pj.lista_czesci():
			out.append_array((c["siatka"] as Siatka).items.map(func(e): return e["p"]))
	for n in swiat.get_children():
		if n is LupNaZiemi and not n.is_queued_for_deletion():
			out.append(n.przedmiot)
	return out


func _test_mechanik() -> void:
	var bledy := 0
	var ek := Gra.ekw
	gracz.sterowanie = false
	# A: kolejka przenoszenia przerwana zamknięciem – nic nie znika ani się nie dubluje
	var pj := Pojemnik.new()
	pj.nazwa = "Szafa testowa"
	pj.siatka = Siatka.new(5, 4)
	for pid in ["konserwa", "zegarek", "bandaz", "kompas"]:
		pj.siatka.dodaj(Przedmiot.nowy(pid))
	swiat.add_child(pj)
	pj.global_position = gracz.global_position - gracz.global_basis.z * 1.0
	ek.sloty["plecak"] = null
	var przed := _wszystkie_przedmioty(pj).size()
	ekran_ekw.otworz(pj)
	await _klatki(3)
	pj.odkryj_wszystko()
	for e in pj.siatka.items.duplicate():
		ekran_ekw._szybkie_przeniesienie(e["p"], {"typ": "siatka", "siatka": pj.siatka})
	await get_tree().create_timer(1.6).timeout
	ekran_ekw.zamknij()
	await _klatki(5)
	var po := _wszystkie_przedmioty(pj)
	var unik := {}
	for x in po:
		unik[x] = true
	var ok := po.size() == przed and unik.size() == po.size()
	print("A kolejka przerwana: przed %d po %d unikalne %d %s" % [przed, po.size(), unik.size(), "OK" if ok else "BLAD"])
	bledy += 0 if ok else 1
	# B: trafienie w trakcie przekładania – przedmiot na ziemi
	ekran_ekw.otworz(pj)
	await _klatki(3)
	var zost: Array = pj.siatka.items.map(func(e): return e["p"])
	if not zost.is_empty():
		var p0: Przedmiot = zost[0]
		ekran_ekw._szybkie_przeniesienie(p0, {"typ": "siatka", "siatka": pj.siatka})
		await get_tree().create_timer(0.6).timeout
		gracz.trafiony(gracz.global_position + Vector3.UP * 0.3, 1.0, 0.0, null)
		await _klatki(5)
		var na_ziemi := swiat.get_children().any(func(n): return n is LupNaZiemi and n.przedmiot == p0)
		ok = na_ziemi and not pj.siatka.zawiera(p0) and not ekran_ekw.otwarty
		print("B trafienie w trakcie: na ziemi %s %s" % [na_ziemi, "OK" if ok else "BLAD"])
		bledy += 0 if ok else 1
	# C: rosnący stos nie nachodzi na sąsiada
	ek.ograniczony = true
	var kk := ek.kieszenie
	for e in kk.items.duplicate():
		kk.usun(e["p"])
	var g9 := Przedmiot.nowy("a_762", 9)
	kk.poloz(g9, 0, 0, false)
	kk.poloz(Przedmiot.nowy("kompas"), 0, 1, false)
	ek.dodaj(Przedmiot.nowy("a_762", 5))
	ok = _siatka_ok(kk)
	print("C stos w kieszeni: %s" % ("OK" if ok else "BLAD (nakładanie)"))
	bledy += 0 if ok else 1
	for sg in ek.siatki():
		if not _siatka_ok(sg):
			print("C siatka nieprawidłowa: ", sg)
			bledy += 1
	# D: wyrzucenie przy ścianie – nie za ścianę
	var space := gracz.get_world_3d().direct_space_state
	var przod := -gracz.global_basis.z
	var hh := {}
	for obr in 8:
		gracz.rotation.y += PI / 4.0
		await _klatki(1)
		przod = -gracz.global_basis.z
		var qq := PhysicsRayQueryParameters3D.create(gracz.global_position + Vector3.UP * 0.3, gracz.global_position + Vector3.UP * 0.3 + przod * 6.0, Balistyka.WARSTWA_SWIAT)
		qq.exclude = [gracz.get_rid()]
		hh = space.intersect_ray(qq)
		if not hh.is_empty():
			break
	if not hh.is_empty():
		var sciana: Vector3 = hh["position"]
		gracz.global_position = sciana - przod * 0.35 - Vector3.UP * 0.3
		await _klatki(3)
		var q2 := PhysicsRayQueryParameters3D.create(gracz.global_position + Vector3.UP * 0.3, gracz.global_position + Vector3.UP * 0.3 + przod * 6.0, Balistyka.WARSTWA_SWIAT)
		q2.exclude = [gracz.get_rid()]
		var h2 := space.intersect_ray(q2)
		var d_sc: float = (h2["position"] - (gracz.global_position + Vector3.UP * 0.3)).length() if not h2.is_empty() else 9.0
		var l := gracz.upusc(Przedmiot.nowy("konserwa"))
		await get_tree().create_timer(1.0).timeout
		var d_l := Vector2(l.global_position.x - gracz.global_position.x, l.global_position.z - gracz.global_position.z).dot(Vector2(przod.x, przod.z))
		# nic nie stoi między graczem a leżącym przedmiotem (nie przeleciał przez ścianę)
		var q3 := PhysicsRayQueryParameters3D.create(gracz.global_position + Vector3.UP * 0.3, l.global_position + Vector3.UP * 0.1, Balistyka.WARSTWA_SWIAT)
		q3.exclude = [gracz.get_rid()]
		ok = space.intersect_ray(q3).is_empty()
		print("D wyrzucenie przy ścianie: %.2f m przed graczem (ściana %.2f) %s" % [d_l, d_sc, "OK" if ok else "BLAD"])
		bledy += 0 if ok else 1
	# E: kłódka – wyłamanie
	var pk := Pojemnik.new()
	pk.nazwa = "Skrzynia"
	pk.siatka = Siatka.new(3, 2)
	pk.zamkniety_kluczem = "klodka"
	swiat.add_child(pk)
	pk.global_position = gracz.global_position
	pk.interakcja(gracz)
	while not gracz.akcja.is_empty():
		await get_tree().process_frame
	ok = pk.zamkniety_kluczem == ""
	print("E kłódka wyłamana: %s" % ("OK" if ok else "BLAD"))
	bledy += 0 if ok else 1
	# F: wyjęcie znalezionego przedmiotu nie odsłania kolejnego
	var pf := Pojemnik.new()
	pf.nazwa = "Szuflada"
	pf.siatka = Siatka.new(4, 2)
	for pid in ["zegarek", "kompas", "bandaz"]:
		pf.siatka.dodaj(Przedmiot.nowy(pid))
	swiat.add_child(pf)
	pf.szukaj(10.0, 1.0)
	var pierwszy: Przedmiot = pf.siatka.items[0]["p"]
	var znany: bool = pf.lista_czesci()[0]["znane"].has(pierwszy)
	pf.siatka.usun(pierwszy)
	var drugi: Przedmiot = pf.siatka.items[0]["p"]
	ok = znany and not pf.lista_czesci()[0]["znane"].has(drugi) and not pf.przeszukany()
	print("F szukanie po wyjęciu: %s" % ("OK" if ok else "BLAD"))
	bledy += 0 if ok else 1
	# G: kolejka czynności – lek zlecony w trakcie innej czynności rusza po jej końcu
	ek.ograniczony = true
	var bz := Przedmiot.nowy("bolostop")
	ek.kieszenie.dodaj(bz)
	gracz.cialo.przeciwbol = 0.0
	gracz.zacznij_akcje("Test", 0.6, func(): pass, "podnies")
	gracz.uzyj_leku(bz, true)
	var w_kolejce := gracz.kolejka_akcji.size()
	await get_tree().create_timer(0.8).timeout
	var ruszyl: bool = not gracz.akcja.is_empty() and String(gracz.akcja.get("typ", "")) == "leczenie_bolostop"
	ok = w_kolejce == 1 and ruszyl
	print("G kolejka czynności: zaplanowano %d, ruszyło %s %s" % [w_kolejce, ruszyl, "OK" if ok else "BLAD"])
	bledy += 0 if ok else 1
	gracz.przerwij_akcje(true)
	print("TEST MECHANIK: błędów %d" % bledy)


func _zrzut_vm(katalog: String) -> void:
	DirAccess.make_dir_recursive_absolute(katalog)
	for w in get_tree().get_nodes_in_group("wrogowie"):
		if _wrog_testowy == null and w is Wrog and OS.get_cmdline_user_args().has("--szaber") and w.frakcja == "szabrownik" and w.posterunek.is_empty():
			_wrog_testowy = w
			continue
		if _wrog_testowy == null and w is Wrog and OS.get_cmdline_user_args().has("--granat"):
			_wrog_testowy = w
			w.set_physics_process(false)
			continue
		if _wrog_testowy == null and w is Wrog and w.frakcja == "szabrownik" and OS.get_cmdline_user_args().has("--poddanie"):
			_wrog_testowy = w
			continue
		if _wrog_testowy == null and w is Wrog and OS.get_cmdline_user_args().has("--drzwi"):
			_wrog_testowy = w
			continue
		if _wrog_testowy == null and w is Wrog and OS.get_cmdline_user_args().has("--zwloki"):
			_wrog_testowy = w
			w.set_physics_process(false)
			continue
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


## Wrogowie chodzą po mapie z drzwiami (zamknięte, uchylone, na klucz): czy nie utykają pod drzwiami.
func _test_drzwi_ai() -> void:
	gracz.global_position += Vector3(0, 40, 0)
	gracz.set_physics_process(false)
	var drzwi := get_tree().get_nodes_in_group("drzwi")
	var zamkn0 := drzwi.filter(func(d): return d.zamkniete()).size()
	var pozycje := {}
	var utkniety := {}
	for w in get_tree().get_nodes_in_group("wrogowie"):
		pozycje[w] = (w as Node3D).global_position
	var droga := 0.0
	for i in 120:
		await get_tree().create_timer(0.5).timeout
		for w in pozycje.keys():
			if not is_instance_valid(w):
				continue
			var p: Vector3 = (w as Node3D).global_position
			droga += p.distance_to(pozycje[w])
			pozycje[w] = p
			for d in drzwi:
				if d.zamkniete() and p.distance_to(d.global_position) < 1.3:
					utkniety[w] = float(utkniety.get(w, 0.0)) + 0.5
	var zamkn1 := drzwi.filter(func(d): return d.zamkniete()).size()
	var max_ut := 0.0
	for w in utkniety:
		max_ut = maxf(max_ut, utkniety[w])
	print("TEST DRZWI AI: drzwi %d, zamkniętych %d -> %d, wyważonych %d, droga wrogów %.0f m, najdłużej pod zamkniętymi %.1f s" % [drzwi.size(), zamkn0, zamkn1,
		drzwi.filter(func(d): return d.wywazone).size(), droga, max_ut])
	print("TEST DRZWI AI: " + ("OK" if max_ut < 8.0 else "UTKNIĘCIE"))
	get_tree().quit()


## Broń w ruchu: lufa przy ścianie (opuszczona, bez strzału), bezwładność przy obrocie, przechył w bok.
func _test_ruchu_broni(katalog: String) -> void:
	var bledy := 0
	Gra.ekw.sloty["glowna"] = Gra.nowy_naladowany("kb47", "a_762")
	gracz._wybierz_bron("glowna")
	await get_tree().create_timer(1.5).timeout
	var space := swiat.get_world_3d().direct_space_state
	# najbliższa ściana: promienie wokół gracza
	var best := 99.0
	var kier_best := Vector3.FORWARD
	for i in 16:
		var k := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
		var q := PhysicsRayQueryParameters3D.create(gracz.global_position + Vector3.UP * 1.5, gracz.global_position + Vector3.UP * 1.5 + k * 6.0, Balistyka.WARSTWA_SWIAT)
		q.exclude = [gracz.get_rid()]
		var r := space.intersect_ray(q)
		if not r.is_empty() and (r["position"] as Vector3).distance_to(gracz.global_position + Vector3.UP * 1.5) < best:
			best = (r["position"] as Vector3).distance_to(gracz.global_position + Vector3.UP * 1.5)
			kier_best = k
	var cel := gracz.global_position + kier_best
	gracz.look_at(Vector3(cel.x, gracz.global_position.y, cel.z), Vector3.UP)
	gracz.kamera.rotation.x = 0.0
	await get_tree().create_timer(0.4).timeout
	await _zapisz(katalog, "rb_0_wolno")
	# podejście pod ścianę na 0,35 m
	gracz.global_position += kier_best * maxf(0.0, best - 0.45)
	await get_tree().create_timer(1.0).timeout
	await _zapisz(katalog, "rb_1_sciana")
	print("  przy ścianie (%.2f m): sciana=%.2f" % [best, gracz.bron.sciana])
	if gracz.bron.sciana < 0.6:
		bledy += 1
	gracz.global_position -= kier_best * 0.9
	await get_tree().create_timer(1.0).timeout
	print("  odsunięty: sciana=%.2f" % gracz.bron.sciana)
	if gracz.bron.sciana > 0.2:
		bledy += 1
	# obrót głowy: bezwładność (broń zostaje z tyłu, potem wraca)
	for i in 6:
		gracz.bron.dodaj_sway(Vector2(40, 0))
		await get_tree().process_frame
	await _zapisz(katalog, "rb_2_obrot")
	print("  sway po obrocie: %s" % gracz.bron._sway)
	await get_tree().create_timer(0.8).timeout
	print("  sway po 0,8 s: %s" % gracz.bron._sway)
	if gracz.bron._sway.length() > 0.01:
		bledy += 1
	print("TEST RUCHU BRONI: błędów %d" % bledy)


## Test drzwi: otwieranie, uchylanie, zamykanie, wyważanie, wróg otwierający drzwi, podsłuch, przestrzał.
func _test_drzwi(katalog: String) -> void:
	var bledy := 0
	var lista := get_tree().get_nodes_in_group("drzwi")
	print("DRZWI: %d skrzydeł, zamkniętych %d, na klucz %d, metalowych %d" % [lista.size(), lista.filter(func(d): return d.zamkniete()).size(),
		lista.filter(func(d): return d.na_klucz).size(), lista.filter(func(d): return d.rodzaj == "metal").size()])
	if lista.is_empty():
		print("TEST DRZWI: brak drzwi")
		return
	var kom := []
	gracz.komunikat.connect(func(t): kom.append(t))
	var sw := OmniLight3D.new()
	sw.omni_range = 6.0
	sw.light_energy = 1.4
	gracz.kamera.add_child(sw)
	# najbliższe drzwi, gracz po stronie przeciwnej do otwierania
	var gp := gracz.global_position
	lista.sort_custom(func(a, b): return a.global_position.distance_to(gp) < b.global_position.distance_to(gp))
	var rodzaje := {}
	for d0 in lista:
		rodzaje[d0.rodzaj] = d0
	var dr: Drzwi = lista[0]
	var ustaw_przed := func(d: Drzwi, odl: float):
		d.ustaw_kat(0.0)
		var p: Vector3 = d.global_transform * Vector3(0, 0, -odl)
		gracz.global_position = Vector3(p.x, d.global_position.y + 0.05, p.z)
		gracz.velocity = Vector3.ZERO
		var c: Vector3 = d.global_transform * Vector3(0, 0, 0)
		gracz.look_at(Vector3(c.x, gracz.global_position.y, c.z), Vector3.UP)
		gracz.kamera.rotation.x = -0.05
	# zrzuty każdego rodzaju
	for r in rodzaje:
		ustaw_przed.call(rodzaje[r], 1.6)
		await get_tree().create_timer(0.5).timeout
		await _zapisz(katalog, "drzwi_%s" % r)
		print("  %s: kat %.2f max %.2f poz %s n %s skrzydło %s zawias.rot %s" % [r, rodzaje[r].kat, rodzaje[r].max_kat, rodzaje[r].global_position, rodzaje[r].global_basis.z, rodzaje[r].skrzydlo.global_position, rodzaje[r]._zawias.rotation])
	ustaw_przed.call(dr, 1.0)
	await get_tree().create_timer(0.4).timeout
	# uchylenie kucając
	gracz.kucanie = 1.0
	dr.interakcja(gracz)
	await get_tree().create_timer(2.2).timeout
	await _zapisz(katalog, "drzwi_uchylone")
	print("  uchylone: %s kat %.2f" % [dr.rodzaj, dr.kat])
	if not (dr.kat < -0.2 and dr.kat > -0.45):
		print("  BŁĄD: uchylenie kat=%.2f" % dr.kat)
		bledy += 1
	gracz.kucanie = 0.0
	await get_tree().create_timer(0.3).timeout
	dr.interakcja(gracz)
	await get_tree().create_timer(1.6).timeout
	await _zapisz(katalog, "drzwi_otwarte")
	if dr.kat > -1.0 and dr.max_kat < -1.0:
		print("  BŁĄD: otwarcie kat=%.2f max=%.2f" % [dr.kat, dr.max_kat])
		bledy += 1
	dr.interakcja(gracz)
	await get_tree().create_timer(1.4).timeout
	if not dr.zamkniete():
		print("  BŁĄD: zamknięcie kat=%.2f" % dr.kat)
		bledy += 1
	# przestrzał drewnianych drzwi: kula za drzwiami zostawia ślad na ścianie dalej
	# wyważanie
	dr.na_klucz = true
	dr.wytrzymalosc = 2
	var kopniecia := 0
	while not dr.wywazone and kopniecia < 8:
		dr.interakcja(gracz)
		await get_tree().create_timer(1.2).timeout
		kopniecia += 1
	await get_tree().create_timer(0.8).timeout
	await _zapisz(katalog, "drzwi_wywazone")
	print("  wyważone po %d kopnięciach: %s, kat %.2f" % [kopniecia, dr.wywazone, dr.kat])
	if not dr.wywazone:
		bledy += 1
	# podsłuch: wróg za zamkniętymi drzwiami
	var d2: Drzwi = null
	for d in lista:
		if d != dr and d.rodzaj != "metal":
			d2 = d
			break
	var w = _wrog_testowy
	if d2 and w:
		d2.na_klucz = false
		ustaw_przed.call(d2, 0.8)
		var za: Vector3 = d2.global_transform * Vector3(0, 0, 3.0)
		w.global_position = w._najblizszy_na_siatce(za)
		w.set_physics_process(false)
		kom.clear()
		await get_tree().create_timer(2.4).timeout
		print("  podsłuch: %s" % [kom])
		if not kom.any(func(t): return String(t).begins_with("Za drzwiami")):
			print("  BŁĄD: podsłuch nic nie dał")
			bledy += 1
		# wróg idzie przez zamknięte drzwi – powinien je otworzyć
		gracz.global_position = d2.global_transform * Vector3(2.5, 0.05, -3.0)
		w.set_physics_process(true)
		var cel: Vector3 = w._najblizszy_na_siatce(d2.global_transform * Vector3(0, 0, -3.0))
		var t := 0.0
		while t < 15.0 and d2.zamkniete():
			w.stan = "szukanie"
			w._idz(cel)
			await get_tree().create_timer(0.3).timeout
			t += 0.3
		print("  wróg przy drzwiach po %.1f s, otwarte: %s (wróg %.1f m od drzwi)" % [t, not d2.zamkniete(), w.global_position.distance_to(d2.global_position)])
		if d2.zamkniete():
			bledy += 1
	print("TEST DRZWI: błędów %d" % bledy)


func _zapisz(katalog: String, nazwa: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join(nazwa + ".png"))


func _klatki(n: int) -> void:
	for f in n:
		await get_tree().process_frame


## Animacje broni: blokada zamka, przeładowanie z pustą komorą, łamanie obrzyna, zegarek, dodatki.
func _zrzut_animacji(katalog: String) -> void:
	var b := gracz.bron
	if OS.get_cmdline_user_args().has("--kontrola"):
		var kb: Przedmiot = Gra.nowy_naladowany("kb47", "a_762")
		Gra.ekw.sloty["glowna"] = kb
		gracz._wybierz_bron("glowna")
		await _klatki(40)
		b.stan = "sprawdzanie"
		b.stan_t = 0.0
		b.stan_total = 1.8
		await get_tree().create_timer(0.75).timeout
		await _zapisz(katalog, "ko_sprawdzanie")
		await get_tree().create_timer(1.4).timeout
		kb.dane["zaciecie"] = true
		b.stan = "usuwanie"
		b.stan_t = 0.0
		b.stan_total = 1.3
		await get_tree().create_timer(0.5).timeout
		await _zapisz(katalog, "ko_zaciecie")
		await get_tree().create_timer(1.2).timeout
		print("zaciecie po: ", kb.dane["zaciecie"])
		return
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
	if OS.get_cmdline_user_args().has("--drzwi"):
		await _test_drzwi(katalog)
		return
	if OS.get_cmdline_user_args().has("--granat"):
		var w = _wrog_testowy
		var bl := 0
		Gra.ekw.kieszenie.dodaj(Przedmiot.nowy("granat_f1"))
		var cel: Vector3 = gracz.global_position - gracz.global_basis.z * 6.0
		w.global_position = w._najblizszy_na_siatce(cel)
		gracz.kamera.rotation.x = 0.15
		gracz.rzuc_granat()
		await get_tree().create_timer(0.6).timeout
		await _zapisz(katalog, "granat_1_zamach")
		await get_tree().create_timer(0.9).timeout
		await _zapisz(katalog, "granat_2_lot")
		var gr := get_tree().get_nodes_in_group("granaty")
		var t := 0.0
		var hp0: float = w.cialo.procent()
		while t < 6.0 and w.cialo.procent() >= hp0:
			await get_tree().process_frame
			t += get_process_delta_time()
		await _zapisz(katalog, "granat_3_wybuch")
		print("  wróg: hp %.0f%% -> %.0f%%, martwy %s, odl. %.1f m" % [hp0 * 100.0, w.cialo.procent() * 100.0, w.cialo.martwy, w.global_position.distance_to(gracz.global_position)])
		if w.cialo.procent() >= hp0:
			bl += 1
		print("TEST GRANATU: błędów %d" % bl)
		return
	if OS.get_cmdline_user_args().has("--poddanie"):
		var w = _wrog_testowy
		var bl := 0
		if w == null:
			print("TEST PODDANIA: brak szabrownika")
			return
		var kom := []
		gracz.komunikat.connect(func(t): kom.append(t))
		Gra.bony = 1000
		var p: Vector3 = gracz.global_position - gracz.global_basis.z * 5.0
		w.global_position = w._najblizszy_na_siatce(p)
		w.look_at(Vector3(gracz.global_position.x, w.global_position.y, gracz.global_position.z), Vector3.UP)
		w.posterunek = {}
		w.cecha = "zwykly"
		w.lup.append(Przedmiot.nowy("zegarek"))
		w.gracz = gracz
		w.stan = "walka"
		w.morale = 5.0
		w._w_magazynku = 0
		w.zapas_mag = 0
		w.cialo.obrazenia("brzuch", 30.0)
		var t := 0.0
		while t < 8.0 and not w.poddany:
			await get_tree().create_timer(0.25).timeout
			t += 0.25
		await get_tree().create_timer(1.0).timeout
		gracz.look_at(Vector3(w.global_position.x, gracz.global_position.y, w.global_position.z), Vector3.UP)
		await get_tree().create_timer(0.4).timeout
		await _zapisz(katalog, "poddanie")
		print("  poddany po %.1f s: %s, stan %s, wrogi graczowi: %s" % [t, w.poddany, w.stan, w.wrogi(gracz)])
		if not w.poddany or w.wrogi(gracz):
			bl += 1
		var przed := get_tree().get_nodes_in_group("lup_swiat").size()
		w.interakcja(gracz)
		await get_tree().create_timer(1.0).timeout
		var po := get_tree().get_nodes_in_group("lup_swiat").size()
		print("  łup na ziemi: %d -> %d" % [przed, po])
		if po <= przed:
			bl += 1
		w.interakcja(gracz)
		print("  informacja: %s, bony %d" % [kom.back() if not kom.is_empty() else "-", Gra.bony])
		if Gra.bony != 700:
			bl += 1
		w.interakcja(gracz)
		await get_tree().create_timer(1.0).timeout
		print("  po puszczeniu: stan %s" % w.stan)
		print("TEST PODDANIA: błędów %d" % bl)
		return
	if OS.get_cmdline_user_args().has("--potrzeby"):
		var bl := 0
		Gra.potrzeby = {"glod": 20.0, "pragnienie": 12.0}
		var w := Przedmiot.nowy("woda")
		var k := Przedmiot.nowy("konserwa")
		Gra.ekw.kieszenie.dodaj(w)
		Gra.ekw.kieszenie.dodaj(k)
		gracz.spozyj(w)
		await get_tree().create_timer(1.5).timeout
		await _zapisz(katalog, "pot_picie")
		await get_tree().create_timer(2.6).timeout
		gracz.spozyj(k)
		await get_tree().create_timer(2.0).timeout
		await _zapisz(katalog, "pot_jedzenie")
		await get_tree().create_timer(4.6).timeout
		print("  po: %s, w kieszeni woda %s konserwa %s" % [Gra.potrzeby, Gra.ekw.kieszenie.zawiera(w), Gra.ekw.kieszenie.zawiera(k)])
		if float(Gra.potrzeby["pragnienie"]) < 40.0 or float(Gra.potrzeby["glod"]) < 50.0 or Gra.ekw.kieszenie.zawiera(w):
			bl += 1
		var p0: float = Gra.potrzeby["pragnienie"]
		await get_tree().create_timer(5.0).timeout
		print("  spadek pragnienia w 5 s: %.3f" % (p0 - float(Gra.potrzeby["pragnienie"])))
		if p0 <= float(Gra.potrzeby["pragnienie"]):
			bl += 1
		print("TEST POTRZEB: błędów %d" % bl)
		return
	if OS.get_cmdline_user_args().has("--ruch_broni"):
		await _test_ruchu_broni(katalog)
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
			await get_tree().create_timer(2.0).timeout
			await _zapisz(katalog, "pl_%s_b" % pid)
			if ekran_ekw._kieszenie.has(slot):
				var gui: SiatkaUI = ekran_ekw._ramki[slot].get_meta("siatka_ui")
				for i in (ekran_ekw._kieszenie[slot] as Array).size():
					ekran_ekw._klik_kieszeni(gui, i, slot)
					await get_tree().create_timer(0.3).timeout
					if i == 0:
						await _zapisz(katalog, "pl_%s_c" % pid)
					while ekran_ekw._zajete():
						await get_tree().process_frame
					await get_tree().create_timer(0.1).timeout
				await get_tree().create_timer(0.4).timeout
				await _zapisz(katalog, "pl_%s_d" % pid)
				print("%s kieszenie: %s" % [pid, (ekran_ekw._kieszenie[slot] as Array).map(func(e): return "%s=%s" % [e["nazwa"], e["otwarta"]])])
			ekran_ekw.zamknij()
			await get_tree().create_timer(1.0).timeout
		return
	if OS.get_cmdline_user_args().has("--mechaniki"):
		await _test_mechanik()
		return
	if OS.get_cmdline_user_args().has("--szaber"):
		var w0 = _wrog_testowy
		if w0 == null:
			print("SZABER: brak szabrownika")
			return
		# gracz daleko i niewidoczny: wróg nie walczy
		gracz.global_position = w0.global_position + Vector3(0, 30, 0)
		gracz.set_physics_process(false)
		var l := LupNaZiemi.new()
		l.przedmiot = Przedmiot.nowy("zegarek")
		swiat.add_child(l)
		var kier: Vector3 = -w0.global_basis.z
		l.global_position = w0._najblizszy_na_siatce(w0.global_position + kier * 3.0) + Vector3.UP * 0.2
		w0.stan = "patrol"
		w0._szaber_skan = 0.0
		var t0 := 0.0
		while t0 < 40.0 and is_instance_valid(l):
			await get_tree().create_timer(0.5).timeout
			t0 += 0.5
		print("SZABER: po %.0f s stan=%s, zegarek zabrany=%s, w łupie wroga: %s" % [t0, w0.stan, not is_instance_valid(l), w0.lup.any(func(x): return x.id == "zegarek")])
		return
	if OS.get_cmdline_user_args().has("--nowe"):
		var ek := Gra.ekw
		var kb: Przedmiot = Gra.nowy_naladowany("kb47", "a_762")
		kb.dane["mag"].dane["naboje"] = 0
		kb.dane["komora"] = ""
		ek.sloty["glowna"] = kb
		ek.sloty["plecak"] = Przedmiot.nowy("plecak_turystyczny")
		# magazynki tylko w plecaku
		for sg in ek.siatki(true):
			for e in (sg as Siatka).items.duplicate():
				if (e["p"] as Przedmiot).typ() in ["magazynek", "amunicja"]:
					(sg as Siatka).usun(e["p"])
		ek.siatka_plecaka().poloz(Gra.magazynek("mag_kb47", "a_762", 30), 0, 2, false)
		gracz._wybierz_bron("glowna")
		await _klatki(30)
		print("ograniczony: ", ek.ograniczony, " magazynek pod ręką: ", not ek.znajdz_magazynek(["mag_kb47"]).is_empty())
		ekran_ekw.otworz(null)
		await _klatki(3)
		ekran_ekw.przelacz_pojemnik("plecak")
		await get_tree().create_timer(2.6).timeout
		ekran_ekw._synchronizuj_dostep()
		print("plecak rozłożony, zapięty – magazynek: ", not ek.znajdz_magazynek(["mag_kb47"]).is_empty())
		var gui: SiatkaUI = ekran_ekw._ramki["plecak"].get_meta("siatka_ui")
		ekran_ekw._klik_kieszeni(gui, 1, "plecak")
		while ekran_ekw._zajete():
			await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
		ekran_ekw._synchronizuj_dostep()
		print("komora otwarta – magazynek: ", not ek.znajdz_magazynek(["mag_kb47"]).is_empty())
		# nieznany przedmiot
		var nz := Przedmiot.nowy("zegarek")
		nz.dane["nieznany"] = true
		ek.kieszenie.dodaj(nz)
		print("nazwa przed: ", nz.nazwa())
		ekran_ekw._obejrzyj(nz)
		await get_tree().create_timer(0.8).timeout
		await _zapisz(katalog, "nw_ogladanie")
		while not gracz.akcja.is_empty():
			await get_tree().process_frame
		print("nazwa po: ", nz.nazwa())
		var m2 := Gra.magazynek("mag_kb47", "a_762", 17)
		m2.dane["sprawdzony"] = false
		print("etykieta nieprzeliczonego: ", m2.etykieta())
		ek.siatka_plecaka().dodaj(Przedmiot.nowy("konserwa"))
		ek.siatka_plecaka().dodaj(Przedmiot.nowy("klucz_nastawny"))
		ek._brzek = -1.0
		print("brzęk: %.2f" % ek.brzek())
		# taśma: owinięcie konserwy
		ek.kieszenie.dodaj(Przedmiot.nowy("tasma"))
		var kons: Przedmiot = null
		for e in ek.siatka_plecaka().items:
			if (e["p"] as Przedmiot).id == "konserwa":
				kons = e["p"]
		ekran_ekw._uzyj_narzedzia(kons, "tasma", 2.0, "Owijanie taśmą", func(): kons.dane["wyciszony"] = true)
		while not gracz.akcja.is_empty():
			await get_tree().process_frame
		ek._brzek = -1.0
		print("brzęk po taśmie: %.2f, taśma użyć: %s" % [ek.brzek(), str(ekran_ekw._znajdz_narzedzie("tasma").dane.get("uzycia"))])
		var sk := Siatka.new(6, 4)
		for pid in ["konserwa", "kb47", "bandaz", "mag_kb47", "zegarek"]:
			sk.dodaj(Przedmiot.nowy(pid))
		print("sortowanie: ", sk.sortuj(), " pierwszy: ", sk.items[0]["p"].id)
		return
	if OS.get_cmdline_user_args().has("--reka"):
		# przekładanie ręką: z kieszeni do rozłożonego plecaka (przeciągnięcie), potem trafienie w trakcie
		Gra.ekw.sloty["plecak"] = Przedmiot.nowy("plecak_turystyczny")
		Gra.ekw.kieszenie.dodaj(Przedmiot.nowy("konserwa"))
		print("dodano kompas: ", Gra.ekw.kieszenie.dodaj(Przedmiot.nowy("kompas")))
		ekran_ekw.otworz(null)
		await _klatki(5)
		ekran_ekw.przelacz_pojemnik("plecak")
		await get_tree().create_timer(2.0).timeout
		var gui: SiatkaUI = ekran_ekw._ramki["plecak"].get_meta("siatka_ui")
		for i in (ekran_ekw._kieszenie["plecak"] as Array).size():
			ekran_ekw._klik_kieszeni(gui, i, "plecak")
			while ekran_ekw._zajete():
				await get_tree().process_frame
			await get_tree().create_timer(0.1).timeout
		await get_tree().create_timer(0.5).timeout
		gui = ekran_ekw._ramki["plecak"].get_meta("siatka_ui")
		var kons: Przedmiot = null
		for e in Gra.ekw.kieszenie.items:
			if (e["p"] as Przedmiot).id == "konserwa":
				kons = e["p"]
		var cel := gui.global_position + Vector2(2.5, 2.5) * SiatkaUI.KOM
		ekran_ekw._animuj(kons, {"typ": "siatka", "siatka": Gra.ekw.kieszenie}, cel, func():
			Gra.ekw.kieszenie.usun(kons)
			Gra.ekw.siatka_plecaka().poloz(kons, 2, 2, false))
		for fr in [0.2, 0.45, 0.65, 0.88]:
			while ekran_ekw._reka_p.aktywna and ekran_ekw._reka_p.postep() < fr:
				await get_tree().process_frame
			await _zapisz(katalog, "rk_%d" % int(fr * 100))
		while not ekran_ekw._przekl.is_empty():
			await get_tree().process_frame
		print("konserwa w plecaku: ", Gra.ekw.siatka_plecaka().zawiera(kons))
		# drugi: trafienie w trakcie
		var radio: Przedmiot = null
		for e in Gra.ekw.kieszenie.items:
			if (e["p"] as Przedmiot).id == "kompas":
				radio = e["p"]
		ekran_ekw._animuj(radio, {"typ": "siatka", "siatka": Gra.ekw.kieszenie}, cel, func(): pass)
		await get_tree().create_timer(0.7).timeout
		gracz.trafiony(gracz.global_position + Vector3.UP * 0.3, 5.0, 0.0, null)
		await get_tree().create_timer(1.2).timeout
		var na_ziemi: Array = swiat.get_children().filter(func(x): return x is LupNaZiemi and x.przedmiot == radio)
		print("radio w kieszeniach: ", Gra.ekw.kieszenie.zawiera(radio), " na ziemi: ", na_ziemi.size(), " ekran otwarty: ", ekran_ekw.otwarty, " plecak w slocie: ", Gra.ekw.sloty["plecak"] != null)
		return
	if OS.get_cmdline_user_args().has("--porzucenie"):
		Gra.ekw.sloty["plecak"] = Przedmiot.nowy("plecak_wojskowy")
		Gra.ekw.siatka_plecaka().dodaj(Przedmiot.nowy("konserwa"))
		ekran_ekw.otworz(null)
		await _klatki(5)
		ekran_ekw.przelacz_pojemnik("plecak")
		await get_tree().create_timer(2.5).timeout
		await _zapisz(katalog, "pz_0_rozlozony")
		gracz.sterowanie = true
		Input.action_press("tyl")
		await get_tree().create_timer(0.8).timeout
		Input.action_release("tyl")
		await get_tree().create_timer(0.6).timeout
		gracz.kamera.rotation.x = -0.6
		await _klatki(5)
		await _zapisz(katalog, "pz_1_porzucony")
		var lz: Array = swiat.get_children().filter(func(x): return x is LupNaZiemi and x.przedmiot.id == "plecak_wojskowy")
		print("plecak w slocie: ", Gra.ekw.sloty["plecak"], " na ziemi: ", lz.size(), " otwarty: ", ekran_ekw.otwarty)
		if not lz.is_empty():
			print("tekst: ", lz[0].tekst_interakcji(gracz))
			lz[0].interakcja(gracz)
			while not gracz.akcja.is_empty():
				await get_tree().process_frame
			print("po zalozeniu: ", Gra.ekw.sloty["plecak"] != null, " konserwa: ", Gra.ekw.siatka_plecaka().items.size() if Gra.ekw.siatka_plecaka() else -1)
		# szybka kamizelka w marszu
		ekran_ekw.otworz(null)
		await _klatki(2)
		ekran_ekw.szybka_kamizelka()
		var p0 := gracz.global_position
		Input.action_press("przod")
		await get_tree().create_timer(1.0).timeout
		Input.action_release("przod")
		print("marsz z kamizelka: %.2f m, otwarty: %s" % [gracz.global_position.distance_to(p0), ekran_ekw.otwarty])
		return
	if OS.get_cmdline_user_args().has("--zwloki"):
		# wróg pada przed graczem, gracz przeszukuje ciało po częściach i zdejmuje pancerz
		gracz.sterowanie = false
		var przod3 := -gracz.global_basis.z
		przod3.y = 0
		przod3 = przod3.normalized()
		var w0 = _wrog_testowy

		if w0 == null:
			print("brak wroga")
			return
		w0.global_position = gracz.global_position + przod3 * 1.3
		w0.pancerz = Przedmiot.nowy("kamizelka_kl2")
		w0.helm = Przedmiot.nowy("helm_wz67")
		await _klatki(3)
		w0.cialo.martwy = true
		w0._smierc("test")
		await get_tree().create_timer(1.2).timeout
		await _zapisz(katalog, "zw_0_cialo")
		var pj2: Pojemnik = null
		for c in w0.get_children():
			if c is Pojemnik:
				pj2 = c
		pj2.interakcja(gracz)
		while not gracz.akcja.is_empty():
			await get_tree().process_frame
		await get_tree().create_timer(1.5).timeout
		await _zapisz(katalog, "zw_1_kieszenie")
		await get_tree().create_timer(4.0).timeout
		await _zapisz(katalog, "zw_2_calosc")
		print("pancerz na modelu: ", w0._czesci.get("pancerz_m").visible if w0._czesci.has("pancerz_m") else "brak")
		# kolejka przekładania: wszystkie magazynki z ładownic Ctrl+klikiem
		for c in pj2.lista_czesci():
			if c["nazwa"] == "Ładownice":
				for e in (c["siatka"] as Siatka).items.duplicate():
					ekran_ekw._szybkie_przeniesienie(e["p"], {"typ": "siatka", "siatka": c["siatka"]})
				print("w kolejce: ", ekran_ekw._kolejka.size())
				await get_tree().create_timer(0.3).timeout
				await _zapisz(katalog, "zw_2b_kolejka")
				while not ekran_ekw._kolejka.is_empty() or ekran_ekw._zajete():
					await get_tree().process_frame
				print("w ladownicach po kolejce: ", (c["siatka"] as Siatka).items.size(), " kolejka: ", ekran_ekw._kolejka.size())
		var nc: Dictionary = pj2.lista_czesci()[pj2.lista_czesci().size() - 1]
		print("czesci: ", pj2.lista_czesci().map(func(c): return "%s:%d/%d" % [c["nazwa"], c["odkryte"], (c["siatka"] as Siatka).items.size()]))
		if nc["zdejmowane"] and not (nc["siatka"] as Siatka).items.is_empty():
			ekran_ekw._zdejmij_z_ciala((nc["siatka"] as Siatka).items[0]["p"], nc["siatka"])
			await get_tree().create_timer(1.0).timeout
			await _zapisz(katalog, "zw_3_zdejmowanie")
			while not gracz.akcja.is_empty():
				await get_tree().process_frame
			print("pancerz na modelu po zdjęciu: ", w0._czesci.get("pancerz_m").visible if w0._czesci.has("pancerz_m") else "brak")
			print("po zdjeciu na ciele: ", (nc["siatka"] as Siatka).items.size(), " pancerz w ekw: ", Gra.ekw.siatki().any(func(s): return (s as Siatka).items.any(func(e): return (e["p"] as Przedmiot).typ() == "pancerz")))
		return
	if OS.get_cmdline_user_args().has("--meble"):
		gracz.sterowanie = false
		var ar2 := OS.get_cmdline_user_args()
		var lista_m := ["szafa", "szafka_metalowa", "meblosciana", "szafka_kuchenna", "lodowka", "biurko", "skrzynia_wojskowa", "skrzynia", "apteczka_scienna"]
		if ar2.has("--tylko"):
			lista_m = [ar2[ar2.find("--tylko") + 1]]
		var przod2 := -gracz.global_basis.z
		przod2.y = 0
		przod2 = przod2.normalized()
		for mid in lista_m:
			var pj := Pojemnik.new()
			pj.nazwa = String(mid)
			pj.mebel_id = mid
			pj.siatka = Siatka.new(5, 3)
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 3
			pj.wypelnij("szafa", 4, rng2)
			var mm := ModeleMebli.zbuduj(mid)
			pj.mebel = mm
			pj.niski = mid in ["meblosciana", "szafka_kuchenna", "biurko", "skrzynia_wojskowa", "skrzynia"]
			pj.add_child(mm["wezel"])
			swiat.add_child(pj)
			var odl := 1.25 if mid != "apteczka_scienna" else 0.9
			pj.global_position = gracz.global_position + przod2 * odl + (Vector3.UP * 1.2 if mid == "apteczka_scienna" else Vector3.ZERO)
			pj.look_at(gracz.global_position + Vector3.UP * pj.global_position.y, Vector3.UP, true)
			gracz.rotation.y += 0.6
			await _klatki(5)
			pj.interakcja(gracz)
			await get_tree().create_timer(0.25).timeout
			await _zapisz(katalog, "mb_%s_a" % mid)
			while not gracz.akcja.is_empty():
				await get_tree().process_frame
			await get_tree().create_timer(2.6).timeout
			await _zapisz(katalog, "mb_%s_b" % mid)
			ekran_ekw.zamknij()
			await get_tree().create_timer(0.8).timeout
			pj.queue_free()
			await _klatki(3)
		return
	if OS.get_cmdline_user_args().has("--lup"):
		# wszystkie przedmioty położone na ziemi w siatce przed graczem, kamera w dół
		gracz.sterowanie = false
		var ids: Array = Dane.przedmioty.keys()
		var przod := -gracz.global_basis.z
		przod.y = 0
		przod = przod.normalized()
		var bok := przod.cross(Vector3.UP)
		var kol := 6
		var grupy := [ids.slice(0, 18), ids.slice(18, 36), ids.slice(36, ids.size())]
		for gi in grupy.size():
			var ln: Array = []
			for i in grupy[gi].size():
				var pr := Przedmiot.nowy(String(grupy[gi][i]), 40 if Dane.def(String(grupy[gi][i])).get("typ", "") == "amunicja" else 1)
				if pr.typ() == "bron":
					pr = Gra.nowy_naladowany(pr.id, {"pw9": "a_9x18", "pm63": "a_9x18", "kb47": "a_762", "obrzyn": "a_12"}[pr.id])
					if pr.id == "kb47":
						pr.dane["dod_wylot"] = Przedmiot.nowy("tlumik_762")
						pr.dane["dod_celownik"] = Przedmiot.nowy("luneta")
						pr.dane["dod_latarka"] = Przedmiot.nowy("latarka_taktyczna")
						pr.dane["dod_chwyt"] = Przedmiot.nowy("chwyt")
				var l := LupNaZiemi.new()
				l.przedmiot = pr
				swiat.add_child(l)
				l.global_position = gracz.global_position + przod * (1.0 + (i / kol) * 0.45) + bok * ((i % kol) - kol * 0.5 + 0.5) * 0.42 + Vector3.UP * 0.3
				ln.append(l)
			gracz.kamera.rotation.x = -0.95
			await _klatki(20)
			await _zapisz(katalog, "lup_%d" % gi)
			for l in ln:
				l.queue_free()
			await _klatki(3)
		# rzut z dłoni
		gracz.kamera.rotation.x = -0.5
		gracz.upusc(Gra.nowy_naladowany("kb47", "a_762"))
		await _klatki(8)
		await _zapisz(katalog, "lup_rzut_lot")
		await get_tree().create_timer(0.45).timeout
		await _zapisz(katalog, "lup_rzut_kurz")
		Efekty.iskry(swiat, gracz.global_position - gracz.global_basis.z * 1.0 + Vector3.UP * 0.5, Vector3.UP)
		await get_tree().create_timer(0.08).timeout
		await _zapisz(katalog, "lup_iskry")
		await _klatki(40)
		await _zapisz(katalog, "lup_rzut_lezy")
		return
	if OS.get_cmdline_user_args().has("--czynnosci"):
		gracz.sterowanie = false
		var tylko := ""
		var ar := OS.get_cmdline_user_args()
		if ar.has("--tylko"):
			tylko = ar[ar.find("--tylko") + 1]
		var lista := [["rozladowanie", "mag_kb47", "a_762", 2.4, 8], ["rozladowanie", "obrzyn", "a_12", 1.6, 2], ["magazynek", "mag_kb47", "a_762", 3.0, 6], ["magazynek", "mag_pw9", "a_9x18", 2.4, 6],
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
