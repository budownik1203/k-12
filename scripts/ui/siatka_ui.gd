class_name SiatkaUI
extends Control
## Widok siatki pojemnika z przedmiotami. Przeciąganie obsługuje EkranEkwipunku (kontroler).

signal klik(ui: SiatkaUI, p: Przedmiot, przycisk: int, pozycja: Vector2)
signal najechano(p: Przedmiot)

const KOM := 34

var siatka: Siatka
var tytul := ""
var widoczne := -1          # ile pierwszych przedmiotów widać (-1 = wszystkie) – przy przeszukiwaniu
var kontroler: Node         # EkranEkwipunku
var zrodlo := ""            # opis: "skrytka", "plecak", "pojemnik"...
var _hover: Przedmiot = null


func ustaw(s: Siatka, nazwa := "") -> void:
	if siatka and siatka.zmieniona.is_connected(queue_redraw):
		siatka.zmieniona.disconnect(queue_redraw)
	siatka = s
	tytul = nazwa
	if siatka:
		siatka.zmieniona.connect(queue_redraw)
		custom_minimum_size = Vector2(siatka.w * KOM, siatka.h * KOM)
	else:
		custom_minimum_size = Vector2(KOM * 2, KOM)
	queue_redraw()


func komorka_pod(pos_lokalna: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos_lokalna.x / KOM)), int(floor(pos_lokalna.y / KOM)))


func ukryty(p: Przedmiot) -> bool:
	if widoczne < 0 or siatka == null:
		return false
	for i in siatka.items.size():
		if siatka.items[i]["p"] == p:
			return i >= widoczne
	return false


func _draw() -> void:
	if siatka == null:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.05, 0.6))
		draw_string(Motyw.cond(), Vector2(6, 22), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Motyw.TEKST_CIEMNY)
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(siatka.w, siatka.h) * KOM), Motyw.KOMORKA)
	for x in siatka.w + 1:
		draw_line(Vector2(x * KOM, 0), Vector2(x * KOM, siatka.h * KOM), Motyw.KOMORKA_LINIA)
	for y in siatka.h + 1:
		draw_line(Vector2(0, y * KOM), Vector2(siatka.w * KOM, y * KOM), Motyw.KOMORKA_LINIA)
	var przeciagany: Przedmiot = kontroler.przeciagany() if kontroler and kontroler.has_method("przeciagany") else null
	for i in siatka.items.size():
		var e: Dictionary = siatka.items[i]
		var p: Przedmiot = e["p"]
		if p == przeciagany:
			continue
		var r := Rect2(Vector2(e["x"], e["y"]) * KOM, Vector2(p.szer(), p.wys()) * KOM)
		if widoczne >= 0 and i >= widoczne:
			draw_rect(r.grow(-2), Color(0.09, 0.09, 0.08))
			draw_string(Motyw.mono_b(), r.position + Vector2(r.size.x * 0.5 - 5, r.size.y * 0.5 + 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Motyw.TEKST_CIEMNY)
			continue
		rysuj_przedmiot(self, p, r, p == _hover)


static func rysuj_przedmiot(ci: CanvasItem, p: Przedmiot, r: Rect2, podswietl := false) -> void:
	var tlo := Color(0.17, 0.17, 0.15, 0.95)
	match p.typ():
		"bron": tlo = Color(0.2, 0.16, 0.13, 0.95)
		"med": tlo = Color(0.14, 0.19, 0.15, 0.95)
		"amunicja", "magazynek": tlo = Color(0.19, 0.18, 0.12, 0.95)
		"lup": tlo = Color(0.16, 0.15, 0.19, 0.95)
		"klucz": tlo = Color(0.22, 0.2, 0.1, 0.95)
	ci.draw_rect(r.grow(-1), tlo)
	if podswietl:
		ci.draw_rect(r.grow(-1), Color(0.8, 0.66, 0.3, 0.18))
	ci.draw_rect(r.grow(-1), Color(0.33, 0.31, 0.25), false, 1.0)
	var tex := Dane.ikona(p.id)
	if tex:
		var ts := tex.get_size()
		if p.obrot:
			# ikona obrócona o 90°
			var srodek := r.get_center()
			ci.draw_set_transform(srodek, PI / 2.0, Vector2.ONE)
			ci.draw_texture_rect(tex, Rect2(-ts * 0.5, ts), false)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			ci.draw_texture_rect(tex, Rect2(r.get_center() - ts * 0.5, ts), false)
	var et := p.etykieta()
	if et != "":
		var f := Motyw.mono_b()
		var w := f.get_string_size(et, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		ci.draw_rect(Rect2(r.end - Vector2(w + 5, 14), Vector2(w + 4, 13)), Color(0, 0, 0, 0.65))
		ci.draw_string(f, r.end - Vector2(w + 3, 4), et, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Motyw.TEKST)
	# skrócona nazwa w rogu (dla przedmiotów większych niż 1 kratka)
	if r.size.x >= 60:
		ci.draw_string(Motyw.cond(), r.position + Vector2(4, 12), p.nazwa().substr(0, int(r.size.x / 7)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.72, 0.62, 0.85))


func _gui_input(event: InputEvent) -> void:
	if siatka == null:
		return
	if event is InputEventMouseMotion:
		var k := komorka_pod(event.position)
		var p := siatka.przedmiot_w(k.x, k.y)
		if p != null and ukryty(p):
			p = null
		if p != _hover:
			_hover = p
			najechano.emit(p)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var k := komorka_pod(event.position)
		var p := siatka.przedmiot_w(k.x, k.y)
		if p != null and ukryty(p):
			return
		klik.emit(self, p, event.button_index, event.global_position)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != null:
		_hover = null
		najechano.emit(null)
		queue_redraw()
