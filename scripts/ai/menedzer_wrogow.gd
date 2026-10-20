extends Node
## Rozstawia oddziały przeciwników, zarządza osłonami i łącznością w oddziałach,
## a z czasem i hałasem rajdu dosyła nowe grupy (rosnące zagrożenie).

const ALFABET := ["Alfa", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot"]

var rajd: Node
var oslony: Array = []
var lampy: Array = []
var _zajete := {}          # indeks osłony -> wrog
var oddzialy: Array = []
var rng := RandomNumberGenerator.new()
var zagrozenie := 0.0
var _nastepna_fala := 240.0
var boss: Node = null      # Sęp (jeśli jest w tym rajdzie)
var _rep_t := 4.0          # co ile sprawdzać ostrzeżenia przyjaznych oddziałów
var _polowanie_t := 75.0   # najbliższe „namierzenie” gracza przez wrogą frakcję
var _ostrzezone := {}      # oddział -> już ostrzegł
var _polowanie_zapowiedziane := false


class Oddzial:
	extends RefCounted
	var nazwa := ""
	var czlonkowie: Array = []
	var dowodca: Node = null
	var poluje_t := 0.0      # wysłany na gracza: przez ten czas nawołuje się (słychać z daleka)
	var glos_t := 0.0

	## Kto idzie przodem przy przeszukiwaniu: dowódca albo najodważniejszy z żywych.
	func prowadzacy() -> Node:
		var best: Node = null
		var bm := -INF
		for w in czlonkowie:
			if not is_instance_valid(w) or w.cialo.martwy:
				continue
			var m: float = w.morale + (30.0 if w.cecha == "agresywny" else 0.0) + (15.0 if w.rola == "flanka" else 0.0)
			if w.stan == "opatrywanie":
				m -= 100.0
			if m > bm:
				bm = m
				best = w
		return best

	func alarm(pos: Vector3, od: Node) -> void:
		for w in czlonkowie:
			if is_instance_valid(w) and w != od:
				w.alarm_od_oddzialu(pos)

	func strata(kto: Node) -> void:
		czlonkowie.erase(kto)
		var spadek := 40.0 if kto == dowodca else 22.0
		for w in czlonkowie:
			if is_instance_valid(w):
				w.morale -= spadek
				w.alarm_od_oddzialu(kto.global_position)
		if kto == dowodca:
			dowodca = null
			# najemnicy po chwili wybierają nowego dowódcę
			for w in czlonkowie:
				if is_instance_valid(w) and w.frakcja == "najemnik":
					dowodca = w
					w.morale += 20.0
					break


func rozstaw(r: Node) -> void:
	rajd = r
	rng.seed = Gra.ziarno_rajdu + 77
	oslony = r.info["oslony"]
	lampy = r.info["lampy"]
	Gra.halas.connect(_halas)
	var spawny: Array = r.info["spawny"].duplicate()
	# komórki ze spawnami, od najgłębszej
	var po_komorce := {}
	for s in spawny:
		var k: Vector2i = s["komorka"]
		if not po_komorce.has(k):
			po_komorce[k] = []
		po_komorce[k].append(s)
	var komorki := po_komorce.keys()
	komorki.shuffle()
	var liczba := clampi(int(r.info["komorki"].size() / 9.0), 3, 7)
	# wojskowi na posterunkach z worków: siedzą w gnieździe i trzymają wejście
	for i in r.info.get("posterunki", []).size():
		_posterunek(r.info["posterunki"][i], i)
	var najemnicy := rng.randf() < 0.55
	komorki.sort_custom(func(a, b): return po_komorce[a][0]["glebokosc"] > po_komorce[b][0]["glebokosc"])
	var i := 0
	var start_pos: Vector3 = r.info.get("start", Vector3.ZERO)
	var uzyte := {}
	for k in komorki:
		if i >= liczba:
			break
		if (po_komorce[k][0]["pos"] as Vector3).distance_to(start_pos) < 25.0:
			continue
		var frak := "najemnik" if (najemnicy and i == 0) else "szabrownik"
		var ile := rng.randi_range(2, 3) if frak == "szabrownik" else 2
		_oddzial(frak, po_komorce[k], ile, i)
		uzyte[k] = true
		i += 1
	# Sęp: najgłębsza wolna komórka daleko od startu (zawsze, gdy jest na niego zlecenie)
	if zlecenie_na_bossa() or OS.get_cmdline_user_args().has("--boss") or Gra.sep_w_rajdzie(Gra.ziarno_rajdu):
		var najg: Vector2i = Vector2i(-999, -999)
		var gl := -1.0
		for k in po_komorce:
			var pk: Dictionary = po_komorce[k][0]
			if uzyte.has(k) or (pk["pos"] as Vector3).distance_to(start_pos) < 40.0:
				continue
			if float(pk.get("glebokosc", 0.0)) > gl:
				gl = float(pk.get("glebokosc", 0.0))
				najg = k
		if najg.x != -999:
			_boss(po_komorce[najg], start_pos)
	# fauna: watahy psów w piwnicach i magazynach
	var stada := 0
	for k in komorki:
		if stada >= 3:
			break
		if r.info["komorki"].has(k) and r.info["komorki"][k]["typ"] in ["piwnica", "magazyn"] and rng.randf() < 0.7:
			_stado(po_komorce[k][0]["pos"], rng.randi_range(1, 2))
			stada += 1


func _oddzial(frak: String, punkty: Array, ile: int, idx: int) -> void:
	var o := Oddzial.new()
	o.nazwa = "%s-%02d" % [ALFABET[idx % ALFABET.size()], rng.randi_range(1, 19)]
	var f: Dictionary = Dane.frakcje[frak]
	for j in ile:
		var zest := _losuj_zestaw(f["zestawy"])
		var w := Wrog.new()
		w.przygotuj(frak, zest, rng)
		w.menedzer = self
		w.oddzial = o
		w.rola = "dowodca" if j == 0 else ("flanka" if j == 2 or (frak == "najemnik" and j == 1) else "strzelec")
		var p: Vector3 = punkty[j % punkty.size()]["pos"] + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		rajd.swiat.add_child(w)
		w.global_position = p
		w.rotation.y = rng.randf() * TAU
		o.czlonkowie.append(w)
		if j == 0:
			o.dowodca = w
		w.set_meta("oddzial_nazwa", o.nazwa)
	oddzialy.append(o)


static func zlecenie_na_bossa() -> bool:
	for k in Gra.kontrakty.get("aktywne", []):
		if String(k.get("cel", "")) in ["boss", "niesmiertelnik"]:
			return true
	return false


## Sęp i dwóch dezerterów: trzymają pozycję w głębi strefy (jak posterunek), twarzą ku wejściu od strony startu.
func _boss(punkty: Array, start_pos: Vector3) -> void:
	var o := Oddzial.new()
	o.nazwa = "Sępy"
	var p0: Vector3 = punkty[0]["pos"]
	var kier := start_pos - p0
	kier.y = 0.0
	kier = kier.normalized() if kier.length() > 0.1 else Vector3.FORWARD
	var zest: Dictionary = Dane.frakcje["najemnik"]["zestawy"][0]
	for j in 3:
		var w := Wrog.new()
		w.przygotuj("najemnik", zest, rng)
		if j == 0:
			w.uczyn_bossem()
			boss = w
		else:
			w.uczyn_dezerterem()
		w.menedzer = self
		w.oddzial = o
		w.rola = "dowodca" if j == 0 else "strzelec"
		var bok := kier.cross(Vector3.UP) * (0.0 if j == 0 else (1.4 if j == 1 else -1.4))
		var p: Vector3 = (punkty[j % punkty.size()]["pos"] as Vector3) if j > 0 and punkty.size() > j else p0 + bok + kier * (0.0 if j == 0 else 1.0)
		w.posterunek = {"pos": p, "kier": kier}
		w.stan = "posterunek"
		rajd.swiat.add_child(w)
		w.global_position = p + Vector3(0, 0.05, 0)
		w.rotation.y = atan2(-kier.x, -kier.z)
		w.set_meta("oddzial_nazwa", o.nazwa)
		o.czlonkowie.append(w)
		if j == 0:
			o.dowodca = w
	oddzialy.append(o)
	rajd.dodaj_zdarzenie("Nasłuch: Sęp i jego ludzie zaszyli się w głębi strefy.")


func _posterunek(pst: Dictionary, idx: int) -> void:
	var o := Oddzial.new()
	o.nazwa = "Posterunek %d" % (idx + 1)
	var f: Dictionary = Dane.frakcje["wojskowy"]
	var miejsca: Array = pst["miejsca"]
	for j in miejsca.size():
		var w := Wrog.new()
		w.przygotuj("wojskowy", _losuj_zestaw(f["zestawy"]), rng)
		w.menedzer = self
		w.oddzial = o
		w.rola = "dowodca" if j == 0 else "strzelec"
		w.posterunek = {"pos": miejsca[j], "kier": pst["kier"]}
		w.stan = "posterunek"
		rajd.swiat.add_child(w)
		w.global_position = miejsca[j] + Vector3(0, 0.05, 0)
		w.rotation.y = atan2(-(pst["kier"] as Vector3).x, -(pst["kier"] as Vector3).z)
		o.czlonkowie.append(w)
		if j == 0:
			o.dowodca = w
	oddzialy.append(o)


func _losuj_zestaw(zestawy: Array) -> Dictionary:
	var tab := []
	for z in zestawy:
		tab.append([z, z["waga"]])
	var suma := 0.0
	for t in tab:
		suma += t[1]
	var r := rng.randf() * suma
	for t in tab:
		r -= t[1]
		if r <= 0.0:
			return t[0]
	return zestawy[0]


func zajeta_oslona(o: Dictionary, kto: Node) -> bool:
	var idx := oslony.find(o)
	return _zajete.has(idx) and is_instance_valid(_zajete[idx]) and _zajete[idx] != kto


func zajmij_oslone(o: Dictionary, kto: Node) -> void:
	zwolnij_oslone(kto)
	_zajete[oslony.find(o)] = kto


func zwolnij_oslone(kto: Node) -> void:
	for k in _zajete.keys():
		if _zajete[k] == kto:
			_zajete.erase(k)


func _halas(_pos: Vector3, zasieg: float, zrodlo: Node) -> void:
	if zrodlo is Gracz:
		zagrozenie += zasieg * 0.004


func _process(delta: float) -> void:
	if rajd == null or rajd.koniec:
		return
	zagrozenie += delta * 0.01
	_rep_t -= delta
	if _rep_t <= 0.0:
		_rep_t = 1.5
		_ostrzezenia()
	# polujący nawołują się w marszu – gracz ma szansę usłyszeć, skąd idą
	for o in oddzialy:
		if o.poluje_t <= 0.0:
			continue
		o.poluje_t -= delta
		o.glos_t -= delta
		if o.glos_t <= 0.0:
			o.glos_t = rng.randf_range(7.0, 11.0)
			var d: Node = o.prowadzacy()
			if d and d.stan != "walka":
				Dzwiek.graj_3d("glos_komenda_%d" % (rng.randi() % 3), (d as Node3D).global_position + Vector3.UP * 1.6, (d as Node3D).get_parent(), 3.0, rng.randf_range(0.9, 1.05), 45.0)
	_polowanie_t -= delta
	if _polowanie_t <= 0.0:
		_polowanie_t = rng.randf_range(80.0, 120.0)
		_polowanie()
	_nastepna_fala -= delta * (1.0 + zagrozenie * 0.05)
	if _nastepna_fala <= 0.0:
		_nastepna_fala = rng.randf_range(200.0, 300.0)
		_fala()


func _stado(pos: Vector3, ile: int) -> void:
	for j in ile:
		var f := Fauna.new()
		rajd.swiat.add_child(f)
		f.global_position = pos + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
		f.rotation.y = rng.randf() * TAU


## Nowa grupa (szabrownicy albo fauna) z dala od gracza.
func _fala() -> void:
	var g: Node3D = rajd.gracz
	var kandydaci: Array = rajd.info["spawny"].filter(func(s): return s["pos"].distance_to(g.global_position) > 35.0)
	if kandydaci.is_empty():
		return
	var s: Dictionary = kandydaci[rng.randi() % kandydaci.size()]
	if zagrozenie > 3.0 and rng.randf() < 0.5:
		_stado(s["pos"], rng.randi_range(2, 3))
		rajd.dodaj_zdarzenie("Hałas zwabił faunę strefy.")
	else:
		_oddzial("szabrownik", [s], 2, oddzialy.size())
		rajd.dodaj_zdarzenie("Do strefy weszła nowa grupa szabrowników.")


# ------------------------------------------------------------------ reputacja w strefie

const NAZWY_GRUP := {"szabrownik": "szabrownicy", "najemnik": "najemnicy", "wojskowy": "wojskowi"}


static func kierunek(g: Node3D, cel: Vector3) -> String:
	var lok := g.global_basis.inverse() * (cel - g.global_position)
	var kat := rad_to_deg(atan2(lok.x, -lok.z))
	var t := "przed tobą"
	if kat > 45.0 and kat <= 135.0:
		t = "po prawej"
	elif kat < -45.0 and kat >= -135.0:
		t = "po lewej"
	elif absf(kat) > 135.0:
		t = "za tobą"
	if cel.y - g.global_position.y > 2.0:
		t += ", piętro wyżej"
	elif g.global_position.y - cel.y > 2.0:
		t += ", piętro niżej"
	return t


## Przyjazny oddział (rozejm z reputacji), który zobaczy gracza z bliska, raz ostrzega przed najbliższym zagrożeniem.
func _ostrzezenia() -> void:
	var g: Node3D = rajd.gracz
	if g == null or not is_instance_valid(g):
		return
	var space := g.get_world_3d().direct_space_state
	for o in oddzialy:
		if _ostrzezone.has(o):
			continue
		var d: Node = o.prowadzacy()
		if d == null or not d.rozejm or d.dezerter or d.stan in ["walka", "ucieczka", "poddany"]:
			continue
		if (d as Node3D).global_position.distance_to(g.global_position) > 9.0:
			continue
		var q := PhysicsRayQueryParameters3D.create((d as Node3D).global_position + Vector3.UP * 1.6, g.global_position + Vector3.UP * 1.5, Balistyka.WARSTWA_SWIAT)
		if not space.intersect_ray(q).is_empty():
			continue
		_ostrzezone[o] = true
		var najb: Node3D = null
		var nd := 45.0
		for w in get_tree().get_nodes_in_group("wrogowie"):
			if not is_instance_valid(w) or w == d or w.get("cialo") == null or w.cialo.martwy:
				continue
			if w is Wrog and (w.rozejm or w.frakcja == d.frakcja):
				continue
			var dd := (w as Node3D).global_position.distance_to(g.global_position)
			if dd < nd:
				nd = dd
				najb = w
		var kto: String = d.nazwa_jednostki
		if najb:
			var grupa: String = "pełzacze" if not (najb is Wrog) else ("ludzie Sępa" if najb.dezerter else NAZWY_GRUP.get(najb.frakcja, "obcy"))
			d._napis("Uważaj, %s." % grupa)
			g.komunikat.emit("%s (rozejm): uważaj – %s %s, jakieś %d m." % [kto, grupa, kierunek(g, (najb as Node3D).global_position), int(nd)])
		else:
			d._napis("Spokojnie. Czysto.")
			g.komunikat.emit("%s (rozejm): w okolicy czysto. Tylko nie celuj w nas." % kto)


## Wroga frakcja (reputacja ≤ PROG_POLOWANIA) co jakiś czas wysyła najbliższy wolny oddział tam, gdzie gracz jest.
func _polowanie() -> void:
	var g: Node3D = rajd.gracz
	if g == null or not is_instance_valid(g) or rajd.koniec:
		return
	for f in FrakcjeBazy.DANE:
		if FrakcjeBazy.rep(f) > FrakcjeBazy.PROG_POLOWANIA:
			continue
		var best: Oddzial = null
		var bd := INF
		for o in oddzialy:
			var d: Node = o.prowadzacy()
			if d == null or d.frakcja != f or d.dezerter or not (d.posterunek as Dictionary).is_empty() or d.stan == "walka":
				continue
			var dd := (d as Node3D).global_position.distance_to(g.global_position)
			if dd > 15.0 and dd < bd:
				bd = dd
				best = o
		if best == null:
			continue
		for w in best.czlonkowie:
			if is_instance_valid(w):
				w.alarm_od_oddzialu(g.global_position + Vector3(rng.randf_range(-5.0, 5.0), 0.0, rng.randf_range(-5.0, 5.0)))
		best.poluje_t = 70.0
		best.glos_t = rng.randf_range(3.0, 6.0)
		if not _polowanie_zapowiedziane:
			_polowanie_zapowiedziane = true
			g.komunikat.emit("W radiostacji trzaski: %s cię namierzyli (reputacja %d). Ruszają w twoją stronę." % [FrakcjeBazy.DANE[f]["nazwa"], FrakcjeBazy.rep(f)])
		rajd.dodaj_zdarzenie("%s wysłali oddział %s na pozycję gracza." % [FrakcjeBazy.DANE[f]["nazwa"], best.nazwa])
