extends Node
## Ładuje wszystkie skrypty projektu, żeby wyłapać błędy parsowania: godot --headless --path . res://tests/sprawdz.tscn

func _ready() -> void:
	var n := 0
	for f in _pliki("res://scripts"):
		var s = load(f)
		n += 1
	print("SPRAWDZONO SKRYPTOW: ", n)
	get_tree().quit()


func _pliki(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_pliki(dir.path_join(sub)))
	return out
