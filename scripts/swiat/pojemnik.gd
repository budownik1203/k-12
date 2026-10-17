class_name Pojemnik
extends StaticBody3D
## Kontener z łupem (szafka, skrzynia, biurko, zwłoki). Zawartość odkrywa się stopniowo przy przeszukiwaniu.

var nazwa := "Szafka"
var siatka: Siatka
var odkryte := 0             # ile pierwszych przedmiotów już widać
var czas_na_przedmiot := 0.7
var zamkniety_kluczem := ""  # id klucza wymagany do otwarcia (puste = otwarty)


func _init() -> void:
	collision_layer = Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_INTERAKCJE
	collision_mask = 0
	set_meta("interakcja", self)


## Wypełnia pojemnik losowo z tabeli lootu.
func wypelnij(tabela: String, losowan: int, rng: RandomNumberGenerator) -> void:
	for i in losowan:
		var pid := Dane.losuj_z_tabeli(tabela, rng)
		if pid == "":
			continue
		var p := Przedmiot.nowy(pid)
		var d := Dane.def(pid)
		if d["typ"] == "amunicja":
			p.ilosc = rng.randi_range(int(d["stos"]) / 4, int(d["stos"]) / 2)
		elif d["typ"] == "magazynek" and rng.randf() < 0.5:
			var am := Dane.amunicja_dla(d["magazynek"]["kaliber"])
			if not am.is_empty():
				p.dane["amunicja"] = am[0]
				p.dane["naboje"] = rng.randi_range(1, int(d["magazynek"]["pojemnosc"]))
		elif d["typ"] == "bron":
			var am2 := Dane.amunicja_dla(d["bron"]["kaliber"])
			if not am2.is_empty() and rng.randf() < 0.5:
				p = Gra.nowy_naladowany(pid, am2[0])
		siatka.dodaj(p)


func przeszukany() -> bool:
	return odkryte >= siatka.items.size()


func tekst_interakcji(_g) -> String:
	var stan := "" if odkryte == 0 else (" (przeszukane)" if przeszukany() else " (częściowo)")
	if siatka.items.is_empty() and odkryte > 0:
		stan = " (puste)"
	return "Przeszukaj: " + nazwa + stan


func interakcja(_g) -> void:
	get_tree().call_group("ui_rajdu", "otworz_pojemnik", self)
