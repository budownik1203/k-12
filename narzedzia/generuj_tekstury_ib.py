"""Tekstury w stylu Iron Blight: realistyczny wzór w niskiej rozdzielczości (ok. 64 px na metr),
wyświetlany bez wygładzania. Mniej "brudu z szumu", więcej struktury: deski, ornamenty, fugi, cegła.

Uruchomienie:  python3 narzedzia/generuj_tekstury_ib.py   (nadpisuje część tekstur z generuj_tekstury.py)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generuj_tekstury import OUT, rng, value_noise, col  # noqa: E402

WYS_SCIANY = 180      # 2,8 m ściany przy ~64 px/m


def zapisz(img, name, kolory=96):
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    im = im.quantize(colors=kolory, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    im.save(OUT / name)
    print("zapisano", name, im.size)


def fbm(h, w, cy, cx, seed, okt=4):
    return value_noise(h, w, cy, cx, seed, okt)


def ziarno(h, w, seed, sila=1.0):
    r = rng(seed)
    return (r.random((h, w)) - 0.5) * sila


def smugi_pionowe(h, w, seed, gest=6):
    """Pionowe pociągnięcia wałka / ślady spływania – delikatne."""
    n = value_noise(h, w, 2, w // gest, seed, 2)
    return n


# ---------------------------------------------------------------- ściany

def sciana_lamperia():
    """Dwukolorowa ściana jak w akademiku: dół farba olejna (zgaszona zieleń), góra jaśniejsza emulsja,
    ciemna linia podziału na 1,5 m, cokół przy podłodze."""
    w, h = 64, WYS_SCIANY
    r = rng(1)
    line = h - int(round(1.5 / 2.8 * h))
    img = np.zeros((h, w, 3))
    # góra: matowa emulsja, bardzo lekkie przebarwienia
    gora = col((150, 158, 136))
    n1 = fbm(h, w, 3, 2, 11)
    n2 = fbm(h, w, 24, 16, 12, 2)
    img[:] = gora * (0.9 + 0.12 * n1[..., None]) + (n2[..., None] - 0.5) * 8
    # zacieki nad lamperią i pod sufitem (subtelne)
    for y in range(line - 10, line):
        img[y] -= 10 * ((y - (line - 10)) / 10) ** 2
    for y in range(0, 10):
        img[y] -= 12 * (1 - y / 10)
    # dół: farba olejna, połysk z pasami wałka
    farba = col((62, 92, 78))
    pas = value_noise(h - line, w, 2, 10, 13, 2)
    dol = farba * (0.88 + 0.16 * fbm(h - line, w, 3, 2, 14)[..., None]) + (pas[..., None] - 0.5) * 14
    img[line:] = dol
    # linia podziału (ciemna, ręcznie malowana)
    img[line - 2:line] = col((44, 52, 44))
    img[line - 2] += (r.random(w)[:, None] - 0.5) * 10
    # odpryski farby olejnej (odsłonięty tynk)
    for _ in range(2):
        y = r.integers(line + 4, h - 14)
        x = r.integers(0, w)
        rr = 1
        for dy in range(-rr, rr + 1):
            for dx in range(-rr - 1, rr + 2):
                if r.random() < 0.75:
                    img[(y + dy) % h, (x + dx) % w] = col((168, 164, 146)) * r.uniform(0.85, 1.0)
    # cokół
    img[h - 9:h] = col((44, 40, 34)) * (0.9 + 0.1 * fbm(9, w, 1, 4, 15)[..., None])
    img[h - 9] = col((70, 64, 54))
    img += ziarno(h, w, 16, 6)[..., None]
    zapisz(img, "sciana_lamperia.png")


def _ornament_tapety(w, h, kolor_tla, kolor_wz, seed, gestosc=16):
    """Tapeta z pionowymi pasami i ornamentem w kształcie liścia/rombu, powtarzalnym w obu osiach."""
    r = rng(seed)
    n = fbm(h, w, 3, 2, seed + 1)
    img = col(kolor_tla)[None, None] * (0.9 + 0.12 * n[..., None])
    # pasy pionowe
    for x in range(w):
        if x % gestosc in (0, 1):
            img[:, x] = img[:, x] * 0.86 + col(kolor_wz) * 0.14
    # ornament: rombowy liść co 16 px, przesunięty co drugi rząd
    for yy in range(0, h, 22):
        for xx in range(0, w, gestosc):
            ox = gestosc // 2 if (yy // 22) % 2 else 0
            cx, cy = (xx + ox + gestosc // 2) % w, yy + 11
            for dy in range(-7, 8):
                szer = int(round((1 - abs(dy) / 7.5) * 4))
                for dx in range(-szer, szer + 1):
                    if abs(dx) == szer or dx == 0 or (dy == 0 and abs(dx) < szer):
                        y = (cy + dy) % h
                        x = (cx + dx) % w
                        img[y, x] = img[y, x] * 0.35 + col(kolor_wz) * 0.65
    return img, r


def tapeta(name, tlo, wz, seed):
    w, h = 64, WYS_SCIANY
    img, r = _ornament_tapety(w, h, tlo, wz, seed)
    # pożółknięcie i ciemniejszy dół, listwa przypodłogowa
    for y in range(h):
        img[y] *= 0.96 + 0.06 * (1 - y / h)
    img[h - 8:h] = col((88, 60, 40)) * (0.9 + 0.12 * fbm(8, w, 1, 6, seed + 3)[..., None])
    img[h - 8] = col((120, 86, 58))
    # łączenie brytów tapety (co 0,5 m) – cienka szczelina, miejscami odklejona
    for x in (0, 32):
        img[:, x] *= 0.82
    y0 = r.integers(8, 40)
    img[y0:y0 + r.integers(12, 30), 32:34] = col((178, 170, 150))
    img += ziarno(h, w, seed + 5, 5)[..., None]
    zapisz(img, name)


def tynk_bialy():
    """Sufit: biała, lekko szara farba z drobną fakturą i rzadkimi zaciekami."""
    w = h = 64
    r = rng(30)
    img = col((172, 170, 160))[None, None] * (0.9 + 0.1 * fbm(h, w, 4, 4, 31)[..., None])
    img += (fbm(h, w, 32, 32, 32, 2)[..., None] - 0.5) * 12
    zapisz(img, "tynk_bialy.png")


def cegla():
    """Cegła pełna w piwnicy: 25 x 6,5 cm z fugą, różne odcienie, zabrudzenia przy podłodze."""
    w, h = 64, WYS_SCIANY
    r = rng(40)
    img = np.zeros((h, w, 3)) + col((92, 88, 80))
    bh, bw = 5, 16
    for row in range(h // bh + 1):
        off = (row % 2) * 8
        for bx in range(-1, w // bw + 1):
            x0 = bx * bw + off
            c = col((132, 70, 50)) * r.uniform(0.72, 1.08)
            if r.random() < 0.12:
                c = col((96, 56, 44)) * r.uniform(0.8, 1.0)
            for y in range(row * bh + 1, min(h, row * bh + bh)):
                for x in range(x0 + 1, x0 + bw):
                    v = 0.9 + 0.14 * r.random()
                    img[y, x % w] = c * v
            # jasna krawędź u góry cegły
            if row * bh + 1 < h:
                for x in range(x0 + 1, x0 + bw):
                    img[row * bh + 1, x % w] *= 1.08
    img *= (0.78 + 0.26 * fbm(h, w, 3, 2, 41))[..., None]
    for y in range(h - 36, h):
        t = (y - (h - 36)) / 36
        img[y] = img[y] * (1 - t * 0.3) + col((70, 76, 64)) * t * 0.22
    zapisz(img, "cegla.png")


def beton_sciana():
    w, h = 64, WYS_SCIANY
    r = rng(50)
    img = col((118, 118, 112))[None, None] * (0.86 + 0.16 * fbm(h, w, 4, 3, 51)[..., None])
    img += (fbm(h, w, 40, 32, 52, 2)[..., None] - 0.5) * 16
    # szwy szalunku co 0,6 m i otwory po ściągach
    for y in range(0, h, 38):
        img[y] *= 0.8
        for x in (12, 44):
            img[min(h - 1, y + 19), x] = (48, 48, 46)
    # zacieki
    for _ in range(6):
        x = r.integers(0, w)
        y0 = r.integers(0, 40)
        for y in range(y0, y0 + r.integers(30, 110)):
            if y < h:
                img[y, x] *= 0.86
    zapisz(img, "beton_sciana.png")


# ---------------------------------------------------------------- podłogi (1 kafel = 1 m)

def parkiet():
    """Deski podłogowe ok. 12 cm szerokości, różne odcienie, słoje i spoiny, przetarcia."""
    w = h = 64
    r = rng(60)
    img = np.zeros((h, w, 3))
    szer = 8                                    # 8 px = 12,5 cm
    for i in range(w // szer):
        x0 = i * szer
        ton = r.uniform(0.78, 1.08)
        baza = col((150, 108, 70)) * ton
        dl = r.integers(32, 64)
        start = r.integers(0, h)
        sl = value_noise(h, szer, 64, 2, 61 + i, 2)
        for x in range(x0, x0 + szer):
            for y in range(h):
                v = 0.9 + 0.16 * sl[y, x - x0] + (0.05 if (x - x0) in (1, 2) else 0.0)
                img[y, x] = baza * v
        img[:, x0] = baza * 0.5
        # styk desek na długości
        ys = (start + np.arange(0, h, dl)) % h
        for y in ys:
            img[y, x0:x0 + szer] = baza * 0.55
        # sęk
        if r.random() < 0.4:
            ky, kx = r.integers(0, h), x0 + r.integers(2, szer - 2)
            img[ky, kx] = baza * 0.45
            img[(ky + 1) % h, kx] = baza * 0.6
    img *= (0.84 + 0.2 * fbm(h, w, 3, 3, 69))[..., None]
    img += ziarno(h, w, 70, 6)[..., None]
    zapisz(img, "parkiet.png")


def lastryko():
    w = h = 64
    r = rng(80)
    img = col((128, 124, 114))[None, None] * (0.9 + 0.12 * fbm(h, w, 4, 4, 81)[..., None])
    for _ in range(420):
        y, x = r.integers(0, h), r.integers(0, w)
        c = [col((176, 170, 156)), col((70, 66, 60)), col((150, 120, 96)), col((100, 106, 100))][r.integers(0, 4)]
        img[y, x] = c * r.uniform(0.85, 1.05)
        if r.random() < 0.3:
            img[y, (x + 1) % w] = c * 0.9
    # dylatacje co 1 m (krawędź kafla)
    img[0, :] = (84, 82, 76)
    img[:, 0] = (84, 82, 76)
    zapisz(img, "lastryko.png")


def kafelki():
    """Kafle 15 x 15 cm (10 px) z szarą fugą, część pęknięta."""
    w = h = 60
    r = rng(90)
    img = np.zeros((h, w, 3)) + col((98, 98, 92))
    for ty in range(0, h, 10):
        for tx in range(0, w, 10):
            c = col((188, 190, 178)) * r.uniform(0.9, 1.04)
            img[ty + 1:ty + 10, tx + 1:tx + 10] = c
            img[ty + 1, tx + 1:tx + 10] *= 1.05
            img[ty + 9, tx + 1:tx + 10] *= 0.94
    for _ in range(3):
        y, x = r.integers(0, h), r.integers(0, w)
        for i in range(r.integers(4, 9)):
            img[(y + i) % h, (x + i // 2) % w] = (90, 90, 84)
    img *= (0.84 + 0.18 * fbm(h, w, 3, 3, 91))[..., None]
    zapisz(img, "kafelki.png")


def beton():
    w = h = 64
    r = rng(100)
    img = col((104, 102, 96))[None, None] * (0.82 + 0.22 * fbm(h, w, 4, 4, 101)[..., None])
    img += (fbm(h, w, 48, 48, 102, 2)[..., None] - 0.5) * 18
    # rysa
    y, x = r.integers(0, h), 0
    while x < w:
        img[y % h, x] *= 0.6
        x += 1
        y += r.integers(-1, 2)
    # plama oleju
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt((yy - 40) ** 2 + (xx - 18) ** 2) + fbm(h, w, 6, 6, 103) * 6
    img[d < 9] *= 0.8
    zapisz(img, "beton.png")


# ---------------------------------------------------------------- meble, drewno, dywany

def drewno():
    """Deska skrzyni / mebla: słoje wzdłuż, kilka desek, łby gwoździ."""
    w = h = 64
    r = rng(110)
    img = np.zeros((h, w, 3))
    for i in range(4):
        y0 = i * 16
        baza = col((138, 100, 62)) * r.uniform(0.82, 1.06)
        sl = value_noise(16, w, 3, 48, 111 + i, 3)
        img[y0:y0 + 16] = baza * (0.84 + 0.24 * sl)[..., None]
        img[y0] = baza * 0.5
        img[y0 + 15] = baza * 0.7
        for x in (5, w - 6):
            img[y0 + 7, x] = (50, 46, 42)
    img += ziarno(h, w, 115, 6)[..., None]
    zapisz(img, "drewno.png")


def fornir():
    """Okleina meblowa PRL (orzech): długie, faliste słoje."""
    w = h = 64
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    n = fbm(h, w, 2, 2, 120)
    fale = np.sin((xx * 0.55 + n * 5.0 + np.sin(yy * 0.05) * 1.2)) * 0.5 + 0.5
    baza = col((132, 78, 44))
    img = baza * (0.8 + 0.22 * fale[..., None]) * (0.9 + 0.12 * fbm(h, w, 4, 16, 121)[..., None])
    img += ziarno(h, w, 122, 5)[..., None]
    zapisz(img, "fornir.png")


def dywan():
    """Dywan perski (jak na zdjęciach z Iron Blight): czerwone pole, granatowe ornamenty, medalion, bordiura."""
    w, h = 96, 64
    r = rng(130)
    czerw = col((130, 36, 30))
    gran = col((36, 40, 70))
    krem = col((196, 176, 136))
    zolty = col((176, 128, 52))
    img = np.zeros((h, w, 3)) + czerw
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = w / 2, h / 2
    # bordiury
    b1 = (yy < 4) | (yy >= h - 4) | (xx < 4) | (xx >= w - 4)
    b2 = ((yy >= 4) & (yy < 7)) | ((yy < h - 4) & (yy >= h - 7)) | ((xx >= 4) & (xx < 7)) | ((xx < w - 4) & (xx >= w - 7))
    img[b1] = gran
    img[b2] = krem
    # wzór w bordiurze: kropki co 3 px
    for x in range(0, w, 3):
        img[1, x] = img[h - 2, x] = zolty
    for y in range(0, h, 3):
        img[y, 1] = img[y, w - 2] = zolty
    # pole: siatka małych rombów
    pole = ~(b1 | b2)
    romb = ((np.abs((xx % 8) - 4) + np.abs((yy % 8) - 4)) == 3)
    img[pole & romb] = img[pole & romb] * 0.4 + gran * 0.6
    kr = ((xx % 8) == 4) & ((yy % 8) == 4)
    img[pole & kr] = zolty
    # medalion
    d = np.abs(xx - cx) / 22 + np.abs(yy - cy) / 16
    img[pole & (d < 1.0)] = gran
    img[pole & (d < 0.8)] = krem * 0.9
    img[pole & (d < 0.62)] = czerw * 1.1
    img[pole & (d < 0.32)] = gran
    img[pole & (d < 0.14)] = zolty
    pierscien = pole & (np.abs(d - 0.9) < 0.05)
    img[pierscien] = zolty
    # narożniki pola
    for (ax, ay) in ((10, 10), (w - 11, 10), (10, h - 11), (w - 11, h - 11)):
        dd = np.abs(xx - ax) + np.abs(yy - ay)
        img[pole & (dd < 5)] = gran
        img[pole & (dd < 3)] = krem
    # zużycie i ziarno włosia
    img *= (0.84 + 0.2 * fbm(h, w, 3, 4, 131))[..., None]
    img += ziarno(h, w, 132, 14)[..., None]
    zapisz(img, "dywan.png", 64)


def szafka():
    """Front szafki/szafy z okleiną, listwy i uchwyt (64 x 128 = cały front)."""
    w, h = 64, 128
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    n = fbm(h, w, 2, 2, 140)
    fale = np.sin(yy * 0.25 + n * 7.0) * 0.5 + 0.5
    img = col((128, 80, 46)) * (0.82 + 0.2 * fale[..., None])
    # ramka i podział na dwoje drzwi
    img[:, :2] *= 0.6
    img[:, -2:] *= 0.6
    img[:2] *= 0.6
    img[-2:] *= 0.6
    img[:, 31:33] = col((60, 38, 24))
    # uchwyty
    for x in (27, 36):
        img[58:70, x] = (190, 186, 170)
        img[58:70, x + 1] = (120, 118, 108)
    img += ziarno(h, w, 141, 5)[..., None]
    zapisz(img, "szafka.png")


def szum():
    """Ogólna faktura brył kolorowanych wierzchołkami (broń, meble, postacie): drobne rysy i zabrudzenia."""
    w = h = 32
    r = rng(150)
    img = np.zeros((h, w, 3)) + 222
    img *= (0.9 + 0.1 * fbm(h, w, 4, 4, 151))[..., None]
    for _ in range(14):
        y, x = r.integers(0, h), r.integers(0, w)
        ln = r.integers(2, 6)
        for i in range(ln):
            img[y, (x + i) % w] += 18
    for _ in range(30):
        y, x = r.integers(0, h), r.integers(0, w)
        img[y, x] -= r.integers(10, 30)
    zapisz(img, "szum.png", 32)


# ---------------------------------------------------------------- ręce i broń (widok z pierwszej osoby)

def skora():
    """Skóra dłoni: ciepły ton, delikatne przebarwienia i pory (bez wyraźnego wzoru)."""
    w = h = 32
    img = col((206, 160, 132))[None, None] * (0.9 + 0.12 * fbm(h, w, 3, 3, 300)[..., None])
    img += (fbm(h, w, 16, 16, 301, 2)[..., None] - 0.5) * 14
    img[..., 0] += (fbm(h, w, 4, 4, 302)[...] - 0.5) * 14
    img += ziarno(h, w, 303, 4)[..., None]
    zapisz(img, "skora.png", 48)


def rekaw():
    """Kurtka wojskowa / robocza: oliwkowa tkanina w skośny splot, przetarcia."""
    w = h = 32
    yy, xx = np.mgrid[0:h, 0:w]
    splot = (((xx + yy) % 4) < 2).astype(float)
    img = col((78, 84, 58))[None, None] * (0.86 + 0.08 * splot[..., None]) * (0.88 + 0.18 * fbm(h, w, 3, 3, 310)[..., None])
    img += ziarno(h, w, 311, 6)[..., None]
    zapisz(img, "rekaw.png", 32)


def metal_bron():
    """Oksydowana stal jak w Iron Blight: ciemny grafit w drobne piksele, wytarte jasne łaty i rysy."""
    w = h = 64
    r = rng(320)
    img = col((50, 52, 58))[None, None] * (0.8 + 0.3 * fbm(h, w, 4, 4, 321)[..., None])
    img += (fbm(h, w, 32, 32, 323, 2)[..., None] - 0.5) * 18
    wyt = fbm(h, w, 6, 6, 324)
    img[wyt > 0.66] = img[wyt > 0.66] * 0.5 + col((128, 130, 134)) * 0.5
    for _ in range(40):
        y, x = r.integers(0, h), r.integers(0, w)
        for i in range(r.integers(2, 9)):
            img[(y + i // 3) % h, (x + i) % w] = col((150, 152, 156)) * r.uniform(0.75, 1.0)
    img += ziarno(h, w, 322, 10)[..., None]
    zapisz(img, "metal_bron.png", 40)


def okladzina():
    """Okładziny chwytu: brązowy bakelit w kratkę (radełkowanie), z wytartymi szczytami."""
    w = h = 32
    yy, xx = np.mgrid[0:h, 0:w]
    krata = (((xx + yy) % 4 == 0) | ((xx - yy) % 4 == 0)).astype(float)
    img = col((70, 46, 34))[None, None] * (0.95 - 0.35 * krata[..., None]) * (0.85 + 0.25 * fbm(h, w, 3, 3, 380)[..., None])
    img += ziarno(h, w, 381, 8)[..., None]
    zapisz(img, "okladzina.png", 24)


def metal_jasny():
    w = h = 32
    img = col((168, 168, 164))[None, None] * (0.85 + 0.2 * fbm(h, w, 3, 3, 330)[..., None])
    img += ziarno(h, w, 331, 10)[..., None]
    zapisz(img, "metal_jasny.png", 32)


def drewno_bron():
    """Kolba i łoże: rudy orzech z ciemnymi, wyraźnymi słojami i jaśniejszymi przetarciami (jak w Iron Blight)."""
    w, h = 32, 64
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    n = fbm(h, w, 2, 2, 340)
    sl = np.sin(xx * 1.1 + n * 7.0 + yy * 0.04)
    ciemne = (sl > 0.72).astype(float)
    img = col((150, 72, 38)) * (0.86 + 0.14 * fbm(h, w, 6, 3, 341)[..., None])
    img = img * (1 - 0.45 * ciemne[..., None])
    img += (fbm(h, w, 16, 8, 343, 2)[..., None] - 0.5) * 20
    jasne = fbm(h, w, 4, 3, 344) > 0.7
    img[jasne] = img[jasne] * 0.75 + col((196, 120, 70)) * 0.25
    img += ziarno(h, w, 342, 8)[..., None]
    zapisz(img, "drewno_bron.png", 40)


def bakelit():
    w = h = 32
    r = rng(350)
    img = col((46, 34, 28))[None, None] * (0.85 + 0.25 * fbm(h, w, 4, 4, 351)[..., None])
    for _ in range(60):
        y, x = r.integers(0, h), r.integers(0, w)
        img[y, x] *= 1.35
    zapisz(img, "bakelit.png", 24)


def tarcza_zegarka():
    """Tarcza zegarka: jasna, z podziałką; środek zostawiony na wskaźnik zdrowia (krzyżyk rysowany bryłą)."""
    w = h = 32
    img = np.zeros((h, w, 3)) + col((214, 212, 200))
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    d = np.sqrt((yy - 15.5) ** 2 + (xx - 15.5) ** 2)
    a = np.arctan2(yy - 15.5, xx - 15.5)
    kres = (np.abs(((a / (2 * np.pi) * 60) % 1) - 0.5) > 0.38) & (d > 12.5) & (d < 15)
    gruby = (np.abs(((a / (2 * np.pi) * 12) % 1) - 0.5) > 0.42) & (d > 10.5) & (d < 15)
    img[kres] = (60, 60, 58)
    img[gruby] = (30, 30, 30)
    img[d >= 15.4] = (90, 90, 86)
    zapisz(img, "tarcza_zegarka.png", 16)


def pasek_zegarka():
    w = h = 16
    img = col((40, 36, 32))[None, None] * (0.85 + 0.2 * fbm(h, w, 2, 2, 360)[..., None])
    img[::4] *= 0.8
    zapisz(img, "pasek_zegarka.png", 12)


# ---------------------------------------------------------------- postacie

def tkanina_npc():
    """Jasnoszara tkanina (barwiona odcieniem frakcji w shaderze): splot, przetarcia, plamy brudu."""
    w = h = 32
    yy, xx = np.mgrid[0:h, 0:w]
    splot = (((xx // 2 + yy) % 3) == 0).astype(float)
    img = np.zeros((h, w, 3)) + 200
    img *= (0.9 - 0.08 * splot[..., None]) * (0.82 + 0.26 * fbm(h, w, 3, 3, 400)[..., None])
    img += ziarno(h, w, 401, 10)[..., None]
    zapisz(img, "tkanina_npc.png", 24)


def skora_npc():
    w = h = 16
    img = col((176, 136, 112))[None, None] * (0.9 + 0.14 * fbm(h, w, 2, 2, 410)[..., None])
    zapisz(img, "skora_npc.png", 16)


def twarz():
    """Twarz 32x32 w stylu Iron Blight: zmęczona, zarost, oczy w cieniu, krwawe zacieki (frakcje ludzkie)."""
    w = h = 32
    img = col((178, 136, 112))[None, None] * (0.9 + 0.12 * fbm(h, w, 3, 3, 420)[..., None])
    # brwi, oczodoły, oczy
    for x0 in (8, 19):
        img[10:12, x0:x0 + 6] = (64, 48, 40)
        img[12:16, x0:x0 + 6] *= 0.72
        img[13:15, x0 + 1:x0 + 5] = (220, 214, 200)
        img[13:15, x0 + 2:x0 + 4] = (40, 34, 30)
    # nos z cieniem, usta
    img[14:21, 15:17] *= 0.88
    img[20:22, 13:19] *= 0.7
    img[24:26, 11:21] = (110, 60, 54)
    img[26, 12:20] *= 0.8
    # zarost
    r = rng(421)
    for _ in range(90):
        y, x = r.integers(20, 32), r.integers(4, 28)
        img[y, x] *= 0.72
    # cienie po bokach (zaokrąglenie)
    for x in range(4):
        img[:, x] *= 0.7 + x * 0.07
        img[:, w - 1 - x] *= 0.7 + x * 0.07
    zapisz(img, "twarz.png", 32)


def twarz_maska():
    """Kominiarka z wycięciem na oczy (najemnicy)."""
    w = h = 32
    img = col((40, 40, 38))[None, None] * (0.85 + 0.25 * fbm(h, w, 6, 6, 430)[..., None])
    img[11:17, 6:26] = col((176, 134, 110))
    for x0 in (9, 19):
        img[13:15, x0:x0 + 4] = (220, 214, 200)
        img[13:15, x0 + 1:x0 + 3] = (40, 34, 30)
    zapisz(img, "twarz_maska.png", 16)


if __name__ == "__main__":
    sciana_lamperia()
    tapeta("tapeta_zielona.png", (120, 134, 108), (82, 98, 76), 160)
    tapeta("tapeta_brazowa.png", (156, 128, 92), (112, 82, 58), 170)
    tynk_bialy()
    cegla()
    beton_sciana()
    parkiet()
    lastryko()
    kafelki()
    beton()
    drewno()
    fornir()
    dywan()
    szafka()
    szum()
    skora()
    rekaw()
    metal_bron()
    okladzina()
    metal_jasny()
    drewno_bron()
    bakelit()
    tarcza_zegarka()
    pasek_zegarka()
    tkanina_npc()
    skora_npc()
    twarz()
    twarz_maska()
