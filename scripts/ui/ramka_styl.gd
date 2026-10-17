class_name RamkaStyl
extends StyleBox
## Przezroczysta ramka panelu ekwipunku: cienki kontur i mocniejsze narożniki (bez tła – świat gry widać pod spodem).

var kolor := Color(0.82, 0.76, 0.58, 0.32)
var naroznik := Color(0.9, 0.84, 0.64, 0.85)
var dl := 14.0
var tlo := Color(0.0, 0.0, 0.0, 0.0)


func _init(akcent := false, margines := 12.0) -> void:
	content_margin_left = margines
	content_margin_right = margines
	content_margin_top = margines
	content_margin_bottom = margines
	if akcent:
		naroznik = Color(0.95, 0.78, 0.38, 0.95)
		kolor = Color(0.95, 0.78, 0.38, 0.4)


func _draw(ci: RID, rect: Rect2) -> void:
	if tlo.a > 0.0:
		RenderingServer.canvas_item_add_rect(ci, rect, tlo)
	var a := rect.position + Vector2(0.5, 0.5)
	var b := rect.end - Vector2(0.5, 0.5)
	# kontur
	for odc in [[a, Vector2(b.x, a.y)], [Vector2(b.x, a.y), b], [b, Vector2(a.x, b.y)], [Vector2(a.x, b.y), a]]:
		RenderingServer.canvas_item_add_line(ci, odc[0], odc[1], kolor, 1.0)
	# narożniki
	var d := minf(dl, minf(rect.size.x, rect.size.y) * 0.3)
	for n in [[a, Vector2(1, 1)], [Vector2(b.x, a.y), Vector2(-1, 1)], [b, Vector2(-1, -1)], [Vector2(a.x, b.y), Vector2(1, -1)]]:
		var p: Vector2 = n[0]
		var k: Vector2 = n[1]
		RenderingServer.canvas_item_add_line(ci, p, p + Vector2(k.x * d, 0), naroznik, 2.0)
		RenderingServer.canvas_item_add_line(ci, p, p + Vector2(0, k.y * d), naroznik, 2.0)
