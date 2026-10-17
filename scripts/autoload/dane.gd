extends Node
## Autoload "Dane": definicje przedmiotów, tabele lootu i frakcje wczytane z assets/dane/przedmioty.json.

var przedmioty := {}   # id -> Dictionary
var tabele := {}       # nazwa -> Array [[id, waga], ...]
var frakcje := {}
var _ikony := {}


func _ready() -> void:
	var f := FileAccess.open("res://assets/dane/przedmioty.json", FileAccess.READ)
	var js: Dictionary = JSON.parse_string(f.get_as_text())
	for p in js["przedmioty"]:
		przedmioty[p["id"]] = p
	tabele = js["tabele_lootu"]
	frakcje = js["frakcje"]


func def(id: String) -> Dictionary:
	return przedmioty.get(id, {})


func istnieje(id: String) -> bool:
	return przedmioty.has(id)


func nazwa(id: String) -> String:
	return def(id).get("nazwa", id)


func ikona(id: String) -> Texture2D:
	if not _ikony.has(id):
		var path := "res://assets/ikony/%s.png" % id
		_ikony[id] = load(path) if ResourceLoader.exists(path) else null
	return _ikony[id]


func losuj(tabela: Array, rng: RandomNumberGenerator = null) -> String:
	var suma := 0.0
	for e in tabela:
		suma += float(e[1])
	var r := (rng.randf() if rng else randf()) * suma
	for e in tabela:
		r -= float(e[1])
		if r <= 0.0:
			return "" if e[0] == "nic" else String(e[0])
	return ""


func losuj_z_tabeli(nazwa_tabeli: String, rng: RandomNumberGenerator = null) -> String:
	return losuj(tabele.get(nazwa_tabeli, []), rng)


## Amunicja pasująca do kalibru (pierwsza znaleziona, do zestawów startowych).
func amunicja_dla(kaliber: String) -> Array:
	var out := []
	for id in przedmioty:
		var d: Dictionary = przedmioty[id]
		if d["typ"] == "amunicja" and d["amunicja"]["kaliber"] == kaliber:
			out.append(id)
	return out
