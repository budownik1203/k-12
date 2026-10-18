class_name AnimacjeAkcji
extends Node3D
## Animacje czynności z pierwszej osoby (osobne dla każdej): napełnianie magazynka nabój po naboju,
## bandażowanie przedramienia, opatrunek uciskowy, szyna na nodze, autostrzykawka w udo, apteczka.
## Dłonie to te same modele co przy broni (Reka); rekwizyty budowane z brył (Bryly).
## Współrzędne: przestrzeń kamery (x w prawo, y w górę, -z do przodu).

var typ := ""
var id := ""                 # przedmiot (lek / magazynek)
var amun := ""               # rodzaj naboju przy napełnianiu
var lewa: Reka
var prawa: Reka
var _rek := {}               # rekwizyty: nazwa -> Node3D
var _owiniecia: Array = []   # bandaż: pierścienie pojawiające się z postępem
var gracz: Node


func zbuduj(p_typ: String, p_id: String, p_amun := "") -> void:
	typ = p_typ
	id = p_id
	amun = p_amun
	for c in get_children():
		c.queue_free()
	_rek.clear()
	_owiniecia.clear()
	lewa = Reka.new(false, true, "otwarta", 0.5)
	prawa = Reka.new(true, false, "otwarta", 0.5)
	add_child(lewa)
	add_child(prawa)
	# przedramiona schodzą do łokci poza dolnymi rogami kadru
	lewa.celuj_lokiec(Vector3(-0.24, -0.5, 0.02), self)
	prawa.celuj_lokiec(Vector3(0.24, -0.5, 0.02), self)
	match typ:
		"magazynek":
			_rek["mag"] = _model_magazynka(id)
			_rek["naboj"] = _model_naboju(amun)
			lewa.ustaw_chwyt("magazynek")
			prawa.ustaw_chwyt("szczypta")
		"rozladowanie":
			if id.begins_with("mag_"):
				_rek["mag"] = _model_magazynka(id)
				lewa.ustaw_chwyt("magazynek")
			else:
				lewa.visible = false
			_rek["naboj"] = _model_naboju(amun)
			prawa.ustaw_chwyt("szczypta")
		"bandaz":
			_rek["rolka"] = _wezel([Bryly.walec(Vector3(-0.018, 0, 0), Vector3(0.018, 0, 0), 0.02, 0.02, "bandaz", 10)])
			lewa.ustaw_chwyt("piesc")
			prawa.ustaw_chwyt("magazynek")
			for i in 6:
				var o := _wezel([Bryly.walec(Vector3(0, 0, -0.008), Vector3(0, 0, 0.008), 0.033, 0.033, "bandaz", 10)])
				o.visible = false
				_owiniecia.append(o)
		"opatrunek":
			_rek["paczka"] = _wezel([Bryly.box(Vector3.ZERO, Vector3(0.07, 0.02, 0.1), "opakowanie", 0.006)])
			_rek["gaza"] = _wezel([Bryly.box(Vector3.ZERO, Vector3(0.08, 0.012, 0.08), "bandaz", 0.004)])
			lewa.ustaw_chwyt("magazynek")
			prawa.ustaw_chwyt("magazynek")
		"szyna":
			_rek["szyna"] = _wezel([Bryly.box(Vector3.ZERO, Vector3(0.1, 0.008, 0.36), "szyna", 0.003)])
			lewa.ustaw_chwyt("magazynek")
			prawa.ustaw_chwyt("magazynek")
		"podnies":
			prawa.ustaw_chwyt("otwarta")
			lewa.visible = false
		"otwieranie":
			prawa.ustaw_chwyt("otwarta")
			lewa.visible = false
		"bolostop":
			_rek["strzykawka"] = _wezel([
				Bryly.walec(Vector3(0, 0, 0.05), Vector3(0, 0, -0.06), 0.011, 0.011, "opakowanie", 10),
				Bryly.walec(Vector3(0, 0, -0.06), Vector3(0, 0, -0.075), 0.011, 0.007, "metal_jasny", 10),
				Bryly.walec(Vector3(0, 0, 0.05), Vector3(0, 0, 0.065), 0.013, 0.013, "czerwony", 10),
			])
			lewa.ustaw_chwyt("otwarta")
			prawa.ustaw_chwyt("piesc")
		_:
			# apteczka: otwarte pudełko w lewej, prawa wyjmuje i przykłada
			_rek["apteczka"] = _wezel([
				Bryly.box(Vector3(0, 0, 0), Vector3(0.14, 0.05, 0.1), "apteczka", 0.006),
				Bryly.box(Vector3(0, 0.03, -0.0), Vector3(0.12, 0.012, 0.085), "bandaz", 0.003),
			])
			_rek["wieko"] = _wezel([Bryly.box(Vector3(0, 0.0, -0.05), Vector3(0.14, 0.012, 0.1), "apteczka", 0.004)])
			_rek["gaza"] = _wezel([Bryly.box(Vector3.ZERO, Vector3(0.05, 0.01, 0.04), "bandaz", 0.003)])
			lewa.ustaw_chwyt("magazynek")
			prawa.ustaw_chwyt("szczypta")


func _wezel(czesci: Array) -> Node3D:
	var n := Node3D.new()
	n.add_child(Bryly.instancja(czesci))
	add_child(n)
	return n


## Magazynek z modelu broni (ten sam, który się wkłada) – górą w (0,0,0).
func _model_magazynka(mid: String) -> Node3D:
	var bron_id: String = {"mag_pw9": "pw9", "mag_pm63": "pm63", "mag_kb47": "kb47"}.get(mid, "kb47")
	var md := ModeleIB.bron(bron_id)
	var n := Node3D.new()
	add_child(n)
	var mi := Bryly.instancja(md.get("mag3", []))
	n.add_child(mi)
	var ab := mi.get_aabb()
	mi.position = -Vector3(ab.get_center().x, ab.end.y, ab.get_center().z)
	n.set_meta("wys", ab.size.y)
	return n


func _model_naboju(aid: String) -> Node3D:
	var cz := []
	match aid:
		"a_12":
			cz = [Bryly.walec(Vector3(0, 0, 0), Vector3(0, 0.055, 0), 0.0105, 0.0105, "czerwony", 8),
				Bryly.walec(Vector3(0, -0.012, 0), Vector3(0, 0, 0), 0.0112, 0.0112, "mosiadz", 8)]
		"a_762", "a_762bp":
			cz = [Bryly.walec(Vector3(0, 0, 0), Vector3(0, 0.03, 0), 0.0056, 0.0056, "mosiadz", 8),
				Bryly.walec(Vector3(0, 0.03, 0), Vector3(0, 0.038, 0), 0.0056, 0.0032, "mosiadz", 8),
				Bryly.walec(Vector3(0, 0.038, 0), Vector3(0, 0.054, 0), 0.0039, 0.0012, "miedz", 8)]
		_:
			cz = [Bryly.walec(Vector3(0, 0, 0), Vector3(0, 0.018, 0), 0.0048, 0.0048, "mosiadz", 8),
				Bryly.walec(Vector3(0, 0.018, 0), Vector3(0, 0.026, 0), 0.0046, 0.0022, "miedz", 8)]
	return _wezel(cz)


## Ustawia dłoń: nadgarstek w `poz`, palce w kierunku `palce`, grzbiet dłoni w stronę `grzbiet`.
static func _uloz(r: Reka, poz: Vector3, palce: Vector3, grzbiet: Vector3) -> void:
	var zl := -palce.normalized()
	var yl := (grzbiet - zl * grzbiet.dot(zl)).normalized()
	var xl := yl.cross(zl).normalized()
	r.basis = Basis(xl, yl, zl)
	r.position = poz


func aktualizuj(t: float, czas: float, kroki: int, zrobione: int, wejscie: float) -> void:
	# wejscie 0..1: ręce wjeżdżają od dołu kadru na początku czynności
	var dol := Vector3(0, -0.25, 0.05) * (1.0 - wejscie)
	var f := clampf(t / maxf(0.01, czas), 0.0, 1.0)
	if gracz and lewa:
		lewa.ustaw_zdrowie(gracz.cialo.procent(), gracz.cialo.krwawi() > 0)
	match typ:
		"magazynek":
			_magazynek(t, czas, kroki, zrobione, dol)
		"rozladowanie":
			_rozladowanie(t, czas, kroki, zrobione, dol)
		"bandaz":
			_bandaz(t, f, dol)
		"opatrunek":
			_opatrunek(t, f, dol)
		"szyna":
			_szyna(t, f, dol)
		"podnies":
			_podnies(f, dol)
		"otwieranie":
			_siegnij(f, dol)
		"bolostop":
			_bolostop(t, f, dol)
		_:
			_apteczka(t, f, dol)


func _magazynek(t: float, czas: float, kroki: int, zrobione: int, dol: Vector3) -> void:
	# lewa trzyma magazynek pionowo przed sobą, lekko pochylony; prawa bierze nabój z dołu i wciska go z góry
	var mag: Node3D = _rek["mag"]
	var gora := Vector3(-0.01, -0.035, -0.33) + dol
	mag.position = gora + Vector3(0, sin(t * 2.3) * 0.002, 0)
	mag.rotation = Vector3(0.35, 0.3, -0.12)
	var wys: float = mag.get_meta("wys", 0.12)
	var b := mag.basis
	_uloz(lewa, gora + b * Vector3(-0.04, -wys * 0.55, 0.035), b * Vector3(0.6, 0.0, -1.0), b * Vector3(-1.0, 0.1, 0.2))
	var krok := czas / maxf(1.0, kroki)
	var p := fmod(t, krok) / krok
	if zrobione >= kroki:
		p = 1.0
	var naboj: Node3D = _rek["naboj"]
	var dolny := gora + Vector3(0.09, -0.12, 0.05)
	var nad := gora + b * Vector3(0, 0.028, -0.004)
	var w := gora + b * Vector3(0, 0.004, -0.004)
	var np: Vector3
	if p < 0.45:
		np = dolny.lerp(nad, smoothstep(0.0, 0.45, p))
	elif p < 0.8:
		np = nad.lerp(w, smoothstep(0.45, 0.8, p))
	else:
		np = w.lerp(dolny, smoothstep(0.8, 1.0, p))
	naboj.visible = p < 0.8
	naboj.position = np
	naboj.basis = b * Basis(Vector3(1, 0, 0), deg_to_rad(-80.0))
	# kciuk i palec wskazujący trzymają nabój – nadgarstek za nim
	var kier := Vector3(-0.75, 0.3, -0.55).normalized()
	_uloz(prawa, np - kier * 0.125 + Vector3(0, -0.018, 0), kier, Vector3(0.2, 1.0, 0.3))
	# docisk sprężyny: magazynek lekko „siada” przy wciśnięciu
	if p > 0.55 and p < 0.8:
		mag.position.y -= 0.004


func _rozladowanie(t: float, czas: float, kroki: int, zrobione: int, dol: Vector3) -> void:
	# kciuk prawej zsuwa nabój do przodu z wargi magazynka, nabój wypada w dół do dłoni / kieszeni
	var krok := czas / maxf(1.0, kroki)
	var p := fmod(t, krok) / krok
	if zrobione >= kroki:
		p = 1.0
	var naboj: Node3D = _rek["naboj"]
	var gora := Vector3(-0.01, -0.035, -0.33) + dol
	var b := Basis(Vector3(1, 0, 0), 0.35) * Basis(Vector3(0, 1, 0), 0.3) * Basis(Vector3(0, 0, 1), -0.12)
	if _rek.has("mag"):
		var mag: Node3D = _rek["mag"]
		mag.position = gora + Vector3(0, sin(t * 2.0) * 0.002, 0)
		mag.basis = b
		var wys: float = mag.get_meta("wys", 0.12)
		_uloz(lewa, gora + b * Vector3(-0.04, -wys * 0.55, 0.035), b * Vector3(0.6, 0.0, -1.0), b * Vector3(-1.0, 0.1, 0.2))
	else:
		# z komory / rury: nabój wyciągany palcami do tyłu i w bok
		gora = Vector3(0.0, -0.06, -0.36) + dol
	var tyl := gora + b * Vector3(0, 0.006, 0.02)
	var przod := gora + b * Vector3(0, 0.008, -0.05)
	var dol_k := gora + Vector3(0.1, -0.2, 0.03)
	var np: Vector3
	if p < 0.3:
		np = tyl
	elif p < 0.65:
		np = tyl.lerp(przod, smoothstep(0.3, 0.65, p))
	else:
		np = przod.lerp(dol_k, smoothstep(0.65, 1.0, p))
	naboj.visible = p > 0.08 and p < 0.97
	naboj.position = np
	naboj.basis = b * Basis(Vector3(1, 0, 0), deg_to_rad(-80.0 - smoothstep(0.65, 1.0, p) * 60.0))
	# kciuk: z tyłu nad nabojem przesuwa się do przodu, potem wraca
	var kc: Vector3
	if p < 0.3:
		kc = (przod + Vector3(0.02, 0.02, 0.0)).lerp(tyl, smoothstep(0.0, 0.3, p))
	elif p < 0.65:
		kc = tyl.lerp(przod, smoothstep(0.3, 0.65, p))
	else:
		kc = przod + Vector3(0.02, 0.02 * smoothstep(0.65, 1.0, p), 0.0)
	# dłoń z prawej i od dołu: palce do góry w lewo, kciuk na wierzchu magazynka
	var nadg := kc + Vector3(0.1, -0.085, 0.01)
	_uloz(prawa, nadg, (kc - nadg).normalized() + Vector3(0, 0, -0.3), Vector3(1.0, 0.1, 0.4))


func _bandaz(t: float, f: float, dol: Vector3) -> void:
	# lewe przedramię poziomo przed sobą (wewnętrzną stroną do góry, widać zegarek), prawa owija je rolką
	var lp := Vector3(-0.12, -0.12, -0.36) + dol
	_uloz(lewa, lp, Vector3(0.95, 0.1, -0.25), Vector3(0.0, -1.0, 0.1))
	var przedr := lp + Vector3(-0.07, -0.01, 0.02)
	var kat := t * 7.0
	var promien := 0.05
	var rolka: Node3D = _rek["rolka"]
	var os := Vector3(-0.95, -0.1, 0.25).normalized()
	var u := os.cross(Vector3.UP).normalized()
	var v := os.cross(u)
	var srodek := przedr + os * (0.02 + f * 0.06)
	rolka.position = srodek + (u * cos(kat) + v * sin(kat)) * promien
	rolka.basis = Basis.looking_at(os, Vector3.UP)
	_uloz(prawa, rolka.position + Vector3(0.06, -0.03, 0.07), Vector3(-0.7, 0.25, -0.6), Vector3(0.0, 1.0, 0.3))
	var n := int(f * _owiniecia.size() + 0.5)
	for i in _owiniecia.size():
		var o: Node3D = _owiniecia[i]
		o.visible = i < n
		o.position = przedr + os * (0.01 + i * 0.014)
		o.basis = Basis.looking_at(os, Vector3.UP)


func _opatrunek(t: float, f: float, dol: Vector3) -> void:
	# 0-35%: rozrywanie opakowania, 35-100%: gaza przyciskana do rany (w dół kadru) z uciskiem
	var paczka: Node3D = _rek["paczka"]
	var gaza: Node3D = _rek["gaza"]
	if f < 0.35:
		var e := smoothstep(0.0, 0.35, f)
		var sr := Vector3(0, -0.1, -0.34) + dol
		paczka.visible = true
		gaza.visible = false
		paczka.position = sr + Vector3(-0.03 - e * 0.04, 0, 0)
		paczka.rotation = Vector3(1.2, 0.0, -0.3 - e * 0.4)
		_uloz(lewa, paczka.position + Vector3(-0.06, -0.03, 0.06), Vector3(0.6, 0.4, -0.7), Vector3(-0.3, 0.6, 0.6))
		_uloz(prawa, sr + Vector3(0.05 + e * 0.05, -0.02, 0.06), Vector3(-0.6, 0.4, -0.7), Vector3(0.3, 0.6, 0.6))
	else:
		var e := smoothstep(0.35, 0.55, f)
		var ucisk := sin(t * 5.0) * 0.008
		var sr := Vector3(0, -0.1 - e * 0.07 + ucisk, -0.32) + dol
		paczka.visible = false
		gaza.visible = true
		gaza.position = sr
		gaza.rotation = Vector3(0.3, 0, 0)
		_uloz(lewa, sr + Vector3(-0.07, 0.03, 0.08), Vector3(0.5, -0.5, -0.7), Vector3(0.0, 1.0, 0.2))
		_uloz(prawa, sr + Vector3(0.07, 0.04, 0.08), Vector3(-0.5, -0.5, -0.7), Vector3(0.0, 1.0, 0.2))


func _szyna(t: float, f: float, dol: Vector3) -> void:
	# szyna wyginana w obu dłoniach, potem opuszczana do nogi i mocowana (ruchy owijania)
	var szyna: Node3D = _rek["szyna"]
	var e := smoothstep(0.15, 0.4, f)
	var sr := Vector3(0, -0.1 - e * 0.16, -0.36 + e * 0.04) + dol
	szyna.position = sr
	szyna.rotation = Vector3(0.9 + e * 0.5, 0.0, 0.0)
	var b := szyna.basis
	var owij := sin(t * 6.0) * 0.03 * smoothstep(0.45, 0.55, f)
	_uloz(lewa, sr + b * Vector3(-0.07, 0.0, 0.12) + Vector3(0, 0, 0.06), Vector3(0.5, 0.3, -0.8), Vector3(-0.4, 0.8, 0.3))
	_uloz(prawa, sr + b * Vector3(0.07 + owij, owij, -0.06) + Vector3(0, 0, 0.06), Vector3(-0.5, 0.3, -0.8), Vector3(0.4, 0.8, 0.3))


func _bolostop(t: float, f: float, dol: Vector3) -> void:
	# zdjęcie nasadki, zamach i wbicie autostrzykawki w udo (dół kadru), przytrzymanie
	var s: Node3D = _rek["strzykawka"]
	var start := Vector3(0.06, -0.1, -0.33) + dol
	var udo := Vector3(0.05, -0.27, -0.27)
	var p: Vector3
	if f < 0.3:
		p = start
	elif f < 0.45:
		p = start.lerp(start + Vector3(0, 0.05, 0.02), smoothstep(0.3, 0.45, f))
	elif f < 0.55:
		p = (start + Vector3(0, 0.05, 0.02)).lerp(udo, smoothstep(0.45, 0.55, f))
	else:
		p = udo + Vector3(0, sin(t * 3.0) * 0.003, 0)
	s.position = p
	s.basis = Basis.looking_at(Vector3(0.0, -1.0, 0.25), Vector3(0, 0, -1))
	_uloz(prawa, p + Vector3(0.0, 0.07, 0.04), Vector3(0.0, -0.4, -0.9), Vector3(1.0, 0.2, 0.0))
	# lewa zdejmuje nasadkę na początku, potem opiera się o kolano
	var lp := start + Vector3(-0.08, 0.04, 0.0) if f < 0.3 else Vector3(-0.13, -0.24, -0.3) + dol
	_uloz(lewa, lp, Vector3(0.5, 0.2, -0.8), Vector3(-0.3, 0.9, 0.2))
	lewa.ustaw_chwyt("szczypta" if f < 0.3 else "otwarta")


func _apteczka(t: float, f: float, dol: Vector3) -> void:
	var ap: Node3D = _rek["apteczka"]
	var wieko: Node3D = _rek["wieko"]
	var gaza: Node3D = _rek["gaza"]
	var sr := Vector3(-0.05, -0.15, -0.34) + dol
	ap.position = sr
	ap.rotation = Vector3(0.55, 0.25, 0.0)
	var b := ap.basis
	wieko.position = sr + b * Vector3(0, 0.025, 0.05)
	wieko.basis = b * Basis(Vector3(1, 0, 0), deg_to_rad(-100.0 * smoothstep(0.0, 0.15, f)))
	_uloz(lewa, sr + b * Vector3(-0.09, -0.02, 0.0) + Vector3(-0.02, -0.02, 0.05), b * Vector3(1.0, 0.0, -0.3), b * Vector3(0, -1, 0))
	# prawa: co ok. 1,2 s bierze gazę z pudełka i przykłada (w dół kadru)
	var c := fmod(t, 1.2) / 1.2
	var z_pudla := sr + b * Vector3(0.02, 0.035, 0.0)
	var rana := Vector3(0.1, -0.25, -0.28)
	var gp: Vector3
	if c < 0.3:
		gp = z_pudla
	elif c < 0.6:
		gp = z_pudla.lerp(rana, smoothstep(0.3, 0.6, c))
	else:
		gp = rana.lerp(z_pudla, smoothstep(0.75, 1.0, c))
	gaza.position = gp
	gaza.visible = f > 0.12
	_uloz(prawa, gp + Vector3(0.06, 0.035, 0.06), Vector3(-0.6, -0.3, -0.7), Vector3(0.2, 1.0, 0.2))


func _podnies(f: float, dol: Vector3) -> void:
	# prawa dłoń sięga w dół przed siebie (ku ziemi), zaciska się i wraca
	var gora := Vector3(0.12, -0.16, -0.32) + dol
	var ziemia := Vector3(0.04, -0.42, -0.42)
	var e := smoothstep(0.0, 0.5, f) * (1.0 - smoothstep(0.7, 1.0, f))
	var p := gora.lerp(ziemia, e)
	_uloz(prawa, p, Vector3(-0.2, -0.85, -0.45), Vector3(0.3, 0.3, 0.9))
	prawa.ustaw_chwyt("piesc" if f > 0.48 else "otwarta")


func _siegnij(f: float, dol: Vector3) -> void:
	# prawa dłoń sięga przed siebie do uchwytu / wieka, chwyta i ciągnie do siebie, potem puszcza
	var gora := Vector3(0.12, -0.16, -0.3) + dol
	var uchwyt := Vector3(0.05, -0.1, -0.6)
	var e := smoothstep(0.0, 0.35, f)
	var ciag := smoothstep(0.35, 0.8, f)
	var p := gora.lerp(uchwyt, e) + Vector3(0.04, 0.0, 0.22) * ciag
	p = p.lerp(gora + Vector3(0, -0.12, 0.05), smoothstep(0.85, 1.0, f))
	_uloz(prawa, p, Vector3(-0.15, -0.1, -1.0), Vector3(0.3, 1.0, 0.2))
	prawa.ustaw_chwyt("piesc" if f > 0.32 and f < 0.85 else "otwarta")
