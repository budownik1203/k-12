extends Node
## Autoload "Gra": stan rozgrywki między scenami (skrytka, bony, ekwipunek, zdrowie), zapis i przejścia.

signal halas(pozycja: Vector3, zasieg: float, zrodlo: Node)
signal zmiana_bonow
signal ustawienia_zmiana

var ZAPIS := "user://zapis_k12.json"
const WERSJA := 1

var bony := 0
var skrytka: Siatka
var ekw: Ekwipunek
var zdrowie := {}            # część ciała -> hp po rajdzie (puste = pełne)
var potrzeby := {"glod": 80.0, "pragnienie": 80.0}   # 100 = syty / napojony
var kontrakty := {"oferty": [], "aktywne": []}       # zlecenia Pośrednika
var statystyki := {"rajdy": 0, "przezyte": 0, "zgony": 0, "zabici": 0, "zarobione": 0}
var ustawienia := {"czulosc": 1.0, "fov": 75.0, "glosnosc": 0.8, "glosnosc_tla": 0.8, "odwroc_y": false, "kolysanie": 1.0,
	"skala_renderu": 1.0, "skala_ui": 1.0, "cienie": true, "wygladzanie": true, "samouczek": true, "pokaz_fps": false, "proste_kieszenie": false, "samouczek_widziane": []}
var ostatni_raport := {}
var poczta: Array = []        # ubezpieczone przedmioty wracające po śmierci (słowniki)
var ziarno_rajdu := 0
var rajd_w_toku := false
var kryjowka: Array = []      # postawione meble kryjówki: {"id", "x", "z", "r" (obrót co 90°)}
var meble_zapas := {}         # kupione, niepostawione meble: id -> liczba
var reputacja := {"szabrownik": 0, "najemnik": 0, "wojskowy": 0}
var odpoczynek := false       # po powrocie z rajdu można raz przespać się w kryjówce
var izby_kryjowki := 1        # 2 = wykupiona druga izba (przebita ściana)
var potwierdzone_ziarno := 0  # meldunek tego ziarna sprawdzony u Pośrednika (pewny)
var nastepne_ziarno := 0      # ziarno najbliższego rajdu (losowane po powrocie – meldunki mogą je „podejrzeć”)
var przerwany_rajd := false   # gra zamknięta w trakcie rajdu: przy wczytaniu – zaginięcie w akcji


func _ready() -> void:
	# testy automatyczne nie nadpisują zapisu gracza
	var a := OS.get_cmdline_user_args()
	if a.has("--test") or a.has("--walka") or a.has("--ewakuacja") or a.has("--zrzuty") or a.has("--test_zapis") or a.has("--test_kryjowki") or a.has("--ekonomia") or a.has("--prezentacja") or a.has("--test_v14") or a.has("--soak") or a.has("--test_v15") or a.has("--test_v16") or a.has("--test_nakladanie") or a.has("--test_zapiecia"):
		ZAPIS = "user://zapis_test.json"
	if not wczytaj():
		nowa_gra()
	Widok3D.skala_ui.call_deferred(get_window())


func nowa_gra() -> void:
	bony = 12000
	kryjowka = MebleKryjowki.START.duplicate(true)
	meble_zapas = {}
	reputacja = {"szabrownik": 0, "najemnik": 0, "wojskowy": 0}
	odpoczynek = false
	izby_kryjowki = 1
	nastepne_ziarno = randi() | 1
	skrytka = Siatka.new(MebleKryjowki.SZER_SKRYTKI, MebleKryjowki.wiersze_skrytki(kryjowka), 0.0)
	ekw = Ekwipunek.new()
	zdrowie = {}
	potrzeby = {"glod": 80.0, "pragnienie": 80.0}
	kontrakty = {"oferty": [], "aktywne": []}
	odnow_oferty()
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
	# sprzęt z przydziału: nie do sprzedania (inaczej zestaw byłby darmową maszynką do bonów)
	var b := nowy_naladowany("pw9", "a_9x18")
	b.dane["przydzial"] = true
	(b.dane["mag"] as Przedmiot).dane["przydzial"] = true
	ekw.zaloz("pistolet", b)
	if ekw.sloty["kamizelka"] == null:
		var k := Przedmiot.nowy("kamizelka_wedkarska")
		k.dane["przydzial"] = true
		ekw.zaloz("kamizelka", k)
	if ekw.sloty["plecak"] == null:
		var w := Przedmiot.nowy("worek")
		w.dane["przydzial"] = true
		ekw.zaloz("plecak", w)
	var m := _magazynek("mag_pw9", "a_9x18", 8)
	m.dane["przydzial"] = true
	var reszta := [m, Przedmiot.nowy("a_9x18", 16), Przedmiot.nowy("bandaz")]
	if not ekw.ma_wyposazenie("latarka") and ekw.znajdz_id("latarka").is_empty():
		reszta.append(Przedmiot.nowy("latarka"))
	# pełne kieszenie: reszta zestawu do skrytki (nie przepada)
	for pz in reszta:
		if not ekw.dodaj(pz):
			skrytka.dodaj(pz)
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


var _startuje := false


func rozpocznij_rajd() -> void:
	# podwójne kliknięcie „Wejdź do strefy” nie liczy dwóch rajdów
	if _startuje:
		return
	_startuje = true
	get_tree().create_timer(3.0).timeout.connect(func(): _startuje = false)
	ziarno_rajdu = nastepne_ziarno if nastepne_ziarno != 0 else randi()
	nastepne_ziarno = 0
	rajd_w_toku = true
	statystyki["rajdy"] += 1
	pokaz_ladowanie()
	# droga do strefy i noc w terenie: głód i pragnienie rosną (jedzenie w bazie ma sens)
	potrzeby["glod"] = maxf(0.0, float(potrzeby["glod"]) - 10.0)
	potrzeby["pragnienie"] = maxf(0.0, float(potrzeby["pragnienie"]) - 14.0)
	odpoczynek = false
	zapisz()
	# dwie klatki na narysowanie ekranu przemarszu, zanim generator zajmie wątek
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/rajd.tscn")


# ------------------------------------------------------------------ ekran przemarszu (ładowanie rajdu)

var _ladowanie: CanvasLayer
const PRZEMARSZ := ["Przemarsz kanałem burzowym. Szczury salutują.", "Wartownik sprawdza przepustkę dłużej niż zwykle. Też nie wierzy, że wrócisz.",
	"Mgła nad blokowiskiem gęstnieje. Instrukcja przewiduje mgłę „umiarkowaną”.", "Ostatni papieros przed bramą. Regulamin zabrania, nikt nie pilnuje.",
	"Licznik Geigera trzeszczy. Zgodnie z normą – w zaokrągleniu.", "Za ogrodzeniem cisza. Nie ta dobra cisza.",
	"Stara prawda strefy: strzałka z kurzą łapką pod spodem prowadzi tam, gdzie czekają szabrownicy."]


func pokaz_ladowanie() -> void:
	if OS.get_cmdline_user_args().size() > 0 and _ladowanie == null and DisplayServer.get_name() == "headless":
		return
	ukryj_ladowanie(true)
	_ladowanie = CanvasLayer.new()
	_ladowanie.layer = 120
	add_child(_ladowanie)
	var tlo := ColorRect.new()
	tlo.color = Color(0.02, 0.02, 0.025)
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	tlo.theme = Motyw.motyw()
	_ladowanie.add_child(tlo)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -360
	v.offset_right = 360
	v.offset_top = -60
	v.offset_bottom = 60
	v.add_theme_constant_override("separation", 10)
	tlo.add_child(v)
	var t := Motyw.etykieta("PRZEMARSZ DO STREFY K-12 · ROZKAZ NR %d" % maxi(1, int(statystyki.get("rajdy", 0))), 20, Motyw.TEKST, Motyw.mono_b())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var l := Motyw.etykieta(PRZEMARSZ[randi() % PRZEMARSZ.size()], 15, Motyw.TEKST_CIEMNY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	_trasa_l = Motyw.etykieta("", 15, Motyw.TEKST_CIEMNY, Motyw.mono())
	_trasa_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_trasa_l)
	etap_ladowania(0)


var _trasa_l: Label
const TRASA := ["Śluza", "Kanał", "Ogrodzenie", "Podwórze", "Strefa"]


## Postęp przemarszu: kolejne punkty trasy odpowiadają etapom budowy rajdu.
func etap_ladowania(n: int) -> void:
	if _trasa_l == null or not is_instance_valid(_trasa_l):
		return
	var cz := []
	for i in TRASA.size():
		cz.append(("■ " if i <= n else "□ ") + TRASA[i])
	_trasa_l.text = "  ─  ".join(cz)


## Rajd gotowy: ekran przemarszu gaśnie.
func ukryj_ladowanie(od_razu := false) -> void:
	if _ladowanie == null or not is_instance_valid(_ladowanie):
		return
	var cl := _ladowanie
	_ladowanie = null
	if od_razu:
		cl.queue_free()
		return
	var tlo := cl.get_child(0) as CanvasItem
	var tw := create_tween()
	tw.tween_property(tlo, "modulate:a", 0.0, 0.6)
	tw.tween_callback(cl.queue_free)


## Czy Sęp będzie w rajdzie o tym ziarnie (bez zlecenia na niego) – deterministycznie, żeby meldunki mówiły prawdę.
static func sep_w_rajdzie(ziarno: int) -> bool:
	var r := RandomNumberGenerator.new()
	r.seed = ziarno * 31 + 9
	return r.randf() < 0.4


## Zdarzenia rajdu o tym ziarnie: [{"t", "typ"}] (awaria prądu, obława, zrzut).
static func plan_zdarzen(ziarno: int) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = ziarno * 7 + 3
	if rng.randf() < 0.4:
		out.append({"t": rng.randf_range(300.0, 900.0), "typ": "awaria"})
	if rng.randf() < 0.3:
		out.append({"t": rng.randf_range(420.0, 1200.0), "typ": "oblawa"})
	if rng.randf() < 0.3:
		out.append({"t": rng.randf_range(480.0, 1100.0), "typ": "zrzut"})
	return out


## Meldunki przed rajdem (stół z planem strefy w kryjówce): Sęp i zapowiedziane zdarzenia najbliższej nocy.
func meldunki() -> Array:
	var out := []
	var z := nastepne_ziarno
	# nasłuch nie zawsze mówi prawdę: wiarygodność rośnie z reputacją u Wojska (to ich radiostacja);
	# przekłamania są stałe dla danego rajdu (to samo ziarno – ten sam meldunek)
	var rw := clampf(float(reputacja.get("wojskowy", 0)) / 60.0, 0.0, 1.0)
	var wiar := 0.55 + 0.4 * rw
	if potwierdzone_ziarno == z and z != 0:
		wiar = 1.01         # Pośrednik sprawdził meldunek swoimi kanałami
	var rng := RandomNumberGenerator.new()
	rng.seed = z * 7 + 3
	if wiar > 1.0:
		out.append("Meldunek sprawdzony przez Pośrednika – pewny.")
	else:
		out.append("Wiarygodność nasłuchu: %s (reputacja u Wojska; Pośrednik sprawdzi za opłatą)" % ("wysoka" if wiar > 0.85 else ("średnia" if wiar > 0.68 else "niska")))
	var zlec := false
	for k in kontrakty.get("aktywne", []):
		if String(k.get("cel", "")) in ["boss", "niesmiertelnik"]:
			zlec = true
	var sep := sep_w_rajdzie(z)
	if not zlec and rng.randf() > wiar:
		sep = not sep
	if zlec:
		out.append("Masz zlecenie na Sępa – pośrednicy pilnują, żeby był w strefie.")
	elif sep:
		out.append("Nasłuch: Sęp i jego ludzie siedzą w strefie.")
	else:
		out.append("O Sępie cisza – albo go nie ma, albo siedzi bardzo cicho.")
	var plan := plan_zdarzen(z)
	plan.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	var wpisy := []
	for e in plan:
		if rng.randf() > wiar:
			# przekłamanie: zdarzenie przemilczane albo pora pomylona o kilka minut
			if rng.randf() < 0.5:
				continue
			e = e.duplicate()
			e["t"] = maxf(60.0, float(e["t"]) + rng.randf_range(-5.0, 5.0) * 60.0)
		wpisy.append(e)
	if rng.randf() > wiar + 0.15:
		# plotka o zdarzeniu, którego nie będzie
		wpisy.append({"typ": ["awaria", "oblawa", "zrzut"][rng.randi() % 3], "t": rng.randf_range(5.0, 20.0) * 60.0})
	for e in wpisy:
		var m := int(float(e["t"]) / 60.0)
		match String(e["typ"]):
			"awaria":
				out.append("Elektrownia zapowiada przerwę w dostawie prądu (ok. %d. minuty)." % m)
			"oblawa":
				out.append("Wojsko szykuje obławę w strefie (ok. %d. minuty)." % m)
			"zrzut":
				out.append("Mówią o zrzucie zaopatrzenia (ok. %d. minuty) – samolot nisko nad blokami." % m)
	if wpisy.is_empty():
		out.append("Poza tym spokojna noc – bez zapowiedzi.")
	return out


## Skrytka dopasowana do mebli kryjówki (nigdy nie ucina przedmiotów).
func dopasuj_skrytke() -> void:
	skrytka.zmien_wysokosc(maxi(MebleKryjowki.wiersze_skrytki(kryjowka), skrytka.zajete_wiersze()))


func zmien_reputacje(f: String, o: int) -> void:
	if reputacja.has(f):
		reputacja[f] = clampi(int(reputacja[f]) + o, -100, 100)


## wynik: {"przezyl": bool, "przyczyna": String, "czas": float, "zabici": Array, "wyjscie": String,
##         "wartosc_poczatkowa": int, "utracone": Array, "zdrowie": Dictionary, "zdarzenia": Array}
# ------------------------------------------------------------------ kontrakty (zlecenia Pośrednika)

const KONTRAKTY_DOSTAWA := [["teczka_akt", 1, 9500], ["lampa_elektronowa", 2, 5000], ["maszyna_do_pisania", 1, 8500], ["radio", 1, 5200],
	["akumulator", 2, 9000], ["telefon", 1, 4200], ["przewody", 3, 3800], ["zegarek", 2, 7000]]
const KONTRAKTY_ELIMINACJA := [["szabrownik", 3, 5000], ["najemnik", 2, 8500], ["wojskowy", 2, 9000]]
const KONTRAKTY_WYJSCIE := [["Brama na podwórze", 2800], ["Piwnica nr 7", 4500], ["Okno na rusztowanie", 3800]]
const KONTRAKTY_ZWIAD := [["warsztat", "warsztatu", 3000], ["piwnica", "piwnicy", 3200], ["administracja", "biur administracji", 2600], ["magazyn", "magazynu", 2800]]


## Nowe oferty zleceń (trzy, różnych rodzajów) – po każdym rajdzie.
func odnow_oferty() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(statystyki.get("rajdy", 0)) * 977 + bony
	var rodzaje := ["dostawa", "eliminacja", "wyjscie", "zwiad"]
	rodzaje.shuffle()
	var out := []
	for r in rodzaje.slice(0, 3):
		match r:
			"dostawa":
				var e: Array = KONTRAKTY_DOSTAWA[rng.randi() % KONTRAKTY_DOSTAWA.size()]
				out.append({"typ": "dostawa", "cel": e[0], "ile": e[1], "postep": 0, "nagroda": e[2],
					"opis": "Dostarcz: %s ×%d" % [Dane.nazwa(e[0]), e[1]]})
			"eliminacja":
				var e2: Array = KONTRAKTY_ELIMINACJA[rng.randi() % KONTRAKTY_ELIMINACJA.size()]
				var nazwy := {"szabrownik": "szabrowników", "najemnik": "najemników", "wojskowy": "żołnierzy"}
				out.append({"typ": "eliminacja", "cel": e2[0], "ile": e2[1], "postep": 0, "nagroda": e2[2],
					"opis": "Zlikwiduj %d %s (liczy się po powrocie)" % [e2[1], nazwy[e2[0]]]})
			"wyjscie":
				var e3: Array = KONTRAKTY_WYJSCIE[rng.randi() % KONTRAKTY_WYJSCIE.size()]
				out.append({"typ": "wyjscie", "cel": e3[0], "ile": 1, "postep": 0, "nagroda": e3[1],
					"opis": "Sprawdź drogę: wyjdź ze strefy przez „%s”" % e3[0]})
			"zwiad":
				var e4: Array = KONTRAKTY_ZWIAD[rng.randi() % KONTRAKTY_ZWIAD.size()]
				out.append({"typ": "zwiad", "cel": e4[0], "ile": 1, "postep": 0, "nagroda": e4[2],
					"opis": "Zwiad: wejdź do %s i wróć żywy" % e4[1]})
	kontrakty["oferty"] = out
	var fr := {}
	for f in FrakcjeBazy.DANE:
		fr[f] = FrakcjeBazy.losuj_zlecenia(f, rng)
	kontrakty["frakcje"] = fr


const MAX_ZLECEN := 3


## Przyjęcie zlecenia: od Pośrednika (od = "") albo od przedstawiciela frakcji.
func przyjmij_kontrakt(i: int, od := "") -> bool:
	var of: Array = kontrakty["oferty"] if od == "" else (kontrakty.get("frakcje", {}) as Dictionary).get(od, [])
	if i < 0 or i >= of.size() or (kontrakty["aktywne"] as Array).size() >= MAX_ZLECEN:
		return false
	(kontrakty["aktywne"] as Array).append(of[i])
	of.remove_at(i)
	zapisz()
	return true


## Dostawa: przedmioty ze skrytki (rozpoznane) – zwraca, czy oddano.
func oddaj_dostawe(k: Dictionary) -> bool:
	var potrzeba := int(k["ile"])
	var znalezione := []
	for e in skrytka.items:
		var p: Przedmiot = e["p"]
		if p.id == k["cel"]:
			znalezione.append(p)
			if znalezione.size() >= potrzeba:
				break
	if znalezione.size() < potrzeba:
		return false
	for p in znalezione:
		skrytka.usun(p)
	dodaj_bony(int(k["nagroda"]))
	if k.has("od"):
		zmien_reputacje(String(k["od"]), int(k.get("rep", 0)))
	(kontrakty["aktywne"] as Array).erase(k)
	zapisz()
	return true


## Zaliczanie zleceń po rajdzie (tylko gdy gracz wrócił): eliminacje, wyjście, zwiad.
func _rozlicz_kontrakty(wynik: Dictionary) -> void:
	var notki := []
	var aktywne: Array = kontrakty["aktywne"]
	for k in aktywne.duplicate():
		if not wynik.get("przezyl", false):
			continue
		match String(k["typ"]):
			"eliminacja":
				for z in wynik.get("zabici", []):
					if (String(k["cel"]) == "boss" and z.get("boss", false)) or (String(z.get("frakcja", "")) == k["cel"] and not z.get("dezerter", false)):
						k["postep"] = int(k["postep"]) + 1
			"wyjscie":
				if String(wynik.get("wyjscie", "")) == k["cel"]:
					k["postep"] = 1
			"zwiad":
				if (wynik.get("odwiedzone", []) as Array).has(k["cel"]):
					k["postep"] = 1
		if String(k["typ"]) != "dostawa" and int(k["postep"]) >= int(k["ile"]):
			dodaj_bony(int(k["nagroda"]))
			aktywne.erase(k)
			var od := String(k.get("od", ""))
			if od != "":
				zmien_reputacje(od, int(k.get("rep", 0)))
			notki.append({"czas": 0.0, "tekst": "Zlecenie wykonane: %s (+%d bonów%s)." % [k["opis"], int(k["nagroda"]),
				(", reputacja: %s +%d" % [FrakcjeBazy.DANE[od]["nazwa"], int(k.get("rep", 0))]) if od != "" else ""]})
	if not notki.is_empty():
		var zd: Array = wynik.get("zdarzenia", [])
		zd.append_array(notki)
		wynik["zdarzenia"] = zd
	odnow_oferty()


## Wskazówka samouczka – każda pokazywana raz (można wyłączyć w ustawieniach).
func wskazowka(id: String, tekst: String) -> void:
	if not bool(ustawienia.get("samouczek", true)):
		return
	var w: Array = ustawienia.get("samouczek_widziane", [])
	if w.has(id):
		return
	w.append(id)
	ustawienia["samouczek_widziane"] = w
	get_tree().call_group("hud", "pokaz_wskazowke", tekst)


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
	_rozlicz_kontrakty(wynik)
	statystyki["zabici"] += wynik.get("zabici", []).size()
	# reputacja: frakcje dowiadują się o zabitych (także gdy gracz nie wrócił)
	var bilans := {}
	for z in wynik.get("zabici", []):
		var fz := String(z.get("frakcja", ""))
		if not reputacja.has(fz) or z.get("dezerter", false):
			continue
		for f in reputacja:
			bilans[f] = int(bilans.get(f, 0)) + (FrakcjeBazy.ZABICIE if f == fz else FrakcjeBazy.ZABICIE_INNYCH)
	for f in bilans:
		zmien_reputacje(f, bilans[f])
	wynik["reputacja"] = bilans
	odpoczynek = bool(wynik.get("przezyl", false))
	nastepne_ziarno = randi() | 1
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
				if p.dane.get("przydzial", false):
					kopia.dane["przydzial"] = true
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
		"zdrowie": zdrowie, "potrzeby": potrzeby, "kontrakty": kontrakty, "statystyki": statystyki, "ustawienia": ustawienia, "poczta": poczta,
		"latarka_wydana": true, "kryjowka": kryjowka, "meble_zapas": meble_zapas, "reputacja": reputacja, "odpoczynek": odpoczynek, "izby": izby_kryjowki,
		"nastepne_ziarno": nastepne_ziarno, "rajd_w_toku": rajd_w_toku, "potwierdzone_ziarno": potwierdzone_ziarno,
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
		kontrakty = d.get("kontrakty", {"oferty": [], "aktywne": []})
		if (kontrakty.get("oferty", []) as Array).is_empty():
			odnow_oferty()
		statystyki.merge(d.get("statystyki", {}), true)
		# JSON zwraca liczby jako float – liczniki z powrotem całkowite (inaczej np. "rajdy 2.0" w porównaniach i kluczach)
		for k in statystyki:
			if typeof(statystyki[k]) == TYPE_FLOAT and is_equal_approx(float(statystyki[k]), roundf(float(statystyki[k]))):
				statystyki[k] = int(statystyki[k])
		var wszystkie_k: Array = (kontrakty.get("oferty", []) as Array) + (kontrakty.get("aktywne", []) as Array)
		for fl in (kontrakty.get("frakcje", {}) as Dictionary).values():
			wszystkie_k += fl as Array
		for _l in 1:
			for kt in wszystkie_k:
				for pole in ["ile", "postep", "nagroda", "rep"]:
					if (kt as Dictionary).has(pole):
						kt[pole] = int(kt[pole])
		ustawienia.merge(d.get("ustawienia", {}), true)
		poczta = d.get("poczta", [])
		# kryjówka (zapisy sprzed v0.10: dawny schron – trzy szafki, stół roboczy, kącik)
		kryjowka = d.get("kryjowka", MebleKryjowki.MIGRACJA.duplicate(true))
		meble_zapas = d.get("meble_zapas", {})
		reputacja = {"szabrownik": 0, "najemnik": 0, "wojskowy": 0}
		for f in d.get("reputacja", {}):
			reputacja[f] = int(d["reputacja"][f])
		odpoczynek = bool(d.get("odpoczynek", false))
		izby_kryjowki = int(d.get("izby", 1))
		nastepne_ziarno = int(d.get("nastepne_ziarno", 0))
		potwierdzone_ziarno = int(d.get("potwierdzone_ziarno", 0))
		if nastepne_ziarno == 0:
			nastepne_ziarno = randi() | 1
		if not (kontrakty as Dictionary).has("frakcje"):
			var o: Array = kontrakty.get("oferty", [])
			odnow_oferty()
			if not o.is_empty():
				kontrakty["oferty"] = o
		dopasuj_skrytke()
		# zamknięcie gry w trakcie rajdu nie cofa czasu: zaginięcie w akcji (kryjówka, skrytka i reputacja zostają)
		if bool(d.get("rajd_w_toku", false)):
			_zaginiecie_po_przerwaniu()
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


func _zaginiecie_po_przerwaniu() -> void:
	statystyki["zgony"] = int(statystyki.get("zgony", 0)) + 1
	var utracone := []
	var zwrot := []
	for p in ekw.ryzykowane():
		utracone.append(p.nazwa())
		if p.dane.get("ubezp", false):
			var kopia := Przedmiot.nowy(p.id)
			if p.dane.get("przydzial", false):
				kopia.dane["przydzial"] = true
			poczta.append(kopia.to_dict())
			zwrot.append(p.nazwa())
	ekw.wyczysc()
	zdrowie = {}
	potrzeby = {"glod": 60.0, "pragnienie": 60.0}
	rajd_w_toku = false
	odpoczynek = false
	nastepne_ziarno = randi() | 1
	ostatni_raport = {"przezyl": false, "przyczyna": "zaginiecie", "utracone": utracone, "ubezpieczone": zwrot, "przerwany": true}
	przerwany_rajd = true
	odnow_oferty()
	zapisz()


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


## Wyjście z gry: zatrzymanie dźwięków i zwolnienie zasobów współdzielonych (bez wycieków przy zamykaniu).
func _exit_tree() -> void:
	Efekty.sprzataj()
