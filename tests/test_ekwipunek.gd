extends Node
## Test logiki ekwipunku: godot --headless --path . res://tests/test_ekwipunek.tscn

func _ready() -> void:
	Gra.ZAPIS = "user://zapis_test.json"
	var bledy := 0

	var s := Siatka.new(4, 2, 0.3)
	var kb := Przedmiot.nowy("kb47")
	bledy += _ok(s.dodaj(kb), "kb47 mieści się w 4x2")
	bledy += _ok(not s.dodaj(Przedmiot.nowy("bandaz")), "pełna siatka odrzuca")
	var a := Siatka.new(2, 2)
	bledy += _ok(a.dodaj(Przedmiot.nowy("a_9x18", 30)), "amunicja 30")
	bledy += _ok(a.dodaj(Przedmiot.nowy("a_9x18", 30)), "dokładanie do stosu")
	bledy += _ok(a.policz("a_9x18") == 60, "stos 50+10 = 60 (jest %d)" % a.policz("a_9x18"))
	bledy += _ok(a.zabierz("a_9x18", 55) == 55 and a.policz("a_9x18") == 5, "zabieranie ze stosów")
	var e := Ekwipunek.new()
	e.zaloz("plecak", Przedmiot.nowy("plecak_szturmowy"))
	e.siatka_plecaka().dodaj(Przedmiot.nowy("akumulator"))
	var w := e.waga()
	bledy += _ok(abs(w - (1.0 + 6.0 * 0.55)) < 0.01, "redukcja wagi plecaka 45%% (waga %.2f)" % w)
	var d := e.to_dict()
	var e2 := Ekwipunek.from_dict(JSON.parse_string(JSON.stringify(d)))
	bledy += _ok(abs(e2.waga() - w) < 0.01, "zapis i odczyt ekwipunku")
	var b: Przedmiot = Gra.nowy_naladowany("kb47", "a_762")
	bledy += _ok(b.etykieta() == "30", "broń naładowana 29+1 (jest %s)" % b.etykieta())
	var b2 := Przedmiot.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())))
	bledy += _ok(b2.dane["mag"] is Przedmiot and b2.dane["mag"].dane["naboje"] == 29, "zapis broni z magazynkiem")
	var c := Cialo.new()
	c.obrazenia("glowa", 40)
	bledy += _ok(c.martwy, "trafienie w głowę zabija")
	print("BLEDY: ", bledy)
	get_tree().quit(bledy)


func _ok(warunek: bool, opis: String) -> int:
	print(("OK   " if warunek else "FAIL ") + opis)
	return 0 if warunek else 1
