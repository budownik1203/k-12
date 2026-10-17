class_name PanelCiala
extends Control
## Panel zdrowia (jak w Tarkovie): sylwetka z pięcioma częściami ciała, HP, krwawienia i złamania.
## Upuszczenie środka medycznego na część ciała leczy właśnie ją.

var cialo: Cialo
var podswietl := ""        # część pod kursorem przy przeciąganiu leku
var najechana := ""

const SKALA := 1.0
# prostokąty części (lokalne), ręce i nogi mają po dwa
const CZESCI := {
	"glowa": [Rect2(118, 4, 44, 40)],
	"klatka": [Rect2(104, 48, 72, 54)],
	"brzuch": [Rect2(108, 104, 64, 40)],
	"rece": [Rect2(70, 50, 30, 92), Rect2(180, 50, 30, 92)],
	"nogi": [Rect2(108, 148, 30, 90), Rect2(142, 148, 30, 90)],
}
# miejsca opisów (lewa/prawa strona sylwetki)
const OPISY := {
	"glowa": [Vector2(178, 20), false], "klatka": [Vector2(216, 70), false], "brzuch": [Vector2(216, 120), false],
	"rece": [Vector2(4, 70), true], "nogi": [Vector2(4, 190), true],
}


func _ready() -> void:
	custom_minimum_size = Vector2(300, 244)
	mouse_filter = Control.MOUSE_FILTER_PASS


func czesc_pod(global_pos: Vector2) -> String:
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
	var f := Motyw.mono()
	for cz in CZESCI:
		var frac: float = cialo.hp[cz] / Cialo.MAX[cz]
		for r in CZESCI[cz]:
			var rr := r as Rect2
			draw_rect(rr, Color(0.1, 0.1, 0.09, 0.9))
			# wypełnienie od dołu proporcjonalnie do HP
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
		var op: Array = OPISY[cz]
		var txt := "%d" % int(cialo.hp[cz])
		var znaki := ""
		if cialo.krwawienie[cz] == 2:
			znaki += " ▼▼"
		elif cialo.krwawienie[cz] == 1:
			znaki += " ▼"
		if cialo.zlamanie[cz]:
			znaki += " ✕"
		var poz: Vector2 = op[0]
		draw_string(f, poz, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.87, 0.75))
		if znaki != "":
			draw_string(f, poz + Vector2(0, 16), znaki.strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.25, 0.15))
	if cialo.przeciwbol > 0.0:
		draw_string(f, Vector2(4, 236), "Bólostop: %d s" % int(cialo.przeciwbol), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.75, 0.55))
	elif cialo.bol():
		draw_string(f, Vector2(4, 236), "BÓL – drży celownik", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.4, 0.2))
