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
        box = {"a_9x18": KHAKI, "a_762": OLIWKA, "a_762bp": (60, 62, 60)}[pid]
        shaded_rect(d, [3, 12, 28, 28], box)
        tip = (20, 20, 20) if pid == "a_762bp" else (176, 110, 60)
        n = 4 if pid == "a_9x18" else 3
        for i in range(n):
            x = 6 + i * (22 // n)
            top = 6 if pid == "a_9x18" else 3
            d.rectangle([x, top + 4, x + 3, 13], fill=MOSIADZ)
            d.rectangle([x, top, x + 3, top + 4], fill=tip)
        d.rectangle([6, 18, 25, 22], fill=BIEL)
    elif pid == "a_12":
        for i, x in enumerate((5, 13, 21)):
            shaded_rect(d, [x, 6, x + 6, 22], CZERWIEN)
            shaded_rect(d, [x, 22, x + 6, 27], MOSIADZ)
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
    else:
        d.rectangle([2, 2, W - 3, H - 3], outline=(200, 0, 200))


def main():
    data = json.loads((ROOT / "assets" / "dane" / "przedmioty.json").read_text(encoding="utf-8"))
    for p in data["przedmioty"]:
        W, H = p["w"] * CELL, p["h"] * CELL
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        draw(p["id"], d, W, H)
        img = outline(img)
        img.save(OUT / f"{p['id']}.png")
    print("ikony:", len(data["przedmioty"]))


if __name__ == "__main__":
    main()
