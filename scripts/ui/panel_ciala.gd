class_name PanelCiala
extends Control
## Panel zdrowia (jak w Tarkovie): sylwetka z pięcioma częściami ciała, HP, krwawienia i złamania.
## Upuszczenie środka medycznego na część ciała leczy właśnie ją.

var cialo: Cialo
var podswietl := ""        # część pod kursorem przy przeciąganiu leku
var najechana := ""

# prostokąty części (lokalne), ręce i nogi mają po dwa
const CZESCI := {
	"glowa": [Rect2(53, 4, 44, 40)],
	"klatka": [Rect2(39, 48, 72, 54)],
	"brzuch": [Rect2(43, 104, 64, 40)],
	"rece": [Rect2(5, 50, 30, 92), Rect2(115, 50, 30, 92)],
	"nogi": [Rect2(43, 148, 30, 90), Rect2(77, 148, 30, 90)],
}


func _ready() -> void:
	custom_minimum_size = Vector2(150, 244)
	mouse_filter = Control.MOUSE_FILTER_PASS


func czesc_pod(global_pos: Vector2) -> String:
	if not is_visible_in_tree():
		return ""
	var lok := global_pos - global_position
	for cz in CZESCI:
		for r in CZESCI[cz]:
			if (r as Rect2).grow(3.0).has_point(lok):
				return cz
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var n := czesc_pod(get_global_mouse_position())
		if n != najechana:
			najechana = n
			queue_redraw()


func opis_czesci(cz: String) -> String:
	if cialo == null or cz == "":
		return ""
	var t := "%s: %d/%d HP" % [Cialo.NAZWY[cz], int(cialo.hp[cz]), int(Cialo.MAX[cz])]
	if cialo.hp[cz] <= 0.0:
		t += " · ZNISZCZONE"
	if cialo.krwawienie[cz] == 2:
		t += " · ciężkie krwawienie (opatrunek)"
	elif cialo.krwawienie[cz] == 1:
		t += " · krwawienie (bandaż)"
	if cialo.zlamanie[cz]:
		t += " · złamanie (szyna)"
	return t


func _draw() -> void:
	if cialo == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var f := Motyw.mono_b()
	# głód i pragnienie: dwa pionowe paski w dolnych rogach (jedzenie po lewej, woda po prawej)
	for e in [["jedz.", "glod", 6.0, Color(0.75, 0.6, 0.3)], ["woda", "pragnienie", 120.0, Color(0.35, 0.6, 0.8)]]:
		var v: float = clampf(float(Gra.potrzeby.get(e[1], 100.0)) / 100.0, 0.0, 1.0)
		var r := Rect2(float(e[2]), 168, 22, 70)
		draw_rect(r, Color(0.08, 0.08, 0.07, 0.92))
		var kol: Color = e[3] if v > 0.25 else (Color(0.85, 0.3, 0.15) if fmod(t, 1.0) < 0.6 or v > 0.15 else Color(0.4, 0.1, 0.05))
		draw_rect(Rect2(r.position.x, r.end.y - r.size.y * v, r.size.x, r.size.y * v), Color(kol, 0.85))
		draw_rect(r, Color(0, 0, 0, 0.8), false, 1.0)
		draw_string(f, Vector2(r.position.x - 2, 162), e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.82, 0.7))
	for cz in CZESCI:
		var frac: float = cialo.hp[cz] / Cialo.MAX[cz]
		for r in CZESCI[cz]:
			var rr := r as Rect2
			draw_rect(rr, Color(0.08, 0.08, 0.07, 0.92))
			var kol := Color(0.36, 0.42, 0.3).lerp(Color(0.72, 0.22, 0.12), clampf(1.0 - frac, 0.0, 1.0))
			var h := rr.size.y * clampf(frac, 0.0, 1.0)
			draw_rect(Rect2(rr.position.x, rr.end.y - h, rr.size.x, h), Color(kol, 0.9))
			if cialo.krwawienie[cz] > 0 and fmod(t, 0.9) < 0.45:
				draw_rect(rr, Color(0.9, 0.08, 0.05, 0.35 if cialo.krwawienie[cz] == 1 else 0.6))
			if cialo.zlamanie[cz]:
				draw_line(rr.position + Vector2(3, 3), rr.end - Vector2(3, 3), Color(1, 0.9, 0.6), 2.0)
				draw_line(Vector2(rr.end.x - 3, rr.position.y + 3), Vector2(rr.position.x + 3, rr.end.y - 3), Color(1, 0.9, 0.6), 2.0)
			var obrys := Color(0, 0, 0, 0.8)
			var gr := 1.0
			if cz == podswietl:
				obrys = Color(0.95, 0.85, 0.4)
				gr = 3.0
			elif cz == najechana:
				obrys = Color(0.8, 0.78, 0.66)
				gr = 2.0
			draw_rect(rr, obrys, false, gr)
		# liczba HP wewnątrz (pierwszy prostokąt części), znaki urazów pod nią
		var r0: Rect2 = CZESCI[cz][0]
		var txt := "%d" % int(cialo.hp[cz])
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var p := r0.get_center() + Vector2(-w * 0.5, 4)
		draw_string(f, p + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.9))
		draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.92, 0.8))
		var znaki := ""
		if cialo.krwawienie[cz] == 2:
			znaki += "▼▼"
		elif cialo.krwawienie[cz] == 1:
			znaki += "▼"
		if cialo.zlamanie[cz]:
			znaki += "✕"
		if znaki != "":
			var zw := f.get_string_size(znaki, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(f, r0.get_center() + Vector2(-zw * 0.5, 17), znaki, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.3, 0.2))
