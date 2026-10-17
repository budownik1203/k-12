class_name Balistyka
extends RefCounted
## Wspólne zasady trafień: penetracja (kaliber kontra klasa pancerza), zużycie pancerza.

const WARSTWA_SWIAT := 1
const WARSTWA_POSTACIE := 2
const WARSTWA_HITBOX_WROGA := 4
const WARSTWA_HITBOX_GRACZA := 8
const WARSTWA_INTERAKCJE := 16


## Zwraca {"obr": obrażenia po pancerzu, "przebity": bool, "pancerz": bool}.
## pancerze: Dictionary slot -> Przedmiot (np. {"pancerz": p, "helm": h})
static func przez_pancerz(pancerze: Dictionary, czesc: String, obr: float, pen: float) -> Dictionary:
	for slot in pancerze:
		var p: Przedmiot = pancerze[slot]
		if p == null:
			continue
		var pd: Dictionary = p.defn()["pancerz"]
		if czesc not in pd["strefy"]:
			continue
		var maks := float(pd["wytrzymalosc"])
		var wytrz: float = p.dane["wytrz"]
		if wytrz <= 0.0:
			continue
		var klasa := float(pd["klasa"]) * (0.45 + 0.55 * wytrz / maks)
		var prog := klasa * 10.0
		var szansa: float = clampf(0.5 + (pen - prog) / 14.0, 0.03, 0.97)
		if randf() < szansa:
			p.dane["wytrz"] = maxf(0.0, wytrz - pen * 0.12)
			return {"obr": obr * 0.82, "przebity": true, "pancerz": true}
		p.dane["wytrz"] = maxf(0.0, wytrz - obr * 0.07)
		return {"obr": obr * 0.12 + 1.0, "przebity": false, "pancerz": true}
	return {"obr": obr, "przebity": true, "pancerz": false}


## Losowy kierunek w stożku o kącie (stopnie) wokół kierunku bazowego.
static func rozrzut(kierunek: Vector3, kat_deg: float) -> Vector3:
	if kat_deg <= 0.0:
		return kierunek
	var k := deg_to_rad(kat_deg) * sqrt(randf())
	var a := randf() * TAU
	var ortho := kierunek.cross(Vector3.UP)
	if ortho.length() < 0.01:
		ortho = kierunek.cross(Vector3.RIGHT)
	ortho = ortho.normalized()
	var ortho2 := kierunek.cross(ortho).normalized()
	return (kierunek * cos(k) + (ortho * cos(a) + ortho2 * sin(a)) * sin(k)).normalized()
