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
	var wd := ModeleOporzadzenia.wymiary(id, s)
	w = wd.x
	d = wd.y
	# osobny model dla każdego pojemnika; każda kieszeń ma własne zamknięcie (klapa, zamek, rzep, ściągacz)
	var kz_m := ModeleOporzadzenia.kieszenie_m(id, s)
	var m := ModeleOporzadzenia.zbuduj(id, w, d, kz_m)
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
	var kieszenie := []
	for kz in m.get("kieszenie", []):
		var st2 := []
		for krok in kz["kroki"]:
			var a := []
			for zm in krok:
				a.append((zm[0] as Node3D).get_indexed(NodePath(String(zm[1]))))
			st2.append(a)
		kieszenie.append({"kroki": kz["kroki"], "dzwieki": kz["dzwieki"], "start": st2, "otwarta": false, "tw": null})
	return {"wezel": wezel, "wieko": null, "gora": m["gora"], "w": w, "d": d, "tw": null, "kroki": m["kroki"], "start": start, "id": id, "kieszenie": kieszenie}


## Otwarcie jednej kieszeni (rozpięcie zamka, odpięcie klamer, rzep, ściągacz); zwraca czas.
func otworz_kieszen(co: String, i: int) -> float:
	if not _modele.has(co):
		return 0.0
	var kz: Array = _modele[co].get("kieszenie", [])
	if i < 0 or i >= kz.size() or bool(kz[i]["otwarta"]):
		return 0.0
	var e: Dictionary = kz[i]
	e["otwarta"] = true
	var tw := create_tween()
	e["tw"] = tw
	var czas := 0.0
	for j in (e["kroki"] as Array).size():
		var krok: Array = e["kroki"][j]
		var dz: String = e["dzwieki"][j] if j < (e["dzwieki"] as Array).size() else "plecak"
		var dl := 0.0
		for zm in krok:
			dl = maxf(dl, float(zm[3]))
		czas += dl + 0.03
		var jj := j
		tw.tween_callback(func(): _dzwiek(dz); _aktywuj(co, i, jj, dl + 0.1))
		for zm in krok:
			tw.parallel().tween_property(zm[0], NodePath(String(zm[1])), zm[2], float(zm[3])).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.03)
	return czas


## Stan kieszeni od razu (bez animacji) – po rozłożeniu pojemnika otwarte zostają otwarte.
func ustaw_stan(co: String, stany: Array) -> void:
	if not _modele.has(co):
		return
	_cicho = true
	var kz: Array = _modele[co].get("kieszenie", [])
	for i in mini(kz.size(), stany.size()):
		if bool(stany[i]):
			var e: Dictionary = kz[i]
			for k in (e["kroki"] as Array).size():
				ustaw_krok(co, i, k, 1.0)
			e["otwarta"] = true
	_cicho = false


func liczba_krokow(co: String, i: int) -> int:
	var e := _kieszen(co, i)
	return (e["kroki"] as Array).size() if not e.is_empty() else 0


## Rodzaj kroku do gestu: "klik" (klamra, zatrzask, guzik), "x" (suwak zamka w poprzek), "gora" (klapa,
## rzep, kołnierz – odciągnięcie materiału).
func rodzaj_kroku(co: String, i: int, k: int) -> String:
	var e := _kieszen(co, i)
	if e.is_empty():
		return "gora"
	var dz: String = e["dzwieki"][k] if k < (e["dzwieki"] as Array).size() else "plecak"
	match dz:
		"klik":
			return "klik"
		"zamek":
			return "x"
	return "gora"


func dzwiek_kroku(co: String, i: int, k: int) -> String:
	var e := _kieszen(co, i)
	if e.is_empty():
		return "plecak"
	return e["dzwieki"][k] if k < (e["dzwieki"] as Array).size() else "plecak"


func _kieszen(co: String, i: int) -> Dictionary:
	if not _modele.has(co):
		return {}
	var kz: Array = _modele[co].get("kieszenie", [])
	return kz[i] if i >= 0 and i < kz.size() else {}


## Postęp jednego kroku otwierania (0 = zamknięte, 1 = otwarte) – sterowany gestem myszy.
func ustaw_krok(co: String, i: int, k: int, f: float) -> void:
	var e := _kieszen(co, i)
	if e.is_empty() or k < 0 or k >= (e["kroki"] as Array).size():
		return
	if e.get("tw") and (e["tw"] as Tween).is_valid() and not _w_tweenie:
		(e["tw"] as Tween).kill()
	if not _cicho:
		_aktywuj(co, i, k, 0.35)
	var krok: Array = e["kroki"][k]
	for q in krok.size():
		var zm: Array = krok[q]
		var a = e["start"][k][q]
		var b = zm[2]
		var v = a
		if a is float or a is int:
			v = lerpf(float(a), float(b), f)
		elif a is Vector3:
			v = (a as Vector3).lerp(b, f)
		(zm[0] as Node).set_indexed(NodePath(String(zm[1])), v)


## Krok wykonany animacją (klik klamry): krótko.
func krok_anim(co: String, i: int, k: int, otworz_: bool, czas := 0.15) -> void:
	var e := _kieszen(co, i)
	if e.is_empty() or k < 0 or k >= (e["kroki"] as Array).size():
		return
	_aktywuj(co, i, k, czas + 0.25, true)
	var tw := create_tween()
	tw.tween_method(func(f): ustaw_krok(co, i, k, f), 0.0 if otworz_ else 1.0, 1.0 if otworz_ else 0.0, czas)


func oznacz(co: String, i: int, otw: bool) -> void:
	var e := _kieszen(co, i)
	if not e.is_empty():
		e["otwarta"] = otw


## Zamknięcie jednej kieszeni animacją (tryb prosty): kroki od końca.
func zamknij_kieszen(co: String, i: int) -> float:
	var e := _kieszen(co, i)
	if e.is_empty() or not bool(e["otwarta"]):
		return 0.0
	e["otwarta"] = false
	var tw := create_tween()
	e["tw"] = tw
	var czas := 0.0
	var kroki: Array = e["kroki"]
	for j in range(kroki.size() - 1, -1, -1):
		var dl := 0.0
		for zm in kroki[j]:
			dl = maxf(dl, float(zm[3]))
		czas += dl + 0.03
		var dz: String = e["dzwieki"][j] if j < (e["dzwieki"] as Array).size() else "plecak"
		var jj := j
		tw.tween_callback(func(): _dzwiek(dz); _aktywuj(co, i, jj, dl + 0.1))
		tw.tween_method(func(f): ustaw_krok(co, i, jj, f), 1.0, 0.0, dl)
		tw.tween_interval(0.03)
	return czas


# ------------------------------------------------------------------ dłoń przy zapięciach

var pokaz_reke := false      # dłoń przy zapięciach (wyłączona: tylko podświetlenie elementu)
var _reka: Reka
var _reka_cel := {}           # {"co", "i", "k"} – krok, przy którym pracuje dłoń
var _reka_t := 9.0            # ile jeszcze dłoń zostaje przy zapięciu
var _reka_klik := 0.0         # wciśnięcie klamry (krótki ruch palców)
var _reka_poz := Vector3(0.22, -0.5, -0.2)
var _cicho := false
var _w_tweenie := false
const _BARK := Vector3(0.26, -0.34, 0.1)
const _SPOCZYNEK := Vector3(0.24, -0.55, -0.15)


## Dłoń idzie do zapięcia, które teraz się rusza (gest gracza albo animacja), i trzyma się go.
func _aktywuj(co: String, i: int, k: int, czas: float, klik := false) -> void:
	_reka_cel = {"co": co, "i": i, "k": k}
	_reka_t = czas
	if klik:
		_reka_klik = 1.0


## Punkt chwytu kroku: wolny brzeg klapy / suwak / blokada sznurka (w świecie).
func _punkt_chwytu(co: String, i: int, k: int) -> Variant:
	var e := _kieszen(co, i)
	if e.is_empty() or k < 0 or k >= (e["kroki"] as Array).size():
		return null
	var zm: Array = e["kroki"][k][0]
	var n := zm[0] as Node3D
	if n == null or not is_instance_valid(n):
		return null
	var key := "chwyt_%d" % k
	if not e.has(key):
		# brzeg najdalej od zawiasu (góra, przód) z obrysu siatek węzła – liczony raz, w układzie węzła
		var ab := AABB()
		var pierwszy := true
		for mi in ([n] if n is MeshInstance3D else []) + n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var t := n.global_transform.affine_inverse() * m.global_transform
			var a := t * m.get_aabb()
			ab = a if pierwszy else ab.merge(a)
			pierwszy = false
		var lok := Vector3.ZERO
		if not pierwszy:
			if String(zm[1]).begins_with("blend"):
				lok = Vector3(ab.get_center().x, ab.end.y, ab.end.z * 0.85)
			elif String(zm[1]).begins_with("position"):
				lok = ab.get_center()
			else:
				# klapa: chwyt w ok. 60% długości od zawiasu (dłoń zostaje w kadrze, gdy klapa idzie w górę)
				var brzeg := ab.end.z if absf(ab.end.z) > absf(ab.position.z) else ab.position.z
				lok = Vector3(ab.get_center().x, ab.get_center().y, brzeg * 0.6)
		e[key] = lok
	return n.global_transform * Vector3(e[key])


func _exit_tree() -> void:
	if _reka and is_instance_valid(_reka):
		_reka.queue_free()


func _process(delta: float) -> void:
	if _kam == null or not is_instance_valid(_kam):
		return
	# kamizelka odsuwa się w prawo, gdy obok leży rozłożony plecak / worek (nie zasłaniają się nawzajem)
	if _modele.has("kamizelka"):
		var mk: Dictionary = _modele["kamizelka"]
		var tw: Tween = mk.get("tw")
		if tw == null or not tw.is_valid() or not tw.is_running():
			var inne := _modele.size() > 1
			var w: Node3D = mk["wezel"]
			if is_instance_valid(w):
				w.position.x = move_toward(w.position.x, 0.21 if inne else 0.0, delta * 0.6)
				w.position.y = move_toward(w.position.y, -0.2 if inne else -0.17, delta * 0.3)
				w.rotation.y = move_toward(w.rotation.y, -0.32 if inne else 0.0, delta * 1.2)
	_reka_t -= delta
	_reka_klik = maxf(0.0, _reka_klik - delta * 5.0)
	if not pokaz_reke:
		# bez dłoni przy zapięciach – element do chwycenia tylko się podświetla
		if _reka and is_instance_valid(_reka):
			_reka.visible = false
		return
	var cel_lok := _SPOCZYNEK
	var aktywna := false
	if _reka_t > 0.0 and not _reka_cel.is_empty():
		var p = _punkt_chwytu(_reka_cel["co"], _reka_cel["i"], _reka_cel["k"])
		if p != null:
			cel_lok = _kam.global_transform.affine_inverse() * (p as Vector3)
			aktywna = true
	if _reka == null:
		if not aktywna:
			return
		_reka = Reka.new(true, false, "otwarta", 0.5)
		_kam.add_child(_reka)
		_reka.position = _SPOCZYNEK
		_reka_poz = _SPOCZYNEK
	_reka.visible = aktywna or _reka_poz.distance_to(_SPOCZYNEK) > 0.05
	if gracz:
		_reka.ustaw_zdrowie(gracz.cialo.procent(), gracz.cialo.krwawi() > 0)
	# dłoń dochodzi do zapięcia z lekkim opóźnieniem (naturalnie, nie skokami)
	_reka_poz = _reka_poz.lerp(cel_lok, minf(1.0, delta * (14.0 if aktywna else 6.0)))
	var kier := (_reka_poz - _BARK).normalized()
	kier = (kier + Vector3(0, -0.6, 0)).normalized()
	var nadg := _reka_poz - kier * 0.07 + Vector3(0, 0.025, 0.02) - Vector3(0, 0.015, 0) * sin(_reka_klik * PI)
	_reka.celuj_lokiec(_BARK.lerp(nadg, 0.5) + Vector3(0.06, -0.12, 0.04), _kam)
	AnimacjeAkcji._uloz(_reka, nadg, kier, Vector3(0.15, 1.0, 0.25).normalized())
	_reka.ustaw_chwyt("piesc" if _reka_klik > 0.1 else ("szczypta" if aktywna else "otwarta"))


func ile_otwartych(co: String) -> int:
	var n := 0
	if _modele.has(co):
		for e in _modele[co].get("kieszenie", []):
			if bool(e["otwarta"]):
				n += 1
	return n


func _dzwiek(dz: String) -> void:
	match dz:
		"zamek":
			Dzwiek.graj("zamek", -9.0, randf_range(0.95, 1.1))
		"rzep":
			Dzwiek.graj("rzep", -9.0, randf_range(0.9, 1.1))
		"klik":
			Dzwiek.graj("klik", -10.0, randf_range(0.7, 0.85))
		_:
			Dzwiek.graj("plecak", -13.0, randf_range(1.1, 1.4))


## Zamyka wszystkie otwarte kieszenie (odwrotnie) w podanym tweenie.
func _zamknij_kieszenie(tw: Tween, m: Dictionary, skala: float) -> void:
	for e in m.get("kieszenie", []):
		if not bool(e["otwarta"]):
			continue
		e["otwarta"] = false
		if e["tw"] and (e["tw"] as Tween).is_valid():
			(e["tw"] as Tween).kill()
		var kroki: Array = e["kroki"]
		for j in range(kroki.size() - 1, -1, -1):
			var krok: Array = kroki[j]
			for q in krok.size():
				var zm: Array = krok[q]
				var tg := tw.parallel() if q > 0 else tw
				tg.tween_property(zm[0], NodePath(String(zm[1])), e["start"][j][q], float(zm[3]) * skala).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		var dz: String = e["dzwieki"][0] if not (e["dzwieki"] as Array).is_empty() else "plecak"
		tw.tween_callback(func(): _dzwiek(dz))


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
	# kieszenie zostają tak, jak je zostawiono (otwarte mogą gubić zawartość)
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
	_reka_t = 0.0
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


# ------------------------------------------------------------------ podświetlenie elementu do chwycenia

static var _mat_podsw: ShaderMaterial
static var _mat_podsw_akt: ShaderMaterial
var _podsw := {}              # MeshInstance3D -> true (z nakładką podświetlenia)


static func _mat_podswietlenia(sila: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec3 kolor = vec3(1.0, 0.84, 0.52);
uniform float sila = 0.5;
void fragment() {
	// delikatna poświata brzegów (fresnel), powoli pulsująca
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float puls = 0.7 + 0.3 * sin(TIME * 3.2);
	ALBEDO = kolor * (0.14 + fr * 0.6) * sila * puls;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("sila", sila)
	return m


static var _mat_lekki: ShaderMaterial


## Bardzo delikatna poświata (przeszukiwane zwłoki / mebel).
static func mat_lekki() -> ShaderMaterial:
	if _mat_lekki == null:
		_mat_lekki = _mat_podswietlenia(0.45)
	return _mat_lekki


static func mat_podswietlenia() -> ShaderMaterial:
	if _mat_podsw == null:
		_mat_podsw = _mat_podswietlenia(0.8)
		_mat_podsw_akt = _mat_podswietlenia(1.25)
	return _mat_podsw_akt


## Nakładka (podświetlenie) na wszystkie siatki węzła; null zdejmuje.
static func nakladka(n: Node, m: Material) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = m
	for c in n.get_children():
		nakladka(c, m)


func _wezel_kroku(co: String, i: int, k: int) -> Node3D:
	var e := _kieszen(co, i)
	if e.is_empty() or k < 0 or k >= (e["kroki"] as Array).size():
		return null
	var n := (e["kroki"][k][0] as Array)[0] as Node3D
	return n if n != null and is_instance_valid(n) else null


func _siatki_wezla(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_siatki_wezla(c))
	return out


## Podświetla elementy do chwycenia: lista [[co, i, k, aktywny], ...] (aktywny – pod kursorem / trzymany).
func podswietl(lista: Array) -> void:
	if _mat_podsw == null:
		_mat_podsw = _mat_podswietlenia(0.8)
		_mat_podsw_akt = _mat_podswietlenia(1.25)
	var nowe := {}
	for el in lista:
		var n := _wezel_kroku(el[0], el[1], el[2])
		if n == null:
			continue
		for mi in _siatki_wezla(n):
			nowe[mi] = bool(el[3]) or bool(nowe.get(mi, false))
	for mi in _podsw.keys():
		if not nowe.has(mi) and is_instance_valid(mi):
			(mi as MeshInstance3D).material_overlay = null
	for mi in nowe:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).material_overlay = _mat_podsw_akt if nowe[mi] else _mat_podsw
	_podsw = nowe


## Obszar elementu kroku na ekranie (rzut jego obrysu) – kliknięcie w niego chwyta element.
func obszar_ekran(co: String, i: int, k: int) -> Rect2:
	var n := _wezel_kroku(co, i, k)
	if n == null or _kam == null:
		return Rect2()
	var out := Rect2()
	var jest := false
	for mi in _siatki_wezla(n):
		var m := mi as MeshInstance3D
		var ab := m.get_aabb()
		for c in 8:
			var p = do_ekranu(m.global_transform * ab.get_endpoint(c))
			if p == null:
				continue
			if not jest:
				out = Rect2(p, Vector2.ZERO)
				jest = true
			else:
				out = out.expand(p)
	return out


## Punkt świata na ekranie (piksele okna) albo null, gdy za kamerą.
func do_ekranu(p: Vector3) -> Variant:
	if _kam == null or _kam.is_position_behind(p):
		return null
	var vp := _kam.get_viewport()
	var skala := Vector2(Widok3D.POMNIEJSZENIE, Widok3D.POMNIEJSZENIE)
	if vp is SubViewport:
		var kont := vp.get_parent() as Control
		if kont:
			skala = Widok3D.skala_ekranu(vp)
	return _kam.unproject_position(p) * skala


## Uchwyt kroku (klamra, suwak, brzeg klapy) na ekranie – tu gracz chwyta myszą.
func uchwyt_ekran(co: String, i: int, k: int) -> Variant:
	var p = _punkt_chwytu(co, i, k)
	if p == null:
		return null
	return do_ekranu(p)


## Droga uchwytu na ekranie od zamkniętego (0) do otwartego (1) – w tę stronę trzeba go przeciągnąć.
## f_teraz: bieżący postęp kroku (przywracany po pomiarze).
func droga_kroku(co: String, i: int, k: int, f_teraz: float) -> Vector2:
	var e := _kieszen(co, i)
	if e.is_empty() or k < 0 or k >= (e["kroki"] as Array).size():
		return Vector2.ZERO
	_cicho = true
	ustaw_krok(co, i, k, 0.0)
	var a = uchwyt_ekran(co, i, k)
	ustaw_krok(co, i, k, 1.0)
	var b = uchwyt_ekran(co, i, k)
	ustaw_krok(co, i, k, f_teraz)
	_cicho = false
	if a == null or b == null:
		return Vector2.ZERO
	return (b as Vector2) - (a as Vector2)


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
			skala = Widok3D.skala_ekranu(vp)
	return _kam.unproject_position(p) * skala
