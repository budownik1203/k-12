class_name Wylacznik
extends Node3D
## Wyłącznik światła przy wejściu do pomieszczenia: gasi i zapala lampy w tym pokoju. Ciemny pokój to zasadzka
## (wrogowie gorzej widzą), ale zgaszone światło jest podejrzane: wróg, który wejdzie do pokoju, który pamiętał
## jako jasny, robi się czujny i po chwili zapala.

var lampy: Array = []          # OmniLight3D z migotanie.gd
var obszar := Rect2()          # rzut pomieszczenia (x, z)
var wys := 0.0                 # poziom podłogi
var _zgasil_gracz := false
var _t := 0.0
var _wrog_idzie: Node = null


func tekst_interakcji(_g) -> String:
	return "Zgaś światło" if wlaczone() else "Zapal światło"


func wlaczone() -> bool:
	for l in lampy:
		if is_instance_valid(l) and not bool(l.get("wylaczona")):
			return true
	return false


func przelacz(kto: Node) -> void:
	var zgas := wlaczone()
	for l in lampy:
		if is_instance_valid(l):
			l.set("wylaczona", zgas)
	_zgasil_gracz = zgas and kto is Gracz
	Dzwiek.graj_3d("klik", global_position, get_parent(), -6.0, 0.55, 10.0)
	Gra.emituj_halas(global_position, 2.0, kto)


func interakcja(g) -> void:
	przelacz(g)


func _ready() -> void:
	var B := preload("res://scripts/core/bryly.gd")
	add_child(B.instancja([B.box(Vector3(0, 0, 0.004), Vector3(0.08, 0.11, 0.012), "bakelit", 0.003),
		B.box(Vector3(0, 0.0, 0.012), Vector3(0.025, 0.04, 0.008), "bakelit", 0.002)], false))
	var ob := StaticBody3D.new()
	ob.collision_layer = Balistyka.WARSTWA_INTERAKCJE
	ob.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.16, 0.18, 0.08)
	cs.shape = bs
	ob.add_child(cs)
	ob.set_meta("interakcja", self)
	add_child(ob)


func _physics_process(delta: float) -> void:
	if not _zgasil_gracz:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.6
	if _wrog_idzie and is_instance_valid(_wrog_idzie) and not _wrog_idzie.cialo.martwy:
		if (_wrog_idzie as Node3D).global_position.distance_to(global_position) < 1.2:
			przelacz(_wrog_idzie)
			_wrog_idzie = null
		return
	for w in get_tree().get_nodes_in_group("wrogowie"):
		if not (w is Wrog) or w.cialo.martwy or w.stan not in ["patrol", "czujny", "szukanie"]:
			continue
		var p: Vector3 = (w as Node3D).global_position
		if absf(p.y - wys) < 1.5 and obszar.grow(0.3).has_point(Vector2(p.x, p.z)):
			# ktoś tu zgasił – a było jasno
			w._napis(["Kto zgasił światło?", "Było jasno... Uwaga.", "Ciemno. Ktoś tu był."].pick_random())
			# idzie do wyłącznika (czujny podchodzi do ostatniej pozycji – tu: do ściany z wyłącznikiem)
			w.ostatnia_pozycja = w._najblizszy_na_siatce(global_position)
			if w.stan == "patrol":
				w.stan = "czujny"
				w._nasluch = false
			w.czas_bez_kontaktu = 0.0
			_wrog_idzie = w
			return
