class_name Fauna
extends CharacterBody3D
## Pełzacz: mutant strefy chodzący po ścianach i sufitach. Czai się pod sufitem, pełznie nad ofiarą,
## zeskakuje z wrzaskiem, gryzie na ziemi, a ranny albo po chwili walki wspina się po ścianie i znika
## w ciemności pod stropem. Atakuje wszystko, co żyje (gracza i ludzi z każdej frakcji).

var nazwa_jednostki := "Pełzacz"
var frakcja := "fauna"
var ostatni_sprawca: Node = null   # kto trafił ostatni – do rozliczeń zabójstw
var oddzial = null
var cialo: Cialo
var stan := "sufit"          # sufit | skok | ziemia | wspinaczka | martwy
var gracz: Node3D            # bieżąca ofiara (nazwa zgodna z resztą AI)
var kucanie := 0.0

var _agent: NavigationAgent3D
var _model: Node3D
var _konczyny: Array = []    # [udo, golen, faza]
var _glowa: Node3D
var _szczeka: Node3D
var _normal := Vector3.DOWN  # powierzchnia, na której jest (podłoga UP, sufit DOWN, ściana – jej normalna)
var _kier := Vector3.FORWARD
var _p := Vector3.ZERO       # rzut pozycji na podłogę (ścieżki liczone po siatce nawigacji)
var _sciezka := PackedVector3Array()
var _idx := 0
var _cel_ruchu := Vector3.ZERO
var _t := 0.0
var _atak_t := 0.0
var _decyzja_t := 0.0
var _percepcja_t := 0.0
var _dzwiek_t := 0.0
var _ziemia_t := 0.0
var _hp_ladowanie := 1.0
var _ucieczka_t := 0.0
var _wspin := {}             # {"faza", "sciana", "normal", "t"}
var _skok := {}
var _suf_y := 2.6
var _sluch_pos := Vector3.ZERO
var _sluch_t := 0.0


func _init() -> void:
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	add_to_group("wrogowie")
	add_to_group("fauna")
	cialo = Cialo.new({"glowa": 22.0, "klatka": 55.0, "brzuch": 40.0, "rece": 35.0, "nogi": 40.0})
	cialo.smierc.connect(_smierc)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 0.7
	cs.shape = cap
	cs.position.y = 0.35
	add_child(cs)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 0.9
	_agent.radius = 0.3
	add_child(_agent)
	_buduj()
	Gra.halas.connect(_halas)
	_decyzja_t = randf_range(0.5, 2.0)
	_dzwiek_t = randf_range(2.0, 6.0)
	_kier = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()


var _start := true


## Pierwsza klatka: pozycja nadana przez spawner – od razu pod sufit nad punktem odrodzenia.
func _na_start() -> void:
	_start = false
	var q := _na_siatce(global_position)
	_p = q if q.distance_to(global_position) < 3.0 else global_position
	_suf_y = _sufit(_p)
	global_position = Vector3(_p.x, _suf_y, _p.z)
	_normal = Vector3.DOWN
	_ustaw_orientacje(1.0)


# ------------------------------------------------------------------ model

func _buduj() -> void:
	# organiczne kształty (Tkanina: powierzchnie parametryczne ze skórą): wychudły tułów z żebrami
	# i grzebieniem kręgosłupa, wydłużona czaszka z zapadniętymi oczodołami, szczęka z zębami,
	# długie kończyny ze stawami i trzema pazurami
	var T := preload("res://scripts/ui/tkanina.gd")
	var B := preload("res://scripts/core/bryly.gd")
	var skora := Color(0.6, 0.6, 0.62)
	var opc := {"mat": "skora_npc", "vm": false}
	_model = Node3D.new()
	add_child(_model)
	var tulow := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var z := lerpf(0.34, -0.32, v)
		var cy := 0.3 + 0.05 * sin(v * PI)
		var r := 0.0
		if v < 0.12:
			r = 0.1 * sin(v / 0.12 * PI * 0.5)
		elif v < 0.35:
			r = lerpf(0.1, 0.066, (v - 0.12) / 0.23)
		elif v < 0.75:
			var t := (v - 0.35) / 0.4
			r = lerpf(0.066, 0.13, sin(t * PI * 0.75))
		elif v < 0.9:
			r = 0.115
		else:
			r = lerpf(0.115, 0.05, (v - 0.9) / 0.1)
		var gora := maxf(0.0, sin(th))
		# żebra po bokach i na grzbiecie, grzebień kręgów na środku grzbietu
		if v > 0.42 and v < 0.76 and sin(th) > -0.4:
			r += 0.012 * maxf(0.0, sin(v * 72.0))
		r += 0.022 * pow(maxf(0.0, cos(th - PI * 0.5)), 12.0) * (0.55 + 0.45 * sin(v * 95.0))
		var rx := r * (1.15 if v > 0.72 and v < 0.92 else 1.0)
		return Vector3(cos(th) * rx, cy + sin(th) * r * (0.85 + 0.15 * gora), z)
	var ao_t := func(u: float, v: float) -> float:
		var th := u * TAU
		var a := 0.85 + 0.15 * sin(th)
		if v > 0.42 and v < 0.76 and sin(th) > -0.4:
			a *= 0.8 + 0.2 * maxf(0.0, sin(v * 72.0))
		if sin(u * 41.0 + v * 17.0) > 0.97:
			a *= 0.78     # żyły
		return a
	_model.add_child(T.powierzchnia(18, 40, tulow, Callable(), skora, {"mat": "skora_npc", "vm": false, "ao": ao_t}))
	# szyja: żylasta, wysunięta do przodu
	_model.add_child(T.rura(Vector3(0, 0.31, -0.24), Vector3(0, 0.36, -0.4), func(v): return 0.045 - 0.008 * sin(v * PI), skora, opc))
	_glowa = Node3D.new()
	_glowa.position = Vector3(0, 0.34, -0.36)
	_model.add_child(_glowa)
	var czaszka := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var z := lerpf(0.03, -0.27, v)
		var r := 0.0
		if v < 0.1:
			r = 0.065 * sin(v / 0.1 * PI * 0.5)
		elif v < 0.4:
			r = lerpf(0.065, 0.082, (v - 0.1) / 0.3)
		elif v < 0.9:
			r = lerpf(0.082, 0.042, (v - 0.4) / 0.5)
		else:
			r = 0.042 * cos((v - 0.9) / 0.1 * PI * 0.5)
		# wał nad oczodołami
		if v > 0.5 and v < 0.62:
			r += 0.008 * pow(maxf(0.0, sin(th)), 2.0)
		return Vector3(cos(th) * r, 0.03 + sin(th) * r * 0.78, z)
	var ao_g := func(u: float, v: float) -> float:
		var th := u * TAU
		# zapadnięte oczodoły
		if v > 0.56 and v < 0.7 and sin(th) > 0.3 and absf(cos(th)) > 0.35:
			return 0.25
		return 0.9 + 0.1 * sin(th)
	_glowa.add_child(T.powierzchnia(16, 20, czaszka, Callable(), skora, {"mat": "skora_npc", "vm": false, "ao": ao_g}))
	var zeby := []
	for i in 6:
		for sx in [-1.0, 1.0]:
			var z := -0.12 - i * 0.022
			zeby.append(B.walec(Vector3(sx * (0.03 - i * 0.002), 0.0, z), Vector3(sx * (0.03 - i * 0.002), -0.022, z), 0.006, 0.0, "bandaz", 5))
	# oczy: małe, mętne, świecące
	zeby.append({"t": "box", "c": Vector3(-0.044, 0.075, -0.17), "s": Vector3(0.018, 0.01, 0.012), "m": "czern", "k": Color(1.0, 0.9, 0.5), "f": 0.004})
	zeby.append({"t": "box", "c": Vector3(0.044, 0.075, -0.17), "s": Vector3(0.018, 0.01, 0.012), "m": "czern", "k": Color(1.0, 0.9, 0.5), "f": 0.004})
	var mz := B.instancja(zeby, true)
	_glowa.add_child(mz)
	_szczeka = Node3D.new()
	_szczeka.position = Vector3(0, -0.02, -0.02)
	_glowa.add_child(_szczeka)
	_szczeka.add_child(T.rura(Vector3(0, -0.012, 0.0), Vector3(0, -0.01, -0.24), func(v): return lerpf(0.042, 0.028, v), skora.darkened(0.08), opc, 0.45))
	var dol := []
	for i in 5:
		for sx in [-1.0, 1.0]:
			var z2 := -0.1 - i * 0.025
			dol.append(B.walec(Vector3(sx * 0.024, 0.004, z2), Vector3(sx * 0.024, 0.026, z2), 0.005, 0.0, "bandaz", 5))
	dol.append({"t": "box", "c": Vector3(0, 0.002, -0.15), "s": Vector3(0.04, 0.008, 0.16), "m": "czerwony", "k": Color(0.5, 0.1, 0.08), "f": 0.0})
	_szczeka.add_child(B.instancja(dol, false))
	# cztery długie kończyny: ramię (udo) w górę i na bok, przedramię (goleń) w dół, trzy pazury
	var stawy := [Vector3(-0.13, 0.33, -0.2), Vector3(0.13, 0.33, -0.2), Vector3(-0.1, 0.31, 0.24), Vector3(0.1, 0.31, 0.24)]
	for i in stawy.size():
		var strona := -1.0 if i % 2 == 0 else 1.0
		var udo := Node3D.new()
		udo.position = stawy[i]
		_model.add_child(udo)
		udo.add_child(T.rura(Vector3.ZERO, Vector3(strona * 0.33, 0.16, 0), func(v): return 0.03 + 0.012 * sin(v * PI) - 0.008 * v, skora, opc))
		var golen := Node3D.new()
		golen.position = Vector3(strona * 0.33, 0.16, 0)
		udo.add_child(golen)
		golen.add_child(T.rura(Vector3(0, 0.02, 0), Vector3(strona * 0.035, -0.43, 0), func(v): return lerpf(0.03, 0.017, v) + 0.008 * exp(-pow((v - 0.05) * 12.0, 2.0)), skora, opc))
		var pazury := []
		var kon := Vector3(strona * 0.035, -0.43, 0)
		for kz in [-0.045, 0.0, 0.045]:
			var srodkowy := absf(kz) < 0.01
			pazury.append(B.walec(kon, kon + Vector3(strona * 0.02, -0.035, kz - 0.01), 0.012, 0.009, "skora_npc", 5))
			pazury.append(B.walec(kon + Vector3(strona * 0.02, -0.035, kz - 0.01), kon + Vector3(strona * 0.03, -0.05 - (0.012 if srodkowy else 0.0), kz * 1.5 - 0.035), 0.008, 0.0, "czern", 5))
		golen.add_child(B.instancja(pazury, false))
		_konczyny.append([udo, golen, PI * float(i % 2) + (PI * 0.5 if i >= 2 else 0.0)])
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hitbox(_glowa, "glowa", Vector3(0, 0.02, -0.12), Vector3(0.2, 0.2, 0.3))
	_hitbox(_model, "klatka", Vector3(0, 0.3, -0.18), Vector3(0.34, 0.24, 0.36))
	_hitbox(_model, "brzuch", Vector3(0, 0.3, 0.22), Vector3(0.32, 0.22, 0.4))
	_hitbox(_model, "nogi", Vector3(0, 0.2, 0.0), Vector3(0.95, 0.3, 0.7))


func _hitbox(rodzic: Node3D, czesc: String, poz: Vector3, roz: Vector3) -> void:
	var a := Area3D.new()
	a.collision_layer = Balistyka.WARSTWA_HITBOX_WROGA
	a.collision_mask = 0
	a.monitoring = false
	a.set_meta("czesc", czesc)
	a.set_meta("wlasciciel", self)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = roz
	cs.shape = bs
	cs.position = poz
	a.add_child(cs)
	rodzic.add_child(a)


## Punkt, w który celują inni (środek tułowia – także gdy wisi pod sufitem).
func punkt_celu() -> Vector3:
	return _model.global_transform * Vector3(0, 0.3, 0)


# ------------------------------------------------------------------ świat

func _na_siatce(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)


func _sufit(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.4, p + Vector3.UP * 7.0, Balistyka.WARSTWA_SWIAT)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return (r["position"].y - 0.02) if not r.is_empty() else p.y + 2.7


func _zywy(n: Node) -> bool:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return false
	var c = n.get("cialo")
	return c != null and not c.martwy


func _ofiara_ok(n: Node) -> bool:
	if n == self or not _zywy(n):
		return false
	return n is Gracz or (n.get("frakcja") != null and String(n.get("frakcja")) != "fauna")


func _widzi(n: Node3D) -> bool:
	var od := punkt_celu()
	var cel := n.global_position + Vector3.UP * 1.0
	if od.distance_to(cel) > 18.0:
		return false
	var q := PhysicsRayQueryParameters3D.create(od, cel, Balistyka.WARSTWA_SWIAT)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _wybierz_ofiare() -> void:
	var best: Node3D = null
	var bd := INF
	for n in get_tree().get_nodes_in_group("gracz") + get_tree().get_nodes_in_group("wrogowie"):
		if not (n is Node3D) or not _ofiara_ok(n):
			continue
		var d := global_position.distance_to((n as Node3D).global_position)
		if n == gracz:
			d *= 0.7
		if d < bd and d < 18.0 and _widzi(n):
			bd = d
			best = n
	if best != null and best != gracz:
		gracz = best
		Dzwiek.graj_3d("mutant_klik", global_position, get_parent(), 2.0, randf_range(0.85, 1.05), 26.0)
	elif gracz != null and not _zywy(gracz):
		gracz = null


# ------------------------------------------------------------------ reakcje

func zabity_przez_gracza() -> bool:
	return is_instance_valid(ostatni_sprawca) and ostatni_sprawca is Gracz


func trafiony(czesc: String, obr: float, _pen: float, od_kogo: Node, punkt: Vector3, kier: Vector3) -> void:
	if cialo.martwy:
		return
	if od_kogo:
		ostatni_sprawca = od_kogo
	cialo.obrazenia(czesc, obr, "pocisk")
	Efekty.czastki(get_parent(), punkt, -kier, Color(0.32, 0.36, 0.12), 9, 1.8)
	Dzwiek.graj_3d("trafienie_cialo", punkt, get_parent(), -2.0)
	if cialo.martwy:
		return
	Dzwiek.graj_3d("mutant_wrzask", global_position, get_parent(), -2.0, randf_range(1.1, 1.3), 30.0)
	if od_kogo is Node3D and _ofiara_ok(od_kogo):
		gracz = od_kogo


func _halas(pos: Vector3, zasieg: float, zrodlo: Node) -> void:
	if cialo == null or cialo.martwy or zrodlo == self or (zrodlo != null and zrodlo.get("frakcja") == "fauna"):
		return
	if stan != "sufit" or gracz != null or global_position.distance_to(pos) > zasieg:
		return
	if Time.get_ticks_msec() / 1000.0 - _sluch_t < 1.0:
		return
	_sluch_t = Time.get_ticks_msec() / 1000.0
	if Balistyka.odleglosc_dzwieku(get_world_3d(), pos, _p) < zasieg * 0.7:
		_sluch_pos = pos
		_idz_sufitem(pos)
		_decyzja_t = 8.0


# ------------------------------------------------------------------ pętla

func _physics_process(delta: float) -> void:
	if cialo.martwy:
		return
	if _start:
		_na_start()
	cialo.tick(delta)
	if cialo.martwy:
		return
	_percepcja_t -= delta
	if _percepcja_t <= 0.0:
		_percepcja_t = 0.3
		_wybierz_ofiare()
	_dzwiek_t -= delta
	if _dzwiek_t <= 0.0:
		_dzwiek_t = randf_range(4.0, 9.0) if gracz == null else randf_range(1.5, 3.0)
		Dzwiek.graj_3d("mutant_klik", global_position, get_parent(), -3.0, randf_range(0.8, 1.15), 22.0)
	_atak_t -= delta
	var ruch := 0.0
	match stan:
		"sufit":
			ruch = _na_suficie(delta)
		"skok":
			_lot(delta)
			ruch = 1.0
		"ziemia":
			ruch = _na_ziemi(delta)
		"wspinaczka":
			ruch = _wspinaj(delta)
	_ustaw_orientacje(delta)
	_animuj(delta, ruch)


## Pod sufitem: pełznie po rzucie ścieżki z siatki nawigacji, wysokość z promienia w górę.
func _na_suficie(delta: float) -> float:
	_ucieczka_t -= delta
	var predk := 1.1
	if gracz != null and _zywy(gracz) and _ucieczka_t <= 0.0:
		predk = 3.4
		_decyzja_t -= delta
		if _decyzja_t <= 0.0:
			_decyzja_t = 0.5
			_idz_sufitem(gracz.global_position)
		var dh := Vector2(gracz.global_position.x - _p.x, gracz.global_position.z - _p.z).length()
		if dh < 3.4 and _atak_t <= 0.0 and _widzi(gracz):
			_zacznij_skok()
			return 1.0
	else:
		_decyzja_t -= delta
		if _decyzja_t <= 0.0 or _idx >= _sciezka.size():
			_decyzja_t = randf_range(5.0, 9.0)
			var cel := _p + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
			if _ucieczka_t > 0.0 and gracz != null:
				var od := (_p - gracz.global_position) * Vector3(1, 0, 1)
				cel = _p + od.normalized() * 10.0
				predk = 3.0
			_idz_sufitem(cel)
		if _ucieczka_t > 0.0:
			predk = 3.0
	var v := _krok_sciezki(predk, delta)
	_suf_y = lerpf(_suf_y, _sufit(_p), minf(1.0, delta * 6.0))
	global_position = Vector3(_p.x, _suf_y, _p.z)
	_normal = Vector3.DOWN
	return v


func _idz_sufitem(cel: Vector3) -> void:
	var mapa := get_world_3d().navigation_map
	_sciezka = NavigationServer3D.map_get_path(mapa, _p, _na_siatce(cel), true)
	_idx = 1


func _krok_sciezki(predk: float, delta: float) -> float:
	if _idx >= _sciezka.size():
		return 0.0
	var cel := _sciezka[_idx]
	var d := (cel - _p) * Vector3(1, 0, 1)
	if d.length() < 0.15:
		_idx += 1
		return predk
	var krok := minf(d.length(), predk * cialo.mnoznik_ruchu() * delta)
	_p += d.normalized() * krok
	_p.y = cel.y
	_kier = d.normalized()
	return predk


func _zacznij_skok() -> void:
	stan = "skok"
	var cel := gracz.global_position
	var od := (cel - _p) * Vector3(1, 0, 1)
	var lad := _na_siatce(cel - od.normalized() * 0.7)
	_skok = {"od": global_position, "do": lad, "t": 0.0, "czas": 0.5}
	_kier = od.normalized()
	Dzwiek.graj_3d("mutant_wrzask", global_position, get_parent(), 2.0, randf_range(0.9, 1.05), 34.0)
	_hp_ladowanie = cialo.procent()


func _lot(delta: float) -> void:
	_skok["t"] = float(_skok["t"]) + delta
	var f := clampf(float(_skok["t"]) / float(_skok["czas"]), 0.0, 1.0)
	var a: Vector3 = _skok["od"]
	var b: Vector3 = _skok["do"]
	var p := a.lerp(b, f)
	p.y = lerpf(a.y, b.y, f * f)
	global_position = p
	_normal = Vector3.DOWN.slerp(Vector3.UP, clampf(f * 1.6, 0.0, 1.0)) if f < 0.99 else Vector3.UP
	if _normal.length() < 0.1:
		_normal = Vector3.BACK
	_normal = _normal.normalized()
	if f >= 1.0:
		_p = b
		stan = "ziemia"
		_ziemia_t = randf_range(5.0, 8.0)
		_normal = Vector3.UP
		collision_layer = Balistyka.WARSTWA_POSTACIE
		collision_mask = Balistyka.WARSTWA_SWIAT
		Dzwiek.graj_3d("mutant_drap", global_position, get_parent(), 0.0)
		if gracz and _zywy(gracz) and global_position.distance_to(gracz.global_position) < 1.7:
			_atak(1.4)


## Na ziemi: szybki pościg po siatce nawigacji i ugryzienia; po chwili albo ranny – na ścianę.
func _na_ziemi(delta: float) -> float:
	_ziemia_t -= delta
	if gracz == null or not _zywy(gracz) or _ziemia_t <= 0.0 or cialo.procent() < _hp_ladowanie - 0.3 or cialo.procent() < 0.35:
		_zacznij_wspinaczke()
		return 0.0
	_agent.target_position = gracz.global_position
	var v := Vector3.ZERO
	var d := global_position.distance_to(gracz.global_position)
	if d < 1.35:
		if _atak_t <= 0.0:
			_atak(1.0)
		_kier = ((gracz.global_position - global_position) * Vector3(1, 0, 1)).normalized()
	elif not _agent.is_navigation_finished():
		var n := _agent.get_next_path_position() - global_position
		n.y = 0
		if n.length() > 0.05:
			v = n.normalized() * 5.2 * cialo.mnoznik_ruchu()
			_kier = n.normalized()
	velocity.x = move_toward(velocity.x, v.x, delta * 30.0)
	velocity.z = move_toward(velocity.z, v.z, delta * 30.0)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	_p = global_position
	return Vector2(velocity.x, velocity.z).length() / 5.2


func _atak(mnoznik: float) -> void:
	_atak_t = 0.85
	if _szczeka:
		var tw := _szczeka.create_tween()
		tw.tween_property(_szczeka, "rotation:x", 0.7, 0.07)
		tw.tween_property(_szczeka, "rotation:x", 0.0, 0.2)
	var czesc: String = ["nogi", "rece", "brzuch", "klatka"][randi() % 4]
	var obr := randf_range(11.0, 18.0) * mnoznik
	if gracz is Gracz:
		var g := gracz as Gracz
		g.set_meta("zabojca", nazwa_jednostki)
		g.cialo.obrazenia(czesc, obr, "fauna")
		if randf() < 0.55:
			g.cialo._krwawienie(czesc, 1 if randf() < 0.75 else 2)
		g.trafiony_sygnal.emit(global_position - g.global_position, czesc)
		if mnoznik > 1.2 and g.has_method("ogluszenie"):
			g.ogluszenie(0.35, "Pełzacz spadł ci na plecy!")
		Dzwiek.graj("ugryzienie", -2.0)
	elif gracz.has_method("trafiony"):
		var p := gracz.global_position + Vector3.UP * 1.0
		gracz.trafiony(czesc, obr, 0.0, self, p, (p - global_position).normalized())
		Dzwiek.graj_3d("ugryzienie", p, get_parent(), -2.0)


## Wspinaczka: do najbliższej ściany po ziemi, potem pionowo w górę (ciało brzuchem do ściany), dalej sufit.
func _zacznij_wspinaczke() -> void:
	var space := get_world_3d().direct_space_state
	var od := global_position + Vector3.UP * 2.0
	var best := {}
	var bd := INF
	for i in 8:
		var k := Vector3(cos(TAU * i / 8.0), 0, sin(TAU * i / 8.0))
		var q := PhysicsRayQueryParameters3D.create(od, od + k * 3.5, Balistyka.WARSTWA_SWIAT)
		var r := space.intersect_ray(q)
		if not r.is_empty():
			var d: float = od.distance_to(r["position"])
			if d < bd:
				bd = d
				best = r
	if best.is_empty():
		_ziemia_t = 2.0
		return
	var n: Vector3 = best["normal"]
	n.y = 0
	n = n.normalized()
	var u := _na_siatce(Vector3(best["position"].x, global_position.y, best["position"].z) + n * 0.4)
	stan = "wspinaczka"
	_wspin = {"faza": "dobieg", "punkt": u, "normal": n, "t": 0.0, "y0": u.y, "y1": _sufit(u)}
	_agent.target_position = u
	_ucieczka_t = randf_range(6.0, 10.0)


func _wspinaj(delta: float) -> float:
	if _wspin["faza"] == "dobieg":
		var u: Vector3 = _wspin["punkt"]
		var n := (u - global_position) * Vector3(1, 0, 1)
		if n.length() < 0.35:
			_wspin["faza"] = "gora"
			collision_layer = 0
			collision_mask = 0
			Dzwiek.graj_3d("mutant_drap", global_position, get_parent(), 0.0, 1.1)
			return 0.0
		var v := n.normalized() * 5.0
		_kier = n.normalized()
		velocity = Vector3(v.x, -0.5, v.z)
		move_and_slide()
		_wspin["t"] = float(_wspin["t"]) + delta
		if float(_wspin["t"]) > 3.0:
			_wspin["faza"] = "gora"
			collision_layer = 0
			collision_mask = 0
		return 1.0
	# pionowo po ścianie
	var nn: Vector3 = _wspin["normal"]
	_normal = nn
	_kier = Vector3.UP
	var y1: float = _wspin["y1"]
	global_position.y = move_toward(global_position.y, y1 - 0.05, delta * 3.2)
	if absf(global_position.y - y1) > 0.3:
		global_position += -nn * delta * 0.15
	if global_position.y >= y1 - 0.08:
		stan = "sufit"
		_p = _na_siatce(global_position * Vector3(1, 0, 1) + Vector3(0, _wspin["y0"], 0) + nn * 0.5)
		_suf_y = _sufit(_p)
		_normal = Vector3.DOWN
		_kier = nn
		_decyzja_t = 0.0
		_sciezka = PackedVector3Array()
	return 1.0


# ------------------------------------------------------------------ wygląd

## Ciało ustawione do powierzchni: oś Y modelu = normalna, przód = kierunek ruchu rzutowany na powierzchnię.
func _ustaw_orientacje(delta: float) -> void:
	var up := _normal.normalized()
	var f := _kier - up * _kier.dot(up)
	if f.length() < 0.05:
		f = -_model.global_basis.z - up * (-_model.global_basis.z).dot(up)
		if f.length() < 0.05:
			f = Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	f = f.normalized()
	var z := -f
	var x := up.cross(z).normalized()
	var cel := Basis(x, up, z).orthonormalized()
	var q0 := _model.global_basis.orthonormalized().get_rotation_quaternion()
	var q1 := cel.get_rotation_quaternion()
	_model.global_basis = Basis(q0.slerp(q1, minf(1.0, delta * 9.0)))


func _animuj(delta: float, ruch: float) -> void:
	_t += delta * (2.0 + ruch * 9.0)
	for k in _konczyny:
		var udo: Node3D = k[0]
		var golen: Node3D = k[1]
		var faza: float = k[2]
		udo.rotation.y = sin(_t + faza) * 0.45 * clampf(ruch, 0.15, 1.0)
		udo.rotation.z = cos(_t + faza) * 0.18 * clampf(ruch, 0.1, 1.0)
		golen.rotation.x = maxf(0.0, sin(_t + faza + 0.8)) * 0.4 * clampf(ruch, 0.0, 1.0)
	if _glowa:
		_glowa.rotation.y = sin(_t * 0.37) * 0.35
		_glowa.rotation.x = sin(_t * 0.23) * 0.2


func _smierc(_p2: String) -> void:
	stan = "martwy"
	collision_layer = 0
	collision_mask = 0
	for a in find_children("*", "Area3D", true, false):
		a.queue_free()
	Dzwiek.graj_3d("mutant_wrzask", global_position, get_parent(), 0.0, 0.7, 30.0)
	# spada ze ściany / sufitu na plecy
	var podl := _na_siatce(global_position)
	var cel_b := Basis(Vector3.FORWARD, PI * 0.9) * Basis.looking_at(_kier * Vector3(1, 0, 1) + Vector3(0.001, 0, 0), Vector3.UP)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "global_position", podl + Vector3.UP * 0.05, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_model, "global_basis", cel_b, 0.45)
	get_tree().call_group("ui_rajdu", "zabity_wrog", self)
	set_physics_process(false)
