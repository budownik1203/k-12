extends Node
var bledy := 0


func _ok(w: bool, opis: String) -> void:
	print(("OK   " if w else "FAIL ") + opis)
	if not w:
		bledy += 1


func _scena(nazwa: String, limit := 600) -> bool:
	for i in limit:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path.ends_with(nazwa):
			for k in 30:
				await get_tree().process_frame
			return true
	return false


func _ready() -> void:
	Gra.ZAPIS = "user://zapis_test.json"
	Gra.nowa_gra()
	get_tree().change_scene_to_file("res://scenes/baza.tscn")
	_ok(await _scena("baza.tscn"), "baza wczytana")
	var bony0 := Gra.bony
	for runda in 2:
		Gra.rozpocznij_rajd()
		_ok(await _scena("rajd.tscn", 2000), "rajd %d wczytany" % runda)
		var rajd = get_tree().current_scene
		for i in 60:
			await get_tree().physics_frame
		_ok(Gra._ladowanie == null or not is_instance_valid(Gra._ladowanie) or Gra._ladowanie.is_queued_for_deletion(), "ekran przemarszu zgaszony")
		_ok(Gra.rajd_w_toku, "rajd w toku zapisany")
		if runda == 0:
			rajd._ewakuacja("Brama")
		else:
			rajd.gracz.cialo.obrazenia("glowa", 999.0, "pocisk")
		_ok(await _scena("raport.tscn", 1200), "raport po rajdzie %d" % runda)
		var r: Dictionary = Gra.ostatni_raport
		_ok(r.has("przezyl") and bool(r["przezyl"]) == (runda == 0), "raport: przeżył = %s" % r.get("przezyl"))
		_ok(not Gra.rajd_w_toku, "rajd zakończony w zapisie")
		Gra.idz_do_bazy()
		_ok(await _scena("baza.tscn"), "powrót do bazy %d" % runda)
	# zapis → odczyt
	var stan := JSON.stringify({"bony": Gra.bony, "rajdy": Gra.statystyki["rajdy"], "zgony": Gra.statystyki["zgony"]})
	Gra.zapisz()
	Gra.wczytaj()
	var stan2 := JSON.stringify({"bony": Gra.bony, "rajdy": Gra.statystyki["rajdy"], "zgony": Gra.statystyki["zgony"]})
	_ok(stan == stan2, "zapis i odczyt zgodne (%s)" % stan2)
	_ok(int(Gra.statystyki["rajdy"]) == 2 and int(Gra.statystyki["zgony"]) == 1, "statystyki: 2 rajdy, 1 zgon")
	print("PETLA: błędów ", bledy, " (bony %d → %d)" % [bony0, Gra.bony])
	get_tree().quit()
