class_name Cialo
extends RefCounted
## Model ciała: 5 części ze zdrowiem, krwawienia, złamania i ból.
## Śmierć: zniszczona głowa lub klatka albo wykrwawienie.

signal zmiana
signal smierc(przyczyna: String)
signal uraz(opis: String)

const MAX := {"glowa": 35.0, "klatka": 85.0, "brzuch": 70.0, "rece": 60.0, "nogi": 65.0}
const NAZWY := {"glowa": "Głowa", "klatka": "Klatka piersiowa", "brzuch": "Brzuch", "rece": "Ręce", "nogi": "Nogi"}
const KRWAWIENIE_HP := [0.0, 0.55, 1.7]   # hp/s dla: brak, lekkie, ciężkie

var hp := {}
var krwawienie := {}     # część -> 0/1/2
var zlamanie := {}       # część -> bool
var przeciwbol := 0.0    # sekundy działania środka przeciwbólowego
var martwy := false
var przyczyna := ""


func _init(stan := {}) -> void:
	for c in MAX:
		hp[c] = float(stan.get(c, MAX[c]))
		krwawienie[c] = 0
		zlamanie[c] = false


func stan_do_zapisu() -> Dictionary:
	var d := {}
	for c in MAX:
		if hp[c] < MAX[c]:
			d[c] = maxf(hp[c], 1.0)
	return d


func procent() -> float:
	var s := 0.0
	var m := 0.0
	for c in MAX:
		s += hp[c]
		m += MAX[c]
	return s / m


## Zadaje obrażenia części ciała. zrodlo: opis do raportu ("pocisk", "srut", "fauna"...).
func obrazenia(czesc: String, ile: float, zrodlo := "pocisk") -> void:
	if martwy or ile <= 0.0:
		return
	if hp[czesc] <= 0.0 and czesc not in ["glowa", "klatka"]:
		# zniszczona kończyna: obrażenia rozchodzą się na tułów
		hp["klatka"] -= ile * 0.45
		hp["brzuch"] = maxf(0.0, hp["brzuch"] - ile * 0.25)
	else:
		hp[czesc] = maxf(0.0, hp[czesc] - ile)
	# krwawienia
	var r := randf()
	if ile >= 28.0 and r < 0.22:
		_krwawienie(czesc, 2)
	elif ile >= 8.0 and r < 0.4:
		_krwawienie(czesc, 1)
	# złamania
	if czesc in ["rece", "nogi"] and not zlamanie[czesc] and ile >= 18.0 and randf() < 0.22:
		zlamanie[czesc] = true
		uraz.emit("Złamanie: " + NAZWY[czesc].to_lower())
	_sprawdz_smierc(zrodlo)
	zmiana.emit()


func upadek(wysokosc: float) -> void:
	if wysokosc < 2.4:
		return
	var dmg := (wysokosc - 2.2) * 14.0
	obrazenia("nogi", dmg, "upadek")
	if randf() < 0.5:
		zlamanie["nogi"] = true
		uraz.emit("Złamanie: nogi")


func _krwawienie(czesc: String, poziom: int) -> void:
	if krwawienie[czesc] < poziom:
		krwawienie[czesc] = poziom
		uraz.emit(("Ciężkie" if poziom == 2 else "Lekkie") + " krwawienie: " + NAZWY[czesc].to_lower())


func _sprawdz_smierc(zrodlo: String) -> void:
	if martwy:
		return
	if hp["glowa"] <= 0.0 or hp["klatka"] <= 0.0:
		martwy = true
		przyczyna = zrodlo
		smierc.emit(zrodlo)


func tick(delta: float) -> void:
	if martwy:
		return
	var zm := false
	for c in MAX:
		var k: int = krwawienie[c]
		if k > 0:
			var d: float = KRWAWIENIE_HP[k] * delta
			if hp[c] > 0.0:
				hp[c] = maxf(0.0, hp[c] - d)
			else:
				hp["klatka"] -= d * 0.8
			zm = true
	if przeciwbol > 0.0:
		przeciwbol = maxf(0.0, przeciwbol - delta)
	if zm:
		_sprawdz_smierc("wykrwawienie")
		zmiana.emit()


func krwawi() -> int:
	var m := 0
	for c in MAX:
		m = maxf(m, krwawienie[c])
	return m


func bol() -> bool:
	if przeciwbol > 0.0:
		return false
	for c in MAX:
		if zlamanie[c] or krwawienie[c] == 2 or hp[c] < MAX[c] * 0.45:
			return true
	return false


## Mnożnik prędkości ruchu wynikający z nóg.
func mnoznik_ruchu() -> float:
	var m := 1.0
	if hp["nogi"] <= 0.0:
		m *= 0.55
	elif zlamanie["nogi"] and przeciwbol <= 0.0:
		m *= 0.7
	return m


func moze_biegac() -> bool:
	return not zlamanie["nogi"] and hp["nogi"] > 0.0


## Mnożnik rozrzutu/kołysania broni wynikający z rąk i bólu.
func mnoznik_celnosci() -> float:
	var m := 1.0
	if hp["rece"] <= 0.0:
		m *= 2.0
	elif zlamanie["rece"] and przeciwbol <= 0.0:
		m *= 1.5
	if bol():
		m *= 1.35
	return m


## Leczenie przedmiotem. Zwraca opis lub "" jeśli nie było czego leczyć.
func lecz(efekt: String, dane: Dictionary, med: Przedmiot) -> String:
	match efekt:
		"krwawienie_lekkie":
			for c in MAX:
				if krwawienie[c] == 1:
					krwawienie[c] = 0
					zmiana.emit()
					return "Zatamowano lekkie krwawienie (%s)" % NAZWY[c].to_lower()
		"krwawienie_ciezkie":
			for poziom in [2, 1]:
				for c in MAX:
					if krwawienie[c] == poziom:
						krwawienie[c] = 0
						zmiana.emit()
						return "Zatamowano krwawienie (%s)" % NAZWY[c].to_lower()
		"zlamanie":
			for c in ["nogi", "rece"]:
				if zlamanie[c]:
					zlamanie[c] = false
					zmiana.emit()
					return "Unieruchomiono złamanie (%s)" % NAZWY[c].to_lower()
		"bol":
			przeciwbol = float(dane.get("trwanie", 180))
			med.dane["uzycia"] -= 1
			zmiana.emit()
			return "Środek przeciwbólowy działa"
		"leczenie":
			# najpierw krwawienia lekkie, potem najbardziej uszkodzona część
			for c in MAX:
				if krwawienie[c] == 1 and med.dane["uzycia"] >= 5:
					krwawienie[c] = 0
					med.dane["uzycia"] -= 5
					zmiana.emit()
					return "Opatrzono lekkie krwawienie"
			var najgorsza := ""
			var brak := 0.0
			for c in MAX:
				var b: float = MAX[c] - hp[c]
				if hp[c] > 0.0 and b > brak:
					brak = b
					najgorsza = c
			if najgorsza == "":
				return ""
			var ile: float = minf(minf(float(dane.get("na_raz", 20)), brak), float(med.dane["uzycia"]))
			hp[najgorsza] += ile
			med.dane["uzycia"] -= int(ceil(ile))
			zmiana.emit()
			return "Wyleczono %d HP (%s)" % [int(ile), NAZWY[najgorsza].to_lower()]
	return ""


## Czy dany efekt ma teraz sens (żeby nie marnować leków).
func potrzebuje(efekt: String) -> bool:
	match efekt:
		"krwawienie_lekkie":
			for c in MAX:
				if krwawienie[c] == 1:
					return true
		"krwawienie_ciezkie":
			return krwawi() > 0
		"zlamanie":
			return zlamanie["nogi"] or zlamanie["rece"]
		"bol":
			return bol() or przeciwbol < 20.0
		"leczenie":
			for c in MAX:
				if hp[c] > 0.0 and hp[c] < MAX[c] - 1.0:
					return true
			return krwawi() == 1
	return false
