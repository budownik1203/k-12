class_name SiatkaUI
extends Control
## Widok siatki pojemnika z przedmiotami. Przeciąganie obsługuje EkranEkwipunku (kontroler).

signal klik(ui: SiatkaUI, p: Przedmiot, przycisk: int, pozycja: Vector2)
signal najechano(p: Przedmiot)
signal kieszen(ui: SiatkaUI, indeks: int)
## Gesty przy kieszeniach: wciśnięcie na zapiętej (otwieranie) albo na uchwycie otwartej (zamykanie),
## ruch myszy z wciśniętym przyciskiem, puszczenie.
signal gest_start(ui: SiatkaUI, indeks: int, zamykanie: bool)
signal gest_ruch(ui: SiatkaUI, indeks: int, rel: Vector2)
signal gest_koniec(ui: SiatkaUI, indeks: int)
var _gest := -1
var proste_kieszenie := true     # tryb prosty (klik w kieszeń) – w rajdzie z modelem 3D: chwytanie uchwytów

const KOM := 17          # drobna siatka: dawna kratka 34 px = 2x2 nowe

var siatka: Siatka
var tytul := ""
var widoczne := -1          # ile pierwszych przedmiotów widać (-1 = wszystkie) – przy przeszukiwaniu
var znane = null            # Dictionary przedmiotów już znalezionych (przeszukiwanie); null = wszystko widać
## Kieszenie rozłożonego plecaka / kontenera: zamknięte zakrywają swoje pola (trzeba je otworzyć).
## [{"r": Rect2i, "nazwa": String, "otwarta": bool, "w_toku": bool}]
var kieszenie: Array = []
var ciemno := false         # przeszukiwanie po ciemku: przedmioty jako cienie (bez latarki)
var kontroler: Node         # EkranEkwipunku
var zrodlo := ""            # opis: "skrytka", "plecak", "pojemnik"...
var _hover: Przedmiot = null


func ustaw(s: Siatka, nazwa := "") -> void:
	if siatka and siatka.zmieniona.is_connected(queue_redraw):
		siatka.zmieniona.disconnect(queue_redraw)
	if siatka and siatka.zmieniona.is_connected(_dopasuj_rozmiar):
		siatka.zmieniona.disconnect(_dopasuj_rozmiar)
	siatka = s
	tytul = nazwa
	if siatka:
		siatka.zmieniona.connect(queue_redraw)
		siatka.zmieniona.connect(_dopasuj_rozmiar)
		custom_minimum_size = Vector2(siatka.w * KOM, siatka.h * KOM)
	else:
		custom_minimum_size = Vector2(KOM * 2, KOM)
	queue_redraw()


func komorka_pod(pos_lokalna: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos_lokalna.x / KOM)), int(floor(pos_lokalna.y / KOM)))


func kieszen_pod(k: Vector2i) -> int:
	for i in kieszenie.size():
		if (kieszenie[i]["r"] as Rect2i).has_point(k):
			return i
	return -1


func zakryta(k: Vector2i) -> bool:
	var i := kieszen_pod(k)
	return i >= 0 and not bool(kieszenie[i]["otwarta"])


## Czy obszar (np. pod upuszczany przedmiot) zahacza o zamkniętą kieszeń.
func zakryty_obszar(x: int, y: int, w: int, h: int) -> bool:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if zakryta(Vector2i(xx, yy)):
				return true
	return false


func ukryty(p: Przedmiot) -> bool:
	if not kieszenie.is_empty() and siatka:
		var poz := siatka.pozycja(p)
		if zakryty_obszar(poz.x, poz.y, p.szer(), p.wys()):
			return true
	if znane != null:
		return not (znane as Dictionary).has(p)
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
	var kt := Motyw.tekstura("komorka")
	if siatka.maska.is_empty() and kieszenie.is_empty():
		if kt:
			draw_texture_rect(kt, Rect2(Vector2.ZERO, Vector2(siatka.w, siatka.h) * KOM), true, Color(1, 1, 1, 0.82))
		else:
			draw_rect(Rect2(Vector2.ZERO, Vector2(siatka.w, siatka.h) * KOM), Motyw.KOMORKA)
		for x in siatka.w + 1:
			draw_line(Vector2(x * KOM, 0), Vector2(x * KOM, siatka.h * KOM), Motyw.KOMORKA_LINIA)
		for y in siatka.h + 1:
			draw_line(Vector2(0, y * KOM), Vector2(siatka.w * KOM, y * KOM), Motyw.KOMORKA_LINIA)
	else:
		# tylko pola ładownic; szwy między nimi przezroczyste
		for y in siatka.h:
			for x in siatka.w:
				if not siatka.dostepna(x, y) or zakryta(Vector2i(x, y)):
					continue
				var rk := Rect2(Vector2(x, y) * KOM, Vector2(KOM, KOM))
				if kt:
					draw_texture_rect(kt, rk, true, Color(1, 1, 1, 0.82))
				else:
					draw_rect(rk, Motyw.KOMORKA)
				draw_rect(rk, Motyw.KOMORKA_LINIA, false, 1.0)
	if not siatka.maska.is_empty():
		# przegródki: puste pola to szwy między ładownicami, każda ładownica ma własną obwódkę
		for y in siatka.h:
			for x in siatka.w:
				var r := Rect2(Vector2(x, y) * KOM, Vector2(KOM, KOM))
				if not siatka.dostepna(x, y) or (not proste_kieszenie and zakryta(Vector2i(x, y))):
					continue
				var c := Color(0.02, 0.02, 0.015, 0.95)
				if not siatka.dostepna(x - 1, y):
					draw_line(r.position, Vector2(r.position.x, r.end.y), c, 3.0)
				if not siatka.dostepna(x + 1, y):
					draw_line(Vector2(r.end.x, r.position.y), r.end, c, 3.0)
				if not siatka.dostepna(x, y - 1):
					draw_line(r.position, Vector2(r.end.x, r.position.y), c, 3.0)
				if not siatka.dostepna(x, y + 1):
					draw_line(Vector2(r.position.x, r.end.y), r.end, c, 3.0)
	else:
		draw_rect(Rect2(Vector2.ZERO, Vector2(siatka.w, siatka.h) * KOM), Color(0, 0, 0, 0.5), false, 2.0)
	var przeciagany: Przedmiot = kontroler.przeciagany() if kontroler and kontroler.has_method("przeciagany") else null
	for i in siatka.items.size():
		var e: Dictionary = siatka.items[i]
		var p: Przedmiot = e["p"]
		if p == przeciagany:
			continue
		var r := Rect2(Vector2(e["x"], e["y"]) * KOM, Vector2(p.szer(), p.wys()) * KOM)
		if not kieszenie.is_empty() and zakryty_obszar(int(e["x"]), int(e["y"]), p.szer(), p.wys()):
			continue
		if (znane != null and not (znane as Dictionary).has(p)) or (znane == null and widoczne >= 0 and i >= widoczne):
			draw_rect(r.grow(-2), Color(0.09, 0.09, 0.08))
			draw_string(Motyw.mono_b(), r.position + Vector2(r.size.x * 0.5 - 5, r.size.y * 0.5 + 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Motyw.TEKST_CIEMNY)
			continue
		rysuj_przedmiot(self, p, r, p == _hover)
		if ciemno:
			draw_rect(r.grow(-1), Color(0, 0, 0, 0.5))
		if kontroler and kontroler.has_method("w_kolejce") and kontroler.w_kolejce(p):
			draw_rect(r.grow(-2), Color(0.86, 0.72, 0.36, 0.22))
			draw_rect(r.grow(-2), Color(0.86, 0.72, 0.36, 0.8), false, 1.5)

	_rysuj_kieszenie()


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
	var tex := Dane.ikona(p.ikona_id())
	if tex:
		var ts := tex.get_size()
		# duże przedmioty w małym slocie: ikona pomniejszona do ramki
		var miesc := Vector2(ts.y, ts.x) if p.obrot else ts
		# ikony rysowane w dawnej skali (32 px na grubą kratkę): dopasowane do ramki z zachowaniem proporcji
		var sk := minf(2.0, minf((r.size.x - 3.0) / miesc.x, (r.size.y - 3.0) / miesc.y))
		ts *= sk
		if p.obrot:
			# ikona obrócona o 90°
			var srodek := r.get_center()
			ci.draw_set_transform(srodek, PI / 2.0, Vector2.ONE)
			ci.draw_texture_rect(tex, Rect2(-ts * 0.5, ts), false)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			ci.draw_texture_rect(tex, Rect2(r.get_center() - ts * 0.5, ts), false)
	if p.dane.get("przeterminowany", false):
		# zbrylone, wyblakłe – pomarańczowy wykrzyknik w rogu
		ci.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(9, 11)), Color(0.55, 0.3, 0.08, 0.9))
		ci.draw_string(Motyw.mono_b(), r.position + Vector2(4, 12), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.5))
	if p.typ() == "pancerz":
		# wgniecenia i przetarcia proporcjonalne do zużycia
		var mx := float(p.defn()["pancerz"]["wytrzymalosc"])
		var ub := 1.0 - float(p.dane.get("wytrz", mx)) / maxf(1.0, mx)
		var rr := RandomNumberGenerator.new()
		rr.seed = hash(p)
		for i in int(ub * 9.0):
			var c := r.position + Vector2(rr.randf_range(6, r.size.x - 6), rr.randf_range(6, r.size.y - 6))
			ci.draw_circle(c, rr.randf_range(1.5, 3.0), Color(0.05, 0.05, 0.05, 0.6))
			ci.draw_line(c, c + Vector2(rr.randf_range(-4, 4), rr.randf_range(-4, 4)), Color(0.75, 0.72, 0.6, 0.5), 1.0)
	if p.typ() == "bron" and float(p.dane.get("stan", 100.0)) < 60.0:
		ci.draw_rect(Rect2(r.position + Vector2(3, r.size.y - 5), Vector2((r.size.x - 6) * float(p.dane.get("stan", 100.0)) / 100.0, 2)), Color(0.85, 0.55, 0.25, 0.85))
	if p.dane.get("oznaczony", false):
		ci.draw_string(Motyw.mono_b(), r.position + Vector2(r.size.x - 13, 13), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.78, 0.35))
	if p.nieznany():
		ci.draw_rect(r.grow(-2), Color(0.05, 0.05, 0.04, 0.72))
		ci.draw_string(Motyw.mono_b(), r.get_center() + Vector2(-5, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.86, 0.8, 0.62, 0.8))
	var et := p.etykieta()
	if et != "":
		# etykieta (liczba, stan magazynka) mieści się w ramce przedmiotu – przy wąskich mniejsza czcionka
		var f := Motyw.mono_b()
		var fs := 11
		var w := f.get_string_size(et, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while w > r.size.x - 4.0 and fs > 7:
			fs -= 1
			w = f.get_string_size(et, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var hh := fs + 3.0
		ci.draw_rect(Rect2(r.end - Vector2(minf(w, r.size.x - 2.0) + 4, hh + 1), Vector2(minf(w, r.size.x - 2.0) + 3, hh)), Color(0, 0, 0, 0.65))
		ci.draw_string(f, r.end - Vector2(minf(w, r.size.x - 2.0) + 2, 4), et, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 2.0, fs, Motyw.TEKST)
	# skrócona nazwa w rogu (dla przedmiotów większych niż 1 kratka)
	if r.size.x >= 60:
		ci.draw_string(Motyw.cond(), r.position + Vector2(4, 12), p.nazwa().substr(0, int(r.size.x / 7)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.72, 0.62, 0.85))


## Uchwyt zapinania otwartej kieszeni (prawy górny róg).
func uchwyt_kieszeni(i: int) -> Rect2:
	var rr: Rect2i = kieszenie[i]["r"]
	var r := Rect2(Vector2(rr.position) * KOM, Vector2(rr.size) * KOM)
	return Rect2(Vector2(r.end.x - 26, r.position.y + 1), Vector2(25, 11))


## Podświetlony uchwyt zapięcia (pulsujący pierścień) ze strzałką: dokąd go przeciągnąć.
func _rysuj_uchwyt(kz: Dictionary) -> void:
	var p: Vector2 = kz["uchwyt_l"]
	var akt := bool(kz.get("uchwyt_akt", false))
	var puls := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
	var zolty := Color(1.0, 0.82, 0.3)
	var r := 9.0 + puls * 3.0 if not akt else 7.0
	draw_circle(p, r + 3.0, Color(0, 0, 0, 0.35))
	draw_arc(p, r, 0, TAU, 24, Color(zolty, 0.55 + 0.45 * puls if not akt else 1.0), 2.0)
	draw_circle(p, 3.0, Color(zolty, 0.95))
	var rodz := String(kz.get("uchwyt_rodz", "gora"))
	var f := Motyw.mono_b()
	if rodz == "klik":
		draw_string(f, p + Vector2(r + 4, 4), "klik", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(zolty, 0.9))
		return
	var kier: Vector2 = kz.get("uchwyt_kier", Vector2(0, -1))
	if kier.length() < 0.1:
		return
	# strzałka wzdłuż drogi uchwytu
	var a := p + kier * (r + 4.0)
	var b := p + kier * (r + 30.0 + puls * 6.0)
	draw_line(a, b, Color(zolty, 0.85), 2.0)
	var bok := kier.orthogonal() * 5.0
	draw_colored_polygon(PackedVector2Array([b + kier * 7.0, b + bok, b - bok]), Color(zolty, 0.85))


func _rysuj_kieszenie() -> void:
	var proste := proste_kieszenie
	for ki in kieszenie.size():
		var kz: Dictionary = kieszenie[ki]
		if not proste:
			# rajd z modelem 3D: stan kieszeni widać na samym modelu, element do chwycenia się świeci
			continue
		if bool(kz["otwarta"]):
			# otwarta: przerywany brzeg i uchwyt „zapnij”
			var u := uchwyt_kieszeni(ki)
			draw_rect(u, Color(0.1, 0.09, 0.07, 0.85))
			draw_rect(u, Color(0.86, 0.8, 0.62, 0.6), false, 1.0)
			draw_string(Motyw.cond(), u.position + Vector2(2, 9), "zapnij", HORIZONTAL_ALIGNMENT_CENTER, u.size.x - 4, 8, Color(0.86, 0.8, 0.62, 0.85))
			continue
		var rr: Rect2i = kz["r"]
		var r := Rect2(Vector2(rr.position) * KOM, Vector2(rr.size) * KOM).grow(-1)
		draw_rect(r, Color(0.05, 0.05, 0.04, 0.18))
		# przeszycie wzdłuż brzegu klapy
		var w := r.grow(-4)
		for i in range(0, int(w.size.x), 6):
			draw_line(w.position + Vector2(i, 0), w.position + Vector2(i + 3, 0), Color(0.45, 0.42, 0.32, 0.8))
			draw_line(Vector2(w.position.x + i, w.end.y), Vector2(w.position.x + i + 3, w.end.y), Color(0.45, 0.42, 0.32, 0.8))
		draw_rect(r, Color(0.86, 0.8, 0.62, 0.45), false, 1.5)
		var f := Motyw.cond()
		var nz := String(kz["nazwa"])
		var t2 := "otwieranie..." if bool(kz.get("w_toku", false)) else String(kz.get("podpowiedz", "kliknij – otwórz"))
		# pasek postępu gestu (ile materiału już odsunięte)
		var pg := float(kz.get("postep_calk", 0.0))
		if pg > 0.0 and pg < 1.0:
			draw_rect(Rect2(r.position.x + 3, r.end.y - 5, (r.size.x - 6) * pg, 2), Color(0.95, 0.85, 0.45, 0.9))
		var sz := minf(12.0, r.size.x / maxf(1.0, nz.length()) * 1.7)
		draw_string(f, Vector2(r.position.x + 4, r.get_center().y - 2), nz, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, int(maxf(8.0, sz)), Color(0.86, 0.8, 0.62, 0.9))
		draw_string(f, Vector2(r.position.x + 4, r.get_center().y + 12), t2, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 9, Color(0.7, 0.66, 0.52, 0.75))


func _gui_input(event: InputEvent) -> void:
	if siatka == null:
		return
	if event is InputEventMouseMotion and _gest >= 0:
		gest_ruch.emit(self, _gest, event.relative)
		accept_event()
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _gest >= 0:
		var g := _gest
		_gest = -1
		gest_koniec.emit(self, g)
		accept_event()
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
		if event.button_index == MOUSE_BUTTON_LEFT:
			for ki in kieszenie.size():
				# uchwyt „zapnij” w rogu tylko w trybie prostym i tylko na pustej komórce (nie zabiera kliknięć slotom)
				if proste_kieszenie and bool(kieszenie[ki]["otwarta"]) and uchwyt_kieszeni(ki).has_point(event.position) \
						and siatka.przedmiot_w(k.x, k.y) == null:
					_gest = ki
					gest_start.emit(self, ki, true)
					accept_event()
					return
		if zakryta(k):
			if event.button_index == MOUSE_BUTTON_LEFT:
				_gest = kieszen_pod(k)
				gest_start.emit(self, _gest, false)
			accept_event()
			return
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


## Skrytka zmienia wysokość wraz z meblami kryjówki.
func _dopasuj_rozmiar() -> void:
	if siatka:
		custom_minimum_size = Vector2(siatka.w * KOM, siatka.h * KOM)
