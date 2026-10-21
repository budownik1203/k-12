class_name Potykacz
extends Node3D
## Potykacz: granat F-1 przywiązany do kołka wbitego przy ścianie, drut napięty w poprzek korytarza na wysokości
## kostek, zawleczka przywiązana do drutu. Kto zahaczy nogą (gracz, każdy człowiek, mutant) – zawleczka wyskakuje,
## łyżka odskakuje, po ok. 2,5 s wybuch. Drut jest cienki i ciemny: w świetle latarki skrzy się na chwilę
## (widać go, kiedy się patrzy pod nogi). Zastawiający może go zdjąć [F] przy kołku z granatem.

var a: Vector3                   # koniec z granatem (kołek)
var b: Vector3                   # drugi kołek
var wlasciciel: Node
var _spuszczony := false
var _mat_drut: StandardMaterial3D
var _t := 0.0
var _zauwazyli := {}             # wróg -> zauważył? (sprawdzane raz przy podejściu)
var _rozbraja: Node = null       # wróg, który właśnie rozbraja

const WYS := 0.11


static func rozciagnij(swiat: Node3D, a_: Vector3, b_: Vector3, kto: Node) -> Potykacz:
	var p := Potykacz.new()
	p.a = a_
	p.b = b_
	p.wlasciciel = kto
	p.add_to_group("potykacze")
	swiat.add_child(p)
	return p


func _ready() -> void:
	global_position = a
	var B := preload("res://scripts/core/bryly.gd")
	_mat_drut = StandardMaterial3D.new()
	_mat_drut.albedo_color = Color(0.16, 0.16, 0.15)
	_mat_drut.metallic = 0.8
	_mat_drut.roughness = 0.35
	_mat_drut.emission_enabled = true
	_mat_drut.emission = Color(0.9, 0.9, 0.85)
	_mat_drut.emission_energy_multiplier = 0.0
	var drut := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0018
	cyl.bottom_radius = 0.0018
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 4
	cyl.material = _mat_drut
	drut.mesh = cyl
	drut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drut)
	var srodek := (a + b) * 0.5 + Vector3.UP * WYS
	drut.global_position = srodek
	var kier := (b - a).normalized()
	drut.global_basis = Basis(Quaternion(Vector3.UP, kier))
	# kołki i granat przy pierwszym
	for k in [a, b]:
		var kol := B.instancja([B.walec(Vector3(0, 0, 0), Vector3(0, 0.16, 0), 0.008, 0.005, "drewno", 6)], false)
		add_child(kol)
		kol.global_position = k
	var gr := ModelePrzedmiotow.wezel(Przedmiot.nowy("granat_f1"))
	add_child(gr)
	gr.global_position = a + Vector3.UP * 0.07 - kier * 0.03
	# punkt interakcji (zdjęcie) przy kołku z granatem
	var ob := StaticBody3D.new()
	ob.collision_layer = Balistyka.WARSTWA_INTERAKCJE
	ob.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sf := SphereShape3D.new()
	sf.radius = 0.16
	cs.shape = sf
	ob.add_child(cs)
	ob.set_meta("interakcja", self)
	add_child(ob)
	ob.global_position = a + Vector3.UP * 0.1


func tekst_interakcji(_g) -> String:
	return "Zdejmij potykacz (granat z drutem)"


func interakcja(g) -> void:
	if _spuszczony or g == null:
		return
	var ciemno := Pulapka.swiatlo(self, a + Vector3.UP * 0.1) < 0.3
	if ciemno:
		g.komunikat.emit("Po ciemku – zawleczkę trzeba znaleźć palcami. Poświeć latarką, będzie pewniej.")
	g.zacznij_akcje("Zdejmowanie potykacza" + (" (po ciemku)" if ciemno else ""), 4.0 * (1.8 if ciemno else 1.0), func():
		if _spuszczony:
			return
		if ciemno and randf() < 0.12:
			g.komunikat.emit("Drut szarpnął – zawleczka wyskoczyła!")
			spust()
			return
		_spuszczony = true
		for pid in ["granat_f1", "drut"]:
			var pz := Przedmiot.nowy(pid)
			if not g.ekw.dodaj(pz):
				var l := LupNaZiemi.new()
				l.przedmiot = pz
				get_parent().add_child(l)
				l.global_position = a + Vector3.UP * 0.1
		Dzwiek.graj_3d("zawleczka", a, get_parent(), -10.0)
		g.komunikat.emit("Potykacz zdjęty: zawleczka z powrotem, drut zwinięty.")
		queue_free(), "otwieranie", 0, Callable(), {"id": "drzwi"})


## Odległość postaci od drutu (w poziomie), gdy stopy są na wysokości drutu.
func _odl(p: Vector3) -> float:
	# stopy nad drutem (skok) albo na innej kondygnacji – nie zahaczą
	if p.y - a.y > 0.22 or a.y - p.y > 0.6:
		return 99.0
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var p2 := Vector2(p.x, p.z)
	var ab := b2 - a2
	var t := clampf((p2 - a2).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a2 + ab * t).distance_to(p2)


func _physics_process(delta: float) -> void:
	if _spuszczony:
		return
	_t -= delta
	# błysk drutu w świetle latarki gracza (patrzy w tę stronę, z bliska)
	var g := get_tree().get_first_node_in_group("gracz") as Node3D
	var blysk := 0.0
	if g and g.get("latarka") and g.latarka.visible:
		var srodek := (a + b) * 0.5 + Vector3.UP * WYS
		var d: Vector3 = srodek - g.latarka.global_position
		var kat: float = (-g.latarka.global_basis.z).dot(d.normalized())
		if d.length() < 7.0 and kat > 0.82:
			blysk = clampf((kat - 0.82) / 0.18, 0.0, 1.0) * (1.0 - d.length() / 7.0) * (0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02))
	_mat_drut.emission_energy_multiplier = blysk * 1.6
	if _t > 0.0:
		return
	_t = 0.08
	if _rozbraja != null and (not is_instance_valid(_rozbraja) or str(_rozbraja.get("stan")) != "szaber"):
		_rozbraja = null          # przerwał (walka, śmierć) – drut znowu groźny także dla niego
	for c in get_tree().get_nodes_in_group("gracz") + get_tree().get_nodes_in_group("wrogowie"):
		if not is_instance_valid(c) or c == _rozbraja:
			continue
		var cialo = c.get("cialo")
		if cialo != null and cialo.martwy:
			continue
		var cp: Vector3 = (c as Node3D).global_position
		var d := _odl(cp)
		if c is Wrog and not c.is_in_group("fauna") and d < 2.6 and not _zauwazyli.has(c):
			_zauwazyli[c] = randf() < Pulapka.szansa_zauwazenia(c, (a + b) * 0.5 + Vector3.UP * WYS, 0.0)
			if _zauwazyli[c]:
				_rozbraja = c
				c.rozbroj_pulapke(self)
				continue
		if d < 0.22:
			spust()
			return


## Zawleczka wyskakuje z granatu (drut zahaczony).
func spust() -> void:
	if _spuszczony:
		return
	_spuszczony = true
	var swiat := get_parent() as Node3D
	Dzwiek.graj_3d("lyzka", a, swiat, -2.0, 1.05, 16.0)
	Gra.emituj_halas(a, 6.0, wlasciciel)
	var g := Granat.rzuc(swiat, a + Vector3.UP * 0.08, Vector3.ZERO, wlasciciel, Dane.def("granat_f1"))
	g.zapalnik = randf_range(2.3, 2.8)
	g.ostrzega_od = 1.3
	queue_free()


## Wróg skończył rozbrajanie: granat i drut idą do jego łupu.
func rozbrojony_przez(w) -> void:
	if _spuszczony:
		return
	_spuszczony = true
	w.lup.append(Przedmiot.nowy("granat_f1"))
	w.lup.append(Przedmiot.nowy("drut"))
	queue_free()


func punkt_rozbrajania() -> Vector3:
	return a
