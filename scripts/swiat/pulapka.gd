class_name Pulapka
extends Node3D
## Pułapka na drzwiach: granat F-1 bez zawleczki wciśnięty w szklankę, szklanka zawieszona na klamce (strona gracza).
## Łyżkę zapalnika trzyma ścianka szklanki. Otwarcie drzwi (kogokolwiek – też gracza, kopniak, wybuch) zrzuca
## szklankę: pęka na podłodze, łyżka odskakuje, po ok. 2,5 s wybuch. Ze strony pułapki można ją powoli rozbroić
## (zawleczka wraca na miejsce – granat i szklanka do ekwipunku).

var drzwi: Drzwi
var wlasciciel: Node            # gracz – zabici liczą się jemu
var strona := 1.0               # +1 / −1: po której stronie skrzydła wisi (lokalne Z drzwi)
var _spuszczona := false


static func zastaw(d: Drzwi, g: Node, strona_z: float) -> Pulapka:
	var p := Pulapka.new()
	p.drzwi = d
	p.wlasciciel = g
	p.strona = strona_z
	d.skrzydlo.add_child(p)
	p.add_to_group("pulapki")
	# klamka: przy krawędzi skrzydła po stronie zamka, wysokość ok. 1 m nad podłogą
	var lh := d.wys - 0.05 - 0.012
	p.position = Vector3(d._szer_skrzydla * 0.5 - 0.13, 1.0 - (lh * 0.5 + 0.006) - 0.06, strona_z * (Drzwi.GR * 0.5 + 0.045))
	d.pulapka = p
	return p


func _ready() -> void:
	var szk := ModelePrzedmiotow.wezel(Przedmiot.nowy("szklanka"))
	add_child(szk)
	szk.rotation = Vector3(0, 0, 0)
	szk.position = Vector3(0, -0.05, 0)
	var gr := ModelePrzedmiotow.wezel(Przedmiot.nowy("granat_f1"))
	add_child(gr)
	gr.position = Vector3(0, 0.0, 0)
	# sznurek z klamki
	var B := preload("res://scripts/core/bryly.gd")
	add_child(B.instancja([B.walec(Vector3(0, 0.06, 0), Vector3(0, 0.1, 0), 0.0015, 0.0015, "czern", 4)], false))


## Drzwi ruszyły: szklanka spada i pęka, łyżka odskakuje, granat leży pod drzwiami.
func spust() -> void:
	if _spuszczona:
		return
	_spuszczona = true
	if drzwi:
		drzwi.pulapka = null
	var swiat := drzwi.get_parent() as Node3D
	var gp := global_position
	reparent(swiat, true)
	var podloga := Vector3(gp.x, drzwi.global_position.y + 0.03, gp.z)
	var tw := create_tween()
	tw.tween_property(self, "global_position", podloga, 0.32).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(self, "rotation:z", 1.4, 0.32)
	tw.tween_callback(func():
		Dzwiek.graj_3d("szklo_pek", podloga, swiat, 0.0, randf_range(0.95, 1.05), 26.0)
		Efekty.czastki(swiat, podloga + Vector3.UP * 0.03, Vector3.UP, Color(0.8, 0.9, 0.92), 14, 2.2)
		Gra.emituj_halas(podloga, 9.0, wlasciciel)
		var g := Granat.rzuc(swiat, podloga + Vector3.UP * 0.05, Vector3(randf_range(-0.4, 0.4), 0.3, randf_range(-0.4, 0.4)), wlasciciel, Dane.def("granat_f1"))
		g.zapalnik = randf_range(2.3, 2.8)
		g.ostrzega_od = 1.3
		get_tree().create_timer(0.08).timeout.connect(func(): Dzwiek.graj_3d("lyzka", podloga, swiat, -4.0, 1.0, 14.0))
		queue_free())


## Szansa, że wróg zauważy pułapkę: światło przy niej (lampy, latarki najemników), czujność (idzie ostrożnie,
## szuka) kontra pośpiech walki; wojsko szkolone. Rozstrzygane raz przy podejściu.
static func szansa_zauwazenia(w, punkt: Vector3, premia := 0.0) -> float:
	var s := 0.18 + premia
	var rajd = w.get_tree().get_first_node_in_group("ui_rajdu")
	if rajd and rajd.has_method("oswietlenie"):
		s += clampf(float(rajd.oswietlenie(punkt)) - 0.12, 0.0, 1.0) * 0.45
	match str(w.get("stan")):
		"czujny", "szukanie":
			s += 0.15
		"walka", "ucieczka":
			s -= 0.15
	match str(w.get("frakcja")):
		"wojskowy":
			s += 0.1
		"najemnik":
			s += 0.12          # latarki na broni
	return clampf(s, 0.05, 0.85)


## Wróg skończył rozbrajanie: granat i szklanka w jego łupie.
func rozbrojony_przez(w) -> void:
	if _spuszczona:
		return
	_spuszczona = true
	if drzwi:
		drzwi.pulapka = null
	w.lup.append(Przedmiot.nowy("granat_f1"))
	w.lup.append(Przedmiot.nowy("szklanka"))
	queue_free()


func punkt_rozbrajania() -> Vector3:
	return global_position


## Rozbrojenie (ze strony pułapki): powoli zdjąć szklankę, przytrzymując łyżkę, wsunąć zawleczkę.
## Ile światła przy pułapce (latarka gracza też się liczy): po ciemku palce szukają łyżki na oślep.
static func swiatlo(n: Node3D, punkt: Vector3) -> float:
	var rajd = n.get_tree().get_first_node_in_group("ui_rajdu")
	return float(rajd.oswietlenie(punkt)) if rajd and rajd.has_method("oswietlenie") else 1.0


func rozbroj(g) -> void:
	Gra.emituj_halas(g.global_position, 1.5 if float(g.get("kucanie")) > 0.5 else 3.0, g)
	var ciemno := Pulapka.swiatlo(self, global_position) < 0.3
	if ciemno:
		g.komunikat.emit("Po ciemku – szklanka i łyżka na wyczucie. Poświeć latarką, będzie pewniej.")
	g.zacznij_akcje("Rozbrajanie pułapki" + (" (po ciemku)" if ciemno else ""), 4.5 * (1.8 if ciemno else 1.0), func():
		if _spuszczona:
			return
		if ciemno and randf() < 0.12:
			g.komunikat.emit("Szklanka wyślizgnęła się z palców!")
			spust()
			return
		_spuszczona = true
		if drzwi:
			drzwi.pulapka = null
		for pid in ["granat_f1", "szklanka"]:
			var pz := Przedmiot.nowy(pid)
			if not g.ekw.dodaj(pz):
				var l := LupNaZiemi.new()
				l.przedmiot = pz
				drzwi.get_parent().add_child(l)
				l.global_position = global_position + Vector3.UP * 0.1
		Dzwiek.graj_3d("zawleczka", global_position, drzwi.get_parent(), -10.0)
		g.komunikat.emit("Pułapka zdjęta: łyżka przytrzymana, zawleczka z powrotem. Granat i szklanka w kieszeni.")
		queue_free(), "otwieranie", 0, Callable(), {"id": "drzwi"})
