extends Node
## Autoload "Gra": stan rozgrywki między scenami (skrytka, bony, ekwipunek, zdrowie), zapis i przejścia.

signal halas(pozycja: Vector3, zasieg: float, zrodlo: Node)
signal zmiana_bonow

const ZAPIS := "user://zapis_k12.json"
const WERSJA := 1

var bony := 0
var skrytka: Siatka
var ekw: Ekwipunek
var zdrowie := {}            # część ciała -> hp po rajdzie (puste = pełne)
var statystyki := {"rajdy": 0, "przezyte": 0, "zgony": 0, "zabici": 0, "zarobione": 0}
var ustawienia := {"czulosc": 1.0, "fov": 75.0, "glosnosc": 0.8}
var ostatni_raport := {}
var ziarno_rajdu := 0
var rajd_w_toku := false


func _ready() -> void:
	if not wczytaj():
		nowa_gra()


func nowa_gra() -> void:
	bony = 12000
	skrytka = Siatka.new(10, 14, 0.0)
	ekw = Ekwipunek.new()
	zdrowie = {}
	statystyki = {"rajdy": 0, "przezyte": 0, "zgony": 0, "zabici": 0, "zarobione": 0}
	# ekwipunek startowy
	var pistolet := Przedmiot.nowy("pw9")
	_zaladuj_bron(pistolet, "a_9x18")
	ekw.zaloz("pistolet", pistolet)
	ekw.zaloz("kamizelka", Przedmiot.nowy("kamizelka_wedkarska"))
	ekw.zaloz("plecak", Przedmiot.nowy("worek"))
	ekw.dodaj(_magazynek("mag_pw9", "a_9x18", 8))
	ekw.dodaj(Przedmiot.nowy("a_9x18", 24))
	ekw.dodaj(Przedmiot.nowy("bandaz"))
	ekw.dodaj(Przedmiot.nowy("apteczka"))
	# skrytka
	for pid in ["obrzyn", "bandaz", "bandaz", "opatrunek", "bolostop", "konserwa", "papierosy", "wodka"]:
		skrytka.dodaj(Przedmiot.nowy(pid))
	skrytka.dodaj(Przedmiot.nowy("a_12", 16))
	skrytka.dodaj(Przedmiot.nowy("a_9x18", 40))
	skrytka.dodaj(_magazynek("mag_pw9", "", 0))
	zapisz()


func _magazynek(mag_id: String, amun: String, n: int) -> Przedmiot:
	var m := Przedmiot.nowy(mag_id)
	m.dane["amunicja"] = amun
	m.dane["naboje"] = n
	return m


## Ładuje broń pełnym magazynkiem (albo wewnętrznie) i nabojem w komorze. Używane przy zestawach.
func _zaladuj_bron(b: Przedmiot, amun: String) -> void:
	var bd: Dictionary = b.defn()["bron"]
	if bd.has("wewnetrzny"):
		b.dane["wewn"] = int(bd["wewnetrzny"])
		b.dane["wewn_typ"] = amun
		return
	var mag_id: String = bd["magazynki"][0]
	var cap := int(Dane.def(mag_id)["magazynek"]["pojemnosc"])
	b.dane["mag"] = _magazynek(mag_id, amun, cap - 1)
	b.dane["komora"] = amun


func nowy_naladowany(bron_id: String, amun: String) -> Przedmiot:
	var b := Przedmiot.nowy(bron_id)
	_zaladuj_bron(b, amun)
	return b


func magazynek(mag_id: String, amun: String, n: int) -> Przedmiot:
	return _magazynek(mag_id, amun, n)


func dodaj_bony(n: int) -> void:
	bony += n
	zmiana_bonow.emit()


func ma_bron() -> bool:
	return ekw.sloty["glowna"] != null or ekw.sloty["pistolet"] != null


## Darmowy zestaw startowy: zawsze dostępny, gdy gracz nie ma broni (zabezpieczenie przed spiralą porażek).
func wydaj_zestaw_startowy() -> bool:
	if ma_bron():
		return false
	var b := nowy_naladowany("pw9", "a_9x18")
	ekw.zaloz("pistolet", b)
	if ekw.sloty["kamizelka"] == null:
		ekw.zaloz("kamizelka", Przedmiot.nowy("kamizelka_wedkarska"))
	if ekw.sloty["plecak"] == null:
		ekw.zaloz("plecak", Przedmiot.nowy("worek"))
	ekw.dodaj(_magazynek("mag_pw9", "a_9x18", 8))
	ekw.dodaj(Przedmiot.nowy("a_9x18", 16))
	ekw.dodaj(Przedmiot.nowy("bandaz"))
	zapisz()
	return true


func emituj_halas(pos: Vector3, zasieg: float, zrodlo: Node = null) -> void:
	halas.emit(pos, zasieg, zrodlo)


# ------------------------------------------------------------------ przejścia

func idz_do_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func idz_do_bazy() -> void:
	rajd_w_toku = false
	get_tree().change_scene_to_file("res://scenes/baza.tscn")


func rozpocznij_rajd() -> void:
	ziarno_rajdu = randi()
	rajd_w_toku = true
	statystyki["rajdy"] += 1
	zapisz()
	get_tree().change_scene_to_file("res://scenes/rajd.tscn")


## wynik: {"przezyl": bool, "przyczyna": String, "czas": float, "zabici": Array, "wyjscie": String,
##         "wartosc_poczatkowa": int, "utracone": Array, "zdrowie": Dictionary, "zdarzenia": Array}
func koniec_rajdu(wynik: Dictionary) -> void:
	rajd_w_toku = false
	statystyki["zabici"] += wynik.get("zabici", []).size()
	if wynik["przezyl"]:
		statystyki["przezyte"] += 1
		zdrowie = wynik.get("zdrowie", {})
		var zysk := ekw.wartosc() - int(wynik.get("wartosc_poczatkowa", 0))
		wynik["zysk"] = zysk
		if zysk > 0:
			statystyki["zarobione"] += zysk
	else:
		statystyki["zgony"] += 1
		var utracone := []
		for p in ekw.wszystkie():
			utracone.append(p.nazwa())
		wynik["utracone"] = utracone
		wynik["wartosc_utracona"] = ekw.wartosc()
		ekw.wyczysc()
		zdrowie = {}
	ostatni_raport = wynik
	zapisz()
	get_tree().change_scene_to_file("res://scenes/raport.tscn")


# ------------------------------------------------------------------ zapis

func zapisz() -> void:
	var d := {
		"wersja": WERSJA, "bony": bony, "skrytka": skrytka.to_dict(), "ekw": ekw.to_dict(),
		"zdrowie": zdrowie, "statystyki": statystyki, "ustawienia": ustawienia,
	}
	var txt := JSON.stringify(d)
	if FileAccess.file_exists(ZAPIS):
		var stary := FileAccess.get_file_as_string(ZAPIS)
		var bk := FileAccess.open(ZAPIS + ".bak", FileAccess.WRITE)
		if bk:
			bk.store_string(stary)
	var f := FileAccess.open(ZAPIS, FileAccess.WRITE)
	if f:
		f.store_string(txt)


func wczytaj() -> bool:
	for path in [ZAPIS, ZAPIS + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(d) != TYPE_DICTIONARY or not d.has("skrytka"):
			continue
		bony = int(d["bony"])
		skrytka = Siatka.from_dict(d["skrytka"])
		ekw = Ekwipunek.from_dict(d["ekw"])
		zdrowie = d.get("zdrowie", {})
		statystyki.merge(d.get("statystyki", {}), true)
		ustawienia.merge(d.get("ustawienia", {}), true)
		return true
	return false


func istnieje_zapis() -> bool:
	return FileAccess.file_exists(ZAPIS)


func usun_zapis() -> void:
	if FileAccess.file_exists(ZAPIS):
		DirAccess.remove_absolute(ZAPIS)
	if FileAccess.file_exists(ZAPIS + ".bak"):
		DirAccess.remove_absolute(ZAPIS + ".bak")
