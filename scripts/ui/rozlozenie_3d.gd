class_name Rozlozenie3D
extends Node3D
## Ekwipunek w świecie (jak w Green Hell / Metro Exodus): postać zdejmuje plecak, kładzie go przed sobą
## i rozpina; kontener bezpieczny wyjmuje i stawia obok, otwiera wieko. Kamizelka jest przyciągana do przodu
## przed kamerę. Ekran ekwipunku rysuje siatki slotów w miejscu, gdzie na ekranie jest wnętrze pojemnika.

const KOM_M := 1.0 / 390.0          # metry na piksel siatki przy docelowym ujęciu (ok. 1,2 m od kamery)
const PRZOD := 0.72                 # odległość plecaka od stóp

var gracz: Gracz
var _kam: Camera3D
var _baza := Vector3.ZERO           # punkt na podłodze przed graczem
var _przod := Vector3.FORWARD
var _prawo := Vector3.RIGHT
var _modele := {}                   # co -> {"wezel", "wieko", "gora": Vector3 lokalnie, "w", "d", "tw"}
var _swiatlo: OmniLight3D


func przygotuj(g: Gracz) -> void:
	gracz = g
	_kam = g.kamera
	var b := g.global_basis
	_przod = (-b.z * Vector3(1, 0, 1)).normalized()
	_prawo = (b.x * Vector3(1, 0, 1)).normalized()
	_baza = g.global_position + _przod * PRZOD
	_baza.y = g.global_position.y + 0.02
	# słabe światło nad rozłożonym sprzętem (czołówka / poświata), żeby w ciemności było widać wnętrze
	_swiatlo = OmniLight3D.new()
	_swiatlo.light_color = Color(1.0, 0.9, 0.75)
	_swiatlo.light_energy = 0.0
	_swiatlo.omni_range = 1.8
	_swiatlo.shadow_enabled = false
	add_child(_swiatlo)
	_swiatlo.global_position = _baza + Vector3(0, 0.8, 0) - _przod * 0.25


## Wymiary pojemnika w metrach z rozmiaru siatki (żeby wnętrze na ekranie pasowało do kafelków).
func _wymiary(s: Siatka) -> Vector2:
	return Vector2(s.w * SiatkaUI.KOM * KOM_M + 0.09, s.h * SiatkaUI.KOM * KOM_M / 0.82 + 0.1)


func _poza_podlogi(co: String) -> Transform3D:
	var poz := _baza
	if co == "bezpieczny":
		var szer_p := 0.0
		if _modele.has("plecak"):
			szer_p = float(_modele["plecak"]["w"])
		elif gracz.ekw.siatka_plecaka() != null:
			szer_p = _wymiary(gracz.ekw.siatka_plecaka()).x
		var w: float = _modele["bezpieczny"]["w"] if _modele.has("bezpieczny") else 0.2
		poz += _prawo * (szer_p * 0.5 + w * 0.5 + 0.12) + _przod * 0.05 if szer_p > 0.0 else Vector3.ZERO
	var bas := Basis.looking_at(_przod, Vector3.UP)
	return Transform3D(bas, poz)


func _zbuduj(co: String, s: Siatka) -> Dictionary:
	var wym := _wymiary(s)
	var w := wym.x
	var d := wym.y
	var id := "kontener"
	if co in ["plecak", "kamizelka"] and gracz.ekw.sloty.get(co) != null:
		id = (gracz.ekw.sloty[co] as Przedmiot).id
	if co == "kamizelka":
		w = s.w * SiatkaUI.KOM * (1.0 / 1050.0) + 0.06
		d = s.h * SiatkaUI.KOM * (1.0 / 1050.0) + 0.06
	# osobny model dla każdego pojemnika z własną sekwencją otwierania
	var m := ModeleOporzadzenia.zbuduj(id, w, d)
	var wezel: Node3D = m["wezel"]
	add_child(wezel)
	for mi in wezel.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# wartości początkowe części ruchomych (do zamykania w odwrotnej kolejności)
	var start := []
	for krok in m["kroki"]:
		var st := []
		for zm in krok:
			st.append((zm[0] as Node3D).get_indexed(NodePath(String(zm[1]))))
		start.append(st)
	if co == "kamizelka":
		var sw := OmniLight3D.new()
		sw.light_color = Color(1.0, 0.9, 0.75)
		sw.light_energy = 0.6
		sw.omni_range = 0.9
		sw.position = Vector3(0, 0.12, 0.3)
		wezel.add_child(sw)
	return {"wezel": wezel, "wieko": null, "gora": m["gora"], "w": w, "d": d, "tw": null, "kroki": m["kroki"], "start": start, "id": id}


## Sekwencja otwierania (po kolei kroki, w kroku równolegle), dźwięki rzepów / zamka / klamer.
func _otworz_kroki(tw: Tween, m: Dictionary) -> void:
	for krok in m["kroki"]:
		var dl := 0.0
		for zm in krok:
			dl = maxf(dl, float(zm[3]))
		tw.tween_callback(func(): Dzwiek.graj("plecak", -14.0, randf_range(1.2, 1.6)))
		for zm in krok:
			tw.parallel().tween_property(zm[0], NodePath(String(zm[1])), zm[2], float(zm[3])).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.02)


func _zamknij_kroki(tw: Tween, m: Dictionary, skala: float) -> void:
	var kroki: Array = m.get("kroki", [])
	var start: Array = m.get("start", [])
	for i in range(kroki.size() - 1, -1, -1):
		var krok: Array = kroki[i]
		for j in krok.size():
			var zm: Array = krok[j]
			var tg := tw.parallel() if j > 0 else tw
			tg.tween_property(zm[0], NodePath(String(zm[1])), start[i][j], float(zm[3]) * skala).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


## Wyjęcie i rozłożenie pojemnika w czasie `czas` (zdjęcie z pleców / wyjęcie, położenie, otwarcie).
func otworz(co: String, s: Siatka, czas: float) -> void:
	if _modele.has(co):
		_usun(co)
	var m := _zbuduj(co, s)
	_modele[co] = m
	var wezel: Node3D = m["wezel"]
	var wieko: Node3D = m["wieko"]
	var tw := create_tween()
	m["tw"] = tw
	if co == "kamizelka":
		# kamizelka przy kamerze: wysunięta od dołu i przyciągnięta do przodu
		remove_child(wezel)
		_kam.add_child(wezel)
		wezel.position = Vector3(0.0, -0.42, -0.3)
		wezel.rotation = Vector3(-0.9, 0, 0)
		tw.tween_property(wezel, "position", Vector3(0.0, -0.17, -0.44), czas * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(wezel, "rotation", Vector3(-0.12, 0, 0), czas * 0.6)
		_otworz_kroki(tw, m)
		return
	var cel := _poza_podlogi(co)
	var start := Transform3D(Basis.from_euler(Vector3(1.2, 0.6, -0.4)) * _kam.global_basis.orthonormalized(),
		_kam.global_position + _kam.global_basis.x * 0.4 - _kam.global_basis.y * 0.45 - _kam.global_basis.z * 0.35)
	wezel.global_transform = start
	if wieko:
		wieko.rotation.x = 0.0
	var t1 := czas * (0.45 if co == "plecak" else 0.4)
	tw.tween_property(wezel, "global_transform", cel, t1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): Dzwiek.graj("odloz", -10.0, 0.8))
	_otworz_kroki(tw, m)
	if _swiatlo.light_energy < 0.6:
		create_tween().tween_property(_swiatlo, "light_energy", 0.7, czas)


## Zamknięcie i schowanie (odwrotna animacja), potem usunięcie modelu.
func zamknij(co: String, czas: float) -> void:
	if not _modele.has(co):
		return
	var m: Dictionary = _modele[co]
	if m["tw"] and (m["tw"] as Tween).is_valid():
		(m["tw"] as Tween).kill()
	var wezel: Node3D = m["wezel"]
	var wieko: Node3D = m["wieko"]
	var tw := create_tween()
	m["tw"] = tw
	_zamknij_kroki(tw, m, 0.6)
	if co == "kamizelka":
		tw.tween_property(wezel, "position", Vector3(0.0, -0.45, -0.3), czas * 0.5)
		tw.parallel().tween_property(wezel, "rotation", Vector3(-0.9, 0, 0), czas * 0.5)
		tw.tween_callback(_usun.bind(co))
		return
	var cel := Transform3D(_kam.global_basis.orthonormalized(), _kam.global_position + _kam.global_basis.x * 0.45 - _kam.global_basis.y * 0.5 - _kam.global_basis.z * 0.2)
	tw.tween_property(wezel, "global_transform", cel, czas * 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_usun.bind(co))


func zamknij_wszystko(czas: float) -> void:
	for co in _modele.keys():
		zamknij(co, czas)
	create_tween().tween_property(_swiatlo, "light_energy", 0.0, czas)
	get_tree().create_timer(czas + 0.05).timeout.connect(queue_free)


func _usun(co: String) -> void:
	if not _modele.has(co):
		return
	var w: Node3D = _modele[co]["wezel"]
	if is_instance_valid(w):
		w.queue_free()
	_modele.erase(co)


func ma(co: String) -> bool:
	return _modele.has(co)


## Środek wnętrza pojemnika na ekranie (piksele okna) albo null, gdy poza kadrem.
func punkt_ekranu(co: String) -> Variant:
	if not _modele.has(co) or _kam == null:
		return null
	var m: Dictionary = _modele[co]
	var wezel: Node3D = m["wezel"]
	if not is_instance_valid(wezel):
		return null
	var p: Vector3 = wezel.global_transform * Vector3(m["gora"])
	if _kam.is_position_behind(p):
		return null
	var vp := _kam.get_viewport()
	var skala := Vector2(Widok3D.POMNIEJSZENIE, Widok3D.POMNIEJSZENIE)
	if vp is SubViewport:
		var kont := vp.get_parent() as Control
		if kont:
			skala = kont.size / Vector2((vp as SubViewport).size)
	return _kam.unproject_position(p) * skala
