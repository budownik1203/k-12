class_name Gracz
extends CharacterBody3D
## Gracz w widoku pierwszoosobowym: ruch z bezwładnością zależną od wagi, kucanie, wychylenia,
## sprint z wytrzymałością, rany (Cialo), leczenie z czasem, interakcje i broń.

signal komunikat(tekst: String)
signal zginal(przyczyna: String)
signal trafiony_sygnal(kierunek: Vector3, czesc: String)

const PREDKOSC_CHOD := 2.7
const PREDKOSC_BIEG := 4.9
const PREDKOSC_KUC := 1.35
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
	latarka.position = Vector3(0.15, -0.15, 0)
	latarka.light_color = Color(1.0, 0.94, 0.8)
	latarka.light_energy = 2.6
	latarka.spot_range = 16.0
	latarka.spot_angle = 26.0
	latarka.spot_attenuation = 0.9
	latarka.shadow_enabled = true
	latarka.visible = false
	kamera.add_child(latarka)
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
	bron.ustaw(ekw.sloty[slot])


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
	_ruch(delta, we_aktywne)
	_akcje(delta)
	_interakcje(we_aktywne)
	_bron(delta, we_aktywne)
	if we_aktywne and Input.is_action_just_pressed("latarka"):
		latarka.visible = not latarka.visible
		Dzwiek.graj("klik", -10.0)


func _rozgladanie(delta: float, aktywne: bool) -> void:
	var m := Sterowanie.pobierz_mysz() if aktywne else Vector2.ZERO
	var czul := 0.0022 * float(Gra.ustawienia.get("czulosc", 1.0)) * lerpf(1.0, 0.65, bron.ads)
	rotate_y(-m.x * czul)
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
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _trafienie_shake * deg_to_rad(2.0)
	glowa.rotation.x = _pitch + deg_to_rad(_odrzut.y) + drzenie.y + shake.y
	glowa.rotation.y = deg_to_rad(_odrzut.x) + drzenie.x + shake.x
	# wychylenie
	var cel_w := 0.0
	if aktywne:
		cel_w = Input.get_action_strength("wychyl_p") - Input.get_action_strength("wychyl_l")
	if cel_w != 0.0 and _sciana_przy_wychyleniu(sign(cel_w)):
		cel_w *= 0.3
	wychylenie = move_toward(wychylenie, cel_w, delta * 4.0)
	var wys: float = lerpf(WYS_STOJ, WYS_KUC, kucanie)
	glowa.position = Vector3(wychylenie * 0.32, wys - absf(wychylenie) * 0.06, 0)
	kamera.rotation.z = -wychylenie * deg_to_rad(11)
	var fov_baza := float(Gra.ustawienia.get("fov", 75.0))
	kamera.fov = lerpf(fov_baza, fov_baza * 0.8, bron.ads)


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
	if bron.ads > 0.5:
		v *= 0.75
	_biegnie = moze_biec and kier.length() > 0.1
	if moze_biec and kier.length() > 0.1:
		wytrzymalosc = maxf(0.0, wytrzymalosc - delta * (11.0 + prog * 5.0))
	else:
		wytrzymalosc = minf(100.0, wytrzymalosc + delta * (9.0 if kier.length() < 0.1 else 5.0))
	var cel := (global_basis * kier.normalized()) * v
	# bezwładność zależna od wagi
	var przysp: float = [11.0, 8.0, 5.5, 3.5][prog] if is_on_floor() else 1.5
	velocity.x = move_toward(velocity.x, cel.x, przysp * v * delta * 1.6 + 0.01)
	velocity.z = move_toward(velocity.z, cel.z, przysp * v * delta * 1.6 + 0.01)
	if is_on_floor():
		if _w_powietrzu:
			_w_powietrzu = false
			var wys := _y_spadania - global_position.y
			cialo.upadek(wys)
			Dzwiek.graj_3d("krok", global_position, get_parent(), 0.0, 0.8)
		if aktywne and Input.is_action_just_pressed("skok") and prog < 3 and wytrzymalosc > 12.0 and kucanie < 0.3:
			velocity.y = 3.6
			wytrzymalosc -= 10.0
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
			Dzwiek.graj_3d("krok", global_position, get_parent(), gl + prog * 1.5)
			var zasieg := 3.0 if kucanie > 0.5 else (16.0 if moze_biec else 8.0)
			Gra.emituj_halas(global_position, zasieg * (1.0 + prog * 0.15), self)


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
		if Input.is_action_just_pressed("bron1") and ekw.sloty["glowna"] != null and aktywny_slot != "glowna":
			_wybierz_bron("glowna")
		elif Input.is_action_just_pressed("bron2") and ekw.sloty["pistolet"] != null and aktywny_slot != "pistolet":
			_wybierz_bron("pistolet")
	var ruch: float = clampf(Vector2(velocity.x, velocity.z).length() / PREDKOSC_BIEG, 0.0, 1.0)
	bron.aktualizuj(delta, {
		"strzal": aktywne and Input.is_action_pressed("strzal"),
		"ads": aktywne and Input.is_action_pressed("celuj"),
		"przeladuj": aktywne and Input.is_action_pressed("przeladuj"),
		"tryb": aktywne and Input.is_action_just_pressed("tryb"),
		"sprawdz": aktywne and Input.is_action_just_pressed("sprawdz"),
		"moze": moze and not _biegnie,
		"ruch": ruch, "kucanie": kucanie, "celnosc": cialo.mnoznik_celnosci(),
	})
	if not aktywne or not akcja.is_empty():
		return
	for para in [["lek_bandaz", ["krwawienie_lekkie"]], ["lek_opatrunek", ["krwawienie_ciezkie"]],
			["lek_apteczka", ["leczenie"]], ["lek_szyna", ["zlamanie"]], ["lek_bolostop", ["bol"]]]:
		if Input.is_action_just_pressed(para[0]):
			uzyj_leku_efekt(para[1])


func uzyj_leku_efekt(efekty: Array) -> void:
	if not cialo.potrzebuje(efekty[0]):
		komunikat.emit("Nie ma czego leczyć")
		return
	var z := ekw.znajdz_med(efekty)
	if z.is_empty():
		komunikat.emit("Brak: " + {"krwawienie_lekkie": "bandaża", "krwawienie_ciezkie": "opatrunku", "leczenie": "apteczki", "zlamanie": "szyny", "bol": "środka przeciwbólowego"}.get(efekty[0], "leku"))
		return
	uzyj_leku(z["p"], z["szybki"])


func uzyj_leku(med: Przedmiot, szybki := true) -> void:
	if tryb_bazy or not akcja.is_empty():
		return
	var md: Dictionary = med.defn()["med"]
	var efekt: String = md["efekt"]
	if not cialo.potrzebuje(efekt):
		komunikat.emit("Nie ma czego leczyć")
		return
	var czas := float(md["czas"]) * (1.0 if szybki else 1.5)
	Dzwiek.graj("leczenie", -6.0)
	Gra.emituj_halas(global_position, 6.0, self)
	zacznij_akcje(med.nazwa(), czas, func():
		var opis := cialo.lecz(efekt, md, med)
		if efekt in ["krwawienie_lekkie", "krwawienie_ciezkie", "zlamanie"] and opis != "":
			med.dane["uzycia"] -= 1
		if med.dane["uzycia"] <= 0:
			ekw.usun_przedmiot(med)
		ekw.zmieniony.emit()
		if opis != "":
			komunikat.emit(opis)
		# apteczka leczy dalej, dopóki jest co leczyć i gracz nie przerwał
		if efekt == "leczenie" and med.dane["uzycia"] > 0 and cialo.potrzebuje("leczenie"):
			uzyj_leku(med, szybki)
	)


func zacznij_akcje(nazwa: String, czas: float, koniec: Callable) -> void:
	akcja = {"nazwa": nazwa, "t": 0.0, "czas": czas, "koniec": koniec}


func przerwij_akcje() -> void:
	akcja = {}


func _akcje(delta: float) -> void:
	if akcja.is_empty():
		return
	akcja["t"] += delta
	if akcja["t"] >= akcja["czas"]:
		var k: Callable = akcja["koniec"]
		akcja = {}
		k.call()


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
func upusc(p: Przedmiot) -> void:
	var swiat := get_parent()
	var lup := LupNaZiemi.new()
	lup.przedmiot = p
	swiat.add_child(lup)
	var przod := -global_basis.z
	lup.global_position = global_position + przod * 0.6 + Vector3.UP * 0.4
	komunikat.emit("Upuszczono: " + p.nazwa())


# ------------------------------------------------------------------ obrażenia

## Trafienie z broni przeciwnika. punkt: miejsce trafienia w świecie.
func trafiony(punkt: Vector3, obr: float, pen: float, od_kogo: Node, srut := false) -> void:
	if cialo.martwy:
		return
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
	var wynik := Balistyka.przez_pancerz({"pancerz": ekw.sloty["pancerz"], "helm": ekw.sloty["helm"]}, czesc, obr, pen)
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
		przerwij_akcje()
		komunikat.emit("Leczenie przerwane")
	ekw.zmieniony.emit()


func _smierc(przyczyna: String) -> void:
	sterowanie = false
	bron.ustaw(null)
	latarka.visible = false
	var t := create_tween()
	t.tween_property(glowa, "position:y", 0.25, 0.8).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(kamera, "rotation:z", deg_to_rad(75), 0.8)
	zginal.emit(przyczyna)
