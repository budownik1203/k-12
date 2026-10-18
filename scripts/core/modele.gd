class_name Modele
extends RefCounted
## Definicje brył modeli broni (układ broni: przód = -Z, początek w chwycie).
## Każda definicja: "cialo" (bryły), "mag" (bryły magazynka, osobny węzeł), "lufa" (wylot),
## "celownik" (wysokość linii celowania), "przod" (pozycja lewej dłoni).

const METAL := Color(0.22, 0.23, 0.24)
const METAL_C := Color(0.12, 0.12, 0.13)
const DREWNO := Color(0.42, 0.24, 0.12)
const DREWNO_J := Color(0.52, 0.32, 0.17)
const BAKELIT := Color(0.28, 0.14, 0.09)
const SKORA := Color(0.62, 0.47, 0.38)
const RUKAW := Color(0.3, 0.32, 0.26)
const RUKAWICA := Color(0.24, 0.21, 0.18)


static func bron(id: String) -> Dictionary:
	var d := _bron_bryly(id)
	d.merge(ModeleIB.bron(id), true)
	return d


static func _bron_bryly(id: String) -> Dictionary:
	match id:
		"kb47":
			return {
				"cialo": [
					[Vector3(0, 0.05, -0.12), Vector3(0.05, 0.07, 0.36), METAL_C],
					[Vector3(0, 0.03, 0.22), Vector3(0.045, 0.09, 0.3), DREWNO, Vector3(-6, 0, 0)],
					[Vector3(0, 0.05, -0.38), Vector3(0.056, 0.06, 0.18), DREWNO_J],
					[Vector3(0, 0.094, -0.4), Vector3(0.032, 0.026, 0.2), DREWNO_J],
					[Vector3(0, 0.06, -0.61), Vector3(0.022, 0.022, 0.3), METAL_C],
					[Vector3(0, 0.095, -0.69), Vector3(0.006, 0.05, 0.008), METAL_C],
					[Vector3(-0.011, 0.105, -0.22), Vector3(0.007, 0.03, 0.04), METAL],
					[Vector3(0.011, 0.105, -0.22), Vector3(0.007, 0.03, 0.04), METAL],
					[Vector3(0, 0.094, -0.22), Vector3(0.03, 0.008, 0.04), METAL],
					[Vector3(0, -0.035, 0.0), Vector3(0.034, 0.1, 0.045), BAKELIT, Vector3(18, 0, 0)],
					[Vector3(0, 0.0, -0.06), Vector3(0.01, 0.03, 0.05), METAL],
				],
				"mag": [
					[Vector3(0, -0.07, -0.17), Vector3(0.03, 0.12, 0.065), METAL_C, Vector3(-12, 0, 0)],
					[Vector3(0, -0.16, -0.2), Vector3(0.03, 0.09, 0.062), METAL_C, Vector3(-28, 0, 0)],
				],
				"lufa": Vector3(0, 0.06, -0.77), "celownik": 0.12, "przod": Vector3(0, 0.0, -0.38),
			}
		"pm63":
			return {
				"cialo": [
					[Vector3(0, 0.04, -0.1), Vector3(0.045, 0.06, 0.27), METAL],
					[Vector3(0, 0.04, -0.27), Vector3(0.02, 0.02, 0.08), METAL_C],
					[Vector3(0, -0.035, 0.0), Vector3(0.035, 0.11, 0.045), BAKELIT, Vector3(10, 0, 0)],
					[Vector3(0, -0.03, -0.17), Vector3(0.03, 0.07, 0.03), BAKELIT],
					[Vector3(0, 0.025, 0.12), Vector3(0.04, 0.012, 0.18), METAL_C],
					[Vector3(0, 0.08, -0.21), Vector3(0.006, 0.03, 0.01), METAL_C],
					[Vector3(-0.01, 0.084, 0.0), Vector3(0.006, 0.024, 0.02), METAL_C],
					[Vector3(0.01, 0.084, 0.0), Vector3(0.006, 0.024, 0.02), METAL_C],
				],
				"mag": [[Vector3(0, -0.12, 0.004), Vector3(0.026, 0.16, 0.034), METAL_C, Vector3(10, 0, 0)]],
				"lufa": Vector3(0, 0.04, -0.32), "celownik": 0.095, "przod": Vector3(0, -0.04, -0.17),
			}
		"pw9":
			return {
				"cialo": [
					[Vector3(0, 0.035, -0.07), Vector3(0.03, 0.036, 0.17), METAL],
					[Vector3(0, 0.008, -0.06), Vector3(0.028, 0.022, 0.14), METAL_C],
					[Vector3(0, -0.035, 0.005), Vector3(0.029, 0.09, 0.042), BAKELIT, Vector3(12, 0, 0)],
					[Vector3(0, 0.058, -0.145), Vector3(0.006, 0.012, 0.008), METAL_C],
					[Vector3(-0.007, 0.058, 0.005), Vector3(0.006, 0.012, 0.008), METAL_C],
					[Vector3(0.007, 0.058, 0.005), Vector3(0.006, 0.012, 0.008), METAL_C],
				],
				"mag": [[Vector3(0, -0.085, 0.012), Vector3(0.024, 0.02, 0.034), METAL_C, Vector3(12, 0, 0)]],
				"lufa": Vector3(0, 0.035, -0.16), "celownik": 0.064, "przod": Vector3(0, -0.05, 0.02),
			}
		"obrzyn":
			return {
				"cialo": [
					[Vector3(-0.012, 0.045, -0.25), Vector3(0.022, 0.022, 0.38), METAL],
					[Vector3(0.012, 0.045, -0.25), Vector3(0.022, 0.022, 0.38), METAL],
					[Vector3(0, 0.022, -0.2), Vector3(0.05, 0.03, 0.17), DREWNO_J],
					[Vector3(0, 0.03, -0.03), Vector3(0.05, 0.05, 0.1), METAL_C],
					[Vector3(0, -0.03, 0.05), Vector3(0.04, 0.1, 0.05), DREWNO, Vector3(28, 0, 0)],
					[Vector3(0, 0.062, -0.42), Vector3(0.008, 0.01, 0.008), METAL_C],
				],
				"mag": [],
				"lufa": Vector3(0, 0.045, -0.45), "celownik": 0.068, "przod": Vector3(0, -0.01, -0.2),
			}
	return {"cialo": [[Vector3.ZERO, Vector3(0.05, 0.05, 0.2), Color.MAGENTA]], "mag": [], "lufa": Vector3(0, 0, -0.2), "celownik": 0.05, "przod": Vector3(0, 0, -0.1)}


## Ręce do widoku pierwszoosobowego (prawa na chwycie, lewa w punkcie "przod").
## Latarka (przód = -Z, początek w uchwycie dłoni).
static func latarka() -> Array:
	var r := [
		[Vector3(0, 0, 0.055), Vector3(0.034, 0.034, 0.02), METAL],                 # zakrętka
		[Vector3(0, 0, -0.01), Vector3(0.031, 0.031, 0.12), Color(0.16, 0.18, 0.14)],  # korpus (lakier wojskowy)
		[Vector3(0, 0, -0.08), Vector3(0.038, 0.038, 0.02), METAL_C],             # przejście
		[Vector3(0, 0, -0.112), Vector3(0.05, 0.05, 0.046), Color(0.16, 0.18, 0.14)],  # głowica
		[Vector3(0, 0, -0.137), Vector3(0.054, 0.054, 0.008), METAL],              # pierścień
		[Vector3(0.0, 0.018, -0.02), Vector3(0.012, 0.01, 0.022), Color(0.5, 0.12, 0.08)],  # włącznik
		[Vector3(0.0, -0.02, 0.03), Vector3(0.008, 0.012, 0.04), METAL_C],        # zaczep
	]
	for i in 3:
		r.append([Vector3(0, 0, -0.045 + i * 0.03), Vector3(0.034, 0.034, 0.006), METAL_C])  # radełkowanie
	return r


## Szkło latarki (osobny węzeł: świeci, gdy latarka włączona).
static func szklo_latarki() -> Array:
	return [[Vector3(0, 0, -0.142), Vector3(0.042, 0.042, 0.004), Color(1.0, 0.96, 0.8)]]


## Lewa dłoń zaciśnięta na latarce i rękaw.
static func reka_z_latarka() -> Array:
	return [
		[Vector3(0, -0.004, 0.0), Vector3(0.05, 0.05, 0.075), RUKAWICA],
		[Vector3(-0.035, -0.04, 0.13), Vector3(0.06, 0.06, 0.22), RUKAW, Vector3(15, 22, 0)],
	]


static func rece(przod: Vector3, pistolet: bool, tylko_prawa := false) -> Array:
	var r := [
		[Vector3(0.0, -0.035, 0.03), Vector3(0.045, 0.05, 0.07), RUKAWICA],
		[Vector3(0.02, -0.07, 0.17), Vector3(0.06, 0.06, 0.22), RUKAW, Vector3(18, -8, 0)],
	]
	if tylko_prawa:
		return r
	if pistolet:
		r.append([Vector3(-0.022, -0.045, 0.035), Vector3(0.042, 0.045, 0.06), RUKAWICA, Vector3(0, 20, 0)])
		r.append([Vector3(-0.075, -0.085, 0.18), Vector3(0.06, 0.06, 0.22), RUKAW, Vector3(18, 25, 0)])
	else:
		r.append([przod + Vector3(-0.008, -0.02, 0.0), Vector3(0.045, 0.045, 0.065), RUKAWICA])
		r.append([przod + Vector3(-0.08, -0.07, 0.14), Vector3(0.06, 0.06, 0.24), RUKAW, Vector3(12, 35, 0)])
	return r
