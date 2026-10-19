extends Node
## Autoload "Gra": stan rozgrywki między scenami (skrytka, bony, ekwipunek, zdrowie), zapis i przejścia.

signal halas(pozycja: Vector3, zasieg: float, zrodlo: Node)
signal zmiana_bonow

var ZAPIS := "user://zapis_k12.json"
const WERSJA := 1

var bony := 0
var skrytka: Siatka
var ekw: Ekwipunek
var zdrowie := {}            # część ciała -> hp po rajdzie (puste = pełne)
var potrzeby := {"glod": 80.0, "pragnienie": 80.0}   # 100 = syty / napojony
var statystyki := {"rajdy": 0, "przezyte": 0, "zgony": 0, "zabici": 0, "zarobione": 0}
var ustawienia := {"czulosc": 1.0, "fov": 75.0, "glosnosc": 0.8}
var ostatni_raport := {}
var poczta: Array = []        # ubezpieczone przedmioty wracające po śmierci (słowniki)
var ziarno_rajdu := 0
var rajd_w_toku := false


func _ready() -> void:
	# testy automatyczne nie nadpisują zapisu gracza
	var a := OS.get_cmdline_user_args()
	if a.has("--test") or a.has("--walka") or a.has("--ewakuacja") or a.has("--zrzuty") or a.has("--test_zapis"):
		ZAPIS = "user://zapis_test.json"
	if not wczytaj():
		nowa_gra()


func nowa_gra() -> void:
	bony = 12000
	skrytka = Siatka.new(10, 14, 0.0)
	ekw = Ekwipunek.new()
	zdrowie = {}
	potrzeby = {"glod": 80.0, "pragnienie": 80.0}
	statystyki = {"rajdy": 0, "przezyte": 0, "zgony": 0, "zabici": 0, "zarobione": 0}
	poczta = []
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
	ekw.dodaj(Przedmiot.nowy("latarka"))
	# skrytka
	for pid in ["obrzyn", "bandaz", "bandaz", "opatrunek", "bolostop", "konserwa", "woda", "suchary", "papierosy", "wodka"]:
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
	if not ekw.ma_wyposazenie("latarka") and ekw.znajdz_id("latarka").is_empty():
		ekw.dodaj(Przedmiot.nowy("latarka"))
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
## Zjedzenie / wypicie (w bazie od razu, w rajdzie po czynności gracza): zmienia głód i pragnienie.
func spozyj(p: Przedmiot) -> String:
	var j: Dictionary = p.defn().get("jedzenie", {})
	potrzeby["glod"] = clampf(float(potrzeby["glod"]) + float(j.get("glod", 0)), 0.0, 100.0)
	potrzeby["pragnienie"] = clampf(float(potrzeby["pragnienie"]) + float(j.get("pragnienie", 0)), 0.0, 100.0)
	if j.get("alkohol", false):
		return "Pali w gardle. Ból zelżał, ręce drżą."
	if j.get("picie", false):
		return "Napojony (%d%%)" % int(potrzeby["pragnienie"])
	return "Najedzony (%d%%)%s" % [int(potrzeby["glod"]), " – chce się pić" if float(j.get("pragnienie", 0)) < 0.0 else ""]


func _odblokuj_ekw() -> void:
	if ekw:
		# w schronie wszystko rozpoznane (spokojnie obejrzane przy stole)
		for p in ekw.wszystkie():
			(p as Przedmiot).dane.erase("nieznany")
		ekw.ograniczony = false
		ekw.plecak_rozlozony = false
		ekw.bezp_rozlozony = false
		ekw.zakryte.clear()


func koniec_rajdu(wynik: Dictionary) -> void:
	_odblokuj_ekw()
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
		var wartosc := 0
		var zwrot := []
		for p in ekw.ryzykowane():
			utracone.append(p.nazwa())
			if p.dane.get("ubezp", false):
				p.dane.erase("ubezp")
				# zwracany pusty (bez magazynka i zawartości)
				var kopia := Przedmiot.nowy(p.id)
				poczta.append(kopia.to_dict())
				zwrot.append(p.nazwa())
		for sl in Ekwipunek.SLOTY:
			if ekw.sloty[sl] != null:
				wartosc += ekw.sloty[sl].wartosc()
		wartosc += ekw.kieszenie.wartosc()
		wynik["utracone"] = utracone
		wynik["wartosc_utracona"] = wartosc
		wynik["ubezpieczone"] = zwrot
		ekw.wyczysc()
		zdrowie = {}
		potrzeby = {"glod": 60.0, "pragnienie": 60.0}
	ostatni_raport = wynik
	zapisz()
	get_tree().change_scene_to_file("res://scenes/raport.tscn")


# ------------------------------------------------------------------ zapis

func zapisz() -> void:
	var d := {
		"wersja": WERSJA, "bony": bony, "skrytka": skrytka.to_dict(), "ekw": ekw.to_dict(),
		"zdrowie": zdrowie, "potrzeby": potrzeby, "statystyki": statystyki, "ustawienia": ustawienia, "poczta": poczta,
		"latarka_wydana": true,
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
		potrzeby = {"glod": float(d.get("potrzeby", {}).get("glod", 80.0)), "pragnienie": float(d.get("potrzeby", {}).get("pragnienie", 80.0))}
		statystyki.merge(d.get("statystyki", {}), true)
		ustawienia.merge(d.get("ustawienia", {}), true)
		poczta = d.get("poczta", [])
		# przedmioty, które po zmianie rozmiarów (stosy, przegródki) nie zmieściły się – do skrytki albo na pocztę
		for p in Przedmiot.przepelnienie:
			if not skrytka.dodaj(p):
				poczta.append(p.to_dict())
		Przedmiot.przepelnienie.clear()
		# zapisy sprzed latarki-przedmiotu: jedna latarka w skrytce
		if not d.get("latarka_wydana", false):
			if not ekw.ma_wyposazenie("latarka") and ekw.znajdz_id("latarka").is_empty() and not skrytka.wszystkie().any(func(p): return p.id == "latarka"):
				skrytka.dodaj(Przedmiot.nowy("latarka"))
		return true
	return false


func istnieje_zapis() -> bool:
	return FileAccess.file_exists(ZAPIS)


func usun_zapis() -> void:
	if FileAccess.file_exists(ZAPIS):
		DirAccess.remove_absolute(ZAPIS)
	if FileAccess.file_exists(ZAPIS + ".bak"):
		DirAccess.remove_absolute(ZAPIS + ".bak")


## Koszt ubezpieczenia przedmiotu (ok. 18% wartości, minimum 300).
func koszt_ubezpieczenia(p: Przedmiot) -> int:
	return maxi(300, int(float(p.defn().get("cena", 0)) * 0.18))


## Odbiera zwrócone ubezpieczone przedmioty do skrytki. Zwraca nazwy odebranych.
func odbierz_poczte() -> Array:
	var odebrane := []
	var zostaje := []
	for d in poczta:
		var p := Przedmiot.from_dict(d)
		if skrytka.dodaj(p):
			odebrane.append(p.nazwa())
		else:
			zostaje.append(d)
	poczta = zostaje
	if not odebrane.is_empty():
		zapisz()
	return odebrane
