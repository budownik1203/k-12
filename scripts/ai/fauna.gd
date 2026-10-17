class_name Fauna
extends CharacterBody3D
## Zmutowana fauna: zdziczałe psy strefy. Reagują na hałas i krew, atakują z bliska, uciekają ranne.

var nazwa_jednostki := "Zdziczały pies"
var frakcja := "fauna"
var oddzial = null
var cialo: Cialo
var stan := "wedrowka"     # wedrowka | poscig | ucieczka | martwy
var gracz: Gracz
var cel := Vector3.ZERO
var _agent: NavigationAgent3D
var _model: Node3D
var _nogi: Array = []
var _glowa: Node3D
var _t := 0.0
var _atak_t := 0.0
var _decyzja_t := 0.0
var _warkot_t := 0.0


func _init() -> void:
	collision_layer = Balistyka.WARSTWA_POSTACIE
	collision_mask = Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_POSTACIE


func _ready() -> void:
	add_to_group("wrogowie")
	cialo = Cialo.new({"glowa": 20.0, "klatka": 45.0, "brzuch": 35.0, "rece": 30.0, "nogi": 35.0})
	cialo.smierc.connect(_smierc)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 0.7
	cs.shape = cap
	cs.position.y = 0.35
	add_child(cs)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 0.8
	_agent.radius = 0.3
	add_child(_agent)
	_buduj()
	Gra.halas.connect(_halas)
	_decyzja_t = randf_range(1, 4)


func _buduj() -> void:
	var siersc := Color(0.28, 0.24, 0.2)
	var lysa := Color(0.48, 0.32, 0.3)   # łyse, zniekształcone płaty skóry
	_model = Node3D.new()
	add_child(_model)
	_model.add_child(Kit.instancja([
		[Vector3(0, 0.5, 0), Vector3(0.3, 0.28, 0.75), siersc],
		[Vector3(0.05, 0.56, 0.1), Vector3(0.2, 0.18, 0.3), lysa],
		[Vector3(0, 0.58, 0.42), Vector3(0.06, 0.06, 0.3), siersc, Vector3(-30, 0, 0)],
	]))
	_glowa = Node3D.new()
	_glowa.position = Vector3(0, 0.6, -0.42)
	_model.add_child(_glowa)
	_glowa.add_child(Kit.instancja([
		[Vector3(0, 0.02, -0.08), Vector3(0.22, 0.2, 0.22), siersc],
		[Vector3(0, -0.04, -0.24), Vector3(0.14, 0.11, 0.18), lysa],
		[Vector3(0, -0.1, -0.24), Vector3(0.12, 0.03, 0.16), Color(0.7, 0.66, 0.55)],  # zęby
		[Vector3(-0.07, 0.15, -0.02), Vector3(0.05, 0.1, 0.04), siersc], [Vector3(0.07, 0.15, -0.02), Vector3(0.05, 0.1, 0.04), siersc],
		[Vector3(-0.06, 0.06, -0.19), Vector3(0.03, 0.02, 0.01), Color(0.9, 0.7, 0.2)], [Vector3(0.06, 0.06, -0.19), Vector3(0.03, 0.02, 0.01), Color(0.9, 0.7, 0.2)],
	]))
	for p in [Vector3(-0.1, 0.4, -0.28), Vector3(0.1, 0.4, -0.28), Vector3(-0.1, 0.4, 0.28), Vector3(0.1, 0.4, 0.28)]:
		var n := Node3D.new()
		n.position = p
		_model.add_child(n)
		n.add_child(Kit.instancja([[Vector3(0, -0.2, 0), Vector3(0.08, 0.4, 0.08), siersc]]))
		_nogi.append(n)
	_hitbox(_glowa, "glowa", Vector3(0, 0, -0.12), Vector3(0.24, 0.24, 0.36))
	_hitbox(_model, "klatka", Vector3(0, 0.5, -0.12), Vector3(0.32, 0.3, 0.4))
	_hitbox(_model, "brzuch", Vector3(0, 0.5, 0.22), Vector3(0.32, 0.3, 0.34))
	_hitbox(_model, "nogi", Vector3(0, 0.2, 0), Vector3(0.28, 0.4, 0.7))


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


func trafiony(czesc: String, obr: float, _pen: float, od_kogo: Node, punkt: Vector3, kier: Vector3) -> void:
	if cialo.martwy:
		return
	cialo.obrazenia(czesc, obr, "pocisk")
	Efekty.czastki(get_parent(), punkt, -kier, Color(0.45, 0.04, 0.03), 8, 1.6)
	Dzwiek.graj_3d("trafienie_cialo", punkt, get_parent(), -2.0)
	if cialo.martwy:
		return
	if od_kogo is Gracz:
		gracz = od_kogo
	if cialo.procent() < 0.4 and randf() < 0.6:
		stan = "ucieczka"
		_decyzja_t = 0.0
	else:
		stan = "poscig"


func _halas(pos: Vector3, zasieg: float, zrodlo: Node) -> void:
	if cialo == null or cialo.martwy or not (zrodlo is Gracz):
		return
	if global_position.distance_to(pos) < zasieg * 1.2 and stan == "wedrowka":
		gracz = zrodlo
		cel = pos
		_decyzja_t = 6.0
		_agent.target_position = pos


func _physics_process(delta: float) -> void:
	if cialo.martwy:
		return
	cialo.tick(delta)
	if cialo.martwy:
		return
	if gracz == null:
		gracz = get_tree().get_first_node_in_group("gracz") as Gracz
	var v := Vector3.ZERO
	var szybko := false
	match stan:
		"wedrowka":
			_decyzja_t -= delta
			if _decyzja_t <= 0.0:
				_decyzja_t = randf_range(3.0, 7.0)
				var p := global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
				_agent.target_position = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)
			if gracz and not gracz.cialo.martwy and _widzi_gracza():
				stan = "poscig"
				Dzwiek.graj_3d("warkot", global_position, get_parent(), 0.0, 1.0, 30.0)
		"poscig":
			szybko = true
			if gracz == null or gracz.cialo.martwy:
				stan = "wedrowka"
			else:
				_agent.target_position = gracz.global_position
				var d := global_position.distance_to(gracz.global_position)
				_atak_t -= delta
				if d < 1.5 and _atak_t <= 0.0:
					_atak_t = 1.0
					_ugryz()
				_warkot_t -= delta
				if _warkot_t <= 0.0:
					_warkot_t = randf_range(2.0, 4.0)
					Dzwiek.graj_3d("warkot", global_position, get_parent(), -2.0, randf_range(0.9, 1.1), 30.0)
		"ucieczka":
			szybko = true
			_decyzja_t -= delta
			if _decyzja_t <= 0.0 and gracz:
				_decyzja_t = 3.0
				var od := global_position - gracz.global_position
				od.y = 0
				_agent.target_position = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, global_position + od.normalized() * 10.0)
	if not _agent.is_navigation_finished():
		var n := _agent.get_next_path_position() - global_position
		n.y = 0
		if n.length() > 0.05:
			v = n.normalized() * (6.2 if szybko else 1.5) * cialo.mnoznik_ruchu()
			rotation.y = lerp_angle(rotation.y, atan2(-n.x, -n.z), minf(1.0, delta * 8.0))
	velocity.x = move_toward(velocity.x, v.x, delta * 20.0)
	velocity.z = move_toward(velocity.z, v.z, delta * 20.0)
	velocity.y = -0.3 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	var pv := Vector2(velocity.x, velocity.z).length()
	_t += delta * pv * 3.5
	for i in _nogi.size():
		(_nogi[i] as Node3D).rotation.x = sin(_t + (PI if i % 3 == 0 else 0.0)) * clampf(pv / 5.0, 0.0, 1.0) * 0.8


func _widzi_gracza() -> bool:
	var d := global_position.distance_to(gracz.global_position)
	if d > 16.0:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6, gracz.global_position + Vector3.UP * 1.0, Balistyka.WARSTWA_SWIAT)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _ugryz() -> void:
	var czesc: String = ["nogi", "nogi", "rece", "brzuch"][randi() % 4]
	var p: Vector3 = gracz.global_position + Vector3.UP * float({"nogi": 0.4, "rece": 1.2, "brzuch": 1.0}[czesc])
	gracz.set_meta("zabojca", nazwa_jednostki)
	gracz.cialo.obrazenia(czesc, randf_range(10.0, 17.0), "fauna")
	if randf() < 0.45:
		gracz.cialo._krwawienie(czesc, 1)
	gracz.trafiony_sygnal.emit(global_position - gracz.global_position, czesc)
	Dzwiek.graj("ugryzienie", -2.0)


func _smierc(_p: String) -> void:
	stan = "martwy"
	collision_layer = 0
	for a in find_children("*", "Area3D", true, false):
		a.queue_free()
	var t := create_tween()
	t.tween_property(_model, "rotation:z", deg_to_rad(85), 0.35)
	t.parallel().tween_property(_model, "position:y", -0.2, 0.35)
	get_tree().call_group("ui_rajdu", "zabity_wrog", self)
	set_physics_process(false)
