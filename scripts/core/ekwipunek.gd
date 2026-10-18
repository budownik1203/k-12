class_name Ekwipunek
extends RefCounted
## Ekwipunek postaci: sloty na ciele + kieszenie. Kamizelka i plecak mają własne siatki.
## Waga efektywna liczy redukcję wagi pojemnika (mechanika z Project Zomboid).

signal zmieniony

const SLOTY := ["glowna", "pistolet", "helm", "pancerz", "kamizelka", "plecak", "util0", "util1", "util2", "util3"]
const NAZWY_SLOTOW := {
	"glowna": "Broń główna", "pistolet": "Pistolet", "helm": "Hełm",
	"pancerz": "Pancerz", "kamizelka": "Kamizelka", "plecak": "Plecak",
	"util0": "Pas", "util1": "Wyp. 2", "util2": "Wyp. 3", "util3": "Wyp. 4",
}
## Typy przedmiotów na sloty wyposażenia dodatkowego (latarka, mapa, kompas...).
const UTILITY := ["latarka", "mapa", "kompas"]
const MAX_UTILITY := 4

var sloty := {}
var kieszenie := Siatka.new(4, 1, 0.0)
var bezpieczny := Siatka.new(2, 2, 0.0)   # kontener bezpieczny: przeżywa śmierć


func _init() -> void:
	for s in SLOTY:
		sloty[s] = null


## Do którego slotu może trafić przedmiot (albo "" jeśli do żadnego).
static func slot_dla(p: Przedmiot) -> String:
	var d := p.defn()
	if d.get("typ", "") in UTILITY:
		return "util"
	match d.get("typ", ""):
		"bron":
			return d["bron"]["slot"]
		"pojemnik":
			return d["pojemnik"]["slot"]
		"pancerz":
			return d["pancerz"]["slot"]
	return ""


static func pasuje(slot: String, p: Przedmiot) -> bool:
	var s := slot_dla(p)
	if slot.begins_with("util"):
		return s == "util"
	if slot == "glowna" and s == "pistolet":
		return true  # pistolet też może być bronią główną
	return s == slot


## Liczba aktywnych slotów wyposażenia dodatkowego: jeden na pasie + tyle, ile daje kamizelka.
func liczba_utility() -> int:
	var n := 1
	if sloty["kamizelka"] != null:
		n += int(sloty["kamizelka"].defn()["pojemnik"].get("utility", 0))
	return mini(n, MAX_UTILITY)


func util_aktywny(slot: String) -> bool:
	return not slot.begins_with("util") or int(slot.substr(4)) < liczba_utility()


## Czy przedmiot o danym id jest w aktywnym slocie wyposażenia (np. latarka gotowa do użycia).
## Czy przedmiot o danym id jest gdziekolwiek w ekwipunku (siatki i sloty).
func ma_przedmiot(pid: String) -> bool:
	for s in siatki():
		for e in (s as Siatka).items:
			if (e["p"] as Przedmiot).id == pid:
				return true
	for k in sloty:
		if sloty[k] != null and (sloty[k] as Przedmiot).id == pid:
			return true
	return false


func ma_wyposazenie(pid: String) -> bool:
	for i in liczba_utility():
		var p: Przedmiot = sloty["util%d" % i]
		if p != null and p.id == pid:
			return true
	return false


func wolny_util() -> String:
	for i in liczba_utility():
		if sloty["util%d" % i] == null:
			return "util%d" % i
	return ""


func zaloz(slot: String, p: Przedmiot) -> bool:
	if slot == "util":
		slot = wolny_util()
		if slot == "":
			return false
	if sloty[slot] != null or not pasuje(slot, p) or not util_aktywny(slot):
		return false
	sloty[slot] = p
	zmieniony.emit()
	return true


func zdejmij(slot: String) -> Przedmiot:
	var p: Przedmiot = sloty[slot]
	sloty[slot] = null
	zmieniony.emit()
	return p


func siatka_kamizelki() -> Siatka:
	return sloty["kamizelka"].dane["siatka"] if sloty["kamizelka"] != null else null


func siatka_plecaka() -> Siatka:
	return sloty["plecak"].dane["siatka"] if sloty["plecak"] != null else null


## Siatki w kolejności dostępu: kieszenie i kamizelka są "pod ręką", plecak wolniej.
func siatki(tylko_szybkie := false) -> Array:
	var out := [kieszenie]
	var k := siatka_kamizelki()
	if k:
		out.insert(0, k)
	if not tylko_szybkie:
		var pl := siatka_plecaka()
		if pl:
			out.append(pl)
		out.append(bezpieczny)
	return out


func czy_szybka(s: Siatka) -> bool:
	return s == kieszenie or s == siatka_kamizelki()


func waga() -> float:
	var total := 0.0
	for s in SLOTY:
		var p: Przedmiot = sloty[s]
		if p == null:
			continue
		if p.typ() == "pojemnik":
			total += float(p.defn()["waga"]) + (p.dane["siatka"] as Siatka).masa_efektywna()
		else:
			total += p.waga()
	total += kieszenie.masa() + bezpieczny.masa()
	return total


## Dokłada przedmiot do ekwipunku. Magazynki, amunicja i leki najpierw do kamizelki.
func dodaj(p: Przedmiot) -> bool:
	if p.typ() in UTILITY and wolny_util() != "":
		return zaloz("util", p)
	var kolejnosc := siatki()
	kolejnosc.erase(bezpieczny)
	if p.typ() not in ["magazynek", "amunicja", "med"]:
		kolejnosc = [siatka_plecaka(), kieszenie, siatka_kamizelki()].filter(func(s): return s != null)
	for s in kolejnosc:
		if (s as Siatka).dodaj(p):
			zmieniony.emit()
			return true
	zmieniony.emit()
	return false


## Najlepszy magazynek do przeładowania: z nabojami, najpierw pod ręką.
func znajdz_magazynek(mag_ids: Array) -> Dictionary:
	var best := {}
	for s in siatki():
		for e in (s as Siatka).items:
			var p: Przedmiot = e["p"]
			if p.id in mag_ids and p.dane["naboje"] > 0:
				var szybki := czy_szybka(s)
				var score: int = p.dane["naboje"] + (1000 if szybki else 0)
				if best.is_empty() or score > best["score"]:
					best = {"p": p, "siatka": s, "szybki": szybki, "score": score}
	return best


func policz_amunicje(kaliber: String) -> int:
	var n := 0
	for s in siatki():
		for e in (s as Siatka).items:
			var p: Przedmiot = e["p"]
			if p.typ() == "amunicja" and p.defn()["amunicja"]["kaliber"] == kaliber:
				n += p.ilosc
	return n


## Zabiera do n naboi danego kalibru (preferując wskazany typ). Zwraca {"id": typ, "n": ile}.
func zabierz_amunicje(kaliber: String, n: int, preferowany := "") -> Dictionary:
	var kandydaci := []
	for s in siatki():
		for e in (s as Siatka).items:
			var p: Przedmiot = e["p"]
			if p.typ() == "amunicja" and p.defn()["amunicja"]["kaliber"] == kaliber:
				kandydaci.append([s, p])
	if kandydaci.is_empty():
		return {"id": "", "n": 0}
	var typ_id: String = kandydaci[0][1].id
	for k in kandydaci:
		if k[1].id == preferowany:
			typ_id = preferowany
	var wziete := 0
	for k in kandydaci:
		if k[1].id != typ_id:
			continue
		wziete += (k[0] as Siatka).zabierz(typ_id, n - wziete)
		if wziete >= n:
			break
	zmieniony.emit()
	return {"id": typ_id, "n": wziete}


func znajdz_med(efekty: Array) -> Dictionary:
	for s in siatki():
		for e in (s as Siatka).items:
			var p: Przedmiot = e["p"]
			if p.typ() == "med" and p.defn()["med"]["efekt"] in efekty:
				return {"p": p, "siatka": s, "szybki": czy_szybka(s)}
	return {}


func znajdz_id(id: String) -> Dictionary:
	for s in siatki():
		for e in (s as Siatka).items:
			var p: Przedmiot = e["p"]
			if p.id == id:
				return {"p": p, "siatka": s, "szybki": czy_szybka(s)}
	return {}


## Pasek szybkiego dostępu (klawisze 4-9): środki medyczne z kamizelki i kieszeni,
## jeden wpis na rodzaj, w stałej kolejności. Zmienia się razem z ekwipunkiem.
func pasek() -> Array:
	var kolejnosc := ["bandaz", "opatrunek", "apteczka", "szyna", "bolostop"]
	var znalezione := {}
	for s in siatki(true):
		for e in (s as Siatka).items:
			var p: Przedmiot = e["p"]
			if p.typ() != "med":
				continue
			if not znalezione.has(p.id):
				znalezione[p.id] = {"id": p.id, "p": p, "ilosc": 0}
			znalezione[p.id]["ilosc"] += 1
	var out := []
	for id in kolejnosc:
		if znalezione.has(id):
			out.append(znalezione[id])
			znalezione.erase(id)
	for id in znalezione:
		out.append(znalezione[id])
	return out.slice(0, 6)


func znajdz_klucz(otwiera: String) -> Dictionary:
	for s in siatki():
		for e in (s as Siatka).items:
			var p: Przedmiot = e["p"]
			if p.typ() == "klucz" and p.defn()["klucz"]["otwiera"] == otwiera:
				return {"p": p, "siatka": s}
	return {}


func usun_przedmiot(p: Przedmiot) -> bool:
	for s in siatki():
		if (s as Siatka).usun(p):
			zmieniony.emit()
			return true
	for sl in SLOTY:
		if sloty[sl] == p:
			sloty[sl] = null
			zmieniony.emit()
			return true
	return false


## Wszystkie przedmioty (sloty + zawartość siatek) – do raportów i wartości.
func wszystkie() -> Array:
	var out := []
	for sl in SLOTY:
		if sloty[sl] != null:
			out.append(sloty[sl])
	for s in siatki():
		out.append_array((s as Siatka).wszystkie())
	return out


func wartosc() -> int:
	var v := 0
	for sl in SLOTY:
		if sloty[sl] != null:
			v += (sloty[sl] as Przedmiot).wartosc()
	v += kieszenie.wartosc()
	return v


## Czyści ekwipunek po śmierci. Kontener bezpieczny zostaje.
func wyczysc() -> void:
	for s in SLOTY:
		sloty[s] = null
	kieszenie = Siatka.new(4, 1, 0.0)
	zmieniony.emit()


## Przedmioty, które przepadają przy śmierci (bez kontenera bezpiecznego).
func ryzykowane() -> Array:
	var out := []
	for sl in SLOTY:
		if sloty[sl] != null:
			out.append(sloty[sl])
			if sloty[sl].typ() == "pojemnik":
				out.append_array((sloty[sl].dane["siatka"] as Siatka).wszystkie())
	out.append_array(kieszenie.wszystkie())
	return out


func to_dict() -> Dictionary:
	var sl := {}
	for s in SLOTY:
		sl[s] = sloty[s].to_dict() if sloty[s] != null else null
	return {"sloty": sl, "kieszenie": kieszenie.to_dict(), "bezpieczny": bezpieczny.to_dict()}


static func from_dict(d: Dictionary) -> Ekwipunek:
	var e := Ekwipunek.new()
	for s in SLOTY:
		var v = d.get("sloty", {}).get(s)
		e.sloty[s] = Przedmiot.from_dict(v) if v != null else null
	if d.has("kieszenie"):
		e.kieszenie = Siatka.from_dict(d["kieszenie"])
	# latarka z dawnych zapisów leżała w siatce – przenosimy na pas
	if e.sloty["util0"] == null:
		var z := e.znajdz_id("latarka")
		if not z.is_empty():
			(z["siatka"] as Siatka).usun(z["p"])
			e.sloty["util0"] = z["p"]
	if d.has("bezpieczny"):
		e.bezpieczny = Siatka.from_dict(d["bezpieczny"])
	return e
