class_name LupNaZiemi
extends Area3D
## Przedmiot leżący na ziemi (upuszczony magazynek, wyrzucony łup): model 3D przedmiotu z cieniem,
## leży płasko pod losowym kątem. Wyrzucony z ręki leci łukiem i upada z dźwiękiem zależnym od wagi.

var przedmiot: Przedmiot
var rzut_z: Variant = null       # Vector3: skąd leci (dłoń); null = kładziony od razu na ziemi
var _model: Node3D
var _podnoszony := false


func _ready() -> void:
	collision_layer = Balistyka.WARSTWA_INTERAKCJE
	collision_mask = 0
	monitoring = false
	set_meta("interakcja", self)
	_model = ModelePrzedmiotow.wezel(przedmiot)
	_model.rotation.y = randf() * TAU
	add_child(_model)
	var ab: AABB = _model.get_meta("aabb", AABB(Vector3(-0.1, 0, -0.1), Vector3(0.2, 0.1, 0.2)))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# pole chwytu nieco większe od przedmiotu (drobiazgi łatwo przeoczyć, ale da się w nie wycelować)
	var r := maxf(maxf(ab.size.x, ab.size.z), 0.16)
	bs.size = Vector3(r, maxf(ab.size.y, 0.1) + 0.04, r)
	cs.shape = bs
	cs.position.y = bs.size.y * 0.5
	add_child(cs)
	_na_podloge.call_deferred()


func _na_podloge() -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 4.0, Balistyka.WARSTWA_SWIAT)
	var r := space.intersect_ray(q)
	var cel := global_position
	if not r.is_empty():
		cel = r["position"] + Vector3.UP * 0.004
	if rzut_z == null:
		global_position = cel
		return
	# lot z dłoni: łuk do miejsca upadku, obrót w powietrzu, odbicie
	var start: Vector3 = rzut_z
	global_position = start
	var rot0 := _model.rotation
	_model.rotation += Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
	var czas := clampf(sqrt(maxf(0.05, start.y - cel.y) / 4.9), 0.18, 0.5)
	var tw := create_tween()
	tw.tween_method(func(f: float):
		var p := start.lerp(cel, f)
		p.y += sin(f * PI) * 0.12
		global_position = p, 0.0, 1.0, czas)
	tw.parallel().tween_property(_model, "rotation", rot0, czas)
	tw.tween_callback(_upadek)
	# odbicie przedmiotów twardych i lekkich
	if przedmiot.waga() < 2.0 and przedmiot.typ() not in ["pojemnik", "pancerz", "med"]:
		tw.tween_property(self, "global_position", cel + Vector3.UP * 0.03, 0.07).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "global_position", cel, 0.08).set_ease(Tween.EASE_IN)


func _upadek() -> void:
	var w := przedmiot.waga()
	var miekki := przedmiot.typ() in ["pojemnik", "pancerz", "med"]
	var dz := "upadek_miekki" if miekki else "upadek_metal"
	var wys := clampf(1.3 - w * 0.08, 0.6, 1.4)
	Dzwiek.graj_3d(dz, global_position, get_parent(), clampf(-14.0 + w * 2.0, -14.0, -2.0), wys, 14.0)
	# hałas słyszalny dla wrogów (cięższe dalej)
	Gra.emituj_halas(global_position, clampf(4.0 + w * 1.5, 4.0, 14.0), get_tree().get_first_node_in_group("gracz"))


func _do_zalozenia(g) -> String:
	# porzucony plecak / kamizelka / pancerz: od razu na plecy, jeśli slot wolny
	var sl := Ekwipunek.slot_dla(przedmiot)
	if sl in ["plecak", "kamizelka", "pancerz", "helm"] and g.ekw.sloty.get(sl) == null:
		return sl
	return ""


func tekst_interakcji(g) -> String:
	if _do_zalozenia(g) != "":
		return "Załóż: " + przedmiot.nazwa()
	return "Podnieś: " + przedmiot.nazwa()


func interakcja(g) -> void:
	if not g.akcja.is_empty() or _podnoszony:
		return
	# schylenie się i sięgnięcie po przedmiot (krótka czynność, przerywalna); cięższe dłużej
	_podnoszony = true
	var sl := _do_zalozenia(g)
	if sl != "":
		var cz: float = {"plecak": 1.8, "kamizelka": 2.2, "pancerz": 4.0, "helm": 1.2}[sl]
		g.zacznij_akcje("Zakładanie: " + przedmiot.nazwa(), cz, func():
			_podnoszony = false
			if is_instance_valid(self) and g.ekw.zaloz(sl, przedmiot):
				Dzwiek.graj("plecak", -6.0)
				queue_free()
			, "podnies")
		get_tree().create_timer(cz + 0.5).timeout.connect(func(): _podnoszony = false)
		return
	var czas := clampf(0.6 + przedmiot.waga() * 0.06, 0.6, 1.4)
	g.zacznij_akcje("Podnoszenie: " + przedmiot.nazwa(), czas, func():
		_podnoszony = false
		if is_instance_valid(self) and g.ekw.dodaj(przedmiot):
			Dzwiek.graj("podnies", -6.0)
			queue_free()
		elif is_instance_valid(self):
			g.komunikat.emit("Brak miejsca w ekwipunku")
		, "podnies")
	get_tree().create_timer(czas + 0.5).timeout.connect(func(): _podnoszony = false)
