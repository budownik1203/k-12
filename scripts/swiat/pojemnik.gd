class_name Pojemnik
extends StaticBody3D
## Kontener z łupem (szafka, skrzynia, biurko, zwłoki). Zawartość odkrywa się stopniowo przy przeszukiwaniu.

var nazwa := "Szafka"
var siatka: Siatka
var odkryte := 0             # ile pierwszych przedmiotów już widać
var czas_na_przedmiot := 0.7
var zamkniety_kluczem := ""  # id klucza wymagany do otwarcia (puste = otwarty)
var mebel_id := ""
var niski := false           # niski mebel / zwłoki: przyklęk przy przeszukiwaniu
var mebel := {}              # ModeleMebli: ruchome części (drzwi, szuflady, wieko)
var otwarty_mebel := false
var _start: Array = []
var _tw: Tween
var wys_wnetrza := -1.0
var _kurz_byl := false      # bez modelu ruchomego: wysokość punktu, na który się patrzy


func _init() -> void:
	collision_layer = Balistyka.WARSTWA_SWIAT | Balistyka.WARSTWA_INTERAKCJE
	collision_mask = 0
	set_meta("interakcja", self)


## Wypełnia pojemnik losowo z tabeli lootu.
func wypelnij(tabela: String, losowan: int, rng: RandomNumberGenerator) -> void:
	for i in losowan:
		var pid := Dane.losuj_z_tabeli(tabela, rng)
		if pid == "":
			continue
		var p := Przedmiot.nowy(pid)
		var d := Dane.def(pid)
		if d["typ"] == "amunicja":
			p.ilosc = rng.randi_range(int(d["stos"]) / 4, int(d["stos"]) / 2)
		elif d["typ"] == "magazynek" and rng.randf() < 0.5:
			var am := Dane.amunicja_dla(d["magazynek"]["kaliber"])
			if not am.is_empty():
				p.dane["amunicja"] = am[0]
				p.dane["naboje"] = rng.randi_range(1, int(d["magazynek"]["pojemnosc"]))
		elif d["typ"] == "bron":
			var am2 := Dane.amunicja_dla(d["bron"]["kaliber"])
			if not am2.is_empty() and rng.randf() < 0.5:
				p = Gra.nowy_naladowany(pid, am2[0])
		if d["typ"] == "magazynek":
			p.dane["sprawdzony"] = false
		if d["typ"] == "med" and rng.randf() < 0.3:
			p.dane["przeterminowany"] = true
			p.dane["rok"] = rng.randi_range(1974, 1986)
		if d["typ"] == "bron":
			p.dane["stan"] = rng.randf_range(30.0, 85.0)
		if d["typ"] == "lup" and rng.randf() < 0.75:
			p.dane["nieznany"] = true     # trzeba obejrzeć, żeby wiedzieć, co to
		siatka.dodaj(p)


## Części pojemnika przeszukiwane po kolei (zwłoki: kieszenie kurtki, spodni, ładownice, plecak;
## mebel: jedna). {"nazwa", "siatka", "odkryte", "zdejmowane": przedmioty na ciele – zdjęcie trwa}
var czesci: Array = []
var _szuk_t := 0.0


func lista_czesci() -> Array:
	if czesci.is_empty() and siatka:
		czesci = [{"nazwa": "", "siatka": siatka, "odkryte": odkryte, "zdejmowane": false}]
	for c in czesci:
		if not c.has("znane"):
			# znane przedmioty (zbiór): wyjęcie jednego nie odsłania następnego bez szukania
			var zn := {}
			var items: Array = (c["siatka"] as Siatka).items
			for i in mini(int(c.get("odkryte", 0)), items.size()):
				zn[items[i]["p"]] = true
			c["znane"] = zn
	return czesci


func _nieznany(c: Dictionary) -> Przedmiot:
	var zn: Dictionary = c["znane"]
	for e in (c["siatka"] as Siatka).items:
		if not zn.has(e["p"]):
			return e["p"]
	return null


func przeszukany() -> bool:
	for c in lista_czesci():
		if _nieznany(c) != null:
			return false
	return true


func pusty() -> bool:
	for c in lista_czesci():
		if not (c["siatka"] as Siatka).items.is_empty():
			return false
	return true


func zaczety() -> bool:
	for c in lista_czesci():
		if not (c["znane"] as Dictionary).is_empty():
			return true
	return odkryte > 0


## Bieżąca przeszukiwana część (indeks) albo -1.
func czesc_szukana() -> int:
	var cz := lista_czesci()
	for i in cz.size():
		if _nieznany(cz[i]) != null:
			return i
	return -1


## Czas wyszukania przedmiotu: drobiazg szybko, karabin dłużej; po ciemku dwa razy wolniej.
func czas_szukania(p: Przedmiot, swiatlo: float) -> float:
	var komorki := p.szer() * p.wys()
	var t := czas_na_przedmiot * (0.55 + 0.11 * komorki)
	return t * lerpf(2.1, 1.0, clampf(swiatlo, 0.0, 1.0))


## Krok przeszukiwania; zwraca indeks części, w której coś odkryto, albo -1.
func szukaj(delta: float, swiatlo: float) -> int:
	var i := czesc_szukana()
	if i < 0:
		return -1
	var c: Dictionary = lista_czesci()[i]
	var p := _nieznany(c)
	_szuk_t += delta
	if _szuk_t >= czas_szukania(p, swiatlo):
		_szuk_t = 0.0
		(c["znane"] as Dictionary)[p] = true
		c["odkryte"] = (c["znane"] as Dictionary).size()
		odkryte += 1
		return i
	return -1


## Przedmiot włożony przez gracza – wiadomo, co to.
func poznaj(p: Przedmiot) -> void:
	for c in lista_czesci():
		if (c["siatka"] as Siatka).zawiera(p):
			(c["znane"] as Dictionary)[p] = true


func odkryj_wszystko() -> void:
	for c in lista_czesci():
		for e in (c["siatka"] as Siatka).items:
			(c["znane"] as Dictionary)[e["p"]] = true


## Zamknięta na kłódkę skrzynia / szafka: klucz otwiera od razu, narzędziem (kombinerki, klucz nastawny)
## wyłamuje się szybciej, gołymi rękami i kolbą – długo; wyłamywanie słychać daleko.
func _wylam(g) -> void:
	if g.ekw.ma_przedmiot(zamkniety_kluczem):
		zamkniety_kluczem = ""
		Dzwiek.graj_3d("klik", global_position, get_parent(), -6.0, 0.8)
		interakcja(g)
		return
	var narzedzie: bool = g.ekw.ma_przedmiot("kombinerki") or g.ekw.ma_przedmiot("klucz_nastawny")
	var czas := 3.2 if narzedzie else 6.5
	if g.has_method("patrz_na"):
		g.patrz_na(punkt_wnetrza(), 0.45, 0.35 if niski else 0.0)
	var halas := func():
		Dzwiek.graj_3d("lom", global_position + Vector3.UP * 0.5, get_parent(), -4.0, randf_range(0.9, 1.1), 30.0)
		Gra.emituj_halas(global_position, 16.0 if narzedzie else 22.0, g)
	halas.call()
	var t := get_tree().create_timer(czas * 0.5)
	t.timeout.connect(func():
		if not g.akcja.is_empty() and String(g.akcja.get("nazwa", "")).begins_with("Wyłamywanie"):
			halas.call())
	g.zacznij_akcje(("Wyłamywanie kłódki" if narzedzie else "Wyłamywanie kłódki (kolbą)") + ": " + nazwa, czas, func():
		zamkniety_kluczem = ""
		var kl = mebel.get("klodka")
		Dzwiek.graj_3d("upadek_metal", global_position + Vector3.UP * 0.3, get_parent(), -6.0, 1.2)
		var kp: Vector3 = (kl as Node3D).global_position if kl and is_instance_valid(kl) else global_position + Vector3.UP * 0.4
		Efekty.iskry(get_parent(), kp, global_basis.z + Vector3.UP * 0.5)
		Efekty.kurz(get_parent(), Vector3(kp.x, global_position.y, kp.z), 0.6)
		if kl and is_instance_valid(kl):
			# kłódka spada na ziemię
			var kn := kl as Node3D
			var tk := kn.create_tween()
			tk.tween_property(kn, "global_position", Vector3(kp.x, global_position.y + 0.02, kp.z) + global_basis.z * 0.12, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tk.parallel().tween_property(kn, "rotation", kn.rotation + Vector3(1.4, 0.6, 0.3), 0.3)
		g.komunikat.emit("Kłódka puściła")
		, "otwieranie")


func tekst_interakcji(_g) -> String:
	if zamkniety_kluczem != "":
		return "Wyłam kłódkę: " + nazwa + (" (masz narzędzie)" if _g and (_g.ekw.ma_przedmiot("kombinerki") or _g.ekw.ma_przedmiot("klucz_nastawny")) else " (kolbą – głośno, długo)")
	var stan := "" if not zaczety() else (" (przeszukane)" if przeszukany() else " (częściowo)")
	if pusty() and zaczety():
		stan = " (puste)"
	if zamkniety_kluczem != "" and not otwarty_mebel:
		stan += " – zamknięte"
	return "Przeszukaj: " + nazwa + stan


## Punkt wnętrza w świecie (tam patrzy postać i tam rzutowane są kafelki siatki).
func punkt_wnetrza() -> Vector3:
	if mebel.has("wnetrze"):
		return global_transform * Vector3(mebel["wnetrze"])
	var h := wys_wnetrza if wys_wnetrza >= 0.0 else (0.45 if niski else 1.1)
	return global_position + Vector3.UP * h


## Otwiera drzwi / szuflady / wieko kolejnymi krokami; zwraca czas trwania.
func otworz_mebel() -> float:
	if mebel.is_empty() or otwarty_mebel:
		return 0.0
	otwarty_mebel = true
	var kroki: Array = mebel["kroki"]
	if _start.is_empty():
		_start = ModeleMebli.wartosci_startowe(kroki)
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	var czas := 0.0
	var dz: String = mebel.get("dzwiek", "drzwi")
	if not _kurz_byl:
		# pierwsze otwarcie od lat: kurz z zawiasów i szczelin
		_kurz_byl = true
		var pk := punkt_wnetrza() + global_basis.z * 0.25
		get_tree().create_timer(0.15).timeout.connect(func(): Efekty.kurz(get_parent(), Vector3(pk.x, global_position.y + (0.3 if niski else 0.8), pk.z), 0.7))
	for krok in kroki:
		var dl := 0.0
		for zm in krok:
			dl = maxf(dl, float(zm[3]))
		czas += dl + 0.04
		_tw.tween_callback(func(): _dzwiek(dz, true))
		for zm in krok:
			_tw.parallel().tween_property(zm[0], NodePath(String(zm[1])), zm[2], float(zm[3])).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tw.tween_interval(0.04)
	return czas


func zamknij_mebel() -> void:
	if mebel.is_empty() or not otwarty_mebel:
		return
	otwarty_mebel = false
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	var kroki: Array = mebel["kroki"]
	var dz: String = mebel.get("dzwiek", "drzwi")
	for i in range(kroki.size() - 1, -1, -1):
		var krok: Array = kroki[i]
		for j in krok.size():
			var zm: Array = krok[j]
			var tg := _tw.parallel() if j > 0 else _tw
			tg.tween_property(zm[0], NodePath(String(zm[1])), _start[i][j], float(zm[3]) * 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.tween_callback(func(): _dzwiek(dz, false))


func _dzwiek(dz: String, otw: bool) -> void:
	var nazwa: String = {"drzwi": "drzwi", "szuflada": "szuflada", "wieko": "wieko"}.get(dz, "drzwi")
	Dzwiek.graj_3d(nazwa, global_position + Vector3.UP * 0.5, get_parent(), -10.0 if otw else -8.0, randf_range(0.95, 1.1) * (1.0 if otw else 1.15), 18.0)
	Gra.emituj_halas(global_position, 6.0 if dz != "wieko" else 8.0, get_tree().get_first_node_in_group("gracz"))


## Podejście do mebla: postać zwraca się w stronę wnętrza (przy niskich przyklęka), sięga ręką,
## otwiera drzwi / szufladę / wieko – dopiero wtedy widać zawartość.
func interakcja(g) -> void:
	if not g.akcja.is_empty():
		return
	if zamkniety_kluczem != "":
		_wylam(g)
		return
	var czas := otworz_mebel()
	if g.has_method("patrz_na"):
		g.patrz_na(punkt_wnetrza(), 0.45, 0.35 if niski else 0.0)
	var otw := func(): get_tree().call_group("ui_rajdu", "otworz_pojemnik", self)
	if czas <= 0.05:
		czas = 0.45 if niski else 0.3
	g.zacznij_akcje("Otwieranie: " + nazwa, czas, otw, "otwieranie")
