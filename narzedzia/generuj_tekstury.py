"""Generator tekstur low poly (styl PS1) dla próbki Strefa K-12.

Uruchomienie:  python3 narzedzia/generuj_tekstury.py
Wynik:         assets/textures/*.png

Wszystkie tekstury są proceduralne i powtarzalne (stałe ziarno losowania),
większość jest kafelkowalna w poziomie lub w obu osiach.
"""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"
OUT.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------- narzędzia

def rng(seed):
    return np.random.default_rng(seed)


def value_noise(h, w, cells_y, cells_x, seed, octaves=3):
    """Kafelkowalny szum wartości 0..1 (zawija się na krawędziach)."""
    r = rng(seed)
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    cy, cx = cells_y, cells_x
    for _ in range(octaves):
        grid = r.random((cy, cx))
        ys = np.arange(h) / h * cy
        xs = np.arange(w) / w * cx
        y0 = np.floor(ys).astype(int)
        x0 = np.floor(xs).astype(int)
        fy = (ys - y0)[:, None]
        fx = (xs - x0)[None, :]
        fy = fy * fy * (3 - 2 * fy)
        fx = fx * fx * (3 - 2 * fx)
        y1, x1 = (y0 + 1) % cy, (x0 + 1) % cx
        y0, x0 = y0 % cy, x0 % cx
        a = grid[y0][:, x0]
        b = grid[y0][:, x1]
        c = grid[y1][:, x0]
        d = grid[y1][:, x1]
        out += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)
        total += amp
        amp *= 0.5
        cy, cx = cy * 2, cx * 2
    return out / total


def col(c):
    return np.array(c, dtype=float)


def lerp(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) else t
    return a + (b - a) * t


def blob(img, cy, cx, radius, color, r, wrap=True, alpha=1.0):
    h, w, _ = img.shape
    rr = int(np.ceil(radius)) + 1
    for dy in range(-rr, rr + 1):
        for dx in range(-rr, rr + 1):
            d = (dy * dy + dx * dx) ** 0.5 + r.random() * 0.6
            if d <= radius:
                y, x = cy + dy, cx + dx
                if wrap:
                    y, x = y % h, x % w
                elif not (0 <= y < h and 0 <= x < w):
                    continue
                img[y, x] = img[y, x] * (1 - alpha) + col(color) * alpha


def rect(img, y0, x0, y1, x1, color, alpha=1.0):
    img[y0:y1, x0:x1] = img[y0:y1, x0:x1] * (1 - alpha) + col(color) * alpha


def outline(img, y0, x0, y1, x1, color):
    img[y0, x0:x1] = color
    img[y1 - 1, x0:x1] = color
    img[y0:y1, x0] = color
    img[y0:y1, x1 - 1] = color


# Mała czcionka 3x5 do napisów na tabliczkach.
FONT = {
    "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
    "J": ["001", "001", "001", "101", "010"], "C":["011", "100", "100", "100", "011"],
    "D": ["110", "101", "101", "101", "110"], "E": ["111", "100", "110", "100", "111"],
    "G": ["011", "100", "101", "101", "011"], "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"], "K": ["101", "110", "100", "110", "101"],
    "L": ["100", "100", "100", "100", "111"], "Ł": ["100", "110", "100", "100", "111"],
    "N": ["101", "111", "111", "111", "101"], "O": ["010", "101", "101", "101", "010"],
    "P": ["110", "101", "110", "100", "100"], "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
    "W": ["101", "101", "111", "111", "101"], "Y": ["101", "101", "010", "010", "010"],
    "Z": ["111", "001", "010", "100", "111"], "Ę": ["111", "100", "110", "100", "111"],
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["110", "001", "010", "100", "111"], "3": ["110", "001", "010", "001", "110"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "110", "001", "110"],
    "6": ["011", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "110"],
    " ": ["000", "000", "000", "000", "000"], "-": ["000", "000", "111", "000", "000"],
    ".": ["000", "000", "000", "000", "010"],
}


def text(img, y, x, s, color):
    for ch in s:
        g = FONT.get(ch.upper(), FONT[" "])
        for gy, row in enumerate(g):
            for gx, v in enumerate(row):
                if v == "1" and 0 <= y + gy < img.shape[0] and 0 <= x + gx < img.shape[1]:
                    img[y + gy, x + gx] = color
        x += 4
    return x


def text_width(s):
    return len(s) * 4 - 1


def save(img, name, colors=32):
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    im = im.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    im.save(OUT / name)
    print("zapisano", name, im.size)


# ---------------------------------------------------------------- tekstury

def sciana_lamperia():
    """1 m x 2,8 m: dół farba olejna (lamperia), pasek, góra pobiała. Kafelkuje się w obu osiach."""
    w, h = 64, 128
    r = rng(1)
    n1 = value_noise(h, w, 4, 4, 11)
    n2 = value_noise(h, w, 16, 8, 12, 2)
    line = h - int(round(1.5 / 2.8 * h))  # rząd granicy lamperii
    img = np.zeros((h, w, 3))
    # pobiała
    biel = col((150, 140, 116))
    img[:] = biel[None, None] * (0.86 + 0.18 * n1[..., None]) - 10 * n2[..., None]
    # brud i zacieki nad lamperią
    for y in range(line - 18, line):
        t = (y - (line - 18)) / 18
        img[y] -= 22 * t * t
    for _ in range(6):
        x = r.integers(0, w)
        ln = r.integers(4, 14)
        for y in range(line - ln, line):
            img[y, x] -= 14
    # plamy wilgoci u góry
    for _ in range(5):
        blob(img, r.integers(0, line - 10), r.integers(0, w), r.integers(3, 8), (104, 92, 68), r, alpha=0.45)
    for _ in range(10):
        x = r.integers(0, w)
        y = r.integers(0, line - 20)
        for i in range(r.integers(6, 24)):
            img[(y + i) % h, x] -= 16
    # pasek oddzielający
    img[line - 2:line] = col((92, 48, 40)) * (0.9 + 0.1 * n2[line - 2:line, :, None])
    # farba olejna
    farba = col((46, 74, 62))
    lam = farba[None, None] * (0.85 + 0.2 * n1[line:, :, None])
    # poziome smugi pędzla
    smugi = value_noise(h - line, w, 32, 2, 13, 2)
    lam += (smugi[..., None] - 0.5) * 18
    img[line:] = lam
    # odpryski i zarysowania
    for _ in range(14):
        y = r.integers(line + 2, h - 2)
        x = r.integers(0, w)
        blob(img, y, x, r.uniform(0.6, 1.6), (176, 170, 150), r, alpha=0.9)
    for _ in range(8):
        y = r.integers(line + 4, h - 6)
        x = r.integers(0, w)
        ln = r.integers(3, 9)
        for i in range(ln):
            img[y, (x + i) % w] += 22
    # ciemny pas przy podłodze (kopnięcia, mopy)
    for y in range(h - 7, h):
        img[y] -= (y - (h - 7)) * 6
    save(img, "sciana_lamperia.png")


def tynk_bialy():
    w = h = 64
    r = rng(2)
    n = value_noise(h, w, 4, 4, 21)
    n2 = value_noise(h, w, 16, 16, 22, 2)
    img = col((140, 132, 112))[None, None] * (0.8 + 0.25 * n[..., None]) - 12 * n2[..., None]
    # zaciek
    cy, cx = 40, 22
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((yy - cy) / 1.2) ** 2 + (xx - cx) ** 2) + 4 * value_noise(h, w, 8, 8, 23)
    ring = (np.abs(d - 13) < 1.2)
    img[d < 13] -= 9
    img[ring] = img[ring] * 0.82 + col((150, 128, 90)) * 0.18
    save(img, "tynk_bialy.png", 24)


def lastryko():
    w = h = 64
    r = rng(3)
    n = value_noise(h, w, 4, 4, 31)
    img = col((96, 92, 86))[None, None] * (0.85 + 0.2 * n[..., None])
    kolory = [(190, 186, 176), (60, 58, 56), (150, 98, 72), (210, 206, 196), (96, 92, 88)]
    for _ in range(170):
        c = kolory[r.integers(0, len(kolory))]
        blob(img, r.integers(0, h), r.integers(0, w), r.uniform(0.3, 1.5), c, r)
    save(img, "lastryko.png")


def beton():
    w = h = 64
    r = rng(4)
    n = value_noise(h, w, 4, 4, 41)
    n2 = value_noise(h, w, 32, 32, 42, 2)
    img = col((100, 98, 92))[None, None] * (0.8 + 0.24 * n[..., None]) - 14 * (n2[..., None] - 0.5)
    for _ in range(40):
        y, x = r.integers(0, h), r.integers(0, w)
        img[y, x] -= 30
    # ślad szalunku
    img[31] -= 10
    save(img, "beton.png", 24)


def drzwi_skaj(numer, name, seed):
    """Drzwi obite skajem z pikowaniem w romby, 0,9 x 2,05 m."""
    w, h = 64, 128
    r = rng(seed)
    base = col((104, 58, 38))
    yy, xx = np.mgrid[0:h, 0:w]
    img = np.zeros((h, w, 3)) + base
    # romby: współrzędne obrócone o 45°
    s = 12
    u = (xx + yy) / s
    v = (xx - yy) / s
    fu = np.abs(u - np.round(u))
    fv = np.abs(v - np.round(v))
    edge = np.minimum(fu, fv)  # 0 na szwie, 0.5 w środku poduszki
    shade = 0.62 + 0.75 * edge
    light = 1 + 0.18 * ((u % 1) - 0.5) * -1  # lekkie światło z góry-lewej
    img = img * (shade * light)[..., None]
    noise = value_noise(h, w, 8, 4, seed + 1)
    img *= (0.92 + 0.12 * noise)[..., None]
    # guziki w węzłach
    for y in range(0, h):
        for x in range(0, w):
            if fu[y, x] < 0.09 and fv[y, x] < 0.09 and 4 < x < w - 5 and 4 < y < h - 5:
                img[y, x] = (196, 160, 82)
    # obramowanie listwą
    rama = col((70, 38, 24))
    for t in range(3):
        outline(img, t, t, h - t, w - t, rama * (1 + 0.15 * t))
    # wizjer
    rect(img, 38, 30, 42, 34, (40, 34, 30))
    img[39:41, 31:33] = (150, 150, 160)
    # tabliczka z numerem
    rect(img, 26, 24, 34, 40, (176, 140, 64))
    outline(img, 26, 24, 34, 40, (120, 90, 40))
    text(img, 28, 32 - text_width(numer) // 2, numer, (50, 36, 20))
    # szyldy zamków
    for y0 in (64, 78):
        rect(img, y0, 52, y0 + 6, 56, (160, 150, 130))
        img[y0 + 2:y0 + 4, 53:55] = (40, 36, 34)
    # przetarcia skaju przy klamce
    for _ in range(10):
        blob(img, r.integers(60, 80), r.integers(44, 60), r.uniform(0.6, 1.4), (130, 84, 56), r, wrap=False, alpha=0.6)
    save(img, name)


def drzwi_metal():
    w, h = 64, 128
    r = rng(5)
    n = value_noise(h, w, 6, 3, 51)
    img = col((78, 96, 74))[None, None] * (0.85 + 0.2 * n[..., None])
    # przetłoczenia paneli
    for (y0, y1) in ((10, 56), (66, 118)):
        outline(img, y0, 8, y1, 56, (56, 70, 54))
        img[y0 + 1, 9:55] += 18
        img[y0 + 1:y1 - 1, 9] += 18
    # rdza
    for _ in range(18):
        y = r.integers(0, h)
        x = r.integers(0, w)
        blob(img, y, x, r.uniform(0.7, 2.6), (118, 64, 36), r, wrap=False, alpha=0.75)
    for x in range(0, w):
        if r.random() < 0.5:
            ln = r.integers(1, 8)
            img[h - ln:h, x] = img[h - ln:h, x] * 0.4 + col((110, 60, 34)) * 0.6
    # tabliczka PIWNICA
    rect(img, 18, 16, 27, 48, (210, 206, 190))
    outline(img, 18, 16, 27, 48, (40, 40, 40))
    text(img, 20, 32 - text_width("PIWNICA") // 2, "PIWNICA", (30, 30, 30))
    # szyld zamka
    rect(img, 62, 50, 70, 55, (60, 60, 60))
    save(img, "drzwi_metal.png")


def skrzynki():
    w, h = 64, 40
    r = rng(6)
    n = value_noise(h, w, 4, 6, 61)
    img = col((112, 124, 132))[None, None] * (0.86 + 0.18 * n[..., None])
    bw, bh = 16, 13
    nr = 1
    for by in range(3):
        for bx in range(4):
            x0, y0 = bx * bw, by * bh + 1
            outline(img, y0, x0, y0 + bh, x0 + bw, (60, 66, 72))
            img[y0 + 3, x0 + 3:x0 + bw - 3] = (30, 30, 34)  # szczelina
            rect(img, y0 + 6, x0 + 3, y0 + 11, x0 + 10, (206, 200, 184))
            text(img, y0 + 6, x0 + 4, f"{nr}", (40, 40, 40)) if nr < 10 else text(img, y0 + 6, x0 + 3, f"{nr}", (40, 40, 40))
            img[y0 + 8, x0 + 12] = (40, 40, 40)  # zamek
            nr += 1
    # jedna wygięta, otwarta skrytka
    rect(img, 14, 32, 27, 48, (40, 42, 46))
    for _ in range(12):
        blob(img, r.integers(0, h), r.integers(0, w), r.uniform(0.5, 1.4), (124, 72, 44), r, wrap=False, alpha=0.7)
    save(img, "skrzynki.png")


def kaloryfer():
    w = h = 32
    r = rng(7)
    n = value_noise(h, w, 4, 4, 71)
    img = col((206, 202, 188))[None, None] * (0.88 + 0.14 * n[..., None])
    for _ in range(10):
        blob(img, r.integers(0, h), r.integers(0, w), r.uniform(0.5, 1.5), (126, 76, 46), r, alpha=0.7)
    img[-4:] -= 26
    save(img, "kaloryfer.png", 16)


def drewno():
    w = h = 64
    r = rng(8)
    img = np.zeros((h, w, 3))
    plank_h = 16
    for p in range(4):
        tone = r.uniform(0.85, 1.1)
        grain = value_noise(plank_h, w, 2, 1, 80 + p, 2)
        streak = value_noise(plank_h, w, 8, 1, 90 + p, 3)
        base = col((150, 112, 70)) * tone
        y0 = p * plank_h
        img[y0:y0 + plank_h] = base[None, None] * (0.82 + 0.25 * grain[..., None] + 0.12 * (streak[..., None] - 0.5))
        img[y0] = base * 0.45
        img[y0 + plank_h - 1] = base * 0.7
    # ramka ze sztachet na krawędziach
    for t in range(5):
        img[:, t] = img[:, t] * 0.7 + col((120, 86, 52)) * 0.3
        img[:, w - 1 - t] = img[:, w - 1 - t] * 0.7 + col((120, 86, 52)) * 0.3
    img[:, 5] *= 0.6
    img[:, w - 6] *= 0.6
    # gwoździe
    for y in (4, 12, 20, 28, 36, 44, 52, 60):
        img[y, 2] = (60, 60, 64)
        img[y, w - 3] = (60, 60, 64)
    # szablon na skrzyni
    text(img, 29, 32 - text_width("K-12") // 2, "K-12", (46, 40, 34))
    save(img, "drewno.png")


def beczka():
    w = h = 64
    r = rng(9)
    n = value_noise(h, w, 4, 6, 91)
    img = col((58, 84, 120))[None, None] * (0.82 + 0.25 * n[..., None])
    for yr in (10, 32, 54):
        img[yr - 1:yr + 2] *= 0.6
        img[yr - 2] *= 1.15
    for _ in range(26):
        blob(img, r.integers(0, h), r.integers(0, w), r.uniform(0.6, 2.4), (122, 66, 36), r, alpha=0.75)
    for _ in range(8):
        x = r.integers(0, w)
        y = r.integers(0, 30)
        for i in range(r.integers(6, 20)):
            img[(y + i) % h, x] = img[(y + i) % h, x] * 0.4 + col((120, 64, 34)) * 0.6
    save(img, "beczka.png")


def szafka():
    w, h = 64, 128
    r = rng(10)
    n = value_noise(h, w, 4, 4, 101)
    img = col((128, 132, 128))[None, None] * (0.86 + 0.16 * n[..., None])
    outline(img, 2, 2, h - 2, w - 2, (76, 80, 78))
    for y in range(10, 26, 3):
        img[y, 18:46] = (40, 42, 42)
    rect(img, 60, 52, 72, 56, (64, 66, 66))
    rect(img, 34, 24, 41, 40, (208, 202, 186))
    text(img, 35, 32 - text_width("23") // 2, "23", (40, 40, 40))
    for _ in range(14):
        blob(img, r.integers(0, h), r.integers(0, w), r.uniform(0.6, 1.6), (118, 70, 42), r, wrap=False, alpha=0.6)
    img[-10:] -= np.linspace(0, 30, 10)[:, None, None]
    save(img, "szafka.png")


def jednolity(name, c, seed, var=0.12, size=16):
    n = value_noise(size, size, 2, 2, seed)
    img = col(c)[None, None] * (1 - var / 2 + var * n[..., None])
    save(img, name, 8)


def plafon():
    w = h = 32
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt((yy - 16) ** 2 + (xx - 16) ** 2) / 16
    img = col((255, 236, 196))[None, None] * (1.0 - 0.25 * d[..., None])
    # martwe muchy w kloszu
    for (y, x) in ((20, 12), (21, 14), (12, 20)):
        img[y, x] = (90, 80, 60)
    save(img, "plafon.png", 16)


def okno():
    """Widok przez okno: wieczorne niebo i sylwetki bloków ze światłami."""
    w = h = 64
    r = rng(11)
    t = np.linspace(0, 1, h)[:, None]
    sky = lerp(col((40, 46, 78)), col((184, 110, 74)), t ** 1.6)
    img = np.repeat(sky, w, axis=1)
    x = 0
    while x < w:
        bw = r.integers(10, 22)
        top = r.integers(20, 40)
        img[top:, x:x + bw] = (26, 26, 34)
        for wy in range(top + 3, h - 2, 4):
            for wx in range(x + 2, min(x + bw - 1, w - 1), 3):
                if r.random() < 0.28:
                    img[wy:wy + 2, wx] = (226, 186, 106)
        x += bw + r.integers(0, 4)
    # brud na szybie
    n = value_noise(h, w, 4, 4, 112)
    img = img * (0.85 + 0.15 * n[..., None]) + 18 * n[..., None]
    save(img, "okno.png")


def hydrant():
    w = h = 64
    r = rng(12)
    n = value_noise(h, w, 4, 4, 121)
    img = col((168, 36, 30))[None, None] * (0.86 + 0.18 * n[..., None])
    outline(img, 1, 1, h - 1, w - 1, (110, 20, 18))
    rect(img, 12, 8, 50, 56, (60, 66, 70))
    rect(img, 13, 9, 49, 55, (120, 140, 148), 0.6)
    # wąż zwinięty widoczny przez szybkę
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt((yy - 31) ** 2 + (xx - 32) ** 2)
    ring = ((d % 4) < 2) & (d < 16) & (d > 4)
    img[ring & (yy > 12) & (yy < 50)] = img[ring & (yy > 12) & (yy < 50)] * 0.5 + col((190, 180, 150)) * 0.5
    text(img, 4, 32 - text_width("HYDRANT") // 2, "HYDRANT", (240, 236, 226))
    text(img, 54, 32 - text_width("ZBIJ SZYBE") // 2, "ZBIJ SZYBE", (240, 236, 226))
    for _ in range(6):
        blob(img, r.integers(0, h), r.integers(0, w), r.uniform(0.5, 1.2), (110, 60, 40), r, wrap=False, alpha=0.6)
    save(img, "hydrant.png")


def tablica():
    w, h = 64, 48
    r = rng(13)
    n = value_noise(h, w, 8, 8, 131, 2)
    img = col((150, 108, 66))[None, None] * (0.8 + 0.3 * n[..., None])
    outline(img, 0, 0, h, w, (80, 54, 32))
    outline(img, 1, 1, h - 1, w - 1, (96, 66, 40))
    kartki = [(4, 4, 22, 22), (6, 26, 30, 46), (26, 6, 44, 24), (24, 48, 42, 60), (33, 28, 45, 44)]
    for i, (y0, x0, y1, x1) in enumerate(kartki):
        paper = col((222, 216, 196)) if i != 3 else col((214, 196, 120))
        rect(img, y0, x0, y1, x1, paper)
        for ly in range(y0 + 7 if i == 1 else y0 + 3, y1 - 2, 2):
            ln = r.integers(4, x1 - x0 - 2)
            img[ly, x0 + 2:x0 + 2 + ln] = (120, 116, 110)
        img[y0, (x0 + x1) // 2] = (200, 40, 40)  # pinezka
    text(img, 8, 36 - text_width("OGŁ.") // 2, "OGŁ.", (170, 30, 30))
    save(img, "tablica.png")


def lampa_sciana():
    jednolity("metal_ciemny.png", (46, 46, 44), 141, 0.18)
    jednolity("porecz.png", (88, 52, 34), 142, 0.1)
    jednolity("rama_drzwi.png", (84, 66, 52), 143, 0.15)
    jednolity("okno_rama.png", (182, 176, 160), 144, 0.12)
    jednolity("klamka.png", (180, 164, 120), 145, 0.2)


if __name__ == "__main__":
    sciana_lamperia()
    tynk_bialy()
    lastryko()
    beton()
    drzwi_skaj("12", "drzwi_skaj_12.png", 50)
    drzwi_skaj("13", "drzwi_skaj_13.png", 52)
    drzwi_skaj("14", "drzwi_skaj_14.png", 54)
    drzwi_metal()
    skrzynki()
    kaloryfer()
    drewno()
    beczka()
    szafka()
    plafon()
    okno()
    hydrant()
    tablica()
    lampa_sciana()


# ================================================================ biom 1: mieszkania, piwnice, magazyny

def parkiet():
    w = h = 64
    r = rng(201)
    img = np.zeros((h, w, 3))
    # jodełka uproszczona: klepki 16x4 naprzemiennie
    for by in range(0, h, 4):
        for bx in range(0, w, 16):
            off = (by // 4 % 2) * 8
            x0 = (bx + off) % w
            tone = r.uniform(0.75, 1.05)
            base = col((112, 70, 40)) * tone
            for y in range(by, by + 4):
                for x in range(x0, x0 + 16):
                    img[y % h, x % w] = base * (0.93 + 0.1 * r.random())
            img[by % h, :] *= 0.97
            img[by:by + 4, x0 % w] = base * 0.55
        img[by] *= 0.75
    n = value_noise(h, w, 4, 4, 202)
    img *= (0.8 + 0.25 * n)[..., None]
    save(img, "parkiet.png")


def tapeta(name, base_c, wzor_c, seed):
    """Tapeta PRL z powtarzalnym wzorem, pociemniała, z zaciekami. Kafelkuje się w obu osiach (1 m x 2,8 m)."""
    w, h = 64, 128
    r = rng(seed)
    n = value_noise(h, w, 4, 4, seed + 1)
    img = col(base_c)[None, None] * (0.82 + 0.22 * n[..., None])
    for yy in range(0, h, 16):
        for xx in range(0, w, 16):
            ox = 8 if (yy // 16) % 2 else 0
            cx, cy = (xx + ox) % w, yy + 8
            for dy in range(-3, 4):
                for dx in range(-3, 4):
                    if abs(dx) + abs(dy) in (3,) or (dx == 0 and dy == 0):
                        img[(cy + dy) % h, (cx + dx) % w] = img[(cy + dy) % h, (cx + dx) % w] * 0.4 + col(wzor_c) * 0.6
    # listwa przypodłogowa i brud przy podłodze
    img[h - 5:h] = col((70, 50, 34))
    img[h - 5] *= 1.25
    for y in range(h - 16, h - 5):
        img[y] -= (y - (h - 16)) * 1.5
    # zacieki i odklejone pasy
    for _ in range(5):
        x = r.integers(0, w)
        for y in range(r.integers(0, 20), r.integers(30, 90)):
            img[y, x] -= 18
            img[y, (x + 1) % w] -= 8
    for _ in range(2):
        blob(img, r.integers(10, 60), r.integers(0, w), r.integers(4, 8), (96, 84, 62), r, alpha=0.4)
    x0 = r.integers(0, w - 6)
    img[r.integers(10, 40):r.integers(60, 100), x0:x0 + 3] = col((150, 140, 118))
    save(img, name)


def kafelki():
    w = h = 64
    r = rng(211)
    img = np.zeros((h, w, 3))
    for ty in range(0, h, 16):
        for tx in range(0, w, 16):
            c = col((176, 182, 168)) if (tx // 16 + ty // 16) % 2 == 0 else col((150, 164, 150))
            c = c * r.uniform(0.9, 1.04)
            img[ty:ty + 16, tx:tx + 16] = c
            img[ty:ty + 16, tx] = (90, 90, 84)
            img[ty, tx:tx + 16] = (90, 90, 84)
            img[ty + 1, tx + 1:tx + 15] += 16
    for _ in range(4):
        y, x = r.integers(0, h), r.integers(0, w)
        for i in range(r.integers(4, 12)):
            img[(y + i) % h, (x + i // 2) % w] = (70, 70, 66)
    n = value_noise(h, w, 4, 4, 212)
    img *= (0.78 + 0.25 * n)[..., None]
    save(img, "kafelki.png")


def cegla():
    """Ceglana ściana piwnicy, 1 m x 2,8 m, kafelkuje się."""
    w, h = 64, 128
    r = rng(221)
    img = np.zeros((h, w, 3)) + col((70, 66, 60))
    bh, bw = 6, 16
    for row in range(0, h // bh + 1):
        off = (row % 2) * 8
        for bx in range(-1, w // bw + 1):
            x0 = bx * bw + off
            c = col((122, 64, 46)) * r.uniform(0.7, 1.05)
            for y in range(row * bh + 1, min(h, row * bh + bh)):
                for x in range(x0 + 1, x0 + bw):
                    img[y, x % w] = c * (0.9 + 0.15 * r.random())
    n = value_noise(h, w, 4, 4, 222)
    img *= (0.7 + 0.35 * n)[..., None]
    # wykwity i wilgoć przy podłodze
    for y in range(h - 30, h):
        img[y] = img[y] * (1 - (y - (h - 30)) / 30 * 0.35) + col((90, 96, 80)) * ((y - (h - 30)) / 30 * 0.25)
    save(img, "cegla.png")


def beton_sciana():
    """Ściana z betonu z zaciekami, 1 m x 2,8 m."""
    w, h = 64, 128
    r = rng(231)
    n = value_noise(h, w, 4, 4, 232)
    n2 = value_noise(h, w, 32, 16, 233, 2)
    img = col((96, 96, 92))[None, None] * (0.75 + 0.3 * n[..., None]) - 12 * (n2[..., None] - 0.5)
    for y in (42, 85):
        img[y] -= 14
    for _ in range(14):
        x = r.integers(0, w)
        for y in range(r.integers(0, 40), r.integers(50, 128)):
            img[y, x] -= 10
    img[h - 8:] -= 16
    save(img, "beton_sciana.png")


def tkanina():
    w = h = 32
    r = rng(241)
    img = np.zeros((h, w, 3))
    for y in range(h):
        for x in range(w):
            c = col((96, 70, 48)) if ((x // 4 + y // 4) % 2) else col((84, 60, 40))
            img[y, x] = c * (0.88 + 0.2 * r.random())
    save(img, "tkanina.png", 16)


def fornir():
    w = h = 64
    n = value_noise(h, w, 2, 8, 251, 4)
    s = value_noise(h, w, 1, 32, 252, 2)
    img = col((118, 74, 42))[None, None] * (0.75 + 0.3 * n[..., None] + 0.1 * (s[..., None] - 0.5))
    save(img, "fornir.png")


def emalia():
    w = h = 32
    r = rng(261)
    n = value_noise(h, w, 2, 2, 262)
    img = col((196, 196, 182))[None, None] * (0.85 + 0.15 * n[..., None])
    for _ in range(6):
        blob(img, r.integers(0, h), r.integers(0, w), r.uniform(0.5, 1.3), (110, 76, 50), r, alpha=0.7)
    save(img, "emalia.png", 16)


def ekran_tv():
    w = h = 32
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt((yy - 16) ** 2 + (xx - 16) ** 2) / 22
    img = col((40, 48, 46))[None, None] * (1.0 - 0.6 * d[..., None])
    img[::2] *= 0.85
    save(img, "ekran_tv.png", 16)


def worek_piasek():
    w = h = 32
    r = rng(271)
    n = value_noise(h, w, 4, 4, 272)
    img = col((130, 116, 82))[None, None] * (0.8 + 0.3 * n[..., None])
    for y in range(0, h, 2):
        img[y] *= 0.94
    save(img, "worek_piasek.png", 16)


def metal_zielony():
    w = h = 64
    r = rng(281)
    n = value_noise(h, w, 4, 4, 282)
    img = col((62, 78, 54))[None, None] * (0.82 + 0.22 * n[..., None])
    outline(img, 2, 2, h - 2, w - 2, (40, 52, 36))
    for _ in range(14):
        blob(img, r.integers(0, h), r.integers(0, w), r.uniform(0.6, 2.0), (110, 62, 34), r, wrap=False, alpha=0.7)
    rect(img, 26, 16, 38, 48, (190, 180, 150))
    text(img, 29, 32 - text_width("WP-12") // 2, "WP-12", (40, 40, 30))
    save(img, "metal_zielony.png")


def znak_wyjscie():
    w, h = 64, 32
    img = np.zeros((h, w, 3)) + col((30, 140, 70))
    outline(img, 1, 1, h - 1, w - 1, (220, 240, 220))
    text(img, 7, 32 - text_width("WYJSCIE") // 2, "WYJSCIE", (235, 250, 235))
    text(img, 16, 32 - text_width("->") // 2, "->", (235, 250, 235))
    save(img, "znak_wyjscie.png", 8)


def zarowka():
    w = h = 16
    img = np.zeros((h, w, 3)) + col((255, 226, 160))
    save(img, "zarowka.png", 4)


def materac():
    w = h = 32
    r = rng(291)
    n = value_noise(h, w, 4, 4, 292)
    img = col((150, 140, 120))[None, None] * (0.8 + 0.25 * n[..., None])
    for x in range(0, w, 8):
        img[:, x] *= 0.8
    blob(img, 18, 12, 6, (120, 96, 60), r, alpha=0.4)
    save(img, "materac.png", 16)


if __name__ == "__main__":
    parkiet()
    tapeta("tapeta_zielona.png", (104, 112, 84), (70, 82, 56), 301)
    tapeta("tapeta_brazowa.png", (126, 100, 72), (88, 64, 44), 311)
    kafelki()
    cegla()
    beton_sciana()
    tkanina()
    fornir()
    emalia()
    ekran_tv()
    worek_piasek()
    metal_zielony()
    znak_wyjscie()
    zarowka()
    materac()
