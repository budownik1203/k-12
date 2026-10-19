class_name MebleKryjowki
extends RefCounted
## Katalog mebli do kryjówki gracza: cena u Kwatermistrza placówki, funkcja i przyrost skrytki.
## Funkcje: "skrytka" (powiększa skrytkę o „wiersze”), "warsztat" (montaż dodatków), "odpoczynek" (leczy po rajdzie),
## "kuchnia" (ciepły posiłek), "lampa" (światło), "" (wystrój).

const SZER_SKRYTKI := 20
const BAZA_SKRYTKI := 10      # wiersze bez żadnego mebla (pudła pod ścianą)
const MAX_SKRYTKI := 64

const KATALOG := {
	"szafka_metalowa": {"cena": 4500, "funkcja": "skrytka", "wiersze": 6, "opis": "Szafka ubraniowa na kłódkę. Skrytka +6 rzędów."},
	"regal_metalowy": {"cena": 7000, "funkcja": "skrytka", "wiersze": 8, "opis": "Regał z kątowników. Skrytka +8 rzędów."},
	"skrzynia_wojskowa": {"cena": 6000, "funkcja": "skrytka", "wiersze": 6, "opis": "Skrzynia po amunicji. Skrytka +6 rzędów."},
	"szafa": {"cena": 6500, "funkcja": "skrytka", "wiersze": 8, "opis": "Szafa z odzysku. Skrytka +8 rzędów."},
	"biurko": {"cena": 3500, "funkcja": "skrytka", "wiersze": 4, "opis": "Biurko z szufladami. Skrytka +4 rzędy."},
	"lodowka": {"cena": 4000, "funkcja": "skrytka", "wiersze": 4, "opis": "Lodówka Mińsk (nie chłodzi). Skrytka +4 rzędy."},
	"stol_warsztatowy": {"cena": 9000, "funkcja": "warsztat", "opis": "Stół roboczy z imadłem: montaż kolimatora, lunety i chwytu."},
	"lozko": {"cena": 5000, "funkcja": "odpoczynek", "opis": "Prycza. Sen po rajdzie leczy połowę ran (raz po każdym powrocie)."},
	"wersalka": {"cena": 4000, "funkcja": "odpoczynek", "opis": "Wersalka. Sen po rajdzie leczy połowę ran (raz po każdym powrocie)."},
	"kuchenka": {"cena": 3500, "funkcja": "kuchnia", "opis": "Kuchenka na butlę. Jedzenie na ciepło syci o połowę lepiej i nie suszy."},
	"zarowka": {"cena": 400, "funkcja": "lampa", "opis": "Goła żarówka pod sufitem."},
	"stol": {"cena": 1500, "funkcja": "", "opis": "Stół. Do kart, map i rozmyślań."},
	"krzeslo": {"cena": 500, "funkcja": "", "opis": "Krzesło. Jedno – gości nie przewidziano."},
	"dywan": {"cena": 1200, "funkcja": "", "opis": "Dywan. Tłumi kroki i wyrzuty sumienia."},
	"telewizor": {"cena": 2500, "funkcja": "", "opis": "Telewizor Rubin. Jeden kanał, i tak nic nie leci."},
	"worki_piasek": {"cena": 800, "funkcja": "", "opis": "Worki z piaskiem. Na wszelki wypadek."},
	"beczka": {"cena": 600, "funkcja": "", "opis": "Beczka. Pusta, sprawdzono."},
	"skrzynia": {"cena": 2500, "funkcja": "skrytka", "wiersze": 3, "opis": "Skrzynka z desek. Skrytka +3 rzędy."},
}

## Wyposażenie nowej gry: prycza i jedna szafka (skrytka 16 rzędów).
const START := [{"id": "lozko", "x": 1.2, "z": 1.0, "r": 1}, {"id": "szafka_metalowa", "x": 0.35, "z": 3.4, "r": 1}]
## Zapisy sprzed kryjówki: odtwarza dawny schron (skrytka 28 rzędów, stół roboczy, kącik).
const MIGRACJA := [{"id": "lozko", "x": 1.2, "z": 1.0, "r": 1}, {"id": "szafka_metalowa", "x": 0.35, "z": 3.0, "r": 1},
	{"id": "szafka_metalowa", "x": 0.35, "z": 3.6, "r": 1}, {"id": "szafka_metalowa", "x": 0.35, "z": 4.2, "r": 1},
	{"id": "stol_warsztatowy", "x": 7.6, "z": 1.6, "r": 3}, {"id": "stol", "x": 5.2, "z": 3.2, "r": 0},
	{"id": "krzeslo", "x": 4.4, "z": 3.2, "r": 1}, {"id": "dywan", "x": 5.2, "z": 3.4, "r": 0}]


static func nazwa(id: String) -> String:
	var m: Dictionary = Dane.meble.get(id, {})
	if m.has("nazwa"):
		return {"lozko": "Prycza", "szafka_metalowa": "Szafka metalowa", "regal_metalowy": "Regał metalowy", "zarowka": "Żarówka"}.get(id, String(m["nazwa"]))
	return id


static func rozmiar(id: String) -> Vector3:
	var m: Dictionary = Dane.meble.get(id, {})
	if m.has("rozmiar"):
		var r: Array = m["rozmiar"]
		return Vector3(float(r[0]), float(r[1]), float(r[2]))
	return Vector3(0.6, 0.6, 0.6)


## Wysokość skrytki (rzędy) z postawionych mebli.
static func wiersze_skrytki(kryjowka: Array) -> int:
	var w := BAZA_SKRYTKI
	for e in kryjowka:
		w += int(KATALOG.get(String(e["id"]), {}).get("wiersze", 0))
	return mini(w, MAX_SKRYTKI)


static func ma_funkcje(kryjowka: Array, f: String) -> bool:
	for e in kryjowka:
		if String(KATALOG.get(String(e["id"]), {}).get("funkcja", "")) == f:
			return true
	return false
