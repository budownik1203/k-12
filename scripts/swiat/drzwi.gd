class_name Drzwi
extends Node3D
## Drzwi w otworze: skrzydło na zawiasach (AnimatableBody3D – blokuje przejście, wzrok i kule metalowych drzwi),
## otwierane i zamykane ręką (chwyt [F] + mysz; powoli = cicho); zamknięte na klucz – otwierane wytrychem
## albo wyważane kopniakami (głośno, kilka kopnięć, metalowe dłużej). Wrogowie otwierają drzwi na swojej
## drodze, zamknięte na klucz wyważają. Stojąc nieruchomo pod zamkniętymi drzwiami można podsłuchać,
## co jest za nimi.
##
## Układ lokalny: płaszczyzna otworu XY, +Z – strona, w którą otwiera się skrzydło (do pomieszczenia).

const B := preload("res://scripts/core/bryly.gd")
const KAT_PELNY := -1.62
const GR := 0.045

var szer := 1.2
var wys := 2.1
var rodzaj := "fornir"          # fornir / emalia / skaj / metal
var na_klucz := false
var kat := 0.0                  # 0 = zamknięte, ujemny = otwarte (do +Z)
var max_kat := KAT_PELNY
var wywazone := false
var wytrzymalosc := 3           # kopnięcia do wyważenia

var skrzydlo: AnimatableBody3D
var _zawias: Node3D
var _cel := 0.0
var _predkosc := 2.0
var _cichy := false
var _ai_t := 0.0
var _ai_czeka := {}
var _ai_kop_t := 0.0
var znane_zamkniecie := false   # gracz już szarpnął klamką i wie, że nie puszcza (zamek / klin z drugiej strony)
var _podsluch_t := 0.0
var _podsluch_cd := 0.0
var _szer_skrzydla := 1.1
var pulapka: Node = null
var przejmuje_mysz := true       # chwycone skrzydło: mysz pcha / ciągnie drzwi
var klin := false                # klin wbity od strony klin_strona – od drugiej strony drzwi nie ustępują
var klin_strona := 1.0
var _chwyt_v := 0.0              # prędkość skrzydła z ręki (po puszczeniu jeszcze chwilę się toczy)
var _grzech_t := 0.0
var _spr_pulapki := {}           # wróg -> czy zauważył pułapkę (raz przy podejściu)         # Pulapka: granat w szklance na klamce


## Ustawia drzwi w miejscu z generatora: {"p", "n", "w", "h"}.
func ustaw(m: Dictionary, rodz: String) -> void:
	szer = float(m["w"])
	wys = float(m["h"])
	rodzaj = rodz
	wytrzymalosc = 6 if rodzaj == "metal" else randi_range(2, 4)
	position = m["p"]
	basis = Basis.looking_at(-Vector3(m["n"]), Vector3.UP)


func _ready() -> void:
	add_to_group("drzwi")
	_zbuduj()
	_kat_wolny.call_deferred()


func _zbuduj() -> void:
	var fr := 0.05
	var kol_fr := Color(0.42, 0.3, 0.2) if rodzaj != "metal" else Color(0.32, 0.34, 0.3)
	var m_fr := "drewno_m" if rodzaj != "metal" else "metal_ciemny_m"
	# ościeżnica: dwa słupki i nadproże
	var cz := [
		{"t": "box", "c": Vector3(-szer * 0.5 + fr * 0.5, wys * 0.5, -0.01), "s": Vector3(fr, wys, 0.12), "m": m_fr, "k": kol_fr, "f": 0.006},
		{"t": "box", "c": Vector3(szer * 0.5 - fr * 0.5, wys * 0.5, -0.01), "s": Vector3(fr, wys, 0.12), "m": m_fr, "k": kol_fr, "f": 0.006},
		{"t": "box", "c": Vector3(0, wys - fr * 0.5, -0.01), "s": Vector3(szer, fr, 0.12), "m": m_fr, "k": kol_fr, "f": 0.006},
	]
	var mi := B.instancja(cz, false)
	add_child(mi)
	_zawias = Node3D.new()
	_zawias.position = Vector3(-szer * 0.5 + fr, 0, -GR * 0.5 - 0.005)
	add_child(_zawias)
	_szer_skrzydla = szer - fr * 2.0 - 0.008
	var lh := wys - fr - 0.012
	skrzydlo = AnimatableBody3D.new()
	skrzydlo.collision_layer = Balistyka.WARSTWA_SWIAT
	skrzydlo.collision_mask = 0
	skrzydlo.sync_to_physics = false
	skrzydlo.set_meta("interakcja", self)
	skrzydlo.set_meta("drzwi", self)
	skrzydlo.position = Vector3(_szer_skrzydla * 0.5, lh * 0.5 + 0.006, 0)
	_zawias.add_child(skrzydlo)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(_szer_skrzydla, lh, GR)
	cs.shape = bs
	skrzydlo.add_child(cs)
	var lm := B.instancja(_skrzydlo_czesci(_szer_skrzydla, lh), false)
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	skrzydlo.add_child(lm)


## Wygląd skrzydła wg rodzaju (współrzędne względem środka skrzydła).
func _skrzydlo_czesci(lw: float, lh: float) -> Array:
	var cz := []
	match rodzaj:
		"skaj":
			# obicie skajem z guzikami (romby) i wałkiem przy krawędzi
			var k := Color(0.36, 0.12, 0.1)
			cz.append({"t": "box", "c": Vector3.ZERO, "s": Vector3(lw, lh, GR), "m": "drewno_m", "k": Color(0.35, 0.25, 0.18), "f": 0.004})
			for sz in [-1.0, 1.0]:
				cz.append({"t": "box", "c": Vector3(0, 0, sz * (GR * 0.5 + 0.008)), "s": Vector3(lw - 0.04, lh - 0.04, 0.018), "m": "tkanina", "k": k, "f": 0.008})
				for iy in 7:
					for ix in 3:
						var x := (ix - 1) * lw * 0.28 + (lw * 0.14 if iy % 2 == 1 else 0.0)
						if absf(x) > lw * 0.42:
							continue
						var y := (iy - 3) * lh * 0.13
						var z: float = sz * (GR * 0.5 + 0.018)
						cz.append(B.walec(Vector3(x, y, z), Vector3(x, y, z + sz * 0.006), 0.009, 0.007, "mosiadz", 6))
		"emalia":
			var k2 := Color(0.86, 0.84, 0.76)
			cz.append({"t": "box", "c": Vector3.ZERO, "s": Vector3(lw, lh, GR), "m": "emalia_m", "k": k2, "f": 0.005})
			# górna szyba z matowego szkła w ramce
			for sz in [-1.0, 1.0]:
				cz.append({"t": "box", "c": Vector3(0, lh * 0.22, sz * (GR * 0.5 + 0.002)), "s": Vector3(lw * 0.62, lh * 0.36, 0.004), "m": "czern", "k": Color(0.55, 0.62, 0.62), "f": 0.0})
				cz.append({"t": "box", "c": Vector3(0, -lh * 0.24, sz * (GR * 0.5 + 0.002)), "s": Vector3(lw * 0.62, lh * 0.34, 0.004), "m": "emalia_m", "k": k2.darkened(0.06), "f": 0.002})
		"metal":
			var k3 := Color(0.36, 0.42, 0.32)
			cz.append({"t": "box", "c": Vector3.ZERO, "s": Vector3(lw, lh, GR), "m": "metal_zielony_m", "k": k3, "f": 0.003})
			for sz in [-1.0, 1.0]:
				for y in [-0.3, 0.0, 0.3]:
					cz.append({"t": "box", "c": Vector3(0, y * lh, sz * (GR * 0.5 + 0.006)), "s": Vector3(lw - 0.06, 0.05, 0.012), "m": "metal_zielony_m", "k": k3.darkened(0.12), "f": 0.004})
				for x in [-0.46, 0.46]:
					for y2 in [-0.45, -0.15, 0.15, 0.45]:
						var z2: float = sz * (GR * 0.5 + 0.003)
						cz.append(B.walec(Vector3(x * lw, y2 * lh, z2), Vector3(x * lw, y2 * lh, z2 + sz * 0.005), 0.007, 0.006, "metal_ciemny_m", 6))
		_:
			var k4 := Color(0.62, 0.45, 0.3)
			cz.append({"t": "box", "c": Vector3.ZERO, "s": Vector3(lw, lh, GR), "m": "fornir_m", "k": k4, "f": 0.005})
			for sz in [-1.0, 1.0]:
				for y in [0.24, -0.22]:
					cz.append({"t": "box", "c": Vector3(0, y * lh, sz * (GR * 0.5 + 0.003)), "s": Vector3(lw * 0.68, lh * 0.36, 0.006), "m": "fornir_m", "k": k4.darkened(0.12), "f": 0.004})
	# klamki i szyldy z dziurką od klucza po obu stronach
	var hx := lw * 0.5 - 0.075
	for sz in [-1.0, 1.0]:
		var z: float = sz * (GR * 0.5 + 0.004)
		var yk := 1.0 - lh * 0.5
		cz.append({"t": "box", "c": Vector3(hx, yk - 0.05, z), "s": Vector3(0.045, 0.22, 0.008), "m": "metal_jasny", "f": 0.003})
		cz.append({"t": "box", "c": Vector3(hx, yk - 0.11, z + sz * 0.005), "s": Vector3(0.008, 0.02, 0.004), "m": "czern", "f": 0.0})
		cz.append(B.walec(Vector3(hx, yk, z), Vector3(hx, yk, z + sz * 0.05), 0.009, 0.009, "metal_jasny", 8))
		cz.append(B.walec(Vector3(hx, yk, z + sz * 0.05), Vector3(hx - 0.11, yk - 0.008, z + sz * 0.055), 0.008, 0.007, "metal_jasny", 8))
	return cz


## Ile skrzydło może się otworzyć, zanim trafi na mebel lub ścianę (promienie z zawiasu).
func _kat_wolny() -> void:
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var pz := _zawias.global_position
	var naj := KAT_PELNY
	var a := -0.1
	while a >= KAT_PELNY:
		var kier := global_basis * Vector3(cos(a), 0, -sin(a))
		var traf := false
		for y in [0.4, 1.3]:
			var q := PhysicsRayQueryParameters3D.create(pz + Vector3.UP * y + kier * 0.05, pz + Vector3.UP * y + kier * (_szer_skrzydla + 0.02), Balistyka.WARSTWA_SWIAT)
			var wykl: Array[RID] = [skrzydlo.get_rid()]
			for pr in get_tree().get_nodes_in_group("przesuwne"):
				wykl.append((pr as CollisionObject3D).get_rid())
			q.exclude = wykl
			if not space.intersect_ray(q).is_empty():
				traf = true
		if traf:
			naj = minf(-0.25, a + 0.12)
			break
		a -= 0.1
	max_kat = naj
	kat = clampf(kat, max_kat, 0.0)
	_cel = clampf(_cel, max_kat, 0.0)
	_zawias.rotation.y = kat


## Stan początkowy (bez animacji): 0 zamknięte, ujemny – otwarte.
func ustaw_kat(k: float) -> void:
	kat = k
	_cel = k
	if _zawias:
		_zawias.rotation.y = k


func zamkniete() -> bool:
	return kat > -0.05


func srodek() -> Vector3:
	return global_transform * Vector3(0, 1.0, 0)


# ------------------------------------------------------------------ ruch

var _ostatni_otwierajacy: Node = null


func _otworz(do_kata: float, predkosc: float, cicho: bool, kto: Node = null) -> void:
	_ostatni_otwierajacy = kto
	do_kata = maxf(do_kata, max_kat)
	if zamkniete():
		Dzwiek.graj_3d("drzwi_skrzyp" if cicho else "drzwi_otworz", srodek(), get_parent(), -14.0 if cicho else -5.0, randf_range(0.92, 1.08), 18.0 if cicho else 28.0)
	elif cicho:
		Dzwiek.graj_3d("drzwi_skrzyp", srodek(), get_parent(), -16.0, randf_range(0.9, 1.1), 14.0)
	Gra.emituj_halas(srodek(), 2.5 if cicho else 8.0, kto)
	_cel = do_kata
	_predkosc = predkosc
	_cichy = cicho


func _zamknij(predkosc: float, cicho: bool, kto: Node = null) -> void:
	if cicho:
		Dzwiek.graj_3d("drzwi_skrzyp", srodek(), get_parent(), -18.0, randf_range(1.0, 1.15), 12.0)
	_cel = 0.0
	_predkosc = predkosc
	_cichy = cicho
	Gra.emituj_halas(srodek(), 2.0 if cicho else 4.0, kto)


func _physics_process(delta: float) -> void:
	if absf(kat - _cel) > 0.0005:
		var stary := kat
		var nowy := move_toward(kat, _cel, _predkosc * delta)
		# skrzydło nie przechodzi przez ludzi: stojący w świetle drzwi blokuje je (trzeba się odsunąć)
		var kto := _ktos_w_drodze(nowy)
		if kto is Przesuwny:
			# barykada: skrzydło opiera się o skrzynię / szafkę; wróg napiera (głośno) i po trochu ją spycha
			nowy = kat
			_blok_t += delta
			if _ostatni_otwierajacy is Wrog and _blok_t > 0.9:
				_blok_t = 0.0
				var pr := kto as Przesuwny
				var kier := ((pr.global_position - _zawias.global_position) * Vector3(1, 0, 1)).normalized()
				pr.apply_central_impulse(kier * pr.mass * 0.9)
				Dzwiek.graj_3d("drzwi_kopniak", srodek(), get_parent(), -2.0, randf_range(0.85, 1.0), 35.0)
				Gra.emituj_halas(srodek(), 18.0, _ostatni_otwierajacy)
		elif kto != null:
			# gracza drzwi nie przesuwają; wroga (który sam pcha drzwi na siebie) po chwili „mijają”
			_blok_t += delta
			if kto.is_in_group("gracz") or _blok_t < 0.8:
				nowy = kat
		else:
			_blok_t = 0.0
		# pułapka: każde poruszenie zamkniętego skrzydła zrzuca szklankę z klamki
		if pulapka and is_instance_valid(pulapka) and stary > -0.05 and nowy < stary - 0.01:
			pulapka.spust()
		kat = nowy
		_zawias.rotation.y = kat
		if _cel == 0.0 and kat == 0.0 and stary != 0.0:
			# zatrzaśnięcie
			Dzwiek.graj_3d("drzwi_zamknij", srodek(), get_parent(), -18.0 if _cichy else -4.0, randf_range(0.95, 1.05), 12.0 if _cichy else 30.0)
			if not _cichy:
				Gra.emituj_halas(srodek(), 10.0, null)
				# trzaśnięcie wstrząsa futryną: szklanka na sąsiednich drzwiach może spaść
				for pu in get_tree().get_nodes_in_group("pulapki"):
					if is_instance_valid(pu) and pu.drzwi != self and (pu as Node3D).global_position.distance_to(srodek()) < 3.0 and randf() < 0.35:
						pu.spust()
	_ai_t -= delta
	if _ai_t <= 0.0:
		_ai_t = 0.15
		_wrogowie(0.15)
		_podsluch(0.15)


var _ksztalt_q: PhysicsShapeQueryParameters3D
var _blok_t := 0.0


func _ktos_w_drodze(k: float) -> Node:
	if _ksztalt_q == null:
		_ksztalt_q = PhysicsShapeQueryParameters3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(_szer_skrzydla - 0.1, 1.6, GR + 0.02)
		_ksztalt_q.shape = bs
		_ksztalt_q.collision_mask = Balistyka.WARSTWA_POSTACIE | Przesuwny.WARSTWA
	var tz := Transform3D(Basis(Vector3.UP, k), _zawias.position) * Transform3D(Basis.IDENTITY, Vector3(_szer_skrzydla * 0.5 + 0.05, 0.95, 0))
	_ksztalt_q.transform = global_transform * tz
	var r := get_world_3d().direct_space_state.intersect_shape(_ksztalt_q, 1)
	return null if r.is_empty() else r[0]["collider"] as Node


# ------------------------------------------------------------------ gracz

## Gracz po stronie, po której wisi pułapka (widzi szklankę na klamce)?
func strona_pulapki(g) -> bool:
	if pulapka == null or not is_instance_valid(pulapka) or g == null:
		return false
	var s := 1.0 if (g.global_position - global_position).dot(global_basis.z) > 0.0 else -1.0
	return s == float(pulapka.strona)


func tekst_interakcji(g) -> String:
	if wywazone:
		return "Wyważone drzwi"
	if strona_pulapki(g):
		return "Rozbrój pułapkę (granat w szklance) – powoli"
	if klin and g != null:
		var st := 1.0 if (g.global_position - global_position).dot(global_basis.z) > 0.0 else -1.0
		if st == klin_strona:
			return "Wyjmij klin spod drzwi"
		elif zamkniete() and znane_zamkniecie:
			return "Zaklinowane od drugiej strony – wyważ kopniakami (głośno)"
	# z wyglądu drzwi nie widać, czy są zamknięte – trzeba nacisnąć klamkę
	if na_klucz and zamkniete() and znane_zamkniecie:
		if g != null and g.ekw.ma_przedmiot("wytrych"):
			return "Zamknięte na klucz – otwórz wytrychem (cicho)"
		return "Zamknięte na klucz – wyważ kopniakami (głośno)" if rodzaj != "metal" else "Zamknięte na klucz, metalowe – wyważ (bardzo głośno, długo)"
	if zamkniete():
		return "Drzwi – przytrzymaj [F] i pchnij myszą"
	return "Drzwi – przytrzymaj [F]: od siebie pchasz, do siebie ciągniesz"


func interakcja(g) -> void:
	if wywazone or not g.akcja.is_empty():
		return
	if strona_pulapki(g):
		pulapka.rozbroj(g)
		return
	if klin:
		var st := 1.0 if (g.global_position - global_position).dot(global_basis.z) > 0.0 else -1.0
		if st == klin_strona:
			g.zacznij_akcje("Wyjmowanie klina", 1.2, func(): wyjmij_klin(g), "podnies")
			return
		elif zamkniete():
			if not znane_zamkniecie:
				_szarpnij(g)
				return
			_kopnij(g)
			return
	if na_klucz and zamkniete():
		if not znane_zamkniecie:
			_szarpnij(g)
			return
		if g.ekw.ma_przedmiot("wytrych"):
			_wytrych(g)
		else:
			_kopnij(g)
		return
	# zwykłe drzwi otwiera i zamyka się tylko ręką: przytrzymaj [F] i ruszaj myszą (krótkie [F] nic nie robi)
	Gra.wskazowka("drzwi_reka", "Drzwi: przytrzymaj [F] na klamce i ruszaj myszą – od siebie pchasz, do siebie ciągniesz. Powoli – cicho, szybko – trzaśnie.")


var _slodki_kat := randf_range(15.0, 165.0)


# ------------------------------------------------------------------ chwyt ręką (fizyczne drzwi)

## Chwytać można zwykłe drzwi (nie wyważone, bez pułapki po stronie gracza, bez wytrychu w toku).
func mozna_chwycic(g) -> bool:
	return not wywazone and not strona_pulapki(g)


func chwyc(g) -> void:
	if g.has_method("patrz_na"):
		pass
	Dzwiek.graj_3d("klik", srodek(), get_parent(), -16.0, 0.6, 6.0)   # klamka


## Ruch myszy na chwyconej klamce: w górę / od siebie pcha skrzydło, w dół ciągnie do siebie. Szybki ruch
## – głośno (skrzypi, trzaska), powolny – cicho; zamknięte na klucz albo zaklinowane tylko szarpią.
func chwyc_ruch(g, m: Vector2, delta: float) -> void:
	var strona := 1.0 if (g.global_position - global_position).dot(global_basis.z) > 0.0 else -1.0
	var pchniecie := -m.y * 0.0045 + m.x * 0.0012 * strona
	# zaklinowane drzwi nie ustępują z żadnej strony – klin trzeba najpierw wyjąć (krótkie [F] od jego strony)
	if (na_klucz and zamkniete()) or (klin and zamkniete()):
		if absf(pchniecie) > 0.004:
			_grzech_t -= delta
			if _grzech_t <= 0.0:
				_grzech_t = 0.35
				znane_zamkniecie = true
				Dzwiek.graj_3d("drzwi_kopniak", srodek(), get_parent(), -18.0, 1.4, 10.0)
				Gra.emituj_halas(srodek(), 3.0, g)
				g.komunikat.emit("Zaklinowane – nie ustępują" if klin and not na_klucz else "Zamknięte na klucz")
		return
	# od strony +Z pchnięcie zamyka (kąt do 0), od −Z otwiera (kąt ujemny)
	var dk := pchniecie * (1.0 if strona > 0.0 else -1.0)
	var nowy := clampf(kat + dk, max_kat, 0.0)
	_chwyt_v = lerpf(_chwyt_v, (nowy - kat) / maxf(delta, 0.001), 0.5)
	_cel = nowy
	_predkosc = 9.0
	_cichy = absf(_chwyt_v) < 1.2
	if zamkniete() and nowy < -0.01:
		Dzwiek.graj_3d("drzwi_skrzyp" if _cichy else "drzwi_otworz", srodek(), get_parent(), -16.0 if _cichy else -6.0, randf_range(0.92, 1.08), 14.0 if _cichy else 26.0)
		Gra.emituj_halas(srodek(), 2.0 if _cichy else 7.0, g)
	elif absf(_chwyt_v) > 0.5 and randf() < delta * 2.0:
		Dzwiek.graj_3d("drzwi_skrzyp", srodek(), get_parent(), -20.0, randf_range(0.85, 1.15), 10.0)


## Naciśnięcie klamki zamkniętych drzwi: szarpnięcie, ciche stuknięcie – dopiero teraz wiadomo, że nie puszczają.
func _szarpnij(g) -> void:
	g.zacznij_akcje("Klamka", 0.5, func():
		znane_zamkniecie = true
		Dzwiek.graj_3d("drzwi_kopniak", srodek(), get_parent(), -18.0, 1.4, 10.0)
		Gra.emituj_halas(srodek(), 3.0, g)
		g.komunikat.emit("Klamka nie puszcza – zamknięte na klucz" if na_klucz else "Nie ustępują – coś je blokuje od drugiej strony")
		, "otwieranie", 0, Callable(), {"id": "drzwi"})


## Puszczona klamka: skrzydło toczy się jeszcze chwilę siłą rozpędu (pchnięte mocno – trzaśnie).
func pusc_chwyt(_g) -> void:
	if absf(_chwyt_v) > 0.4:
		_cel = clampf(kat + _chwyt_v * 0.35, max_kat, 0.0)
		_predkosc = clampf(absf(_chwyt_v), 0.4, 4.0)
		_cichy = absf(_chwyt_v) < 1.5
	_chwyt_v = 0.0


## Klin pod drzwi (od strony gracza): z drugiej strony nie da się ich otworzyć bez wyważania.
func wbij_klin(g) -> void:
	var strona := 1.0 if (g.global_position - global_position).dot(global_basis.z) > 0.0 else -1.0
	klin = true
	klin_strona = strona
	var B := preload("res://scripts/core/bryly.gd")
	var k := B.instancja([B.box(Vector3.ZERO, Vector3(0.06, 0.04, 0.14), "drewno", 0.005)], false)
	k.name = "Klin"
	add_child(k)
	k.position = Vector3(szer * 0.5 - 0.2, 0.02, strona * 0.1)
	Dzwiek.graj_3d("drzwi_kopniak", srodek(), get_parent(), -14.0, 1.6, 10.0)
	Gra.emituj_halas(srodek(), 3.0, g)


func wyjmij_klin(g) -> void:
	klin = false
	var k := get_node_or_null("Klin")
	if k:
		k.queue_free()
	if not g.ekw.dodaj(Przedmiot.nowy("klin")):
		g.upusc(Przedmiot.nowy("klin"))


## Wytrych: zbliżenie zamka i ręczne otwieranie (kąt haczyka + napięcie), nie automat.
func _wytrych(g) -> void:
	var w: Przedmiot = null
	for p in g.ekw.wszystkie():
		if (p as Przedmiot).id == "wytrych":
			w = p
			break
	if g.has_method("patrz_na"):
		g.patrz_na(global_transform * Vector3(szer * 0.5 - 0.14, 1.0, 0.0), 0.4, 0.3)
	Dzwiek.graj_3d("wytrych", srodek(), get_parent(), -10.0, randf_range(0.9, 1.1), 10.0)
	Gra.emituj_halas(srodek(), 3.0, g)
	var ui := WytrychUI.new()
	ui.drzwi = self
	ui.gracz = g
	ui.wytrych = w
	get_tree().current_scene.add_child(ui)


func _kopnij(g) -> void:
	g.zacznij_akcje("Wyważanie drzwi", 0.95, func():
		_uderzenie(g)
		if g.has_method("kopniecie"):
			g.kopniecie(2.5)
		if not wywazone:
			g.komunikat.emit("Drzwi trzeszczą – jeszcze raz" if rodzaj != "metal" else "Blacha dudni – zamek trzyma")
		, "otwieranie", 0, Callable(), {"id": "drzwi"})


## Jedno kopnięcie (gracz albo wróg): hałas, kurz, ubytek wytrzymałości, w końcu wyważenie.
func _uderzenie(kto: Node) -> void:
	var metal := rodzaj == "metal"
	Dzwiek.graj_3d("drzwi_metal_kopniak" if metal else "drzwi_kopniak", srodek(), get_parent(), 0.0, randf_range(0.92, 1.06), 45.0)
	Gra.emituj_halas(srodek(), 30.0 if metal else 24.0, kto)
	Efekty.kurz(get_parent(), global_transform * Vector3(0, 2.0, 0.1), 0.6)
	# skrzydło drga w futrynie
	var tw := create_tween()
	tw.tween_property(_zawias, "rotation:y", -0.03, 0.05)
	tw.tween_property(_zawias, "rotation:y", 0.0, 0.12)
	wytrzymalosc -= 1 if metal else randi_range(1, 2)
	if wytrzymalosc <= 0:
		_wywaz(kto)


func _wywaz(kto: Node) -> void:
	wywazone = true
	na_klucz = false
	if klin:
		klin = false
		var kn := get_node_or_null("Klin")
		if kn:
			kn.queue_free()
	Dzwiek.graj_3d("drzwi_wywaz", srodek(), get_parent(), 2.0, randf_range(0.95, 1.05), 50.0)
	Gra.emituj_halas(srodek(), 32.0, kto)
	var zamek := global_transform * Vector3(szer * 0.5 - 0.1, 1.0, 0.0)
	Efekty.czastki(get_parent(), zamek, global_basis.z, Color(0.55, 0.42, 0.3) if rodzaj != "metal" else Color(1.0, 0.8, 0.4), 18, 3.5)
	Efekty.kurz(get_parent(), zamek, 1.0)
	# skrzydło wpada do środka, odbija się i zostaje krzywo
	_cel = maxf(max_kat, -1.35)
	_predkosc = 7.0
	_cichy = true
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_instance_valid(self):
			_cel = maxf(max_kat, -1.05)
			_predkosc = 1.5)
	skrzydlo.rotation.z = deg_to_rad(randf_range(-2.0, 2.0))


# ------------------------------------------------------------------ wrogowie

func _wrogowie(dt: float) -> void:
	if wywazone or kat < -0.9:
		return
	var c := global_transform * Vector3(0, 0, 0)
	for w in get_tree().get_nodes_in_group("wrogowie"):
		if not is_instance_valid(w) or str(w.get("stan")) == "martwy":
			continue
		var wp: Vector3 = (w as Node3D).global_position
		var d := Vector2(wp.x - c.x, wp.z - c.z).length()
		if d > 1.5 or absf(wp.y - c.y) > 1.5:
			_ai_czeka.erase(w)
			continue
		var v: Vector3 = w.get("velocity") if w.get("velocity") != null else Vector3.ZERO
		var stoi_pod := float(_ai_czeka.get(w, 0.0))
		if w.has_method("chce_przez"):
			# człowiek otwiera tylko drzwi na swojej drodze (stojąc obok, nie szarpie klamki)
			if not w.chce_przez(self):
				_ai_czeka.erase(w)
				continue
		elif v.length() < 0.15 and stoi_pod <= 0.0 and d > 0.9:
			continue
		_ai_czeka[w] = stoi_pod + dt
		var zaklinowane := klin and zamkniete() and signf((wp - global_position).dot(global_basis.z)) != klin_strona
		if (na_klucz and zamkniete()) or zaklinowane:
			if w.is_in_group("fauna"):
				continue
			# wróg wyważa: najpierw chwilę szarpie klamkę
			_ai_kop_t -= dt
			if _ai_czeka[w] > 1.2 and _ai_kop_t <= 0.0:
				_ai_kop_t = 1.1
				_uderzenie(w)
			continue
		# pułapka po stronie wroga: może zauważyć szklankę na klamce – wtedy ją zdejmuje zamiast otwierać
		if pulapka and is_instance_valid(pulapka) and not w.is_in_group("fauna") and w.has_method("rozbroj_pulapke"):
			if w.get("_szaber_cel") == pulapka and str(w.get("stan")) == "szaber":
				_ai_czeka.erase(w)
				continue
			var ps := 1.0 if (wp - global_position).dot(global_basis.z) > 0.0 else -1.0
			if ps == float(pulapka.strona):
				if not _spr_pulapki.has(w):
					_spr_pulapki[w] = randf() < Pulapka.szansa_zauwazenia(w, pulapka.global_position)
				if _spr_pulapki[w]:
					w.rozbroj_pulapke(pulapka)
					_ai_czeka.erase(w)
					continue
		if _ai_czeka[w] > 0.3:
			var po_stronie := (wp - global_position).dot(global_basis.z) > 0.0
			_otworz(max_kat, 2.0 if not po_stronie else 1.5, false, w)
			_ai_czeka.clear()
			return


# ------------------------------------------------------------------ podsłuch

func _podsluch(dt: float) -> void:
	_podsluch_cd -= dt
	if kat < -0.5 or wywazone:
		_podsluch_t = 0.0
		return
	var g := get_tree().get_first_node_in_group("gracz") as Node3D
	if g == null:
		return
	var c := global_transform * Vector3(0, 0, 0)
	var gp := g.global_position
	if Vector2(gp.x - c.x, gp.z - c.z).length() > 1.3 or Vector2(g.get("velocity").x, g.get("velocity").z).length() > 0.3:
		_podsluch_t = 0.0
		return
	_podsluch_t += dt
	if _podsluch_t < 1.6 or _podsluch_cd > 0.0:
		return
	_podsluch_cd = 12.0
	var strona := signf((gp - c).dot(global_basis.z))
	var ile := 0
	var najblizej := 99.0
	var czujni := 0
	for w in get_tree().get_nodes_in_group("wrogowie"):
		if not is_instance_valid(w) or str(w.get("stan")) == "martwy":
			continue
		var wp: Vector3 = (w as Node3D).global_position
		if signf((wp - c).dot(global_basis.z)) == strona:
			continue
		var d := wp.distance_to(c)
		if d > 14.0:
			continue
		ile += 1
		najblizej = minf(najblizej, d)
		if str(w.get("stan")) in ["walka", "czujny", "szukanie"]:
			czujni += 1
	# przez drzwi słychać niepewnie: liczba i odległość to zgadywanie (czasem złe)
	if ile > 0 and randf() < 0.25:
		ile = maxi(1, ile + (1 if randf() < 0.5 else -1))
	if ile > 0 and randf() < 0.2:
		ile = 0          # stoją cicho – nic nie słychać
	var t: String
	if ile == 0:
		t = "Pod drzwiami: chyba cisza."
	elif get_tree().get_nodes_in_group("fauna").any(func(f): return is_instance_valid(f) and (f as Node3D).global_position.distance_to(c) < 14.0 and str(f.get("stan")) != "martwy"):
		t = "Za drzwiami: drapanie i klikanie. Coś tam jest."
	elif czujni > 0:
		t = "Za drzwiami: chyba szepty, szczęk metalu – ktoś %s." % ("czeka" if randf() < 0.7 else "się kręci")
	else:
		t = "Za drzwiami: kroki? %s" % ("Raczej blisko." if najblizej < 5.0 else ("Gdzieś w środku." if randf() < 0.7 else "Trudno powiedzieć, ile ich."))
	g.emit_signal("komunikat", t)
