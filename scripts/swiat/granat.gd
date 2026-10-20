class_name Granat
extends RigidBody3D
## Rzucony granat: leci po łuku, odbija się (brzęk), toczy, po czasie zapalnika wybucha. Odłamki ranią
## w promieniu (słabiej za przeszkodą), fala wyważa pobliskie drzwi, ogłusza; wrogowie widzący granat
## uciekają z krzykiem „Granat!”.

var zapalnik := 3.6
var obrazenia := 130.0
var promien := 7.5
var rzucajacy: Node = null
var _t := 0.0
var _odbicia := 0
var _ostrzez_t := 0.0
var _ostatni_kontakt := 0.0
var ostrzega_od := 0.4      # po ilu sekundach wrogowie „widzą” granat (pułapka: później – szkło, łyżka, zanim zrozumieją)


static func rzuc(swiat: Node3D, skad: Vector3, predkosc: Vector3, kto: Node, defn: Dictionary = {}) -> Granat:
	var g := Granat.new()
	var gd: Dictionary = defn.get("granat", {})
	g.zapalnik = float(gd.get("zapalnik", 3.6)) + randf_range(-0.3, 0.4)
	g.obrazenia = float(gd.get("obrazenia", 130.0))
	g.promien = float(gd.get("promien", 7.5))
	g.rzucajacy = kto
	swiat.add_child(g)
	g.global_position = skad
	g.linear_velocity = predkosc
	g.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	return g


func _ready() -> void:
	collision_layer = 0
	collision_mask = Balistyka.WARSTWA_SWIAT
	mass = 0.6
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.32
	pm.friction = 0.8
	physics_material_override = pm
	linear_damp = 0.15
	angular_damp = 1.5
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.042
	cs.shape = sh
	add_child(cs)
	var m := ModelePrzedmiotow.wezel(Przedmiot.nowy("granat_f1"))
	var ab: AABB = m.get_meta("aabb", AABB())
	m.position = -Vector3(0, ab.size.y * 0.5, 0)
	add_child(m)
	body_entered.connect(_kontakt)


func _kontakt(_b: Node) -> void:
	if _t - _ostatni_kontakt < 0.12:
		return
	_ostatni_kontakt = _t
	var v := linear_velocity.length()
	if v > 1.2:
		_odbicia += 1
		Dzwiek.graj_3d("granat_odbicie", global_position, get_parent(), clampf(-16.0 + v * 1.5, -16.0, -4.0), randf_range(0.85, 1.15), 18.0)
		Gra.emituj_halas(global_position, 6.0, rzucajacy)


func _physics_process(delta: float) -> void:
	_t += delta
	_ostrzez_t -= delta
	if _ostrzez_t <= 0.0 and _t > ostrzega_od:
		_ostrzez_t = 0.3
		_ostrzez()
	if _t >= zapalnik:
		_wybuch()


## Wrogowie, którzy widzą granat obok siebie, uciekają.
func _ostrzez() -> void:
	for w in get_tree().get_nodes_in_group("wrogowie"):
		if is_instance_valid(w) and w.has_method("unik_granatu") and (w as Node3D).global_position.distance_to(global_position) < promien * 0.9:
			w.unik_granatu(global_position)


func _wybuch() -> void:
	set_physics_process(false)
	var p := global_position + Vector3.UP * 0.08
	var swiat := get_parent() as Node3D
	var space := get_world_3d().direct_space_state
	Dzwiek.graj_3d("wybuch", p, swiat, 6.0, randf_range(0.92, 1.05), 120.0)
	Gra.emituj_halas(p, 60.0, rzucajacy)
	Efekty.blysk(swiat, p, 12.0)
	Efekty.kurz(swiat, p, 3.0)
	Efekty.czastki(swiat, p, Vector3.UP, Color(0.35, 0.32, 0.28), 30, 6.0)
	Efekty.czastki(swiat, p, Vector3.UP, Color(1.0, 0.75, 0.35), 14, 9.0)
	Efekty.slad(swiat, p - Vector3.UP * 0.07, Vector3.UP, false)
	var sw := OmniLight3D.new()
	sw.light_color = Color(1.0, 0.75, 0.45)
	sw.light_energy = 9.0
	sw.omni_range = 9.0
	swiat.add_child(sw)
	sw.global_position = p + Vector3.UP * 0.4
	var tw := sw.create_tween()
	tw.tween_property(sw, "light_energy", 0.0, 0.25)
	tw.tween_callback(sw.queue_free)
	# odłamki i fala: gracz, ludzie, mutanty
	var cele: Array = get_tree().get_nodes_in_group("gracz") + get_tree().get_nodes_in_group("wrogowie")
	for c in cele:
		if not is_instance_valid(c) or not (c is Node3D):
			continue
		var ciala = c.get("cialo")
		if ciala == null or ciala.martwy:
			continue
		var srodek: Vector3 = (c as Node3D).global_position + Vector3.UP * (0.9 if c is Gracz or c is Wrog else 0.3)
		var d := p.distance_to(srodek)
		if d > promien * 1.6:
			continue
		var q := PhysicsRayQueryParameters3D.create(p, srodek, Balistyka.WARSTWA_SWIAT)
		q.exclude = [get_rid()]
		var zaslona := 0.2 if not space.intersect_ray(q).is_empty() else 1.0
		var sila := pow(clampf(1.0 - d / promien, 0.0, 1.0), 1.4) * zaslona
		if c is Gracz:
			# ogłuszenie i wstrząs nawet bez ran
			var oglusz := clampf(1.0 - d / (promien * 1.6), 0.0, 1.0) * zaslona
			Dzwiek.przytlum(2.5 + oglusz * 4.0, oglusz)
			if c.has_method("kopniecie"):
				c.kopniecie(8.0 * oglusz)
			if c.has_method("przygniec"):
				c.przygniec(oglusz * 3.0)
			if sila > 0.0:
				# kilka odłamków w losowe części ciała (z bliska więcej)
				for i in 4 + int(round(4.0 * clampf(1.0 - d / promien, 0.0, 1.0) * zaslona)):
					c.trafiony(srodek + Vector3(randf_range(-0.3, 0.3), randf_range(-0.6, 0.6), randf_range(-0.3, 0.3)), obrazenia * sila * 0.3, 3.0, rzucajacy if rzucajacy else self, true)
				c.set_meta("zabojca", "granat")
		elif c.has_method("trafiony") and sila > 0.0:
			var czesci := ["klatka", "brzuch", "nogi", "rece", "glowa"]
			# im bliżej, tym więcej odłamków (z bliska F-1 jest śmiertelny)
			for i in 4 + int(round(4.0 * clampf(1.0 - d / promien, 0.0, 1.0) * zaslona)):
				c.trafiony(czesci[randi() % (5 if randf() < 0.3 else 4)], obrazenia * sila * 0.3, 3.0, rzucajacy if rzucajacy else self, srodek, (srodek - p).normalized())
		if c is Wrog and c.has_method("przygniec") and not ciala.martwy:
			c.przygniec(2.0 * clampf(1.0 - d / (promien * 1.6), 0.0, 1.0), rzucajacy)
	# fala strąca szklanki z klamek i szarpie druty potykaczy w pobliżu (wybuch łańcuchowy)
	for pu in get_tree().get_nodes_in_group("pulapki"):
		if is_instance_valid(pu) and (pu as Node3D).global_position.distance_to(p) < 6.0 and randf() < 1.0 - (pu as Node3D).global_position.distance_to(p) / 6.0:
			pu.spust()
	for po in get_tree().get_nodes_in_group("potykacze"):
		if is_instance_valid(po) and ((po.a + po.b) * 0.5).distance_to(p) < 4.0 and randf() < 0.7:
			po.spust()
	# fala wyważa bliskie zamknięte drzwi
	for dr in get_tree().get_nodes_in_group("drzwi"):
		if is_instance_valid(dr) and (dr as Node3D).global_position.distance_to(p) < 3.2 and not dr.wywazone:
			dr._wywaz(rzucajacy)
	queue_free()
