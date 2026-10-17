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
	var wezel := Node3D.new()
	add_child(wezel)
	var bryly := []
	var wieko_bryly := []
	var h := 0.1
	match co:
		"plecak":
			var tk := Color(0.27, 0.3, 0.2)
			var ciem := Color(0.12, 0.12, 0.09)
			h = 0.11
			# rozpięty worek: dno, niskie ściany, ciemne wnętrze, klamry
			bryly.append([Vector3(0, 0.02, 0), Vector3(w, 0.04, d), tk])
			bryly.append([Vector3(-w * 0.5 + 0.02, h * 0.5, 0), Vector3(0.04, h, d), tk])
			bryly.append([Vector3(w * 0.5 - 0.02, h * 0.5, 0), Vector3(0.04, h, d), tk])
			bryly.append([Vector3(0, h * 0.5, d * 0.5 - 0.02), Vector3(w, h, 0.04), tk])
			bryly.append([Vector3(0, h * 0.5, -d * 0.5 + 0.02), Vector3(w, h, 0.04), tk])
			bryly.append([Vector3(0, h * 0.5 - 0.02, 0), Vector3(w - 0.08, 0.01, d - 0.08), ciem])
			bryly.append([Vector3(-w * 0.5 - 0.02, h * 0.45, 0.0), Vector3(0.05, h * 0.6, d * 0.5), tk.darkened(0.15)])
			bryly.append([Vector3(w * 0.5 + 0.02, h * 0.45, 0.0), Vector3(0.05, h * 0.6, d * 0.5), tk.darkened(0.15)])
			# klapa: od zawiasu na dalszej krawędzi w stronę gracza
			wieko_bryly.append([Vector3(0, 0.015, d * 0.5), Vector3(w + 0.02, 0.03, d), tk.lightened(0.05)])
			wieko_bryly.append([Vector3(-w * 0.22, 0.034, d * 0.55), Vector3(0.04, 0.01, d * 0.9), ciem])
			wieko_bryly.append([Vector3(w * 0.22, 0.034, d * 0.55), Vector3(0.04, 0.01, d * 0.9), ciem])
			wieko_bryly.append([Vector3(-w * 0.22, 0.04, d * 0.95), Vector3(0.06, 0.02, 0.05), Color(0.5, 0.48, 0.4)])
			wieko_bryly.append([Vector3(w * 0.22, 0.04, d * 0.95), Vector3(0.06, 0.02, 0.05), Color(0.5, 0.48, 0.4)])
		"bezpieczny":
			var met := Color(0.33, 0.35, 0.31)
			h = 0.09
			bryly.append([Vector3(0, h * 0.5, 0), Vector3(w, h, d), met])
			bryly.append([Vector3(0, h - 0.004, 0), Vector3(w - 0.03, 0.01, d - 0.03), Color(0.09, 0.09, 0.08)])
			wieko_bryly.append([Vector3(0, 0.012, d * 0.5), Vector3(w + 0.01, 0.024, d + 0.01), met.lightened(0.08)])
			wieko_bryly.append([Vector3(0, 0.03, d * 0.9), Vector3(0.06, 0.02, 0.03), Color(0.6, 0.55, 0.3)])
		"kamizelka":
			var oliw := Color(0.3, 0.32, 0.22)
			# przód kamizelki przyciągnięty przed kamerę: płyta z ładownicami, szelki u góry
			w = s.w * SiatkaUI.KOM * (1.0 / 1050.0) + 0.06
			d = s.h * SiatkaUI.KOM * (1.0 / 1050.0) + 0.06
			bryly.append([Vector3(0, 0, -0.01), Vector3(w, d, 0.03), oliw])
			bryly.append([Vector3(0, 0, 0.006), Vector3(w - 0.03, d - 0.03, 0.006), Color(0.1, 0.1, 0.08)])
			bryly.append([Vector3(0, d * 0.5 + 0.012, -0.012), Vector3(w + 0.01, 0.025, 0.035), oliw.darkened(0.15)])
			bryly.append([Vector3(-w * 0.5 - 0.01, 0, -0.015), Vector3(0.02, d * 0.9, 0.03), oliw.darkened(0.15)])
			bryly.append([Vector3(w * 0.5 + 0.01, 0, -0.015), Vector3(0.02, d * 0.9, 0.03), oliw.darkened(0.15)])
	var mi := Kit.instancja(bryly)
	mi.material_override = Kit.material_kolor_vm()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wezel.add_child(mi)
	var wieko: Node3D = null
	if not wieko_bryly.is_empty():
		wieko = Node3D.new()
		wieko.position = Vector3(0, h, -d * 0.5)
		wezel.add_child(wieko)
		var wm := Kit.instancja(wieko_bryly)
		wm.material_override = Kit.material_kolor_vm()
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wieko.add_child(wm)
	if co == "kamizelka":
		# czołówka / poświata na ładownicach, żeby szybki dostęp działał też w ciemności
		var sw := OmniLight3D.new()
		sw.light_color = Color(1.0, 0.9, 0.75)
		sw.light_energy = 0.6
		sw.omni_range = 0.9
		sw.position = Vector3(0, 0.12, 0.3)
		wezel.add_child(sw)
	var gora := Vector3(0, h, 0) if co != "kamizelka" else Vector3(0, 0, 0.01)
	return {"wezel": wezel, "wieko": wieko, "gora": gora, "w": w, "d": d, "tw": null}


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
		tw.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(wezel, "position", Vector3(0.0, -0.17, -0.44), czas)
		tw.tween_property(wezel, "rotation", Vector3(-0.12, 0, 0), czas)
		return
	var cel := _poza_podlogi(co)
	var start := Transform3D(Basis.from_euler(Vector3(1.2, 0.6, -0.4)) * _kam.global_basis.orthonormalized(),
		_kam.global_position + _kam.global_basis.x * 0.4 - _kam.global_basis.y * 0.45 - _kam.global_basis.z * 0.35)
	wezel.global_transform = start
	if wieko:
		wieko.rotation.x = 0.0
	var t1 := czas * (0.6 if co == "plecak" else 0.5)
	tw.tween_property(wezel, "global_transform", cel, t1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): Dzwiek.graj("odloz", -10.0, 0.8))
	if wieko:
		tw.tween_property(wieko, "rotation:x", -2.75, czas - t1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	if co == "kamizelka":
		tw.set_parallel(true)
		tw.tween_property(wezel, "position", Vector3(0.0, -0.45, -0.3), czas)
		tw.tween_property(wezel, "rotation", Vector3(-0.9, 0, 0), czas)
		tw.chain().tween_callback(_usun.bind(co))
		return
	if wieko:
		tw.tween_property(wieko, "rotation:x", 0.0, czas * 0.35)
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
