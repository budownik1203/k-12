extends Node
## Pętla gry: baza → rajd (ekran przemarszu) → ewakuacja → raport → baza → rajd → zgon → raport → baza.
## Sprawdza zapis po każdym etapie. godot --path . res://tests/petla.tscn
var bledy := 0


func _ok(w: bool, opis: String) -> void:
	print(("OK   " if w else "FAIL ") + opis)
	if not w:
		bledy += 1


func _ready() -> void:
	# węzeł przeżywa zmiany scen (dziecko autoloadu)
	var n := Node.new()
	n.set_script(load("res://tests/petla_krok.gd"))
	Gra.add_child.call_deferred(n)
