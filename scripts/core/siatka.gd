class_name Siatka
extends RefCounted
## Siatka pojemnika (plecak, kamizelka, kieszenie, skrytka, skrzynia).
## Każdy wpis to {"p": Przedmiot, "x": int, "y": int}.

signal zmieniona

var w: int
var h: int
var redukcja := 0.0
var items: Array = []


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
	var pw := int(p.defn().get("h", 1)) if rot else int(p.defn().get("w", 1))
	var ph := int(p.defn().get("w", 1)) if rot else int(p.defn().get("h", 1))
	if x < 0 or y < 0 or x + pw > w or y + ph > h:
		return false
	var occ := _zajete(ignore)
	for yy in ph:
		for xx in pw:
			if occ[(y + yy) * w + x + xx] == 1:
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
				var ile: int = min(p.ilosc, q.stos_max() - q.ilosc)
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
	for e in d.get("i", []):
		s.items.append({"p": Przedmiot.from_dict(e["p"]), "x": int(e["x"]), "y": int(e["y"])})
	return s
