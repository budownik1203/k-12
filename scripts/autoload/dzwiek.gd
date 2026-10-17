extends Node
## Autoload "Dzwiek": odtwarzanie efektów 2D i 3D z puli odtwarzaczy.
## Pliki: res://assets/audio/<nazwa>.wav (brak pliku = cisza, bez błędu).

var _cache := {}
var _pula_3d: Array[AudioStreamPlayer3D] = []
var _pula_2d: Array[AudioStreamPlayer] = []
var _lp: AudioEffectLowPassFilter
var _przytl_t := 0.0
var _przytl_sila := 0.0


## Przytłumienie wszystkich dźwięków (ogłuszenie): filtr dolnoprzepustowy na szynie głównej, powoli wraca.
func przytlum(czas: float, sila: float) -> void:
	if _lp == null:
		_lp = AudioEffectLowPassFilter.new()
		_lp.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(0, _lp)
	_przytl_t = maxf(_przytl_t, czas)
	_przytl_sila = maxf(_przytl_sila, sila)


func _process(delta: float) -> void:
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
		p.bus = "Master"
		rodzic.add_child(p)
		_pula_3d.append(p)
		_pula_3d = _pula_3d.filter(func(x): return is_instance_valid(x))
	p.stream = s
	p.max_distance = zasieg
	p.volume_db = glosnosc_db + linear_to_db(Gra.ustawienia.get("glosnosc", 0.8))
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
