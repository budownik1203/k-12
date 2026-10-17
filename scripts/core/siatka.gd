class_name Siatka
extends RefCounted
## Siatka pojemnika (plecak, kamizelka, kieszenie, skrytka, skrzynia).
## Każdy wpis to {"p": Przedmiot, "x": int, "y": int}.

signal zmieniona

var w: int
var h: int
var redukcja := 0.0
var items: Array = []
var maska := PackedByteArray()   # 1 = komórka istnieje; puste = cała siatka (przegródki kieszeni)


## Siatka pojemnika z definicji: rozmiar, redukcja wagi i układ przegródek ("uklad": ["##.##", ...]).
static func z_definicji(pj: Dictionary) -> Siatka:
	var s := Siatka.new(int(pj["sw"]), int(pj["sh"]), float(pj.get("redukcja", 0.0)))
	s.ustaw_uklad(pj.get("uklad", []))
	return s


func ustaw_uklad(wiersze: Array) -> void:
	maska = PackedByteArray()
	if wiersze.is_empty():
		return
	maska.resize(w * h)
	for y in mini(h, wiersze.size()):
		var r: String = wiersze[y]
		for x in mini(w, r.length()):
			maska[y * w + x] = 1 if r[x] == "#" else 0


func dostepna(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	return maska.is_empty() or maska[y * w + x] == 1


## Ile z "ile" sztuk da się dołożyć do stosu q, żeby po urośnięciu nadal mieścił się w siatce.
func ile_zmiesci(q: Przedmiot, ile: int) -> int:
	var poz := pozycja(q)
	if poz.x < 0:
		return ile
	var n := q.ilosc
	var k := ile
	while k > 0:
		q.ilosc = n + k
		var ok := moze(q, poz.x, poz.y, q.obrot, q)
		q.ilosc = n
		if ok:
			return k
		k -= 1
	return 0


func _init(sw := 4, sh := 4, red := 0.0) -> void:
	w = sw
	h = sh
	redukcja = red


func _zajete(ignore: Przedmiot = null) -> PackedByteArray:
	var occ := PackedByteArray()
	occ.resize(w * h)
	for e in items:
		var p: Przedmiot = e["p"]
		if p == ignore:
			continue
		for yy in p.wys():
			for xx in p.szer():
				var i: int = (e["y"] + yy) * w + e["x"] + xx
				if i >= 0 and i < occ.size():
					occ[i] = 1
	return occ


func moze(p: Przedmiot, x: int, y: int, rot: bool, ignore: Przedmiot = null) -> bool:
	var r := p.rozmiar()
	var pw := r.y if rot else r.x
	var ph := r.x if rot else r.y
	if x < 0 or y < 0 or x + pw > w or y + ph > h:
		return false
	var occ := _zajete(ignore)
	for yy in ph:
		for xx in pw:
			if occ[(y + yy) * w + x + xx] == 1 or not dostepna(x + xx, y + yy):
				return false
	return true


func poloz(p: Przedmiot, x: int, y: int, rot: bool) -> bool:
	if not moze(p, x, y, rot, p):
		return false
	usun(p)
	p.obrot = rot
	items.append({"p": p, "x": x, "y": y})
	zmieniona.emit()
	return true


func usun(p: Przedmiot) -> bool:
	for i in items.size():
		if items[i]["p"] == p:
			items.remove_at(i)
			zmieniona.emit()
			return true
	return false


func zawiera(p: Przedmiot) -> bool:
	for e in items:
		if e["p"] == p:
			return true
	return false


func pozycja(p: Przedmiot) -> Vector2i:
	for e in items:
		if e["p"] == p:
			return Vector2i(e["x"], e["y"])
	return Vector2i(-1, -1)


func przedmiot_w(x: int, y: int) -> Przedmiot:
	for e in items:
		var p: Przedmiot = e["p"]
		if x >= e["x"] and x < e["x"] + p.szer() and y >= e["y"] and y < e["y"] + p.wys():
			return p
	return null


func wolne_miejsce(p: Przedmiot) -> Dictionary:
	for rot in [p.obrot, not p.obrot]:
		for y in h:
			for x in w:
				if moze(p, x, y, rot, p):
					return {"x": x, "y": y, "rot": rot}
	return {}


## Dokłada przedmiot: najpierw uzupełnia stosy, potem szuka wolnego miejsca. Zwraca true, jeśli zmieścił się w całości.
func dodaj(p: Przedmiot) -> bool:
	if p.stos_max() > 1:
		for e in items:
			var q: Przedmiot = e["p"]
			if q.id == p.id and q.ilosc < q.stos_max():
				var ile: int = ile_zmiesci(q, min(p.ilosc, q.stos_max() - q.ilosc))
				if ile <= 0:
					continue
				q.ilosc += ile
				p.ilosc -= ile
				if p.ilosc <= 0:
					zmieniona.emit()
					return true
	var m := wolne_miejsce(p)
	if m.is_empty():
		if p.stos_max() > 1:
			zmieniona.emit()
		return false
	p.obrot = m["rot"]
	items.append({"p": p, "x": m["x"], "y": m["y"]})
	zmieniona.emit()
	return true


func masa() -> float:
	var s := 0.0
	for e in items:
		s += (e["p"] as Przedmiot).waga()
	return s


func masa_efektywna() -> float:
	return masa() * (1.0 - redukcja)


func policz(pid: String) -> int:
	var n := 0
	for e in items:
		if e["p"].id == pid:
			n += e["p"].ilosc
	return n


## Zabiera n sztuk przedmiotu (ze stosów). Zwraca ile faktycznie zabrano.
func zabierz(pid: String, n: int) -> int:
	var wziete := 0
	for e in items.duplicate():
		var p: Przedmiot = e["p"]
		if p.id != pid:
			continue
		var ile: int = min(n - wziete, p.ilosc)
		p.ilosc -= ile
		wziete += ile
		if p.ilosc <= 0:
			items.erase(e)
		if wziete >= n:
			break
	zmieniona.emit()
	return wziete


func wszystkie() -> Array:
	var out := []
	for e in items:
		out.append(e["p"])
	return out


func wartosc() -> int:
	var v := 0
	for e in items:
		v += (e["p"] as Przedmiot).wartosc()
	return v


func to_dict() -> Dictionary:
	var arr := []
	for e in items:
		arr.append({"p": (e["p"] as Przedmiot).to_dict(), "x": e["x"], "y": e["y"]})
	return {"w": w, "h": h, "r": redukcja, "i": arr}


static func from_dict(d: Dictionary) -> Siatka:
	var s := Siatka.new(int(d["w"]), int(d["h"]), float(d.get("r", 0.0)))
	var reszta := []
	for e in d.get("i", []):
		var p := Przedmiot.from_dict(e["p"])
		# stosy mogły zmienić rozmiar między wersjami: co nie pasuje, układamy na nowo
		if s.moze(p, int(e["x"]), int(e["y"]), p.obrot):
			s.items.append({"p": p, "x": int(e["x"]), "y": int(e["y"])})
		else:
			reszta.append(p)
	for p in reszta:
		if not s.dodaj(p):
			Przedmiot.przepelnienie.append(p)
	return s
