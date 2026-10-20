"""Atlas naklejek (ślady na ścianach i podłogach) w skali świata: 64 px = 1 m.

Pęknięcia, zacieki, graffiti (napisy i znaki sprayem), dziury po kulach, okopcenia, odpadający tynk
z cegłą, stare ogłoszenia, plamy na podłodze. Alfa miękka – shader naklejki ditheruje ją w pikselach.
Wynik: assets/textures/naklejki.png + assets/dane/naklejki.json (prostokąt w atlasie, rozmiar w metrach,
miejsce: sciana / sciana_gora / sciana_dol / podloga, waga losowania).

    python3 narzedzia/generuj_naklejki.py
"""
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
PX_M = 64
ATLAS = 1024
rnd = random.Random(1986)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_C = "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf"


def pusta(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def pekniecie(w, h, seed):
    r = random.Random(seed)
    im = pusta(w, h)
    d = ImageDraw.Draw(im)
    # pień od krawędzi (dół albo róg) w górę, rozgałęzienia
    def galaz(x, y, kat, dl, gr):
        for _ in range(int(dl)):
            nx = x + math.cos(kat) * 3
            ny = y + math.sin(kat) * 3
            d.line([(x, y), (nx, ny)], fill=(28, 24, 20, 235), width=gr)
            d.line([(x + 1, y + 1), (nx + 1, ny + 1)], fill=(210, 205, 190, 70), width=1)
            x, y = nx, ny
            kat += r.uniform(-0.45, 0.45)
            if r.random() < 0.08 and gr > 1:
                galaz(x, y, kat + r.choice([-1, 1]) * r.uniform(0.5, 1.1), dl * 0.45, gr - 1)
            if not (0 <= x < w and 0 <= y < h):
                return
    galaz(r.uniform(w * 0.3, w * 0.7), h - 1, -math.pi / 2 + r.uniform(-0.4, 0.4), h / 3.2, 2)
    if r.random() < 0.6:
        galaz(0, r.uniform(h * 0.2, h * 0.6), r.uniform(-0.3, 0.3), w / 3.0, 1)
    return im


def zaciek(w, h, seed):
    r = random.Random(seed)
    a = np.zeros((h, w), np.float32)
    # plama u góry i strugi w dół
    cx = w / 2
    yy, xx = np.mgrid[0:h, 0:w]
    a += np.clip(1.0 - (((xx - cx) / (w * 0.45)) ** 2 + (yy / (h * 0.28)) ** 2), 0, 1) * 0.8
    for _ in range(r.randint(3, 6)):
        x0 = cx + r.uniform(-w * 0.35, w * 0.35)
        dl = r.uniform(h * 0.4, h * 0.95)
        sz = r.uniform(2.0, 5.0)
        mask = np.clip(1.0 - np.abs(xx - x0 - np.sin(yy * 0.05 + x0) * 2) / sz, 0, 1) * (yy < dl) * (1.0 - yy / dl) * 0.9
        a = np.maximum(a, mask)
    a = np.clip(a + (np.random.default_rng(seed).random((h, w)) - 0.5) * 0.25, 0, 1) * 0.75
    rgb = np.zeros((h, w, 3), np.uint8)
    rgb[..., 0] = 92
    rgb[..., 1] = 74
    rgb[..., 2] = 45
    # obwódka ciemniejsza (rdzawe brzegi)
    kraw = (a > 0.15) & (a < 0.3)
    rgb[kraw] = (70, 50, 28)
    out = np.dstack([rgb, (a * 255).astype(np.uint8)])
    return Image.fromarray(out, "RGBA")


def spray(tekst, w, h, kolor, seed, rozmiar=None, font=FONT):
    r = random.Random(seed)
    s = 3
    big = Image.new("L", (w * s, h * s), 0)
    d = ImageDraw.Draw(big)
    fs = rozmiar or int(h * s * 0.62)
    f = ImageFont.truetype(font, fs)
    while d.textlength(tekst, font=f) > w * s * 0.94 and fs > 10:
        fs -= 2
        f = ImageFont.truetype(font, fs)
    tw = d.textlength(tekst, font=f)
    x = (w * s - tw) / 2
    y = (h * s - fs) / 2 - fs * 0.1
    # litery lekko rozjechane jak w pośpiechu
    for ch in tekst:
        d.text((x, y + r.uniform(-fs * 0.06, fs * 0.06)), ch, font=f, fill=255)
        x += d.textlength(ch, font=f)
    big = big.rotate(r.uniform(-4, 4), resample=Image.BICUBIC)
    big = big.filter(ImageFilter.GaussianBlur(s * 0.9))
    a = np.asarray(big.resize((w, h), Image.LANCZOS), np.float32) / 255.0
    a = np.clip((a - 0.2) * 1.6, 0, 1)
    # zacieki farby
    rng = np.random.default_rng(seed)
    for _ in range(r.randint(2, 6)):
        cols = np.where(a.max(axis=0) > 0.6)[0]
        if len(cols) == 0:
            break
        cx = int(rng.choice(cols))
        rows = np.where(a[:, cx] > 0.6)[0]
        y0 = int(rows.max())
        dl = r.randint(3, max(4, h // 3))
        for k in range(dl):
            if y0 + k < h:
                a[y0 + k, cx] = max(a[y0 + k, cx], 0.85 * (1 - k / dl))
    a = np.clip(a * (0.85 + rng.random((h, w)) * 0.3), 0, 1)
    rgb = np.zeros((h, w, 3), np.uint8)
    rgb[...] = kolor
    return Image.fromarray(np.dstack([rgb, (a * 255).astype(np.uint8)]), "RGBA")


def znak(rodzaj, n, kolor, seed):
    s = 4
    big = Image.new("L", (n * s, n * s), 0)
    d = ImageDraw.Draw(big)
    W = n * s
    lw = int(W * 0.07)
    if rodzaj == "czaszka":
        d.ellipse([W * 0.2, W * 0.1, W * 0.8, W * 0.62], outline=255, width=lw)
        d.ellipse([W * 0.3, W * 0.3, W * 0.45, W * 0.45], fill=255)
        d.ellipse([W * 0.55, W * 0.3, W * 0.7, W * 0.45], fill=255)
        d.rectangle([W * 0.35, W * 0.62, W * 0.65, W * 0.78], outline=255, width=lw)
        for k in range(3):
            d.line([(W * (0.42 + k * 0.08), W * 0.62), (W * (0.42 + k * 0.08), W * 0.78)], fill=255, width=lw // 2)
        d.line([(W * 0.12, W * 0.85), (W * 0.88, W * 0.98)], fill=255, width=lw)
        d.line([(W * 0.12, W * 0.98), (W * 0.88, W * 0.85)], fill=255, width=lw)
    elif rodzaj == "usmiech":
        d.ellipse([W * 0.1, W * 0.1, W * 0.9, W * 0.9], outline=255, width=lw)
        d.line([(W * 0.37, W * 0.32), (W * 0.37, W * 0.45)], fill=255, width=lw)
        d.line([(W * 0.63, W * 0.32), (W * 0.63, W * 0.45)], fill=255, width=lw)
        d.arc([W * 0.27, W * 0.35, W * 0.73, W * 0.75], 20, 160, fill=255, width=lw)
    elif rodzaj == "kreski":
        for g in range(3):
            x0 = W * (0.08 + g * 0.31)
            for k in range(4):
                d.line([(x0 + k * W * 0.055, W * 0.3), (x0 + k * W * 0.055, W * 0.72)], fill=255, width=lw // 2)
            d.line([(x0 - W * 0.02, W * 0.62), (x0 + W * 0.2, W * 0.38)], fill=255, width=lw // 2)
    elif rodzaj == "oko":
        d.ellipse([W * 0.08, W * 0.3, W * 0.92, W * 0.7], outline=255, width=lw)
        d.ellipse([W * 0.38, W * 0.36, W * 0.62, W * 0.64], fill=255)
        d.line([(W * 0.5, W * 0.05), (W * 0.5, W * 0.25)], fill=255, width=lw // 2)
    elif rodzaj == "radiacja":
        c = W / 2
        for k in range(3):
            a0 = k * 120 - 90 - 30
            d.pieslice([c - W * 0.42, c - W * 0.42, c + W * 0.42, c + W * 0.42], a0, a0 + 60, fill=255)
        d.ellipse([c - W * 0.14, c - W * 0.14, c + W * 0.14, c + W * 0.14], fill=0)
        d.ellipse([c - W * 0.08, c - W * 0.08, c + W * 0.08, c + W * 0.08], fill=255)
    big = big.filter(ImageFilter.GaussianBlur(s * 0.8))
    a = np.asarray(big.resize((n, n), Image.LANCZOS), np.float32) / 255.0
    a = np.clip((a - 0.15) * 1.5, 0, 1) * (0.85 + np.random.default_rng(seed).random((n, n)) * 0.3)
    rgb = np.zeros((n, n, 3), np.uint8)
    rgb[...] = kolor
    return Image.fromarray(np.dstack([rgb, (np.clip(a, 0, 1) * 255).astype(np.uint8)]), "RGBA")


def dziury(w, h, seed):
    r = random.Random(seed)
    im = pusta(w, h)
    d = ImageDraw.Draw(im)
    for _ in range(r.randint(5, 11)):
        x, y = r.uniform(6, w - 6), r.uniform(6, h - 6)
        rr = r.uniform(1.5, 3.2)
        d.ellipse([x - rr * 2.2, y - rr * 2.2, x + rr * 2.2, y + rr * 2.2], fill=(150, 145, 135, 110))
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(18, 16, 14, 245))
        for _ in range(3):
            k = r.uniform(0, math.tau)
            d.line([(x, y), (x + math.cos(k) * rr * 3, y + math.sin(k) * rr * 3)], fill=(40, 36, 32, 160), width=1)
    return im


def sadza(w, h, seed):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = w / 2
    # pióropusz od dołu ku górze, rozszerzający się
    szer = (w * 0.18) + (h - yy) * 0.35
    a = np.clip(1.0 - np.abs(xx - cx + np.sin(yy * 0.07) * 6) / szer, 0, 1) * np.clip((yy / h) * 1.4, 0, 1)
    a = np.clip(a * (0.7 + rng.random((h, w)) * 0.5), 0, 1) * 0.8
    rgb = np.full((h, w, 3), 22, np.uint8)
    return Image.fromarray(np.dstack([rgb, (a * 255).astype(np.uint8)]), "RGBA")


def tynk(w, h, seed):
    r = random.Random(seed)
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    # nieregularny kształt odpadniętego tynku
    a = np.zeros((h, w), np.float32)
    for _ in range(6):
        cx, cy = r.uniform(w * 0.25, w * 0.75), r.uniform(h * 0.25, h * 0.75)
        rx, ry = r.uniform(w * 0.15, w * 0.35), r.uniform(h * 0.15, h * 0.35)
        a = np.maximum(a, ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 < 1)
    a = a.astype(np.float32)
    # cegła pod spodem: rzędy 4 px, spoiny
    rgb = np.zeros((h, w, 3), np.uint8)
    rzad = (yy // 5)
    przes = (rzad % 2) * 6
    spoina = ((yy % 5) == 0) | (((xx + przes) % 12) == 0)
    rgb[...] = (128, 58, 40)
    odc = rng.integers(-14, 14, (h, w, 1))
    rgb = np.clip(rgb.astype(np.int16) + odc, 0, 255).astype(np.uint8)
    rgb[spoina] = (150, 140, 120)
    # brzeg tynku (jasna krawędź z cieniem)
    from scipy.ndimage import binary_dilation
    kraw = binary_dilation(a > 0.5, iterations=2) & (a < 0.5)
    rgb[kraw] = (90, 85, 75)
    al = np.where(a > 0.5, 1.0, np.where(kraw, 0.9, 0.0))
    return Image.fromarray(np.dstack([rgb, (al * 255).astype(np.uint8)]), "RGBA")


def ogloszenie(w, h, seed, naglowek):
    r = random.Random(seed)
    im = Image.new("RGBA", (w, h), (214, 205, 176, 255))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, 9], fill=(150, 40, 30, 255))
    f = ImageFont.truetype(FONT_C, 8)
    d.text((2, 0), naglowek, font=f, fill=(235, 225, 200, 255))
    for k in range(r.randint(5, 8)):
        y = 14 + k * 5
        if y > h - 6:
            break
        d.line([(3, y), (r.randint(w // 2, w - 4), y)], fill=(90, 85, 70, 255), width=1)
    # oddarty róg i zażółcenie
    px = im.load()
    rng = np.random.default_rng(seed)
    for yy in range(h):
        for xx in range(w):
            if xx + (h - yy) * 0.6 < r.uniform(6, 12) and yy > h * 0.6:
                px[xx, yy] = (0, 0, 0, 0)
            elif px[xx, yy][3] > 0:
                c = px[xx, yy]
                z = int(rng.integers(-12, 8))
                px[xx, yy] = (max(0, c[0] + z), max(0, c[1] + z), max(0, c[2] + z - 6), c[3])
    return im


def plama(w, h, seed, kolor, alfa):
    r = random.Random(seed)
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    a = np.zeros((h, w), np.float32)
    for _ in range(5):
        cx, cy = r.uniform(w * 0.3, w * 0.7), r.uniform(h * 0.3, h * 0.7)
        rr = r.uniform(w * 0.12, w * 0.3)
        a = np.maximum(a, np.clip(1.0 - np.hypot(xx - cx, yy - cy) / rr, 0, 1))
    a = np.clip(a * 1.8, 0, 1) * alfa * (0.8 + rng.random((h, w)) * 0.3)
    rgb = np.zeros((h, w, 3), np.uint8)
    rgb[...] = kolor
    return Image.fromarray(np.dstack([rgb, (np.clip(a, 0, 1) * 255).astype(np.uint8)]), "RGBA")


def strzalka(tekst, strona, kolor, seed):
    """Strzałka sprayem z nazwą wyjścia: „BRAMA →” albo „← BRAMA” (128 x 48 px = 2 x 0,75 m)."""
    w, h = 128, 48
    s = 3
    big = Image.new("L", (w * s, h * s), 0)
    d = ImageDraw.Draw(big)
    f = ImageFont.truetype(FONT, 20 * s)
    tw = d.textlength(tekst, font=f)
    lw = 5 * s
    sy = h * s * 0.72 if tekst else h * s * 0.5
    if strona == "p":
        x0, x1 = w * s * 0.06, w * s * 0.93
        d.text((x0, h * s * 0.04), tekst, font=f, fill=255)
        d.line([(x0, sy), (x1 - 4 * s, sy)], fill=255, width=lw)
        d.polygon([(x1, sy), (x1 - 14 * s, sy - 10 * s), (x1 - 14 * s, sy + 10 * s)], fill=255)
    else:
        x0, x1 = w * s * 0.07, w * s * 0.94
        d.text((x1 - tw, h * s * 0.04), tekst, font=f, fill=255)
        d.line([(x0 + 4 * s, sy), (x1, sy)], fill=255, width=lw)
        d.polygon([(x0, sy), (x0 + 14 * s, sy - 10 * s), (x0 + 14 * s, sy + 10 * s)], fill=255)
    r = random.Random(seed)
    big = big.rotate(r.uniform(-3, 3), resample=Image.BICUBIC).filter(ImageFilter.GaussianBlur(s * 0.7))
    a = np.asarray(big.resize((w, h), Image.LANCZOS), np.float32) / 255.0
    a = np.clip((a - 0.18) * 1.7, 0, 1) * (0.88 + np.random.default_rng(seed).random((h, w)) * 0.24)
    rgb = np.zeros((h, w, 3), np.uint8)
    rgb[...] = kolor
    return Image.fromarray(np.dstack([rgb, (np.clip(a, 0, 1) * 255).astype(np.uint8)]), "RGBA")


def otwor(pierscien, srodek, seed):
    r = random.Random(seed)
    n = 12
    im = pusta(n, n)
    px = im.load()
    c = (n - 1) / 2 + r.uniform(-0.6, 0.6)
    for y in range(n):
        for x in range(n):
            d = math.hypot(x - c, y - c) + r.uniform(-0.7, 0.7)
            if d < 1.6:
                px[x, y] = srodek + (255,)
            elif d < 3.2:
                px[x, y] = tuple(int(k * 0.7) for k in pierscien) + (235,)
            elif d < 5.2 and r.random() < 0.6:
                px[x, y] = pierscien + (int(170 * (1 - (d - 3.2) / 2.0)),)
    return im


def main():
    elementy = []   # (nazwa, obraz, miejsce, waga)
    for i in range(4):
        elementy.append(("pekniecie_%d" % i, pekniecie(96, 128, 10 + i), "sciana_dol", 6))
    for i in range(3):
        elementy.append(("zaciek_%d" % i, zaciek(96, 160, 20 + i), "sciana_gora", 4))
    napisy = [("STREFA K-12", (25, 22, 20)), ("NIE WCHODŹ", (150, 30, 25)), ("TU BYŁ ZENEK", (40, 60, 120)),
              ("SĘP = ZDRAJCA", (150, 30, 25)), ("WODA SKAŻONA", (25, 22, 20)), ("UWAGA PEŁZACZE", (190, 185, 170)),
              ("ОПАСНО", (150, 30, 25)), ("KIEROWNIK ŚPI", (40, 60, 120)), ("MAMO, ZABIERZ MNIE", (25, 22, 20)),
              ("KONIEC ŚWIATA 1986", (190, 185, 170))]
    for i, (t, k) in enumerate(napisy):
        elementy.append(("graffiti_%d" % i, spray(t, 192, 48, k, 40 + i), "sciana", 3))
    for i, (rd, k) in enumerate([("czaszka", (25, 22, 20)), ("usmiech", (190, 185, 170)), ("kreski", (25, 22, 20)),
                                  ("oko", (150, 30, 25)), ("radiacja", (180, 150, 30))]):
        elementy.append(("znak_%s" % rd, znak(rd, 64, k, 60 + i), "sciana", 2))
    for i in range(2):
        elementy.append(("dziury_%d" % i, dziury(64, 64, 70 + i), "sciana", 3))
    for i in range(2):
        elementy.append(("sadza_%d" % i, sadza(96, 128, 80 + i), "sciana_dol", 2))
    for i in range(3):
        elementy.append(("tynk_%d" % i, tynk(96, 72, 90 + i), "sciana", 4))
    for i, t in enumerate(["ZEBRANIE LOKATORÓW", "KOMUNIKAT", "ZAKAZ WSTĘPU"]):
        elementy.append(("ogloszenie_%d" % i, ogloszenie(44, 60, 100 + i, t), "sciana", 2))
    for i, (k, al) in enumerate([((40, 32, 26), 0.75), ((60, 20, 16), 0.65), ((30, 34, 30), 0.6)]):
        elementy.append(("plama_%d" % i, plama(112, 96, 110 + i, k, al), "podloga", 3))

    # strzałki do wyjść (malowane przez poprzedników): osobno w prawo i w lewo, żeby napis się nie odbijał
    for nazwa, tekst, kolor in [("brama", "BRAMA", (225, 222, 205)), ("piwnica", "PIWNICA 7", (210, 175, 40)), ("okno", "OKNO", (175, 40, 30))]:
        for strona in ["p", "l"]:
            elementy.append(("strzalka_%s_%s" % (nazwa, strona), strzalka(tekst, strona, kolor, 200 + len(elementy)), "strzalka", 0))
    # znaki gracza (puszka sprayu): pomarańczowe – odróżniają się od cudzych
    pom = (235, 120, 28)
    elementy.append(("gracz_strzalka_p", strzalka("", "p", pom, 400), "gracza", 0))
    elementy.append(("gracz_strzalka_l", strzalka("", "l", pom, 401), "gracza", 0))
    elementy.append(("gracz_krzyzyk", spray("X", 48, 48, pom, 402, rozmiar=110), "gracza", 0))
    elementy.append(("gracz_wykrzyknik", spray("!", 48, 48, pom, 403, rozmiar=120), "gracza", 0))
    # dziury po kulach wg materiału ściany (pojedyncze, 12 px – w świecie ok. 12 cm z odpryskiem)
    for nazwa, pierscien, srodek in [("tynk", (205, 200, 185), (25, 22, 20)), ("cegla", (150, 70, 50), (40, 22, 18)),
                                      ("kafelki", (235, 235, 228), (30, 30, 30)), ("beton", (120, 118, 112), (22, 22, 22))]:
        for i in range(2):
            elementy.append(("otwor_%s_%d" % (nazwa, i), otwor(pierscien, srodek, 300 + i * 7 + len(nazwa)), "otwor", 0))
    # pakowanie półkowe
    atlas = pusta(ATLAS, ATLAS)
    meta = {}
    x = y = 0
    wys_polki = 0
    for nazwa, im, miejsce, waga in sorted(elementy, key=lambda e: -e[1].height):
        w, h = im.size
        if x + w > ATLAS:
            x = 0
            y += wys_polki + 2
            wys_polki = 0
        assert y + h <= ATLAS, "atlas za mały"
        atlas.paste(im, (x, y))
        meta[nazwa] = {"rect": [x, y, w, h], "m": [w / PX_M, h / PX_M], "miejsce": miejsce, "waga": waga}
        x += w + 2
        wys_polki = max(wys_polki, h)
    atlas.save(ROOT / "assets/textures/naklejki.png")
    (ROOT / "assets/dane/naklejki.json").write_text(json.dumps({"atlas": ATLAS, "elementy": meta}, ensure_ascii=False, indent=1))
    print("naklejki:", len(meta), "zajęte do y =", y + wys_polki)


if __name__ == "__main__":
    main()
