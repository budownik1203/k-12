class_name Tkanina
extends RefCounted
## Miękkie bryły z tkaniny dla plecaków, worków i kamizelek: powierzchnie parametryczne (obrotowe
## o przekroju zaokrąglonego prostokąta), z fałdami i cieniowaniem w zagłębieniach (kolor wierzchołków),
## dwustronne (ciemna podszewka od środka), z drugim kształtem jako blend shape "otw" – dzięki temu
## worek naprawdę rozszerza się u góry, kołnierz plecaka rozluźnia, a wylot ładownicy rozchyla.

const B := preload("res://scripts/core/bryly.gd")

static var _mat := {}


static func material(k: Color, nazwa := "tkanina", vm := true) -> ShaderMaterial:
	var klucz := "%s|%s|%s" % [k.to_html(), nazwa, vm]
	if not _mat.has(klucz):
		var m := (B.material(nazwa, vm, k) as ShaderMaterial).duplicate() as ShaderMaterial
		m.set_shader_parameter("use_vertex_color", true)
		_mat[klucz] = m
	return _mat[klucz]


## Siatka nu×nv z funkcji f(u, v) -> Vector3 (u, v w 0..1). f2 – kształt po otwarciu (albo pusty Callable).
## opcje: "ao": Callable(u, v) -> jasność 0..1, "podszewka": Color (druga strona; brak = jednostronna),
## "zawin_u": bool (u zawija się – przekrój zamknięty), "uv": skala UV.
static func powierzchnia(nu: int, nv: int, f: Callable, f2: Callable, k: Color, opcje := {}) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var z_blend := f2.is_valid()
	if z_blend:
		mesh.add_blend_shape("otw")
		mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	var zawin: bool = opcje.get("zawin_u", true)
	var uvs: float = opcje.get("uv", 3.0)
	var ao: Callable = opcje.get("ao", Callable())
	var siatki := [_punkty(nu, nv, f)]
	if z_blend:
		siatki.append(_punkty(nu, nv, f2))
	var normalne := []
	for s in siatki:
		normalne.append(_normalne(s, nu, nv, zawin))
	var strony := [[k, 1.0]]
	if opcje.has("podszewka"):
		strony.append([opcje["podszewka"], -1.0])
	for st in strony:
		var znak: float = st[1]
		var arrs := []
		for si in siatki.size():
			var P: Array = siatki[si]
			var N: Array = normalne[si]
			var V := PackedVector3Array()
			var NN := PackedVector3Array()
			for j in nv + 1:
				for i in nu + 1:
					V.append(P[j][i])
					NN.append(N[j][i] * znak)
			arrs.append([V, NN])
		var UV := PackedVector2Array()
		var C := PackedColorArray()
		for j in nv + 1:
			for i in nu + 1:
				var u := float(i) / nu
				var v := float(j) / nv
				UV.append(Vector2(u * uvs, v * uvs * 0.7))
				var a := 1.0 if not ao.is_valid() else float(ao.call(u, v))
				if znak < 0.0:
					a *= 0.75
				C.append(Color(a, a, a))
		var I := PackedInt32Array()
		var P0: Array = siatki[0]
		var N0: Array = normalne[0]
		for j in nv:
			for i in nu:
				var a0 := j * (nu + 1) + i
				var a1 := a0 + 1
				var b0 := a0 + nu + 1
				var b1 := b0 + 1
				for tr in [[a0, a1, b1], [a0, b1, b0]]:
					var p0: Vector3 = P0[tr[0] / (nu + 1)][tr[0] % (nu + 1)]
					var p1: Vector3 = P0[tr[1] / (nu + 1)][tr[1] % (nu + 1)]
					var p2: Vector3 = P0[tr[2] / (nu + 1)][tr[2] % (nu + 1)]
					var n: Vector3 = (N0[tr[0] / (nu + 1)][tr[0] % (nu + 1)] + N0[tr[1] / (nu + 1)][tr[1] % (nu + 1)] + N0[tr[2] / (nu + 1)][tr[2] % (nu + 1)]) * znak
					# kolejność jak w Bryly: iloczyn wektorowy przeciwny do normalnej = przód
					if (p1 - p0).cross(p2 - p0).dot(n) > 0.0:
						I.append_array([tr[0], tr[2], tr[1]])
					else:
						I.append_array(tr)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = arrs[0][0]
		arr[Mesh.ARRAY_NORMAL] = arrs[0][1]
		arr[Mesh.ARRAY_TEX_UV] = UV
		arr[Mesh.ARRAY_COLOR] = C
		arr[Mesh.ARRAY_INDEX] = I
		var bl := []
		if z_blend:
			var b := []
			b.resize(Mesh.ARRAY_MAX)
			b[Mesh.ARRAY_VERTEX] = arrs[1][0]
			b[Mesh.ARRAY_NORMAL] = arrs[1][1]
			bl.append(b)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, bl)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(st[0], String(opcje.get("mat", "tkanina")), bool(opcje.get("vm", true))))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _punkty(nu: int, nv: int, f: Callable) -> Array:
	var P := []
	for j in nv + 1:
		var w := []
		for i in nu + 1:
			w.append(f.call(float(i) / nu, float(j) / nv))
		P.append(w)
	return P


static func _normalne(P: Array, nu: int, nv: int, zawin: bool) -> Array:
	var N := []
	for j in nv + 1:
		var w := []
		for i in nu + 1:
			var il := i - 1
			var ip := i + 1
			if zawin:
				if il < 0:
					il = nu - 1
				if ip > nu:
					ip = 1
			else:
				il = maxi(0, il)
				ip = mini(nu, ip)
			var jl := maxi(0, j - 1)
			var jp := mini(nv, j + 1)
			var du: Vector3 = P[j][ip] - P[j][il]
			var dv: Vector3 = P[jp][i] - P[jl][i]
			var n := du.cross(dv)
			if n.length() < 1e-9:
				# biegun (środek dna / wierzchołka): normalna z sąsiedniego pierścienia
				var jj := 1 if j == 0 else nv - 1
				var c := Vector3.ZERO
				for q in nu:
					c += P[jj][q]
				c /= nu
				n = (P[j][i] - c).normalized()
				if n.length() < 0.1:
					n = Vector3.DOWN if j == 0 else Vector3.UP
			w.append(n.normalized())
		N.append(w)
	# kierunek: na zewnątrz od środka bryły
	var srodek := Vector3.ZERO
	var ile := 0
	for j in nv + 1:
		for i in nu + 1:
			srodek += P[j][i]
			ile += 1
	srodek /= ile
	var dodatnie := 0
	for j in range(0, nv + 1, maxi(1, nv / 4)):
		for i in range(0, nu + 1, maxi(1, nu / 4)):
			if (N[j][i] as Vector3).dot(P[j][i] - srodek) > 0.0:
				dodatnie += 1
			else:
				dodatnie -= 1
	if dodatnie < 0:
		for j in nv + 1:
			for i in nu + 1:
				N[j][i] = -N[j][i]
	return N


## Punkt przekroju: zaokrąglony prostokąt (superelipsa) o półosiach a (X) i b (Z).
static func przekroj(th: float, a: float, b: float, sup := 4.0) -> Vector2:
	var c := cos(th)
	var s := sin(th)
	return Vector2(signf(c) * pow(absf(c), 2.0 / sup) * a, signf(s) * pow(absf(s), 2.0 / sup) * b)


## Bryła obrotowa: prof(v) -> Vector3(skala przekroju, wysokość y, dodatkowy promień w m),
## fald(th, v) -> względne wybrzuszenie (fałdy, grudy zawartości).
static func obrotowa(a: float, b: float, sup: float, prof: Callable, fald: Callable) -> Callable:
	return func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var pr: Vector3 = prof.call(v)
		var q := przekroj(th, a, b, sup)
		var r: float = pr.x * (1.0 + float(fald.call(th, v)))
		return Vector3(q.x * r + cos(th) * pr.z, pr.y, q.y * r + sin(th) * pr.z)


## Profil miękkiej skrzynki: dno (od środka), zaokrąglona krawędź, ściana, krawędź, wierzch (do środka).
## Zwraca Vector3(skala, y, dodatkowy promień). otwarta = bez wierzchu (kończy się na brzegu u góry).
static func prof_skrzynki(t: float, h: float, rr: float, otwarta := false, wyp := 0.0) -> Vector3:
	if otwarta:
		# dno 0–0,2, krawędź 0,2–0,4, ściana 0,4–1 (do brzegu)
		if t < 0.2:
			return Vector3(t / 0.2, 0.0, 0.0)
		if t < 0.4:
			var a := (t - 0.2) / 0.2 * PI * 0.5
			return Vector3(1.0, rr * (1.0 - cos(a)), rr * sin(a))
		return Vector3(1.0, lerpf(rr, h, (t - 0.4) / 0.6), rr)
	if t < 0.15:
		return Vector3(t / 0.15, 0.0, 0.0)
	if t < 0.3:
		var a2 := (t - 0.15) / 0.15 * PI * 0.5
		return Vector3(1.0, rr * (1.0 - cos(a2)), rr * sin(a2))
	if t < 0.7:
		return Vector3(1.0, lerpf(rr, h - rr, (t - 0.3) / 0.4), rr)
	if t < 0.85:
		var a3 := (t - 0.7) / 0.15 * PI * 0.5
		return Vector3(1.0, h - rr + rr * sin(a3), rr * cos(a3))
	var s := 1.0 - (t - 0.85) / 0.15
	return Vector3(s, h + wyp * (1.0 - s * s), 0.0)


## Poduszka (miękki prostopadłościan): w × h × d, zaokrąglone krawędzie, wypukłe ściany i wierzch.
static func poduszka(w: float, h: float, d: float, k: Color, wyp := 0.04, ziarno := 0, nu := 32, nv := 16) -> MeshInstance3D:
	var rr := minf(h * 0.45, minf(w, d) * 0.3)
	var a := maxf(0.005, w * 0.5 - rr)
	var b := maxf(0.005, d * 0.5 - rr)
	var fz := float(ziarno)
	var prof := func(v: float) -> Vector3: return prof_skrzynki(v, h, rr, false, h * wyp * 2.0)
	var fald := func(th: float, v: float) -> float:
		var sc := clampf((v - 0.3) / 0.4, 0.0, 1.0)
		return (wyp * sin(sc * PI) + 0.012 * sin(th * 5.0 + fz) * sin(v * 9.0 + fz * 0.7)) if v > 0.15 and v < 0.85 else 0.0
	return powierzchnia(nu, nv, obrotowa(a, b, 8.0, prof, fald), Callable(), k,
		{"ao": func(_u, v): return lerpf(0.7, 1.0, clampf(v * 4.0, 0.0, 1.0))})


## Płat tkaniny (klapa): w × d, grubość g, lekko wypukły i opadający na brzegach. Leży w XZ,
## zawias wzdłuż krawędzi z = 0, płat sięga do z = +d. zwis – opadnięcie wolnego brzegu (m).
static func plat(w: float, d: float, g: float, k: Color, zwis := 0.01, wyp := 0.012, ziarno := 0) -> MeshInstance3D:
	var fz := float(ziarno)
	var f := func(u: float, v: float) -> Vector3:
		# u – obwód przekroju (góra/dół płata), v – wzdłuż szerokości; płaski przekrój o promieniu g/2
		var th := u * TAU
		var x := (v - 0.5) * w
		var ex := 1.0 - pow(absf(v - 0.5) * 2.0, 6.0)
		var zz := (0.5 - 0.5 * cos(th)) * d
		var t := zz / d
		var y := sin(th) * g * 0.5 * maxf(0.3, ex)
		y += wyp * sin(t * PI) * ex - zwis * t * t + 0.003 * sin(x * 40.0 + fz) * t
		return Vector3(x, y, zz)
	return powierzchnia(18, 10, func(u, v): return f.call(u, v), Callable(), k,
		{"ao": func(u, _v): return 1.0 if sin(u * TAU) > 0.0 else 0.8})


## Rura (kończyna, szyja, palec): oś od a do b, promień prof(v) (v: 0 przy a, 1 przy b), przekrój elipsa
## spłaszczona `spl`; zamknięte końce (promień schodzi do zera na brzegach v).
static func rura(a: Vector3, b: Vector3, prof: Callable, k: Color, opcje := {}, spl := 1.0, nu := 10, nv := 8) -> MeshInstance3D:
	var os := b - a
	var w := os.normalized()
	var u0 := w.cross(Vector3.UP if absf(w.y) < 0.95 else Vector3.RIGHT).normalized()
	var v0 := w.cross(u0)
	var f := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var r: float = prof.call(v)
		# zaokrąglone końce
		var kon := sin(clampf(v / 0.08, 0.0, 1.0) * PI * 0.5) * sin(clampf((1.0 - v) / 0.08, 0.0, 1.0) * PI * 0.5)
		return a + os * v + (u0 * cos(th) + v0 * sin(th) * spl) * r * kon
	return powierzchnia(nu, nv, f, Callable(), k, opcje)
