class_name SlotUI
extends Control
## Miejsce na ciele (hełm, pancerz, kamizelka, plecak, broń).

signal klik(ui: SlotUI, p: Przedmiot, przycisk: int, pozycja: Vector2)
signal najechano(p: Przedmiot)

var ekw: Ekwipunek
var slot := ""
var kontroler: Node
var _hover := false


func ustaw(e: Ekwipunek, s: String, rozmiar: Vector2i) -> void:
	ekw = e
	slot = s
	custom_minimum_size = Vector2(rozmiar) * SiatkaUI.KOM + Vector2(0, 16)
	mouse_filter = Control.MOUSE_FILTER_STOP


func przedmiot() -> Przedmiot:
	return ekw.sloty.get(slot) if ekw else null


func _draw() -> void:
	draw_string(Motyw.mono_b(), Vector2(0, 11), Ekwipunek.NAZWY_SLOTOW[slot].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Motyw.TEKST_CIEMNY)
	var r := Rect2(Vector2(0, 16), size - Vector2(0, 16))
	draw_rect(r, Motyw.KOMORKA)
	var p := przedmiot()
	var przec: Przedmiot = kontroler.przeciagany() if kontroler and kontroler.has_method("przeciagany") else null
	if p != null and p != przec:
		var tex := Dane.ikona(p.id)
		SiatkaUI.rysuj_przedmiot(self, p, r, _hover)
	else:
		# podpowiedź, czy przeciągany przedmiot tu pasuje
		if przec != null and Ekwipunek.pasuje(slot, przec):
			draw_rect(r, Color(0.4, 0.6, 0.35, 0.18))
	draw_rect(r, Motyw.RAMKA, false, 1.0)


func _process(_d: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		klik.emit(self, przedmiot(), event.button_index, event.global_position)
		accept_event()
	elif event is InputEventMouseMotion:
		if not _hover:
			_hover = true
			najechano.emit(przedmiot())


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		najechano.emit(null)
