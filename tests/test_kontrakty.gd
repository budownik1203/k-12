extends Node
## Zlecenia Pośrednika: oferty, przyjęcie, rozliczenie po rajdzie, dostawa ze skrytki.

func _ready() -> void:
	var bl := 0
	Gra.ZAPIS = "user://zapis_test_kontrakty.json"
	Gra.nowa_gra()
	var of: Array = Gra.kontrakty["oferty"]
	print("oferty: ", of.map(func(k): return k["opis"]))
	if of.size() != 3:
		bl += 1
	# eliminacja + wyjście + zwiad + dostawa – ręcznie
	Gra.kontrakty["oferty"] = [
		{"typ": "eliminacja", "cel": "szabrownik", "ile": 2, "postep": 0, "nagroda": 1000, "opis": "e"},
		{"typ": "wyjscie", "cel": "Brama na podwórze", "ile": 1, "postep": 0, "nagroda": 500, "opis": "w"},
		{"typ": "dostawa", "cel": "radio", "ile": 1, "postep": 0, "nagroda": 700, "opis": "d"}]
	Gra.przyjmij_kontrakt(0)
	Gra.przyjmij_kontrakt(0)
	if Gra.przyjmij_kontrakt(0):
		print("BŁĄD: trzecie zlecenie przyjęte")
		bl += 1
	var b0 := Gra.bony
	var w := {"przezyl": true, "wyjscie": "Brama na podwórze", "zabici": [{"frakcja": "szabrownik"}, {"frakcja": "szabrownik"}, {"frakcja": "wojskowy"}], "zdarzenia": []}
	Gra._rozlicz_kontrakty(w)
	print("bony +%d, aktywne %d, notki %s" % [Gra.bony - b0, Gra.kontrakty["aktywne"].size(), w["zdarzenia"]])
	if Gra.bony - b0 != 1500 or not Gra.kontrakty["aktywne"].is_empty():
		bl += 1
	var d := {"typ": "dostawa", "cel": "radio", "ile": 1, "postep": 0, "nagroda": 700, "opis": "d"}
	Gra.kontrakty["aktywne"] = [d]
	if Gra.oddaj_dostawe(d):
		print("BŁĄD: oddano bez radia")
		bl += 1
	Gra.skrytka.dodaj(Przedmiot.nowy("radio"))
	b0 = Gra.bony
	if not Gra.oddaj_dostawe(d) or Gra.bony - b0 != 700:
		print("BŁĄD: dostawa")
		bl += 1
	print("TEST KONTRAKTÓW: błędów %d" % bl)
	get_tree().quit(bl)
