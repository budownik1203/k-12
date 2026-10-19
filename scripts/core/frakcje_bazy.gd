class_name FrakcjeBazy
extends RefCounted
## Przedstawiciele frakcji w recepcji placówki: oferta z progami reputacji, zlecenia, wpływ reputacji na rajd.
## Reputacja -100..100. Zabicie członka frakcji: -5 u niej, +1 u pozostałych. Zlecenie frakcji: + „rep”.
## Reputacja ≥ PROG_ROZEJMU: oddziały frakcji w strefie nie strzelają pierwsze (rozejm do pierwszego strzału gracza).
## Reputacja ≤ PROG_WROGOSCI: przedstawiciel nie handluje.

const PROG_WROGOSCI := -30
const ZABICIE := -5
const ZABICIE_INNYCH := 1

const DANE := {
	"szabrownik": {
		"nazwa": "Szabrownicy", "przedstawiciel": "Zenek „Kulawy”", "opis": "łącznik Szabrowników",
		"prog_rozejmu": 35,
		"powitania": ["Towar z piwnic, ceny z księżyca. Bierzesz czy oglądasz?", "Nasi mówią, że strzelasz do swoich. Mam nadzieję, że kłamią.", "Wytrych to nie przestępstwo. To klucz uniwersalny."],
		"wrogie": ["Spadaj. Chłopaki pamiętają twoją gębę.", "Z mordercami nie handlujemy. Chyba że za podwójną cenę. Nie, jednak nie."],
		"oferta": [["wytrych", 1, 0], ["tasma", 1, 0], ["mapa", 1, 0], ["obrzyn", 1, 0], ["a_12", 20, 0], ["maska_gazowa", 1, 10],
			["zestaw_czyszczacy", 1, 10], ["klucz_piwnica", 1, 15], ["lornetka", 1, 25], ["granat_f1", 1, 35]],
		"zlecenia": [["eliminacja", "najemnik", 2, 6000, 12], ["eliminacja", "wojskowy", 2, 7000, 14], ["dostawa", "zegarek", 2, 7500, 10],
			["dostawa", "wodka", 2, 3500, 8], ["dostawa", "lancuszek", 1, 7000, 10]],
	},
	"najemnik": {
		"nazwa": "Najemnicy", "przedstawiciel": "kpt. Rys", "opis": "werbownik Najemników",
		"prog_rozejmu": 40,
		"powitania": ["Płacimy za wyniki, nie za starania.", "Kontrakt to kontrakt. Sentymenty są w innym okienku.", "Sprzęt mamy lepszy niż wojsko. I częściej czyszczony."],
		"wrogie": ["Masz na koncie naszych ludzi. Rozmowa skończona.", "Werbunek zamknięty. Dla ciebie na zawsze."],
		"oferta": [["plecak_szturmowy", 1, 0], ["latarka_taktyczna", 1, 0], ["opatrunek", 1, 0], ["chwyt", 1, 10], ["kamizelka_lbv", 1, 15],
			["kolimator", 1, 20], ["tlumik_9", 1, 25], ["a_762bp", 30, 30], ["tlumik_762", 1, 45]],
		"zlecenia": [["eliminacja", "szabrownik", 3, 4500, 10], ["eliminacja", "wojskowy", 2, 8000, 14], ["dostawa", "kanister", 1, 7500, 10],
			["dostawa", "akumulator", 1, 7000, 8], ["zwiad", "magazyn", 1, 3000, 6]],
	},
	"wojskowy": {
		"nazwa": "Wojsko", "przedstawiciel": "por. Wrona", "opis": "oficer łącznikowy Wojska",
		"prog_rozejmu": 50,
		"powitania": ["Przepustka, nazwisko, cel wizyty. Żartowałem. Czego?", "Regulamin przewiduje współpracę z cywilami. Niechętną.", "Sprzęt z magazynu jednostki. Pokwitowanie zbędne."],
		"wrogie": ["Jesteś na liście. Nie tej dobrej.", "Wynocha, zanim wezwę wartę."],
		"oferta": [["helm_wz67", 1, 0], ["kamizelka_kl2", 1, 0], ["mag_kb47", 1, 0], ["a_762", 60, 0], ["napiersnik", 1, 10], ["hamulec", 1, 15],
			["a_762bp", 30, 20], ["granat_f1", 1, 20], ["plecak_wojskowy", 1, 25], ["kamizelka_kl4", 1, 40], ["luneta", 1, 55]],
		"zlecenia": [["eliminacja", "szabrownik", 4, 5500, 12], ["eliminacja", "najemnik", 2, 8500, 14], ["dostawa", "teczka_akt", 1, 9500, 12],
			["dostawa", "radio", 2, 8000, 10], ["zwiad", "administracja", 1, 3000, 6]],
	},
}

const NAZWY_CELU := {"szabrownik": "szabrowników", "najemnik": "najemników", "wojskowy": "żołnierzy"}
const MIEJSCA := {"warsztat": "warsztatu", "piwnica": "piwnicy", "administracja": "biur administracji", "magazyn": "magazynu"}


static func rep(f: String) -> int:
	return int(Gra.reputacja.get(f, 0))


static func prog_rozejmu(f: String) -> int:
	return int(DANE.get(f, {}).get("prog_rozejmu", 999))


## Mnożnik ceny u przedstawiciela: do −15% przy pełnym zaufaniu, do +25% przy niechęci.
static func mnoznik_ceny(f: String) -> float:
	var r := rep(f)
	return 1.0 - 0.15 * clampf(r / 100.0, 0.0, 1.0) + 0.25 * clampf(-r / 60.0, 0.0, 1.0)


static func opis_rep(r: int) -> String:
	if r >= 60:
		return "zaufany"
	if r >= 30:
		return "przyjazny"
	if r >= 10:
		return "znany"
	if r > PROG_WROGOSCI:
		return "obojętny" if r >= -10 else "podejrzany"
	return "wrogi"


## Dwie oferty zleceń od frakcji (po każdym rajdzie nowe).
static func losuj_zlecenia(f: String, rng: RandomNumberGenerator) -> Array:
	var wzory: Array = (DANE[f]["zlecenia"] as Array).duplicate()
	var out := []
	for i in 2:
		if wzory.is_empty():
			break
		var w: Array = wzory.pop_at(rng.randi() % wzory.size())
		var k := {"typ": w[0], "cel": w[1], "ile": int(w[2]), "postep": 0, "nagroda": int(w[3]), "rep": int(w[4]), "od": f}
		match String(w[0]):
			"eliminacja":
				k["opis"] = "Zlikwiduj %d %s (liczy się po powrocie)" % [int(w[2]), NAZWY_CELU.get(w[1], w[1])]
			"dostawa":
				k["opis"] = "Dostarcz: %s ×%d" % [Dane.nazwa(w[1]), int(w[2])]
			"zwiad":
				k["opis"] = "Zwiad: wejdź do %s i wróć żywy" % MIEJSCA.get(w[1], w[1])
		out.append(k)
	return out
