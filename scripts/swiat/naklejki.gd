class_name Naklejki
extends RefCounted
## Ślady na ścianach i podłogach (atlas naklejki.png): pęknięcia, zacieki spod sufitu, graffiti, dziury po kulach,
## okopcenia, odpadający tynk, stare ogłoszenia, plamy. Kładzione promieniami z wnętrza pomieszczeń na ściany
## generatora („Sciany”) – tylko tam, gdzie cała naklejka leży na płaskiej ścianie (bez otworów i narożników).
## Jedna siatka na kondygnację.

static var _dane: Dictionary = {}
static var pozycje: Array = []   # ostatnio położone strzałki [pozycja, normalna, id] – do testów
static var drzwi: Array = []     # środki otworów drzwiowych (Vector3) – naklejki trzymają się od nich z daleka


static func _przy_drzwiach(p: Vector3, polsz: float) -> bool:
	for d in drzwi:
		var dd := Vector2((d as Vector3).x - p.x, (d as Vector3).z - p.z).length()
		if dd < polsz + 0.75 and absf((d as Vector3).y - p.y) < 2.5:
			return true
	return false
static var _mat: ShaderMaterial


## Kubełki siatek w kratce 9 m: renderer Compatibility oświetla obiekt ograniczoną liczbą najbliższych lamp,
## więc jedna siatka na całe piętro byłaby oświetlona lampami z jednego miejsca (reszta naklejek – tylko ambient).
class Kubelki:
	extends RefCounted
	var st := {}     # Vector3i -> SurfaceTool
	var ile := 0

	func quad(pts: Array, uv: Array, nrm: Vector3) -> void:
		var c: Vector3 = (pts[0] + pts[2]) * 0.5
		var k := Vector3i(floori(c.x / 9.0), floori(c.y / 2.5), floori(c.z / 9.0))
		if not st.has(k):
			var t := SurfaceTool.new()
			t.begin(Mesh.PRIMITIVE_TRIANGLES)
			st[k] = t
		var s: SurfaceTool = st[k]
		for i in [0, 2, 1, 0, 3, 2]:
			s.set_normal(nrm)
			s.set_uv(uv[i])
			s.add_vertex(pts[i])
		ile += 1

	func wezly(rodzic: Node3D, nazwa: String, mat: Material, warstwy: int) -> Node3D:
		var n := Node3D.new()
		n.name = nazwa
		rodzic.add_child(n)
		n.global_position = Vector3.ZERO
		for k in st:
			var mi := MeshInstance3D.new()
			mi.mesh = (st[k] as SurfaceTool).commit()
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if warstwy > 0:
				mi.layers = warstwy
			n.add_child(mi)
		n.set_meta("ile", ile)
		return n


static func dane() -> Dictionary:
	if _dane.is_empty():
		_dane = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dane/naklejki.json"))
	return _dane


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/naklejka.gdshader")
		_mat.set_shader_parameter("albedo_tex", load("res://assets/textures/naklejki.png"))
	return _mat


static func _losuj(rng: RandomNumberGenerator, miejsca: Array) -> String:
	var el: Dictionary = dane()["elementy"]
	var suma := 0.0
	for k in el:
		if String(el[k]["miejsce"]) in miejsca:
			suma += float(el[k]["waga"])
	var r := rng.randf() * suma
	for k in el:
		if String(el[k]["miejsce"]) in miejsca:
			r -= float(el[k]["waga"])
			if r <= 0.0:
				return k
	return ""


static func _sciana(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, Balistyka.WARSTWA_SWIAT)
	var r := space.intersect_ray(q)
	if r.is_empty():
		return {}
	var c: Node = r["collider"]
	if c == null or not String(c.name).begins_with("Sciany"):
		return {}
	return r


## komorki: {klucz: {"typ", "rect"}}; podloga_y: wysokość podłogi; wys: wysokość pomieszczeń; rodzic: węzeł kondygnacji.
static func rozmiesc(rodzic: Node3D, space: PhysicsDirectSpaceState3D, komorki: Dictionary, podloga_y: float, wys: float, rng: RandomNumberGenerator, warstwy := 0) -> Node3D:
	var kub := Kubelki.new()
	var el: Dictionary = dane()["elementy"]
	var A := float(dane()["atlas"])
	var ile := 0
	var polozone: Array = []    # [środek, promień] – naklejki nie nachodzą na siebie (ani na strzałki do wyjść)
	for ps in pozycje:
		polozone.append([ps[0], 1.2])
	for k in komorki:
		var kom: Dictionary = komorki[k]
		var rr: Rect2 = kom["rect"]
		var typ := String(kom.get("typ", ""))
		# więcej śladów w korytarzach, klatkach, piwnicach i warsztatach
		var n := rng.randi_range(2, 4) + (3 if typ in ["korytarz", "klatka", "piwnica", "warsztat", "magazyn"] else 0)
		var proby := 0
		while n > 0 and proby < n * 6:
			proby += 1
			var podl := rng.randf() < 0.18
			var id := _losuj(rng, ["podloga"] if podl else ["sciana", "sciana_gora", "sciana_dol"])
			if id == "":
				continue
			var e: Dictionary = el[id]
			var sz := Vector2(float(e["m"][0]), float(e["m"][1]))
			var skala := rng.randf_range(0.85, 1.15)
			sz *= skala
			var srodek := Vector3(rng.randf_range(rr.position.x + 0.6, rr.end.x - 0.6), podloga_y, rng.randf_range(rr.position.y + 0.6, rr.end.y - 0.6))
			var p0: Vector3
			var nrm: Vector3
			var gora: Vector3
			if podl:
				var r0 := _sciana(space, srodek + Vector3.UP * 0.5, srodek - Vector3.UP * 0.3)
				# podłoga należy do „Sciany”? – jeśli nie, rzut na wysokość podłogi
				p0 = Vector3(srodek.x, podloga_y + 0.004, srodek.z) if r0.is_empty() else (r0["position"] as Vector3) + Vector3.UP * 0.004
				nrm = Vector3.UP
				var kat := rng.randf() * TAU
				gora = Vector3(cos(kat), 0, sin(kat))
			else:
				var kat2 := rng.randf() * TAU
				var kier := Vector3(cos(kat2), 0, sin(kat2))
				var miejsce := String(e["miejsce"])
				var h: float
				match miejsce:
					"sciana_gora":
						h = wys - sz.y * 0.5 - 0.02
					"sciana_dol":
						h = sz.y * 0.5 + rng.randf_range(0.0, 0.25)
					_:
						h = rng.randf_range(maxf(0.9, sz.y * 0.5 + 0.2), minf(2.0, wys - sz.y * 0.5 - 0.1))
				var r1 := _sciana(space, srodek + Vector3.UP * h, srodek + Vector3.UP * h + kier * 12.0)
				if r1.is_empty():
					continue
				nrm = r1["normal"]
				if absf(nrm.y) > 0.1:
					continue
				p0 = (r1["position"] as Vector3) + nrm * 0.006
				gora = Vector3.UP
			var prawo := gora.cross(nrm).normalized()
			# cała naklejka na płaskiej powierzchni: 4 narożniki muszą trafić w tę samą płaszczyznę
			var ok := true
			for sx in [-0.5, 0.5]:
				for sy in [-0.5, 0.5]:
					var c: Vector3 = p0 + prawo * sz.x * float(sx) + gora * sz.y * float(sy)
					var rc := _sciana(space, c + nrm * 0.15, c - nrm * 0.15)
					if rc.is_empty() or (rc["normal"] as Vector3).dot(nrm) < 0.98 or absf((rc["position"] as Vector3).distance_to(c) - 0.006) > 0.03:
						ok = false
			if not ok and not podl:
				continue
			var prom := sz.length() * 0.5
			if not podl and _przy_drzwiach(p0, sz.x * 0.5):
				continue
			var koliduje := false
			for pl in polozone:
				if (pl[0] as Vector3).distance_to(p0) < (prom + float(pl[1])) * 0.85:
					koliduje = true
					break
			if koliduje:
				continue
			polozone.append([p0, prom])
			var re: Array = e["rect"]
			var u0 := float(re[0]) / A
			var v0 := float(re[1]) / A
			var u1 := (float(re[0]) + float(re[2])) / A
			var v1 := (float(re[1]) + float(re[3])) / A
			var odbij := rng.randf() < 0.5 and (id.begins_with("pekniecie") or id.begins_with("plama") or id.begins_with("dziury") or id.begins_with("tynk"))
			if odbij:
				var t := u0
				u0 = u1
				u1 = t
			var pts := [p0 - prawo * sz.x * 0.5 - gora * sz.y * 0.5, p0 + prawo * sz.x * 0.5 - gora * sz.y * 0.5,
				p0 + prawo * sz.x * 0.5 + gora * sz.y * 0.5, p0 - prawo * sz.x * 0.5 + gora * sz.y * 0.5]
			var uv := [Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), Vector2(u0, v0)]
			kub.quad(pts, uv, nrm)
			ile += 1
			n -= 1
	if ile == 0:
		return null
	return kub.wezly(rodzic, "Naklejki", material(), warstwy)


## Strzałki do wyjść malowane przez poprzedników: wzdłuż ścieżek nawigacji ze startu i z kilku punktów mapy
## do każdego wyjścia, co ok. 12 m ścieżki, na ścianie obok (strona i kierunek strzałki wg biegu ścieżki).
## Jeden fałszywy trop na mapę (strzałki z nazwą wyjścia prowadzą w ślepy zaułek – szabrownicy lubią gości).
## Zwraca [węzeł parteru, węzeł piętra] (każdy może być null).
static func strzalki(swiat: Node3D, space: PhysicsDirectSpaceState3D, wyjscia: Array, zrodla: Array, pietro_y: float, rng: RandomNumberGenerator, warstwy: Array = [0, 0], falszywe_cele: Array = []) -> Array:
	var mapa := swiat.get_world_3d().navigation_map
	var kub := [Kubelki.new(), Kubelki.new()]
	var stan := {"polozone": [], "ile": [0, 0]}
	pozycje.clear()
	var klucze := []
	for w in wyjscia:
		var ew := w as Ewakuacja
		var klucz := "brama" if ew.nazwa.contains("Brama") else ("piwnica" if ew.nazwa.contains("Piwnica") else "okno")
		klucze.append(klucz)
		var cel := NavigationServer3D.map_get_closest_point(mapa, ew.global_position)
		for z in zrodla:
			var od := NavigationServer3D.map_get_closest_point(mapa, z as Vector3)
			var sciezka := NavigationServer3D.map_get_path(mapa, od, cel, true)
			_trasa(space, sciezka, cel, klucz, rng, pietro_y, kub, stan, 999, false)
	# fałszywy trop: z losowego punktu do głębokiego zaułka, 2–3 strzałki z nazwą prawdziwego wyjścia
	if not falszywe_cele.is_empty() and zrodla.size() > 1 and not klucze.is_empty():
		var od2 := NavigationServer3D.map_get_closest_point(mapa, zrodla[1 + rng.randi() % (zrodla.size() - 1)] as Vector3)
		var cel2 := NavigationServer3D.map_get_closest_point(mapa, falszywe_cele[rng.randi() % falszywe_cele.size()] as Vector3)
		var sc2 := NavigationServer3D.map_get_path(mapa, od2, cel2, true)
		_trasa(space, sc2, cel2, String(klucze[rng.randi() % klucze.size()]), rng, pietro_y, kub, stan, 3, true)
	var out := []
	for k in 2:
		out.append(null if int(stan["ile"][k]) == 0 else (kub[k] as Kubelki).wezly(swiat, "Strzalki", material(), int(warstwy[k])))
	return out


static func _trasa(space: PhysicsDirectSpaceState3D, sciezka: PackedVector3Array, cel: Vector3, klucz: String, rng: RandomNumberGenerator,
		pietro_y: float, kub: Array, stan: Dictionary, limit: int, falszywa: bool) -> void:
	if sciezka.size() < 2:
		return
	var el: Dictionary = dane()["elementy"]
	var A := float(dane()["atlas"])
	var polozone: Array = stan["polozone"]
	var postawione := 0
	var przebyte := 0.0
	var nastepna := rng.randf_range(5.0, 9.0)
	for i in range(1, sciezka.size()):
		var a: Vector3 = sciezka[i - 1]
		var b: Vector3 = sciezka[i]
		var dl := a.distance_to(b)
		while przebyte + dl >= nastepna:
			var t := (nastepna - przebyte) / maxf(dl, 0.001)
			var p := a.lerp(b, t)
			nastepna += rng.randf_range(10.0, 14.0) if not falszywa else rng.randf_range(6.0, 9.0)
			var kier := b - a
			kier.y = 0.0
			if kier.length() < 0.01 or p.distance_to(cel) < 4.0 or postawione >= limit:
				continue
			kier = kier.normalized()
			var bok := kier.cross(Vector3.UP)
			for strona_bok in [bok, -bok]:
				var r := _sciana(space, p + Vector3.UP * 1.45, p + Vector3.UP * 1.45 + strona_bok * 3.5)
				if r.is_empty() or absf((r["normal"] as Vector3).y) > 0.1:
					continue
				var nrm: Vector3 = r["normal"]
				var prawo := Vector3.UP.cross(nrm).normalized()
				var id := "strzalka_%s_%s" % [klucz, "p" if kier.dot(prawo) > 0.0 else "l"]
				var e: Dictionary = el[id]
				var sz := Vector2(float(e["m"][0]), float(e["m"][1]))
				var p0: Vector3 = (r["position"] as Vector3) + nrm * 0.007
				var zly := _przy_drzwiach(p0, sz.x * 0.5)
				for pl in polozone:
					if (pl as Vector3).distance_to(p0) < 3.5:
						zly = true
				if zly:
					break
				var ok := true
				for sx in [-0.5, 0.5]:
					for sy in [-0.5, 0.5]:
						var c: Vector3 = p0 + prawo * sz.x * float(sx) + Vector3.UP * sz.y * float(sy)
						var rc := _sciana(space, c + nrm * 0.15, c - nrm * 0.15)
						if rc.is_empty() or (rc["normal"] as Vector3).dot(nrm) < 0.98:
							ok = false
				if not ok:
					continue
				polozone.append(p0)
				pozycje.append([p0, nrm, id, falszywa])
				var re: Array = e["rect"]
				var u0 := float(re[0]) / A
				var v0 := float(re[1]) / A
				var u1 := (float(re[0]) + float(re[2])) / A
				var v1 := (float(re[1]) + float(re[3])) / A
				var pts := [p0 - prawo * sz.x * 0.5 - Vector3.UP * sz.y * 0.5, p0 + prawo * sz.x * 0.5 - Vector3.UP * sz.y * 0.5,
					p0 + prawo * sz.x * 0.5 + Vector3.UP * sz.y * 0.5, p0 - prawo * sz.x * 0.5 + Vector3.UP * sz.y * 0.5]
				var uv := [Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), Vector2(u0, v0)]
				var gorne := p0.y > pietro_y - 0.6
				(kub[1 if gorne else 0] as Kubelki).quad(pts, uv, nrm)
				stan["ile"][1 if gorne else 0] += 1
				postawione += 1
				break
		przebyte += dl


static var znaki_gracza: Array = []   # [pozycja, normalna, id] – znaki namalowane przez gracza (mapa)


## Znak namalowany przez gracza sprayem: jeden czworokąt na ścianie (oświetlany jak ściana).
static func znak_gracza(rodzic: Node3D, pos: Vector3, nrm: Vector3, id: String, warstwy := 0) -> MeshInstance3D:
	var el: Dictionary = dane()["elementy"]
	if not el.has(id):
		return null
	var e: Dictionary = el[id]
	var A := float(dane()["atlas"])
	var sk := 0.7 if id.contains("strzalka") else 0.9
	var sz := Vector2(float(e["m"][0]), float(e["m"][1])) * sk
	var prawo := Vector3.UP.cross(nrm).normalized()
	var p0 := pos + nrm * 0.008
	var re: Array = e["rect"]
	var u0 := float(re[0]) / A
	var v0 := float(re[1]) / A
	var u1 := (float(re[0]) + float(re[2])) / A
	var v1 := (float(re[1]) + float(re[3])) / A
	var pts := [p0 - prawo * sz.x * 0.5 - Vector3.UP * sz.y * 0.5, p0 + prawo * sz.x * 0.5 - Vector3.UP * sz.y * 0.5,
		p0 + prawo * sz.x * 0.5 + Vector3.UP * sz.y * 0.5, p0 - prawo * sz.x * 0.5 + Vector3.UP * sz.y * 0.5]
	var uv := [Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), Vector2(u0, v0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_normal(nrm)
		st.set_uv(uv[i])
		st.add_vertex(pts[i])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if warstwy > 0:
		mi.layers = warstwy
	rodzic.add_child(mi)
	znaki_gracza.append([pos, nrm, id])
	return mi
