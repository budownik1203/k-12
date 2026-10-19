class_name ModeleIB
extends RefCounted
## Modele broni w stylu Iron Blight, budowane z prawdziwych sylwetek: każdy element (zamek, chwyt, kolba,
## łoże, magazynek, kabłąk) to profil boczny wyciągnięty na szerokość z fazą, a lufy i rury to walce.
## Tekstury: wytarta oksydowana stal, rudy orzech ze słojami, bakelit w kratkę. Punkty (lufa, celownik,
## chwyt, łoże) zgodne z animacjami i dodatkami.

const B := preload("res://scripts/core/bryly.gd")


static func V(z: float, y: float) -> Vector2:
	return Vector2(z, y)


## Kabłąk spustu: pasek w kształcie litery U (profil bez otworów: zewnętrzny łuk + wewnętrzny z powrotem).
static func _kablak(z_przod: float, z_tyl: float, y_gora: float, gl: float, gr := 0.004, w := 0.008, m := "metal") -> Dictionary:
	var zew := []
	var wew := []
	var n := 8
	var cz := (z_przod + z_tyl) * 0.5
	var rz := (z_tyl - z_przod) * 0.5
	for i in n + 1:
		var a := PI * float(i) / n
		zew.append(V(cz - cos(a) * rz, y_gora - sin(a) * gl))
	for i in range(n, -1, -1):
		var a := PI * float(i) / n
		wew.append(V(cz - cos(a) * (rz - gr), y_gora - sin(a) * (gl - gr)))
	return B.profil(zew + wew, w, m, 0.0)


## Nacięcia zamka po obu stronach.
static func _naciecia(x: float, y: float, z0: float, z1: float, n: int, wys: float) -> Array:
	var out := []
	for i in n:
		var z := lerpf(z0, z1, float(i) / maxf(1.0, n - 1))
		for sx in [-1.0, 1.0]:
			out.append(B.box(Vector3(sx * x, y, z), Vector3(0.0018, wys, 0.0018), "czern", 0.0))
	return out


static func _nity(punkty: Array, x: float) -> Array:
	var out := []
	for p in punkty:
		for sx in [-1.0, 1.0]:
			out.append(B.walec(Vector3(sx * x, p.y, p.x), Vector3(sx * (x + 0.0014), p.y, p.x), 0.0026, 0.0022, "metal_jasny", 6))
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


## PW-9 „Kruk” (typ Makarowa).
static func _pw9() -> Dictionary:
	# zamek (ruchomy: odskakuje przy strzale, zostaje w tyle po ostatnim naboju)
	var zamek := [
		B.profil([V(0.022, 0.021), V(0.023, 0.044), V(0.017, 0.05), V(-0.148, 0.05), V(-0.156, 0.046), V(-0.159, 0.032), V(-0.156, 0.021)], 0.026, "metal", 0.004),
		B.profil([V(0.016, 0.046), V(0.012, 0.0535), V(-0.144, 0.0535), V(-0.148, 0.046)], 0.019, "metal", 0.005),
		B.walec(Vector3(0, 0.034, -0.157), Vector3(0, 0.034, -0.1595), 0.0058, 0.0058, "czern", 8),
		B.box(Vector3(0.0132, 0.041, -0.05), Vector3(0.002, 0.013, 0.03), "czern", 0.0),
		B.box(Vector3(0, 0.057, -0.142), Vector3(0.004, 0.009, 0.007), "metal", 0.0),
		B.box(Vector3(-0.0065, 0.057, 0.008), Vector3(0.005, 0.009, 0.008), "metal", 0.0),
		B.box(Vector3(0.0065, 0.057, 0.008), Vector3(0.005, 0.009, 0.008), "metal", 0.0),
	]
	zamek.append_array(_naciecia(0.0132, 0.036, -0.004, 0.016, 8, 0.02))
	var c := [
		B.walec(Vector3(0, 0.034, -0.03), Vector3(0, 0.034, -0.155), 0.0055, 0.0055, "metal_jasny", 8),   # lufa (widać przy odskoku)
		# szkielet z chwytem (jeden profil), okładzina w kratkę na wierzchu
		B.profil([V(-0.15, 0.021), V(-0.15, 0.011), V(-0.11, 0.009), V(-0.04, 0.008), V(-0.014, 0.004), V(-0.009, -0.03),
			V(-0.004, -0.07), V(0.0, -0.081), V(0.034, -0.081), V(0.037, -0.062), V(0.031, -0.02), V(0.029, 0.0),
			V(0.034, 0.013), V(0.03, 0.021)], 0.024, "metal", 0.004),
		B.profil([V(-0.007, -0.004), V(-0.003, -0.07), V(0.031, -0.07), V(0.027, -0.004)], 0.0275, "okladzina", 0.003),
		B.walec(Vector3(0, -0.081, 0.026), Vector3(0, -0.086, 0.03), 0.0038, 0.0038, "metal_jasny", 6),
		# kabłąk i spust
		_kablak(-0.046, -0.008, 0.008, 0.026),
		B.profil([V(-0.027, 0.007), V(-0.023, -0.003), V(-0.025, -0.012), V(-0.02, -0.013), V(-0.017, -0.002), V(-0.02, 0.007)], 0.006, "metal_jasny", 0.001),
		# kurek, bezpiecznik, przyrządy
		B.profil([V(0.024, 0.026), V(0.036, 0.034), V(0.04, 0.046), V(0.033, 0.048), V(0.025, 0.04)], 0.009, "metal", 0.002),
		B.box(Vector3(-0.0138, 0.036, 0.006), Vector3(0.004, 0.006, 0.016), "metal_jasny", 0.002),
	]
	# stopka i korpus magazynka (korpus schowany w chwycie, widać go przy wymianie)
	var m := [B.profil([V(-0.002, -0.081), V(0.0, -0.088), V(0.036, -0.088), V(0.035, -0.081)], 0.022, "metal", 0.002),
		B.profil([V(-0.003, -0.006), V(0.024, -0.006), V(0.031, -0.081), V(0.001, -0.081)], 0.017, "metal", 0.002),
		B.walec(Vector3(0, -0.0045, 0.006), Vector3(0, -0.0045, 0.016), 0.0045, 0.0045, "mosiadz", 8)]
	return {"cialo3": c, "mag3": m, "chwyt": Vector3(0, -0.04, 0.014), "kat_chwytu": 10.0, "lozysko": Vector3(0, -0.04, 0.014),
		"ruchome": {"zamek": {"czesci": zamek, "skok": 0.026, "blokada": true}},
		"montaz": {"latarka": Vector3(0, -0.004, -0.112), "latarka_pod": true}}


## PM-63 „Rak”: płaska komora ze skośnym przodem, zamek z „łopatką”, chwyt przedni, kolba z blachy.
static func _pm63() -> Dictionary:
	var c := [
		B.profil([V(0.04, 0.016), V(0.04, 0.06), V(-0.2, 0.06), V(-0.235, 0.05), V(-0.24, 0.022), V(-0.2, 0.016)], 0.04, "metal", 0.006),
		B.walec(Vector3(0, 0.044, -0.2), Vector3(0, 0.044, -0.3), 0.0075, 0.0075, "metal_jasny", 8),
		B.walec(Vector3(0, 0.044, -0.3), Vector3(0, 0.044, -0.334), 0.0085, 0.0085, "metal", 8),
		B.walec(Vector3(0, 0.044, -0.334), Vector3(0, 0.044, -0.336), 0.005, 0.005, "czern", 8),
		B.box(Vector3(0.0205, 0.048, -0.12), Vector3(0.002, 0.014, 0.05), "czern", 0.0),
		# chwyt z magazynkiem w środku i chwyt przedni
		B.profil([V(-0.024, 0.016), V(-0.016, -0.03), V(-0.012, -0.085), V(0.024, -0.085), V(0.026, -0.03), V(0.024, 0.016)], 0.032, "okladzina", 0.01),
		B.profil([V(-0.19, 0.016), V(-0.188, -0.05), V(-0.178, -0.064), V(-0.155, -0.062), V(-0.152, 0.016)], 0.028, "bakelit", 0.009),
		_kablak(-0.08, -0.024, 0.016, 0.028, 0.004, 0.008),
		B.profil([V(-0.058, 0.014), V(-0.054, 0.002), V(-0.056, -0.008), V(-0.05, -0.009), V(-0.048, 0.003), V(-0.051, 0.014)], 0.006, "metal_jasny", 0.001),
		# kolba z dwóch prętów i stopki
		B.box(Vector3(0.014, 0.024, 0.13), Vector3(0.004, 0.009, 0.2), "metal", 0.002),
		B.box(Vector3(-0.014, 0.024, 0.13), Vector3(0.004, 0.009, 0.2), "metal", 0.002),
		B.profil([V(0.228, 0.03), V(0.234, 0.03), V(0.236, -0.03), V(0.226, -0.03)], 0.036, "metal", 0.003),
		# przyrządy
		B.box(Vector3(0, 0.08, -0.205), Vector3(0.005, 0.024, 0.008), "metal", 0.0),
		B.box(Vector3(-0.01, 0.082, 0.02), Vector3(0.005, 0.02, 0.016), "metal", 0.0),
		B.box(Vector3(0.01, 0.082, 0.02), Vector3(0.005, 0.02, 0.016), "metal", 0.0),
	]
	c.append_array(_nity([V(-0.17, 0.03), V(-0.04, 0.03)], 0.0202))
	# zamek PM-63 to cała górna część z „łopatką” – przy strzale jedzie do tyłu
	var zamek := [
		B.profil([V(0.036, 0.058), V(0.03, 0.072), V(-0.22, 0.072), V(-0.232, 0.06)], 0.034, "metal", 0.008),
		B.profil([V(-0.232, 0.03), V(-0.232, 0.066), V(-0.3, 0.06), V(-0.305, 0.03)], 0.026, "metal", 0.006),
	]
	zamek.append_array(_naciecia(0.0172, 0.065, 0.0, 0.03, 6, 0.01))
	var m := [B.profil([V(-0.014, -0.085), V(-0.012, -0.2), V(0.022, -0.2), V(0.022, -0.085)], 0.024, "metal", 0.004),
		B.profil([V(-0.019, 0.012), V(0.02, 0.012), V(0.022, -0.085), V(-0.014, -0.085)], 0.022, "metal", 0.003),
		B.walec(Vector3(0, 0.0135, -0.008), Vector3(0, 0.0135, 0.004), 0.0045, 0.0045, "mosiadz", 8),
		B.profil([V(-0.016, -0.2), V(-0.016, -0.208), V(0.025, -0.208), V(0.025, -0.2)], 0.027, "metal", 0.002)]
	return {"cialo3": c, "mag3": m, "chwyt": Vector3(0, -0.045, 0.006), "kat_chwytu": 6.0, "lozysko": Vector3(0, -0.03, -0.17),
		"ruchome": {"zamek": {"czesci": zamek, "skok": 0.05, "blokada": true}},
		"montaz": {"celownik": Vector3(0, 0.072, -0.07), "latarka": Vector3(0.03, 0.038, -0.262)}}


## KB-47 „Kałach”: tłoczona komora z nitami, zaokrąglona pokrywa, rude łoże z wyprofilowaniem,
## kolba z grzbietem i stopką, bananowy magazynek.
static func _kb47() -> Dictionary:
	var c := [
		# komora i pokrywa
		B.profil([V(0.06, 0.028), V(0.06, 0.08), V(-0.3, 0.08), V(-0.3, 0.026), V(-0.21, 0.02), V(-0.12, 0.02), V(-0.02, 0.02), V(0.03, 0.022)], 0.046, "metal", 0.005),
		B.profil([V(0.068, 0.076), V(0.058, 0.094), V(-0.225, 0.094), V(-0.245, 0.08)], 0.042, "metal", 0.011),
		B.box(Vector3(0.0235, 0.066, -0.15), Vector3(0.002, 0.014, 0.085), "czern", 0.0),

		B.profil([V(0.0, 0.05), V(0.002, 0.066), V(-0.09, 0.064), V(-0.09, 0.058)], 0.003, "metal", 0.0, 0.0245),     # przełącznik
		# szczerbinka na klinie
		B.profil([V(-0.2, 0.08), V(-0.2, 0.098), V(-0.262, 0.098), V(-0.28, 0.082)], 0.03, "metal", 0.004),
		B.box(Vector3(-0.011, 0.105, -0.22), Vector3(0.007, 0.03, 0.04), "metal", 0.002),
		B.box(Vector3(0.011, 0.105, -0.22), Vector3(0.007, 0.03, 0.04), "metal", 0.002),
		# łoże dolne z wyprofilowaniem pod palce i nakładka na rurę gazową
		B.profil([V(-0.29, 0.074), V(-0.29, 0.026), V(-0.305, 0.016), V(-0.37, 0.02), V(-0.4, 0.014), V(-0.47, 0.018), V(-0.485, 0.032), V(-0.485, 0.074)], 0.056, "drewno", 0.014),
		B.profil([V(-0.305, 0.084), V(-0.298, 0.104), V(-0.495, 0.104), V(-0.505, 0.086)], 0.032, "drewno", 0.011),
		B.profil([V(-0.29, 0.024), V(-0.29, 0.084), V(-0.296, 0.084), V(-0.296, 0.024)], 0.05, "metal", 0.003),
		B.profil([V(-0.485, 0.03), V(-0.485, 0.084), V(-0.492, 0.084), V(-0.492, 0.03)], 0.05, "metal", 0.003),
		# lufa, rura gazowa, blok gazowy, wycior, blok muszki z osłoną, hamulec
		B.walec(Vector3(0, 0.058, -0.49), Vector3(0, 0.058, -0.77), 0.0105, 0.0095, "metal", 10),
		B.walec(Vector3(0, 0.094, -0.5), Vector3(0, 0.094, -0.59), 0.0085, 0.0085, "metal", 8),
		B.profil([V(-0.58, 0.042), V(-0.58, 0.104), V(-0.61, 0.104), V(-0.62, 0.05)], 0.024, "metal", 0.004),
		B.walec(Vector3(0, 0.038, -0.49), Vector3(0, 0.038, -0.74), 0.003, 0.003, "metal_jasny", 6),
		B.profil([V(-0.675, 0.044), V(-0.675, 0.088), V(-0.705, 0.088), V(-0.71, 0.046)], 0.022, "metal", 0.004),
		B.box(Vector3(-0.009, 0.098, -0.69), Vector3(0.003, 0.022, 0.022), "metal", 0.0),
		B.box(Vector3(0.009, 0.098, -0.69), Vector3(0.003, 0.022, 0.022), "metal", 0.0),
		B.box(Vector3(0, 0.095, -0.69), Vector3(0.0045, 0.05, 0.006), "metal", 0.0),
		B.walec(Vector3(0, 0.058, -0.77), Vector3(0, 0.058, -0.806), 0.0135, 0.0125, "metal", 10),
		B.walec(Vector3(0, 0.058, -0.806), Vector3(0, 0.058, -0.808), 0.007, 0.007, "czern", 8),
		# kolba: grzbiet opadający do stopki, szyjka u dołu
		B.profil([V(0.055, 0.078), V(0.372, 0.062), V(0.375, -0.046), V(0.33, -0.05), V(0.17, -0.01), V(0.1, 0.01), V(0.055, 0.028)], 0.042, "drewno", 0.014),
		B.profil([V(0.37, 0.064), V(0.384, 0.064), V(0.386, -0.05), V(0.372, -0.05)], 0.046, "metal", 0.004),
		# chwyt pistoletowy (skośny), kabłąk, spust
		B.profil([V(-0.018, 0.021), V(-0.012, -0.03), V(0.004, -0.084), V(0.034, -0.08), V(0.03, -0.04), V(0.018, 0.021)], 0.031, "okladzina", 0.01),
		_kablak(-0.105, -0.022, 0.02, 0.032, 0.004, 0.009),
		B.profil([V(-0.072, 0.018), V(-0.068, 0.004), V(-0.07, -0.008), V(-0.063, -0.009), V(-0.06, 0.004), V(-0.064, 0.018)], 0.007, "metal_jasny", 0.001),
	]
	c.append_array(_nity([V(-0.25, 0.03), V(-0.07, 0.03), V(0.025, 0.04)], 0.0232))
	var m := [
		B.profil([V(-0.205, 0.022), V(-0.208, -0.04), V(-0.222, -0.1), V(-0.25, -0.16), V(-0.268, -0.188), V(-0.205, -0.212),
			V(-0.19, -0.18), V(-0.168, -0.12), V(-0.152, -0.06), V(-0.142, 0.022)], 0.03, "metal", 0.006),
		B.profil([V(-0.27, -0.186), V(-0.274, -0.196), V(-0.204, -0.222), V(-0.2, -0.212)], 0.033, "metal", 0.003),
	]
	for i in 3:
		var t := 0.25 + i * 0.22
		var zz := lerpf(-0.175, -0.225, t)
		var yy := lerpf(0.0, -0.17, t)
		m.append(B.box(Vector3(0.0156, yy, zz), Vector3(0.002, 0.028, 0.034), "metal", 0.0, Vector3(-20 - i * 8, 0, 0)))
		m.append(B.box(Vector3(-0.0156, yy, zz), Vector3(0.002, 0.028, 0.034), "metal", 0.0, Vector3(-20 - i * 8, 0, 0)))
	var raczka := [
		B.profil([V(-0.072, 0.064), V(-0.078, 0.072), V(-0.098, 0.072), V(-0.1, 0.064)], 0.03, "metal_jasny", 0.003, 0.025),
		B.box(Vector3(0.0232, 0.068, -0.03), Vector3(0.003, 0.014, 0.14), "metal", 0.0),     # suwadło widoczne w oknie
	]
	return {"cialo3": c, "mag3": m, "chwyt": Vector3(0, -0.04, 0.01), "kat_chwytu": 16.0, "lozysko": Vector3(0, 0.046, -0.385),
		"ruchome": {"zamek": {"czesci": raczka, "skok": 0.07, "blokada": false}},
		"montaz": {"celownik": Vector3(0, 0.094, -0.115), "latarka": Vector3(0.038, 0.05, -0.44), "chwyt": Vector3(0, 0.016, -0.415)}}


## Obrzyn: dwie lufy z szyną, baskila, kurki, ucięta kolba w kształcie chwytu.
static func _obrzyn() -> Dictionary:
	# lufy z czółenkiem: łamane na zawiasie przy przeładowaniu
	var lufy := [
		B.walec(Vector3(-0.0118, 0.045, -0.07), Vector3(-0.0118, 0.045, -0.44), 0.0118, 0.0112, "metal", 12),
		B.walec(Vector3(0.0118, 0.045, -0.07), Vector3(0.0118, 0.045, -0.44), 0.0118, 0.0112, "metal", 12),
		B.walec(Vector3(-0.0118, 0.045, -0.44), Vector3(-0.0118, 0.045, -0.442), 0.0085, 0.0085, "czern", 10),
		B.walec(Vector3(0.0118, 0.045, -0.44), Vector3(0.0118, 0.045, -0.442), 0.0085, 0.0085, "czern", 10),
		B.box(Vector3(0, 0.0585, -0.25), Vector3(0.008, 0.005, 0.37), "metal", 0.002),
		B.box(Vector3(0, 0.031, -0.25), Vector3(0.012, 0.01, 0.37), "metal", 0.002),
		B.box(Vector3(0, 0.063, -0.43), Vector3(0.004, 0.005, 0.005), "metal_jasny", 0.0),
		B.walec(Vector3(-0.0118, 0.045, -0.069), Vector3(-0.0118, 0.045, -0.071), 0.0086, 0.0086, "czern", 10),
		B.walec(Vector3(0.0118, 0.045, -0.069), Vector3(0.0118, 0.045, -0.071), 0.0086, 0.0086, "czern", 10),
		B.profil([V(-0.1, 0.034), V(-0.1, 0.012), V(-0.12, 0.004), V(-0.24, 0.008), V(-0.255, 0.034)], 0.05, "drewno", 0.013),
	]
	var c := [
		# baskila
		B.profil([V(0.005, 0.0), V(0.005, 0.05), V(-0.012, 0.058), V(-0.07, 0.058), V(-0.07, 0.02), V(-0.04, 0.0)], 0.05, "metal", 0.008),
		B.box(Vector3(0, 0.062, 0.0), Vector3(0.012, 0.012, 0.03), "metal_jasny", 0.004),
		# kurki
		B.profil([V(0.004, 0.04), V(0.01, 0.06), V(0.02, 0.068), V(0.024, 0.062), V(0.014, 0.04)], 0.006, "metal", 0.0015, -0.011),
		B.profil([V(0.004, 0.04), V(0.01, 0.06), V(0.02, 0.068), V(0.024, 0.062), V(0.014, 0.04)], 0.006, "metal", 0.0015, 0.011),
		# chwyt z uciętej kolby
		B.profil([V(0.004, 0.05), V(0.04, 0.04), V(0.07, 0.0), V(0.11, -0.07), V(0.112, -0.09), V(0.07, -0.092), V(0.05, -0.05), V(0.03, -0.018), V(0.005, 0.0)], 0.042, "drewno", 0.014),
		B.profil([V(0.072, -0.092), V(0.114, -0.09), V(0.115, -0.098), V(0.07, -0.1)], 0.044, "metal", 0.003),
		_kablak(-0.038, 0.012, 0.0, 0.026, 0.004, 0.009),
		B.profil([V(-0.024, 0.0), V(-0.02, -0.01), V(-0.022, -0.018), V(-0.016, -0.019), V(-0.014, -0.008), V(-0.017, 0.0)], 0.006, "metal_jasny", 0.001),
		B.profil([V(-0.008, 0.0), V(-0.004, -0.01), V(-0.006, -0.017), V(0.0, -0.018), V(0.002, -0.008), V(-0.001, 0.0)], 0.006, "metal_jasny", 0.001),
	]
	return {"cialo3": c, "mag3": [], "chwyt": Vector3(0, -0.036, 0.055), "kat_chwytu": 34.0, "lozysko": Vector3(0, 0.025, -0.17),
		"ruchome": {"lufy": {"czesci": lufy, "zawias": Vector3(0, 0.02, -0.07), "kat": -0.55}},
		"montaz": {"latarka": Vector3(0, 0.012, -0.33), "latarka_pod": true}}
