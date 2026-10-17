class_name Przedmiot
extends RefCounted
## Egzemplarz przedmiotu w ekwipunku. Stan zależny od typu trzymany jest w "dane":
##   magazynek: {"amunicja": id, "naboje": int}
##   bron:      {"mag": Przedmiot|null, "komora": id amunicji|"", "wewn": int, "wewn_typ": id, "tryb": int}
##   med:       {"uzycia": int}
##   pojemnik:  {"siatka": Siatka}
##   pancerz:   {"wytrz": float}
##   klucz:     {"uzycia": int}

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
			p.dane = {"mag": null, "komora": "", "wewn": 0, "wewn_typ": "", "tryb": 0}
		"med":
			p.dane = {"uzycia": int(d["med"]["uzycia"])}
		"pojemnik":
			var pj: Dictionary = d["pojemnik"]
			p.dane = {"siatka": Siatka.new(int(pj["sw"]), int(pj["sh"]), float(pj["redukcja"]))}
		"pancerz":
			p.dane = {"wytrz": float(d["pancerz"]["wytrzymalosc"])}
		"klucz":
			p.dane = {"uzycia": int(d["klucz"]["uzycia"])}
	return p


func defn() -> Dictionary:
	return Dane.def(id)


func typ() -> String:
	return defn().get("typ", "")


func nazwa() -> String:
	return defn().get("nazwa", id)


func szer() -> int:
	return int(defn().get("h", 1)) if obrot else int(defn().get("w", 1))


func wys() -> int:
	return int(defn().get("w", 1)) if obrot else int(defn().get("h", 1))


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
	return p


func kopia() -> Przedmiot:
	return Przedmiot.from_dict(to_dict())
