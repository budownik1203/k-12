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
	for s in siatki_pod_reka():
		for e in (s as Siatka).items:
			if not odkryty(s, e):
				continue
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


## Rajd: plecak i kontener na plecach są niedostępne (przeładowanie, leki, podnoszenie, napełnianie
## sięgają tylko do kamizelki i kieszeni); po zdjęciu i rozłożeniu – tylko otwarte kieszenie.
var ograniczony := false
var plecak_rozlozony := false
var bezp_rozlozony := false
var zakryte := {}            # Siatka -> [Rect2i] zapiętych kieszeni


func siatki_pod_reka() -> Array:
	if not ograniczony:
		return siatki()
	var out := siatki(true)
	if plecak_rozlozony and siatka_plecaka() != null:
		out.append(siatka_plecaka())
	if bezp_rozlozony:
		out.append(bezpieczny)
	return out


## Czy przedmiot leży w otwartej części siatki (nie w zapiętej kieszeni).
func odkryty(s: Siatka, e: Dictionary) -> bool:
	if not zakryte.has(s):
		return true
	var p: Przedmiot = e["p"]
	var r := Rect2i(int(e["x"]), int(e["y"]), p.szer(), p.wys())
	for z in zakryte[s]:
		if (z as Rect2i).intersects(r):
			return false
	return true


## Dodaje do siatki z pominięciem zapiętych kieszeni (stosy i wolne miejsce).
func _dodaj_do(s: Siatka, p: Przedmiot) -> bool:
	if not zakryte.has(s):
		return s.dodaj(p)
	if p.stos_max() > 1:
		for e in s.items:
			var q: Przedmiot = e["p"]
			if q.id == p.id and q.ilosc < q.stos_max() and odkryty(s, e):
				var ile: int = mini(p.ilosc, q.stos_max() - q.ilosc)
				q.ilosc += ile
				p.ilosc -= ile
				if p.ilosc <= 0:
					s.zmieniona.emit()
					return true
	for rot in [p.obrot, not p.obrot]:
		var r := p.rozmiar()
		var pw: int = r.y if rot else r.x
		var ph: int = r.x if rot else r.y
		for y in s.h:
			for x in s.w:
				if not s.moze(p, x, y, rot):
					continue
				var ok := true
				for z in zakryte[s]:
					if (z as Rect2i).intersects(Rect2i(x, y, pw, ph)):
						ok = false
						break
				if ok:
					s.poloz(p, x, y, rot)
					return true
	return false


## Jak daleko sięga ręka: ładownica kamizelki pod ręką, kieszeń spodni wolniej, rozłożony plecak najwolniej.
func mnoznik_dostepu(s: Siatka) -> float:
	if s == siatka_kamizelki():
		return 1.0
	if s == kieszenie:
		return 1.35
	return 1.8


const METAL_LUZEM := ["bron", "magazynek", "amunicja", "dodatek", "klucz"]
const METAL_LUP := ["konserwa", "klucz_nastawny", "kombinerki", "kanister", "gasnica", "akumulator", "lornetka",
	"lampa_elektronowa", "maszyna_do_pisania", "telefon", "radio", "wodka", "spirytus", "przewody", "latarka"]
var _brzek := -1.0
var _brzek_kl := 0


## Hałas luźnego metalu: przedmioty w plecaku i kieszeniach obijają się o siebie (w ładownicach kamizelki
## siedzą ciasno). Stos amunicji luzem brzęczy mocniej niż pudełko.
func brzek() -> float:
	if _brzek >= 0.0 and Engine.get_process_frames() - _brzek_kl < 30:
		return _brzek
	_brzek_kl = Engine.get_process_frames()
	var b := 0.0
	for s in [kieszenie, siatka_plecaka()]:
		if s == null:
			continue
		for e in (s as Siatka).items:
			var p: Przedmiot = e["p"]
			if (p.typ() in METAL_LUZEM or p.id in METAL_LUP) and not p.dane.get("wyciszony", false):
				b += 0.55 if p.typ() == "amunicja" and p.ilosc <= 12 else 0.35
	_brzek = minf(6.0, b)
	return _brzek


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
	var kolejnosc := siatki_pod_reka()
	kolejnosc.erase(bezpieczny)
	if p.typ() not in ["magazynek", "amunicja", "med"]:
		kolejnosc = [siatka_plecaka(), kieszenie, siatka_kamizelki()].filter(func(s): return s != null and s in siatki_pod_reka())
	for s in kolejnosc:
		if _dodaj_do(s as Siatka, p):
			zmieniony.emit()
			return true
	zmieniony.emit()
	return false


## Najlepszy magazynek do przeładowania: z nabojami, najpierw pod ręką.
func znajdz_magazynek(mag_ids: Array) -> Dictionary:
	var best := {}
	for s in siatki_pod_reka():
		for e in (s as Siatka).items:
			if not odkryty(s, e):
				continue
			var p: Przedmiot = e["p"]
			if p.id in mag_ids and p.dane["naboje"] > 0:
				var szybki := czy_szybka(s)
				var mn := mnoznik_dostepu(s)
				# najpierw najbliżej ręki, potem najpełniejszy
				var score: int = p.dane["naboje"] + int((2.0 - mn) * 2000.0)
				if best.is_empty() or score > best["score"]:
					best = {"p": p, "siatka": s, "szybki": szybki, "score": score, "mnoznik": mn}
	return best


func policz_amunicje(kaliber: String) -> int:
	var n := 0
	for s in siatki_pod_reka():
		for e in (s as Siatka).items:
			if not odkryty(s, e):
				continue
			var p: Przedmiot = e["p"]
			if p.typ() == "amunicja" and p.defn()["amunicja"]["kaliber"] == kaliber:
				n += p.ilosc
	return n


## Zabiera do n naboi danego kalibru (preferując wskazany typ). Zwraca {"id": typ, "n": ile}.
func zabierz_amunicje(kaliber: String, n: int, preferowany := "") -> Dictionary:
	var kandydaci := []
	for s in siatki_pod_reka():
		for e in (s as Siatka).items:
			if not odkryty(s, e):
				continue
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
		var st: Przedmiot = k[1]
		var ile: int = mini(st.ilosc, n - wziete)
		st.ilosc -= ile
		wziete += ile
		if st.ilosc <= 0:
			(k[0] as Siatka).usun(st)
		if wziete >= n:
			break
	zmieniony.emit()
	return {"id": typ_id, "n": wziete}


func znajdz_med(efekty: Array) -> Dictionary:
	for s in siatki_pod_reka():
		for e in (s as Siatka).items:
			if not odkryty(s, e):
				continue
			var p: Przedmiot = e["p"]
			if p.typ() == "med" and p.defn()["med"]["efekt"] in efekty:
				return {"p": p, "siatka": s, "szybki": czy_szybka(s)}
	return {}


func znajdz_id(id: String) -> Dictionary:
	for s in siatki_pod_reka():
		for e in (s as Siatka).items:
			if not odkryty(s, e):
				continue
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
	for s in siatki_pod_reka():
		for e in (s as Siatka).items:
			if not odkryty(s, e):
				continue
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
