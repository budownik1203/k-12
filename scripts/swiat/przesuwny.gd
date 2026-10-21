class_name Przesuwny
extends RigidBody3D
## Fizyczny przedmiot do przesuwania: skrzynka, krzesło, beczka, szafka. Przytrzymaj [F] – chwyt: lekkie
## podnosisz przed sobą, ciężkie ciągniesz po podłodze (wolno, głośno). Zasłania (kule i wzrok), blokuje drzwi –
## można nim zabarykadować wejście (wróg musi drzwi wyważyć, przesuwając barykadę – słychać to).

const RODZAJE := {
	"skrzynka": {"nazwa": "Skrzynka", "masa": 14.0, "r": Vector3(0.55, 0.42, 0.4)},
	"krzeslo": {"nazwa": "Krzesło", "masa": 5.0, "r": Vector3(0.44, 0.9, 0.44)},
	"beczka": {"nazwa": "Beczka", "masa": 32.0, "r": Vector3(0.58, 0.88, 0.58)},
	"szafka": {"nazwa": "Szafka", "masa": 42.0, "r": Vector3(0.8, 0.9, 0.42)},
}
const WARSTWA := 32           # przedmioty przesuwne (drzwi sprawdzają, czy coś blokuje skrzydło)

var rodzaj := "skrzynka"
var przejmuje_mysz := false   # chwyt nie zabiera myszy (przedmiot idzie za wzrokiem)
var _odl := 1.2
var _dzw := 0.0
var _chwycony := false


static func nowy(r: String) -> Przesuwny:
	var p := Przesuwny.new()
	p.rodzaj = r
	return p


func _ready() -> void:
	add_to_group("przesuwne")
	var d: Dictionary = RODZAJE[rodzaj]
	mass = float(d["masa"])
	collision_layer = Balistyka.WARSTWA_SWIAT | WARSTWA | Balistyka.WARSTWA_INTERAKCJE
	collision_mask = Balistyka.WARSTWA_SWIAT | WARSTWA
	linear_damp = 1.5
	angular_damp = 3.0
	can_sleep = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8
	physics_material_override = pm
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_uderzenie)
	set_meta("interakcja", self)
	var B := preload("res://scripts/core/bryly.gd")
	var r: Vector3 = d["r"]
	var cz := []
	var ks := BoxShape3D.new()
	ks.size = r
	var ksz: Shape3D = ks
	match rodzaj:
		"skrzynka":
			cz = [B.box(Vector3(0, r.y * 0.5, 0), r, "drewno", 0.01)]
			for y in [0.1, r.y - 0.1]:
				cz.append(B.box(Vector3(0, y, 0), Vector3(r.x + 0.01, 0.05, r.z + 0.01), "drewno_m", 0.004))
		"krzeslo":
			cz = [B.box(Vector3(0, 0.45, 0), Vector3(0.42, 0.04, 0.42), "drewno", 0.004),
				B.box(Vector3(0, 0.7, -0.19), Vector3(0.42, 0.42, 0.03), "drewno", 0.004)]
			for x in [-0.18, 0.18]:
				for z in [-0.18, 0.18]:
					cz.append(B.box(Vector3(x, 0.22, z), Vector3(0.035, 0.45, 0.035), "drewno_m", 0.002))
		"beczka":
			cz = [B.walec(Vector3(0, 0, 0), Vector3(0, r.y, 0), r.x * 0.5, r.x * 0.5, "metal_zielony_m", 14)]
			for y in [0.2, r.y - 0.2]:
				cz.append(B.walec(Vector3(0, y - 0.02, 0), Vector3(0, y + 0.02, 0), r.x * 0.5 + 0.01, r.x * 0.5 + 0.01, "metal_ciemny_m", 14))
			var cyl := CylinderShape3D.new()
			cyl.radius = r.x * 0.5
			cyl.height = r.y
			ksz = cyl
		"szafka":
			cz = [B.box(Vector3(0, r.y * 0.5, 0), r, "metal_zielony_m", 0.006),
				B.box(Vector3(0, r.y * 0.5, r.z * 0.5 + 0.004), Vector3(0.01, r.y * 0.9, 0.006), "metal_ciemny_m", 0.0)]
	var mi := B.instancja(cz, false)
	add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = ksz
	cs.position = Vector3(0, r.y * 0.5, 0)
	add_child(cs)


func tekst_interakcji(_g) -> String:
	var d: Dictionary = RODZAJE[rodzaj]
	return "%s (%d kg) – przytrzymaj [F] i %s" % [d["nazwa"], int(mass), "nieś" if mass < 15.0 else "ciągnij"]


func interakcja(g) -> void:
	g.komunikat.emit("Przytrzymaj [F], żeby chwycić – %s." % ("podniesiesz" if mass < 15.0 else "pociągniesz po podłodze, powoli i głośno"))


## Początek chwytu: odległość od oczu zostaje (przedmiot idzie za wzrokiem).
func chwyc(g) -> void:
	_chwycony = true
	sleeping = false
	_odl = clampf((global_position - g.kamera.global_position).length(), 0.9, 1.6)


func chwyc_ruch(g, _m: Vector2, delta: float) -> void:
	if not _chwycony:
		chwyc(g)
	var kam: Camera3D = g.kamera
	var cel: Vector3 = kam.global_position - kam.global_basis.z * _odl
	var lekki := mass < 15.0
	var srodek := global_position + Vector3.UP * float(RODZAJE[rodzaj]["r"].y) * 0.5
	var d := cel - srodek
	if not lekki:
		d.y = 0.0          # ciężkie suną po podłodze
	var vmax := clampf(30.0 / mass, 0.35, 2.4)
	var v := (d * 7.0).limit_length(vmax)
	linear_velocity = Vector3(v.x, v.y if lekki else linear_velocity.y, v.z)
	if lekki:
		angular_velocity = angular_velocity.lerp(Vector3.ZERO, minf(1.0, delta * 8.0))
	# szuranie / stukot – słychać, tym dalej, im cięższe
	var pr := Vector2(linear_velocity.x, linear_velocity.z).length()
	_dzw -= delta * (0.4 + pr * 3.0)
	if _dzw <= 0.0 and pr > 0.15:
		_dzw = 0.55
		Dzwiek.graj_3d("drzwi_skrzyp" if not lekki else "szelest_0", global_position, get_parent(), -10.0 + mass * 0.12, randf_range(0.45, 0.6) if not lekki else 1.2, 10.0 + mass * 0.3)
		Gra.emituj_halas(global_position, 2.0 + mass * 0.15, g)
	if (cel - srodek).length() > 2.4:
		g.pusc_chwyt()          # zaczepiło się – wypada z rąk


func pusc_chwyt(_g) -> void:
	_chwycony = false


## Ciężar w rękach spowalnia marsz (gracz): lekkie prawie nie, szafkę ledwo.
func limit_predkosci() -> float:
	return lerpf(1.3, 0.45, clampf(mass / 45.0, 0.0, 1.0))


func _uderzenie(_b: Node) -> void:
	var v := linear_velocity.length()
	if v > 2.2:
		Dzwiek.graj_3d("upadek_miekki", global_position, get_parent(), -6.0 + mass * 0.1, randf_range(0.7, 0.9), 18.0)
		Gra.emituj_halas(global_position, 4.0 + mass * 0.2, null)
