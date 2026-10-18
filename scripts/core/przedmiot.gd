class_name Przedmiot
extends RefCounted
## Egzemplarz przedmiotu w ekwipunku. Stan zależny od typu trzymany jest w "dane":
##   magazynek: {"amunicja": id, "naboje": int}
##   bron:      {"mag": Przedmiot|null, "komora": id amunicji|"", "wewn": int, "wewn_typ": id, "tryb": int}
##   med:       {"uzycia": int}
##   pojemnik:  {"siatka": Siatka}
##   pancerz:   {"wytrz": float}
##   klucz:     {"uzycia": int}

## Przedmioty, które po wczytaniu starego zapisu nie zmieściły się w pojemniku (trafią do skrytki).
static var przepelnienie: Array = []

var id: String
var ilosc := 1
var obrot := false
var dane := {}


static func nowy(pid: String, ile := 1) -> Przedmiot:
	var p := Przedmiot.new()
	p.id = pid
	p.ilosc = ile
	var d := p.defn()
	match d.get("typ", ""):
		"magazynek":
			p.dane = {"amunicja": "", "naboje": 0}
		"bron":
			p.dane = {"mag": null, "komora": "", "wewn": 0, "wewn_typ": "", "tryb": 0,
				"dod_wylot": null, "dod_celownik": null, "dod_chwyt": null, "dod_latarka": null}
		"med":
			p.dane = {"uzycia": int(d["med"]["uzycia"])}
		"pojemnik":
			p.dane = {"siatka": Siatka.z_definicji(d["pojemnik"])}
		"pancerz":
			p.dane = {"wytrz": float(d["pancerz"]["wytrzymalosc"])}
		"klucz":
			p.dane = {"uzycia": int(d["klucz"]["uzycia"])}
	return p


const SLOTY_DODATKOW := ["wylot", "celownik", "chwyt", "latarka"]


## Dodatki zamontowane na broni.
func dodatki() -> Array:
	var out := []
	for s in SLOTY_DODATKOW:
		var d = dane.get("dod_" + s)
		if d != null:
			out.append(d)
	return out


func dodatek(slot: String) -> Przedmiot:
	return dane.get("dod_" + slot)


## Iloczyn mnożników z dodatków (np. "odrzut", "halas", "rozrzut_ads"); brak = 1.
func mod(nazwa: String) -> float:
	var m := 1.0
	for d in dodatki():
		m *= float((d as Przedmiot).defn()["dodatek"].get(nazwa, 1.0))
	return m


func defn() -> Dictionary:
	return Dane.def(id)


func typ() -> String:
	return defn().get("typ", "")


func nazwa() -> String:
	if nieznany():
		return nazwa_ogolna()
	return defn().get("nazwa", id)


## Znaleziony w strefie i jeszcze nieobejrzany: znasz tylko kształt i ciężar.
func nieznany() -> bool:
	return bool(dane.get("nieznany", false))


const MIEKKIE := ["papierosy", "teczka_akt", "kartka_mieso", "mapa", "maska_gazowa", "kaseta", "ikona"]


func nazwa_ogolna() -> String:
	if id in MIEKKIE:
		return "Zawiniątko" if waga() < 0.5 else "Pakunek"
	if waga() > 3.0:
		return "Ciężki metalowy przedmiot"
	return "Metalowy drobiazg" if szer() * wys() <= 1 else "Metalowy przedmiot"


## Rozmiar bez obrotu. Stosy amunicji rosną z liczbą sztuk: garść 1x1, potem pudełko.
## "rozmiary_stosu": [[do_ilu, w, h, przyrostek_ikony], ...]
func rozmiar() -> Vector2i:
	var d := defn()
	if d.has("rozmiary_stosu"):
		for r in d["rozmiary_stosu"]:
			if ilosc <= int(r[0]):
				return Vector2i(int(r[1]), int(r[2]))
	return Vector2i(int(d.get("w", 1)), int(d.get("h", 1)))


func ikona_id() -> String:
	var d := defn()
	if d.has("rozmiary_stosu"):
		for r in d["rozmiary_stosu"]:
			if ilosc <= int(r[0]):
				return id + String(r[3])
	return id


func szer() -> int:
	var r := rozmiar()
	return r.y if obrot else r.x


func wys() -> int:
	var r := rozmiar()
	return r.x if obrot else r.y


func stos_max() -> int:
	return int(defn().get("stos", 1))


func waga() -> float:
	var d := defn()
	var w := float(d.get("waga", 0.0)) * ilosc
	match typ():
		"magazynek":
			if dane["naboje"] > 0:
				w += Dane.def(dane["amunicja"]).get("waga", 0.0) * dane["naboje"]
		"bron":
			if dane["mag"] != null:
				w += (dane["mag"] as Przedmiot).waga()
			for dd in dodatki():
				w += (dd as Przedmiot).waga()
			if dane["wewn"] > 0:
				w += Dane.def(dane["wewn_typ"]).get("waga", 0.0) * dane["wewn"]
		"pojemnik":
			w += (dane["siatka"] as Siatka).masa()
	return w


## Cena przy sprzedaży (zawartość liczy się osobno).
func wartosc() -> int:
	var d := defn()
	var v := float(d.get("cena", 0)) * ilosc
	match typ():
		"magazynek":
			if dane["naboje"] > 0:
				v += Dane.def(dane["amunicja"]).get("cena", 0) * dane["naboje"]
		"bron":
			if dane["mag"] != null:
				v += (dane["mag"] as Przedmiot).wartosc()
			for dd in dodatki():
				v += (dd as Przedmiot).wartosc()
		"pancerz":
			v *= clamp(dane["wytrz"] / float(d["pancerz"]["wytrzymalosc"]), 0.2, 1.0)
		"med":
			v *= float(dane["uzycia"]) / float(d["med"]["uzycia"])
		"pojemnik":
			for e in (dane["siatka"] as Siatka).items:
				v += (e["p"] as Przedmiot).wartosc()
	return int(v)


## Krótki napis na ikonie (liczba naboi, stos, zużycie).
func etykieta() -> String:
	match typ():
		"amunicja":
			return str(ilosc)
		"magazynek":
			if not bool(dane.get("sprawdzony", true)):
				# nieprzeliczony: tylko na wagę i oko
				var f := float(dane["naboje"]) / maxf(1.0, float(defn()["magazynek"]["pojemnosc"]))
				return "pełny?" if f >= 0.9 else ("~½+" if f >= 0.5 else ("mało" if f > 0.15 else ("resztki" if f > 0.0 else "pusty?")))
			return "%d/%d" % [dane["naboje"], defn()["magazynek"]["pojemnosc"]]
		"bron":
			var n := 0
			if dane["mag"] != null:
				n = dane["mag"].dane["naboje"]
			n += dane["wewn"] + (1 if dane["komora"] != "" else 0)
			return str(n)
		"med":
			var u := int(defn()["med"]["uzycia"])
			return "" if u <= 1 else "%d/%d" % [dane["uzycia"], u]
		"pancerz":
			return "%d/%d" % [int(dane["wytrz"]), int(defn()["pancerz"]["wytrzymalosc"])]
		"klucz":
			return "%dx" % dane["uzycia"]
	return ""


func to_dict() -> Dictionary:
	var out := {"id": id, "n": ilosc, "r": obrot}
	var d := {}
	for k in dane:
		var v = dane[k]
		if v is Przedmiot:
			d[k] = {"_p": v.to_dict()}
		elif v is Siatka:
			d[k] = {"_s": v.to_dict()}
		else:
			d[k] = v
	out["d"] = d
	return out


static func from_dict(dd: Dictionary) -> Przedmiot:
	var p := Przedmiot.nowy(dd["id"], int(dd.get("n", 1)))
	p.obrot = bool(dd.get("r", false))
	var d: Dictionary = dd.get("d", {})
	for k in d:
		var v = d[k]
		if v is Dictionary and v.has("_p"):
			p.dane[k] = Przedmiot.from_dict(v["_p"])
		elif v is Dictionary and v.has("_s"):
			p.dane[k] = Siatka.from_dict(v["_s"])
		elif v == null:
			p.dane[k] = null
		elif v is float and (k in ["naboje", "wewn", "tryb", "uzycia"]):
			p.dane[k] = int(v)
		else:
			p.dane[k] = v
	# pojemnik: siatka zawsze według aktualnej definicji (rozmiar, przegródki); stare zapisy przenosimy
	if p.typ() == "pojemnik" and p.dane.get("siatka") is Siatka:
		var stara: Siatka = p.dane["siatka"]
		var nowa := Siatka.z_definicji(p.defn()["pojemnik"])
		if stara.w != nowa.w or stara.h != nowa.h or not nowa.maska.is_empty():
			var reszta := []
			for e in stara.items:
				var q: Przedmiot = e["p"]
				if nowa.moze(q, e["x"], e["y"], q.obrot):
					nowa.items.append(e)
				else:
					reszta.append(q)
			for q in reszta:
				if not nowa.dodaj(q):
					przepelnienie.append(q)
			p.dane["siatka"] = nowa
	return p


func kopia() -> Przedmiot:
	return Przedmiot.from_dict(to_dict())
