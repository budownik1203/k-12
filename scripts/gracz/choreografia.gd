class_name Choreografia
extends RefCounted
## Odtwarzacz sekwencji ruchu rąk i części broni (przeładowania, sprawdzanie komór).
## Sekwencja to lista odcinków. Każdy odcinek startuje od bieżącego stanu (bez skoków) i w swoim czasie
## dochodzi do celów: lewa dłoń, obiekty (magazynek, naboje, łuski), kanały mechanizmu (lufy, rączka zamka,
## zamek pistoletu), przechył i przesunięcie całej broni. Cel może być funkcją wołaną co klatkę (np. komora
## na łamanych lufach – idzie razem z nimi).
## Przyczepianie: obiekt = "reka" jedzie w dłoni (z odstępem z chwili startu odcinka), a "reka_przy" = nazwa
## obiektu – dłoń trzyma obiekt, który prowadzi ruch. "doczep" ustawia obiekt w dłoni (wyjęty z kieszeni).
## "spadaj" puszcza obiekt z prędkością (wypada z dłoni, wybity magazynek).
## Wszystko w przestrzeni modelu broni (przód = -Z).

const GRAWITACJA := Vector3(0, -30.0, 0)      # jednostki modelu (skala widoku 0,3)

var odcinki: Array = []
var calosc := 0.0
var reka := Transform3D()
var reka_baza := Transform3D()
var chwyt := ""
var lok := Vector3(-0.2, -0.3, 0.28)          # łokieć względem nadgarstka
var obiekty := {}                             # nazwa -> Node3D (dziecko modelu)
var kanaly := {}                              # nazwa -> float
var bron_rot := Vector3.ZERO
var bron_poz := Vector3.ZERO
var kop: Callable                             # (Vector3 obrót, Vector3 przesunięcie) – szarpnięcie broni
var skonczona := false

var _i := -1
var _t0 := 0.0
var _st := {}             # stan na starcie odcinka
var _przyczep := {}       # obiekt -> offset względem dłoni
var _przy_off := Transform3D()
var _spada := {}          # obiekt -> {v, w}
var _ost_t := 0.0


## Dodaje odcinek. o: {t (s), ease ("gladko"|"liniowo"|"przysp"|"hamuj"|"trzask"), reka (Transform3D|Callable),
## reka_przy (nazwa), obiekty {nazwa: Transform3D|Callable|"reka"}, doczep {nazwa: Transform3D – obiekt w dłoni},
## spadaj {nazwa: Vector3 prędkość}, pokaz {nazwa: bool}, kanaly {nazwa: float}, bron [rot, poz], chwyt,
## lok (Vector3), dzw [[nazwa, gł], ...] na starcie, dzw_k na końcu, start/koniec (Callable), kop_k [rot, poz], nazwa}
func dodaj(o: Dictionary) -> void:
	odcinki.append(o)
	calosc += float(o["t"])


func indeks(nazwa: String) -> int:
	for i in odcinki.size():
		if String(odcinki[i].get("nazwa", "")) == nazwa:
			return i
	return -1


func start_odcinka(i: int) -> float:
	var t := 0.0
	for j in i:
		t += float(odcinki[j]["t"])
	return t


func biezacy() -> int:
	return _i


## Przeskok do odcinka (np. przerwanie ładowania strzałem); zwraca czas jego startu.
func skocz(i: int) -> float:
	_zacznij(i, start_odcinka(i))
	return _t0


## Skala czasu: rozciąga wszystkie odcinki tak, żeby całość trwała `czas`.
func skaluj(czas: float) -> void:
	if calosc <= 0.0:
		return
	var k := czas / calosc
	for o in odcinki:
		o["t"] = float(o["t"]) * k
	calosc = czas


func aktualizuj(t: float) -> void:
	if odcinki.is_empty() or skonczona:
		return
	var dt := maxf(0.0, t - _ost_t)
	_ost_t = t
	if _i < 0:
		_zacznij(0, 0.0)
	while true:
		var o: Dictionary = odcinki[_i]
		var kon := _t0 + float(o["t"])
		if t >= kon:
			_ustaw(1.0)
			_zakoncz(o)
			if _i + 1 < odcinki.size():
				_zacznij(_i + 1, kon)
				continue
			skonczona = true
			break
		_ustaw(clampf((t - _t0) / maxf(0.0001, float(o["t"])), 0.0, 1.0))
		break
	_spadanie(dt)


func _cel(v):
	if v is Callable:
		return (v as Callable).call()
	return v


func _zacznij(i: int, t0: float) -> void:
	_i = i
	_t0 = t0
	var o: Dictionary = odcinki[i]
	_st = {"reka": reka, "bron_rot": bron_rot, "bron_poz": bron_poz, "lok": lok, "kanaly": kanaly.duplicate(), "obiekty": {}}
	for n in o.get("pokaz", {}):
		if obiekty.has(n):
			(obiekty[n] as Node3D).visible = bool(o["pokaz"][n])
	for n in o.get("doczep", {}):
		if obiekty.has(n):
			var ob: Node3D = obiekty[n]
			ob.transform = reka * (o["doczep"][n] as Transform3D).affine_inverse()
			ob.visible = true
			_spada.erase(n)
	_przyczep.clear()
	for n in o.get("obiekty", {}):
		if not obiekty.has(n):
			continue
		var ob: Node3D = obiekty[n]
		_st["obiekty"][n] = ob.transform
		if typeof(o["obiekty"][n]) == TYPE_STRING and o["obiekty"][n] == "reka":
			_przyczep[n] = reka.affine_inverse() * ob.transform
		_spada.erase(n)
	for n in o.get("spadaj", {}):
		if obiekty.has(n):
			_spada[n] = {"v": o["spadaj"][n], "w": Vector3(randf_range(-9, 9), randf_range(-4, 4), randf_range(-9, 9)), "t": 0.0}
	if o.has("reka_przy") and obiekty.has(o["reka_przy"]):
		_przy_off = (obiekty[o["reka_przy"]] as Node3D).transform.affine_inverse() * reka
	if o.has("chwyt"):
		chwyt = o["chwyt"]
	for d in o.get("dzw", []):
		Dzwiek.graj(d[0], d[1], randf_range(0.96, 1.04))
	if o.has("start"):
		(o["start"] as Callable).call()


func _zakoncz(o: Dictionary) -> void:
	for d in o.get("dzw_k", []):
		Dzwiek.graj(d[0], d[1], randf_range(0.96, 1.04))
	if o.has("kop_k") and kop.is_valid():
		kop.call(o["kop_k"][0], o["kop_k"][1])
	if o.has("chwyt_k"):
		chwyt = o["chwyt_k"]
	if o.has("koniec"):
		(o["koniec"] as Callable).call()


static func _e(rodzaj: String, f: float) -> float:
	match rodzaj:
		"liniowo":
			return f
		"przysp":
			return f * f
		"hamuj":
			return 1.0 - (1.0 - f) * (1.0 - f)
		"trzask":
			return f * f * f
		"sprezyna":
			# dojście z lekkim przestrzeleniem
			return 1.0 - cos(f * PI * 1.25) * exp(-4.0 * f) * (1.0 - f)
	return f * f * (3.0 - 2.0 * f)


static func miesz(a: Transform3D, b: Transform3D, e: float) -> Transform3D:
	var qa := a.basis.orthonormalized().get_rotation_quaternion()
	var qb := b.basis.orthonormalized().get_rotation_quaternion()
	return Transform3D(Basis(qa.slerp(qb, clampf(e, 0.0, 1.0))), a.origin.lerp(b.origin, e))


func _ustaw(f: float) -> void:
	var o: Dictionary = odcinki[_i]
	var e := _e(String(o.get("ease", "gladko")), f)
	# kanały mechanizmu
	for n in o.get("kanaly", {}):
		var a := float(_st["kanaly"].get(n, 0.0))
		kanaly[n] = lerpf(a, float(_cel(o["kanaly"][n])), e)
	# przechył broni
	if o.has("bron"):
		bron_rot = (_st["bron_rot"] as Vector3).lerp(o["bron"][0], e)
		bron_poz = (_st["bron_poz"] as Vector3).lerp(o["bron"][1], e)
	if o.has("lok"):
		lok = (_st["lok"] as Vector3).lerp(o["lok"], e)
	# obiekty prowadzone celem
	for n in o.get("obiekty", {}):
		if not obiekty.has(n) or _przyczep.has(n):
			continue
		var cel: Transform3D = _cel(o["obiekty"][n])
		(obiekty[n] as Node3D).transform = miesz(_st["obiekty"][n], cel, e)
	# dłoń: przy obiekcie albo do celu
	if o.has("reka_przy") and obiekty.has(o["reka_przy"]):
		reka = (obiekty[o["reka_przy"]] as Node3D).transform * _przy_off
	elif o.has("reka"):
		reka = miesz(_st["reka"], _cel(o["reka"]), e)
	# obiekty w dłoni
	for n in _przyczep:
		(obiekty[n] as Node3D).transform = reka * (_przyczep[n] as Transform3D)


func _spadanie(dt: float) -> void:
	if dt <= 0.0:
		return
	for n in _spada.keys():
		var s: Dictionary = _spada[n]
		var ob: Node3D = obiekty.get(n)
		if ob == null or not is_instance_valid(ob):
			_spada.erase(n)
			continue
		s["t"] = float(s["t"]) + dt
		s["v"] = (s["v"] as Vector3) + GRAWITACJA * dt
		ob.position += (s["v"] as Vector3) * dt
		var w: Vector3 = s["w"]
		ob.basis = (Basis.from_euler(w * dt) * ob.basis).orthonormalized()
		if float(s["t"]) > 0.7:
			ob.visible = false
			_spada.erase(n)


func spada(n: String) -> bool:
	return _spada.has(n)


# ------------------------------------------------------------------ pozy dłoni

## Poza dłoni (jak Reka.chwyc): przedmiot w punkcie p leży w zgięciu palców; `os` – kierunek, wzdłuż którego
## układają się palce (od wskazującego do małego), `wnetrze` – w którą stronę patrzy wnętrze dłoni.
static func dlon(prawa: bool, p: Vector3, os: Vector3, wnetrze: Vector3, glebokosc := 0.075, odstep := 0.031) -> Transform3D:
	var xl := os.normalized() if prawa else -os.normalized()
	var yl := (-wnetrze).normalized()
	yl = (yl - xl * yl.dot(xl)).normalized()
	var zl := xl.cross(yl).normalized()
	var b := Basis(xl, yl, zl)
	return Transform3D(b, p - b * Vector3(0, -odstep, -glebokosc))


## Obrót wokół punktu (osie modelu, kąty w radianach).
static func obrot_wokol(punkt: Vector3, euler: Vector3) -> Transform3D:
	var b := Basis.from_euler(euler)
	return Transform3D(b, punkt - b * punkt)
