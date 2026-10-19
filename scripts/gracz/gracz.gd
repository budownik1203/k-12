class_name Gracz
extends CharacterBody3D
## Gracz w widoku pierwszoosobowym: ruch z bezwładnością zależną od wagi, kucanie, wychylenia,
## sprint z wytrzymałością, rany (Cialo), leczenie z czasem, interakcje i broń.

signal komunikat(tekst: String)
signal zginal(przyczyna: String)
signal trafiony_sygnal(kierunek: Vector3, czesc: String)

const PREDKOSC_CHOD := 2.45
const PREDKOSC_BIEG := 4.5
const PREDKOSC_KUC := 1.2
const WYS_STOJ := 1.62
const WYS_KUC := 0.98
const MASKA_INTERAKCJI := Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_INTERAKCJE

var ekw: Ekwipunek
var cialo: Cialo
var glowa: Node3D
var kamera: Camera3D
var bron: Bron
var latarka: SpotLight3D
var hitbox: Area3D
var ksztalt: CollisionShape3D

var sterowanie := true
var aktywny_slot := "glowna"
var kucanie := 0.0
var wychylenie := 0.0
var wytrzymalosc := 100.0
var akcja := {}              # {"nazwa", "t", "czas", "koniec": Callable}
var cel_interakcji: Node = null
var tekst_interakcji := ""
var halas_ruchu := 0.0       # 0..1 do HUD
var tryb_bazy := false       # w bazie: bez broni i leczenia

var _pitch := 0.0
var _odrzut := Vector2.ZERO
var _odrzut_cel := Vector2.ZERO
var _krok := 0.0
var _vy_poprzednie := 0.0
var _y_spadania := 0.0
var _w_powietrzu := false
var _bol_t := 0.0
var _trafienie_shake := 0.0
var _biegnie := false
var latarka_w_rece := false     # latarka w lewej ręce (sama albo z pistoletem)
var latarka_wlaczona := true
var latarka_broni_wl := false   # latarka taktyczna na broni
var _kop := 0.0                 # kopnięcie kamery po strzale
var _kam_kop := Vector3.ZERO    # sprężyna kamery po strzale: (pochylenie, odchylenie, przechył)
var _kam_kop_v := Vector3.ZERO
var oglusz := 0.0               # ogłuszenie po trafieniu w hełm (sekundy, malejąco)
var ruch_z_ekwipunkiem := false  # szybka kamizelka (2x Tab): wolny marsz z otwartymi ładownicami
var ekw_pitch := 0.0            # widok przy ekwipunku: spojrzenie w dół, przechył, przysiad
var ekw_roll := 0.0
var ekw_glowa := 0.0
var _ekw_tw: Tween
var latarka_poswiata: SpotLight3D   # szeroki, słaby snop wokół jasnego środka
var latarka_odblask: OmniLight3D    # światło odbite na dłoniach
var _latarka_t := 0.0
var _bob_t := 0.0
var _bob_amp := 0.0
var _ladowanie := 0.0        # ugięcie kamery po wylądowaniu
var _przechyl := 0.0


func _init() -> void:
	collision_layer = Balistyka.WARSTWA_POSTACIE
	collision_mask = Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_POSTACIE
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50)


func _ready() -> void:
	add_to_group("gracz")
	ekw = Gra.ekw
	cialo = Cialo.new(Gra.zdrowie)
	cialo.smierc.connect(_smierc)
	cialo.uraz.connect(func(t): komunikat.emit(t))
	ksztalt = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	ksztalt.shape = cap
	ksztalt.position.y = 0.875
	add_child(ksztalt)
	hitbox = Area3D.new()
	hitbox.collision_layer = Balistyka.WARSTWA_HITBOX_GRACZA
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var hs := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 0.28
	hcap.height = 1.75
	hs.shape = hcap
	hs.position.y = 0.875
	hitbox.add_child(hs)
	hitbox.set_meta("gracz", self)
	add_child(hitbox)
	glowa = Node3D.new()
	glowa.position.y = WYS_STOJ
	add_child(glowa)
	kamera = Camera3D.new()
	kamera.fov = Gra.ustawienia.get("fov", 75.0)
	kamera.near = 0.02
	kamera.far = 80.0
	kamera.current = true
	glowa.add_child(kamera)
	latarka = SpotLight3D.new()
	latarka.position = Vector3(-0.08, -0.14, -0.15)
	# żarówka latarki: ciepły, wąski jasny środek z cieniem + szeroka słaba poświata
	latarka.light_color = Color(1.0, 0.9, 0.72)
	latarka.light_energy = 3.4
	latarka.spot_range = 22.0
	latarka.spot_angle = 14.0
	latarka.spot_angle_attenuation = 1.6
	latarka.spot_attenuation = 1.1
	latarka.shadow_enabled = true
	latarka.shadow_bias = 0.04
	latarka.visible = false
	kamera.add_child(latarka)
	latarka_poswiata = SpotLight3D.new()
	latarka_poswiata.light_color = Color(1.0, 0.88, 0.68)
	latarka_poswiata.light_energy = 0.9
	latarka_poswiata.spot_range = 14.0
	latarka_poswiata.spot_angle = 36.0
	latarka_poswiata.spot_angle_attenuation = 0.7
	latarka_poswiata.spot_attenuation = 1.3
	latarka.add_child(latarka_poswiata)
	latarka_odblask = OmniLight3D.new()
	latarka_odblask.light_color = Color(1.0, 0.9, 0.75)
	latarka_odblask.light_energy = 0.35
	latarka_odblask.omni_range = 0.9
	latarka_odblask.position = Vector3(0, 0, 0.25)
	latarka.add_child(latarka_odblask)
	bron = Bron.new()
	bron.gracz = self
	bron.kamera = kamera
	kamera.add_child(bron)
	bron.komunikat.connect(func(t): komunikat.emit(t))
	if not tryb_bazy:
		_wybierz_bron(aktywny_slot if ekw.sloty[aktywny_slot] != null else ("pistolet" if ekw.sloty["pistolet"] != null else "glowna"))
	ekw.zmieniony.connect(_ekw_zmieniony)


func _ekw_zmieniony() -> void:
	if tryb_bazy:
		return
	# puste ręce, a broń trafiła do slotu (podniesiona z ziemi / z łupu) – od razu w ręce
	var nb := ekw.nowa_bron
	ekw.nowa_bron = ""
	if nb != "" and bron.przedmiot == null and not latarka_w_rece and ekw.sloty.get(nb) != null:
		_wybierz_bron(nb)
		return
	# broń mogła zostać zdjęta w ekwipunku
	if bron.przedmiot != ekw.sloty.get(aktywny_slot):
		var inny := "pistolet" if aktywny_slot == "glowna" else "glowna"
		if ekw.sloty[aktywny_slot] != null:
			_wybierz_bron(aktywny_slot)
		elif ekw.sloty[inny] != null:
			_wybierz_bron(inny)
		else:
			bron.ustaw(null)


func _wybierz_bron(slot: String) -> void:
	if tryb_bazy:
		bron.ustaw(null)
		return
	aktywny_slot = slot
	var p: Przedmiot = ekw.sloty.get(slot) if slot != "" else null
	# latarka zostaje w ręce tylko z pistoletem (karabin trzyma się oburącz)
	if p != null and p.defn()["bron"]["slot"] != "pistolet":
		latarka_w_rece = false
	if latarka_w_rece and not ekw.ma_wyposazenie("latarka"):
		latarka_w_rece = false
	bron.ustaw(p, latarka_w_rece)
	_odswiez_latarke()
	Dzwiek.graj("klik", -14.0, 0.7)


func _odswiez_latarke() -> void:
	latarka.visible = not tryb_bazy and ((latarka_w_rece and latarka_wlaczona) or (not latarka_w_rece and bron.ma_latarke_broni() and latarka_broni_wl))
	bron.swiecenie_szkla(latarka.visible)
	latarka.position = Vector3(-0.03, -0.17, -0.15) if bron.przedmiot != null else Vector3(-0.09, -0.14, -0.15)


## Wyciąga latarkę: z pistoletem (gdy jest) albo samą. sama=true wymusza samą latarkę.
func wez_latarke(sama := false) -> void:
	if not ekw.ma_wyposazenie("latarka"):
		komunikat.emit("Brak latarki na slocie wyposażenia (pas/kamizelka)" if ekw.znajdz_id("latarka").is_empty() == false else "Nie masz latarki")
		return
	latarka_w_rece = true
	latarka_wlaczona = true
	if not sama and ekw.sloty["pistolet"] != null:
		_wybierz_bron("pistolet")
	elif not sama and bron.przedmiot != null and bron.jest_pistolet():
		_wybierz_bron(aktywny_slot)
	else:
		_wybierz_bron("")
	Dzwiek.graj("klik", -8.0)


## Widok przy ekwipunku: "kamizelka" – spojrzenie w dół na ładownice, "plecak" – zdjęcie plecaka
## (przysiad, przechył), "" – powrót. Zwraca czas animacji.
func widok_ekwipunku(tryb: String) -> float:
	if _ekw_tw and _ekw_tw.is_valid():
		_ekw_tw.kill()
	_ekw_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var cel := [0.0, 0.0, 0.0]
	var czas := 0.3
	match tryb:
		"kamizelka":
			# zerknięcie w dół na przyciągniętą do przodu kamizelkę
			cel = [-0.42, 0.0, 0.04]
			czas = 0.3
		"plecak":
			# przyklęk i spojrzenie na rozłożony przed sobą plecak (ok. 0,7 m od stóp)
			cel = [-0.95, 0.0, 0.6]
			czas = 0.9
	_ekw_tw.tween_property(self, "ekw_pitch", (cel[0] - _pitch) if tryb != "" else 0.0, czas)
	_ekw_tw.tween_property(self, "ekw_roll", cel[1], czas)
	_ekw_tw.tween_property(self, "ekw_glowa", cel[2], czas)
	if tryb != "":
		bron.animacja_akcji("schowaj")
	else:
		bron.animacja_akcji(String(akcja.get("typ", "")) if not akcja.is_empty() else "")
	return czas


## Zwrócenie się ku punktowi (mebel, zwłoki): obrót ciała, spojrzenie, opcjonalny przyklęk.
## Cofa to widok_ekwipunku("").
func patrz_na(punkt: Vector3, czas: float, przysiad := 0.0) -> void:
	if _ekw_tw and _ekw_tw.is_valid():
		_ekw_tw.kill()
	var oko := glowa.global_position - Vector3.UP * (przysiad - ekw_glowa)
	var d := punkt - oko
	var poz := Vector2(d.x, d.z)
	if poz.length() < 0.05:
		return
	var yaw := atan2(-d.x, -d.z)
	var dy := wrapf(yaw - rotation.y, -PI, PI)
	var pitch := clampf(atan2(d.y, poz.length()), deg_to_rad(-80), deg_to_rad(60))
	_ekw_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ekw_tw.tween_property(self, "rotation:y", rotation.y + dy, czas)
	_ekw_tw.tween_property(self, "ekw_pitch", pitch - _pitch, czas)
	_ekw_tw.tween_property(self, "ekw_glowa", przysiad, czas)
	_ekw_tw.tween_property(self, "ekw_roll", 0.0, czas)


## Przy upadku z wysokości albo ogłuszeniu coś drobnego może wypaść z kieszeni spodni (bez klapek).
func wypadnij_z_kieszeni(szansa: float) -> void:
	if tryb_bazy or randf() > szansa or ekw.kieszenie.items.is_empty():
		return
	var kand := ekw.kieszenie.items.filter(func(e): return (e["p"] as Przedmiot).szer() * (e["p"] as Przedmiot).wys() <= 1 and not (e["p"] as Przedmiot).dane.get("oznaczony", false))
	if kand.is_empty():
		return
	var p: Przedmiot = kand.pick_random()["p"]
	ekw.kieszenie.usun(p)
	ekw.zmieniony.emit()
	var l := upusc(p)
	komunikat.emit("Coś wypadło ci z kieszeni: " + p.nazwa())
	if l:
		l.rzut_z = global_position + Vector3.UP * 0.9


## Ogłuszenie (trafienie w hełm): biały błysk, pisk w uszach, przytłumiony dźwięk, drżenie i spowolnienie.
func ogluszenie(sila: float, tekst: String) -> void:
	oglusz = maxf(oglusz, 1.0 + sila * 3.0)
	if sila > 0.6:
		wypadnij_z_kieszeni(0.25)
	_odrzut_cel += Vector2(randf_range(-3.0, 3.0), randf_range(2.0, 5.0)) * sila
	_trafienie_shake = maxf(_trafienie_shake, sila * 1.5)
	if sila > 0.4:
		Dzwiek.graj("pisk", lerpf(-14.0, -3.0, sila))
	Dzwiek.przytlum(1.0 + sila * 3.0, sila)
	get_tree().call_group("hud", "ogluszenie", sila)
	if tekst != "":
		komunikat.emit(tekst)


## Kopnięcie kamery przy strzale (fov i drżenie), silniejsze dla mocniejszej broni.
func kopniecie(sila: float) -> void:
	_kop = minf(1.5, _kop + 0.35 + sila * 0.09)
	# gładkie szarpnięcie głowy (sprężyna) zamiast losowego drżenia: podbicie, lekki przechył w losową stronę
	_kam_kop_v += Vector3(-(0.6 + sila * 0.22), randf_range(-0.25, 0.25) * sila * 0.3, randf_range(-1.0, 1.0) * (0.35 + sila * 0.12)) * 25.0 * lerpf(1.0, 0.6, bron.ads)


func waga() -> float:
	return ekw.waga()


## Próg obciążenia: 0 lekki, 1 obciążony, 2 przeciążony, 3 krytyczny.
func prog_obciazenia() -> int:
	var w := waga()
	if w < 18.0:
		return 0
	if w < 28.0:
		return 1
	if w < 40.0:
		return 2
	return 3


func dodaj_odrzut(v: Vector2) -> void:
	_odrzut_cel += v


# ------------------------------------------------------------------ pętla

func _physics_process(delta: float) -> void:
	cialo.tick(delta)
	if cialo.martwy:
		return
	var we_aktywne := sterowanie and not Sterowanie.blokada
	_rozgladanie(delta, we_aktywne)
	_ruch(delta, we_aktywne or (sterowanie and ruch_z_ekwipunkiem))
	_akcje(delta)
	_interakcje(we_aktywne)
	_bron(delta, we_aktywne)
	_dzwieki_ciala(delta)
	_potrzeby(delta)
	_wypadanie_t -= delta
	if _wypadanie_t <= 0.0:
		_wypadanie_t = 0.25
		_wypadanie(0.25)
	przygniecenie = maxf(0.0, przygniecenie - delta * 0.3)
	_samouczek_t -= delta
	if _samouczek_t <= 0.0:
		_samouczek_t = 0.5
		_samouczek()
	if we_aktywne and Input.is_action_just_pressed("granat"):
		rzuc_granat()
	if we_aktywne and Input.is_action_just_pressed("latarka"):
		if latarka_w_rece:
			latarka_wlaczona = not latarka_wlaczona
			_odswiez_latarke()
			Dzwiek.graj("klik", -10.0)
		elif bron.ma_latarke_broni():
			latarka_broni_wl = not latarka_broni_wl
			_odswiez_latarke()
			Dzwiek.graj("klik", -10.0, 1.3)
		else:
			wez_latarke()
	# snop wychodzi z soczewki trzymanej latarki i podąża za ręką (kołysanie, odrzut, animacje)
	if latarka.visible:
		_latarka_t += delta
		# żarówka lekko pulsuje (słaba bateria)
		var puls := 1.0 - 0.04 * sin(_latarka_t * 31.0) * sin(_latarka_t * 7.3)
		if randf() < 0.002:
			puls = 0.35
		latarka.light_energy = 3.4 * puls
		latarka_poswiata.light_energy = 0.9 * puls
	# przerwanie akcji: X, strzał, zmiana broni
	if not akcja.is_empty():
		var przerwij := Input.is_action_just_pressed("przerwij")
		if we_aktywne and (Input.is_action_just_pressed("strzal") or Input.is_action_just_pressed("bron1") or Input.is_action_just_pressed("bron2") or Input.is_action_just_pressed("bron3")):
			przerwij = true
		if przerwij:
			przerwij_akcje(true)


func _rozgladanie(delta: float, aktywne: bool) -> void:
	var m := Sterowanie.pobierz_mysz() if aktywne else Vector2.ZERO
	var czul := 0.0022 * float(Gra.ustawienia.get("czulosc", 1.0)) * lerpf(1.0, 0.65, bron.ads)
	rotate_y(-m.x * czul)
	if bool(Gra.ustawienia.get("odwroc_y", false)):
		m.y = -m.y
	_pitch = clampf(_pitch - m.y * czul, deg_to_rad(-86), deg_to_rad(86))
	bron.dodaj_sway(m)
	# odrzut: szybki wzrost, powolny powrót
	var krok := _odrzut_cel * minf(1.0, delta * 22.0)
	_odrzut += krok
	_odrzut_cel -= krok
	var powrot := _odrzut * minf(1.0, delta * 3.2)
	_odrzut -= powrot
	# ból: drżenie celownika
	var drzenie := Vector2.ZERO
	if cialo.bol():
		_bol_t += delta
		drzenie = Vector2(sin(_bol_t * 1.7) * 0.4 + sin(_bol_t * 4.3) * 0.25, cos(_bol_t * 1.3) * 0.35) * deg_to_rad(1.2)
	_trafienie_shake = maxf(0.0, _trafienie_shake - delta * 3.0)
	_kop = move_toward(_kop, 0.0, delta * 7.0)
	oglusz = maxf(0.0, oglusz - delta)
	if oglusz > 0.0:
		var o := minf(1.0, oglusz / 2.0)
		drzenie += Vector2(sin(Time.get_ticks_msec() * 0.0021) * 1.6, cos(Time.get_ticks_msec() * 0.0017) * 1.1) * deg_to_rad(1.5) * o
	var rk := minf(delta, 0.1)
	while rk > 0.0:
		var hk := minf(rk, 0.008)
		_kam_kop_v += (-_kam_kop * 260.0 - _kam_kop_v * 20.0) * hk
		_kam_kop += _kam_kop_v * hk
		rk -= hk
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (_trafienie_shake * deg_to_rad(2.0)) + Vector2(_kam_kop.y, -_kam_kop.x) * deg_to_rad(1.0)
	var zerk := bron.zerkniecie * bron.zerkniecie * (3.0 - 2.0 * bron.zerkniecie)
	glowa.rotation.x = clampf(_pitch + ekw_pitch - zerk * deg_to_rad(9.0), deg_to_rad(-88), deg_to_rad(88)) + deg_to_rad(_odrzut.y) + drzenie.y + shake.y
	glowa.rotation.y = deg_to_rad(_odrzut.x) + drzenie.x + shake.x
	# wychylenie
	var cel_w := 0.0
	if aktywne:
		cel_w = Input.get_action_strength("wychyl_p") - Input.get_action_strength("wychyl_l")
	if cel_w != 0.0 and _sciana_przy_wychyleniu(sign(cel_w)):
		cel_w *= 0.3
	wychylenie = move_toward(wychylenie, cel_w, delta * 4.0)
	var wys: float = lerpf(WYS_STOJ, WYS_KUC, kucanie)
	# kołysanie głowy w rytm kroków, przechył przy ruchu w bok, ugięcie po lądowaniu
	var pozioma := Vector2(velocity.x, velocity.z).length()
	var naziemi := is_on_floor()
	_bob_amp = move_toward(_bob_amp, clampf(pozioma / PREDKOSC_BIEG, 0.0, 1.0) if naziemi else 0.0, delta * 3.0)
	_bob_t += delta * (5.2 + pozioma * 1.25)
	var waga_mn := 1.0 + prog_obciazenia() * 0.25
	var kol := float(Gra.ustawienia.get("kolysanie", 1.0))
	var bob_y := -absf(sin(_bob_t)) * 0.055 * _bob_amp * waga_mn * (1.0 - bron.ads * 0.7) * kol
	var bob_x := sin(_bob_t) * 0.03 * _bob_amp * (1.0 - bron.ads * 0.7) * kol
	var bok := (global_basis.inverse() * velocity).x
	_przechyl = lerpf(_przechyl, -bok * 0.012, minf(1.0, delta * 5.0))
	_ladowanie = move_toward(_ladowanie, 0.0, delta * 0.6)
	glowa.position = Vector3(wychylenie * 0.32 + bob_x, wys - absf(wychylenie) * 0.06 + bob_y - _ladowanie - ekw_glowa, 0)
	kamera.rotation.z = -wychylenie * deg_to_rad(11) + _przechyl + sin(_bob_t) * 0.006 * _bob_amp + ekw_roll + _kam_kop.z * deg_to_rad(1.0)
	var fov_baza := float(Gra.ustawienia.get("fov", 75.0))
	kamera.fov = lerpf(fov_baza, fov_baza * 0.8 / bron.zoom(), bron.ads) + _kop * 1.2


func _sciana_przy_wychyleniu(strona: float) -> bool:
	var space := get_world_3d().direct_space_state
	var od := global_position + Vector3.UP * lerpf(WYS_STOJ, WYS_KUC, kucanie)
	var do_ := od + global_basis.x * strona * 0.55
	var q := PhysicsRayQueryParameters3D.create(od, do_, Balistyka.WARSTWA_SWIAT)
	return not space.intersect_ray(q).is_empty()


func _ruch(delta: float, aktywne: bool) -> void:
	var kier := Vector3.ZERO
	var chce_kucac := false
	var chce_biec := false
	if aktywne:
		kier = Vector3(Input.get_axis("lewo", "prawo"), 0, Input.get_axis("przod", "tyl"))
		chce_kucac = Input.is_action_pressed("kucanie")
		chce_biec = Input.is_action_pressed("bieg") and kier.z < 0.0
	# nie da się wstać pod niskim sufitem
	if not chce_kucac and kucanie > 0.0 and _sufit_nisko():
		chce_kucac = true
	kucanie = move_toward(kucanie, 1.0 if chce_kucac else 0.0, delta * 4.0)
	var cap := ksztalt.shape as CapsuleShape3D
	cap.height = lerpf(1.75, 1.15, kucanie)
	ksztalt.position.y = cap.height * 0.5
	var prog := prog_obciazenia()
	var moze_biec := chce_biec and cialo.moze_biegac() and prog < 3 and wytrzymalosc > 1.0 and kucanie < 0.3 and akcja.is_empty() and bron.ads < 0.3
	var v := PREDKOSC_CHOD
	if moze_biec:
		v = PREDKOSC_BIEG
	elif kucanie > 0.5:
		v = PREDKOSC_KUC
	v *= [1.0, 0.9, 0.75, 0.5][prog] * cialo.mnoznik_ruchu()
	if not akcja.is_empty():
		v *= 0.45
	if ruch_z_ekwipunkiem and Sterowanie.blokada:
		# zerkanie w ładownice w marszu: tylko powoli, bez biegu
		v = minf(v, PREDKOSC_KUC)
		moze_biec = false
	if oglusz > 0.0:
		v *= 1.0 - 0.45 * minf(1.0, oglusz / 2.0)
	if bron.ads > 0.5:
		v *= 0.75
	_biegnie = moze_biec and kier.length() > 0.1
	if moze_biec and kier.length() > 0.1:
		wytrzymalosc = maxf(0.0, wytrzymalosc - delta * (11.0 + prog * 5.0))
	else:
		wytrzymalosc = minf(100.0, wytrzymalosc + delta * (9.0 if kier.length() < 0.1 else 5.0) * mnoznik_sil())
	var cel := (global_basis * kier.normalized()) * v
	# ciężki ruch: rozpędzanie i hamowanie w m/s², zależne od obciążenia; w powietrzu prawie bez kontroli
	var teraz := Vector2(velocity.x, velocity.z)
	var cel2 := Vector2(cel.x, cel.z)
	var przysp: float
	if not is_on_floor():
		przysp = 2.0
	elif cel2.length() > teraz.length() + 0.05:
		# rozpędzanie: do chodu prawie od razu, do biegu wolniej (zależnie od obciążenia)
		przysp = [22.0, 18.0, 14.0, 10.0][prog] if teraz.length() < PREDKOSC_CHOD else [9.0, 7.5, 6.0, 4.5][prog]
	else:
		# hamowanie i zmiana kierunku: stopy trzymają się podłogi
		przysp = [30.0, 26.0, 22.0, 16.0][prog]
	# zmiana kierunku (np. w bok przy biegu) też hamuje mocno, bez poślizgu
	if is_on_floor() and teraz.length() > 0.3 and cel2.length() > 0.3 and teraz.normalized().dot(cel2.normalized()) < 0.7:
		przysp = maxf(przysp, 20.0)
	teraz = teraz.move_toward(cel2, przysp * delta)
	velocity.x = teraz.x
	velocity.z = teraz.y
	if is_on_floor():
		if _w_powietrzu:
			_w_powietrzu = false
			var wys := _y_spadania - global_position.y
			cialo.upadek(wys)
			if wys > 2.2:
				wypadnij_z_kieszeni(0.45)
			if wys > 0.4:
				wstrzas_kieszeni(clampf(0.08 + wys * 0.06, 0.08, 0.35), "upadek")
			_ladowanie = clampf(0.05 + wys * 0.08, 0.05, 0.22)
			Dzwiek.krok(global_position, get_parent(), clampf(-6.0 + wys * 3.0, -6.0, 3.0), 0.8)
		if aktywne and not (ruch_z_ekwipunkiem and Sterowanie.blokada) and Input.is_action_just_pressed("skok") and prog < 3 and wytrzymalosc > 12.0 and kucanie < 0.3:
			velocity.y = 3.6
			wytrzymalosc -= 10.0
			wstrzas_kieszeni(0.06, "skok")
	else:
		if not _w_powietrzu:
			_w_powietrzu = true
			_y_spadania = global_position.y
		_y_spadania = maxf(_y_spadania, global_position.y)
		velocity.y -= 9.8 * delta
	move_and_slide()
	# kroki i hałas
	var pozioma := Vector2(velocity.x, velocity.z).length()
	halas_ruchu = clampf(pozioma / PREDKOSC_BIEG, 0.0, 1.0) * (0.35 if kucanie > 0.5 else 1.0)
	if is_on_floor() and pozioma > 0.4:
		_krok += pozioma * delta
		var dl := 0.85 if moze_biec else 0.62
		if _krok > dl:
			_krok = 0.0
			var gl := -14.0 if kucanie > 0.5 else (-4.0 if moze_biec else -9.0)
			Dzwiek.krok(global_position, get_parent(), gl + prog * 1.5, 0.95 if prog >= 2 else 1.0)
			# szelest ubrania i oporządzenia (przy kucaniu i obciążeniu częściej słychać siebie)
			if randf() < (0.35 if kucanie > 0.5 else 0.15 + prog * 0.08):
				Dzwiek.graj_3d(Dzwiek.wariant("szelest"), global_position + Vector3.UP * 1.0, get_parent(), -22.0 + prog * 2.0, randf_range(0.85, 1.15), 6.0)
			var zasieg := 2.5 if kucanie > 0.5 else (11.0 if moze_biec else 6.0)
			# brzęk luźnego metalu w plecaku i kieszeniach (w biegu najgłośniej, przy kucaniu prawie wcale)
			var brz := ekw.brzek() * (1.0 if moze_biec else (0.15 if kucanie > 0.5 else 0.45))
			if brz > 0.8:
				zasieg += brz
				if randf() < 0.5:
					Dzwiek.graj_3d("klik", global_position + Vector3.UP * 0.9, get_parent(), -20.0 + minf(8.0, brz), randf_range(0.55, 0.8), 12.0)
			Gra.emituj_halas(global_position, zasieg * (1.0 + prog * 0.15), self)


var _oddech_t := 0.0
var _serce_t := 0.0


## Oddech po wysiłku (zadyszka przy niskiej wytrzymałości) i bicie serca przy ciężkich ranach.
func _dzwieki_ciala(delta: float) -> void:
	_oddech_t -= delta
	if wytrzymalosc < 40.0 and _oddech_t <= 0.0:
		var f := 1.0 - wytrzymalosc / 40.0
		Dzwiek.graj("oddech", lerpf(-20.0, -9.0, f), lerpf(1.0, 1.25, f))
		_oddech_t = lerpf(2.4, 1.7, f)
	var hp := cialo.procent()
	_serce_t -= delta
	if hp < 0.4 and _serce_t <= 0.0:
		var f2 := 1.0 - hp / 0.4
		Dzwiek.graj("serce", lerpf(-16.0, -4.0, f2), 1.0)
		_serce_t = lerpf(1.0, 0.55, f2)


func _sufit_nisko() -> bool:
	var space := get_world_3d().direct_space_state
	var od := global_position + Vector3.UP * 1.0
	var q := PhysicsRayQueryParameters3D.create(od, od + Vector3.UP * 0.85, Balistyka.WARSTWA_SWIAT)
	return not space.intersect_ray(q).is_empty()


# ------------------------------------------------------------------ broń i leczenie

func _bron(delta: float, aktywne: bool) -> void:
	if tryb_bazy:
		return
	var moze := aktywne and akcja.is_empty() and bron.przedmiot != null
	if aktywne and akcja.is_empty() and not bron.zajeta():
		if Input.is_action_just_pressed("bron1") and ekw.sloty["glowna"] != null and (aktywny_slot != "glowna" or latarka_w_rece):
			latarka_w_rece = false
			_wybierz_bron("glowna")
		elif Input.is_action_just_pressed("bron2") and ekw.sloty["pistolet"] != null:
			# drugie wciśnięcie przy pistolecie: dobiera/odkłada latarkę
			if aktywny_slot == "pistolet" and bron.przedmiot != null:
				if latarka_w_rece:
					latarka_w_rece = false
					_wybierz_bron("pistolet")
				else:
					wez_latarke()
			else:
				_wybierz_bron("pistolet")
		elif Input.is_action_just_pressed("bron3"):
			if latarka_w_rece and bron.przedmiot == null:
				latarka_w_rece = false
				_wybierz_bron("glowna" if ekw.sloty["glowna"] != null else "pistolet")
			else:
				wez_latarke(true)
	var ruch: float = clampf(Vector2(velocity.x, velocity.z).length() / PREDKOSC_BIEG, 0.0, 1.0)
	bron.aktualizuj(delta, {
		"strzal": aktywne and Input.is_action_pressed("strzal"),
		"ads": aktywne and Input.is_action_pressed("celuj"),
		"przeladuj": aktywne and Input.is_action_pressed("przeladuj"),
		"tryb": aktywne and Input.is_action_just_pressed("tryb"),
		"sprawdz": aktywne and Input.is_action_just_pressed("sprawdz"),
		"moze": moze and not _biegnie,
		"bieg": _biegnie and Vector2(velocity.x, velocity.z).length() > 2.0,
		"ruch": ruch, "kucanie": kucanie, "celnosc": cialo.mnoznik_celnosci(),
	})
	if not aktywne:
		return
	# pasek szybkiego dostępu 4-9 (w trakcie innej czynności – zaplanuj jako następną)
	var pasek := ekw.pasek()
	for i in 6:
		if Input.is_action_just_pressed("pasek%d" % (i + 1)):
			if i < pasek.size():
				var z := ekw.znajdz_id(pasek[i]["id"])
				if not z.is_empty():
					uzyj_leku(z["p"], z["szybki"])
			else:
				komunikat.emit("Pusty slot paska [%d] – połóż leki w kamizelce lub kieszeniach" % (i + 4))


func uzyj_leku_efekt(efekty: Array) -> void:
	if not cialo.potrzebuje(efekty[0]):
		komunikat.emit("Nie ma czego leczyć")
		return
	var z := ekw.znajdz_med(efekty)
	if z.is_empty():
		komunikat.emit("Brak: " + {"krwawienie_lekkie": "bandaża", "krwawienie_ciezkie": "opatrunku", "leczenie": "apteczki", "zlamanie": "szyny", "bol": "środka przeciwbólowego"}.get(efekty[0], "leku"))
		return
	uzyj_leku(z["p"], z["szybki"])


var alkohol := 0.0             # sekundy drżenia rąk po wódce
var przygniecenie := 0.0       # 0..1 – ostrzał tuż obok: ciemnieje obraz, drżą ręce, gorsza celność


## Kula przeleciała blisko: przygniecenie ogniem (rośnie z serią, opada po kilku sekundach spokoju).
func przygniec(sila: float) -> void:
	przygniecenie = minf(1.0, przygniecenie + 0.22 * sila)
	_kop += 0.004 * sila
var _potrzeby_prog := {"glod": 100.0, "pragnienie": 100.0}


## Jedzenie i picie w rajdzie: czynność z animacją (przerywalna), potem zmiana głodu i pragnienia.
## Granat: wyjęcie (z kamizelki szybko, z kieszeni wolniej), zawleczka, zamach i rzut.
## Kucając – toczy go po podłodze (cicho, krótko).
func rzuc_granat() -> void:
	if tryb_bazy or not akcja.is_empty():
		return
	var z := ekw.znajdz_id("granat_f1")
	if z.is_empty():
		komunikat.emit("Brak granatu pod ręką (kamizelka, kieszenie)")
		return
	var p: Przedmiot = z["p"]
	var czas := 1.1 * ekw.mnoznik_dostepu(z["siatka"], p)
	_otworz_po_drodze(p)
	var nisko := kucanie > 0.5
	zacznij_akcje("Granat", czas, func():
		if not ekw.usun_przedmiot(p):
			return
		var przod := -kamera.global_basis.z
		var skad := kamera.global_position + kamera.global_basis.x * 0.15 + przod * 0.35 - kamera.global_basis.y * 0.1
		var v: Vector3
		if nisko:
			var plaski := Vector3(przod.x, 0.0, przod.z).normalized()
			v = plaski * 6.0 + Vector3.UP * 0.8
		else:
			v = (przod + Vector3.UP * 0.22).normalized() * 13.0
		v += velocity * 0.6
		Granat.rzuc(get_parent(), skad, v, self, p.defn())
		Gra.emituj_halas(global_position, 5.0, self)
		ekw.zmieniony.emit()
		, "granat", 0, Callable(), {"id": "granat_f1"})


func spozyj(p: Przedmiot) -> void:
	if not akcja.is_empty():
		zaplanuj(p.nazwa(), func(): spozyj(p))
		return
	var j: Dictionary = p.defn().get("jedzenie", {})
	var picie: bool = j.get("picie", false)
	Gra.emituj_halas(global_position, 3.0, self)
	Dzwiek.graj("szelest_1" if not picie else "odloz", -12.0, 0.9)
	zacznij_akcje(("Picie: " if picie else "Jedzenie: ") + p.nazwa(), float(j.get("czas", 4.0)), func():
		if not ekw.usun_przedmiot(p):
			return
		var opis := Gra.spozyj(p)
		if j.get("alkohol", false):
			cialo.przeciwbol = maxf(cialo.przeciwbol, 75.0)
			alkohol = maxf(alkohol, 120.0)
		ekw.zmieniony.emit()
		komunikat.emit(opis)
		, "picie" if picie else "jedzenie", 0, Callable(), {"id": p.id})


# ------------------------------------------------------------------ otwarte kieszenie gubią zawartość

var _wypadanie_t := 0.25
## Szansa na sekundę biegu, że coś wypadnie z otwartej kieszeni danego rodzaju zapięcia.
const WYPADANIE := {"rzep": 0.035, "zatrzask": 0.035, "guzik": 0.03, "zamek": 0.015, "klapa": 0.05, "sciagacz": 0.045, "wieko": 0.0}


## Otwarte kieszenie kamizelki i plecaka na plecach: w ruchu (bieg najmocniej) coś może z nich wypaść.
func _wypadanie(dt: float) -> void:
	if tryb_bazy or not is_on_floor():
		return
	var v := Vector2(velocity.x, velocity.z).length()
	var ruch := 0.0
	if _biegnie and v > 2.5:
		ruch = 1.0
	elif v > 1.0:
		ruch = 0.12 if kucanie < 0.5 else 0.25
	if ruch <= 0.0:
		return
	_gubienie(ruch * dt)


## Jednorazowy wstrząs (skok, lądowanie, trafienie): szansa na wypadnięcie z każdej otwartej kieszeni.
func wstrzas_kieszeni(szansa: float, _powod: String) -> void:
	if tryb_bazy:
		return
	_gubienie(szansa * 20.0)


func _gubienie(mnoznik: float) -> void:
	for co in ["kamizelka", "plecak"]:
		if co == "plecak" and (ekw.plecak_rozlozony or ekw.siatka_plecaka() == null):
			continue
		var s: Siatka = ekw.siatka_kamizelki() if co == "kamizelka" else ekw.siatka_plecaka()
		if s == null:
			continue
		var st := ekw.stan_kieszeni(co)
		var defs := ekw.kieszenie_def(co)
		var worek: bool = co == "plecak" and (ekw.sloty["plecak"] as Przedmiot).id == "worek"
		for i in mini(st.size(), defs.size()):
			if not bool(st[i]):
				continue
			var typ: String = defs[i]["typ"]
			if co == "kamizelka":
				typ = ModeleOporzadzenia.TYP_LADOWNIC.get((ekw.sloty["kamizelka"] as Przedmiot).id, typ)
			var p_s: float = float(WYPADANIE.get(typ, 0.03)) * (1.6 if worek else 1.0)
			if randf() > p_s * mnoznik:
				continue
			_wypadnij_z(s, defs[i]["r"], co)


## Z otwartej kieszeni wypada przedmiot leżący najbliżej wylotu (ładownica – u góry), drobne łatwiej.
func _wypadnij_z(s: Siatka, r: Rect2i, co: String) -> void:
	var kand := []
	for e in s.items:
		var p: Przedmiot = e["p"]
		if r.intersects(Rect2i(int(e["x"]), int(e["y"]), p.szer(), p.wys())):
			kand.append(e)
	if kand.is_empty():
		return
	kand.sort_custom(func(a, b): return int(a["y"]) * 10 + (a["p"] as Przedmiot).szer() * (a["p"] as Przedmiot).wys() < int(b["y"]) * 10 + (b["p"] as Przedmiot).szer() * (b["p"] as Przedmiot).wys())
	var e0: Dictionary = kand[0] if co == "kamizelka" else kand.pick_random()
	var p0: Przedmiot = e0["p"]
	if p0.szer() * p0.wys() > 4 and randf() < 0.7:
		return     # duże rzeczy rzadko wyskakują same
	s.usun(p0)
	ekw.zmieniony.emit()
	var l := LupNaZiemi.new()
	l.przedmiot = p0
	l.rzut_z = global_position + Vector3.UP * (1.15 if co == "kamizelka" else 1.3) + global_basis.z * 0.15
	get_parent().add_child(l)
	l.global_position = global_position + global_basis.z * randf_range(0.4, 0.9) + global_basis.x * randf_range(-0.4, 0.4) + Vector3.UP * 0.3
	komunikat.emit("Coś upadło za tobą – z otwartej %s." % ("ładownicy" if co == "kamizelka" else "kieszeni plecaka"))
	Gra.wskazowka("wypadlo", "Z otwartej kieszeni wypadł przedmiot – leży za tobą. Zapięte kieszenie nie gubią zawartości (w ekwipunku: uchwyt „zapnij”).")


## Sięgnięcie do zapiętej ładownicy / kieszeni: postać ją otwiera (dźwięk rzepu / klamry) i zostawia otwartą.
func _otworz_po_drodze(p: Przedmiot) -> bool:
	if tryb_bazy:
		return false
	var s := ekw.siatka_z(p)
	if s == null or not ekw.otworz_kieszen_dla(s, p):
		return false
	Dzwiek.graj("rzep", -9.0, randf_range(0.9, 1.1))
	Gra.emituj_halas(global_position, 3.5, self)
	Gra.wskazowka("ladownica_otwarta", "Sięgając do zapiętej ładownicy, postać ją otwiera – i zostawia otwartą. Z otwartej wyjmuje się szybciej, ale w biegu, przy skoku czy trafieniu coś może z niej wypaść. Zapniesz ją w ekwipunku (uchwyt „zapnij”).")
	return true


## Głód i pragnienie w rajdzie: maleją z czasem (szybciej w biegu); niskie spowalniają odzyskiwanie sił,
## zerowe powoli odbierają zdrowie. Komunikaty przy przekraczaniu progów.
func _potrzeby(delta: float) -> void:
	if tryb_bazy:
		return
	var bieg := 1.0 if _biegnie else 0.0
	Gra.potrzeby["glod"] = maxf(0.0, float(Gra.potrzeby["glod"]) - delta * 0.012 * (1.0 + bieg * 0.8))
	Gra.potrzeby["pragnienie"] = maxf(0.0, float(Gra.potrzeby["pragnienie"]) - delta * 0.02 * (1.0 + bieg * 1.5))
	alkohol = maxf(0.0, alkohol - delta)
	for k in ["glod", "pragnienie"]:
		var v: float = Gra.potrzeby[k]
		for prog in [30.0, 15.0, 0.0]:
			if v <= prog and float(_potrzeby_prog[k]) > prog:
				komunikat.emit({"glod": {30.0: "Burczy w brzuchu.", 15.0: "Słabniesz z głodu – zjedz coś.", 0.0: "Głód zaczyna wyniszczać organizm."},
					"pragnienie": {30.0: "Zaschło w gardle.", 15.0: "Kręci się w głowie z pragnienia – napij się.", 0.0: "Odwodnienie – tracisz siły i zdrowie."}}[k][prog])
		_potrzeby_prog[k] = v
		if v <= 0.0:
			cialo.obrazenia("brzuch", delta * (0.15 if k == "glod" else 0.25), k)


var _samouczek_t := 1.0


## Wskazówki samouczka w sytuacjach, gdy przydają się pierwszy raz.
func _samouczek() -> void:
	if tryb_bazy:
		return
	var c = cel_interakcji
	if c != null and is_instance_valid(c):
		if c is Pojemnik:
			Gra.wskazowka("pojemnik", "Przeszukiwanie idzie po kolei – zawartość odkrywa się z czasem, po ciemku wolniej (latarka [L] pomaga). Przekładanie robi ręka: trwa, a trafienie wytrąca przedmiot.")
		elif c is Drzwi:
			Gra.wskazowka("drzwi", "Drzwi: F otwiera i zamyka – słychać to daleko. Kucając F uchylasz je cicho na szparę. Stojąc przy zamkniętych drzwiach, podsłuchasz, co za nimi.")
		elif c is LupNaZiemi:
			Gra.wskazowka("lup", "Podniesienie zajmuje chwilę. Do zapiętego plecaka na plecach nic nie wejdzie – w ekwipunku [Tab] zdejmij go i otwórz kieszeń.")
		elif c is Wrog:
			Gra.wskazowka("poddany", "Poddał się. F – każesz oddać łup; potem możesz kupić informację i rozejm z jego ludźmi albo puścić go wolno. Strzał zrywa rozejm.")
	if cialo.krwawi() > 0:
		Gra.wskazowka("krwawienie", "Krwawisz! Bandaż z paska [4] albo w ekwipunku upuść lek na krwawiącą część ciała. Ciężkie krwawienie zatrzyma tylko opatrunek.")
	if bron.przedmiot and bron.stan == "gotowa" and String(bron.przedmiot.dane.get("komora", "x")) == "" and int(bron.przedmiot.dane.get("wewn", 1)) == 0:
		Gra.wskazowka("pusty", "Pusty magazynek – R przeładowuje (przytrzymaj: szybko, stary leci na ziemię). Magazynki napełniasz w ekwipunku klawiszem G.")
	if wytrzymalosc < 15.0:
		Gra.wskazowka("zmeczenie", "Zadyszka – marsz albo postój odnawia siły. Głód, pragnienie i ciężki plecak spowalniają odpoczynek.")
	if float(Gra.potrzeby["glod"]) < 30.0 or float(Gra.potrzeby["pragnienie"]) < 30.0:
		Gra.wskazowka("glod", "Głód i pragnienie (paski w panelu ciała, Tab): PPM na jedzeniu lub wodzie – Zjedz / Wypij.")
	if przygniecenie > 0.5:
		Gra.wskazowka("ostrzal", "Jesteś pod ostrzałem – kule tuż obok psują celność. Zejdź z linii ognia, kucnij za osłoną. Twoje kule tak samo przygniatają wrogów.")
	if not ekw.znajdz_id("granat_f1").is_empty():
		Gra.wskazowka("granat", "Masz granat pod ręką: G – rzut (kucając toczysz go po podłodze). Wybuch po ok. 3,5 s.")


## Mnożnik odzyskiwania sił (głód, pragnienie).
func mnoznik_sil() -> float:
	var m := 1.0
	if float(Gra.potrzeby["glod"]) < 25.0:
		m *= 0.75
	if float(Gra.potrzeby["pragnienie"]) < 25.0:
		m *= 0.7
	return m


## czesc: część ciała wybrana w panelu zdrowia ("" = najpilniejsza).
func uzyj_leku(med: Przedmiot, szybki := true, czesc := "") -> void:
	if tryb_bazy:
		return
	if not akcja.is_empty():
		if String(akcja.get("typ", "")) != "leczenie_" + med.id:
			zaplanuj(med.nazwa(), func(): uzyj_leku(med, szybki, czesc))
		return
	var md: Dictionary = med.defn()["med"]
	var efekt: String = md["efekt"]
	if not cialo.potrzebuje(efekt, czesc):
		komunikat.emit("Nie ma czego leczyć" + ((" (" + Cialo.NAZWY[czesc].to_lower() + ")") if czesc != "" else ""))
		return
	var czas := float(md["czas"]) * (1.0 if szybki else 1.5)
	# zapięta ładownica: najpierw odpiąć klapkę (zostaje otwarta)
	if _otworz_po_drodze(med):
		czas += 0.6
	var przet: bool = med.dane.get("przeterminowany", false)
	if przet:
		czas *= 1.4     # zbrylony proszek, sklejony opatrunek – idzie opornie
	Dzwiek.graj("leczenie", -6.0)
	Gra.emituj_halas(global_position, 4.0, self)
	var nazwa: String = med.nazwa() + ((" → " + Cialo.NAZWY[czesc].to_lower()) if czesc != "" else "")
	zacznij_akcje(nazwa, czas, func():
		if przet and efekt in ["krwawienie_lekkie", "bol"] and randf() < 0.3:
			med.dane["uzycia"] -= 1
			if med.dane["uzycia"] <= 0:
				ekw.usun_przedmiot(med)
			ekw.zmieniony.emit()
			komunikat.emit("Przeterminowany – nie zadziałał")
			return
		var opis := cialo.lecz(efekt, md, med, czesc)
		if efekt in ["krwawienie_lekkie", "krwawienie_ciezkie", "zlamanie"] and opis != "":
			med.dane["uzycia"] -= 1
		if med.dane["uzycia"] <= 0:
			ekw.usun_przedmiot(med)
		ekw.zmieniony.emit()
		if opis != "":
			komunikat.emit(opis)
		# apteczka leczy dalej, dopóki jest co leczyć i gracz nie przerwał
		if efekt == "leczenie" and med.dane["uzycia"] > 0 and cialo.potrzebuje("leczenie", czesc):
			uzyj_leku(med, szybki, czesc)
	, "leczenie_" + med.id, 0, Callable(), {"id": med.id, "czesc": czesc})


## Akcja z czasem (leczenie, napełnianie). typ: animacja rąk. kroki > 0: akcja krokowa – na_krok
## wołane co czas/kroki sekund (np. jeden nabój); przerwanie zostawia to, co już zrobione.
func zacznij_akcje(nazwa: String, czas: float, koniec: Callable, typ := "leczenie", kroki := 0, na_krok := Callable(), dane := {}) -> void:
	akcja = {"nazwa": nazwa, "t": 0.0, "czas": czas, "koniec": koniec, "typ": typ, "kroki": kroki, "zrobione": 0, "na_krok": na_krok}
	akcja.merge(dane)
	bron.animacja_akcji(typ)


func przerwij_akcje(z_komunikatem := false) -> void:
	if z_komunikatem:
		kolejka_akcji.clear()
	if akcja.is_empty():
		return
	if z_komunikatem:
		komunikat.emit("Przerwano: " + String(akcja["nazwa"]))
		Dzwiek.graj("klik", -10.0, 0.6)
	akcja = {}
	bron.animacja_akcji("")


## Postęp bieżącego kroku akcji (0..1) – do kółka na HUD.
func postep_kroku() -> float:
	if akcja.is_empty():
		return 0.0
	if int(akcja["kroki"]) > 0:
		var krok: float = float(akcja["czas"]) / int(akcja["kroki"])
		return clampf((float(akcja["t"]) - int(akcja["zrobione"]) * krok) / krok, 0.0, 1.0)
	return clampf(float(akcja["t"]) / float(akcja["czas"]), 0.0, 1.0)


func _akcje(delta: float) -> void:
	if akcja.is_empty():
		return
	akcja["t"] += delta
	var kroki: int = akcja["kroki"]
	if kroki > 0:
		var krok: float = float(akcja["czas"]) / kroki
		while int(akcja["zrobione"]) < kroki and float(akcja["t"]) >= (int(akcja["zrobione"]) + 1) * krok:
			akcja["zrobione"] = int(akcja["zrobione"]) + 1
			var nk: Callable = akcja["na_krok"]
			if nk.is_valid():
				nk.call()
			if akcja.is_empty():
				return
	if akcja["t"] >= akcja["czas"]:
		var k: Callable = akcja["koniec"]
		akcja = {}
		bron.animacja_akcji("")
		k.call()
		# zaplanowana następna czynność (np. bandaż po napełnieniu magazynka)
		if akcja.is_empty() and not kolejka_akcji.is_empty():
			var nast: Dictionary = kolejka_akcji.pop_front()
			(nast["cb"] as Callable).call()


## Kolejka czynności: zlecona w trakcie innej rusza po jej końcu (najwyżej 3). X czyści kolejkę.
var kolejka_akcji: Array = []


func zaplanuj(nazwa: String, cb: Callable) -> void:
	if kolejka_akcji.size() >= 3:
		komunikat.emit("Za dużo naraz – najpierw skończ")
		return
	kolejka_akcji.append({"nazwa": nazwa, "cb": cb})
	komunikat.emit("Następnie: " + nazwa)


# ------------------------------------------------------------------ interakcje

func _interakcje(aktywne: bool) -> void:
	cel_interakcji = null
	tekst_interakcji = ""
	var space := get_world_3d().direct_space_state
	var od := kamera.global_position
	var q := PhysicsRayQueryParameters3D.create(od, od - kamera.global_basis.z * 2.3, MASKA_INTERAKCJI)
	q.collide_with_areas = true
	q.exclude = [get_rid()]
	var r := space.intersect_ray(q)
	if r.is_empty():
		return
	var col: Object = r["collider"]
	var cel: Object = col.get_meta("interakcja") if col.has_meta("interakcja") else null
	if cel == null or not is_instance_valid(cel):
		return
	cel_interakcji = cel
	tekst_interakcji = cel.tekst_interakcji(self) if cel.has_method("tekst_interakcji") else "Użyj"
	if aktywne and Input.is_action_just_pressed("interakcja") and cel.has_method("interakcja"):
		cel.interakcja(self)


## Upuszcza przedmiot na ziemię przed graczem.
func upusc(p: Przedmiot) -> LupNaZiemi:
	var swiat := get_parent()
	var lup := LupNaZiemi.new()
	lup.przedmiot = p
	# wypada z dłoni przed postacią: lekki rozrzut, żeby kolejne przedmioty nie leżały jeden na drugim
	var przod := -kamera.global_basis.z
	przod.y = 0.0
	przod = przod.normalized() if przod.length() > 0.01 else -global_basis.z
	var bok := przod.cross(Vector3.UP)
	var cel := global_position + przod * randf_range(0.45, 0.75) + bok * randf_range(-0.25, 0.25) + Vector3.UP * 0.3
	# nie za ścianę ani w mebel: jeśli coś stoi po drodze, przedmiot ląduje przed przeszkodą
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, cel, Balistyka.WARSTWA_SWIAT)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		cel = global_position + Vector3.UP * 0.3 + (hp - (global_position + Vector3.UP * 0.3)) * 0.6
	lup.rzut_z = kamera.global_position + przod * 0.3 + Vector3.DOWN * 0.25
	swiat.add_child(lup)
	lup.global_position = cel
	komunikat.emit("Upuszczono: " + p.nazwa())
	return lup


# ------------------------------------------------------------------ obrażenia

## Trafienie z broni przeciwnika. punkt: miejsce trafienia w świecie.
func trafiony(punkt: Vector3, obr: float, pen: float, od_kogo: Node, srut := false) -> void:
	if cialo.martwy:
		return
	# trafiony przy rozłożonym plecaku / przeszukiwaniu: zrywa się, sprzęt zostaje na ziemi
	get_tree().call_group("ekran_ekwipunku", "zerwij_sie", "trafienie")
	wstrzas_kieszeni(0.12, "trafienie")
	var wys: float = lerpf(WYS_STOJ, WYS_KUC, kucanie) + 0.12
	var y: float = (punkt.y - global_position.y) / wys
	var czesc := "nogi"
	if y > 0.88:
		czesc = "glowa"
	elif y > 0.66:
		czesc = "klatka"
	elif y > 0.5:
		czesc = "brzuch"
	if czesc in ["klatka", "brzuch"] and randf() < 0.22:
		czesc = "rece"
	var helm: Przedmiot = ekw.sloty["helm"]
	var kier0 := (punkt - global_position)
	if od_kogo is Node3D:
		kier0 = (od_kogo as Node3D).global_position - global_position
	if czesc == "glowa" and helm != null and float(helm.dane["wytrz"]) > 0.0:
		var maks := float(helm.defn()["pancerz"]["wytrzymalosc"])
		var stan_h: float = float(helm.dane["wytrz"]) / maks
		# rykoszet: kula pod kątem ślizga się po okrągłej skorupie
		if randf() < 0.35 * clampf(stan_h, 0.3, 1.0) and not srut:
			helm.dane["wytrz"] = maxf(0.0, float(helm.dane["wytrz"]) - pen * 0.1)
			Dzwiek.graj("helm", -2.0, randf_range(1.0, 1.2))
			ogluszenie(0.45, "Rykoszet od hełmu!")
			trafiony_sygnal.emit(kier0, czesc)
			ekw.zmieniony.emit()
			return
	var wynik := Balistyka.przez_pancerz({"pancerz": ekw.sloty["pancerz"], "helm": helm}, czesc, obr, pen)
	# druga szansa: śmiertelny strzał w głowę w hełmie – hełm się wgniata i przestaje chronić, ty żyjesz, ale ogłuszony
	if czesc == "glowa" and helm != null and float(helm.dane.get("wytrz", 0.0)) > 0.0 and cialo.hp["glowa"] - float(wynik["obr"]) <= 0.0:
		wynik["obr"] = maxf(0.0, cialo.hp["glowa"] - randf_range(3.0, 9.0))
		helm.dane["wytrz"] = 0.0
		Dzwiek.graj("helm", 2.0, 0.85)
		ogluszenie(1.0, "Hełm przyjął kulę – jest zniszczony!")
	elif czesc == "glowa" and wynik["pancerz"]:
		Dzwiek.graj("helm", -4.0, 1.1)
		ogluszenie(0.3, "")
	cialo.obrazenia(czesc, wynik["obr"], "srut" if srut else "pocisk")
	_trafienie_shake = 1.0 if wynik["przebity"] else 0.5
	_odrzut_cel += Vector2(randf_range(-1.5, 1.5), randf_range(0.5, 2.0))
	if wynik["pancerz"]:
		Dzwiek.graj("trafienie_pancerz", -2.0)
	else:
		Dzwiek.graj("trafienie_cialo", -1.0)
	var kier := (punkt - global_position)
	if od_kogo is Node3D:
		kier = (od_kogo as Node3D).global_position - global_position
	trafiony_sygnal.emit(kier, czesc)
	if akcja.size() > 0 and randf() < 0.5:
		przerwij_akcje(true)
	ekw.zmieniony.emit()


func _smierc(przyczyna: String) -> void:
	sterowanie = false
	bron.ustaw(null)
	latarka.visible = false
	var t := create_tween()
	t.tween_property(glowa, "position:y", 0.25, 0.8).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(kamera, "rotation:z", deg_to_rad(75), 0.8)
	zginal.emit(przyczyna)
