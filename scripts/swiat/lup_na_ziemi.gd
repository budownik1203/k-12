class_name LupNaZiemi
extends Area3D
## Przedmiot leżący na ziemi (upuszczony magazynek, wyrzucony łup). Widoczny jako ikonka w świecie.

var przedmiot: Przedmiot


func _ready() -> void:
	collision_layer = Balistyka.WARSTWA_INTERAKCJE
	collision_mask = 0
	monitoring = false
	set_meta("interakcja", self)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.35, 0.2, 0.35)
	cs.shape = bs
	add_child(cs)
	var s := Sprite3D.new()
	s.texture = Dane.ikona(przedmiot.ikona_id())
	s.pixel_size = 0.0075
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.position.y = 0.12
	add_child(s)
	_na_podloge.call_deferred()


func _na_podloge() -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 4.0, Balistyka.WARSTWA_SWIAT)
	var r := space.intersect_ray(q)
	if not r.is_empty():
		global_position = r["position"] + Vector3.UP * 0.02


func tekst_interakcji(_g) -> String:
	return "Podnieś: " + przedmiot.nazwa()


func interakcja(g) -> void:
	if not g.akcja.is_empty() or _podnoszony:
		return
	# schylenie się i sięgnięcie po przedmiot (krótka czynność, przerywalna)
	_podnoszony = true
	g.zacznij_akcje("Podnoszenie: " + przedmiot.nazwa(), 0.75, func():
		_podnoszony = false
		if is_instance_valid(self) and g.ekw.dodaj(przedmiot):
			Dzwiek.graj("podnies", -6.0)
			queue_free()
		elif is_instance_valid(self):
			g.komunikat.emit("Brak miejsca w ekwipunku")
	, "podnies")
	get_tree().create_timer(1.2).timeout.connect(func(): _podnoszony = false)


var _podnoszony := false
