class_name Przeladowania
extends RefCounted
## Choreografie przeładowań broni gracza (widok pierwszoosobowy). Każda zwraca Choreografię gotową do
## odtwarzania przez Bron; obiekty pomocnicze (naboje, łuski, drugi magazynek) są dziećmi modelu broni
## i trafiają do b._chor_wezly (zwalniane po skończeniu).
##
## Dwururka (obrzyn): kciuk na dźwigni, lufy opadają na zawiasie, wyciąg podnosi łuski; lewa dłoń sięga do
## komór, chwyta krawędzie łusek, wyciąga je i odrzuca (szybkie: szarpnięcie lufami w górę – łuski
## wylatują same), sięga do kieszeni po naboje, wsuwa je do komór, wraca na czółenko i zatrzaskuje lufy.
## Magazynek łukowy (KB-47): dłoń obejmuje magazynek, kciuk wciska zatrzask, magazynek wychyla się do przodu
## na zaczepie i wychodzi; nowy wchodzi zaczepem pierwszy i dociśnięty do tyłu klika (szybkie: nowy
## magazynek wybija stary, który spada). Magazynek w chwycie (PM-63, PW-9): wysunięty w osi chwytu, nowy
## wsunięty i dobity dłonią. Pusta komora: przeciągnięcie rączki zamka / zamka górą i puszczenie.

const B := preload("res://scripts/core/bryly.gd")

static var nadpisz := {}        # testy: podmiana póz (przechył broni) bez przebudowy

const LUFY_ZAW := Vector3(0, 0.02, -0.07)
const KOMORA := Vector3(0, 0.025, 0.0)        # środek między komorami (względem zawiasu)
const ROZSTAW := 0.0118
const WYCIAG := 0.007                         # o tyle wyciąg wysuwa łuski przy otwarciu


# ------------------------------------------------------------------ pomocnicze

static func _wezel(b, czesci: Array) -> MeshInstance3D:
	var mi := B.instancja(czesci)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	b.model.add_child(mi)
	b._chor_wezly.append(mi)
	return mi


## Nabój 12/70 (albo wystrzelona łuska): kryza w z = 0, korpus wzdłuż -Z.
static func _naboj_12(b, luska: bool) -> MeshInstance3D:
	var c := [
		B.walec(Vector3(0, 0, 0.0026), Vector3(0, 0, 0.0), 0.0094, 0.0094, "mosiadz", 10),
		B.walec(Vector3(0, 0, 0.0), Vector3(0, 0, -0.013), 0.0084, 0.0084, "mosiadz", 10),
		B.walec(Vector3(0, 0, -0.013), Vector3(0, 0, -0.064), 0.0082, 0.0082, "czerwony", 10),
		B.walec(Vector3(0, 0, 0.0027), Vector3(0, 0, 0.0029), 0.0028, 0.0028, "czern" if luska else "metal_jasny", 8),
	]
	if luska:
		# rozchylona zawijka, osmalone wnętrze
		c.append(B.walec(Vector3(0, 0, -0.064), Vector3(0, 0, -0.071), 0.0082, 0.0094, "czerwony", 10))
		c.append(B.walec(Vector3(0, 0, -0.07), Vector3(0, 0, -0.0705), 0.0072, 0.0072, "czern", 10))
	else:
		c.append(B.walec(Vector3(0, 0, -0.064), Vector3(0, 0, -0.069), 0.0082, 0.0045, "czerwony", 10))
	return _wezel(b, c)


static func _kieszen(baza: Transform3D, w_dol := 0.36) -> Transform3D:
	# dłoń przy kieszeni / ładownicy: poniżej kadru, nadgarstek wykręcony
	var bz := Basis.from_euler(Vector3(0.6, 0.5, 0.4)) * baza.basis
	return Transform3D(bz, baza.origin + Vector3(-0.07, -w_dol, 0.2))


static func _zwykla_lok() -> Vector3:
	return Vector3(-0.2, -0.3, 0.28)


# ------------------------------------------------------------------ dwururka

## Lufy (węzeł zawiasu) w stanie otwarcia o (0..1, kanał "lufy").
static func _lufy_t(kat: float, o: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(kat * o, 0, 0)), LUFY_ZAW)


## Rama komór (środek między lufami na czole komór, oś luf = -Z), wysunięcie s wzdłuż osi do tyłu.
static func _komory_t(kat: float, o: float, s: float, x := 0.0) -> Transform3D:
	return _lufy_t(kat, o) * Transform3D(Basis(), KOMORA + Vector3(x, 0, s))


static func obrzyn(b, szybkie: bool) -> Choreografia:
	var ch := Choreografia.new()
	var d: Dictionary = b.przedmiot.dane
	var kat: float = float(b._ruchome["lufy"]["dane"]["kat"])
	var baza: Transform3D = b._reka_baza
	ch.reka = baza
	ch.reka_baza = baza
	ch.chwyt = "lozysko"
	ch.kanaly = {"lufy": 0.0}
	ch.kop = b._kop_anim
	var n := int(b.bd["wewnetrzny"])
	var luski := clampi(int(d.get("luski", 0)), 0, n)
	var wewn := clampi(int(d.get("wewn", 0)), 0, n - luski)
	var komory := []
	for k in n:
		komory.append("luska" if k < luski else ("naboj" if k < luski + wewn else ""))
	var do_wyjecia := []
	var wolne := []
	for k in n:
		if komory[k] == "luska":
			do_wyjecia.append(k)
		if komory[k] != "naboj":
			wolne.append(k)
	var zapas: int = b.gracz.ekw.policz_amunicje(b.bd["kaliber"])
	var wkladane := wolne.slice(0, mini(wolne.size(), zapas))
	var xk := func(k: int) -> float: return ROZSTAW if k == 0 else -ROZSTAW
	# zawartość komór (łuski i naboje) – widać je dopiero przy otwartych lufach
	for k in n:
		if komory[k] == "":
			continue
		var w := _naboj_12(b, komory[k] == "luska")
		w.visible = true
		ch.obiekty["k%d" % k] = w
	for k in wkladane:
		ch.obiekty["n%d" % k] = _naboj_12(b, false)
	var kom_cel := func(k: int, s: float) -> Callable:
		# wyciąg wysuwa łuski razem z otwieraniem luf
		return func() -> Transform3D:
			var o := float(ch.kanaly.get("lufy", 0.0))
			return _komory_t(kat, o, s * o if s == WYCIAG else s, xk.call(k))
	var pelne := []
	var naboje := []
	for k in n:
		if komory[k] != "":
			pelne.append(k)
		if komory[k] == "naboj":
			naboje.append(k)
	var w_komorach := func(lista: Array) -> Dictionary:
		var o := {}
		for k in lista:
			if ch.obiekty.has("k%d" % k):
				o["k%d" % k] = kom_cel.call(k, WYCIAG)
		return o
	# dłoń na czółenku – czółenko jest częścią luf, więc idzie z nimi w dół
	var na_loze := func() -> Transform3D:
		return _lufy_t(kat, float(ch.kanaly.get("lufy", 0.0))) * _lufy_t(kat, 0.0).affine_inverse() * baza
	# chwyt za kryzy: dłoń za komorami, palce w przód wzdłuż luf, wnętrze w dół na łuski
	# palce z lewej w poprzek czoła komór, opuszki na kryzach, wnętrze dłoni do czoła luf
	var szczypta := Choreografia.dlon(false, Vector3(0.0, 0.0, 0.006), Vector3(0.55, 1, 0), Vector3(0.1, 0.0, -1), 0.125, 0.022)
	var przy_komorach := func(s: float, dx := Vector3.ZERO) -> Callable:
		return func() -> Transform3D:
			var t := _komory_t(kat, float(ch.kanaly.get("lufy", 0.0)), s)
			return Transform3D(t.basis, t.origin + dx) * szczypta
	var otwarta_bron := [Vector3(0.35, 0.55, 0.25), Vector3(-0.07, 0.03, 0.03)]
	var otw: Dictionary = w_komorach.call(pelne)
	# 1. kciuk na dźwigni, lufy opadają na zawiasie
	ch.dodaj({"nazwa": "otworz", "t": 0.3, "ease": "przysp", "kanaly": {"lufy": 1.0}, "reka": na_loze, "obiekty": otw,
		"bron": otwarta_bron, "dzw": [["klik", -12.0]], "dzw_k": [["obrzyn_lam", -5.0]], "kop_k": [Vector3(-0.03, 0, 0.0), Vector3(0, -0.004, 0)]})
	if not do_wyjecia.is_empty():
		if szybkie:
			# szarpnięcie lufami w górę: łuski same wylatują przez ramię
			var wyl := {}
			for k in do_wyjecia:
				wyl["k%d" % k] = Vector3(randf_range(-0.3, 0.3), 2.2, 2.8)
			ch.dodaj({"t": 0.16, "ease": "przysp", "reka": na_loze, "obiekty": w_komorach.call(pelne),
				"bron": [Vector3(1.05, 0.25, 0.3), Vector3(-0.02, 0.06, 0.06)]})
			ch.dodaj({"t": 0.16, "ease": "hamuj", "reka": na_loze, "obiekty": w_komorach.call(naboje),
				"spadaj": wyl, "bron": otwarta_bron, "koniec": func(): _luski_spadly(b, do_wyjecia.size())})
		else:
			# dłoń do komór, palce na kryzach
			ch.dodaj({"t": 0.24, "reka": przy_komorach.call(WYCIAG * 0.9 + 0.004), "obiekty": w_komorach.call(pelne),
				"chwyt": "otwarta", "chwyt_k": "szczypta", "lok": Vector3(-0.12, -0.32, 0.2)})
			var w_dloni := {}
			for k in do_wyjecia:
				w_dloni["k%d" % k] = "reka"
			# wyciągnięcie łusek wzdłuż osi luf
			ch.dodaj({"t": 0.2, "ease": "hamuj", "reka": przy_komorach.call(0.105), "obiekty": w_dloni,
				"dzw": [["naboj_wloz", -13.0]]})
			# odrzucenie w bok
			var odrzut := {}
			for k in do_wyjecia:
				odrzut["k%d" % k] = Vector3(-1.4, 0.4, 1.2)
			ch.dodaj({"t": 0.14, "ease": "przysp", "reka": przy_komorach.call(0.14, Vector3(-0.07, 0.03, 0.03)), "obiekty": w_dloni,
				"chwyt_k": "otwarta"})
			ch.dodaj({"t": 0.06, "reka": przy_komorach.call(0.15, Vector3(-0.1, 0.02, 0.04)), "spadaj": odrzut,
				"koniec": func(): _luski_spadly(b, do_wyjecia.size())})
	var stan := {"wziete": 0, "id": "", "wlozone": false}
	if not wkladane.is_empty():
		# po naboje do kieszeni
		ch.dodaj({"t": 0.26, "reka": _kieszen(baza), "chwyt": "otwarta", "lok": Vector3(-0.15, -0.3, 0.3)})
		var dz := {}
		var w_reke := {}
		for k in wkladane:
			# naboje w palcach w tym samym układzie, w jakim wejdą do komór
			dz["n%d" % k] = Transform3D(Basis(), Vector3(-xk.call(k), 0, 0)) * szczypta
			w_reke["n%d" % k] = "reka"
		ch.dodaj({"t": 0.14, "reka": _kieszen(baza, 0.4), "chwyt": "szczypta", "dzw": [["szelest_1", -16.0]],
			"start": func():
				var wz: Dictionary = b.gracz.ekw.zabierz_amunicje(b.bd["kaliber"], wkladane.size(), String(d.get("wewn_typ", "")))
				stan["wziete"] = int(wz.get("n", 0))
				stan["id"] = String(wz.get("id", ""))})
		ch.dodaj({"t": 0.26, "reka": przy_komorach.call(0.1), "doczep": dz, "obiekty": w_reke, "lok": Vector3(-0.12, -0.32, 0.2)})
		# wsunięcie do komór i dopchnięcie kciukiem
		var wlozone := {}
		for k in wkladane:
			wlozone["n%d" % k] = kom_cel.call(k, 0.0)
		ch.dodaj({"nazwa": "wsun", "t": 0.16, "ease": "hamuj", "reka": przy_komorach.call(0.002), "obiekty": w_reke,
			"dzw_k": [["naboj_wloz", -7.0]],
			"koniec": func():
				var m: int = mini(int(stan["wziete"]), wkladane.size())
				if m > 0:
					if int(d.get("wewn", 0)) == 0 or String(d.get("wewn_typ", "")) == "":
						d["wewn_typ"] = stan["id"]
					d["wewn"] = int(d.get("wewn", 0)) + m
				d["luski"] = 0
				stan["wlozone"] = true
				b.zmiana.emit()})
		var po: Dictionary = w_komorach.call(naboje)
		po.merge(wlozone)
		ch.dodaj({"t": 0.05, "reka": przy_komorach.call(-0.004), "obiekty": po, "chwyt_k": "otwarta"})
	# powrót na czółenko i zatrzaśnięcie luf
	var wszystkie: Dictionary = w_komorach.call(naboje if not do_wyjecia.is_empty() else pelne)
	for k in wkladane:
		wszystkie["n%d" % k] = kom_cel.call(k, 0.0)
	ch.dodaj({"nazwa": "zamknij_chwyt", "t": 0.18, "reka": na_loze, "obiekty": wszystkie, "chwyt": "lozysko", "lok": _zwykla_lok(),
		"start": func():
			# przerwane przed włożeniem: naboje z dłoni wracają do kieszeni
			if not stan["wlozone"] and int(stan["wziete"]) > 0:
				b.gracz.ekw.dodaj(Przedmiot.nowy(String(stan["id"]), int(stan["wziete"])))
				stan["wziete"] = 0
				for k in wkladane:
					(ch.obiekty["n%d" % k] as Node3D).visible = false
			# łuski, których nie zdążył wyrzucić, zostają w komorach (dane bez zmian)
			if int(d.get("luski", 0)) > 0:
				for k in do_wyjecia:
					(ch.obiekty["k%d" % k] as Node3D).visible = false})
	ch.dodaj({"nazwa": "zamknij", "t": 0.12, "ease": "trzask", "kanaly": {"lufy": 0.0}, "reka": na_loze, "obiekty": wszystkie,
		"bron": [Vector3(0.12, 0.1, 0.1), Vector3(-0.01, 0.0, 0.02)], "dzw_k": [["obrzyn_zamk", -4.0]],
		"kop_k": [Vector3(0.09, 0.02, 0.05), Vector3(0, 0.006, 0.01)]})
	ch.dodaj({"t": 0.2, "reka": baza, "bron": [Vector3.ZERO, Vector3.ZERO], "pokaz": _ukryj_wszystko(ch)})
	ch.skaluj(ch.calosc * float(b.bd["przeladowanie"]) / 1.2 * (0.85 if szybkie else 1.0))
	return ch


static func _ukryj_wszystko(ch: Choreografia) -> Dictionary:
	var o := {}
	for n in ch.obiekty:
		if String(n).begins_with("k") or String(n).begins_with("n"):
			o[n] = false
	return o


## Odrzucone łuski spadają pod nogi (głuchy plastik o podłogę).
static func _luski_spadly(b, ile: int) -> void:
	if ile <= 0 or b.gracz == null:
		return
	b.przedmiot.dane["luski"] = 0
	var gdzie: Vector3 = b.gracz.global_position + b.gracz.global_basis * Vector3(-0.3, 0.05, -0.2)
	for i in ile:
		b.get_tree().create_timer(0.38 + i * 0.07).timeout.connect(func():
			if is_instance_valid(b) and b.is_inside_tree():
				Dzwiek.graj_3d("luska_srut", gdzie, b.gracz.get_parent(), -10.0, randf_range(0.9, 1.1), 14.0))


## Sprawdzenie komór dwururki: uchylenie luf, rzut oka na kryzy (naboje / łuski), zamknięcie.
static func obrzyn_sprawdz(b) -> Choreografia:
	var ch := Choreografia.new()
	var d: Dictionary = b.przedmiot.dane
	var kat: float = float(b._ruchome["lufy"]["dane"]["kat"])
	var baza: Transform3D = b._reka_baza
	ch.reka = baza
	ch.chwyt = "lozysko"
	ch.kanaly = {"lufy": 0.0}
	ch.kop = b._kop_anim
	var n := int(b.bd["wewnetrzny"])
	var luski := clampi(int(d.get("luski", 0)), 0, n)
	var wewn := clampi(int(d.get("wewn", 0)), 0, n - luski)
	var cele := {}
	for k in n:
		var c := "luska" if k < luski else ("naboj" if k < luski + wewn else "")
		if c == "":
			continue
		var w := _naboj_12(b, c == "luska")
		w.visible = true
		ch.obiekty["k%d" % k] = w
		var x := ROZSTAW if k == 0 else -ROZSTAW
		cele["k%d" % k] = func() -> Transform3D: return _komory_t(kat, float(ch.kanaly["lufy"]), WYCIAG * 0.5 * float(ch.kanaly["lufy"]), x)
	var na_loze := func() -> Transform3D:
		return _lufy_t(kat, float(ch.kanaly["lufy"])) * _lufy_t(kat, 0.0).affine_inverse() * baza
	ch.dodaj({"t": 0.35, "kanaly": {"lufy": 0.62}, "reka": na_loze, "obiekty": cele, "bron": [Vector3(0.62, 0.5, 0.5), Vector3(-0.05, 0.05, 0.06)],
		"dzw": [["klik", -12.0]], "dzw_k": [["obrzyn_lam", -10.0]]})
	ch.dodaj({"t": 0.75, "reka": na_loze, "obiekty": cele, "bron": [Vector3(0.66, 0.54, 0.46), Vector3(-0.05, 0.05, 0.06)]})
	ch.dodaj({"t": 0.14, "ease": "trzask", "kanaly": {"lufy": 0.0}, "reka": na_loze, "obiekty": cele, "bron": [Vector3(0.1, 0.1, 0.1), Vector3.ZERO],
		"dzw_k": [["obrzyn_zamk", -6.0]], "kop_k": [Vector3(0.07, 0.02, 0.04), Vector3.ZERO]})
	ch.dodaj({"t": 0.2, "reka": baza, "bron": [Vector3.ZERO, Vector3.ZERO], "pokaz": _ukryj_wszystko(ch)})
	return ch


# ------------------------------------------------------------------ magazynki

static func magazynek(b, szybkie: bool, czas: float) -> Choreografia:
	var pistolet: bool = b.jest_pistolet()
	if b.przedmiot.id == "kb47":
		return _lukowy(b, szybkie, czas)
	return _w_chwycie(b, szybkie, czas, pistolet)


static func _poczatek(b) -> Choreografia:
	var ch := Choreografia.new()
	ch.reka = b._reka_baza
	ch.reka_baza = b._reka_baza
	ch.chwyt = "pistolet" if (b.jest_pistolet() or b.md.has("chwyt_pionowy")) else "lozysko"
	ch.kop = b._kop_anim
	ch.obiekty["mag"] = b.mag_node
	ch.kanaly = {"raczka": 0.0, "zamek": 1.0 if b._byl_pusty else 0.0}
	return ch


## Gdzie dłoń odkłada stary / bierze nowy magazynek (ładownica kamizelki, kieszeń spodni – niżej).
static func _ladownica(b) -> Transform3D:
	var w_dol := 0.38
	if not b.job.is_empty() and b.gracz and b.job.get("siatka") == b.gracz.ekw.kieszenie:
		w_dol = 0.52
	return _kieszen(b._reka_baza, w_dol)


## KB-47: magazynek łukowy wychylany na przednim zaczepie.
static func _lukowy(b, szybkie: bool, czas: float) -> Choreografia:
	var ch := _poczatek(b)
	var zaczep := Vector3(0, 0.02, -0.205)
	var wychyl := func(a: float, dol := 0.0) -> Transform3D:
		return Transform3D(Basis(), Vector3(0, -dol, -dol * 0.25)) * Choreografia.obrot_wokol(zaczep, Vector3(a, 0, 0))
	# dłoń obejmuje magazynek z lewej, palce na przedniej krawędzi, kciuk na zatrzasku z tyłu
	var chwyt_mag := Choreografia.dlon(false, Vector3(0, -0.075, -0.19), Vector3(0, -1, -0.3), Vector3(1, 0, 0.1), 0.058, 0.026)
	var przechyl: Array = nadpisz.get("kb47", [Vector3(0.2, 0.5, -0.4), Vector3(-0.06, 0.08, 0.05)])
	var pocz := _ladownica(b)
	var mag_n: Node3D = null
	if szybkie:
		mag_n = _wezel(b, b.md.get("mag3", []))
		ch.obiekty["mag_n"] = mag_n
	if not szybkie:
		ch.dodaj({"t": 0.12, "reka": wychyl.call(0.0) * chwyt_mag, "bron": przechyl, "chwyt": "otwarta", "chwyt_k": "magazynek",
			"lok": Vector3(-0.1, -0.34, 0.24)})
		ch.dodaj({"t": 0.1, "ease": "hamuj", "obiekty": {"mag": wychyl.call(0.4)}, "reka_przy": "mag", "dzw": [["mag_wyjmij", -6.0]]})
		ch.dodaj({"t": 0.08, "obiekty": {"mag": wychyl.call(0.4, 0.09)}, "reka_przy": "mag"})
		ch.dodaj({"t": 0.18, "reka": pocz, "obiekty": {"mag": "reka"}, "lok": Vector3(-0.15, -0.3, 0.3)})
		ch.dodaj({"t": 0.12, "reka": _kieszen(b._reka_baza, 0.44), "pokaz": {"mag": false}, "dzw": [["rzep", -18.0]]})
		ch.dodaj({"t": 0.2, "reka": wychyl.call(0.4, 0.09) * chwyt_mag, "doczep": {"mag": chwyt_mag}, "obiekty": {"mag": "reka"},
			"lok": Vector3(-0.1, -0.34, 0.24)})
	else:
		# nowy magazynek z ładownicy wybija stary
		ch.dodaj({"t": 0.16, "reka": pocz, "chwyt": "otwarta", "bron": przechyl, "lok": Vector3(-0.15, -0.3, 0.3)})
		ch.dodaj({"t": 0.1, "reka": _kieszen(b._reka_baza, 0.42), "chwyt": "magazynek", "dzw": [["rzep", -18.0]]})
		var za_starym: Transform3D = Transform3D(Basis(), Vector3(0, -0.06, 0.07)) * wychyl.call(0.25)
		ch.dodaj({"t": 0.2, "reka": za_starym * chwyt_mag, "doczep": {"mag_n": chwyt_mag}, "obiekty": {"mag_n": "reka"},
			"lok": Vector3(-0.1, -0.34, 0.24)})
		ch.dodaj({"t": 0.07, "ease": "przysp", "reka": Transform3D(Basis(), Vector3(0, -0.035, 0.015)) * wychyl.call(0.3) * chwyt_mag,
			"obiekty": {"mag_n": "reka", "mag": wychyl.call(0.45, 0.02)}, "dzw": [["mag_wyjmij", -5.0]]})
		ch.dodaj({"t": 0.08, "reka": wychyl.call(0.4, 0.09) * chwyt_mag, "obiekty": {"mag_n": "reka"},
			"spadaj": {"mag": Vector3(0.0, -0.6, -0.9)}})
	var mag_w := "mag_n" if szybkie else "mag"
	# wsunięcie: zaczep pierwszy, potem do tyłu aż kliknie
	ch.dodaj({"t": 0.09, "reka": wychyl.call(0.38, 0.0) * chwyt_mag, "obiekty": {mag_w: "reka"}})
	ch.dodaj({"t": 0.07, "ease": "przysp", "obiekty": {mag_w: wychyl.call(0.0)}, "reka_przy": mag_w, "dzw_k": [["mag_wloz", -4.0]],
		"kop_k": [Vector3(0.03, 0.015, 0.03), Vector3(0, 0.003, 0)]})
	if szybkie:
		# stary leży gdzieś pod nogami – na miejscu jest nowy
		ch.dodaj({"t": 0.01, "obiekty": {"mag": wychyl.call(0.0)}, "pokaz": {"mag": true, "mag_n": false}})
	if b._byl_pusty:
		# lewa dłoń górą do rączki zamka po prawej, przeciągnięcie do oporu i puszczenie
		var p_r := Vector3(0.033, 0.068, -0.086)
		var raczka := Choreografia.dlon(false, p_r, Vector3(0, 0, -1), Vector3(0.6, -0.8, 0), 0.07, 0.024)
		var cofnieta := Transform3D(Basis(), Vector3(0, 0, 0.07)) * raczka
		ch.dodaj({"t": 0.16, "reka": raczka, "chwyt": "otwarta", "chwyt_k": "piesc", "bron": [Vector3(0.1, 0.25, -0.15), Vector3(-0.01, 0.0, 0.02)],
			"lok": Vector3(-0.05, -0.2, 0.3)})
		ch.dodaj({"t": 0.1, "ease": "hamuj", "reka": cofnieta, "kanaly": {"raczka": 1.0}, "dzw": [["zamek_kb", -5.0]]})
		ch.dodaj({"t": 0.05, "ease": "trzask", "reka": Transform3D(Basis(), Vector3(0, 0.01, 0.05)) * raczka, "kanaly": {"raczka": 0.0},
			"chwyt": "otwarta", "kop_k": [Vector3(0.04, -0.03, 0.06), Vector3(0, 0, 0.008)]})
	ch.dodaj({"t": 0.2, "reka": b._reka_baza, "bron": [Vector3.ZERO, Vector3.ZERO], "chwyt": "pistolet" if b.md.has("chwyt_pionowy") else "lozysko",
		"lok": _zwykla_lok()})
	ch.skaluj(czas)
	return ch


## PM-63 i PW-9: magazynek w chwycie, wysuwany w osi chwytu i dobijany dłonią.
static func _w_chwycie(b, szybkie: bool, czas: float, pistolet: bool) -> Choreografia:
	var ch := _poczatek(b)
	var kat := deg_to_rad(float(b.md.get("kat_chwytu", 10.0)))
	var os_dol := Basis.from_euler(Vector3(kat, 0, 0)) * Vector3(0, -1, 0)
	var wysun := func(dl: float) -> Transform3D:
		return Transform3D(Basis(), os_dol * dl)
	var dno: Vector3 = Vector3(0, -0.21, 0.006) if not pistolet else Vector3(0, -0.088, 0.017)
	var dl_mag := 0.13 if not pistolet else 0.095
	# dłoń pod stopką magazynka: wnętrze do góry, palce w prawo
	var pod_stopka := Choreografia.dlon(false, dno + os_dol * 0.01, Vector3(0, 0, 1), -os_dol, 0.05, 0.022)
	var dobicie := Choreografia.dlon(false, dno + os_dol * 0.03, Vector3(0, 0, 1), -os_dol, 0.045, 0.03)
	var przechyl: Array = nadpisz.get("pw9" if pistolet else "pm63", [Vector3(0.2, 0.5, -0.4), Vector3(-0.04, 0.11, -0.01)] if pistolet else [Vector3(0.2, 0.5, -0.4), Vector3(-0.06, 0.08, 0.05)])
	var pocz := _ladownica(b)
	ch.dodaj({"t": 0.12, "reka": pod_stopka, "bron": przechyl, "chwyt": "otwarta", "chwyt_k": "magazynek", "lok": Vector3(-0.12, -0.3, 0.22)})
	if szybkie:
		# zatrzask wciśnięty, magazynek wypada sam
		ch.dodaj({"t": 0.08, "obiekty": {"mag": wysun.call(dl_mag * 0.6)}, "reka": Transform3D(Basis(), Vector3(-0.04, -0.05, 0.02)) * pod_stopka,
			"chwyt": "otwarta", "dzw": [["mag_wyjmij", -6.0]], "spadaj": {}})
		ch.dodaj({"t": 0.01, "spadaj": {"mag": os_dol * 1.6}})
		ch.dodaj({"t": 0.18, "reka": pocz, "lok": Vector3(-0.15, -0.3, 0.3)})
	else:
		ch.dodaj({"t": 0.14, "ease": "hamuj", "obiekty": {"mag": wysun.call(dl_mag + 0.01)}, "reka_przy": "mag", "dzw": [["mag_wyjmij", -6.0]]})
		ch.dodaj({"t": 0.18, "reka": pocz, "obiekty": {"mag": "reka"}, "lok": Vector3(-0.15, -0.3, 0.3)})
	ch.dodaj({"t": 0.12, "reka": _kieszen(b._reka_baza, 0.44), "pokaz": {"mag": false}, "chwyt": "magazynek", "dzw": [["rzep", -18.0]]})
	var przed: Transform3D = wysun.call(dl_mag + 0.02) * pod_stopka
	ch.dodaj({"t": 0.2, "reka": przed, "doczep": {"mag": pod_stopka}, "obiekty": {"mag": "reka"}, "lok": Vector3(-0.12, -0.3, 0.22)})
	ch.dodaj({"t": 0.1, "ease": "hamuj", "reka": wysun.call(0.012) * pod_stopka, "obiekty": {"mag": "reka"}})
	# dobicie dłonią
	ch.dodaj({"t": 0.05, "ease": "trzask", "reka": dobicie, "obiekty": {"mag": wysun.call(0.0)}, "chwyt": "otwarta", "dzw_k": [["mag_wloz", -4.0]],
		"kop_k": [Vector3(0.05, 0.0, 0.0), Vector3(0, 0.006, 0)]})
	if b._byl_pusty:
		# zamek górą: dłoń na nacięciach z tyłu zamka, cofnięcie i puszczenie
		var p_z := Vector3(0, 0.058, 0.004) if pistolet else Vector3(0, 0.074, 0.018)
		var zamek := Choreografia.dlon(false, p_z, Vector3(0, 0, -1), Vector3(0.15, -1, 0), 0.06, 0.02)
		var skok: float = float(b._ruchome["zamek"]["dane"]["skok"]) if b._ruchome.has("zamek") else 0.03
		ch.dodaj({"t": 0.16, "reka": Transform3D(Basis(), Vector3(0, 0, skok)) * zamek, "chwyt": "otwarta", "chwyt_k": "piesc",
			"bron": [Vector3(0.15, 0.35, -0.3), Vector3(0.0, -0.01, -0.06) if pistolet else Vector3(0, 0, 0.0)], "lok": Vector3(-0.15, -0.15, 0.3)})
		ch.dodaj({"t": 0.07, "ease": "hamuj", "reka": Transform3D(Basis(), Vector3(0, 0, skok + 0.008)) * zamek, "kanaly": {"zamek": 1.15}})
		ch.dodaj({"t": 0.05, "ease": "trzask", "reka": Transform3D(Basis(), Vector3(-0.02, 0.03, skok + 0.02)) * zamek, "kanaly": {"zamek": 0.0},
			"chwyt": "otwarta", "dzw": [["zamek_pist" if pistolet else "zamek_kb", -4.0]], "kop_k": [Vector3(0.05, 0.02, 0.04), Vector3(0, 0, 0.006)]})
	ch.dodaj({"t": 0.2, "reka": b._reka_baza, "bron": [Vector3.ZERO, Vector3.ZERO], "chwyt": "pistolet" if pistolet else "lozysko", "lok": _zwykla_lok()})
	ch.skaluj(czas)
	return ch


# ------------------------------------------------------------------ sprawdzanie magazynka

## Okienka kontrolne w ściankach magazynka: w każdym widać mosiężny nabój, jeśli słupek
## naboi sięga tak głęboko. Ułamki – od góry magazynka.
const OKIENKA := {
	"kb47": [0.12, 0.36, 0.62, 0.9],
	"pm63": [0.2, 0.4, 0.6, 0.8, 0.96],
	"pw9": [0.15, 0.4, 0.65, 0.9],
}


static func okienka(b, mag: Przedmiot) -> MeshInstance3D:
	var id: String = b.przedmiot.id
	if not OKIENKA.has(id) or mag == null:
		return null
	var cap := float(mag.defn()["magazynek"]["pojemnosc"])
	var pelny := float(mag.dane.get("naboje", 0)) / maxf(1.0, cap)
	var c := []
	for fr in OKIENKA[id]:
		var p := Vector3.ZERO
		var rot := Vector3.ZERO
		var rozm := Vector3(0.0016, 0.016, 0.011)
		match id:
			"kb47":
				var t: float = lerpf(0.05, 0.85, fr)
				p = Vector3(-0.0162, lerpf(0.0, -0.17, t), lerpf(-0.175, -0.215, t) + 0.0)
				rot = Vector3(-20 - t * 24.0, 0, 0)
				rozm = Vector3(0.0016, 0.022, 0.014)
			"pm63":
				p = Vector3(-0.0122, lerpf(0.004, -0.195, fr), 0.003)
				rot = Vector3(6, 0, 0)
			"pw9":
				p = Vector3(-0.0088, lerpf(-0.012, -0.078, fr), 0.015)
				rot = Vector3(10, 0, 0)
				rozm = Vector3(0.0016, 0.012, 0.009)
		# okienka po obu stronach (widać je z każdej strony, z której się zerknie)
		for sx in [1.0, -1.0]:
			var q := Vector3(p.x * sx, p.y, p.z)
			c.append(B.box(q, rozm, "czern", 0.0, rot))
			if pelny >= fr - 0.001 and pelny > 0.0:
				c.append(B.box(q + Vector3(0.0006 * -sx, 0, 0), Vector3(0.0012, rozm.y * 0.7, rozm.z * 0.8), "metal_jasny", 0.0, rot))
	var mi := B.instancja(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.mag_node.add_child(mi)
	b._chor_wezly.append(mi)
	return mi


## Zerknięcie na magazynek: broń przekręcona lewym bokiem do oka i przysunięta, lewa dłoń wysuwa
## magazynek kawałek z gniazda, chwila na policzenie naboi w okienkach, dociśnięcie z powrotem.
static func sprawdz_magazynek(b) -> Choreografia:
	var ch := _poczatek(b)
	ch.kanaly = {"raczka": 0.0}
	okienka(b, b.przedmiot.dane.get("mag"))
	var pistolet: bool = b.jest_pistolet()
	var oglad := [Vector3(0.12, 0.62, -0.62), Vector3(-0.08, 0.1, 0.07)] if not pistolet else [Vector3(0.1, 0.75, -0.5), Vector3(-0.05, 0.1, 0.05)]
	var chwyt: Transform3D
	var wysun: Transform3D
	if b.przedmiot.id == "kb47":
		var zaczep := Vector3(0, 0.02, -0.205)
		chwyt = Choreografia.dlon(false, Vector3(0, -0.075, -0.19), Vector3(0, -1, -0.3), Vector3(1, 0, 0.1), 0.058, 0.026)
		wysun = Transform3D(Basis(), Vector3(0, -0.018, -0.004)) * Choreografia.obrot_wokol(zaczep, Vector3(0.12, 0, 0))
	else:
		var kat := deg_to_rad(float(b.md.get("kat_chwytu", 10.0)))
		var os_dol := Basis.from_euler(Vector3(kat, 0, 0)) * Vector3(0, -1, 0)
		var dno: Vector3 = Vector3(0, -0.21, 0.006) if not pistolet else Vector3(0, -0.088, 0.017)
		chwyt = Choreografia.dlon(false, dno + os_dol * 0.01, Vector3(0, 0, 1), -os_dol, 0.05, 0.022)
		wysun = Transform3D(Basis(), os_dol * (0.075 if pistolet else 0.05))
	ch.dodaj({"t": 0.28, "reka": chwyt, "bron": oglad, "chwyt": "otwarta", "chwyt_k": "magazynek", "lok": Vector3(-0.12, -0.32, 0.22)})
	ch.dodaj({"t": 0.16, "ease": "hamuj", "obiekty": {"mag": wysun}, "reka_przy": "mag", "dzw": [["mag_wyjmij", -12.0]]})
	ch.dodaj({"t": 0.9, "obiekty": {"mag": wysun}, "reka_przy": "mag", "bron": [oglad[0] + Vector3(0.05, 0.06, -0.05), oglad[1] + Vector3(0, 0.01, 0.01)]})
	ch.dodaj({"t": 0.1, "ease": "przysp", "obiekty": {"mag": Transform3D()}, "reka_przy": "mag", "dzw_k": [["mag_wloz", -8.0]],
		"kop_k": [Vector3(0.02, 0, 0.01), Vector3.ZERO]})
	ch.dodaj({"t": 0.26, "reka": b._reka_baza, "bron": [Vector3.ZERO, Vector3.ZERO], "chwyt": "pistolet" if (pistolet or b.md.has("chwyt_pionowy")) else "lozysko",
		"lok": _zwykla_lok()})
	return ch
