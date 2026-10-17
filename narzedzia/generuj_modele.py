"""Generator modeli low poly dla próbki Strefa K-12.

Uruchomienie:  python3 narzedzia/generuj_modele.py
Wynik:         assets/models/*.glb

klatka_schodowa.glb powstaje z parametrów (liczba pięter, wymiary biegów),
więc ten sam skrypt jest zaczątkiem generatora modułów do mapy.
"""
from pathlib import Path

import numpy as np

from gltf_mini import Mesh, write_glb

OUT = Path(__file__).resolve().parent.parent / "assets" / "models"
OUT.mkdir(parents=True, exist_ok=True)

MAT = {
    "sciana": {"texture": "sciana_lamperia.png"},
    "tynk": {"texture": "tynk_bialy.png"},
    "lastryko": {"texture": "lastryko.png"},
    "beton": {"texture": "beton.png"},
    "metal_ciemny": {"texture": "metal_ciemny.png"},
    "porecz": {"texture": "porecz.png"},
    "okno_emit": {"texture": "okno.png"},
    "okno_rama": {"texture": "okno_rama.png"},
    "rama_drzwi": {"texture": "rama_drzwi.png"},
    "klamka": {"texture": "klamka.png"},
    "drzwi_skaj_12": {"texture": "drzwi_skaj_12.png"},
    "drzwi_skaj_13": {"texture": "drzwi_skaj_13.png"},
    "drzwi_skaj_14": {"texture": "drzwi_skaj_14.png"},
    "drzwi_metal": {"texture": "drzwi_metal.png"},
    "skrzynki": {"texture": "skrzynki.png"},
    "szafka": {"texture": "szafka.png"},
    "kaloryfer": {"texture": "kaloryfer.png"},
    "drewno": {"texture": "drewno.png"},
    "beczka": {"texture": "beczka.png"},
    "plafon_emit": {"texture": "plafon.png"},
    "hydrant": {"texture": "hydrant.png"},
    "tablica": {"texture": "tablica.png"},
}

# ------------------------------------------------------------ klatka schodowa
# Układ (metry): x wzdłuż klatki, z w poprzek, y w górę.
#   x 0..XL    podest piętra (drzwi mieszkań)
#   x XL..XM   biegi schodów: bieg A (z 0..ZA) w górę, bieg B (z ZB..LZ) dalej w górę
#   x XM..LX   spocznik z oknem
LX, LZ, H = 5.4, 2.6, 2.8
XL, XM = 1.6, 4.1
ZA, ZB = 1.2, 1.4
STEPS = 8
RISE = (H / 2) / STEPS
RUN = (XM - XL) / STEPS
SLAB = 0.2
WALL_T = 0.25
PIETRA = 2                       # poziomy 0..PIETRA
TOP = (PIETRA + 1) * H

DOOR_W, DOOR_H = 0.9, 2.05
DOOR_X0 = 0.3                    # drzwi na ścianach bocznych podestu
DOOR_Z0 = (LZ - DOOR_W) / 2      # drzwi na ścianie czołowej
WIN_Z0, WIN_Z1 = 0.7, 1.9
WIN_Y0, WIN_H = 0.9, 1.2         # nad spocznikiem


def fh_a(x):
    """Wysokość podłogi przy ścianie z=0 (bieg A), względem poziomu piętra."""
    if x <= XL:
        return 0.0
    if x >= XM:
        return H / 2
    return (x - XL) / (XM - XL) * H / 2


def fh_b(x):
    """Wysokość podłogi przy ścianie z=LZ (bieg B), sprowadzona okresowo do tej samej lamperii."""
    if x <= XL:
        return 0.0
    if x >= XM:
        return -H / 2
    return -(x - XL) / (XM - XL) * H / 2


def breaks(a, b, step, extra=()):
    vals = set(np.round(np.arange(a, b, step), 4).tolist())
    vals |= {round(a, 4), round(b, 4)}
    vals |= {round(e, 4) for e in extra if a <= e <= b}
    return sorted(vals)


def wall(mesh, axis, fixed, normal, u_rng, y_rng, holes, fh, extra_u=()):
    """Ściana wewnętrzna z otworami. Lamperia podąża za poziomem podłogi fh(u)."""
    def P(u, y):
        return (fixed, y, u) if axis == "x" else (u, y, fixed)

    hu = [h[0] for h in holes] + [h[1] for h in holes]
    hy = [h[2] for h in holes] + [h[3] for h in holes]
    us = breaks(u_rng[0], u_rng[1], 0.6, list(extra_u) + hu)
    ys = breaks(y_rng[0], y_rng[1], 0.7, hy)
    n = np.array(normal, dtype=float)
    for i in range(len(us) - 1):
        for j in range(len(ys) - 1):
            u0, u1, y0, y1 = us[i], us[i + 1], ys[j], ys[j + 1]
            cu, cy = (u0 + u1) / 2, (y0 + y1) / 2
            if any(h[0] < cu < h[1] and h[2] < cy < h[3] for h in holes):
                continue

            def uv(u, y):
                return (u, 1 - (y - fh(u)) / H)

            mesh.quad("sciana", P(u0, y0), P(u1, y0), P(u1, y1), P(u0, y1),
                      uv(u0, y0), uv(u1, y0), uv(u1, y1), uv(u0, y1), facing=n)
    # ościeża otworów
    for (ua, ub, ya, yb, kind) in [(h[0], h[1], h[2], h[3], h[4]) for h in holes]:
        d = -n * (WALL_T if kind == "okno" else 0.12)
        uvec = np.array((0, 0, 1.0)) if axis == "x" else np.array((1.0, 0, 0))
        A = np.array(P(ua, ya)); B = np.array(P(ub, ya)); C = np.array(P(ub, yb)); D = np.array(P(ua, yb))
        dl = np.linalg.norm(d)
        mesh.quad("tynk", A, D, D + d, A + d, (0, ya), (0, yb), (dl, yb), (dl, ya), facing=uvec)
        mesh.quad("tynk", B, C, C + d, B + d, (0, ya), (0, yb), (dl, yb), (dl, ya), facing=-uvec)
        mesh.quad("tynk", D, C, C + d, D + d, (ua, 0), (ub, 0), (ub, dl), (ua, dl), facing=np.array((0, -1.0, 0)))
        if kind == "okno":
            mesh.quad("lastryko", A, B, B + d, A + d, (ua, 0), (ub, 0), (ub, dl), (ua, dl), facing=np.array((0, 1.0, 0)))


def okno(mesh, z0, z1, y0, y1):
    """Szyba i rama w otworze ściany x=LX, plus parapet."""
    xg = LX + 0.18
    mesh.quad("okno_emit", (xg, y0, z1), (xg, y0, z0), (xg, y1, z0), (xg, y1, z1),
              (0, 1), (1, 1), (1, 0), (0, 0), facing=np.array((-1.0, 0, 0)))
    xf = LX + 0.15
    t = 0.05
    for a, b in (((xf, y0 + t / 2, z0), (xf, y0 + t / 2, z1)), ((xf, y1 - t / 2, z0), (xf, y1 - t / 2, z1)),
                 ((xf, y0, z0 + t / 2), (xf, y1, z0 + t / 2)), ((xf, y0, z1 - t / 2), (xf, y1, z1 - t / 2)),
                 ((xf, y0, (z0 + z1) / 2), (xf, y1, (z0 + z1) / 2)),
                 ((xf, y0 + (y1 - y0) * 0.68, z0), (xf, y0 + (y1 - y0) * 0.68, z1))):
        mesh.beam("okno_rama", a, b, t, t * 1.2)
    mesh.box("lastryko", (LX - 0.07, y0 - 0.04, z0 - 0.06), (LX, y0, z1 + 0.06), faces="-x+y-y+z-z")


def bieg(steps_mesh, walls_mesh, ramp_mesh, x_start, x_dir, y_base, z0, z1, inner_z, inner_dir, ground):
    """Bieg schodów: STEPS stopni od x_start w kierunku x_dir (+1/-1), podnoszący się od y_base."""
    for i in range(STEPS):
        xa = x_start + x_dir * i * RUN
        xb = x_start + x_dir * (i + 1) * RUN
        y0 = y_base + i * RISE
        y1 = y0 + RISE
        lo, hi = min(xa, xb), max(xa, xb)
        # stopnica
        steps_mesh.quad("lastryko", (lo, y1, z0), (hi, y1, z0), (hi, y1, z1), (lo, y1, z1),
                        (lo, z0), (hi, z0), (hi, z1), (lo, z1), facing=np.array((0, 1.0, 0)))
        # podstopnica (patrzy w stronę, z której się wchodzi)
        steps_mesh.quad("beton", (xa, y0, z0), (xa, y0, z1), (xa, y1, z1), (xa, y1, z0),
                        (z0, -y0), (z1, -y0), (z1, -y1), (z0, -y1), facing=np.array((-x_dir, 0, 0.0)))
        # bok od strony duszy
        def soffit(x):
            return y_base - SLAB + (x - x_start) * x_dir / (XM - XL) * (H / 2)
        b0 = 0.0 if ground else soffit(xa)
        b1 = 0.0 if ground else soffit(xb)
        target = walls_mesh if ground else steps_mesh
        target.quad("beton", (xa, b0, inner_z), (xb, b1, inner_z), (xb, y1, inner_z), (xa, y1, inner_z),
                    (xa, -b0), (xb, -b1), (xb, -y1), (xa, -y1), facing=np.array((0, 0, inner_dir)))
    x_end = x_start + x_dir * (XM - XL)
    if not ground:
        s0 = y_base - SLAB
        s1 = y_base - SLAB + H / 2
        steps_mesh.quad("tynk", (x_start, s0, z0), (x_end, s1, z0), (x_end, s1, z1), (x_start, s0, z1),
                        (x_start, z0), (x_end, z0), (x_end, z1), (x_start, z1), facing=np.array((0, -1.0, 0)))
    # rampa kolizyjna: po niej chodzi gracz zamiast wspinać się na stopnie
    for yo, fac in ((0.0, 1.0), (-0.1, -1.0)):
        ramp_mesh.quad("beton", (x_start, y_base + yo, z0), (x_end, y_base + H / 2 + yo, z0),
                       (x_end, y_base + H / 2 + yo, z1), (x_start, y_base + yo, z1),
                       (0, 0), (1, 0), (1, 1), (0, 1), facing=np.array((0, fac, 0)))


def balustrada_biegu(mesh, x_start, x_dir, y_base, z):
    hr = 0.9 + RISE / 2
    a = (x_start, y_base + hr, z)
    b = (x_start + x_dir * (XM - XL), y_base + H / 2 + hr, z)
    mesh.beam("porecz", a, b, 0.05, 0.04, tiles=2)
    for i in range(STEPS):
        xc = x_start + x_dir * (i + 0.5) * RUN
        top = y_base + (i + 1) * RISE
        yr = y_base + (xc - x_start) * x_dir / (XM - XL) * H / 2 + hr - 0.02
        mesh.beam("metal_ciemny", (xc, top, z), (xc, yr, z), 0.018, 0.018)
    # listwa dolna łącząca tralki
    mesh.beam("metal_ciemny", (x_start, y_base + RISE + 0.08, z),
              (x_start + x_dir * (XM - XL), y_base + H / 2 + RISE + 0.08, z), 0.03, 0.012)


def klatka():
    walls, steps, rails, ramps, glass = Mesh(), Mesh(), Mesh(), Mesh(), Mesh()
    hr = 0.9 + RISE / 2

    # --- ściany z otworami
    holes_x0 = [(DOOR_Z0, DOOR_Z0 + DOOR_W, k * H, k * H + DOOR_H, "drzwi") for k in range(PIETRA + 1)]
    holes_z0 = [(DOOR_X0, DOOR_X0 + DOOR_W, k * H, k * H + DOOR_H, "drzwi") for k in range(1, PIETRA + 1)]
    holes_zl = [(DOOR_X0, DOOR_X0 + DOOR_W, k * H, k * H + DOOR_H, "drzwi") for k in range(PIETRA + 1)]
    holes_xl = [(WIN_Z0, WIN_Z1, k * H + H / 2 + WIN_Y0, k * H + H / 2 + WIN_Y0 + WIN_H, "okno") for k in range(PIETRA)]
    wall(walls, "x", 0.0, (1, 0, 0), (0, LZ), (0, TOP), holes_x0, lambda u: 0.0)
    wall(walls, "x", LX, (-1, 0, 0), (0, LZ), (0, TOP), holes_xl, lambda u: H / 2)
    wall(walls, "z", 0.0, (0, 0, 1), (0, LX), (0, TOP), holes_z0, fh_a, extra_u=(XL, XM))
    wall(walls, "z", LZ, (0, 0, -1), (0, LX), (0, TOP), holes_zl, fh_b, extra_u=(XL, XM))
    for k in range(PIETRA):
        okno(glass, WIN_Z0, WIN_Z1, k * H + H / 2 + WIN_Y0, k * H + H / 2 + WIN_Y0 + WIN_H)

    # --- posadzka parteru i strop
    walls.quad("lastryko", (0, 0, 0), (LX, 0, 0), (LX, 0, LZ), (0, 0, LZ), (0, 0), (LX, 0), (LX, LZ), (0, LZ),
               facing=np.array((0, 1.0, 0)))
    walls.quad("tynk", (0, TOP, 0), (LX, TOP, 0), (LX, TOP, LZ), (0, TOP, LZ), (0, 0), (LX, 0), (LX, LZ), (0, LZ),
               facing=np.array((0, -1.0, 0)))

    # --- podesty pięter i spoczniki
    for k in range(1, PIETRA + 1):
        y = k * H
        walls.box("lastryko", (0, y - SLAB, 0), (XL, y, LZ), faces="+y", tiles=1)
        walls.box("tynk", (0, y - SLAB, 0), (XL, y, LZ), faces="-y", tiles=1)
        walls.box("beton", (0, y - SLAB, 0), (XL, y, LZ), faces="+x", tiles=1)
    for k in range(PIETRA):
        y = k * H + H / 2
        walls.box("lastryko", (XM, y - SLAB, 0), (LX, y, LZ), faces="+y")
        walls.box("tynk", (XM, y - SLAB, 0), (LX, y, LZ), faces="-y")
        walls.box("beton", (XM, y - SLAB, 0), (LX, y, LZ), faces="-x")

    # --- biegi
    for k in range(PIETRA):
        ground = k == 0
        bieg(steps, walls, ramps, XL, +1, k * H, 0.0, ZA, ZA, +1, ground)
        bieg(steps, walls, ramps, XM, -1, k * H + H / 2, ZB, LZ, ZB, -1, ground)
        balustrada_biegu(rails, XL, +1, k * H, ZA - 0.03)
        balustrada_biegu(rails, XM, -1, k * H + H / 2, ZB + 0.03)
        # łącznik poręczy na spoczniku
        ym = k * H + H / 2 + hr
        rails.beam("porecz", (XM + 0.025, ym, ZA - 0.055), (XM + 0.025, ym, ZB + 0.055), 0.05, 0.04)
        rails.beam("metal_ciemny", (XM + 0.025, k * H + H / 2, (ZA + ZB) / 2), (XM + 0.025, ym, (ZA + ZB) / 2), 0.018, 0.018)
        # łącznik na podeście piętra wyżej
        if k + 1 < PIETRA:
            yp = (k + 1) * H + hr
            rails.beam("porecz", (XL - 0.025, yp, ZA - 0.055), (XL - 0.025, yp, ZB + 0.055), 0.05, 0.04)

    # parter: zamknięcie przestrzeni pod biegami (komórka pod schodami)
    walls.quad("sciana", (XL, 0, ZB), (XL, 0, LZ), (XL, H - SLAB, LZ), (XL, H - SLAB, ZB),
               (ZB, 1), (LZ, 1), (LZ, 1 - (H - SLAB) / H), (ZB, 1 - (H - SLAB) / H), facing=np.array((-1.0, 0, 0)))
    walls.quad("beton", (XM, 0, ZA), (XM, 0, ZB), (XM, H / 2, ZB), (XM, H / 2, ZA),
               (ZA, 0), (ZB, 0), (ZB, -H / 2), (ZA, -H / 2), facing=np.array((-1.0, 0, 0)))

    # ostatnie piętro: balustrada nad duszą klatki
    yt = PIETRA * H
    rails.beam("porecz", (XL + 0.02, yt + hr, 0.05), (XL + 0.02, yt + hr, ZB + 0.055), 0.05, 0.04)
    for z in np.arange(0.12, ZB, 0.13):
        rails.beam("metal_ciemny", (XL + 0.02, yt, z), (XL + 0.02, yt + hr - 0.02, z), 0.018, 0.018)
    ramps.box("beton", (XL - 0.05, yt, 0.0), (XL + 0.08, yt + 1.1, ZB + 0.1), uv="fit")

    write_glb(OUT / "klatka_schodowa.glb",
              [("sciany-col", walls, [0, 0, 0]), ("schody", steps, [0, 0, 0]),
               ("balustrady", rails, [0, 0, 0]), ("okna", glass, [0, 0, 0]),
               ("rampy-colonly", ramps, [0, 0, 0])], MAT)


# ------------------------------------------------------------ rekwizyty
# Każdy rekwizyt ma środek w dolnym punkcie tylnej krawędzi (przy ścianie), przód patrzy w +z.

def drzwi(nazwa, mat_skrzydla):
    m, leaf = Mesh(), Mesh()
    hw = DOOR_W / 2
    t = 0.07
    # opaska ościeżnicy na ścianie
    m.box("rama_drzwi", (-hw - t, 0, 0), (-hw, DOOR_H + t, 0.015), faces="+x-x+y+z")
    m.box("rama_drzwi", (hw, 0, 0), (hw + t, DOOR_H + t, 0.015), faces="+x-x+y+z")
    m.box("rama_drzwi", (-hw, DOOR_H, 0), (hw, DOOR_H + t, 0.015), faces="+y-y+z")
    # skrzydło
    leaf.box("rama_drzwi", (-hw + 0.01, 0.01, -0.1), (hw - 0.01, DOOR_H - 0.01, -0.06),
             uv="fit", mats={"+z": mat_skrzydla}, faces="+z+x-x+y")
    # klamka i szyld
    m.box("klamka", (0.28, 0.93, -0.06), (0.32, 1.12, -0.052))
    m.beam("klamka", (0.30, 1.03, -0.055), (0.30, 1.03, -0.015), 0.018, 0.018)
    m.beam("klamka", (0.30, 1.03, -0.02), (0.17, 1.03, -0.02), 0.02, 0.016)
    write_glb(OUT / f"{nazwa}.glb", [("oscieznica", m, [0, 0, 0]), ("skrzydlo-col", leaf, [0, 0, 0])], MAT)


def skrzynki_pocztowe():
    m = Mesh()
    m.box("szafka", (-0.5, 0, 0), (0.5, 0.62, 0.2), uv="fit", mats={"+z": "skrzynki"}, faces="+z+x-x+y-y")
    write_glb(OUT / "skrzynki_pocztowe.glb", [("skrzynki", m, [0, 0, 0])], MAT)


def kaloryfer():
    m = Mesh()
    n = 11
    w = 0.065
    x0 = -n * w / 2
    for i in range(n):
        xa = x0 + i * w + 0.006
        m.box("kaloryfer", (xa, 0.06, 0.05), (xa + w - 0.012, 0.6, 0.13), uv="fit", faces="+z+x-x+y-y")
    m.box("kaloryfer", (x0, 0.1, 0.07), (-x0, 0.14, 0.11), faces="+z+y-y")
    m.box("kaloryfer", (x0, 0.52, 0.07), (-x0, 0.56, 0.11), faces="+z+y-y")
    for xs in (x0 - 0.06, -x0 + 0.04):
        m.beam("metal_ciemny", (xs + 0.01, 0.54, 0.09), (xs + 0.01, 0.54, 0.0), 0.03, 0.03)
    m.beam("metal_ciemny", (-x0 + 0.05, 0.54, 0.09), (-x0 + 0.05, -0.12, 0.09), 0.03, 0.03)
    write_glb(OUT / "kaloryfer.glb", [("kaloryfer", m, [0, 0, 0])], MAT)


def skrzynia():
    m = Mesh()
    m.box("drewno", (-0.3, 0, 0), (0.3, 0.6, 0.6), uv="fit")
    write_glb(OUT / "skrzynia.glb", [("skrzynia-col", m, [0, 0, 0])], MAT)


def beczka():
    m = Mesh()
    m.cylinder("beczka", "metal_ciemny", (0, 0, 0), 0.29, 0.88, seg=10, u_tiles=2)
    write_glb(OUT / "beczka.glb", [("beczka-col", m, [0, 0, 0])], MAT)


def szafka():
    m = Mesh()
    m.box("szafka", (-0.25, 0, 0), (0.25, 1.8, 0.45), uv="fit", faces="+z+x-x+y")
    write_glb(OUT / "szafka.glb", [("szafka-col", m, [0, 0, 0])], MAT)


def plafon():
    """Lampa sufitowa: środek w punkcie mocowania, wisi w dół."""
    m = Mesh()
    m.cylinder("metal_ciemny", "metal_ciemny", (0, -0.03, 0), 0.2, 0.03, seg=8)
    seg = 8
    rings = [(0.18, -0.03), (0.16, -0.09), (0.09, -0.13), (0.0, -0.14)]
    angs = np.linspace(0, 2 * np.pi, seg + 1)
    for (r0, y0), (r1, y1) in zip(rings[:-1], rings[1:]):
        for i in range(seg):
            a0, a1 = angs[i], angs[i + 1]
            p0 = (r0 * np.cos(a0), y0, r0 * np.sin(a0))
            p1 = (r0 * np.cos(a1), y0, r0 * np.sin(a1))
            p2 = (r1 * np.cos(a1), y1, r1 * np.sin(a1))
            p3 = (r1 * np.cos(a0), y1, r1 * np.sin(a0))
            out = np.array([np.cos((a0 + a1) / 2), -0.6, np.sin((a0 + a1) / 2)])
            uv = lambda r, a: (0.5 + 0.5 * r / 0.18 * np.cos(a), 0.5 + 0.5 * r / 0.18 * np.sin(a))
            if r1 == 0:
                m.tri("plafon_emit", p0, p1, p2, uv(r0, a0), uv(r0, a1), (0.5, 0.5), facing=out)
            else:
                m.quad("plafon_emit", p0, p1, p2, p3, uv(r0, a0), uv(r0, a1), uv(r1, a1), uv(r1, a0), facing=out)
    write_glb(OUT / "plafon.glb", [("plafon", m, [0, 0, 0])], MAT)


def hydrant():
    m = Mesh()
    m.box("hydrant", (-0.28, 0, 0), (0.28, 0.56, 0.14), uv="fit", faces="+z+x-x+y-y")
    write_glb(OUT / "hydrant.glb", [("hydrant", m, [0, 0, 0])], MAT)


def tablica():
    m = Mesh()
    m.box("drewno", (-0.42, 0, 0), (0.42, 0.62, 0.03), uv="fit", mats={"+z": "tablica"}, faces="+z+x-x+y-y")
    write_glb(OUT / "tablica_ogloszen.glb", [("tablica", m, [0, 0, 0])], MAT)


if __name__ == "__main__":
    klatka()
    drzwi("drzwi_skaj_12", "drzwi_skaj_12")
    drzwi("drzwi_skaj_13", "drzwi_skaj_13")
    drzwi("drzwi_skaj_14", "drzwi_skaj_14")
    drzwi("drzwi_piwnica", "drzwi_metal")
    skrzynki_pocztowe()
    kaloryfer()
    skrzynia()
    beczka()
    szafka()
    plafon()
    hydrant()
    tablica()
