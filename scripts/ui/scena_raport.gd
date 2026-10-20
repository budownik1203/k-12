extends Node
## Raport urzędowy po rajdzie (przeżycie albo zgon) z dopiskami zależnymi od przebiegu.

const KOMUNIKATY_ZGONU := {
	"pocisk": "Ostrzeżenie! Zawartość ołowiu w organizmie przekroczyła normę zakładową.",
	"srut": "Uwaga: rozproszone zgłoszenie urazów. Rozpatrzenie potrwa.",
	"wykrwawienie": "Przypominamy: krew jest własnością Zakładu. Prosimy jej nie rozlewać.",
	"upadek": "Grawitacja działa zgodnie z normą PN-K12. Reklamacji nie przyjmujemy.",
	"zaginiecie": "Operator uznany za zaginionego w akcji. Wyposażenie przechodzi na rzecz Skarbu Strefy.",
	"fauna": "Prosimy nie dokarmiać zwierząt Sobą.",
	"granat": "Ostrzeżenie! Rozczłonkowanie może powodować zgon.",
}
const NAZWY_PRZYCZYN := {
	"pocisk": "rana postrzałowa", "srut": "rany od śrutu", "wykrwawienie": "wykrwawienie",
	"upadek": "upadek z wysokości", "zaginiecie": "zaginięcie w akcji", "fauna": "fauna",
}


func _ready() -> void:
	Sterowanie.przechwyc(false)
	Sterowanie.blokada = true
	var r: Dictionary = Gra.ostatni_raport
	var cl := CanvasLayer.new()
	add_child(cl)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = Motyw.motyw()
	cl.add_child(root)
	var tlo := ColorRect.new()
	tlo.color = Color(0.04, 0.04, 0.035)
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(tlo)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var kartka := PanelContainer.new()
	var st := Motyw.panel(Color(0.8, 0.76, 0.64), Color(0.35, 0.3, 0.22), 2)
	st.set_content_margin_all(26)
	kartka.add_theme_stylebox_override("panel", st)
	cc.add_child(kartka)
	# kartka mieści się w oknie: treść przewijana (kółko / pasek), przycisk podpisu zawsze widoczny na dole
	var dopasuj := func():
		var wys := root.get_viewport_rect().size.y / maxf(0.01, root.get_global_transform_with_canvas().get_scale().y)
		kartka.custom_minimum_size = Vector2(760, clampf(wys - 40.0, 360.0, 900.0))
	dopasuj.call()
	root.get_viewport().size_changed.connect(dopasuj)
	var zew := VBoxContainer.new()
	zew.add_theme_constant_override("separation", 8)
	kartka.add_child(zew)
	var przew := ScrollContainer.new()
	przew.size_flags_vertical = Control.SIZE_EXPAND_FILL
	przew.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	zew.add_child(przew)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	przew.add_child(v)
	var ciem := Color(0.14, 0.12, 0.09)
	var szary := Color(0.35, 0.31, 0.25)
	var przezyl: bool = r.get("przezyl", false)
	v.add_child(Motyw.etykieta("STREFA K-12 · WYDZIAŁ EWIDENCJI OPERATORÓW", 12, szary, Motyw.mono()))
	v.add_child(Motyw.etykieta("RAPORT Z RAJDU NR %d" % Gra.statystyki.get("rajdy", 0), 24, ciem, Motyw.mono_b()))
	var stempel := Motyw.etykieta("POWRÓT DO BAZY" if przezyl else "ZGON", 30, Color(0.62, 0.12, 0.08) if not przezyl else Color(0.2, 0.42, 0.18), Motyw.mono_b())
	stempel.rotation = -0.05
	v.add_child(stempel)
	var czas := float(r.get("czas", 0.0))
	v.add_child(Motyw.etykieta("Czas w strefie: %d min %02d s" % [int(czas) / 60, int(czas) % 60], 15, ciem, Motyw.mono()))
	if przezyl:
		v.add_child(Motyw.etykieta("Wyjście: %s" % r.get("wyjscie", "?"), 15, ciem, Motyw.mono()))
		var kurz := int(r.get("strata_kurz", 0))
		var zysk := int(r.get("zysk", 0)) + kurz
		v.add_child(Motyw.etykieta("Bilans wyposażenia: %+d bonów" % zysk, 15, ciem, Motyw.mono()))
		if int(r.get("zuzyte_amunicja", 0)) + int(r.get("zuzyte_leki", 0)) > 0:
			v.add_child(Motyw.etykieta("  w tym zużyte: amunicja ok. %d, leki ok. %d bonów" % [int(r.get("zuzyte_amunicja", 0)), int(r.get("zuzyte_leki", 0))], 13, szary, Motyw.mono()))
		if int(r.get("zuzycie_suma", 0)) > 0:
			var zl := Motyw.etykieta("  zużycie sprzętu: %s (razem ok. %d bonów utraty wartości)" % [", ".join(r.get("zuzycie_sprzetu", [])), int(r.get("zuzycie_suma", 0))], 13, szary, Motyw.mono())
			zl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(zl)
		if kurz > 0:
			v.add_child(Motyw.etykieta("  osobno: kurz na broni −%d (wraca po czyszczeniu)" % kurz, 13, szary, Motyw.mono()))
		if bool(r.get("brudna_bron", false)):
			v.add_child(Motyw.etykieta("  Broń wróciła zakurzona – przed kolejnym wyjściem wyczyść ją zestawem (częściej się zacina).", 13, szary))
		if zysk <= 0:
			v.add_child(Motyw.etykieta("Uwaga komisji: rajd bez zysku. Obecność odnotowano, entuzjazmu nie.", 13, szary))
		else:
			v.add_child(Motyw.etykieta("Uwaga komisji: wynik w normie. Nagroda: brak nagany.", 13, szary))
		var wyn: Array = r.get("wyniesione", [])
		if not wyn.is_empty():
			var suma := 0
			for e in wyn:
				suma += int(e["wartosc"])
			v.add_child(Motyw.etykieta("Wyniesione ze strefy (%d szt., ok. %d bonów):" % [wyn.size(), suma], 15, ciem, Motyw.mono_b()))
			var lista := []
			for e in wyn.slice(0, 8):
				lista.append("%s (%d)" % [e["nazwa"], int(e["wartosc"])])
			var l := Motyw.etykieta("  " + ", ".join(lista) + (" i %d innych" % (wyn.size() - 8) if wyn.size() > 8 else ""), 13, ciem, Motyw.mono())
			l.autowrap_mode = TextServer.AUTOWRAP_WORD
			l.custom_minimum_size = Vector2(560, 0)
			v.add_child(l)
	else:
		var p: String = r.get("przyczyna", "pocisk")
		v.add_child(Motyw.etykieta("Przyczyna zgonu: %s" % NAZWY_PRZYCZYN.get(p, p), 15, ciem, Motyw.mono()))
		if String(r.get("zabojca", "")) != "" and p != "zaginiecie":
			v.add_child(Motyw.etykieta("Sprawca: %s" % r["zabojca"], 15, ciem, Motyw.mono()))
		var kom := Motyw.etykieta("„%s”" % KOMUNIKATY_ZGONU.get(p, KOMUNIKATY_ZGONU["pocisk"]), 16, Color(0.5, 0.1, 0.06), Motyw.cond())
		kom.autowrap_mode = TextServer.AUTOWRAP_WORD
		v.add_child(kom)
		v.add_child(Motyw.etykieta("Utracone wyposażenie: %d bonów" % int(r.get("wartosc_utracona", 0)), 15, ciem, Motyw.mono()))
		var ub: Array = r.get("ubezpieczone", [])
		if not ub.is_empty():
			v.add_child(Motyw.etykieta("Ubezpieczenie: wróci do skrytki – " + ", ".join(ub), 13, Color(0.2, 0.4, 0.18), Motyw.mono()))
		var ut: Array = r.get("utracone", [])
		if not ut.is_empty():
			var l := Motyw.etykieta(", ".join(ut.slice(0, 14)) + ("..." if ut.size() > 14 else ""), 12, szary)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD
			v.add_child(l)
	# dopiski z przebiegu rajdu
	v.add_child(Motyw.etykieta("DOPISKI:", 13, szary, Motyw.mono_b()))
	# powtarzające się wpisy (kolejne grupy, hałas zwabił faunę) zbite w jeden z licznikiem
	var zbite := []
	var ile := {}
	for d in dopiski(r):
		if not ile.has(d):
			zbite.append(d)
		ile[d] = int(ile.get(d, 0)) + 1
	for d in zbite:
		var l2 := Motyw.etykieta("— " + d + (" (×%d)" % int(ile[d]) if int(ile[d]) > 1 else ""), 14, ciem)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD
		v.add_child(l2)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var s: Dictionary = Gra.statystyki
	var akt: Array = Gra.kontrakty.get("aktywne", [])
	if not akt.is_empty():
		var lz := []
		for k in akt:
			lz.append(String(k["opis"]) + ("" if k["typ"] in ["dostawa", "wyjscie", "zwiad"] else " [%d/%d]" % [int(k["postep"]), int(k["ile"])]))
		var le := Motyw.etykieta("Zlecenia w toku: " + "; ".join(lz), 13, szary, Motyw.mono())
		le.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		le.custom_minimum_size = Vector2(560, 0)
		v.add_child(le)
	var rp: Dictionary = r.get("reputacja", {})
	if not rp.is_empty():
		var czesci := []
		for f in rp:
			czesci.append("%s %+d (%+d)" % [FrakcjeBazy.DANE[f]["nazwa"], int(rp[f]), FrakcjeBazy.rep(f)])
		v.add_child(Motyw.etykieta("Reputacja: " + " · ".join(czesci), 13, szary, Motyw.mono()))
	v.add_child(Motyw.etykieta("Kartoteka: rajdy %d · przeżyte %d · zgony %d · zlikwidowani %d" % [s["rajdy"], s["przezyte"], s["zgony"], s["zabici"]], 13, szary, Motyw.mono()))
	var b := Button.new()
	b.text = "Podpisz i wróć do bazy"
	b.pressed.connect(func(): Gra.idz_do_bazy())
	zew.add_child(b)
	Dzwiek.graj("pieczatka", 0.0)
	var args := OS.get_cmdline_user_args()
	for flaga in ["--zrzuty", "--zrzuty_raport"]:
		if args.has(flaga):
			_zrzut.call_deferred(args[args.find(flaga) + 1])


func _zrzut(k: String) -> void:
	for f in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(k.path_join("raport.png"))
	print("zrzut raportu")
	get_tree().quit()


static func dopiski(r: Dictionary) -> Array:
	var out := []
	var zabici: Array = r.get("zabici", [])
	var oddzialy := {}
	for z in zabici:
		var o: String = String(z.get("oddzial_nazwa", ""))
		var f: String = z.get("frakcja", "")
		var klucz := "%s|%s" % [f, o]
		oddzialy[klucz] = oddzialy.get(klucz, 0) + 1
	for k in oddzialy:
		var parts: PackedStringArray = k.split("|")
		var f := parts[0]
		var o := parts[1]
		var n: int = oddzialy[k]
		if f == "fauna":
			out.append("Unieszkodliwiono %d okaz%s fauny. Wniosek schroniska o odszkodowanie odrzucono." % [n, "" if n == 1 else "y"])
		elif f == "najemnik":
			out.append("Zlikwidowano %d najemnik%s z oddziału %s. Konkurencja ograniczona." % [n, "a" if n == 1 else "ów", o if o != "" else "bez nazwy"])
		else:
			var dop: String = ["dopisek: to dalej cywile", "dopisek: inwentarz zmniejszony", "dopisek: bez komentarza"][randi() % 3]
			out.append("Likwidacja %d szabrownik%s (grupa %s) – %s." % [n, "a" if n == 1 else "ów", o if o != "" else "?", dop])
	var zd: Dictionary = r.get("zdrowie", {})
	if zd.has("rece") and float(zd["rece"]) <= 1.0:
		out.append("Kosztem utraconej (funkcjonalnie) ręki.")
	if zd.has("nogi") and float(zd["nogi"]) <= 1.0:
		out.append("Powrót o własnych siłach uznano za przesadę: nogi niesprawne.")
	if zabici.is_empty():
		out.append("Brak strat po stronie przeciwnika. Pacyfizm odnotowano w aktach.")
	for e in r.get("zdarzenia", []):
		out.append(e["tekst"])
	return out
