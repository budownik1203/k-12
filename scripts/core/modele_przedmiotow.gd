class_name ModelePrzedmiotow
extends RefCounted
## Modele 3D przedmiotów leżących w świecie (na ziemi, w szufladzie, na zwłokach) – z tych samych
## brył i tekstur co broń i rekwizyty czynności. Każdy przedmiot ma własny kształt: broń i magazynki
## z modeli broni, pudełka amunicji, bandaż, apteczka, butelki, konserwy, radio, kanister itd.
## Układ: model leży na ziemi, po wyśrodkowaniu dno w y = 0.

const B := preload("res://scripts/core/bryly.gd")


static func _b(c: Vector3, s: Vector3, m: String, f := 0.004, k := Color.WHITE, r := Vector3.ZERO) -> Dictionary:
	return {"t": "box", "c": c, "s": s, "m": m, "f": f, "k": k, "r": r}


static func _w(a: Vector3, b: Vector3, r0: float, r1: float, m: String, n := 10, k := Color.WHITE) -> Dictionary:
	return {"t": "walec", "a": a, "b": b, "r0": r0, "r1": r1, "m": m, "n": n, "kat": 0.0, "k": k}


## Węzeł z modelem przedmiotu: dno na y = 0, środek w (0, 0). vm = false: oświetlenie świata (bez
## podświetlenia viewmodelu), z cieniem.
static func wezel(p: Przedmiot, vm := false) -> Node3D:
	var n := Node3D.new()
	var piv := Node3D.new()
	n.add_child(piv)
	var cz: Array = []
	match p.typ():
		"bron":
			var md := Modele.bron(p.id)
			cz = (md.get("cialo3", []) as Array).duplicate()
			if p.dane.get("mag") != null:
				cz.append_array(md.get("mag3", []))
			cz.append_array(_dodatki_broni(p, md))
			# broń leży na boku (prawą stroną do góry)
			piv.rotation = Vector3(0, 0, deg_to_rad(90))
		"magazynek":
			var bid: String = {"mag_pw9": "pw9", "mag_pm63": "pm63", "mag_kb47": "kb47"}.get(p.id, "kb47")
			cz = (Modele.bron(bid).get("mag3", []) as Array).duplicate()
			piv.rotation = Vector3(0, 0, deg_to_rad(90))
		"pojemnik":
			var d: Dictionary = p.defn()["pojemnik"]
			var kam := String(d.get("slot", "")) == "kamizelka"
			var m := ModeleOporzadzenia.zbuduj(p.id)
			var w: Node3D = m["wezel"]
			_bez_vm(w, vm)
			piv.add_child(w)
			if kam:
				piv.rotation = Vector3(deg_to_rad(-90), 0, 0)   # kamizelka leży płasko
				piv.scale = Vector3.ONE * 1.8                     # model kamizelki budowany w skali „przy kamerze”
			return _wysrodkuj(n, piv)
		_:
			cz = czesci(p)
	if cz.is_empty():
		cz = [_b(Vector3(0, 0.03, 0), Vector3(0.08, 0.06, 0.08), "opakowanie")]
	var mi := B.instancja(cz, vm)
	if not vm:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	piv.add_child(mi)
	return _wysrodkuj(n, piv)


static func _przesun(cz: Array, o: Vector3) -> Array:
	var out := []
	for c in cz:
		var d: Dictionary = (c as Dictionary).duplicate()
		if d.has("c"):
			d["c"] = Vector3(d["c"]) + o
		if d.has("a"):
			d["a"] = Vector3(d["a"]) + o
			d["b"] = Vector3(d["b"]) + o
		out.append(d)
	return out


## Dodatki założone na broń leżącą w świecie (tłumik na wylocie, celownik na pokrywie, latarka, chwyt).
static func _dodatki_broni(p: Przedmiot, md: Dictionary) -> Array:
	var out := []
	var mont: Dictionary = md.get("montaz", {})
	for slot in Przedmiot.SLOTY_DODATKOW:
		var d: Przedmiot = p.dodatek(slot)
		if d == null:
			continue
		var cz := _dodatek(d.id)
		match slot:
			"wylot":
				var lufa: Vector3 = md.get("lufa", Vector3.ZERO)
				var dl := 0.14 if d.id == "tlumik_9" else (0.18 if d.id == "tlumik_762" else 0.06)
				var r := 0.017 if d.id == "tlumik_9" else (0.019 if d.id == "tlumik_762" else 0.016)
				out.append_array(_przesun(cz, lufa + Vector3(0, -r, -dl * 0.5 + 0.01)))
			"celownik":
				if mont.has("celownik"):
					out.append_array(_przesun(cz, Vector3(mont["celownik"])))
			"chwyt":
				if mont.has("chwyt"):
					# chwyt pionowy pod łożem
					var cc := []
					for c in cz:
						var dd: Dictionary = (c as Dictionary).duplicate()
						if dd.has("c"):
							var v: Vector3 = dd["c"]
							dd["c"] = Vector3(v.x, -v.z * 0.6 - 0.04, v.y)
							var sz: Vector3 = dd["s"]
							dd["s"] = Vector3(sz.x, sz.z, sz.y)
						cc.append(dd)
					out.append_array(_przesun(cc, Vector3(mont["chwyt"])))
			"latarka":
				if mont.has("latarka"):
					out.append_array(_przesun(cz, Vector3(mont["latarka"]) + Vector3(0, -0.014, 0)))
	return out


static func _bez_vm(w: Node, vm: bool) -> void:
	if vm:
		return
	for c in w.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var mesh := mi.mesh as ArrayMesh
			if mesh:
				for i in mesh.get_surface_count():
					var m := mesh.surface_get_material(i) as ShaderMaterial
					if m:
						var m2 := m.duplicate() as ShaderMaterial
						m2.set_shader_parameter("use_emission", false)
						mi.set_surface_override_material(i, m2)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_bez_vm(c, vm)


## Przesuwa obrócony model tak, by leżał dnem na y = 0, wyśrodkowany w XZ. Zapisuje rozmiar w meta "aabb".
static func _wysrodkuj(n: Node3D, piv: Node3D) -> Node3D:
	var ab := _aabb(piv, Transform3D(piv.basis, Vector3.ZERO))
	piv.position = -Vector3(ab.get_center().x, ab.position.y, ab.get_center().z)
	n.set_meta("aabb", AABB(Vector3(-ab.size.x * 0.5, 0, -ab.size.z * 0.5), ab.size))
	return n


static func _aabb(w: Node3D, t: Transform3D) -> AABB:
	var out := AABB()
	var jest := false
	for c in w.get_children():
		if not c is Node3D:
			continue
		var tc: Transform3D = t * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var a: AABB = tc * (c as MeshInstance3D).mesh.get_aabb()
			out = a if not jest else out.merge(a)
			jest = true
		var sub := _aabb(c, tc)
		if sub.size != Vector3.ZERO:
			out = sub if not jest else out.merge(sub)
			jest = true
	return out


## Bryły drobnych przedmiotów (w układzie: leży na ziemi, y w górę).
static func czesci(p: Przedmiot) -> Array:
	var id := p.id
	match p.typ():
		"amunicja":
			return _amunicja(p)
		"dodatek":
			return _dodatek(id)
		"med":
			return _med(id)
		"pancerz":
			return _pancerz(id)
		"klucz":
			return [_w(Vector3(-0.03, 0.003, 0), Vector3(-0.03, 0.007, 0), 0.012, 0.012, "mosiadz", 10),
				_b(Vector3(0.005, 0.004, 0), Vector3(0.05, 0.004, 0.008), "mosiadz", 0.001),
				_b(Vector3(0.022, 0.004, 0.006), Vector3(0.008, 0.004, 0.008), "mosiadz", 0.001),
				_b(Vector3(0.012, 0.004, 0.006), Vector3(0.006, 0.004, 0.006), "mosiadz", 0.001),
				_w(Vector3(-0.03, 0.002, 0.0), Vector3(-0.03, 0.008, 0.0), 0.004, 0.004, "czern", 6)]
		"mapa":
			return [_b(Vector3(0, 0.004, 0), Vector3(0.16, 0.008, 0.22), "bandaz", 0.001, Color(0.85, 0.8, 0.62)),
				_b(Vector3(0, 0.009, 0.03), Vector3(0.1, 0.002, 0.08), "bandaz", 0.0, Color(0.5, 0.62, 0.45)),
				_b(Vector3(0, 0.0085, 0), Vector3(0.162, 0.001, 0.004), "czern", 0.0, Color(0.6, 0.6, 0.6))]
		"kompas":
			return [_w(Vector3(0, 0, 0), Vector3(0, 0.016, 0), 0.03, 0.03, "metal", 14),
				_w(Vector3(0, 0.016, 0), Vector3(0, 0.017, 0), 0.025, 0.025, "bandaz", 14, Color(0.9, 0.88, 0.8)),
				_b(Vector3(0, 0.018, 0), Vector3(0.004, 0.002, 0.04), "czerwony", 0.0),
				_w(Vector3(0, 0.006, -0.03), Vector3(0, 0.006, -0.038), 0.006, 0.006, "metal_jasny", 8)]
		"latarka":
			return [_w(Vector3(0, 0.017, 0.07), Vector3(0, 0.017, -0.05), 0.016, 0.016, "metal_jasny", 10, Color(0.6, 0.7, 0.55)),
				_w(Vector3(0, 0.022, -0.05), Vector3(0, 0.022, -0.1), 0.019, 0.025, "metal_jasny", 10, Color(0.6, 0.7, 0.55)),
				_w(Vector3(0, 0.022, -0.1), Vector3(0, 0.022, -0.104), 0.022, 0.022, "metal_jasny", 10),
				_b(Vector3(0, 0.034, 0.0), Vector3(0.01, 0.008, 0.02), "czerwony", 0.002)]
	return _lup(id)


static func _amunicja(p: Przedmiot) -> Array:
	# garść: kilka luźnych naboi; większy stos: tekturowe pudełko z nadrukiem, kilka naboi obok
	var cz := []
	var r := 0.0048
	var dl := 0.026
	var szus := "miedz"
	match p.id:
		"a_12":
			r = 0.0105; dl = 0.07; szus = "czerwony"
		"a_762", "a_762bp":
			r = 0.0056; dl = 0.056
	var luzne := mini(p.ilosc, 6)
	if p.ilosc > 12:
		var s := Vector3(0.1, 0.035, 0.07) if p.id != "a_12" else Vector3(0.12, 0.075, 0.085)
		cz.append(_b(Vector3(0, s.y * 0.5, 0), s, "opakowanie", 0.003, Color(0.75, 0.68, 0.5)))
		cz.append(_b(Vector3(0, s.y + 0.0005, 0), Vector3(s.x * 0.7, 0.001, s.z * 0.35), "bandaz", 0.0, Color(0.85, 0.82, 0.7)))
		if p.id == "a_762bp":
			cz.append(_b(Vector3(0, s.y + 0.001, s.z * 0.3), Vector3(s.x * 0.9, 0.001, 0.008), "czern", 0.0))
		luzne = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p.id) + p.ilosc
	for i in luzne:
		var x := 0.07 + rng.randf_range(0.0, 0.05) if p.ilosc > 12 else rng.randf_range(-0.04, 0.04)
		var z := rng.randf_range(-0.04, 0.04)
		var kat := rng.randf() * TAU
		var o := Vector3(cos(kat), 0, sin(kat))
		var a := Vector3(x, r, z) - o * dl * 0.5
		cz.append(_w(a, a + o * dl * 0.62, r, r, "mosiadz" if p.id != "a_12" else "czerwony", 8))
		cz.append(_w(a + o * dl * 0.62, a + o * dl, r * 0.85, r * 0.25, szus if p.id != "a_12" else "czerwony", 8))
		if p.id == "a_12":
			cz.append(_w(a - o * 0.012, a, r * 1.06, r * 1.06, "mosiadz", 8))
	return cz


static func _dodatek(id: String) -> Array:
	match id:
		"tlumik_9", "tlumik_762":
			var r := 0.017 if id == "tlumik_9" else 0.019
			var dl := 0.14 if id == "tlumik_9" else 0.18
			return [_w(Vector3(0, r, dl * 0.5), Vector3(0, r, -dl * 0.5), r, r, "metal", 12),
				_w(Vector3(0, r, dl * 0.5), Vector3(0, r, dl * 0.5 + 0.012), r * 0.7, r * 0.7, "metal", 10),
				_w(Vector3(0, r, -dl * 0.5), Vector3(0, r, -dl * 0.5 - 0.002), r * 0.35, r * 0.35, "czern", 8)]
		"hamulec":
			return [_w(Vector3(0, 0.016, 0.03), Vector3(0, 0.016, -0.03), 0.016, 0.015, "metal", 10),
				_b(Vector3(0.012, 0.016, -0.005), Vector3(0.008, 0.014, 0.008), "czern", 0.0),
				_b(Vector3(-0.012, 0.016, -0.005), Vector3(0.008, 0.014, 0.008), "czern", 0.0)]
		"kolimator":
			return [_b(Vector3(0, 0.006, 0), Vector3(0.03, 0.012, 0.07), "metal", 0.002),
				_b(Vector3(0, 0.03, -0.01), Vector3(0.042, 0.04, 0.032), "metal", 0.004),
				_b(Vector3(0, 0.03, -0.01), Vector3(0.028, 0.026, 0.034), "czern", 0.0),
				_w(Vector3(0.022, 0.036, 0.0), Vector3(0.03, 0.036, 0.0), 0.005, 0.005, "metal_jasny", 8)]
		"luneta":
			return [_w(Vector3(0, 0.022, 0.09), Vector3(0, 0.022, -0.07), 0.014, 0.014, "metal", 12),
				_w(Vector3(0, 0.024, -0.07), Vector3(0, 0.024, -0.11), 0.016, 0.02, "metal", 12),
				_w(Vector3(0, 0.022, 0.09), Vector3(0, 0.022, 0.12), 0.017, 0.017, "guma", 12),
				_b(Vector3(0.0, 0.006, 0.0), Vector3(0.03, 0.012, 0.09), "metal", 0.002),
				_w(Vector3(0, 0.036, 0.0), Vector3(0, 0.048, 0.0), 0.007, 0.007, "metal", 8)]
		"chwyt":
			return [_b(Vector3(0, 0.014, 0), Vector3(0.03, 0.028, 0.1), "bakelit", 0.006),
				_b(Vector3(0, 0.026, -0.04), Vector3(0.03, 0.006, 0.03), "metal", 0.002)]
		"latarka_taktyczna":
			return [_w(Vector3(0, 0.014, 0.05), Vector3(0, 0.014, -0.04), 0.013, 0.013, "metal", 10),
				_w(Vector3(0, 0.017, -0.04), Vector3(0, 0.017, -0.07), 0.017, 0.017, "metal", 10),
				_b(Vector3(0, 0.03, 0.0), Vector3(0.02, 0.008, 0.04), "metal", 0.002)]
	return []


static func _med(id: String) -> Array:
	match id:
		"bandaz":
			return [_w(Vector3(-0.03, 0.022, 0), Vector3(0.03, 0.022, 0), 0.022, 0.022, "bandaz", 12),
				_w(Vector3(-0.031, 0.022, 0), Vector3(0.031, 0.022, 0), 0.007, 0.007, "bandaz", 8, Color(0.8, 0.78, 0.72))]
		"opatrunek":
			return [_b(Vector3(0, 0.012, 0), Vector3(0.08, 0.024, 0.12), "opakowanie", 0.006),
				_b(Vector3(0, 0.025, 0.02), Vector3(0.05, 0.002, 0.03), "czerwony", 0.0)]
		"szyna":
			return [_b(Vector3(0, 0.02, 0), Vector3(0.11, 0.04, 0.2), "szyna", 0.01),
				_b(Vector3(0, 0.041, 0), Vector3(0.112, 0.002, 0.02), "bandaz", 0.0, Color(0.85, 0.8, 0.7))]
		"bolostop":
			return [_b(Vector3(0, 0.009, 0), Vector3(0.06, 0.018, 0.09), "opakowanie", 0.003, Color(0.9, 0.9, 0.95)),
				_b(Vector3(0, 0.0185, -0.02), Vector3(0.05, 0.001, 0.02), "czerwony", 0.0)]
		"apteczka":
			return [_b(Vector3(0, 0.03, 0), Vector3(0.16, 0.06, 0.11), "apteczka", 0.008),
				_b(Vector3(0, 0.061, 0), Vector3(0.04, 0.002, 0.012), "bandaz", 0.0, Color(0.95, 0.95, 0.95)),
				_b(Vector3(0, 0.061, 0), Vector3(0.012, 0.002, 0.04), "bandaz", 0.0, Color(0.95, 0.95, 0.95)),
				_b(Vector3(0, 0.06, -0.056), Vector3(0.05, 0.012, 0.006), "metal", 0.002)]
	return [_b(Vector3(0, 0.02, 0), Vector3(0.08, 0.04, 0.06), "opakowanie")]


static func _pancerz(id: String) -> Array:
	match id:
		"helm_wz67":
			var k := Color(0.55, 0.62, 0.45)
			var cz := []
			# kopuła z pierścieni (od ronda w górę), pasek podbródkowy
			var n := 6
			for i in n:
				var a0 := float(i) / n * PI * 0.5
				var a1 := float(i + 1) / n * PI * 0.5
				cz.append(_w(Vector3(0, 0.012 + sin(a0) * 0.11, 0), Vector3(0, 0.012 + sin(a1) * 0.11, 0), cos(a0) * 0.12, cos(a1) * 0.12 + 0.001, "metal_jasny", 14, k))
			cz.append(_w(Vector3(0, 0, 0), Vector3(0, 0.012, 0), 0.135, 0.125, "metal_jasny", 14, k))
			cz.append(_b(Vector3(0.0, 0.004, 0.12), Vector3(0.012, 0.006, 0.08), "skora_npc", 0.0))
			return cz
		_:
			var ciezka := id == "kamizelka_kl4"
			var k := Color(0.3, 0.33, 0.24) if ciezka else Color(0.24, 0.28, 0.4)
			var g := 0.06 if ciezka else 0.04
			var cz := [
				{"t": "box", "c": Vector3(0, g * 0.5, 0.02), "s": Vector3(0.36, g, 0.44), "m": "tkanina", "f": 0.02, "k": k, "r": Vector3.ZERO},
				{"t": "box", "c": Vector3(0, g + 0.004, 0.0), "s": Vector3(0.28, 0.01, 0.3), "m": "tkanina", "f": 0.01, "k": k.darkened(0.15), "r": Vector3.ZERO},
			]
			for sx in [-0.11, 0.11]:
				cz.append({"t": "box", "c": Vector3(sx, g * 0.4, -0.23), "s": Vector3(0.07, g * 0.8, 0.08), "m": "tkanina", "f": 0.01, "k": k, "r": Vector3.ZERO})
			for sz in [-0.1, 0.12]:
				cz.append(_b(Vector3(0.0, g + 0.01, sz), Vector3(0.3, 0.004, 0.025), "bakelit", 0.0))
			if not ciezka:
				cz.append(_b(Vector3(0.0, g + 0.012, 0.0), Vector3(0.09, 0.002, 0.03), "bandaz", 0.0, Color(0.9, 0.85, 0.2)))
			return cz


static func _lup(id: String) -> Array:
	match id:
		"zegarek":
			return [_w(Vector3(0, 0, 0), Vector3(0, 0.01, 0), 0.018, 0.018, "zegarek", 12),
				_w(Vector3(0, 0.01, 0), Vector3(0, 0.011, 0), 0.015, 0.015, "tarcza", 12),
				_b(Vector3(0, 0.002, 0.045), Vector3(0.018, 0.003, 0.055), "pasek", 0.001),
				_b(Vector3(0, 0.002, -0.045), Vector3(0.018, 0.003, 0.055), "pasek", 0.001)]
		"wodka", "spirytus":
			var szk := Color(0.75, 0.85, 0.82) if id == "wodka" else Color(0.5, 0.35, 0.2)
			var dl := 0.24 if id == "wodka" else 0.14
			var r := 0.034 if id == "wodka" else 0.026
			# butelka leży
			return [_w(Vector3(0, r, dl * 0.5), Vector3(0, r, -dl * 0.2), r, r, "metal_jasny", 12, szk),
				_w(Vector3(0, r, -dl * 0.2), Vector3(0, r, -dl * 0.35), r, r * 0.35, "metal_jasny", 12, szk),
				_w(Vector3(0, r, -dl * 0.35), Vector3(0, r, -dl * 0.5), r * 0.33, r * 0.33, "metal_jasny", 10, szk),
				_w(Vector3(0, r, -dl * 0.5), Vector3(0, r, -dl * 0.5 - 0.012), r * 0.36, r * 0.36, "czerwony" if id == "wodka" else "metal", 10),
				_w(Vector3(0, r, dl * 0.35), Vector3(0, r, -dl * 0.05), r + 0.0008, r + 0.0008, "bandaz", 12, Color(0.92, 0.9, 0.85) if id == "wodka" else Color(0.95, 0.95, 0.9))]
		"papierosy":
			return [_b(Vector3(0, 0.011, 0), Vector3(0.056, 0.022, 0.088), "opakowanie", 0.002, Color(0.95, 0.85, 0.6)),
				_b(Vector3(0, 0.0225, 0.02), Vector3(0.05, 0.001, 0.03), "czerwony", 0.0)]
		"konserwa":
			return [_w(Vector3(0, 0, 0), Vector3(0, 0.042, 0), 0.042, 0.042, "metal_jasny", 14),
				_w(Vector3(0, 0.01, 0), Vector3(0, 0.032, 0), 0.0425, 0.0425, "bandaz", 14, Color(0.75, 0.6, 0.35)),
				_w(Vector3(0, 0.042, 0), Vector3(0, 0.044, 0), 0.04, 0.04, "metal_jasny", 14)]
		"lampa_elektronowa":
			return [_w(Vector3(0, 0.014, 0.04), Vector3(0, 0.014, 0.02), 0.014, 0.014, "bakelit", 10),
				_w(Vector3(0, 0.014, 0.02), Vector3(0, 0.014, -0.05), 0.013, 0.012, "metal_jasny", 10, Color(0.7, 0.75, 0.75)),
				_w(Vector3(0, 0.014, 0.0), Vector3(0, 0.014, -0.03), 0.007, 0.007, "metal", 8)]
		"akumulator":
			return [_b(Vector3(0, 0.05, 0), Vector3(0.12, 0.1, 0.07), "bakelit", 0.005),
				_w(Vector3(-0.035, 0.1, 0), Vector3(-0.035, 0.112, 0), 0.008, 0.007, "metal", 8),
				_w(Vector3(0.035, 0.1, 0), Vector3(0.035, 0.112, 0), 0.008, 0.007, "czerwony", 8),
				_b(Vector3(0, 0.07, 0.0355), Vector3(0.07, 0.025, 0.001), "bandaz", 0.0, Color(0.9, 0.85, 0.3))]
		"kaseta":
			return [_b(Vector3(0, 0.006, 0), Vector3(0.1, 0.012, 0.064), "bakelit", 0.002),
				_b(Vector3(0, 0.0125, -0.006), Vector3(0.08, 0.001, 0.03), "bandaz", 0.0, Color(0.9, 0.88, 0.8)),
				_w(Vector3(-0.022, 0.012, 0.0), Vector3(-0.022, 0.0135, 0.0), 0.007, 0.007, "czern", 8),
				_w(Vector3(0.022, 0.012, 0.0), Vector3(0.022, 0.0135, 0.0), 0.007, 0.007, "czern", 8)]
		"teczka_akt":
			return [_b(Vector3(0, 0.008, 0), Vector3(0.23, 0.016, 0.32), "opakowanie", 0.003, Color(0.75, 0.62, 0.42)),
				_b(Vector3(0, 0.0165, -0.08), Vector3(0.12, 0.001, 0.04), "czerwony", 0.0),
				_b(Vector3(0.0, 0.017, 0.155), Vector3(0.004, 0.002, 0.03), "bandaz", 0.0)]
		"lancuszek":
			var cz := []
			for i in 10:
				var a := float(i) / 10.0 * TAU
				cz.append(_w(Vector3(cos(a) * 0.03, 0.002, sin(a) * 0.022), Vector3(cos(a + 0.6) * 0.03, 0.002, sin(a + 0.6) * 0.022), 0.0025, 0.0025, "mosiadz", 6))
			cz.append(_b(Vector3(0.0, 0.003, 0.03), Vector3(0.012, 0.004, 0.016), "mosiadz", 0.002))
			return cz
		"radio":
			return [_b(Vector3(0, 0.04, 0), Vector3(0.18, 0.08, 0.05), "skora_npc", 0.008),
				_b(Vector3(-0.035, 0.04, 0.026), Vector3(0.09, 0.06, 0.002), "metal", 0.0),
				_b(Vector3(0.055, 0.05, 0.026), Vector3(0.05, 0.02, 0.003), "bandaz", 0.0, Color(0.9, 0.85, 0.6)),
				_w(Vector3(0.055, 0.025, 0.025), Vector3(0.055, 0.025, 0.032), 0.009, 0.009, "bakelit", 8),
				_w(Vector3(0.08, 0.08, -0.01), Vector3(0.08, 0.2, -0.01), 0.002, 0.0015, "metal_jasny", 6)]
		"klucz_nastawny":
			return [_b(Vector3(0, 0.005, 0.03), Vector3(0.022, 0.01, 0.15), "metal_jasny", 0.002),
				_b(Vector3(0, 0.006, -0.06), Vector3(0.05, 0.012, 0.04), "metal_jasny", 0.003),
				_b(Vector3(0.008, 0.006, -0.085), Vector3(0.012, 0.012, 0.02), "metal_jasny", 0.002)]
		"przewody":
			var cz2 := []
			for i in 3:
				cz2.append(_w(Vector3(0, 0.006 + i * 0.008, 0), Vector3(0, 0.013 + i * 0.008, 0), 0.06, 0.06, "miedz", 14))
			cz2.append(_w(Vector3(0, 0.0, 0), Vector3(0, 0.03, 0), 0.04, 0.04, "czern", 12))
			return cz2
		"kartka_mieso":
			return [_b(Vector3(0, 0.001, 0), Vector3(0.08, 0.002, 0.12), "bandaz", 0.0, Color(0.92, 0.75, 0.75)),
				_b(Vector3(0, 0.0022, 0.02), Vector3(0.06, 0.0005, 0.005), "czern", 0.0)]
		"maszyna_do_pisania":
			return [_b(Vector3(0, 0.04, 0.02), Vector3(0.3, 0.08, 0.26), "metal_jasny", 0.012, Color(0.45, 0.48, 0.42)),
				_b(Vector3(0, 0.07, 0.09), Vector3(0.26, 0.02, 0.12), "czern", 0.004, Color(0.6, 0.6, 0.6)),
				_w(Vector3(-0.17, 0.11, -0.07), Vector3(0.17, 0.11, -0.07), 0.025, 0.025, "bakelit", 12),
				_b(Vector3(0, 0.1, -0.03), Vector3(0.22, 0.03, 0.06), "metal_jasny", 0.006, Color(0.45, 0.48, 0.42))]
		"kanister":
			return [_b(Vector3(0, 0.08, 0), Vector3(0.34, 0.16, 0.13), "metal_jasny", 0.012, Color(0.6, 0.18, 0.12)),
				_b(Vector3(-0.08, 0.08, 0.0), Vector3(0.12, 0.14, 0.135), "metal", 0.0, Color(0.5, 0.15, 0.1)),
				_b(Vector3(0.18, 0.11, 0.0), Vector3(0.03, 0.035, 0.03), "metal_jasny", 0.004, Color(0.4, 0.4, 0.38))]
		"telefon":
			return [_b(Vector3(0, 0.035, 0), Vector3(0.2, 0.07, 0.22), "bakelit", 0.02, Color(0.5, 0.2, 0.15)),
				_w(Vector3(0, 0.072, 0.02), Vector3(0, 0.076, 0.02), 0.055, 0.055, "bandaz", 14, Color(0.9, 0.88, 0.8)),
				_b(Vector3(0, 0.095, -0.03), Vector3(0.22, 0.03, 0.05), "bakelit", 0.012, Color(0.5, 0.2, 0.15))]
		"gasnica":
			return [_w(Vector3(0, 0.055, 0.15), Vector3(0, 0.055, -0.14), 0.055, 0.055, "metal_jasny", 14, Color(0.8, 0.15, 0.12)),
				_w(Vector3(0, 0.055, -0.14), Vector3(0, 0.055, -0.17), 0.05, 0.02, "metal_jasny", 12, Color(0.8, 0.15, 0.12)),
				_b(Vector3(0, 0.06, -0.2), Vector3(0.03, 0.04, 0.06), "metal", 0.004),
				_b(Vector3(0, 0.055, 0.0), Vector3(0.112, 0.06, 0.12), "bandaz", 0.0, Color(0.9, 0.9, 0.85))]
		"lornetka":
			var cz3 := []
			for sx in [-0.034, 0.034]:
				cz3.append(_w(Vector3(sx, 0.028, 0.06), Vector3(sx, 0.028, -0.04), 0.024, 0.026, "guma", 12))
				cz3.append(_w(Vector3(sx, 0.028, 0.06), Vector3(sx, 0.028, 0.08), 0.013, 0.013, "metal", 10))
			cz3.append(_b(Vector3(0, 0.03, 0.04), Vector3(0.04, 0.016, 0.03), "metal", 0.003))
			return cz3
		"maska_gazowa":
			return [_w(Vector3(0, 0.0, 0), Vector3(0, 0.07, 0), 0.085, 0.07, "guma", 12, Color(0.45, 0.5, 0.4)),
				_w(Vector3(-0.035, 0.07, -0.02), Vector3(-0.035, 0.074, -0.02), 0.022, 0.022, "metal_jasny", 10, Color(0.6, 0.7, 0.7)),
				_w(Vector3(0.035, 0.07, -0.02), Vector3(0.035, 0.074, -0.02), 0.022, 0.022, "metal_jasny", 10, Color(0.6, 0.7, 0.7)),
				_w(Vector3(0, 0.04, 0.07), Vector3(0, 0.04, 0.12), 0.035, 0.035, "metal_jasny", 12, Color(0.4, 0.45, 0.35))]
		"kombinerki":
			return [_b(Vector3(-0.012, 0.006, 0.04), Vector3(0.012, 0.012, 0.1), "czerwony", 0.003, Color.WHITE, Vector3(0, 6, 0)),
				_b(Vector3(0.012, 0.006, 0.04), Vector3(0.012, 0.012, 0.1), "czerwony", 0.003, Color.WHITE, Vector3(0, -6, 0)),
				_b(Vector3(0, 0.007, -0.04), Vector3(0.028, 0.014, 0.07), "metal_jasny", 0.004)]
		"tasma":
			return [_w(Vector3(0, 0, 0), Vector3(0, 0.022, 0), 0.04, 0.04, "guma", 14, Color(0.3, 0.3, 0.32)),
				_w(Vector3(0, 0.0005, 0), Vector3(0, 0.0225, 0), 0.021, 0.021, "opakowanie", 12, Color(0.75, 0.65, 0.45)),
				_b(Vector3(0.05, 0.001, 0.01), Vector3(0.04, 0.002, 0.018), "guma", 0.0, Color(0.3, 0.3, 0.32))]
		"zestaw_czyszczacy":
			return [_b(Vector3(0, 0.015, 0), Vector3(0.14, 0.03, 0.07), "metal_jasny", 0.006, Color(0.45, 0.5, 0.35)),
				_w(Vector3(-0.1, 0.006, 0.05), Vector3(0.14, 0.006, 0.05), 0.003, 0.003, "metal_jasny", 6),
				_w(Vector3(0.06, 0.0, -0.06), Vector3(0.06, 0.03, -0.06), 0.015, 0.015, "mosiadz", 10)]
		"ikona":
			return [_b(Vector3(0, 0.01, 0), Vector3(0.18, 0.02, 0.24), "drewno", 0.006),
				_b(Vector3(0, 0.0205, 0), Vector3(0.14, 0.001, 0.2), "mosiadz", 0.0),
				_b(Vector3(0, 0.0215, 0.01), Vector3(0.06, 0.001, 0.08), "skora_npc", 0.0)]
	return [_b(Vector3(0, 0.03, 0), Vector3(0.1, 0.06, 0.08), "opakowanie", 0.004, Color(0.7, 0.65, 0.55))]
