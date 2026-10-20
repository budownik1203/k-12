"""Ikony przedmiotów w stylu szkicu z dokumentacji technicznej (blok wschodni, lata 70–80):
rysunek tuszem na pożółkłym, wyrwanym skrawku papieru – obrys grubszą kreską, krawędzie cieńszą,
cienie kreskowaniem (krzyżowym w głębokim cieniu), przy większych rzeczach odnośnik z numerem,
podpis „Rys.” i linia wymiarowa przy broni.

Wejście: rendery z tests/render_ikon.tscn (normalne + głębia, 4x rozdzielczości).
Uruchomienie:
  xvfb-run -a godot --path . res://tests/render_ikon.tscn --rendering-driver opengl3 -- /tmp/ik
  python3 narzedzia/ikony_szkic.py /tmp/ik
"""
import json
import sys
import zlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ikony"
KOM = 17            # px na kratkę w grze
S = 4               # nadpróbkowanie renderu
TUSZ = np.array([34, 33, 44], dtype=np.float32)
PAPIER = np.array([194, 184, 154], dtype=np.float32)
CZCIONKA = "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Oblique.ttf"


def rng_dla(nazwa):
    return np.random.default_rng(zlib.crc32(nazwa.encode()))


def szum(h, w, r, skala):
    # gładki szum (rozmyty losowy) – nierówności papieru, plamy
    a = r.normal(0, 1, (max(2, h // skala + 2), max(2, w // skala + 2)))
    img = Image.fromarray(((a - a.min()) / (np.ptp(a) + 1e-6) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0 - 0.5


# odcień papieru: sprzęt wojskowy – szarozielony druk wojskowy, łup – pożółkły, środki opatrunkowe – biały
PAPIERY = {
    "wojsko": np.array([172, 178, 160], dtype=np.float32),
    "lup": np.array([204, 186, 140], dtype=np.float32),
    "med": np.array([206, 204, 192], dtype=np.float32),
}
CYWILNE = {"plecak_turystyczny", "worek", "chlebak", "kamizelka_wedkarska", "kamizelka_mysliwska"}


# ------------------------------------------------------------------ kategorie: papier, tusz, pieczątki, dodatki
ZYWNOSC = {"konserwa", "suchary", "woda", "wodka", "spirytus", "papierosy", "kartka_mieso"}
NARZEDZIA = {"prasa_elaboracyjna", "proch", "tkanina_balistyczna", "klucz_nastawny", "kombinerki", "tasma", "zestaw_czyszczacy", "wytrych", "latarka", "klucz_piwnica",
             "kompas", "mapa"}
KALIBRY = {"a_9x18": "9×18 ПСТ", "a_762": "7,62×39 ПС", "a_762bp": "7,62×39 БП", "a_12": "12/70 ДРОБЬ"}
KATEGORIE = {
    # broń: szarozielony druk wojskowy, zawsze czerwona pieczątka „ОДОБРЕНО”, linia wymiarowa
    "bron": {"papier": (170, 177, 158), "tusz": (30, 33, 38), "piecz": ["ОДОБРЕНО"], "szansa": 100, "kolor_p": (166, 38, 36)},
    # części i dodatki: niebieskoszary, numer części
    "czesci": {"papier": (166, 176, 184), "tusz": (28, 32, 46), "piecz": ["ОТК", "ДЕТ. 6П1-04", "КОНТРОЛЬ"], "szansa": 45},
    # amunicja: oliwkowy karton, kaliber szablonem
    "amunicja": {"papier": (176, 168, 128), "tusz": (34, 32, 24), "piecz": ["БОЕПРИПАСЫ", "ОТК", "ПАРТИЯ 17"], "szansa": 40},
    # pancerz, hełm: stalowoszary, klasa ochrony
    "pancerz": {"papier": (160, 166, 170), "tusz": (26, 28, 34), "piecz": ["КЛ. 2", "ГОСТ Р 50744", "ОТК"], "szansa": 70},
    # oporządzenie wojskowe
    "oporzadzenie": {"papier": (168, 174, 152), "tusz": (30, 33, 30), "piecz": ["ИНТЕНДАНТСТВО", "SPRAWDZONO", "EGZ. NR 2"], "szansa": 40},
    # leki: biały papier apteczny, czerwony krzyż w rogu
    "med": {"papier": (210, 208, 198), "tusz": (34, 36, 46), "piecz": ["APTEKA", "МИНЗДРАВ", "ważne do 1987"], "szansa": 35},
    # żywność i picie: różowawy karton jak kartka żywnościowa, metka z ceną
    "zywnosc": {"papier": (206, 180, 162), "tusz": (52, 34, 30), "piecz": ["SPOŁEM", "KARTKA", "ЦЕНА 22 КОП."], "szansa": 35},
    # narzędzia: kalka techniczna – granatowy papier, biała kreska
    "narzedzia": {"papier": (46, 70, 112), "tusz": (226, 232, 238), "piecz": ["WZÓR", "PN-72/M-0312"], "szansa": 30, "kolor_p": (230, 236, 242)},
    # rupiecie: pożółkła makulatura z resztkami druku
    "rupiecie": {"papier": (204, 186, 140), "tusz": (40, 36, 30), "piecz": ["DO SKUPU", "СКУПКА", "БРАК", "SPRAWDZONO"], "szansa": 35},
    "cywilne": {"papier": (198, 182, 140), "tusz": (40, 36, 30), "piecz": ["WZÓR", "ZATWIERDZONO"], "szansa": 30},
}


def kategoria(meta, nazwa):
    typ = meta.get("typ", "")
    if typ == "bron":
        return "bron"
    if typ in ("dodatek", "magazynek"):
        return "czesci"
    if typ == "amunicja":
        return "amunicja"
    if typ == "pancerz":
        return "pancerz"
    if typ == "med":
        return "med"
    if typ == "granat":
        return "amunicja"
    if typ == "pojemnik":
        return "cywilne" if nazwa in CYWILNE else "oporzadzenie"
    if nazwa in ZYWNOSC:
        return "zywnosc"
    if nazwa in NARZEDZIA or typ in ("klucz", "mapa", "kompas", "latarka"):
        return "narzedzia"
    return "rupiecie"


def dodatki_kategorii(img, w, h, kat, nazwa, maska, r, tusz):
    """Znaki rozpoznawcze kategorii: krzyż apteczny, metka z ceną, kaliber szablonem, siatka kalki,
    resztki druku na makulaturze, numer części."""
    d = ImageDraw.Draw(img)
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf", max(16, int(min(w, h) * 0.1)))
    except OSError:
        f = ImageFont.load_default()
    ink = tuple(int(v) for v in tusz) + (200,)
    if kat == "med":
        # czerwony krzyż w rogu
        a = max(14, int(min(w, h) * 0.16))
        x0, y0 = w - a - 10, 10
        d.rectangle([x0 + a * 0.36, y0, x0 + a * 0.64, y0 + a], fill=(180, 40, 36, 210))
        d.rectangle([x0, y0 + a * 0.36, x0 + a, y0 + a * 0.64], fill=(180, 40, 36, 210))
    elif kat == "zywnosc" and min(w, h) >= 2 * KOM * S * 0.5:
        # metka z ceną (naklejona krzywo)
        t = ["Cena zł 18,50", "zł 42,–", "ЦЕНА 22 к.", "zł 7,20"][int(r.integers(0, 4))]
        tw = d.textlength(t, font=f)
        mx, my = 8, h - f.size - 18
        d.rectangle([mx, my, mx + tw + 12, my + f.size + 10], fill=(236, 230, 214, 230), outline=ink, width=2)
        d.text((mx + 6, my + 3), t, font=f, fill=ink)
    elif kat == "amunicja":
        t = KALIBRY.get(nazwa.split("_garsc")[0], "")
        if t and min(w, h) >= KOM * S:
            # szablon: grube litery, przerwy jak w szablonie malarskim
            ff = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", max(14, int(min(w, h) * 0.12)))
            tw = d.textlength(t, font=ff)
            d.text(((w - tw) / 2, h - ff.size - 14), t, font=ff, fill=(60, 52, 30, 170))
    elif kat == "rupiecie" and w * h >= (3 * KOM * S) ** 2 * 0.6:
        # resztki druku gazety w tle – tylko tam, gdzie nie ma rysunku
        druk = Image.new("L", (w, h), 0)
        dd = ImageDraw.Draw(druk)
        for i in range(int(h / 22)):
            y = 10 + i * 22
            if r.random() < 0.45:
                continue
            x0 = int(r.uniform(0.0, 0.3) * w)
            x1 = int(r.uniform(0.4, 1.0) * w)
            dd.line([(x0, y), (x1, y)], fill=255, width=4)
        wolne = ~ndimage.binary_dilation(maska, iterations=10)
        a = (np.asarray(druk, np.float32) / 255.0) * wolne * 0.22
        warstwa = Image.new("RGBA", (w, h), (80, 70, 50, 0))
        warstwa.putalpha(Image.fromarray((a * 255).astype(np.uint8)))
        img.alpha_composite(warstwa)
    elif kat == "czesci" and w * h >= (3 * KOM * S) ** 2 * 0.3:
        t = "дет. %d-%02d" % (int(r.integers(2, 9)), int(r.integers(1, 40)))
        d.text((12, 8), t, font=f, fill=ink)


def rodzaj_papieru(meta, nazwa):
    typ = meta.get("typ", "")
    if typ == "med":
        return "med"
    if typ in ("bron", "dodatek", "magazynek", "amunicja", "pancerz", "granat") or (typ == "pojemnik" and nazwa not in CYWILNE):
        return "wojsko"
    return "lup"


def papier(h, w, r, baza=PAPIER, kalka=False):
    p = np.ones((h, w, 3), np.float32) * baza
    if kalka:
        yy, xx = np.mgrid[0:h, 0:w]
        siatka = ((xx % 24) < 1.5) | ((yy % 24) < 1.5)
        p[siatka] += 22
    p += szum(h, w, r, 6)[..., None] * 18
    p += szum(h, w, r, 40)[..., None] * 22
    # plamy (zacieki, ślady palców)
    plamy = np.clip(szum(h, w, r, 30) * 3.0 - 0.6, 0, 1)
    p -= plamy[..., None] * np.array([18, 26, 46])
    # włókna
    for _ in range(int(h * w / 9000) + 2):
        y, x = r.integers(0, h), r.integers(0, w)
        dl = r.integers(6, 20)
        kat = r.uniform(0, np.pi)
        for t in range(dl):
            yy, xx = int(y + np.sin(kat) * t), int(x + np.cos(kat) * t)
            if 0 <= yy < h and 0 <= xx < w:
                p[yy, xx] -= 14
    # alfa: wyrwane brzegi (postrzępione, z jednej-dwóch stron mocniej)
    a = np.ones((h, w), np.float32)
    marg = 3
    for bok in range(4):
        dl = w if bok < 2 else h
        mocno = r.random() < 0.35
        prof = np.clip(marg + (np.abs(np.cumsum(r.normal(0, 1.4 if mocno else 0.7, dl))) % (9 if mocno else 4)), 0, 14).astype(int)
        for i in range(dl):
            k = prof[i]
            if bok == 0:
                a[:k, i] = 0
            elif bok == 1:
                a[h - k:, i] = 0
            elif bok == 2:
                a[i, :k] = 0
            else:
                a[i, w - k:] = 0
    # zagięcie / pęknięcie: lekko ciemniejsza linia
    if r.random() < 0.4:
        x0 = r.integers(w // 4, max(w // 4 + 1, 3 * w // 4))
        p[:, x0:x0 + 2] -= 16
    return p, a


def rysunek(n_img, d_img, h, w, r, c_img=None):
    n = np.asarray(n_img, np.float32)
    d = np.asarray(d_img, np.float32)
    maska = n[..., 3] > 128
    nv = n[..., :3] / 255.0 * 2.0 - 1.0
    # nakładające się płaskie części (naklejki, nadruki) migoczą normalnymi – mediana je wygładza
    nv = ndimage.median_filter(nv, size=(5, 5, 1))
    gl = d[..., 0] / 255.0          # tylko kanał zgrubny (drobny „fract” daje fałszywe uskoki)
    gl[~maska] = 1.2
    # krawędzie: zagięcia (normalne), uskoki głębi, sylwetka
    gn = sum(np.hypot(ndimage.sobel(nv[..., c], 0), ndimage.sobel(nv[..., c], 1)) for c in range(3))
    gn[~maska] = 0
    # uskok głębi = druga pochodna (pochyła płaszczyzna ma stały spadek – to nie krawędź)
    gd = np.abs(ndimage.laplace(ndimage.uniform_filter(gl, 2)))
    wew = (gn > 1.6) | ((gd > 0.035) & maska)
    sylw = maska ^ ndimage.binary_erosion(maska, iterations=1)
    sylw = ndimage.binary_dilation(sylw, iterations=2)
    wew = ndimage.binary_dilation(wew, iterations=1) & ~sylw
    # cieniowanie z normalnych: światło z lewej-góry-przodu
    L = np.array([-0.45, 0.6, 0.66])
    L /= np.linalg.norm(L)
    jas = np.clip((nv @ L), -1, 1)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # granice barw (nadruki, naklejki, okucia) – cienka kreska; ciemne materiały – lekki ton ołówka
    barwa = np.zeros((h, w), bool)
    ton = np.zeros((h, w), np.float32)
    if c_img is not None:
        c = np.asarray(c_img, np.float32)
        lum = (c[..., 0] * 0.3 + c[..., 1] * 0.59 + c[..., 2] * 0.11) / 255.0
        lum = ndimage.median_filter(lum, size=3)
        gc = np.hypot(ndimage.sobel(lum, 0), ndimage.sobel(lum, 1))
        barwa = (gc > 0.55) & ndimage.binary_erosion(maska, iterations=2)
        ton = np.where(maska, np.clip(0.5 - lum, 0, 1) * 0.35, 0)
    # cieniowanie paskami (jak w ilustracjach technicznych z lat 70.): równoległe kreski wzdłuż
    # długiej osi rysunku, grubsze tam, gdzie ciemniej – walce dostają pasy gęstniejące ku krawędzi,
    # ściany w świetle zostają białe.
    ciem = np.clip((0.66 - jas) / 0.8, 0.0, 1.0) ** 1.1 + ton * 0.8
    ciem = np.where(maska, np.clip(ciem, 0.0, 1.0), 0.0)
    ciem = ndimage.gaussian_filter(ciem, 1.5)
    rozstaw = 14.0          # 3,5 px w grze – paski widać, bez mory
    wzdl = yy if w >= h else xx
    faza = wzdl / rozstaw + szum(h, w, r, 24) * 0.08
    odl = np.abs(faza - np.round(faza)) * rozstaw          # odległość od osi paska (px)
    pol_szer = ciem * rozstaw * 0.42
    pasek = np.clip(pol_szer - odl + 0.8, 0.0, 1.0) * (ciem > 0.08)
    tusz = np.zeros((h, w), np.float32)
    tusz = np.maximum(tusz, pasek * 0.78)
    tusz[barwa] = np.maximum(tusz[barwa], 0.6)
    tusz[wew] = np.maximum(tusz[wew], 0.8)
    tusz[sylw] = 1.0
    # przerwy w kresce (tusz nierówno schodzi)
    przer = szum(h, w, r, 5) > 0.38
    tusz[przer & ~sylw] *= 0.55
    return tusz, maska


def adnotacje(img, w, h, meta, nazwa, maska, r, tusz=None):
    d = ImageDraw.Draw(img)
    try:
        f = ImageFont.truetype(CZCIONKA, max(18, int(min(w, h) * 0.075)))
    except OSError:
        f = ImageFont.load_default()
    kolor = tuple(int(v) for v in tusz) + (220,) if tusz is not None else (40, 38, 52, 220)
    cw, ch = meta["w"], meta["h"]
    nr = zlib.crc32(nazwa.encode()) % 40 + 1
    ys, xs = np.nonzero(maska)
    if len(xs) == 0:
        return
    # linia wymiarowa pod bronią: strzałki i liczba (długość w mm)
    if meta.get("typ") == "bron" and h >= 2 * KOM * S:
        x0, x1 = int(xs.min()), int(xs.max())
        y = min(h - 14, int(ys.max()) + 14)
        d.line([(x0, y), (x1, y)], fill=kolor, width=2)
        for x in (x0, x1):
            d.line([(x, y - 9), (x, y + 9)], fill=kolor, width=2)
        d.polygon([(x0, y), (x0 + 12, y - 4), (x0 + 12, y + 4)], fill=kolor)
        d.polygon([(x1, y), (x1 - 12, y - 4), (x1 - 12, y + 4)], fill=kolor)
        mm = {"pw9": "161", "pm63": "583", "kb47": "870", "obrzyn": "540"}.get(nazwa, str(int((x1 - x0) * 1.1)))
        tw = d.textlength(mm, font=f)
        d.rectangle([(x0 + x1) / 2 - tw / 2 - 4, y - 12, (x0 + x1) / 2 + tw / 2 + 4, y + 12], fill=None)
        d.text(((x0 + x1) / 2 - tw / 2, y - 26), mm, font=f, fill=kolor)
    # odnośnik z numerem części
    if cw * ch >= 4:
        i = r.integers(0, len(xs))
        px, py = int(xs[i]), int(ys[i])
        kx = w - 26 if px < w / 2 else 26
        kx = int(np.clip(kx, 26, w - 26))
        ky = int(np.clip(py - 30, 24, h - 24))
        d.line([(px, py), (kx, ky)], fill=kolor, width=2)
        d.ellipse([px - 3, py - 3, px + 3, py + 3], fill=kolor)
        d.ellipse([kx - 15, ky - 15, kx + 15, ky + 15], outline=kolor, width=2)
        t = str(r.integers(1, 9))
        d.text((kx - d.textlength(t, font=f) / 2, ky - f.size * 0.6), t, font=f, fill=kolor)
    # podpis „Rys.”
    if cw >= 3 and ch >= 2:
        t = ("Рис. %d" if zlib.crc32((nazwa + "ru").encode()) % 100 < 35 else "Rys. %d") % nr
        d.text((14, h - f.size - 12), t, font=f, fill=kolor)


PIECZATKI = ["ZATWIERDZONO", "ОТК", "КОНТРОЛЬ", "PN-72/M-0312", "ГОСТ 1050-74", "WZÓR", "ЗАВОД № 7",
             "EGZ. NR 2", "ДСП", "SPRAWDZONO", "БРАК", "Kontr. jak."]
CZERWONY = (168, 42, 40)
FIOLET = (92, 62, 138)


def pieczatka(img, w, h, maska, r, nazwa, lista=None, kolor=None):
    """Wyblakła pieczątka gumowa w wolnym rogu (czerwona albo fioletowa), lekko krzywo, z ubytkami tuszu."""
    lista = lista or PIECZATKI
    t = lista[int(r.integers(0, len(lista)))]
    rozm = max(16, int(min(w, h) * 0.13))
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", rozm)
    except OSError:
        f = ImageFont.load_default()
    tmp = Image.new("L", (int(f.getlength(t)) + rozm * 2, rozm * 3), 0)
    d = ImageDraw.Draw(tmp)
    tw = f.getlength(t)
    okragla = r.random() < 0.3 and len(t) <= 6
    if okragla:
        s = int(max(tw, rozm) + rozm * 1.4)
        tmp = Image.new("L", (s, s), 0)
        d = ImageDraw.Draw(tmp)
        d.ellipse([2, 2, s - 3, s - 3], outline=255, width=max(2, rozm // 7))
        d.ellipse([rozm // 3, rozm // 3, s - rozm // 3, s - rozm // 3], outline=255, width=max(1, rozm // 12))
        d.text(((s - tw) / 2, s / 2 - rozm * 0.62), t, font=f, fill=255)
    else:
        d.rectangle([3, 3, tmp.width - 4, tmp.height - 4], outline=255, width=max(2, rozm // 7))
        d.text((rozm, rozm * 0.85), t, font=f, fill=255)
    tmp = tmp.rotate(float(r.uniform(-16, 16)), expand=True, resample=Image.BICUBIC)
    if tmp.width > w * 0.8 or tmp.height > h * 0.8:
        sk = min(w * 0.8 / tmp.width, h * 0.8 / tmp.height)
        tmp = tmp.resize((max(1, int(tmp.width * sk)), max(1, int(tmp.height * sk))), Image.BICUBIC)
    a = np.asarray(tmp, np.float32) / 255.0
    # ubytki tuszu: nierówny docisk gumki
    a *= np.clip(0.55 + szum(tmp.height, tmp.width, r, 4) * 1.6, 0, 1) * float(r.uniform(0.5, 0.75))
    # róg, w którym jest najmniej rysunku
    ys, xs = np.nonzero(maska)
    best, poz = None, (0, 0)
    for (px, py) in [(6, 6), (w - tmp.width - 6, 6), (6, h - tmp.height - 6), (w - tmp.width - 6, h - tmp.height - 6)]:
        px, py = max(0, px), max(0, py)
        zaj = maska[py:py + tmp.height, px:px + tmp.width].mean() if maska[py:py + tmp.height, px:px + tmp.width].size else 1.0
        if best is None or zaj < best:
            best, poz = zaj, (px, py)
    kol = kolor if kolor else (CZERWONY if r.random() < 0.6 else FIOLET)
    warstwa = Image.new("RGBA", (tmp.width, tmp.height), kol + (0,))
    warstwa.putalpha(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)))
    img.alpha_composite(warstwa, poz)


def ikona(kat, nazwa, meta):
    n = Image.open(kat / f"{nazwa}_n.png").convert("RGBA")
    dimg = Image.open(kat / f"{nazwa}_d.png").convert("RGBA")
    W, H = n.size
    r = rng_dla(nazwa)
    cp = kat / f"{nazwa}_c.png"
    cimg = Image.open(cp).convert("RGBA") if cp.exists() else None
    tusz, maska = rysunek(n, dimg, H, W, r, cimg)
    baza_id = nazwa.split("_garsc")[0]
    kat_p = kategoria(meta, baza_id)
    kp = KATEGORIE[kat_p]
    ink = np.array(kp["tusz"], dtype=np.float32)
    pap, alfa = papier(H, W, r, np.array(kp["papier"], dtype=np.float32), kat_p == "narzedzia")
    kol = pap * (1 - tusz[..., None]) + ink * tusz[..., None]
    rgba = np.dstack([np.clip(kol, 0, 255), alfa * 255]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    dodatki_kategorii(img, W, H, kat_p, nazwa, maska, r, ink)
    adnotacje(img, W, H, meta, baza_id, maska, r, ink)
    # pieczątka: broń zawsze („ОДОБРЕНО”), reszta tylko na części rysunków, gdzie da się ją odczytać
    duza = meta["w"] * meta["h"] >= 6 and min(meta["w"], meta["h"]) >= 2
    if (kat_p == "bron" or duza) and zlib.crc32((nazwa + "piecz").encode()) % 100 < kp["szansa"]:
        pieczatka(img, W, H, maska, r, nazwa, kp["piecz"], kp.get("kolor_p"))
    # docelowy rozmiar: ramka przedmiotu w siatce (KOM na kratkę, 3 px marginesu)
    cel = (max(6, meta["w"] * KOM - 3), max(6, meta["h"] * KOM - 3))
    img = img.resize(cel, Image.LANCZOS)
    img = img.filter(ImageFilter.UnsharpMask(radius=0.6, percent=60, threshold=2))
    img.save(OUT / f"{nazwa}.png")


def main():
    kat = Path(sys.argv[1])
    meta = json.loads((kat / "meta.json").read_text())
    for nazwa, m in meta.items():
        ikona(kat, nazwa, m)
    print("ikony-szkice:", len(meta))


if __name__ == "__main__":
    main()
