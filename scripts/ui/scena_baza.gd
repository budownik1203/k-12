extends Node
## Baza między rajdami: schron poza kordonem. Handlarze, skrytka, kryjówka i wyjście do strefy.
## Gracz chodzi w pierwszej osobie, bez broni w rękach.

var widok: Dictionary
var swiat: Node3D
var gracz: Gracz
var ekran_ekw: Node
var handel: Node
var _wyjscie_ui: Control
var _wyjscie_root: CanvasLayer
var _hud_prompt: Label
var _hud_info: Label
var _komunikaty: VBoxContainer

# układ (metry): kryjówka x 0..8, z 0..7 · korytarz x 3,3..4,7, z 7..11 · recepcja x −6..14, z 11..25
const H_KRYJ := 2.8
const H_KOR := 2.6
const H_REC := 3.0
const REC := Rect2(-6, 11, 20, 14)
const KRYJ := Rect2(0, 0, 8, 7)
const KOR_X := Vector2(3.3, 4.7)
const IZBA2 := Rect2(8, 0, 5, 7)         # druga izba kryjówki (za przegrodą x = 8)
const PRZEJSCIE_IZB := Vector2(2.6, 4.0) # otwór w przegrodzie (z)
const CENA_IZBY := 25000

var kryjowka: Kryjowka
var _kolizje: StaticBody3D


func _ready() -> void:
	Gra._odblokuj_ekw()
	Gra.dopasuj_skrytke()
	add_to_group("ui_bazy")
	add_to_group("hud")
	widok = Widok3D.zbuduj(self, 0.06, 0.16)
	Widok3D.zastosuj(widok)
	Gra.ustawienia_zmiana.connect(func(): Widok3D.zastosuj(widok))
	swiat = widok["swiat"]
	_buduj_placowke()
	gracz = Gracz.new()
	gracz.tryb_bazy = true
	swiat.add_child(gracz)
	gracz.global_position = Vector3(4.0, 0.05, 4.6)
	gracz.rotation.y = PI
	gracz.komunikat.connect(komunikat)
	kryjowka = Kryjowka.new()
	kryjowka.baza = self
	kryjowka.gracz = gracz
	kryjowka.granice = KRYJ
	kryjowka.wysokosc = H_KRYJ
	kryjowka.strefa_drzwi = Rect2(KOR_X.x - 0.1, KRYJ.end.y - 1.0, KOR_X.y - KOR_X.x + 0.2, 1.0)
	swiat.add_child(kryjowka)
	_ustaw_izby()
	ekran_ekw = load("res://scripts/ui/ekran_ekwipunku.gd").new()
	ekran_ekw.gracz = gracz
	ekran_ekw.tryb_bazy = true
	add_child(ekran_ekw)
	handel = load("res://scripts/ui/handel_ui.gd").new()
	add_child(handel)
	var pauza = load("res://scripts/ui/menu_pauzy.gd").new()
	pauza.w_rajdzie = false
	add_child(pauza)
	_hud()
	_ekran_wyjscia()
	Dzwiek.ambient("ambient_baza", self, -6.0)
	Sterowanie.przechwyc(true)
	Sterowanie.blokada = false
	Sterowanie.menu_otwarte = false
	komunikat("Kryjówka. [B] plan i meble, [Tab] ekwipunek i skrytka. Korytarzem do recepcji placówki.")
	Gra.wskazowka.call_deferred("baza", "Placówka: twoja kryjówka (meble stawiasz pod [B], kupujesz u Kwatermistrza), korytarz i recepcja – handlarze, przedstawiciele frakcji (reputacja, lepszy sprzęt, zlecenia) i śluza do strefy.")
	if Gra.odpoczynek:
		komunikat("Wróciłeś ze strefy. Prycza czeka – sen leczy połowę ran.")
	if not Gra.zdrowie.is_empty():
		komunikat("Masz nieleczone urazy. Medyk przyjmuje (odpłatnie), prycza leczy część za darmo.")
	if float(Gra.potrzeby["glod"]) < 40.0 or float(Gra.potrzeby["pragnienie"]) < 40.0:
		komunikat("Burczy w brzuchu i zasycha w gardle. Zjedz i napij się przed wyjściem.")
	if Gra.przerwany_rajd:
		Gra.przerwany_rajd = false
		komunikat("Poprzedni rajd przerwany – operator uznany za zaginionego w akcji. Sprzęt przepadł, ubezpieczone wróci pocztą.")
	var zwrot := Gra.odbierz_poczte()
	if not zwrot.is_empty():
		komunikat("Pośrednik: ubezpieczyciel zwrócił do skrytki: " + ", ".join(zwrot))
	var args := OS.get_cmdline_user_args()
	if args.has("--zrzuty"):
		_zrzuty.call_deferred(args[args.find("--zrzuty") + 1])
	elif args.has("--test_kryjowki"):
		_test_kryjowki.call_deferred()
	elif args.has("--prezentacja"):
		_prezentacja.call_deferred(args[args.find("--prezentacja") + 1])


# ------------------------------------------------------------------ budowa placówki

func _buduj_placowke() -> void:
	var b := Kit.Budowniczy.new()
	_kolizje = StaticBody3D.new()
	_kolizje.collision_layer = Balistyka.WARSTWA_SWIAT
	swiat.add_child(_kolizje)
	_box_kolizji(Vector3(4, -0.2, 12.5), Vector3(24, 0.4, 28))
	var uv_k := func(u: float, y: float) -> Vector2: return Vector2(u, 1.0 - y / 2.8)
	var uv_r := func(u: float, y: float) -> Vector2: return Vector2(u, 1.0 - y / H_REC)
	# kryjówka: surowy beton (bunkier pod placówką)
	b.plaszczyzna("beton", KRYJ.position.x, KRYJ.position.y, KRYJ.end.x, KRYJ.end.y, 0.0, true, 2.0, 1.0)
	b.plaszczyzna("beton", KRYJ.position.x, KRYJ.position.y, KRYJ.end.x, KRYJ.end.y, H_KRYJ, false, 2.0, 1.0)
	_sciana(b, "beton_sciana", Vector3(0, 0, 0), Vector3(8, 0, 0), H_KRYJ, [], uv_k)
	_sciana(b, "beton_sciana", Vector3(0, 0, 7), Vector3(0, 0, 0), H_KRYJ, [], uv_k)
	# druga izba (za przegrodą – dostępna po wykupieniu u Kwatermistrza)
	b.plaszczyzna("beton", IZBA2.position.x, IZBA2.position.y, IZBA2.end.x, IZBA2.end.y, 0.0, true, 2.0, 1.0)
	b.plaszczyzna("beton", IZBA2.position.x, IZBA2.position.y, IZBA2.end.x, IZBA2.end.y, H_KRYJ, false, 2.0, 1.0)
	_sciana(b, "beton_sciana", Vector3(8, 0, 0), Vector3(13, 0, 0), H_KRYJ, [], uv_k)
	_sciana(b, "beton_sciana", Vector3(13, 0, 0), Vector3(13, 0, 7), H_KRYJ, [], uv_k)
	_sciana(b, "beton_sciana", Vector3(13, 0, 7), Vector3(8, 0, 7), H_KRYJ, [], uv_k)
	_sciana(b, "beton_sciana", Vector3(8, 0, 7), Vector3(0, 0, 7), H_KRYJ, [[8.0 - KOR_X.y, 8.0 - KOR_X.x, 2.2]], uv_k)
	# korytarz: lamperia, lastryko
	b.plaszczyzna("lastryko", KOR_X.x, 7.0, KOR_X.y, 11.0, 0.0, true, 1.0, 1.0)
	b.plaszczyzna("tynk_bialy", KOR_X.x, 7.0, KOR_X.y, 11.0, H_KOR, false, 1.0, 1.0)
	_sciana(b, "sciana_lamperia", Vector3(KOR_X.x, 0, 11), Vector3(KOR_X.x, 0, 7), H_KOR, [], uv_k)
	_sciana(b, "sciana_lamperia", Vector3(KOR_X.y, 0, 7), Vector3(KOR_X.y, 0, 11), H_KOR, [], uv_k)
	b.sciana("sciana_lamperia", Vector3(KOR_X.x, 0, 7), Vector3(KOR_X.y, 0, 7), 2.2, H_KOR, 1.0, uv_k)
	b.sciana("sciana_lamperia", Vector3(KOR_X.y, 0, 11), Vector3(KOR_X.x, 0, 11), 2.4, H_KOR, 1.0, uv_k)
	# recepcja placówki
	b.plaszczyzna("lastryko", REC.position.x, REC.position.y, REC.end.x, REC.end.y, 0.0, true, 1.0, 1.0)
	b.plaszczyzna("tynk_bialy", REC.position.x, REC.position.y, REC.end.x, REC.end.y, H_REC, false, 2.0, 1.0)
	_sciana(b, "sciana_lamperia", Vector3(REC.position.x, 0, 11), Vector3(REC.end.x, 0, 11), H_REC, [[KOR_X.x - REC.position.x, KOR_X.y - REC.position.x, 2.4]], uv_r)
	_sciana(b, "sciana_lamperia", Vector3(REC.end.x, 0, 11), Vector3(REC.end.x, 0, 25), H_REC, [], uv_r)
	_sciana(b, "sciana_lamperia", Vector3(REC.end.x, 0, 25), Vector3(REC.position.x, 0, 25), H_REC, [], uv_r)
	_sciana(b, "sciana_lamperia", Vector3(REC.position.x, 0, 25), Vector3(REC.position.x, 0, 11), H_REC, [], uv_r)
	# filary nośne hali (osłaniają też widok między strefami)
	for fp in [Vector2(0.5, 18.0), Vector2(7.5, 18.0)]:
		var r := 0.3
		var nar := [Vector3(fp.x - r, 0, fp.y - r), Vector3(fp.x - r, 0, fp.y + r), Vector3(fp.x + r, 0, fp.y + r), Vector3(fp.x + r, 0, fp.y - r)]
		for i in 4:
			b.sciana("sciana_lamperia", nar[i], nar[(i + 1) % 4], 0.0, H_REC, 1.0, uv_r)
		_box_kolizji(Vector3(fp.x, H_REC * 0.5, fp.y), Vector3(r * 2, H_REC, r * 2))
	var mi := MeshInstance3D.new()
	mi.mesh = b.zbuduj()
	swiat.add_child(mi)
	# futryny przejść
	var B := preload("res://scripts/core/bryly.gd")
	var fut := []
	for zf in [7.0, 11.0]:
		var top := 2.2 if zf == 7.0 else 2.4
		for xf in [KOR_X.x + 0.04, KOR_X.y - 0.04]:
			fut.append({"t": "box", "c": Vector3(xf, top * 0.5, zf), "s": Vector3(0.08, top, 0.26), "m": "metal_ciemny_m", "f": 0.006})
		fut.append({"t": "box", "c": Vector3((KOR_X.x + KOR_X.y) * 0.5, top + 0.04, zf), "s": Vector3(KOR_X.y - KOR_X.x, 0.08, 0.26), "m": "metal_ciemny_m", "f": 0.006})
	swiat.add_child(B.instancja(fut, false))
	var gen := GeneratorBiomu.new()
	gen.swiat = swiat
	gen.meble = Dane.meble
	_stragany(gen)
	_frakcje(gen)
	_sluza(gen)
	# wystrój recepcji
	gen._mebel("tablica_ogloszen", Vector3(-1.5, 1.4, 11.05), 0.0, false)
	gen._mebel("skrzynki_pocztowe", Vector3(9.5, 1.1, 11.08), 0.0, false)
	gen._mebel("hydrant", Vector3(2.4, 1.0, 11.05), 0.0, false)
	gen._mebel("kaloryfer", Vector3(-3.5, 0.25, 11.07), 0.0, false)
	gen._mebel("kaloryfer", Vector3(11.0, 0.25, 11.07), 0.0, false)
	for xl in [-2.0, 1.0]:
		gen._mebel("krzeslo", Vector3(xl, 0, 12.2), PI, true)
		gen._mebel("krzeslo", Vector3(xl + 0.55, 0, 12.2), PI, true)
	gen._mebel("beczka", Vector3(13.4, 0, 11.6), 0.0, true)
	# poczekalnia między filarami
	gen._mebel("stol", Vector3(4.0, 0, 18.0), 0.0, true)
	for kp in [[3.3, 18.0, PI * 0.5], [4.7, 18.0, -PI * 0.5], [4.0, 17.4, 0.0]]:
		gen._mebel("krzeslo", Vector3(kp[0], 0, kp[1]), kp[2], true)
	gen._mebel("dywan", Vector3(4.0, 0, 18.0), 0.0, false)
	# światło
	for p in [Vector3(4.0, H_KRYJ, 3.5), Vector3(4.0, H_KOR, 9.0), Vector3(10.5, H_KRYJ, 3.5)]:
		_lampa(p, true, 1.7 if p.z < 7.0 else 0.9, 8.0 if p.z < 7.0 else 6.0)
	for p in [Vector3(-2.5, H_REC, 14.5), Vector3(-2.5, H_REC, 20.5), Vector3(4.0, H_REC, 17.5), Vector3(10.5, H_REC, 14.5), Vector3(10.5, H_REC, 20.5), Vector3(4.0, H_REC, 23.2)]:
		_lampa(p, false, 1.35, 8.0)


func _lampa(p: Vector3, gola: bool, energia: float, zasieg: float) -> void:
	var lampa: Node3D = load("res://assets/models/meble/zarowka.glb" if gola else "res://assets/models/plafon.glb").instantiate()
	swiat.add_child(lampa)
	lampa.position = p
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.82, 0.6) if not gola else Color(1.0, 0.74, 0.48)
	l.light_energy = energia
	l.omni_range = zasieg
	l.omni_attenuation = 0.9
	swiat.add_child(l)
	l.position = p + Vector3(0, -0.45 if not gola else -0.7, 0)


## Przegroda między izbami kryjówki: pełna albo przebita (otwór z futryną). Ustawia też granice stawiania.
var _przegroda: Node3D

func _ustaw_izby() -> void:
	if _przegroda and is_instance_valid(_przegroda):
		_przegroda.queue_free()
	var dwie := Gra.izby_kryjowki >= 2
	_przegroda = Node3D.new()
	_przegroda.name = "Przegroda"
	swiat.add_child(_przegroda)
	var b := Kit.Budowniczy.new()
	var uv_k := func(u: float, y: float) -> Vector2: return Vector2(u, 1.0 - y / 2.8)
	var sb := StaticBody3D.new()
	sb.collision_layer = Balistyka.WARSTWA_SWIAT
	_przegroda.add_child(sb)
	var stare := _kolizje
	_kolizje = sb
	var otw := [[PRZEJSCIE_IZB.x, PRZEJSCIE_IZB.y, 2.2]] if dwie else []
	var otw2 := [[7.0 - PRZEJSCIE_IZB.y, 7.0 - PRZEJSCIE_IZB.x, 2.2]] if dwie else []
	_sciana(b, "beton_sciana", Vector3(8, 0, 0), Vector3(8, 0, 7), H_KRYJ, otw, uv_k)
	_sciana(b, "beton_sciana", Vector3(8, 0, 7), Vector3(8, 0, 0), H_KRYJ, otw2, uv_k)
	_kolizje = stare
	var mi := MeshInstance3D.new()
	mi.mesh = b.zbuduj()
	_przegroda.add_child(mi)
	if dwie:
		var B := preload("res://scripts/core/bryly.gd")
		var fut := []
		for zf in [PRZEJSCIE_IZB.x + 0.04, PRZEJSCIE_IZB.y - 0.04]:
			fut.append({"t": "box", "c": Vector3(8.0, 1.1, zf), "s": Vector3(0.26, 2.2, 0.08), "m": "metal_ciemny_m", "f": 0.006})
		fut.append({"t": "box", "c": Vector3(8.0, 2.24, (PRZEJSCIE_IZB.x + PRZEJSCIE_IZB.y) * 0.5), "s": Vector3(0.26, 0.08, PRZEJSCIE_IZB.y - PRZEJSCIE_IZB.x), "m": "metal_ciemny_m", "f": 0.006})
		_przegroda.add_child(B.instancja(fut, false))
	kryjowka.granice = KRYJ.merge(IZBA2) if dwie else KRYJ
	kryjowka.przeszkody = [Rect2(7.9, 0.0, 0.2, PRZEJSCIE_IZB.x), Rect2(7.9, PRZEJSCIE_IZB.y, 0.2, 7.0 - PRZEJSCIE_IZB.y)] if dwie else []
	kryjowka.wolne_strefy = [Rect2(7.4, PRZEJSCIE_IZB.x, 1.2, PRZEJSCIE_IZB.y - PRZEJSCIE_IZB.x)] if dwie else []


## Kwatermistrz: przebicie ściany do drugiej izby.
func rozbuduj_kryjowke() -> bool:
	if Gra.izby_kryjowki >= 2 or Gra.bony < CENA_IZBY:
		return false
	Gra.dodaj_bony(-CENA_IZBY)
	Gra.izby_kryjowki = 2
	Gra.zapisz()
	_ustaw_izby()
	komunikat("Ekipa przebiła ścianę. Druga izba kryjówki jest twoja.")
	return true


func _box_kolizji(c: Vector3, s: Vector3, rot := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = s
	cs.shape = bs
	cs.position = c
	cs.rotation.y = rot
	_kolizje.add_child(cs)


## Ściana od a do b (wnętrze po lewej patrząc z góry: kierunek × góra), z otworami [od, do, wysokość nadproża] (m od a).
func _sciana(b: Kit.Budowniczy, mat: String, a: Vector3, k: Vector3, h: float, otwory: Array, uv: Callable) -> void:
	var dl := a.distance_to(k)
	var d := (k - a) / dl
	var s := 0.0
	var ciecia := otwory.duplicate()
	ciecia.sort_custom(func(x, y): return x[0] < y[0])
	var odcinki := []
	for o in ciecia:
		odcinki.append([s, float(o[0]), 0.0])
		odcinki.append([float(o[0]), float(o[1]), float(o[2])])
		s = float(o[1])
	odcinki.append([s, dl, 0.0])
	for od in odcinki:
		if od[1] - od[0] < 0.001:
			continue
		var pa: Vector3 = a + d * float(od[0])
		var pb: Vector3 = a + d * float(od[1])
		b.sciana(mat, pa, pb, float(od[2]), h, 1.0, uv)
		# kolizja: pełny odcinek ściany (nadproża ponad głową – też, żeby nie przeskoczyć)
		var srodek := (pa + pb) * 0.5
		var dlo := pa.distance_to(pb)
		var y0 := float(od[2])
		var n := d.cross(Vector3.UP)
		_box_kolizji(Vector3(srodek.x, (y0 + h) * 0.5, srodek.z) - n * 0.1, Vector3(dlo, h - y0, 0.2), atan2(-d.z, d.x))


## Stragany handlarzy pod ścianami recepcji (plandeka, lada, towar, handlarz za ladą).
func _stragany(gen: GeneratorBiomu) -> void:
	var lz := REC.position.x + 1.95
	var pz := REC.end.x - 1.95
	_stragan(gen, "zbrojmistrz", "Zbrojmistrz", Vector3(lz, 0, 14.5), PI * 0.5, Color(0.36, 0.4, 0.28), {"ubranie": Color(0.26, 0.29, 0.22), "spodnie": Color(0.2, 0.22, 0.18), "dodatek": Color(0.2, 0.24, 0.16)})
	_stragan(gen, "medyk", "Medyk", Vector3(lz, 0, 20.2), PI * 0.5, Color(0.8, 0.8, 0.76), {"ubranie": Color(0.5, 0.52, 0.5), "spodnie": Color(0.3, 0.3, 0.32), "dodatek": Color(0.8, 0.8, 0.75)})
	_stragan(gen, "posrednik", "Pośrednik", Vector3(pz, 0, 14.5), -PI * 0.5, Color(0.5, 0.2, 0.16), {"ubranie": Color(0.24, 0.2, 0.18), "spodnie": Color(0.15, 0.14, 0.13), "dodatek": Color(0.3, 0.24, 0.2)})
	_stragan(gen, "kwatermistrz", "Kwatermistrz", Vector3(pz, 0, 20.2), -PI * 0.5, Color(0.25, 0.32, 0.45), {"ubranie": Color(0.3, 0.32, 0.36), "spodnie": Color(0.2, 0.2, 0.22), "dodatek": Color(0.35, 0.3, 0.24)})


## Stragan w układzie lokalnym: lada wzdłuż X w z = 0, klient od +Z, handlarz w z = −0,95, ściana w z = −1,95.
func _stragan(gen: GeneratorBiomu, id: String, nazwa: String, poz: Vector3, rot: float, plandeka: Color, kol: Dictionary) -> void:
	var B := preload("res://scripts/core/bryly.gd")
	var piv := Node3D.new()
	piv.name = "Stragan_" + id
	swiat.add_child(piv)
	piv.position = poz
	piv.rotation.y = rot
	var cz := []
	var szer := 3.6
	var medyk := id == "medyk"
	var drewno := Color(0.5, 0.36, 0.24) if not medyk else Color(0.85, 0.85, 0.8)
	var m_korp := "drewno_m" if not medyk else "emalia_m"
	cz.append({"t": "box", "c": Vector3(0, 0.5, 0), "s": Vector3(szer, 1.0, 0.5), "m": m_korp, "k": drewno, "f": 0.01})
	cz.append({"t": "box", "c": Vector3(0, 1.025, -0.04), "s": Vector3(szer + 0.08, 0.05, 0.66), "m": "metal_jasny" if id == "zbrojmistrz" else "fornir_m", "k": Color(0.62, 0.62, 0.6) if id == "zbrojmistrz" else Color(0.55, 0.4, 0.28), "f": 0.006})
	cz.append({"t": "box", "c": Vector3(0, 0.05, 0.24), "s": Vector3(szer, 0.1, 0.03), "m": "metal_ciemny_m", "f": 0.0})
	for i in 5:
		cz.append({"t": "box", "c": Vector3(-szer * 0.5 + (i + 0.5) * szer / 5.0, 0.5, 0.252), "s": Vector3(0.012, 0.86, 0.006), "m": "czern", "k": Color(0.2, 0.15, 0.1), "f": 0.0})
	# słupki i plandeka w pasy (spadek ku klientowi)
	for sx in [-szer * 0.5 - 0.02, szer * 0.5 + 0.02]:
		cz.append(B.walec(Vector3(sx, 0, 0.32), Vector3(sx, 2.25, 0.32), 0.03, 0.03, "metal_ciemny_m", 6))
		cz.append(B.walec(Vector3(sx, 0, -1.9), Vector3(sx, 2.55, -1.9), 0.03, 0.03, "metal_ciemny_m", 6))
		# boczne ścianki z desek
		cz.append({"t": "box", "c": Vector3(sx, 1.1, -0.8), "s": Vector3(0.03, 2.2, 2.2), "m": "drewno_m", "k": drewno.darkened(0.15), "f": 0.004})
	var pasy := 8
	for i in pasy:
		var x0 := -szer * 0.5 - 0.1 + (szer + 0.2) * i / float(pasy)
		var k := plandeka if i % 2 == 0 else Color(0.82, 0.78, 0.66)
		cz.append({"t": "box", "c": Vector3(x0 + (szer + 0.2) / pasy * 0.5, 2.42, -0.78), "s": Vector3((szer + 0.2) / pasy, 0.02, 2.5), "m": "tkanina", "k": k, "f": 0.0, "r": Vector3(-7.5, 0, 0)})
		cz.append({"t": "box", "c": Vector3(x0 + (szer + 0.2) / pasy * 0.5, 2.18, 0.47), "s": Vector3((szer + 0.2) / pasy, 0.18, 0.015), "m": "tkanina", "k": k, "f": 0.0})
	match id:
		"zbrojmistrz":
			var x := -szer * 0.5
			while x <= szer * 0.5 + 0.001:
				if absf(x) > 0.32:
					cz.append(B.walec(Vector3(x, 1.05, -0.25), Vector3(x, 2.3, -0.25), 0.009, 0.009, "metal_ciemny_m", 6))
				x += 0.12
			for y in [1.06, 1.75, 2.3]:
				cz.append({"t": "box", "c": Vector3(0, y, -0.25), "s": Vector3(szer, 0.03, 0.02), "m": "metal_ciemny_m", "f": 0.003})
			cz.append({"t": "box", "c": Vector3(0, 1.55, -0.25), "s": Vector3(0.7, 0.03, 0.03), "m": "metal_ciemny_m", "f": 0.003})
			cz.append({"t": "box", "c": Vector3(1.0, 1.2, -1.87), "s": Vector3(1.4, 0.06, 0.12), "m": "drewno_m", "k": drewno, "f": 0.006})
			cz.append({"t": "box", "c": Vector3(1.0, 0.35, -1.83), "s": Vector3(1.4, 0.08, 0.2), "m": "drewno_m", "k": drewno, "f": 0.006})
		"medyk":
			cz.append({"t": "box", "c": Vector3(0, 1.6, -0.2), "s": Vector3(szer, 1.1, 0.012), "m": "metal_jasny", "k": Color(0.7, 0.85, 0.85), "f": 0.0})
			cz.append({"t": "box", "c": Vector3(0, 1.07, -0.2), "s": Vector3(0.5, 0.06, 0.03), "m": "czern", "f": 0.0})
			# czerwony krzyż na plandece
			cz.append({"t": "box", "c": Vector3(0, 2.18, 0.485), "s": Vector3(0.36, 0.1, 0.01), "m": "tkanina", "k": Color(0.75, 0.1, 0.08), "f": 0.0})
			cz.append({"t": "box", "c": Vector3(0, 2.18, 0.485), "s": Vector3(0.1, 0.16, 0.01), "m": "tkanina", "k": Color(0.75, 0.1, 0.08), "f": 0.0})
		"kwatermistrz":
			# próbki: deski i blachy oparte o ścianę
			for i in 4:
				cz.append({"t": "box", "c": Vector3(-1.3 + i * 0.16, 0.9, -1.8 + i * 0.02), "s": Vector3(0.12, 1.8, 0.03), "m": "drewno_m", "k": drewno.darkened(i * 0.05), "f": 0.003, "r": Vector3(-6, 0, 0)})
		_:
			cz.append({"t": "box", "c": Vector3(-1.2, 1.12, -0.1), "s": Vector3(0.36, 0.14, 0.3), "m": "metal_jasny", "k": Color(0.35, 0.33, 0.3), "f": 0.01})
			cz.append({"t": "box", "c": Vector3(-1.2, 1.24, -0.18), "s": Vector3(0.3, 0.1, 0.06), "m": "czern", "f": 0.004})
	var mi := B.instancja(cz, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	piv.add_child(mi)
	var sb := StaticBody3D.new()
	sb.collision_layer = Balistyka.WARSTWA_SWIAT
	piv.add_child(sb)
	for c in [[Vector3(0, 0.525, -0.04), Vector3(szer + 0.08, 1.05, 0.66)], [Vector3(-szer * 0.5 - 0.02, 1.1, -0.8), Vector3(0.06, 2.2, 2.2)], [Vector3(szer * 0.5 + 0.02, 1.1, -0.8), Vector3(0.06, 2.2, 2.2)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = c[1]
		cs.shape = bs
		cs.position = c[0]
		sb.add_child(cs)
	# meble zaplecza
	match id:
		"zbrojmistrz":
			_mebel_lok(gen, piv, "regal_metalowy", Vector3(-1.1, 0, -1.7), 0.0)
			_mebel_lok(gen, piv, "skrzynia_wojskowa", Vector3(0.2, 0, -1.65), 0.0)
		"medyk":
			_mebel_lok(gen, piv, "szafka_metalowa", Vector3(1.3, 0, -1.7), 0.0)
			_mebel_lok(gen, piv, "lozko", Vector3(-0.9, 0, -1.45), 0.0)
		"posrednik":
			_mebel_lok(gen, piv, "regal_metalowy", Vector3(-1.1, 0, -1.7), 0.0)
			_mebel_lok(gen, piv, "regal_metalowy", Vector3(1.1, 0, -1.7), 0.0)
		"kwatermistrz":
			_mebel_lok(gen, piv, "szafka_metalowa", Vector3(0.4, 0, -1.7), 0.0)
			_mebel_lok(gen, piv, "skrzynia", Vector3(1.2, 0, -1.6), 0.3)
			_mebel_lok(gen, piv, "krzeslo", Vector3(0.9, 0, -0.9), PI)
	# towar na blacie
	var towar: Array = {"zbrojmistrz": [["mag_kb47", -0.9, 0.0], ["a_762", -0.55, 0.3], ["a_9x18", 0.6, 0.0], ["mag_pw9", 0.9, 0.5], ["hamulec", 1.25, 0.2]],
		"medyk": [["bandaz", -1.0, 0.2], ["apteczka", -0.4, 0.0], ["bolostop", 0.5, 0.4], ["szyna", 1.1, 0.1], ["opatrunek", 0.8, 1.2]],
		"posrednik": [["telefon", -0.4, 0.3], ["teczka_akt", 0.4, 0.1], ["zegarek", 0.85, 0.7], ["papierosy", 1.2, 0.2], ["radio", 1.4, 0.0]],
		"kwatermistrz": [["klucz_nastawny", -0.8, 0.4], ["tasma", -0.3, 0.0], ["kombinerki", 0.5, 0.9], ["latarka", 1.1, 0.2]]}.get(id, [])
	for t in towar:
		if not Dane.przedmioty.has(t[0]):
			continue
		var w := ModelePrzedmiotow.wezel(Przedmiot.nowy(t[0]))
		piv.add_child(w)
		w.position = Vector3(float(t[1]), 1.05, -0.08 + randf_range(-0.12, 0.12))
		w.rotation.y = float(t[2])
	if id == "zbrojmistrz":
		for i in 3:
			var bid: String = ["kb47", "pm63", "obrzyn"][i]
			var bw := ModelePrzedmiotow.wezel(Przedmiot.nowy(bid))
			piv.add_child(bw)
			Kryjowka.postaw_pionowo(bw, Vector3(0.55 + i * 0.42, 0.4, -1.79))
	_postac(id, nazwa, piv.to_global(Vector3(0, 0, -0.95)), rot + PI, kol, id)


func _mebel_lok(gen: GeneratorBiomu, piv: Node3D, id: String, lok: Vector3, rot: float) -> void:
	gen._mebel(id, piv.to_global(lok), piv.rotation.y + rot, true)


func _postac(id: String, nazwa: String, pos: Vector3, rot: float, kol: Dictionary, wariant: String) -> void:
	var n := PostacNPC.new()
	n.nazwa = nazwa
	n.id_handlarza = id
	n.wariant = wariant
	n.kolory = kol
	swiat.add_child(n)
	n.position = pos
	n.rotation.y = rot


## Przedstawiciele frakcji: stoliki w rogach recepcji, Wojsko w punkcie kontrolnym przy śluzie.
func _frakcje(gen: GeneratorBiomu) -> void:
	# Szabrownicy – kąt z beczką i skrzynkami, łup na stole
	gen._mebel("stol", Vector3(-3.6, 0, 23.2), 0.0, true)
	gen._mebel("beczka", Vector3(-5.4, 0, 24.3), 0.0, true)
	gen._mebel("skrzynia", Vector3(-1.7, 0, 24.4), 0.4, true)
	gen._mebel("krzeslo", Vector3(-3.6, 0, 22.4), PI, true)
	for t in [["wodka", -3.9, 0.3], ["zegarek", -3.4, 1.0], ["papierosy", -3.1, 0.2]]:
		var w := ModelePrzedmiotow.wezel(Przedmiot.nowy(t[0]))
		swiat.add_child(w)
		w.position = Vector3(float(t[1]), 0.76, 23.2)
		w.rotation.y = float(t[2])
	_postac("szabrownik", "Zenek „Kulawy” (Szabrownicy)", Vector3(-3.6, 0, 24.1), 0.0, {"ubranie": Color(0.36, 0.3, 0.24), "spodnie": Color(0.22, 0.22, 0.24), "dodatek": Color(0.25, 0.22, 0.2)}, "szabrownik")
	# Najemnicy – stół werbunkowy, skrzynie wojskowe
	gen._mebel("stol", Vector3(11.4, 0, 23.2), 0.0, true)
	gen._mebel("skrzynia_wojskowa", Vector3(13.2, 0, 24.4), PI * 0.5, true)
	gen._mebel("skrzynia_wojskowa", Vector3(9.5, 0, 24.5), 0.0, true)
	gen._mebel("krzeslo", Vector3(11.4, 0, 22.4), PI, true)
	for t in [["mapa", 11.0, 0.2], ["kompas", 11.8, 0.0]]:
		var w2 := ModelePrzedmiotow.wezel(Przedmiot.nowy(t[0]))
		swiat.add_child(w2)
		w2.position = Vector3(float(t[1]), 0.76, 23.2)
		w2.rotation.y = float(t[2])
	_postac("najemnik", "kpt. Rys (Najemnicy)", Vector3(11.4, 0, 24.1), 0.0, {"ubranie": Color(0.24, 0.27, 0.22), "spodnie": Color(0.2, 0.22, 0.18), "dodatek": Color(0.16, 0.17, 0.15)}, "najemnik")
	# Wojsko – punkt kontrolny z worków przy śluzie
	gen._mebel("worki_piasek", Vector3(7.0, 0, 22.9), 0.0, true)
	gen._mebel("biurko", Vector3(7.2, 0, 23.9), PI, true)
	_postac("wojskowy", "por. Wrona (Wojsko)", Vector3(7.2, 0, 24.55), 0.0, {"ubranie": Color(0.3, 0.33, 0.24), "spodnie": Color(0.27, 0.29, 0.21), "dodatek": Color(0.22, 0.25, 0.18)}, "wojskowy")


## Śluza do strefy: stalowe drzwi w północnej ścianie, znak, interakcja – rozkaz wyjścia.
func _sluza(gen: GeneratorBiomu) -> void:
	var drzwi: Node3D = load("res://assets/models/drzwi_piwnica.glb").instantiate()
	swiat.add_child(drzwi)
	drzwi.position = Vector3(4.0, 0, REC.end.y - 0.1)
	drzwi.rotation.y = PI
	gen._mebel("znak_wyjscie", Vector3(4.0, 2.3, REC.end.y - 0.05), PI, false)
	gen._mebel("worki_piasek", Vector3(2.2, 0, 24.4), PI * 0.5, true)
	var w := StaticBody3D.new()
	w.collision_layer = Balistyka.WARSTWA_INTERAKCJE
	w.set_meta("interakcja", _Wyjscie.new(self))
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(1.2, 2.2, 0.4)
	cs2.shape = bs2
	cs2.position.y = 1.1
	w.add_child(cs2)
	swiat.add_child(w)
	w.position = Vector3(4.0, 0, REC.end.y - 0.2)


func pokaz_wskazowke(t: String) -> void:
	komunikat("Wskazówka: " + t)


func otworz_handel(id: String) -> void:
	handel.otworz(id)


class _Wyjscie:
	extends RefCounted
	var baza

	func _init(b) -> void:
		baza = b

	func tekst_interakcji(_g) -> String:
		return "Śluza: wyjdź do strefy (rajd)"

	func interakcja(_g) -> void:
		baza.pokaz_wyjscie()


# ------------------------------------------------------------------ HUD bazy

func _hud() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Motyw.motyw()
	cl.add_child(root)
	_hud_prompt = Label.new()
	_hud_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hud_prompt.offset_left = -400
	_hud_prompt.offset_right = 400
	_hud_prompt.offset_top = -130
	_hud_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_prompt.add_theme_font_size_override("font_size", 17)
	root.add_child(_hud_prompt)
	_hud_info = Label.new()
	_hud_info.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud_info.offset_left = -420
	_hud_info.offset_right = -24
	_hud_info.offset_top = 20
	_hud_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_info.add_theme_font_override("font", Motyw.mono())
	_hud_info.add_theme_font_size_override("font_size", 14)
	root.add_child(_hud_info)
	_komunikaty = VBoxContainer.new()
	_komunikaty.position = Vector2(24, 20)
	root.add_child(_komunikaty)
	var kropka := ColorRect.new()
	kropka.color = Color(0.85, 0.82, 0.7, 0.6)
	kropka.set_anchors_preset(Control.PRESET_CENTER)
	kropka.offset_left = -1.5
	kropka.offset_top = -1.5
	kropka.offset_right = 1.5
	kropka.offset_bottom = 1.5
	root.add_child(kropka)


func _process(_d: float) -> void:
	_hud_prompt.text = (("" if "[F]" in gracz.tekst_interakcji else "[F] ") + gracz.tekst_interakcji) if gracz.tekst_interakcji != "" and not Sterowanie.blokada else ""
	var s: Dictionary = Gra.statystyki
	# pod otwartym ekranem (handel, skrytka, ekwipunek) licznik bazy by się nakładał na jego nagłówek
	_hud_info.visible = not (Sterowanie.blokada or handel.otwarty or (ekran_ekw and ekran_ekw.get("otwarty")))
	_hud_info.text = "BONY: %d\nRajdy: %d · przeżyte: %d · zgony: %d" % [Gra.bony, s["rajdy"], s["przezyte"], s["zgony"]]


func komunikat(t: String) -> void:
	var l := Motyw.etykieta(t, 15)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	# długie komunikaty zawijane – nie wchodzą pod licznik bonów w prawym górnym rogu
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var szer := _komunikaty.get_viewport_rect().size.x / maxf(0.01, _komunikaty.get_global_transform_with_canvas().get_scale().x)
	l.custom_minimum_size = Vector2(clampf(szer - 24.0 - 460.0, 320.0, 860.0), 0)
	_komunikaty.add_child(l)
	while _komunikaty.get_child_count() > 5:
		var c := _komunikaty.get_child(0)
		_komunikaty.remove_child(c)
		c.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ ekran wyjścia na rajd

func _ekran_wyjscia() -> void:
	_wyjscie_root = CanvasLayer.new()
	_wyjscie_root.layer = 25
	add_child(_wyjscie_root)
	_wyjscie_ui = Control.new()
	_wyjscie_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wyjscie_ui.theme = Motyw.motyw()
	_wyjscie_ui.visible = false
	_wyjscie_root.add_child(_wyjscie_ui)


func pokaz_wyjscie() -> void:
	for c in _wyjscie_ui.get_children():
		c.queue_free()
	var tlo := ColorRect.new()
	tlo.color = Color(0, 0, 0, 0.8)
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wyjscie_ui.add_child(tlo)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wyjscie_ui.add_child(cc)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(560, 0)
	var stp := Motyw.panel(Color(0.78, 0.74, 0.62), Color(0.3, 0.26, 0.2), 2)
	stp.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", stp)
	cc.add_child(p)
	# rozkaz przewijany (zlecenia, ostrzeżenia, meldunki potrafią zająć więcej niż okno); przyciski zawsze na dole
	var zew := VBoxContainer.new()
	zew.add_theme_constant_override("separation", 8)
	p.add_child(zew)
	var przew := ScrollContainer.new()
	przew.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	zew.add_child(przew)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	przew.add_child(v)
	var dopasuj := func():
		if not is_instance_valid(przew):
			return
		var skala := maxf(0.01, przew.get_global_transform_with_canvas().get_scale().y)
		var maks := przew.get_viewport_rect().size.y / skala - 140.0
		przew.custom_minimum_size = Vector2(0, clampf(v.get_combined_minimum_size().y, 120.0, maxf(200.0, maks)))
	v.minimum_size_changed.connect(dopasuj)
	dopasuj.call_deferred()
	var ciemny := Color(0.15, 0.13, 0.1)
	v.add_child(Motyw.etykieta("ROZKAZ WYJŚCIA DO STREFY NR %d/K-12" % (Gra.statystyki["rajdy"] + 1), 20, ciemny, Motyw.mono_b()))
	v.add_child(Motyw.etykieta("Obszar: Biom 1 – Blokowisko (przedmieścia, osiedle z wielkiej płyty)", 14, ciemny))
	v.add_child(Motyw.etykieta("Cel: wejść, zebrać, wyjść. Kolejność nie podlega negocjacji.", 14, ciemny))
	var e: Ekwipunek = Gra.ekw
	var bronie := []
	for sl in ["glowna", "pistolet"]:
		if e.sloty[sl]:
			bronie.append(e.sloty[sl].nazwa())
	var bron := ", ".join(bronie) if not bronie.is_empty() else "brak"
	v.add_child(Motyw.etykieta("Broń: %s" % bron, 14, ciemny, Motyw.mono()))
	v.add_child(Motyw.etykieta("Wartość wyposażenia (ryzykowana): %d bonów" % e.wartosc(), 14, ciemny, Motyw.mono()))
	v.add_child(Motyw.etykieta("Waga efektywna: %.1f kg" % e.waga(), 14, ciemny, Motyw.mono()))
	var ostrz := []
	if not Gra.ma_bron():
		ostrz.append("BRAK BRONI. Zbrojmistrz wyda darmowy zestaw startowy.")
	if not Gra.zdrowie.is_empty():
		ostrz.append("Nieleczone urazy (koszt u Medyka: %d bonów)." % load("res://scripts/ui/handel_ui.gd").koszt_leczenia())
	var mags := 0
	for s in e.siatki():
		for it in (s as Siatka).items:
			if it["p"].typ() == "magazynek" and it["p"].dane["naboje"] > 0:
				mags += 1
	if Gra.ma_bron() and mags == 0 and (e.sloty["glowna"] == null or not e.sloty["glowna"].defn()["bron"].has("wewnetrzny")):
		ostrz.append("Brak zapasowych załadowanych magazynków.")
	var gl := float(Gra.potrzeby["glod"])
	var pr := float(Gra.potrzeby["pragnienie"])
	if gl < 45.0 or pr < 45.0:
		ostrz.append("Głód %d%%, nawodnienie %d%% – droga do strefy zabierze jeszcze ok. 10 i 14 pkt." % [int(gl), int(pr)])
	for o in ostrz:
		v.add_child(Motyw.etykieta("⚠ " + o, 14, Color(0.55, 0.1, 0.06), Motyw.mono_b()))
	var rozejmy := []
	for f in FrakcjeBazy.DANE:
		if FrakcjeBazy.rep(f) >= FrakcjeBazy.prog_rozejmu(f):
			rozejmy.append(FrakcjeBazy.DANE[f]["nazwa"])
	if not rozejmy.is_empty():
		v.add_child(Motyw.etykieta("Rozejm (nie strzelają pierwsi): " + ", ".join(rozejmy), 13, ciemny, Motyw.mono()))
	var akt: Array = Gra.kontrakty.get("aktywne", [])
	for k in akt:
		var lz := Motyw.etykieta("Zlecenie: " + String(k["opis"]), 13, ciemny, Motyw.mono())
		lz.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lz.custom_minimum_size = Vector2(520, 0)
		v.add_child(lz)
	if MebleKryjowki.ma_funkcje(Gra.kryjowka, "meldunki"):
		for linia in Gra.meldunki():
			var lm := Motyw.etykieta("Meldunek: " + linia, 13, Color(0.2, 0.3, 0.45), Motyw.mono())
			lm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lm.custom_minimum_size = Vector2(520, 0)
			v.add_child(lm)
	v.add_child(Motyw.etykieta("Wszystko, co masz przy sobie, możesz stracić.", 13, Color(0.35, 0.3, 0.25)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	zew.add_child(h)
	var go := Button.new()
	go.text = "Wejdź do strefy"
	go.pressed.connect(func():
		Gra.zapisz()
		Dzwiek.graj("drzwi", 0.0)
		Gra.rozpocznij_rajd())
	h.add_child(go)
	if not Gra.ma_bron():
		var zs := Button.new()
		zs.text = "Pobierz zestaw startowy"
		zs.pressed.connect(func():
			Gra.wydaj_zestaw_startowy()
			pokaz_wyjscie())
		h.add_child(zs)
	var an := Button.new()
	an.text = "Jeszcze nie"
	an.pressed.connect(_ukryj_wyjscie)
	h.add_child(an)
	_wyjscie_ui.visible = true
	Sterowanie.blokada = true
	Sterowanie.przechwyc(false)


func _ukryj_wyjscie() -> void:
	_wyjscie_ui.visible = false
	Sterowanie.blokada = false
	Sterowanie.przechwyc(true)


func _input(event: InputEvent) -> void:
	if _wyjscie_ui and _wyjscie_ui.visible and event.is_action_pressed("pauza"):
		_ukryj_wyjscie()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ test wizualny

func _zrzuty(katalog: String) -> void:
	DirAccess.make_dir_recursive_absolute(katalog)
	gracz.sterowanie = false
	# kryjówka, korytarz, recepcja (stragany, frakcje, śluza)
	var ujecia := [[Vector3(4.0, 0.05, 6.2), 0.0], [Vector3(1.2, 0.05, 5.8), -2.4], [Vector3(4.0, 0.05, 12.0), PI], [Vector3(6.0, 0.05, 13.0), 2.2],
		[Vector3(2.0, 0.05, 16.0), -1.9], [Vector3(4.0, 0.05, 18.5), PI], [Vector3(-1.5, 0.05, 18.0), PI * 0.75]]
	var n := 0
	for u in ujecia:
		gracz.global_position = u[0]
		gracz.rotation.y = u[1]
		for f in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("baza_%d.png" % n))
		n += 1
	handel.otworz("posrednik" if OS.get_cmdline_user_args().has("--posrednik") else "zbrojmistrz")
	for f in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("baza_handel.png"))
	handel.zamknij()
	pokaz_wyjscie()
	for f in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("baza_wyjscie.png"))
	_ukryj_wyjscie()
	# tryb budowy: podgląd stawianego mebla
	gracz.global_position = Vector3(4.0, 0.05, 5.5)
	gracz.rotation.y = 0.0
	gracz.kamera.rotation.x = -0.5
	Gra.meble_zapas["regal_metalowy"] = 1
	kryjowka.zacznij_stawianie("regal_metalowy")
	for f in 12:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("baza_budowa.png"))
	kryjowka.otworz_liste()
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("baza_plan.png"))
	kryjowka.zamknij()
	Gra.meble_zapas.erase("regal_metalowy")
	# druga izba ze stojakiem na broń
	Gra.izby_kryjowki = 2
	_ustaw_izby()
	if not Gra.kryjowka.any(func(e): return String(e["id"]) == "stojak_bron"):
		Gra.kryjowka.append({"id": "stojak_bron", "x": 13.0 - 0.25, "z": 3.5, "r": 3})
	for bid in ["kb47", "pm63"]:
		Gra.skrytka.dodaj(Przedmiot.nowy(bid))
	kryjowka.odbuduj()
	gracz.global_position = Vector3(7.0, 0.05, 3.3)
	gracz.rotation.y = -PI * 0.5
	gracz.kamera.rotation.x = -0.12
	for f in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("baza_izba.png"))
	for fid in ["szabrownik", "kwatermistrz"]:
		handel.otworz(fid)
		for f in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("baza_%s.png" % fid))
		handel.zamknij()
	print("zrzuty bazy: ", n)
	get_tree().quit()


## Test kryjówki: kupno, stawianie (kolizje, przejście), powiększenie skrytki, odmowa zabrania pełnej szafki,
## sen, kuchenka, reputacja i rozejm.
func _test_kryjowki() -> void:
	for f in 10:
		await get_tree().physics_frame
	var bl := 0
	var start := Gra.kryjowka.size()
	var h0 := Gra.skrytka.h
	print("kryjówka: %d mebli, skrytka %d rzędów" % [start, h0])
	# kupno u Kwatermistrza
	Gra.bony = 50000
	handel.otworz("kwatermistrz")
	var bony0 := Gra.bony
	Gra.meble_zapas["regal_metalowy"] = int(Gra.meble_zapas.get("regal_metalowy", 0)) + 1
	handel.zamknij()
	# kolizje i przejście
	var w_drzwiach := kryjowka.powod_odmowy("regal_metalowy", 4.0, 6.7, 0)
	var na_szafce := ""
	for e in Gra.kryjowka:
		if String(e["id"]) == "szafka_metalowa":
			na_szafce = kryjowka.powod_odmowy("regal_metalowy", float(e["x"]), float(e["z"]), 90.0)
			break
	var poza := kryjowka.powod_odmowy("regal_metalowy", 9.0, 3.0, 0)
	var wolne := kryjowka.powod_odmowy("regal_metalowy", 6.5, 0.3, 0)
	print("  w drzwiach: '%s', na szafce: '%s', poza: '%s', wolne: '%s'" % [w_drzwiach, na_szafce, poza, wolne])
	if w_drzwiach == "" or na_szafce == "" or poza == "" or wolne != "":
		print("  BŁĄD: reguły stawiania")
		bl += 1
	# postawienie przez tryb budowy (duch pod celownikiem)
	gracz.global_position = Vector3(5.0, 0.05, 2.6)
	gracz.rotation.y = 0.0
	gracz.kamera.rotation.x = -0.7
	kryjowka.zacznij_stawianie("regal_metalowy")
	for f in 6:
		await get_tree().physics_frame
	kryjowka._duch_pos = Vector2(6.5, 0.3)
	kryjowka._duch_ok = kryjowka.powod_odmowy("regal_metalowy", 6.5, 0.3, 0) == ""
	kryjowka._postaw()
	await get_tree().physics_frame
	print("  po postawieniu: %d mebli, skrytka %d rzędów, tryb %d" % [Gra.kryjowka.size(), Gra.skrytka.h, kryjowka.tryb])
	if Gra.kryjowka.size() != start + 1 or Gra.skrytka.h != h0 + 8:
		print("  BŁĄD: regał nie powiększył skrytki")
		bl += 1
	# przedmiot w ostatnim rzędzie – zabranie regału musi być odrzucone
	var cegla := Przedmiot.nowy("akumulator")
	var ok_pol := Gra.skrytka.poloz(cegla, 0, Gra.skrytka.h - 3, false)
	var idx := Gra.kryjowka.size() - 1
	var odm := kryjowka.zabierz(idx)
	print("  zabranie z pełnym rzędem: '%s' (położono: %s)" % [odm, ok_pol])
	if odm == "" or not ok_pol:
		print("  BŁĄD: zabranie ucięło skrytkę")
		bl += 1
	Gra.skrytka.usun(cegla)
	odm = kryjowka.zabierz(idx)
	if odm != "" or Gra.skrytka.h != h0 or int(Gra.meble_zapas.get("regal_metalowy", 0)) != 1:
		print("  BŁĄD: zabranie pustego regału: '%s' h=%d" % [odm, Gra.skrytka.h])
		bl += 1
	kryjowka.zamknij()
	# sen
	Gra.zdrowie = {"klatka": 40.0, "nogi": 25.0}
	Gra.odpoczynek = true
	kryjowka.odpocznij()
	print("  po śnie: ", Gra.zdrowie, " odpoczynek: ", Gra.odpoczynek)
	if absf(float(Gra.zdrowie.get("klatka", 0)) - 62.5) > 0.5 or Gra.odpoczynek:
		print("  BŁĄD: sen")
		bl += 1
	# kuchenka
	Gra.potrzeby = {"glod": 20.0, "pragnienie": 20.0}
	Gra.skrytka.dodaj(Przedmiot.nowy("konserwa"))
	Gra.skrytka.dodaj(Przedmiot.nowy("woda"))
	kryjowka.ugotuj()
	print("  po posiłku: ", Gra.potrzeby)
	if float(Gra.potrzeby["glod"]) < 76.0 or float(Gra.potrzeby["pragnienie"]) < 70.0:
		print("  BŁĄD: kuchenka")
		bl += 1
	# reputacja: zabici szabrownicy, zlecenie Wojska
	Gra.reputacja = {"szabrownik": 0, "najemnik": 0, "wojskowy": 0}
	var bilans_test := {"przezyl": true, "zabici": [{"frakcja": "szabrownik"}, {"frakcja": "szabrownik"}], "zdarzenia": []}
	var akt: Array = Gra.kontrakty["aktywne"]
	akt.clear()
	akt.append({"typ": "eliminacja", "cel": "szabrownik", "ile": 2, "postep": 0, "nagroda": 5500, "rep": 12, "od": "wojskowy", "opis": "test"})
	Gra._rozlicz_kontrakty(bilans_test)
	for z in bilans_test["zabici"]:
		for f in Gra.reputacja:
			Gra.zmien_reputacje(f, FrakcjeBazy.ZABICIE if f == z["frakcja"] else FrakcjeBazy.ZABICIE_INNYCH)
	print("  reputacja: ", Gra.reputacja)
	if Gra.reputacja["szabrownik"] != -10 or Gra.reputacja["wojskowy"] != 14 or Gra.reputacja["najemnik"] != 2:
		print("  BŁĄD: reputacja")
		bl += 1
	# oferta frakcji z progiem
	Gra.reputacja["wojskowy"] = 39
	handel.otworz("wojskowy")
	await get_tree().process_frame
	var zablokowane := 0
	for r in handel._oferta.get_children():
		for c in r.get_children():
			if c is Button and (c as Button).text.begins_with("rep."):
				zablokowane += 1
	handel.zamknij()
	print("  Wojsko przy rep. 39: zablokowanych pozycji %d" % zablokowane)
	if zablokowane != 2:
		print("  BŁĄD: progi oferty")
		bl += 1
	# rozejm z reputacji
	Gra.reputacja["szabrownik"] = 40
	var w := Wrog.new()
	w.przygotuj("szabrownik", Dane.frakcje["szabrownik"]["zestawy"][0], RandomNumberGenerator.new())
	print("  szabrownik przy rep. 40 – rozejm: ", w.rozejm)
	if not w.rozejm:
		print("  BŁĄD: rozejm z reputacji")
		bl += 1
	w.free()
	# druga izba i stojak na broń
	Gra.bony = 60000
	Gra.izby_kryjowki = 1
	_ustaw_izby()
	var przed_izba := kryjowka.powod_odmowy("stol", 10.5, 3.5, 0)
	var ok_izba := rozbuduj_kryjowke()
	var po_izbie := kryjowka.powod_odmowy("stol", 10.5, 3.5, 0)
	var w_scianie := kryjowka.powod_odmowy("szafka_metalowa", 8.0, 1.0, 0)
	var w_przejsciu := kryjowka.powod_odmowy("szafka_metalowa", 8.4, 3.3, 0)
	print("  izba: przed '%s', kupiona %s (bony %d), po '%s', w ścianie '%s', w przejściu '%s'" % [przed_izba, ok_izba, Gra.bony, po_izbie, w_scianie, w_przejsciu])
	if przed_izba == "" or not ok_izba or po_izbie != "" or w_scianie == "" or w_przejsciu == "" or Gra.bony != 35000:
		print("  BŁĄD: druga izba")
		bl += 1
	if not Gra.skrytka.wszystkie().any(func(p): return (p as Przedmiot).typ() == "bron"):
		Gra.skrytka.dodaj(Przedmiot.nowy("obrzyn"))
	Gra.kryjowka.append({"id": "stojak_bron", "x": 11.0, "z": 0.25, "r": 0})
	kryjowka.odbuduj()
	await get_tree().process_frame
	var stojak: Node3D = kryjowka._wezly.back()
	var bronie_na := (stojak.get_node("Bronie") as Node3D).get_child_count()
	print("  stojak: broni na stojaku %d, skrytka %d rzędów" % [bronie_na, Gra.skrytka.h])
	if bronie_na < 1:
		print("  BŁĄD: stojak nie pokazuje broni")
		bl += 1
	# stół roboczy: elaboracja i naprawa pancerza
	ekran_ekw.otworz_warsztat()
	await get_tree().process_frame
	var prasa := Przedmiot.nowy("prasa_elaboracyjna")
	Gra.skrytka.dodaj(prasa)
	Gra.skrytka.zabierz("proch", 99)
	Gra.skrytka.dodaj(Przedmiot.nowy("proch"))
	Gra.skrytka.dodaj(Przedmiot.nowy("proch"))
	var a0 := Gra.skrytka.policz("a_762")
	ekran_ekw._elaboruj(prasa, 2)
	print("  elaboracja 7,62: naboje +%d, proch %d, prasa użyć %d" % [Gra.skrytka.policz("a_762") - a0, Gra.skrytka.policz("proch"), int(prasa.dane.get("uzycia", 0))])
	if Gra.skrytka.policz("a_762") - a0 != 15 or Gra.skrytka.policz("proch") != 0 or int(prasa.dane.get("uzycia", 0)) != 7:
		print("  BŁĄD: elaboracja")
		bl += 1
	var kam := Przedmiot.nowy("kamizelka_kl2")
	kam.dane["wytrz"] = 12.0
	Gra.skrytka.dodaj(kam)
	Gra.skrytka.dodaj(Przedmiot.nowy("tkanina_balistyczna"))
	var w0 := kam.wartosc()
	ekran_ekw._napraw_pancerz(kam)
	print("  naprawa kl. 2: wytrz %.0f, maks %.0f, wartość %d → %d, tkaniny %d" % [float(kam.dane["wytrz"]), float(kam.dane.get("maks_wytrz", 0)), w0, kam.wartosc(), Gra.skrytka.policz("tkanina_balistyczna")])
	if absf(float(kam.dane["wytrz"]) - 36.0) > 0.1 or Gra.skrytka.policz("tkanina_balistyczna") != 0:
		print("  BŁĄD: naprawa pancerza")
		bl += 1
	ekran_ekw.zamknij()
	# porównanie z noszonym pancerzem w opisie
	var stary_p = Gra.ekw.sloty["pancerz"]
	Gra.ekw.sloty["pancerz"] = Przedmiot.nowy("kamizelka_kl2")
	var opis: String = load("res://scripts/ui/ekran_ekwipunku.gd").opis_przedmiotu(Przedmiot.nowy("kamizelka_kl4"))
	Gra.ekw.sloty["pancerz"] = stary_p
	var linia: Array = Array(opis.split("\n")).filter(func(l): return String(l).contains("wzgl. noszonego"))
	print("  porównanie: ", linia)
	if linia.is_empty() or not String(linia[0]).contains("klasa +2"):
		print("  BŁĄD: porównanie w opisie")
		bl += 1
	print("TEST KRYJÓWKI: błędów ", bl)
	get_tree().quit()


# ------------------------------------------------------------------ kadry do prezentacji

const UKLAD_PREZENTACJI := [
	{"id": "lozko", "x": 0.5, "z": 1.05, "r": 1}, {"id": "szafka_metalowa", "x": 0.25, "z": 3.0, "r": 1},
	{"id": "szafka_metalowa", "x": 0.25, "z": 3.55, "r": 1}, {"id": "szafka_metalowa", "x": 0.25, "z": 4.1, "r": 1},
	{"id": "stol_warsztatowy", "x": 5.5, "z": 0.38, "r": 0}, {"id": "kuchenka", "x": 2.8, "z": 0.33, "r": 0},
	{"id": "dywan", "x": 4.5, "z": 3.6, "r": 0}, {"id": "stol", "x": 4.5, "z": 3.6, "r": 0},
	{"id": "krzeslo", "x": 3.7, "z": 3.6, "r": 1}, {"id": "krzeslo", "x": 5.3, "z": 3.6, "r": 3},
	{"id": "telewizor", "x": 7.65, "z": 5.6, "r": 3}, {"id": "regal_metalowy", "x": 6.4, "z": 6.75, "r": 2},
	{"id": "zarowka", "x": 1.6, "z": 5.2, "r": 0},
	{"id": "stojak_bron", "x": 12.78, "z": 3.4, "r": 3}, {"id": "skrzynia_wojskowa", "x": 10.2, "z": 0.3, "r": 0},
	{"id": "skrzynia_wojskowa", "x": 11.4, "z": 0.3, "r": 0}, {"id": "szafa", "x": 12.68, "z": 6.0, "r": 3},
	{"id": "worki_piasek", "x": 10.2, "z": 6.73, "r": 2}, {"id": "beczka", "x": 8.6, "z": 0.4, "r": 0},
	{"id": "zarowka", "x": 10.5, "z": 5.0, "r": 0}]


func _kadr(katalog: String, nazwa: String, poz: Vector3, cel: Vector3, klatek := 25) -> void:
	gracz.global_position = poz
	var d := cel - poz
	gracz.rotation.y = atan2(-d.x, -d.z)
	gracz.kamera.rotation.x = atan2(cel.y - (poz.y + 1.6), Vector2(d.x, d.z).length())
	for f in klatek:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join(nazwa + ".png"))


## Kadry do prezentacji: urządzona kryjówka (obie izby, stojak z bronią), recepcja, stragany, frakcje, śluza, budowa, ekrany.
func _prezentacja(katalog: String) -> void:
	DirAccess.make_dir_recursive_absolute(katalog)
	gracz.sterowanie = false
	Gra.izby_kryjowki = 2
	Gra.kryjowka = UKLAD_PREZENTACJI.duplicate(true)
	for bid in ["kb47", "pm63", "obrzyn"]:
		var b := Gra.nowy_naladowany(bid, "a_762" if bid == "kb47" else ("a_12" if bid == "obrzyn" else "a_9x18"))
		Gra.skrytka.dodaj(b)
	_ustaw_izby()
	kryjowka.odbuduj()
	# bez napisów HUD-u bazy w kadrach 3D
	_hud_prompt.visible = false
	_hud_info.visible = false
	_komunikaty.visible = false
	set_process(false)
	await _kadr(katalog, "kryjowka_1", Vector3(7.2, 0.05, 6.2), Vector3(2.2, 0.7, 1.6))
	await _kadr(katalog, "kryjowka_2", Vector3(1.6, 0.05, 6.3), Vector3(6.0, 0.6, 1.0))
	await _kadr(katalog, "kryjowka_izba", Vector3(8.9, 0.05, 4.6), Vector3(12.7, 1.0, 3.4))
	await _kadr(katalog, "recepcja_hala", Vector3(4.0, 0.05, 11.6), Vector3(4.0, 1.3, 22.0))
	await _kadr(katalog, "recepcja_stragany", Vector3(5.5, 0.05, 15.8), Vector3(-3.8, 1.3, 15.0))
	await _kadr(katalog, "recepcja_medyk", Vector3(0.0, 0.05, 21.6), Vector3(-4.0, 1.3, 20.0))
	await _kadr(katalog, "recepcja_posrednik", Vector3(7.5, 0.05, 16.6), Vector3(12.0, 1.3, 14.8))
	await _kadr(katalog, "frakcja_szabrownicy", Vector3(-1.4, 0.05, 20.6), Vector3(-3.6, 1.1, 23.6))
	await _kadr(katalog, "frakcja_najemnicy", Vector3(9.4, 0.05, 20.8), Vector3(11.4, 1.1, 23.6))
	await _kadr(katalog, "sluza_wojsko", Vector3(3.0, 0.05, 19.4), Vector3(5.6, 1.3, 24.6))
	# tryb budowy: regał w ręce
	gracz.global_position = Vector3(5.6, 0.05, 5.2)
	gracz.rotation.y = 0.35
	gracz.kamera.rotation.x = -0.55
	Gra.meble_zapas["regal_metalowy"] = 1
	kryjowka.zacznij_stawianie("regal_metalowy")
	for f in 15:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("kryjowka_budowa.png"))
	kryjowka.zamknij()
	Gra.meble_zapas.erase("regal_metalowy")
	# ekrany: handel, przedstawiciele, kwatermistrz, plan, rozkaz wyjścia
	Gra.bony = 48500
	Gra.reputacja = {"szabrownik": 18, "najemnik": 32, "wojskowy": 44}
	for fid in ["zbrojmistrz", "wojskowy", "najemnik", "kwatermistrz", "medyk"]:
		handel.otworz(fid)
		for f in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(katalog.path_join("ekran_%s.png" % fid))
		handel.zamknij()
	pokaz_wyjscie()
	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(katalog.path_join("ekran_rozkaz.png"))
	print("prezentacja bazy gotowa")
	get_tree().quit()
