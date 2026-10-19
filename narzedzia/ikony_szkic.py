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


def rodzaj_papieru(meta, nazwa):
    typ = meta.get("typ", "")
    if typ == "med":
        return "med"
    if typ in ("bron", "dodatek", "magazynek", "amunicja", "pancerz", "granat") or (typ == "pojemnik" and nazwa not in CYWILNE):
        return "wojsko"
    return "lup"


def papier(h, w, r, baza=PAPIER):
    p = np.ones((h, w, 3), np.float32) * baza
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


def adnotacje(img, w, h, meta, nazwa, maska, r):
    d = ImageDraw.Draw(img)
    try:
        f = ImageFont.truetype(CZCIONKA, max(18, int(min(w, h) * 0.075)))
    except OSError:
        f = ImageFont.load_default()
    kolor = (40, 38, 52, 220)
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


def pieczatka(img, w, h, maska, r, nazwa):
    """Wyblakła pieczątka gumowa w wolnym rogu (czerwona albo fioletowa), lekko krzywo, z ubytkami tuszu."""
    t = PIECZATKI[int(r.integers(0, len(PIECZATKI)))]
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
    kol = CZERWONY if r.random() < 0.6 else FIOLET
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
    pap, alfa = papier(H, W, r, PAPIERY[rodzaj_papieru(meta, nazwa.split("_garsc")[0])])
    kol = pap * (1 - tusz[..., None]) + TUSZ * tusz[..., None]
    rgba = np.dstack([np.clip(kol, 0, 255), alfa * 255]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    adnotacje(img, W, H, meta, nazwa.split("_garsc")[0] if "_garsc" in nazwa else nazwa, maska, r)
    # pieczątka tylko na części rysunków (i tylko tam, gdzie da się ją odczytać)
    if meta["w"] * meta["h"] >= 6 and min(meta["w"], meta["h"]) >= 2 and zlib.crc32((nazwa + "piecz").encode()) % 100 < 40:
        pieczatka(img, W, H, maska, r, nazwa)
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
