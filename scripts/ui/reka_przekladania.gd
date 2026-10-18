class_name RekaPrzekladania
extends Node3D
## Dłoń przekładająca przedmiot w ekwipunku (rajd): sięga do slotu, chwyta, unosi przedmiot (model 3D)
## i przenosi go łukiem nad docelowe miejsce, odkłada i puszcza. Działa w przestrzeni kamery
## (węzeł jest dzieckiem kamery); punkty startu i celu podaje ekran ekwipunku.

const SPOCZYNEK := Vector3(0.2, -0.36, -0.32)

var reka: Reka
var _model: Node3D
var _od := Vector3.ZERO
var _do := Vector3.ZERO
var _start_dloni := SPOCZYNEK
var _t := 0.0
var _czas := 1.0
var aktywna := false
var _powrot := 0.0          # po odłożeniu: dłoń wraca w dół kadru
var _koniec_dloni := SPOCZYNEK
var gracz: Node
var _ciezar := 0.0
var _skala := 1.0


func _ready() -> void:
	reka = Reka.new(true, false, "otwarta", 0.5)
	add_child(reka)
	reka.celuj_lokiec(Vector3(0.34, -0.55, 0.12), self)
	reka.position = SPOCZYNEK
	visible = false


## Start przenoszenia: od / do – punkty w układzie kamery.
func zacznij(p: Przedmiot, od: Vector3, do_: Vector3, czas: float) -> void:
	if _model:
		_model.queue_free()
		_model = null
	_skala = 1.0
	_model = ModelePrzedmiotow.wezel(p, true)
	add_child(_model)
	_model.visible = false
	# duże przedmioty trzymane bliżej (bez zasłaniania całego kadru)
	var ab: AABB = _model.get_meta("aabb", AABB())
	var najw := maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
	if najw > 0.35:
		_skala = (0.35 / najw) * 1.4
	_od = od
	_do = do_
	_ciezar = p.waga()
	_start_dloni = reka.position if visible and _powrot > 0.0 else SPOCZYNEK
	_t = 0.0
	_czas = maxf(0.3, czas)
	_powrot = 0.0
	aktywna = true
	visible = true


## Przerwanie (np. trafienie): przedmiot wypada z ręki.
func przerwij() -> void:
	aktywna = false
	if _model:
		_model.queue_free()
		_model = null
	_koniec_dloni = reka.position
	_powrot = 0.001


func postep() -> float:
	return clampf(_t / _czas, 0.0, 1.0)


func _process(delta: float) -> void:
	if gracz and reka:
		reka.ustaw_zdrowie(gracz.cialo.procent(), gracz.cialo.krwawi() > 0)
	if not aktywna:
		if _powrot > 0.0:
			_powrot += delta / 0.35
			var e := smoothstep(0.0, 1.0, minf(1.0, _powrot))
			reka.position = _koniec_dloni.lerp(SPOCZYNEK + Vector3(0, -0.12, 0.05), e)
			reka.ustaw_chwyt("otwarta")
			if _powrot >= 1.0:
				_powrot = 0.0
				visible = false
		return
	_t += delta
	var f := postep()
	# fazy: sięgnięcie (0–0,3), chwyt (0,3–0,4), przeniesienie łukiem (0,4–0,8), odłożenie (0,8–0,92), puszczenie
	var nad_od := _od + Vector3(0, 0.03, 0.04)
	var nad_do := _do + Vector3(0, 0.03, 0.04)
	var poz: Vector3
	var trzyma := false
	if f < 0.3:
		poz = _start_dloni.lerp(nad_od, smoothstep(0.0, 0.3, f))
	elif f < 0.4:
		var e := smoothstep(0.3, 0.4, f)
		poz = nad_od.lerp(_od, sin(e * PI) * 0.8 + e * 0.2)
		trzyma = f > 0.35
	elif f < 0.8:
		var e2 := smoothstep(0.4, 0.8, f)
		poz = nad_od.lerp(nad_do, e2)
		# łuk: uniesienie ku kamerze i do góry w połowie drogi
		poz += Vector3(0, 0.05, 0.06) * sin(e2 * PI)
		trzyma = true
	elif f < 0.92:
		var e3 := smoothstep(0.8, 0.92, f)
		poz = nad_do.lerp(_do, e3)
		trzyma = true
	else:
		poz = _do.lerp(nad_do + Vector3(0.03, 0.02, 0.05), smoothstep(0.92, 1.0, f))
	# ręka wyprostowana od barku: palce w linii bark → dłoń, przy chwycie i odkładaniu nadgarstek
	# zgina się w dół (dłoń nad przedmiotem); łokieć w połowie drogi, nisko – przedramię w prawym dolnym
	# rogu kadru zamiast przez cały ekran
	var bark := Vector3(0.26, -0.34, 0.1)
	var kier := (poz - bark).normalized()
	var blisko_celu := 1.0 - smoothstep(0.0, 0.12, minf(poz.distance_to(_od), poz.distance_to(_do)))
	kier = (kier + Vector3(0, -0.9, 0) * blisko_celu + Vector3(0, -0.25, 0)).normalized()
	var nadg := poz - kier * 0.085
	var lokiec := bark.lerp(nadg, 0.5) + Vector3(0.07, -0.13, 0.04)
	reka.celuj_lokiec(lokiec, self)
	# drobne drżenie przy ciężkich przedmiotach
	if trzyma and _ciezar > 2.0:
		nadg += Vector3(sin(_t * 23.0), cos(_t * 19.0), 0) * 0.0015 * minf(4.0, _ciezar)
	AnimacjeAkcji._uloz(reka, nadg, kier, Vector3(0.15, 1.0, 0.25).normalized())
	reka.ustaw_chwyt("piesc" if trzyma else "otwarta")
	if _model:
		_model.visible = trzyma
		if trzyma:
			# przedmiot trzymany pod palcami (widać go spod dłoni)
			_model.position = poz + kier * 0.02 + Vector3(0, -0.03, 0)
			# przedmiot trzymany przechyla się z dłonią, cięższy zwisa
			_model.basis = Basis.looking_at(Vector3(kier.x, 0.0, kier.z).normalized() if absf(kier.x) + absf(kier.z) > 0.01 else Vector3.FORWARD, Vector3.UP) * Basis(Vector3.RIGHT, 0.2 + minf(0.4, _ciezar * 0.05)) * Basis.from_scale(Vector3.ONE * _skala)
	if f >= 1.0:
		aktywna = false
		if _model:
			_model.queue_free()
			_model = null
		_koniec_dloni = reka.position
		_powrot = 0.001
