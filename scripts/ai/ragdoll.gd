class_name Ragdoll
extends Node3D
## Bezwładne ciało po śmierci: części modelu postaci (miednica, tułów, głowa, ramiona, przedramiona, uda,
## podudzia) stają się bryłami sztywnymi połączonymi przegubami – stożkowymi w barkach, biodrach, szyi
## i kręgosłupie, zawiasami (z ograniczeniem) w łokciach i kolanach. Upada zgodnie z kierunkiem trafienia.
## Po ułożeniu się ciało zamarza (bez kosztu fizyki). Każda część jest polem interakcji zwłok – ciało
## przeszukuje się z dowolnego miejsca, nie tylko tam, gdzie stał.

const MASY := {"biodra": 11.0, "tulow": 16.0, "glowa": 4.5, "ramie_l": 2.4, "ramie_p": 2.4, "lokiec_l": 1.8, "lokiec_p": 1.8,
	"noga_l": 7.0, "noga_p": 7.0, "kolano_l": 4.0, "kolano_p": 4.0}
const RODZICE := {"tulow": "biodra", "glowa": "tulow", "ramie_l": "tulow", "ramie_p": "tulow", "lokiec_l": "ramie_l",
	"lokiec_p": "ramie_p", "noga_l": "biodra", "noga_p": "biodra", "kolano_l": "noga_l", "kolano_p": "noga_p"}

var bryly := {}            # nazwa części -> RigidBody3D
var pojemnik: Node3D = null
var _t := 0.0
var _spokoj := 0.0
var zamrozony := false


## Buduje ragdoll z części postaci (słownik nazwa -> Node3D). Części przenoszone są do brył w świecie.
static func z_postaci(swiat: Node3D, czesci: Dictionary, predkosc: Vector3, kier_trafienia: Vector3) -> Ragdoll:
	var rd := Ragdoll.new()
	rd.name = "Ragdoll"
	swiat.add_child(rd)
	# węzły części i broń zostają na miejscu – przenoszone są tylko ich siatki
	var pomin := []
	for k in MASY.keys() + ["bron"]:
		if czesci.has(k):
			pomin.append(czesci[k])
	# najpierw pozycje stawów (przed przenoszeniem siatek)
	var xf := {}
	for n in MASY:
		if czesci.has(n) and is_instance_valid(czesci[n]):
			xf[n] = (czesci[n] as Node3D).global_transform
	for n in xf:
		var cz: Node3D = czesci[n]
		var b := RigidBody3D.new()
		b.name = "R_" + n
		b.mass = MASY[n]
		b.collision_layer = Balistyka.WARSTWA_INTERAKCJE
		b.collision_mask = Balistyka.WARSTWA_SWIAT
		b.linear_damp = 0.25
		b.angular_damp = 1.2
		b.continuous_cd = n in ["tulow", "biodra", "glowa"]
		var pm := PhysicsMaterial.new()
		pm.friction = 0.9
		pm.bounce = 0.02
		b.physics_material_override = pm
		rd.add_child(b)
		var t: Transform3D = xf[n]
		b.global_transform = Transform3D(t.basis.orthonormalized(), t.origin)
		# siatki części (bez dzieci-części i broni) przechodzą do bryły
		for c in cz.get_children():
			if c in pomin or c is Area3D:
				continue
			(c as Node).reparent(b, true)
		# kształt kolizji z obrysu siatek
		var ab := AABB()
		var jest := false
		var inv := b.global_transform.affine_inverse()
		for mi in b.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			var a := (inv * m.global_transform) * m.get_aabb()
			ab = a if not jest else ab.merge(a)
			jest = true
		if not jest:
			ab = AABB(Vector3(-0.05, -0.1, -0.05), Vector3(0.1, 0.2, 0.1))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(maxf(0.06, ab.size.x * 0.88), maxf(0.06, ab.size.y * 0.92), maxf(0.06, ab.size.z * 0.88))
		cs.shape = bs
		cs.position = ab.get_center()
		b.add_child(cs)
		b.linear_velocity = predkosc
		rd.bryly[n] = b
	# przeguby
	for n in RODZICE:
		if not rd.bryly.has(n) or not rd.bryly.has(RODZICE[n]):
			continue
		var a: RigidBody3D = rd.bryly[RODZICE[n]]
		var b: RigidBody3D = rd.bryly[n]
		var t: Transform3D = xf[n]
		var x := t.basis.x.normalized()
		var y := t.basis.y.normalized()
		var z := t.basis.z.normalized()
		var j: Joint3D
		if n.begins_with("lokiec") or n.begins_with("kolano"):
			# zawias wokół osi X części (oś zawiasu = Z przegubu); zgięcie tylko w naturalną stronę
			var h := HingeJoint3D.new()
			h.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
			h.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(-135.0))
			h.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(4.0))
			h.set_param(HingeJoint3D.PARAM_LIMIT_SOFTNESS, 0.6)
			rd.add_child(h)
			h.global_transform = Transform3D(Basis(-z, y, x), t.origin)
			j = h
		else:
			var c := ConeTwistJoint3D.new()
			var tulowie: bool = n in ["tulow", "glowa"]
			c.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(30.0 if n == "tulow" else (45.0 if n == "glowa" else 70.0)))
			c.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(20.0 if tulowie else 35.0))
			c.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, 0.8)
			rd.add_child(c)
			# oś skrętu (X przegubu) wzdłuż kości: kończyny w dół, kręgosłup i szyja w górę
			var bz := Basis(y, z, x) if tulowie else Basis(-y, x, z)
			c.global_transform = Transform3D(bz, t.origin)
			j = c
		if OS.get_cmdline_user_args().has("--bez_przegubow"):
			j.queue_free()
			continue
		j.node_a = j.get_path_to(a)
		j.node_b = j.get_path_to(b)
	# pchnięcie od pocisku: tułów i głowa dostają impuls w kierunku lotu kuli
	var imp := kier_trafienia
	imp.y = maxf(imp.y, 0.0)
	if imp.length() > 0.01:
		imp = imp.normalized()
		# prędkość zamiast impulsu (impuls przed pierwszym krokiem fizyki liczy się z masą 1)
		for k in ["tulow", "glowa", "biodra"]:
			if rd.bryly.has(k):
				var rb := rd.bryly[k] as RigidBody3D
				rb.linear_velocity += imp * {"tulow": 1.7, "glowa": 2.2, "biodra": 0.5}[k]
		if rd.bryly.has("tulow"):
			(rd.bryly["tulow"] as RigidBody3D).angular_velocity = imp.cross(Vector3.UP) * -2.2
	return rd


func _physics_process(delta: float) -> void:
	if zamrozony:
		return
	if ciagnie_do != Vector3.INF and bryly.has("tulow"):
		# kołnierz w dłoni: tułów (górą) ciągnięty do punktu za graczem, nogi wloką się po podłodze
		var t: RigidBody3D = bryly["tulow"]
		var d := ciagnie_do - t.global_position
		var v := (d * 6.0).limit_length(1.8)
		# całe ciało sunie za tułowiem (inaczej nogi tarciem kotwiczą je w miejscu); kończyny lżej
		for k in bryly:
			var rb: RigidBody3D = bryly[k]
			var w := 1.0 if k in ["tulow", "biodra", "glowa"] else 0.75
			rb.linear_velocity = rb.linear_velocity.lerp(Vector3(v.x, minf(v.y, 0.5) if k == "tulow" else rb.linear_velocity.y, v.z) * w, 0.5)
		if pojemnik and is_instance_valid(pojemnik):
			pojemnik.global_position = t.global_position
		return
	_t += delta
	var ruch := 0.0
	for b in bryly.values():
		ruch = maxf(ruch, (b as RigidBody3D).linear_velocity.length())
	_spokoj = _spokoj + delta if ruch < 0.08 else 0.0
	if (_spokoj > 0.6 and _t > 1.2) or _t > 6.0:
		zamroz()


## Ciało leży: bryły zamarzają (statyczne), pole przeszukiwania wędruje na tułów.
func zamroz() -> void:
	zamrozony = true
	for b in bryly.values():
		var rb := b as RigidBody3D
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		rb.freeze = true
	if pojemnik and is_instance_valid(pojemnik) and bryly.has("tulow"):
		pojemnik.global_position = (bryly["tulow"] as Node3D).global_position
	set_physics_process(false)


## Środek ciała (tułów) – tam patrzy się przy przeszukiwaniu.
func srodek() -> Vector3:
	if bryly.has("tulow"):
		return (bryly["tulow"] as Node3D).global_position
	return global_position


## Ciągnięcie za kołnierz: ciało odmarza, tułów idzie za dłonią gracza (reszta ciągnie się na przegubach).
var ciagnie_do := Vector3.INF


func ciagnij(cel: Vector3) -> void:
	if zamrozony:
		zamrozony = false
		for b in bryly.values():
			(b as RigidBody3D).freeze = false
		set_physics_process(true)
	if ciagnie_do == Vector3.INF:
		for b in bryly.values():
			((b as RigidBody3D).physics_material_override as PhysicsMaterial).friction = 0.3
	ciagnie_do = cel
	_t = 0.0
	_spokoj = 0.0


func pusc() -> void:
	for b in bryly.values():
		((b as RigidBody3D).physics_material_override as PhysicsMaterial).friction = 0.9
	ciagnie_do = Vector3.INF
	_t = 0.0
	_spokoj = 0.0


## Pola interakcji: każda bryła prowadzi do zwłok.
func ustaw_pojemnik(pj: Node3D) -> void:
	pojemnik = pj
	pj.set_meta("ragdoll", self)
	for b in bryly.values():
		(b as Node).set_meta("interakcja", pj)
