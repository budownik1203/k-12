extends Node
## Autoload "Sterowanie": zbiera ruch myszy niezależnie od tego, w którym viewporcie jest gracz,
## i definiuje akcje klawiszy w jednym miejscu.

var mysz := Vector2.ZERO
var blokada := false   # true, gdy otwarty jest ekran ekwipunku/menu
var menu_otwarte := false
var blokuj_tab_do := 0       # klatka, do której Tab nie otwiera ekwipunku (zamknięto nim inne okno)

const AKCJE := {
	"przod": [KEY_W], "tyl": [KEY_S], "lewo": [KEY_A], "prawo": [KEY_D],
	"bieg": [KEY_SHIFT], "kucanie": [KEY_CTRL, KEY_C], "wychyl_l": [KEY_Q], "wychyl_p": [KEY_E],
	"przeladuj": [KEY_R], "interakcja": [KEY_F], "latarka": [KEY_L], "ekwipunek": [KEY_TAB, KEY_I],
	"bron1": [KEY_1], "bron2": [KEY_2], "bron3": [KEY_3], "tryb": [KEY_B], "sprawdz": [KEY_T], "skok": [KEY_SPACE],
	"pasek1": [KEY_4], "pasek2": [KEY_5], "pasek3": [KEY_6], "pasek4": [KEY_7], "pasek5": [KEY_8], "pasek6": [KEY_9],
	"przerwij": [KEY_X], "wyrzuc": [KEY_DELETE, KEY_BACKSPACE], "zegarek": [KEY_H], "ogladaj": [KEY_J],
	"pauza": [KEY_ESCAPE], "pomoc": [KEY_F1], "napelnij": [KEY_G], "granat": [KEY_G], "wyjscia": [KEY_O], "ciagnij": [KEY_Z],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in AKCJE:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			for k in AKCJE[a]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(a, ev)
	for pair in [["strzal", MOUSE_BUTTON_LEFT], ["celuj", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var mb := InputEventMouseButton.new()
			mb.button_index = pair[1]
			InputMap.action_add_event(pair[0], mb)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not blokada:
		mysz += event.relative


func pobierz_mysz() -> Vector2:
	var m := mysz
	mysz = Vector2.ZERO
	return m


func przechwyc(tak: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if tak else Input.MOUSE_MODE_VISIBLE
	mysz = Vector2.ZERO


func blokada_menu() -> bool:
	return menu_otwarte
