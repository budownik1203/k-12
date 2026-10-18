class_name ModeleIB
extends RefCounted
## Modele broni w stylu Iron Blight: dużo fazowanych części i walców, zaokrąglenia z segmentów,
## detale (nacięcia zamka, okno wyrzutnika, kabłąk z łuku, zawleczki, nity) i tekstury w niskiej
## rozdzielczości: wytarta oksydowana stal, rudy orzech ze słojami, bakelit w kratkę.
## Punkty (lufa, celownik, przód, chwyt, łoże) zgodne z animacjami i dodatkami.

const B := preload("res://scripts/core/bryly.gd")


## Łuk z odcinków w płaszczyźnie YZ (kabłąk spustu, zaokrąglenia).
static func _luk(srodek: Vector3, r: float, od: float, do_: float, n: int, gr: Vector2, m := "metal") -> Array:
	var out := []
	for i in n:
		var a0 := deg_to_rad(lerpf(od, do_, float(i) / n))
		var a1 := deg_to_rad(lerpf(od, do_, float(i + 1) / n))
		var p0 := srodek + Vector3(0, sin(a0), cos(a0)) * r
		var p1 := srodek + Vector3(0, sin(a1), cos(a1)) * r
		var sr := (p0 + p1) * 0.5
		var dl := p0.distance_to(p1) + 0.001
		var kat := rad_to_deg(atan2(-(p1 - p0).y, -(p1 - p0).z))
		out.append(B.box(sr, Vector3(gr.x, gr.y, dl), m, 0.0, Vector3(kat, 0, 0)))
	return out


## Nacięcia (radełkowanie zamka) po obu stronach: n pionowych rowków.
static func _naciecia(x: float, y: float, z0: float, z1: float, n: int, wys: float) -> Array:
	var out := []
	for i in n:
		var z := lerpf(z0, z1, float(i) / maxf(1.0, n - 1))
		for sx in [-1.0, 1.0]:
			out.append(B.box(Vector3(sx * x, y, z), Vector3(0.002, wys, 0.0022), "czern", 0.0))
	return out


static func _nity(punkty: Array, x: float) -> Array:
	var out := []
	for p in punkty:
		for sx in [-1.0, 1.0]:
			out.append(B.walec(Vector3(sx * x, p.y, p.z), Vector3(sx * (x + 0.0015), p.y, p.z), 0.0028, 0.0024, "metal_jasny", 6))
	return out


static func bron(id: String) -> Dictionary:
	match id:
		"pw9":
			return _pw9()
		"pm63":
			return _pm63()
		"kb47":
			return _kb47()
		"obrzyn":
			return _obrzyn()
	return {}


## PW-9 „Kruk” (typ Makarowa): zaokrąglony zamek z nacięciami, kurek, okładziny w kratkę.
static func _pw9() -> Dictionary:
	var c := [
		# zamek: korpus + zaokrąglona góra + przód
		B.box(Vector3(0, 0.034, -0.07), Vector3(0.027, 0.028, 0.168), "metal", 0.006),
		B.box(Vector3(0, 0.048, -0.072), Vector3(0.021, 0.008, 0.16), "metal", 0.004),
		B.walec(Vector3(0, 0.036, -0.154), Vector3(0, 0.036, -0.158), 0.0065, 0.0065, "czern", 8),
		B.box(Vector3(0.0137, 0.04, -0.045), Vector3(0.002, 0.012, 0.03), "czern", 0.0),        # okno wyrzutnika
		B.box(Vector3(-0.0137, 0.036, -0.005), Vector3(0.004, 0.006, 0.014), "metal_jasny", 0.002),  # bezpiecznik
		# szkielet, kabłąk, spust
		B.box(Vector3(0, 0.013, -0.075), Vector3(0.025, 0.016, 0.13), "metal", 0.004),
		B.box(Vector3(0, -0.002, -0.062), Vector3(0.006, 0.02, 0.008), "metal_jasny", 0.002, Vector3(-18, 0, 0)),
		# chwyt: szkielet + okładziny w kratkę po bokach + stopka
		B.box(Vector3(0, -0.035, 0.008), Vector3(0.024, 0.086, 0.04), "metal", 0.006, Vector3(12, 0, 0)),
		B.box(Vector3(0.0128, -0.036, 0.008), Vector3(0.003, 0.074, 0.036), "okladzina", 0.002, Vector3(12, 0, 0)),
		B.box(Vector3(-0.0128, -0.036, 0.008), Vector3(0.003, 0.074, 0.036), "okladzina", 0.002, Vector3(12, 0, 0)),
		B.walec(Vector3(0, -0.08, 0.024), Vector3(0, -0.084, 0.03), 0.004, 0.004, "metal_jasny", 6),
		# kurek i przyrządy
		B.box(Vector3(0, 0.032, 0.02), Vector3(0.01, 0.016, 0.012), "metal", 0.003, Vector3(30, 0, 0)),
		B.box(Vector3(0, 0.057, -0.146), Vector3(0.0045, 0.01, 0.008), "metal", 0.0),
		B.box(Vector3(-0.007, 0.057, 0.006), Vector3(0.006, 0.01, 0.008), "metal", 0.0),
		B.box(Vector3(0.007, 0.057, 0.006), Vector3(0.006, 0.01, 0.008), "metal", 0.0),
	]
	c.append_array(_naciecia(0.0137, 0.037, -0.01, 0.012, 7, 0.02))
	c.append_array(_luk(Vector3(0, 0.0, -0.058), 0.021, 180, 345, 6, Vector2(0.006, 0.004)))
	var m := [
		B.box(Vector3(0, -0.084, 0.014), Vector3(0.021, 0.008, 0.032), "metal", 0.003, Vector3(12, 0, 0)),
		B.box(Vector3(0, -0.04, 0.009), Vector3(0.018, 0.08, 0.03), "metal", 0.003, Vector3(12, 0, 0)),
	]
	return {"cialo3": c, "mag3": m, "chwyt": Vector3(0, -0.042, 0.014), "kat_chwytu": 12.0, "lozysko": Vector3(0, -0.04, 0.014)}


## PM-63 „Rak”: płaska komora z ruchomym zamkiem, przedni chwyt, wysuwana kolba z blachy.
static func _pm63() -> Dictionary:
	var c := [
		B.box(Vector3(0, 0.04, -0.1), Vector3(0.042, 0.052, 0.27), "metal", 0.008),
		B.box(Vector3(0, 0.07, -0.09), Vector3(0.034, 0.012, 0.24), "metal", 0.005),
		B.box(Vector3(0.0215, 0.048, -0.13), Vector3(0.002, 0.014, 0.05), "czern", 0.0),
		B.walec(Vector3(0, 0.044, -0.235), Vector3(0, 0.044, -0.33), 0.0095, 0.009, "metal", 8),
		B.box(Vector3(0, 0.042, -0.29), Vector3(0.026, 0.024, 0.07), "metal", 0.006),      # kompensator „łopatka”
		B.walec(Vector3(0, 0.044, -0.33), Vector3(0, 0.044, -0.336), 0.006, 0.006, "czern", 8),
		# chwyt i przedni chwyt
		B.box(Vector3(0, -0.035, 0.0), Vector3(0.032, 0.105, 0.044), "okladzina", 0.012, Vector3(10, 0, 0)),
		B.box(Vector3(0, -0.032, -0.17), Vector3(0.028, 0.07, 0.03), "bakelit", 0.01, Vector3(-5, 0, 0)),
		# kolba składana z blachy
		B.box(Vector3(0.014, 0.02, 0.12), Vector3(0.004, 0.01, 0.2), "metal", 0.002),
		B.box(Vector3(-0.014, 0.02, 0.12), Vector3(0.004, 0.01, 0.2), "metal", 0.002),
		B.box(Vector3(0, 0.0, 0.22), Vector3(0.036, 0.05, 0.006), "metal", 0.003),
		# przyrządy, spust
		B.box(Vector3(0, 0.08, -0.205), Vector3(0.005, 0.026, 0.008), "metal", 0.0),
		B.box(Vector3(-0.01, 0.082, 0.0), Vector3(0.005, 0.02, 0.016), "metal", 0.0),
		B.box(Vector3(0.01, 0.082, 0.0), Vector3(0.005, 0.02, 0.016), "metal", 0.0),
		B.box(Vector3(0, -0.002, -0.055), Vector3(0.007, 0.022, 0.009), "metal_jasny", 0.002, Vector3(-15, 0, 0)),
	]
	c.append_array(_naciecia(0.0215, 0.06, -0.02, 0.02, 6, 0.012))
	c.append_array(_luk(Vector3(0, 0.002, -0.052), 0.022, 180, 345, 6, Vector2(0.006, 0.004)))
	c.append_array(_nity([Vector3(0, 0.03, -0.18), Vector3(0, 0.03, -0.03)], 0.021))
	var m := [
		B.box(Vector3(0, -0.12, 0.004), Vector3(0.024, 0.16, 0.032), "metal", 0.005, Vector3(10, 0, 0)),
		B.box(Vector3(0, -0.198, 0.018), Vector3(0.027, 0.01, 0.036), "metal", 0.003, Vector3(10, 0, 0)),
	]
	return {"cialo3": c, "mag3": m, "chwyt": Vector3(0, -0.046, 0.008), "kat_chwytu": 10.0, "lozysko": Vector3(0, -0.034, -0.17)}


## KB-47 „Kałach”: tłoczona komora z nitami, rude łoże i kolba, zakrzywiony magazynek z segmentów.
static func _kb47() -> Dictionary:
	var c := [
		# komora i pokrywa (zaokrąglona), nity, okno, rączka zamka, przełącznik
		B.box(Vector3(0, 0.05, -0.12), Vector3(0.046, 0.06, 0.36), "metal", 0.006),
		B.box(Vector3(0, 0.086, -0.115), Vector3(0.04, 0.014, 0.33), "metal", 0.008),
		B.box(Vector3(0, 0.094, -0.115), Vector3(0.028, 0.006, 0.3), "metal", 0.003),
		B.box(Vector3(0.0235, 0.068, -0.15), Vector3(0.002, 0.012, 0.08), "czern", 0.0),
		B.box(Vector3(0.03, 0.07, -0.08), Vector3(0.014, 0.01, 0.024), "metal_jasny", 0.004),
		B.box(Vector3(0.0245, 0.06, -0.03), Vector3(0.003, 0.03, 0.09), "metal", 0.001, Vector3(-6, 0, 0)),
		B.box(Vector3(0, 0.022, -0.12), Vector3(0.04, 0.012, 0.3), "metal", 0.004),
		# łoże dolne (zwężające się, z wcięciem), nakładka rury gazowej, okucia
		B.box(Vector3(0, 0.046, -0.385), Vector3(0.056, 0.05, 0.2), "drewno", 0.016),
		B.box(Vector3(0, 0.024, -0.385), Vector3(0.044, 0.016, 0.18), "drewno", 0.007),
		B.box(Vector3(0, 0.096, -0.405), Vector3(0.034, 0.024, 0.19), "drewno", 0.011),
		B.box(Vector3(0, 0.058, -0.29), Vector3(0.05, 0.05, 0.012), "metal", 0.004),
		B.box(Vector3(0, 0.058, -0.488), Vector3(0.05, 0.05, 0.012), "metal", 0.004),
		# lufa, rura gazowa, blok gazowy, blok muszki z osłoną, hamulec
		B.walec(Vector3(0, 0.058, -0.49), Vector3(0, 0.058, -0.77), 0.0105, 0.0095, "metal", 8),
		B.walec(Vector3(0, 0.094, -0.5), Vector3(0, 0.094, -0.6), 0.0085, 0.0085, "metal", 8),
		B.box(Vector3(0, 0.078, -0.6), Vector3(0.024, 0.05, 0.03), "metal", 0.005),
		B.box(Vector3(0, 0.072, -0.69), Vector3(0.022, 0.034, 0.024), "metal", 0.005),
		B.box(Vector3(-0.009, 0.098, -0.69), Vector3(0.003, 0.02, 0.02), "metal", 0.0),
		B.box(Vector3(0.009, 0.098, -0.69), Vector3(0.003, 0.02, 0.02), "metal", 0.0),
		B.box(Vector3(0, 0.095, -0.69), Vector3(0.0045, 0.05, 0.006), "metal", 0.0),
		B.walec(Vector3(0, 0.058, -0.77), Vector3(0, 0.058, -0.805), 0.0135, 0.0125, "metal", 8),
		B.walec(Vector3(0, 0.058, -0.805), Vector3(0, 0.058, -0.808), 0.007, 0.007, "czern", 8),
		# szczerbinka
		B.box(Vector3(0, 0.092, -0.22), Vector3(0.032, 0.01, 0.05), "metal", 0.003),
		B.box(Vector3(-0.011, 0.105, -0.22), Vector3(0.007, 0.03, 0.04), "metal", 0.002),
		B.box(Vector3(0.011, 0.105, -0.22), Vector3(0.007, 0.03, 0.04), "metal", 0.002),
		# kolba: szyjka i trzon, stopka z blachy
		B.box(Vector3(0, 0.038, 0.11), Vector3(0.036, 0.05, 0.1), "drewno", 0.012, Vector3(-8, 0, 0)),
		B.box(Vector3(0, 0.022, 0.26), Vector3(0.042, 0.098, 0.22), "drewno", 0.016, Vector3(-6, 0, 0)),
		B.box(Vector3(0, 0.01, 0.374), Vector3(0.046, 0.11, 0.01), "metal", 0.004, Vector3(-6, 0, 0)),
		# chwyt pistoletowy (bakelit), kabłąk, spust
		B.box(Vector3(0, -0.036, 0.0), Vector3(0.03, 0.1, 0.042), "okladzina", 0.012, Vector3(18, 0, 0)),
		B.box(Vector3(0, -0.004, -0.06), Vector3(0.007, 0.024, 0.009), "metal_jasny", 0.002, Vector3(-15, 0, 0)),
	]
	c.append_array(_luk(Vector3(0, 0.012, -0.06), 0.022, 180, 350, 6, Vector2(0.008, 0.004)))
	c.append_array(_nity([Vector3(0, 0.032, -0.25), Vector3(0, 0.032, -0.07), Vector3(0, 0.04, 0.02)], 0.0232))
	# magazynek: łuk z czterech segmentów z żebrami
	var m := []
	var kat := -10.0
	var p := Vector3(0, -0.02, -0.165)
	for i in 4:
		var dl := 0.05
		var r := Basis.from_euler(Vector3(deg_to_rad(kat), 0, 0))
		var sr := p + r * Vector3(0, -dl * 0.5, 0)
		m.append(B.box(sr, Vector3(0.03, dl + 0.004, 0.064 - i * 0.003), "metal", 0.005, Vector3(kat, 0, 0)))
		m.append(B.box(sr + Vector3(0.0155, 0, 0), Vector3(0.002, dl * 0.7, 0.04), "metal_jasny", 0.0, Vector3(kat, 0, 0)))
		m.append(B.box(sr - Vector3(0.0155, 0, 0), Vector3(0.002, dl * 0.7, 0.04), "metal_jasny", 0.0, Vector3(kat, 0, 0)))
		p = p + r * Vector3(0, -dl, 0)
		kat -= 7.0
	return {"cialo3": c, "mag3": m, "chwyt": Vector3(0, -0.042, 0.012), "kat_chwytu": 18.0, "lozysko": Vector3(0, 0.046, -0.385)}


## Obrzyn: dwie lufy z wąską szyną, baskila z dźwignią otwierania, kurki, chwyt z drewna.
static func _obrzyn() -> Dictionary:
	var c := [
		B.walec(Vector3(-0.0118, 0.045, -0.07), Vector3(-0.0118, 0.045, -0.44), 0.0118, 0.0112, "metal", 10),
		B.walec(Vector3(0.0118, 0.045, -0.07), Vector3(0.0118, 0.045, -0.44), 0.0118, 0.0112, "metal", 10),
		B.walec(Vector3(-0.0118, 0.045, -0.44), Vector3(-0.0118, 0.045, -0.442), 0.0085, 0.0085, "czern", 10),
		B.walec(Vector3(0.0118, 0.045, -0.44), Vector3(0.0118, 0.045, -0.442), 0.0085, 0.0085, "czern", 10),
		B.box(Vector3(0, 0.059, -0.25), Vector3(0.008, 0.006, 0.37), "metal", 0.002),
		B.box(Vector3(0, 0.03, -0.25), Vector3(0.012, 0.012, 0.37), "metal", 0.002),
		B.box(Vector3(0, 0.064, -0.43), Vector3(0.005, 0.006, 0.006), "metal_jasny", 0.0),
		# czółenko (drewno) pod lufami
		B.box(Vector3(0, 0.022, -0.17), Vector3(0.05, 0.03, 0.15), "drewno", 0.012),
		# baskila
		B.box(Vector3(0, 0.032, -0.03), Vector3(0.05, 0.05, 0.08), "metal", 0.01),
		B.box(Vector3(0, 0.058, 0.0), Vector3(0.012, 0.014, 0.03), "metal_jasny", 0.004),
		# kurki
		B.box(Vector3(-0.01, 0.06, 0.018), Vector3(0.006, 0.02, 0.01), "metal", 0.002, Vector3(40, 0, 0)),
		B.box(Vector3(0.01, 0.06, 0.018), Vector3(0.006, 0.02, 0.01), "metal", 0.002, Vector3(40, 0, 0)),
		# chwyt (resztka kolby) z drewna, nasadka
		B.box(Vector3(0, -0.01, 0.045), Vector3(0.04, 0.07, 0.06), "drewno", 0.014, Vector3(28, 0, 0)),
		B.box(Vector3(0, -0.055, 0.075), Vector3(0.038, 0.06, 0.05), "drewno", 0.014, Vector3(28, 0, 0)),
		B.box(Vector3(0, -0.084, 0.092), Vector3(0.04, 0.008, 0.05), "metal", 0.003, Vector3(28, 0, 0)),
		# spusty
		B.box(Vector3(0, 0.0, -0.02), Vector3(0.006, 0.022, 0.008), "metal_jasny", 0.002, Vector3(-15, 0, 0)),
		B.box(Vector3(0, 0.0, -0.005), Vector3(0.006, 0.02, 0.008), "metal_jasny", 0.002, Vector3(-10, 0, 0)),
	]
	c.append_array(_luk(Vector3(0, 0.012, -0.012), 0.024, 180, 350, 6, Vector2(0.007, 0.004)))
	return {"cialo3": c, "mag3": [], "chwyt": Vector3(0, -0.036, 0.055), "kat_chwytu": 28.0, "lozysko": Vector3(0, 0.025, -0.17)}
