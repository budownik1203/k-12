"""Generator ikon przedmiotów (pixel art, 32 px na kratkę siatki ekwipunku).

Uruchomienie:  python3 narzedzia/generuj_ikony.py
Czyta assets/dane/przedmioty.json, zapisuje assets/ikony/<id>.png.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ikony"
OUT.mkdir(parents=True, exist_ok=True)
CELL = 32

# paleta
METAL = (70, 72, 74)
METAL_J = (110, 112, 114)
METAL_C = (40, 40, 42)
DREWNO = (120, 72, 38)
DREWNO_J = (156, 100, 56)
MOSIADZ = (196, 160, 70)
OLIWKA = (82, 92, 58)
OLIWKA_J = (108, 120, 76)
KHAKI = (150, 136, 96)
BIEL = (222, 218, 204)
CZERWIEN = (168, 40, 34)
ZIELEN = (52, 104, 60)
POMARANCZ = (210, 120, 40)
GRANAT = (44, 52, 78)
ZLOTO = (220, 180, 60)
SZKLO = (150, 190, 180)


def shaded_rect(d, box, c, light=True):
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=c)
    if light and x1 - x0 > 2 and y1 - y0 > 2:
        hi = tuple(min(255, v + 34) for v in c)
        lo = tuple(max(0, v - 34) for v in c)
        d.line([(x0, y0), (x1, y0)], fill=hi)
        d.line([(x0, y0), (x0, y1)], fill=hi)
        d.line([(x0, y1), (x1, y1)], fill=lo)
        d.line([(x1, y0), (x1, y1)], fill=lo)


def poly(d, pts, c):
    d.polygon(pts, fill=c)
    lo = tuple(max(0, v - 40) for v in c)
    d.line(pts + [pts[0]], fill=lo)


def cross(d, cx, cy, s, c):
    d.rectangle([cx - s, cy - s // 3, cx + s, cy + s // 3], fill=c)
    d.rectangle([cx - s // 3, cy - s, cx + s // 3, cy + s], fill=c)


def outline(img):
    a = img.split()[3]
    grown = a.filter(ImageFilter.MaxFilter(3))
    ol = Image.new("RGBA", img.size, (12, 12, 12, 255))
    ol.putalpha(grown)
    ol.alpha_composite(img)
    return ol


# --------------------------------------------------------------- rysowanie

def draw(pid, d, W, H):
    if pid == "pw9":
        shaded_rect(d, [6, 7, 58, 15], METAL)
        d.line([(8, 9), (54, 9)], fill=METAL_J)
        poly(d, [(14, 15), (30, 15), (26, 29), (12, 29)], DREWNO)
        d.arc([28, 14, 40, 24], 0, 180, fill=METAL_C, width=2)
        d.rectangle([56, 9, 59, 12], fill=METAL_C)
    elif pid == "pm63":
        shaded_rect(d, [14, 14, 80, 28], METAL)
        shaded_rect(d, [80, 18, 92, 22], METAL_C)
        shaded_rect(d, [24, 28, 34, 56], METAL_C)  # magazynek w chwycie
        poly(d, [(36, 28), (46, 28), (44, 46), (36, 46)], METAL)
        shaded_rect(d, [62, 28, 68, 40], METAL)  # chwyt przedni
        d.line([(4, 18), (14, 18)], fill=METAL_J, width=2)
        d.line([(4, 18), (4, 30)], fill=METAL_J, width=2)
        d.line([(4, 30), (14, 26)], fill=METAL_J, width=2)
    elif pid == "kb47":
        poly(d, [(2, 24), (30, 22), (34, 34), (2, 44)], DREWNO)
        shaded_rect(d, [30, 20, 70, 32], METAL)
        poly(d, [(46, 32), (56, 32), (62, 58), (52, 60)], METAL_C)
        shaded_rect(d, [70, 22, 96, 30], DREWNO_J)
        shaded_rect(d, [96, 24, 124, 27], METAL_C)
        d.rectangle([116, 19, 118, 24], fill=METAL_C)
        poly(d, [(36, 32), (44, 32), (42, 44), (36, 44)], DREWNO)
        d.line([(70, 18), (96, 18)], fill=METAL_C, width=2)
    elif pid == "obrzyn":
        poly(d, [(4, 14), (26, 10), (30, 22), (8, 28)], DREWNO)
        shaded_rect(d, [26, 8, 92, 13], METAL)
        shaded_rect(d, [26, 14, 92, 19], METAL)
        shaded_rect(d, [36, 19, 60, 24], DREWNO_J)
    elif pid == "mag_pw9":
        shaded_rect(d, [11, 4, 21, 28], METAL)
        d.rectangle([12, 4, 20, 6], fill=MOSIADZ)
    elif pid == "mag_pm63":
        shaded_rect(d, [11, 4, 21, 60], METAL)
        d.rectangle([12, 4, 20, 6], fill=MOSIADZ)
    elif pid == "mag_kb47":
        poly(d, [(8, 3), (20, 3), (25, 32), (26, 60), (14, 61), (10, 32)], METAL_C)
        d.line([(10, 6), (13, 32)], fill=METAL_J)
        d.rectangle([9, 3, 19, 5], fill=MOSIADZ)
    elif pid in ("a_9x18", "a_762", "a_762bp"):
        # pudełko 1x2: karton z etykietą, kilka naboi wystaje z otwartego wieczka
        box = {"a_9x18": KHAKI, "a_762": OLIWKA, "a_762bp": (60, 62, 60)}[pid]
        tip = (20, 20, 20) if pid == "a_762bp" else (176, 110, 60)
        shaded_rect(d, [4, 16, 27, 60], box)
        shaded_rect(d, [4, 10, 27, 16], tuple(max(0, v - 25) for v in box))
        for i in range(4):
            x = 7 + i * 5
            d.rectangle([x, 4, x + 3, 11], fill=MOSIADZ)
            d.rectangle([x, 1, x + 3, 4], fill=tip)
        d.rectangle([7, 24, 24, 40], fill=BIEL)
        d.line([(9, 28), (22, 28)], fill=(60, 60, 60))
        d.line([(9, 32), (20, 32)], fill=(60, 60, 60))
        d.line([(9, 36), (22, 36)], fill=CZERWIEN if pid == "a_762bp" else (60, 60, 60))
    elif pid in ("a_9x18_garsc", "a_762_garsc", "a_762bp_garsc"):
        # garść luźnych naboi
        tip = (20, 20, 20) if pid.startswith("a_762bp") else (176, 110, 60)
        dl = 7 if pid.startswith("a_9x18") else 12
        for (x, y, k) in [(5, 20, 0), (12, 14, 1), (18, 21, 0), (9, 8, 1), (20, 9, 0)]:
            if k == 0:
                d.rectangle([x, y, x + dl, y + 3], fill=MOSIADZ)
                d.rectangle([x + dl, y, x + dl + 3, y + 3], fill=tip)
            else:
                d.rectangle([x, y, x + 3, y + dl], fill=MOSIADZ)
                d.rectangle([x, y - 3, x + 3, y], fill=tip)
    elif pid == "a_12":
        # pudełko na 20 łusek: rząd czerwonych łusek w kartonie
        shaded_rect(d, [3, 18, 28, 61], (150, 120, 70))
        for i, x in enumerate((5, 13, 21)):
            shaded_rect(d, [x, 6, x + 6, 22], CZERWIEN)
            shaded_rect(d, [x, 22, x + 6, 27], MOSIADZ)
        d.rectangle([6, 34, 25, 48], fill=BIEL)
        d.text((9, 35), "12", fill=CZERWIEN)
    elif pid == "a_12_garsc":
        for i, x in enumerate((5, 13, 21)):
            shaded_rect(d, [x, 6, x + 6, 22], CZERWIEN)
            shaded_rect(d, [x, 22, x + 6, 27], MOSIADZ)
    elif pid in ("tlumik_9", "tlumik_762"):
        g = 10 if pid == "tlumik_9" else 13
        shaded_rect(d, [4, 16 - g // 2, 54, 16 + g // 2], (46, 48, 46))
        for x in range(10, 52, 8):
            d.line([(x, 16 - g // 2 + 1), (x, 16 + g // 2 - 1)], fill=(30, 30, 30))
        shaded_rect(d, [54, 13, 60, 19], METAL)
    elif pid == "hamulec":
        shaded_rect(d, [6, 11, 26, 21], METAL)
        for x in (10, 15, 20):
            d.rectangle([x, 11, x + 2, 14], fill=METAL_C)
            d.rectangle([x, 18, x + 2, 21], fill=METAL_C)
    elif pid == "kolimator":
        shaded_rect(d, [4, 20, 28, 26], METAL_C)
        d.rectangle([7, 6, 25, 20], outline=(40, 42, 44), width=3)
        d.ellipse([14, 11, 18, 15], fill=(230, 40, 30))
    elif pid == "luneta":
        shaded_rect(d, [12, 11, 52, 19], (40, 42, 40))
        shaded_rect(d, [4, 8, 14, 22], (50, 52, 50))
        shaded_rect(d, [50, 9, 60, 21], (50, 52, 50))
        d.rectangle([26, 20, 36, 27], fill=METAL_C)
        d.rectangle([28, 5, 32, 11], fill=METAL)
    elif pid == "chwyt":
        shaded_rect(d, [6, 4, 26, 10], METAL_C)
        poly(d, [(11, 10), (21, 10), (19, 29), (13, 29)], BAKELIT if False else (70, 40, 26))
    elif pid == "latarka_taktyczna":
        shaded_rect(d, [4, 11, 24, 21], (40, 42, 40))
        shaded_rect(d, [22, 9, 29, 23], METAL)
        d.rectangle([27, 11, 29, 21], fill=(250, 236, 170))
        d.rectangle([8, 21, 14, 26], fill=METAL_C)
    elif pid == "mapa":
        poly(d, [(3, 6), (12, 3), (20, 6), (29, 3), (29, 26), (20, 29), (12, 26), (3, 29)], (200, 190, 150))
        d.line([(12, 3), (12, 26)], fill=(150, 140, 100))
        d.line([(20, 6), (20, 29)], fill=(150, 140, 100))
        d.line([(5, 18), (14, 14), (24, 20)], fill=CZERWIEN, width=2)
        d.ellipse([22, 9, 26, 13], outline=GRANAT)
    elif pid == "kompas":
        d.ellipse([4, 4, 28, 28], fill=METAL, outline=METAL_C)
        d.ellipse([7, 7, 25, 25], fill=BIEL)
        poly(d, [(16, 8), (18, 16), (16, 24), (14, 16)], (60, 60, 60))
        poly(d, [(16, 8), (18, 16), (14, 16)], CZERWIEN)
    elif pid == "napiersnik":
        shaded_rect(d, [4, 10, 60, 56], OLIWKA)
        for x in (8, 22, 36):
            shaded_rect(d, [x, 18, x + 11, 50], OLIWKA_J)
            d.rectangle([x + 1, 18, x + 10, 22], fill=OLIWKA)
        shaded_rect(d, [49, 26, 58, 50], OLIWKA_J)
        d.line([(10, 10), (4, 2)], fill=OLIWKA, width=3)
        d.line([(54, 10), (60, 2)], fill=OLIWKA, width=3)
    elif pid == "kamizelka_mysliwska":
        poly(d, [(8, 6), (24, 6), (32, 18), (40, 6), (56, 6), (58, 92), (6, 92)], (110, 84, 46))
        for (x, y) in [(10, 40), (40, 40), (10, 66), (40, 66)]:
            shaded_rect(d, [x, y, x + 14, y + 16], (90, 66, 36))
        d.rectangle([14, 30, 18, 34], fill=POMARANCZ)
    elif pid == "chlebak":
        shaded_rect(d, [6, 14, 58, 58], (100, 96, 64))
        shaded_rect(d, [6, 14, 58, 32], (86, 82, 54))
        d.rectangle([28, 30, 36, 38], fill=METAL)
        d.line([(10, 14), (32, 2), (54, 14)], fill=(70, 66, 44), width=3)
    elif pid == "plecak_wojskowy":
        shaded_rect(d, [26, 8, 102, 150], OLIWKA)
        shaded_rect(d, [32, 4, 96, 40], OLIWKA_J)
        shaded_rect(d, [4, 50, 26, 120], OLIWKA_J)
        shaded_rect(d, [102, 50, 124, 120], OLIWKA_J)
        shaded_rect(d, [40, 70, 88, 120], OLIWKA_J)
        for x in (44, 80):
            d.rectangle([x, 36, x + 4, 60], fill=METAL_C)
        d.text((50, 125), "88", fill=(40, 44, 30))
    elif pid == "maszyna_do_pisania":
        shaded_rect(d, [6, 26, 90, 58], (60, 70, 66))
        shaded_rect(d, [10, 8, 86, 26], (74, 86, 80))
        d.rectangle([14, 4, 82, 9], fill=METAL_C)
        for r in range(3):
            for k in range(9):
                d.rectangle([14 + k * 8 + r * 2, 34 + r * 7, 18 + k * 8 + r * 2, 37 + r * 7], fill=BIEL)
        d.rectangle([30, 0, 64, 6], fill=BIEL)
    elif pid == "kanister":
        shaded_rect(d, [6, 14, 58, 92], (60, 90, 50))
        d.line([(10, 18), (54, 88)], fill=(48, 72, 40), width=3)
        d.line([(54, 18), (10, 88)], fill=(48, 72, 40), width=3)
        shaded_rect(d, [14, 2, 34, 14], (60, 90, 50))
        shaded_rect(d, [40, 4, 50, 14], METAL)
    elif pid == "telefon":
        shaded_rect(d, [8, 26, 56, 58], (150, 40, 34))
        shaded_rect(d, [4, 12, 60, 24], (130, 34, 28))
        d.ellipse([20, 32, 44, 56], fill=BIEL, outline=METAL_C)
        d.ellipse([28, 40, 36, 48], fill=(150, 40, 34))
    elif pid == "gasnica":
        shaded_rect(d, [8, 18, 24, 92], CZERWIEN)
        shaded_rect(d, [10, 8, 22, 18], METAL)
        d.line([(22, 12), (30, 30)], fill=METAL_C, width=3)
        d.rectangle([10, 40, 22, 60], fill=BIEL)
    elif pid == "lornetka":
        for x in (6, 34):
            shaded_rect(d, [x, 8, x + 22, 26], (40, 40, 40))
            d.ellipse([x + 4, 10, x + 18, 24], fill=(60, 90, 100))
        d.rectangle([28, 12, 34, 20], fill=METAL)
    elif pid == "maska_gazowa":
        d.ellipse([10, 4, 54, 54], fill=(60, 66, 56), outline=(30, 30, 28))
        d.ellipse([16, 16, 28, 28], fill=SZKLO)
        d.ellipse([36, 16, 48, 28], fill=SZKLO)
        shaded_rect(d, [24, 36, 40, 60], METAL)
    elif pid == "kombinerki":
        poly(d, [(12, 2), (20, 2), (18, 26), (14, 26)], METAL_J)
        poly(d, [(8, 30), (15, 26), (14, 62), (6, 62)], CZERWIEN)
        poly(d, [(24, 30), (17, 26), (18, 62), (26, 62)], CZERWIEN)
    elif pid == "ikona":
        shaded_rect(d, [4, 4, 60, 60], ZLOTO)
        shaded_rect(d, [10, 10, 54, 54], (70, 40, 30))
        d.ellipse([22, 14, 42, 34], fill=ZLOTO)
        d.ellipse([26, 18, 38, 30], fill=(190, 150, 110))
        poly(d, [(18, 54), (32, 34), (46, 54)], (40, 50, 90))
    elif pid == "bandaz":
        d.ellipse([5, 7, 27, 25], fill=BIEL, outline=(170, 166, 156))
        d.ellipse([12, 13, 20, 19], fill=(190, 186, 176))
    elif pid == "opatrunek":
        shaded_rect(d, [5, 6, 27, 26], ZIELEN)
        cross(d, 16, 16, 6, BIEL)
    elif pid == "szyna":
        shaded_rect(d, [9, 3, 23, 61], POMARANCZ)
        for y in range(8, 60, 6):
            d.line([(10, y), (22, y)], fill=(160, 80, 20))
    elif pid == "bolostop":
        shaded_rect(d, [4, 7, 28, 25], (190, 196, 200))
        for x in range(8, 26, 6):
            for y in (11, 19):
                d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=BIEL)
    elif pid == "apteczka":
        shaded_rect(d, [4, 7, 28, 27], POMARANCZ)
        cross(d, 16, 17, 5, BIEL)
    elif pid == "kamizelka_wedkarska":
        poly(d, [(14, 4), (24, 12), (40, 12), (50, 4), (58, 16), (56, 60), (8, 60), (6, 16)], KHAKI)
        for x, y in ((12, 26), (36, 26), (12, 42), (36, 42)):
            shaded_rect(d, [x, y, x + 14, y + 10], (130, 116, 80))
    elif pid == "kamizelka_lbv":
        poly(d, [(22, 6), (36, 18), (60, 18), (74, 6), (86, 22), (84, 90), (12, 90), (10, 22)], OLIWKA)
        for x in (16, 32, 50, 66):
            shaded_rect(d, [x, 40, x + 13, 62], OLIWKA_J)
        shaded_rect(d, [16, 66, 79, 84], OLIWKA_J)
    elif pid == "worek":
        poly(d, [(18, 8), (46, 8), (56, 58), (8, 58)], (164, 138, 92))
        d.line([(18, 12), (46, 12)], fill=(100, 80, 50), width=2)
        for y in range(20, 56, 6):
            d.line([(12, y), (52, y)], fill=(148, 122, 80))
    elif pid == "plecak_turystyczny":
        shaded_rect(d, [22, 8, 106, 120], (60, 80, 130))
        shaded_rect(d, [30, 60, 98, 112], (50, 66, 110))
        d.line([(22, 30), (106, 30)], fill=(30, 40, 70), width=3)
        shaded_rect(d, [50, 2, 78, 10], METAL_C)
    elif pid == "plecak_szturmowy":
        shaded_rect(d, [14, 8, 82, 90], OLIWKA)
        shaded_rect(d, [22, 44, 74, 84], OLIWKA_J)
        for x in (24, 56):
            d.line([(x, 8), (x, 44)], fill=(50, 56, 34), width=3)
    elif pid == "kamizelka_kl2":
        poly(d, [(20, 6), (36, 14), (60, 14), (76, 6), (86, 22), (84, 90), (12, 90), (10, 22)], GRANAT)
        d.rectangle([28, 40, 68, 52], fill=BIEL)
        d.rectangle([32, 43, 64, 49], fill=GRANAT)
    elif pid == "kamizelka_kl4":
        poly(d, [(20, 6), (36, 14), (60, 14), (76, 6), (88, 22), (86, 92), (10, 92), (8, 22)], (70, 78, 54))
        shaded_rect(d, [24, 24, 72, 70], (88, 96, 68))
        for x in (18, 42, 66):
            shaded_rect(d, [x, 72, x + 14, 88], OLIWKA_J)
    elif pid == "helm_wz67":
        d.pieslice([6, 10, 58, 66], 180, 360, fill=OLIWKA)
        d.rectangle([4, 36, 60, 42], fill=(64, 72, 46))
        d.arc([14, 16, 50, 52], 200, 250, fill=OLIWKA_J, width=2)
    elif pid == "zegarek":
        d.rectangle([13, 2, 19, 30], fill=(80, 50, 30))
        d.ellipse([7, 8, 25, 24], fill=METAL_J)
        d.ellipse([9, 10, 23, 22], fill=BIEL)
        d.line([(16, 16), (16, 11)], fill=METAL_C)
        d.line([(16, 16), (20, 16)], fill=METAL_C)
    elif pid == "wodka":
        shaded_rect(d, [9, 20, 23, 60], (200, 214, 210))
        d.rectangle([13, 6, 19, 20], fill=(200, 214, 210))
        d.rectangle([13, 3, 19, 7], fill=CZERWIEN)
        d.rectangle([9, 34, 23, 46], fill=BIEL)
        d.rectangle([11, 38, 21, 42], fill=CZERWIEN)
    elif pid == "tasma":
        d.ellipse([4, 4, 28, 28], fill=(40, 40, 44))
        d.ellipse([7, 7, 25, 25], fill=(60, 60, 66))
        d.ellipse([11, 11, 21, 21], fill=(150, 130, 90))
        d.ellipse([13, 13, 19, 19], fill=(0, 0, 0, 0))
        d.line([(24, 18), (30, 26)], fill=(40, 40, 44), width=3)
    elif pid == "zestaw_czyszczacy":
        shaded_rect(d, [4, 8, 36, 26], (80, 86, 60))
        d.rectangle([8, 12, 32, 14], fill=MOSIADZ)
        d.line([(38, 16), (60, 16)], fill=METAL_J, width=2)
        shaded_rect(d, [52, 12, 60, 20], (150, 120, 70))
        d.ellipse([40, 20, 50, 28], fill=(200, 180, 90))
    elif pid == "papierosy":
        shaded_rect(d, [7, 5, 25, 27], (200, 196, 170))
        d.rectangle([7, 12, 25, 18], fill=CZERWIEN)
    elif pid == "konserwa":
        d.ellipse([6, 6, 26, 14], fill=METAL_J)
        shaded_rect(d, [6, 10, 26, 26], METAL)
        d.rectangle([6, 14, 26, 22], fill=(170, 60, 40))
    elif pid == "lampa_elektronowa":
        d.ellipse([9, 3, 23, 25], fill=SZKLO)
        d.rectangle([12, 10, 20, 20], fill=METAL)
        shaded_rect(d, [9, 22, 23, 29], (40, 30, 26))
    elif pid == "akumulator":
        shaded_rect(d, [6, 14, 58, 58], (36, 36, 38))
        d.rectangle([14, 8, 22, 14], fill=CZERWIEN)
        d.rectangle([42, 8, 50, 14], fill=METAL_C)
        d.rectangle([14, 28, 50, 40], fill=(200, 180, 60))
    elif pid == "kaseta":
        shaded_rect(d, [3, 8, 29, 25], (40, 40, 44))
        d.rectangle([7, 11, 25, 17], fill=BIEL)
        d.ellipse([9, 18, 13, 22], fill=METAL_J)
        d.ellipse([19, 18, 23, 22], fill=METAL_J)
    elif pid == "teczka_akt":
        shaded_rect(d, [4, 4, 28, 60], (190, 160, 100))
        d.rectangle([7, 16, 25, 24], fill=CZERWIEN)
        d.line([(16, 4), (16, 10)], fill=(90, 70, 40), width=2)
    elif pid == "lancuszek":
        for i in range(8):
            x = 6 + i * 3
            y = 10 + int(8 * abs((i - 3.5) / 3.5) ** 0.7 * -1) + 12
            d.ellipse([x - 2, y - 2, x + 2, y + 2], outline=ZLOTO)
        d.ellipse([13, 22, 19, 28], fill=ZLOTO)
    elif pid == "radio":
        shaded_rect(d, [3, 5, 61, 28], (130, 40, 36))
        for x in range(6, 30, 3):
            d.line([(x, 9), (x, 24)], fill=(80, 24, 20))
        d.rectangle([36, 10, 56, 16], fill=BIEL)
        d.ellipse([44, 18, 52, 26], fill=METAL_J)
        d.line([(58, 5), (62, 0)], fill=METAL_J)
    elif pid == "klucz_nastawny":
        shaded_rect(d, [10, 13, 54, 19], METAL_J)
        poly(d, [(50, 8), (62, 8), (62, 14), (56, 14), (56, 18), (62, 18), (62, 24), (50, 24)], METAL_J)
        d.ellipse([3, 12, 11, 20], outline=METAL_J, width=2)
    elif pid == "przewody":
        for r, c in ((13, (180, 100, 50)), (10, (200, 120, 60)), (7, (180, 100, 50))):
            d.ellipse([32 - r * 2, 16 - r, 32 + r * 2, 16 + r], outline=c, width=2)
    elif pid == "kartka_mieso":
        shaded_rect(d, [4, 6, 28, 26], (220, 200, 170))
        for y in (10, 14, 18, 22):
            d.line([(7, y), (25, y)], fill=(150, 120, 100))
        d.rectangle([20, 8, 26, 12], fill=CZERWIEN)
    elif pid == "spirytus":
        shaded_rect(d, [10, 10, 22, 29], (180, 120, 70))
        d.rectangle([13, 3, 19, 10], fill=(180, 120, 70))
        d.rectangle([10, 16, 22, 22], fill=BIEL)
    elif pid == "klucz_piwnica":
        d.ellipse([4, 9, 14, 19], outline=METAL_J, width=3)
        d.rectangle([13, 13, 28, 15], fill=METAL_J)
        d.rectangle([22, 15, 24, 20], fill=METAL_J)
        d.rectangle([26, 15, 28, 19], fill=METAL_J)
        d.rectangle([3, 22, 14, 29], fill=(200, 196, 180))
        d.text((5, 21), "7", fill=CZERWIEN)
    elif pid == "latarka":
        shaded_rect(d, [8, 12, 44, 20], (52, 54, 50))
        shaded_rect(d, [44, 9, 56, 23], (92, 94, 90))
        d.rectangle([56, 11, 59, 21], fill=(250, 236, 170))
        d.rectangle([24, 9, 28, 12], fill=(140, 40, 30))
        d.rectangle([4, 13, 8, 19], fill=(40, 40, 38))
    else:
        d.rectangle([2, 2, W - 3, H - 3], outline=(200, 0, 200))


def main():
    data = json.loads((ROOT / "assets" / "dane" / "przedmioty.json").read_text(encoding="utf-8"))
    for p in data["przedmioty"]:
        warianty = [(p["id"], p["w"], p["h"])]
        for r in p.get("rozmiary_stosu", []):
            warianty.append((p["id"] + r[3], r[1], r[2]))
        for (nazwa, w, h) in warianty:
            W, H = w * CELL, h * CELL
            img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            d = ImageDraw.Draw(img)
            draw(nazwa, d, W, H)
            img = outline(img)
            img.save(OUT / f"{nazwa}.png")
    print("ikony:", len(data["przedmioty"]))


if __name__ == "__main__":
    main()
