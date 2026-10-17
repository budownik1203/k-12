class_name KolkoPostepu
extends Control
## Kółko postępu akcji (jak w Wardogs): wewnętrzny łuk – bieżący krok (np. jeden nabój),
## zewnętrzny – całość akcji. Pod spodem nazwa, licznik i podpowiedź przerwania.

var postep := 0.0          # bieżący krok 0..1
var calosc := 0.0          # cała akcja 0..1
var tekst := ""
var licznik := ""
var promien := 22.0
var podpowiedz := true       # "[X] przerwij" pod kółkiem
var srodkuj := false         # rysuj na środku kontrolki (w kontenerach)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func ustaw_z_gracza(g: Gracz) -> void:
	if g == null or g.akcja.is_empty():
		visible = false
		return
	visible = true
	var a: Dictionary = g.akcja
	postep = g.postep_kroku()
	calosc = clampf(float(a["t"]) / maxf(0.01, float(a["czas"])), 0.0, 1.0)
	tekst = String(a["nazwa"])
	licznik = ("%d/%d" % [int(a["zrobione"]), int(a["kroki"])]) if int(a["kroki"]) > 0 else ""
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5 if srodkuj else Vector2.ZERO
	var r := promien
	draw_circle(c, r + 5.0, Color(0, 0, 0, 0.55))
	draw_arc(c, r, 0.0, TAU, 48, Color(0.3, 0.29, 0.24, 0.6), 3.0)
	if calosc > 0.0:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * calosc, 48, Color(0.86, 0.72, 0.36), 3.0)
	if licznik != "":
		draw_arc(c, r - 6.0, -PI * 0.5, -PI * 0.5 + TAU * postep, 40, Color(0.95, 0.92, 0.8), 4.0)
		var f := Motyw.mono_b()
		var w := f.get_string_size(licznik, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(f, c + Vector2(-w * 0.5, 4), licznik, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.92, 0.8))
	else:
		draw_circle(c, (r - 7.0) * postep, Color(0.86, 0.72, 0.36, 0.35))
	var fc := Motyw.cond()
	var tw := fc.get_string_size(tekst, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(fc, c + Vector2(-tw * 0.5 + 1, r + 22), tekst, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.8))
	draw_string(fc, c + Vector2(-tw * 0.5, r + 21), tekst, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.86, 0.72))
	if not podpowiedz:
		return
	var hint := "[X] przerwij"
	var hw := fc.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(fc, c + Vector2(-hw * 0.5, r + 37), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.57, 0.48))
