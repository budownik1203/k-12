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


def papier(h, w, r):
    p = np.ones((h, w, 3), np.float32) * PAPIER
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
    yy, xx = np.mgrid[0:h, 0:w]
    drg = szum(h, w, r, 12) * 3.0                # drżenie ręki
    k1 = ((xx + yy + drg).astype(int) % 7) < 1.6
    k2 = ((xx - yy + drg).astype(int) % 7) < 1.6
    k3 = ((xx + 2 * yy + drg).astype(int) % 9) < 1.4
    kresk = maska & (((jas < 0.42) & k1) | ((jas < 0.18) & k2) | ((jas < 0.0) & k3))
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
    tusz = np.zeros((h, w), np.float32)
    tusz[barwa] = 0.55
    tusz[sylw] = 1.0
    tusz[wew] = np.maximum(tusz[wew], 0.75)
    tusz[kresk] = np.maximum(tusz[kresk], 0.5)
    # lekkie wypełnienie bryły (szary podkład ołówkiem w cieniu)
    pod = np.where(maska, np.clip(0.55 - jas, 0, 1) * 0.16, 0)
    # przerwy w kresce (tusz nierówno schodzi)
    przer = szum(h, w, r, 5) > 0.33
    tusz[przer & ~sylw] *= 0.35
    return np.maximum(tusz, np.maximum(pod, ton)), maska


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
        t = "Rys. %d" % nr
        d.text((14, h - f.size - 12), t, font=f, fill=kolor)


def ikona(kat, nazwa, meta):
    n = Image.open(kat / f"{nazwa}_n.png").convert("RGBA")
    dimg = Image.open(kat / f"{nazwa}_d.png").convert("RGBA")
    W, H = n.size
    r = rng_dla(nazwa)
    cp = kat / f"{nazwa}_c.png"
    cimg = Image.open(cp).convert("RGBA") if cp.exists() else None
    tusz, maska = rysunek(n, dimg, H, W, r, cimg)
    pap, alfa = papier(H, W, r)
    kol = pap * (1 - tusz[..., None]) + TUSZ * tusz[..., None]
    rgba = np.dstack([np.clip(kol, 0, 255), alfa * 255]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    adnotacje(img, W, H, meta, nazwa.split("_garsc")[0] if "_garsc" in nazwa else nazwa, maska, r)
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
