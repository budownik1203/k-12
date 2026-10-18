extends Node
## Autoload "Dzwiek": odtwarzanie efektów 2D i 3D z puli odtwarzaczy.
## Pliki: res://assets/audio/<nazwa>.wav (brak pliku = cisza, bez błędu).

var _cache := {}
var _pula_3d: Array[AudioStreamPlayer3D] = []
var _pula_2d: Array[AudioStreamPlayer] = []
var _lp: AudioEffectLowPassFilter
var _przytl_t := 0.0
var _przytl_sila := 0.0
var _reverb: AudioEffectReverb
var _ak_cel := {"room_size": 0.3, "wet": 0.08, "damping": 0.6}
## Ustawiane przez scenę rajdu: Callable(pos) -> String (podłoże) i Callable(pos) -> Dictionary (akustyka).
var podloze_fn: Callable
var akustyka_fn: Callable
var _ak_t := 0.0
const WARIANTY := {"krok_lastryko": 4, "krok_parkiet": 4, "krok_kafelki": 4, "krok_beton": 4, "krok_gruz": 4,
	"krok_dywan": 4, "krok_blacha": 4, "luska": 3, "szelest": 3, "kapanie": 3, "strzaly_daleko": 3,
	"glos_krzyk": 3, "glos_komenda": 3, "glos_ranny": 3}
## Pogłos wg typu pomieszczenia: [room_size, wet, damping]
const POGLOS := {"piwnica": [0.75, 0.32, 0.35], "magazyn": [0.85, 0.34, 0.3], "warsztat": [0.6, 0.24, 0.45],
	"klatka": [0.8, 0.36, 0.25], "korytarz": [0.55, 0.22, 0.4], "kuchnia": [0.35, 0.16, 0.35],
	"pokoj": [0.25, 0.08, 0.75], "administracja": [0.3, 0.1, 0.7], "zewnatrz": [0.9, 0.05, 0.9]}


func _ready() -> void:
	# szyna "Swiat": dźwięki 3D z pogłosem zależnym od miejsca, w którym stoi słuchacz
	if AudioServer.get_bus_index("Swiat") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Swiat")
		AudioServer.set_bus_send(i, "Master")
		_reverb = AudioEffectReverb.new()
		_reverb.room_size = 0.3
		_reverb.wet = 0.08
		_reverb.dry = 1.0
		_reverb.damping = 0.6
		_reverb.predelay_msec = 25.0
		_reverb.hipass = 0.15
		AudioServer.add_bus_effect(i, _reverb)


## Nazwa losowego wariantu dźwięku ("krok_beton" -> "krok_beton_2").
func wariant(baza: String) -> String:
	var n: int = WARIANTY.get(baza, 0)
	return baza if n == 0 else "%s_%d" % [baza, randi() % n]


## Krok na podłożu pod pozycją (wariant losowy; bez mapy – stary dźwięk).
func krok(pozycja: Vector3, rodzic: Node, glosnosc_db := 0.0, wysokosc := 1.0, zasieg := 40.0) -> void:
	var n := "krok"
	if podloze_fn.is_valid():
		n = wariant("krok_" + str(podloze_fn.call(pozycja)))
	graj_3d(n, pozycja, rodzic, glosnosc_db, wysokosc, zasieg)


func _sluchacz() -> Camera3D:
	var vp := get_viewport()
	return vp.get_camera_3d() if vp else null


## Przytłumienie wszystkich dźwięków (ogłuszenie): filtr dolnoprzepustowy na szynie głównej, powoli wraca.
func przytlum(czas: float, sila: float) -> void:
	if _lp == null:
		_lp = AudioEffectLowPassFilter.new()
		_lp.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(0, _lp)
	_przytl_t = maxf(_przytl_t, czas)
	_przytl_sila = maxf(_przytl_sila, sila)


func _process(delta: float) -> void:
	# pogłos płynnie dopasowuje się do pomieszczenia słuchacza
	if _reverb:
		_ak_t -= delta
		if _ak_t <= 0.0:
			_ak_t = 0.4
			var cam := _sluchacz()
			if akustyka_fn.is_valid() and cam:
				var a: Dictionary = akustyka_fn.call(cam.global_position)
				var v: Array = POGLOS.get(a.get("typ", "pokoj"), [0.3, 0.1, 0.6])
				var duze := clampf((float(a.get("pole", 30.0)) - 25.0) / 60.0, 0.0, 0.25)
				_ak_cel = {"room_size": clampf(v[0] + duze, 0.0, 0.95), "wet": v[1], "damping": v[2]}
			else:
				_ak_cel = {"room_size": 0.3, "wet": 0.06, "damping": 0.6}
		var k := minf(1.0, delta * 1.5)
		_reverb.room_size = lerpf(_reverb.room_size, _ak_cel["room_size"], k)
		_reverb.wet = lerpf(_reverb.wet, _ak_cel["wet"], k)
		_reverb.damping = lerpf(_reverb.damping, _ak_cel["damping"], k)
	if _lp == null:
		return
	if _przytl_t > 0.0:
		_przytl_t -= delta
		var f := clampf(_przytl_t / 1.5, 0.0, 1.0) * _przytl_sila
		_lp.cutoff_hz = lerpf(20000.0, 500.0, f)
	else:
		_przytl_sila = 0.0
		_lp.cutoff_hz = 20000.0


func _strumien(nazwa: String) -> AudioStream:
	if not _cache.has(nazwa):
		var path := "res://assets/audio/%s.wav" % nazwa
		_cache[nazwa] = load(path) if ResourceLoader.exists(path) else null
	return _cache[nazwa]


## Gra dźwięk w świecie. rodzic: węzeł 3D, do którego świata należy dźwięk.
func graj_3d(nazwa: String, pozycja: Vector3, rodzic: Node, glosnosc_db := 0.0, wysokosc := 1.0, zasieg := 40.0) -> void:
	var s := _strumien(nazwa)
	if s == null or rodzic == null or not rodzic.is_inside_tree():
		return
	var p: AudioStreamPlayer3D = null
	for q in _pula_3d:
		if is_instance_valid(q) and not q.playing and q.get_parent() == rodzic:
			p = q
			break
	if p == null:
		p = AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 4.0
		p.bus = "Swiat" if AudioServer.get_bus_index("Swiat") >= 0 else "Master"
		rodzic.add_child(p)
		_pula_3d.append(p)
		_pula_3d = _pula_3d.filter(func(x): return is_instance_valid(x))
	p.stream = s
	p.max_distance = zasieg
	# okluzja: między źródłem a słuchaczem ściana – ciszej i głucho (słychać zza ściany, ale stłumione)
	var okl := _okluzja(pozycja, rodzic)
	p.attenuation_filter_cutoff_hz = lerpf(9000.0, 900.0, okl)
	p.attenuation_filter_db = lerpf(-12.0, -30.0, okl)
	p.volume_db = glosnosc_db - okl * 9.0 + linear_to_db(Gra.ustawienia.get("glosnosc", 0.8))
	p.pitch_scale = wysokosc * randf_range(0.94, 1.06)
	p.global_position = pozycja
	p.play()


func graj(nazwa: String, glosnosc_db := 0.0, wysokosc := 1.0) -> void:
	var s := _strumien(nazwa)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for q in _pula_2d:
		if not q.playing:
			p = q
			break
	if p == null:
		p = AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pula_2d.append(p)
	p.stream = s
	p.volume_db = glosnosc_db + linear_to_db(Gra.ustawienia.get("glosnosc", 0.8))
	p.pitch_scale = wysokosc * randf_range(0.96, 1.04)
	p.play()


## Zapętlony dźwięk tła (ambient) jako dziecko podanego węzła.
func ambient(nazwa: String, rodzic: Node, glosnosc_db := -8.0) -> AudioStreamPlayer:
	var s := _strumien(nazwa)
	if s == null:
		return null
	if s is AudioStreamWAV:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		s = w
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = glosnosc_db + linear_to_db(Gra.ustawienia.get("glosnosc", 0.8))
	rodzic.add_child(p)
	p.play()
	return p


## 0 = słychać wprost, 1 = za ścianą (lub dwiema). Promień od źródła do słuchacza po warstwie świata.
func _okluzja(pozycja: Vector3, rodzic: Node) -> float:
	var cam := _sluchacz()
	if cam == null or not (rodzic is Node3D):
		return 0.0
	var ucho := cam.global_position
	var d := pozycja.distance_to(ucho)
	if d < 1.5 or d > 60.0:
		return 0.0
	var space := (rodzic as Node3D).get_world_3d().direct_space_state
	var od := pozycja + Vector3.UP * 0.15
	var q := PhysicsRayQueryParameters3D.create(od, ucho, Balistyka.WARSTWA_SWIAT)
	var r := space.intersect_ray(q)
	if r.is_empty():
		return 0.0
	# druga przeszkoda dalej = głębiej stłumione
	var q2 := PhysicsRayQueryParameters3D.create((r["position"] as Vector3) + (ucho - od).normalized() * 0.35, ucho, Balistyka.WARSTWA_SWIAT)
	return 1.0 if not space.intersect_ray(q2).is_empty() else 0.7


## Zapętlony dźwięk 3D (np. brzęczenie świetlówki) jako dziecko węzła.
func petla_3d(nazwa: String, rodzic: Node, glosnosc_db := -10.0, zasieg := 8.0) -> AudioStreamPlayer3D:
	var s := _strumien(nazwa)
	if s == null or rodzic == null:
		return null
	if s is AudioStreamWAV:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		s = w
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	p.unit_size = 2.0
	p.max_distance = zasieg
	p.bus = "Swiat" if AudioServer.get_bus_index("Swiat") >= 0 else "Master"
	p.volume_db = glosnosc_db + linear_to_db(Gra.ustawienia.get("glosnosc", 0.8))
	rodzic.add_child(p)
	p.play()
	return p
