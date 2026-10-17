class_name Ewakuacja
extends Area3D
## Strefa wyjścia z rajdu. Wejście uruchamia odliczanie; wyjście ze strefy je przerywa.
## Typy: "glowne" (zawsze), "klucz" (wymaga otwarcia drzwi kluczem), "czasowe" (aktywne w oknie czasowym).

signal ewakuowano(nazwa: String)

var nazwa := "Wyjście"
var typ := "glowne"
var czas_odliczania := 8.0
var wymagany_klucz := ""
var otwarte := true
var okno_od := 0.0          # dla czasowego: sekundy rajdu
var okno_do := 0.0
var rajd_czas := 0.0         # ustawiane przez rajd
var odliczanie := -1.0
var _gracz: Node3D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = Balistyka.WARSTWA_POSTACIE
	monitoring = true
	body_entered.connect(_wejscie)
	body_exited.connect(_wyjscie)


func _wejscie(b: Node) -> void:
	if b is Gracz:
		_gracz = b


func _wyjscie(b: Node) -> void:
	if b == _gracz:
		_gracz = null
		odliczanie = -1.0


func aktywne() -> bool:
	if not otwarte:
		return false
	if typ == "czasowe":
		return rajd_czas >= okno_od and rajd_czas <= okno_do
	return true


func opis_stanu() -> String:
	match typ:
		"klucz":
			return "zamknięte (klucz)" if not otwarte else "otwarte"
		"czasowe":
			if rajd_czas < okno_od:
				return "za %s" % _mmss(okno_od - rajd_czas)
			if rajd_czas <= okno_do:
				return "aktywne jeszcze %s" % _mmss(okno_do - rajd_czas)
			return "zamknięte"
	return "dostępne"


func _mmss(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


func _physics_process(delta: float) -> void:
	if _gracz == null or not aktywne() or not is_instance_valid(_gracz) or _gracz.cialo.martwy:
		odliczanie = -1.0
		return
	if odliczanie < 0.0:
		odliczanie = czas_odliczania
	odliczanie -= delta
	if odliczanie <= 0.0:
		odliczanie = -1.0
		set_physics_process(false)
		ewakuowano.emit(nazwa)


## Drzwi zamknięte na klucz, które otwierają wyjście "klucz".
class DrzwiNaKlucz:
	extends StaticBody3D
	var wyjscie: Ewakuacja
	var klucz := ""

	func _init() -> void:
		collision_layer = Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_INTERAKCJE
		set_meta("interakcja", self)

	func tekst_interakcji(_g) -> String:
		return "Otwórz kluczem: " + Dane.nazwa(klucz) if not wyjscie.otwarte else "Otwarte"

	func interakcja(g) -> void:
		if wyjscie.otwarte:
			return
		var z: Dictionary = g.ekw.znajdz_klucz(wyjscie.wymagany_klucz)
		if z.is_empty():
			g.komunikat.emit("Zamknięte. Potrzebny: " + Dane.nazwa(klucz))
			Dzwiek.graj("klik", -4.0, 0.6)
			return
		var p: Przedmiot = z["p"]
		p.dane["uzycia"] -= 1
		if p.dane["uzycia"] <= 0:
			(z["siatka"] as Siatka).usun(p)
			g.komunikat.emit("Klucz się złamał w zamku. Przynajmniej drzwi są otwarte.")
		wyjscie.otwarte = true
		g.komunikat.emit("Drzwi otwarte: " + wyjscie.nazwa)
		Dzwiek.graj_3d("drzwi", global_position, get_parent(), 0.0)
		# drzwi znikają z drogi
		var t := create_tween()
		t.tween_property(self, "position:y", position.y - 2.2, 1.0)
