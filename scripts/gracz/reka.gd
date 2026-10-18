class_name Reka
extends Node3D
## Dłoń z pierwszej osoby (jak w Iron Blight): śródręcze, cztery palce po trzy paliczki, kciuk, nadgarstek,
## rękaw kurtki; lewa ma zegarek, którego tarcza pokazuje stan zdrowia (krzyżyk zielony / żółty / czerwony).
## Układ: nadgarstek w (0,0,0), palce w stronę -Z, wnętrze dłoni w stronę -Y. Zginanie palców = obrót wokół X.

const DL_PALCOW := [0.074, 0.08, 0.075, 0.06]     # wskazujący, środkowy, serdeczny, mały
const PROM_PALCOW := [0.0088, 0.0092, 0.0086, 0.0076]
const PODZIAL := [0.45, 0.31, 0.24]
## chwyty: [zgięcia 4 palców (3 stawy, stopnie, ujemne = do wnętrza dłoni), kciuk [obrót, zgięcie1, zgięcie2], rozstaw palców]
const CHWYTY := {
	"pistolet": [[[-68, -88, -50], [-74, -90, -52], [-76, -88, -52], [-78, -84, -50]], [50, -25, -30], 0.0],
	"lozysko": [[[-55, -70, -40], [-58, -72, -42], [-62, -72, -44], [-64, -70, -42]], [25, -15, -20], 0.0],
	"spust": [[[-30, -42, -22], [-74, -90, -52], [-76, -88, -52], [-78, -84, -50]], [50, -25, -30], 0.0],
	"latarka": [[[-75, -85, -55], [-78, -88, -55], [-80, -86, -55], [-80, -82, -52]], [60, -30, -30], 0.0],
	"magazynek": [[[-40, -60, -30], [-50, -66, -36], [-56, -70, -40], [-60, -70, -40]], [30, -10, -15], 0.0],
	"strzal": [[[-52, -62, -34], [-74, -90, -52], [-76, -88, -52], [-78, -84, -50]], [50, -25, -30], 0.0],
	"szczypta": [[[-35, -45, -25], [-60, -80, -45], [-70, -85, -50], [-75, -82, -48]], [45, -15, -20], 0.0],
	"otwarta": [[[-12, -10, -6], [-10, -8, -6], [-12, -10, -6], [-14, -10, -6]], [-5, -4, -6], 0.04],
	"piesc": [[[-85, -95, -60], [-88, -95, -60], [-88, -95, -60], [-88, -92, -58]], [70, -40, -45], 0.0],
}

var prawa := true
var zegarek := false
var _palce: Array = []        # [[staw1, staw2, staw3], ...]
var _kciuk: Array = []        # [baza, staw1, staw2]
var _wskaznik: MeshInstance3D
var _mat_wsk: StandardMaterial3D
var _chwyt := "pistolet"
var _cel := {}                # docelowe kąty (płynne przejścia między chwytami)
var _rekaw_dl := 0.34
var _przedramie: Node3D
var _lokiec := Vector3.ZERO          # punkt łokcia w przestrzeni rodzica dłoni (model broni)
var _ma_lokiec := false


func _init(p_prawa := true, p_zegarek := false, chwyt := "pistolet", rekaw_dl := 0.34) -> void:
	prawa = p_prawa
	zegarek = p_zegarek
	_chwyt = chwyt
	_rekaw_dl = rekaw_dl


func _ready() -> void:
	_zbuduj()
	ustaw_chwyt(_chwyt, true)


func _strona() -> float:
	# po której stronie (x) jest kciuk: prawa dłoń wnętrzem w dół ma kciuk po lewej
	return -1.0 if prawa else 1.0


func _zbuduj() -> void:
	var s := _strona()
	# śródręcze: lekko zwężające się do palców, z wypukłością kłykci
	var dl := []
	dl.append(Bryly.box(Vector3(0, 0, -0.045), Vector3(0.08, 0.03, 0.09), "skora", 0.009))
	dl.append(Bryly.box(Vector3(s * 0.012, -0.006, -0.03), Vector3(0.05, 0.02, 0.05), "skora", 0.008))   # kłąb kciuka
	for i in 4:
		var x := -s * (-0.028 + i * 0.019)
		dl.append(Bryly.walec(Vector3(x, 0.006, -0.08), Vector3(x, 0.006, -0.092), 0.009, 0.0085, "skora", 6))
	# nadgarstek i przedramię
	dl.append(Bryly.walec(Vector3(0, 0, 0.012), Vector3(0, 0, -0.012), 0.024, 0.026, "skora", 8))
	add_child(Bryly.instancja(dl))
	# przedramię (z zegarkiem i rękawem) zgina się w nadgarstku – kierunek ustawia celuj_lokiec()
	_przedramie = Node3D.new()
	add_child(_przedramie)
	var od_rekawa := 0.02
	if zegarek:
		od_rekawa = 0.075
		_przedramie.add_child(Bryly.instancja([Bryly.walec(Vector3(0, 0, 0.0), Vector3(0, 0, od_rekawa + 0.01), 0.025, 0.029, "skora", 8)]))
	# rękaw kurtki z mankietem
	var rk := [
		Bryly.walec(Vector3(0, 0, od_rekawa), Vector3(0, 0, od_rekawa + 0.03), 0.039, 0.041, "mankiet", 8, 0.2),
		Bryly.walec(Vector3(0, 0, od_rekawa + 0.03), Vector3(0, -0.005, od_rekawa + _rekaw_dl), 0.041, 0.05, "rekaw", 8, 0.2),
	]
	_przedramie.add_child(Bryly.instancja(rk))
	if zegarek:
		_buduj_zegarek(0.038)
	# palce
	_palce.clear()
	for i in 4:
		var x := -s * (-0.028 + i * 0.019)
		var baza := Node3D.new()
		baza.position = Vector3(x, 0.002, -0.088)
		add_child(baza)
		var staw := baza
		var lancuch := []
		var dlug: float = DL_PALCOW[i]
		var r0: float = PROM_PALCOW[i]
		for j in 3:
			var seg_dl: float = dlug * PODZIAL[j]
			var n := Node3D.new()
			staw.add_child(n)
			if j > 0:
				n.position = Vector3(0, 0, -(dlug * PODZIAL[j - 1]))
			var r_a := r0 * (1.0 - j * 0.1)
			var r_b := r0 * (1.0 - (j + 1) * 0.1) * (0.8 if j == 2 else 1.0)
			var cz := [Bryly.walec(Vector3.ZERO, Vector3(0, 0, -seg_dl), r_a, r_b, "skora", 6)]
			if j == 2:
				cz.append(Bryly.box(Vector3(0, r_b * 0.75, -seg_dl * 0.62), Vector3(r_b * 1.5, 0.002, seg_dl * 0.6), "paznokiec", 0.0))
			n.add_child(Bryly.instancja(cz))
			lancuch.append(n)
			staw = n
		_palce.append(lancuch)
	# kciuk: baza obraca się wokół osi nadgarstka, dwa paliczki
	_kciuk.clear()
	var kb := Node3D.new()
	kb.position = Vector3(s * 0.03, -0.01, -0.022)
	kb.rotation = Vector3(deg_to_rad(-12.0), deg_to_rad(-s * 40.0), 0.0)
	add_child(kb)
	kb.add_child(Bryly.instancja([Bryly.walec(Vector3.ZERO, Vector3(0, 0, -0.04), 0.012, 0.0105, "skora", 6)]))
	var k1 := Node3D.new()
	k1.position = Vector3(0, 0, -0.04)
	kb.add_child(k1)
	k1.add_child(Bryly.instancja([Bryly.walec(Vector3.ZERO, Vector3(0, 0, -0.03), 0.0105, 0.0098, "skora", 6)]))
	var k2 := Node3D.new()
	k2.position = Vector3(0, 0, -0.03)
	k1.add_child(k2)
	k2.add_child(Bryly.instancja([
		Bryly.walec(Vector3.ZERO, Vector3(0, 0, -0.026), 0.0098, 0.0078, "skora", 6),
		Bryly.box(Vector3(0, 0.0075, -0.017), Vector3(0.012, 0.002, 0.014), "paznokiec", 0.0),
	]))
	_kciuk = [kb, k1, k2]


## Zegarek po wewnętrznej stronie nadgarstka (jak u postaci z Iron Blight – tarcza widoczna przy trzymaniu broni).
var zegarek_wewnatrz := true


func _buduj_zegarek(z: float) -> void:
	var g := -1.0 if zegarek_wewnatrz else 1.0
	# pasek wokół nadgarstka, koperta na wierzchu (+Y), tarcza z krzyżykiem-wskaźnikiem
	var cz := [
		Bryly.walec(Vector3(0, 0, z - 0.009), Vector3(0, 0, z + 0.009), 0.0305, 0.0305, "pasek", 10),
		Bryly.walec(Vector3(0, 0.026 * g, z), Vector3(0, 0.037 * g, z), 0.019, 0.018, "zegarek", 12),
		Bryly.walec(Vector3(0, 0.037 * g, z), Vector3(0, 0.0385 * g, z), 0.0165, 0.0165, "tarcza", 12, PI * 0.5),
		Bryly.box(Vector3(s_x(0.021), 0.032 * g, z), Vector3(0.005, 0.004, 0.004), "zegarek"),
	]
	var mi := Bryly.instancja(cz)
	mi.name = "Zegarek"
	_przedramie.add_child(mi)
	_mat_wsk = StandardMaterial3D.new()
	_mat_wsk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_wsk.albedo_color = Color(0.2, 1.0, 0.25)
	_wskaznik = Kit.instancja([
		[Vector3(0, 0.0392 * g, z), Vector3(0.0045, 0.0008, 0.016), Color.WHITE],
		[Vector3(0, 0.0392 * g, z), Vector3(0.016, 0.0008, 0.0045), Color.WHITE],
	])
	_wskaznik.material_override = _mat_wsk
	_wskaznik.set_meta("bryly", true)
	_wskaznik.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_przedramie.add_child(_wskaznik)


func s_x(x: float) -> float:
	return x * _strona()


## Kolor wskaźnika zdrowia na tarczy: zielony > 60%, żółty > 30%, czerwony (pulsuje) niżej.
func ustaw_zdrowie(procent: float, krwawi := false) -> void:
	if _mat_wsk == null:
		return
	var k := Color(0.25, 1.0, 0.3)
	if procent < 0.3:
		k = Color(1.0, 0.18, 0.12) * (0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 220.0)))
	elif procent < 0.6:
		k = Color(1.0, 0.86, 0.15)
	if krwawi and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.25:
		k = Color(1.0, 0.2, 0.15)
	_mat_wsk.albedo_color = k


func ustaw_chwyt(nazwa: String, od_razu := false) -> void:
	if not CHWYTY.has(nazwa):
		return
	_chwyt = nazwa
	var c: Array = CHWYTY[nazwa]
	_cel = {"palce": c[0], "kciuk": c[1], "rozstaw": c[2]}
	if od_razu:
		_zastosuj(1.0)


func _process(delta: float) -> void:
	if not _cel.is_empty():
		_zastosuj(clampf(delta * 14.0, 0.0, 1.0))
	if _ma_lokiec and _przedramie and is_inside_tree():
		_ustaw_przedramie()


## Przedramię celuje w łokieć (punkt w przestrzeni węzła `wzgledem`, np. modelu broni) – zgięcie w nadgarstku
## ograniczone do ok. 70°, żeby dłoń nie łamała się nienaturalnie.
var _wzgledem: Node3D


func celuj_lokiec(punkt: Vector3, wzgledem: Node3D) -> void:
	_lokiec = punkt
	_wzgledem = wzgledem
	_ma_lokiec = true
	if is_inside_tree():
		_ustaw_przedramie()


func _ustaw_przedramie() -> void:
	if _wzgledem == null or not is_instance_valid(_wzgledem):
		return
	var cel_g := _wzgledem.global_transform * _lokiec
	var lok := global_transform.affine_inverse() * cel_g
	var d := lok.normalized()
	if d.length() < 0.5:
		return
	# ograniczenie zgięcia: mieszanie z osią +Z dłoni
	var kat := Vector3(0, 0, 1).angle_to(d)
	if kat > deg_to_rad(70.0):
		d = Vector3(0, 0, 1).slerp(d, deg_to_rad(70.0) / kat).normalized()
	var gora := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	_przedramie.basis = Basis.looking_at(-d, gora)


func _zastosuj(t: float) -> void:
	var s := _strona()
	for i in _palce.size():
		var katy: Array = _cel["palce"][i]
		var lancuch: Array = _palce[i]
		for j in 3:
			var n: Node3D = lancuch[j]
			n.rotation.x = lerp_angle(n.rotation.x, deg_to_rad(float(katy[j])), t)
		var roz: float = float(_cel["rozstaw"]) * (i - 1.5) * -s
		(lancuch[0] as Node3D).rotation.y = lerp_angle((lancuch[0] as Node3D).rotation.y, roz * 4.0, t)
	if _kciuk.size() == 3:
		var kc: Array = _cel["kciuk"]
		var kb: Node3D = _kciuk[0]
		# obrót kciuka: dodatni = w stronę palców (przed wnętrze dłoni)
		kb.rotation.y = lerp_angle(kb.rotation.y, deg_to_rad(-s * (40.0 - float(kc[0]))), t)
		(_kciuk[1] as Node3D).rotation.x = lerp_angle((_kciuk[1] as Node3D).rotation.x, deg_to_rad(float(kc[1])), t)
		(_kciuk[2] as Node3D).rotation.x = lerp_angle((_kciuk[2] as Node3D).rotation.x, deg_to_rad(float(kc[2])), t)


## Ustawia dłoń tak, żeby przedmiot o osi `os_przedmiotu` (kierunek, wzdłuż którego układają się palce –
## od wskazującego do małego) w punkcie `punkt` leżał w zgięciu palców; `wnetrze` – kierunek, w który
## zwrócone jest wnętrze dłoni. Wszystko w przestrzeni rodzica dłoni.
func chwyc(punkt: Vector3, os_przedmiotu: Vector3, wnetrze: Vector3, glebokosc := 0.075, odstep := 0.031) -> void:
	var s := _strona()
	# lokalne X: od wskazującego (x = s*0.028... dla prawej -0.028) do małego
	var xl: Vector3
	if prawa:
		xl = os_przedmiotu.normalized()
	else:
		xl = -os_przedmiotu.normalized()
	var yl := (-wnetrze).normalized()
	yl = (yl - xl * yl.dot(xl)).normalized()
	var zl := xl.cross(yl).normalized()
	basis = Basis(xl, yl, zl)
	position = punkt - basis * Vector3(0, -odstep, -glebokosc)
