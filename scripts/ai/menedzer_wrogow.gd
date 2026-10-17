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


class Oddzial:
	extends RefCounted
	var nazwa := ""
	var czlonkowie: Array = []
	var dowodca: Node = null

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
	var liczba := clampi(int(r.info["komorki"].size() / 4.0), 3, 5)
	var najemnicy := rng.randf() < 0.55
	komorki.sort_custom(func(a, b): return po_komorce[a][0]["glebokosc"] > po_komorce[b][0]["glebokosc"])
	var i := 0
	for k in komorki:
		if i >= liczba:
			break
		var frak := "najemnik" if (najemnicy and i == 0) else "szabrownik"
		var ile := rng.randi_range(2, 3) if frak == "szabrownik" else 2
		_oddzial(frak, po_komorce[k], ile, i)
		i += 1


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
		zagrozenie += zasieg * 0.02


func _process(delta: float) -> void:
	if rajd == null or rajd.koniec:
		return
	zagrozenie += delta * 0.01
	_nastepna_fala -= delta * (1.0 + zagrozenie * 0.05)
	if _nastepna_fala <= 0.0:
		_nastepna_fala = rng.randf_range(200.0, 300.0)
		_fala()


## Nowa grupa szabrowników z dala od gracza.
func _fala() -> void:
	var g: Node3D = rajd.gracz
	var kandydaci: Array = rajd.info["spawny"].filter(func(s): return s["pos"].distance_to(g.global_position) > 18.0)
	if kandydaci.is_empty():
		return
	var s: Dictionary = kandydaci[rng.randi() % kandydaci.size()]
	_oddzial("szabrownik", [s], 2, oddzialy.size())
	rajd.dodaj_zdarzenie("Do strefy weszła nowa grupa szabrowników.")
