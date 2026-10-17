"""Tekstury interfejsu ekwipunku: płótno oporządzenia, kieszenie z przeszyciem, naszywki, siatka komórki.
Uruchom: python3 narzedzia/generuj_ui.py"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "textures" / "ui"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(12)


def splot(w, h, baza, kontrast=10, szum=6):
    """Tkanina: splot płócienny (pionowe i poziome nitki) + szum + plamy zużycia."""
    y, x = np.mgrid[0:h, 0:w]
    nitki = (np.sin(x * np.pi / 2.0) * np.sin(y * np.pi / 2.0)) * kontrast
    pas = (np.sin(y * 0.9) * 0.5 + np.sin(x * 1.1) * 0.5) * kontrast * 0.3
    n = rng.normal(0, szum, (h, w))
    plamy = Image.fromarray((rng.random((h // 8 + 1, w // 8 + 1)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    plamy = (np.asarray(plamy, dtype=np.float32) / 255.0 - 0.5) * 18
    img = np.zeros((h, w, 3), dtype=np.float32)
    for i in range(3):
        img[..., i] = baza[i] + nitki + pas + n + plamy
    return np.clip(img, 0, 255).astype(np.uint8)


def zapisz(arr, nazwa):
    Image.fromarray(arr).save(OUT / nazwa)


# tło: ciemne płótno wnętrza plecaka (kafelkowane)
zapisz(splot(128, 128, (38, 40, 31), 7, 5), "plotno.png")

# kieszeń (9-patch 64x64, marginesy 14): jaśniejsze płótno, lamówka, przeszycie przerywane
def kieszen(baza, nazwa, lamowka=(28, 29, 23)):
    a = splot(64, 64, baza, 8, 5)
    img = Image.fromarray(a).convert("RGBA")
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 63, 63], outline=lamowka + (255,), width=4)
    d.rectangle([4, 4, 59, 59], outline=(0, 0, 0, 90), width=1)
    # przeszycie
    for i in range(8, 56, 5):
        for (x0, y0, x1, y1) in [(i, 7, i + 2, 7), (i, 56, i + 2, 56), (7, i, 7, i + 2), (56, i, 56, i + 2)]:
            d.line([x0, y0, x1, y1], fill=(150, 140, 100, 200), width=1)
    img.save(OUT / nazwa)

kieszen((58, 61, 46), "kieszen.png")
kieszen((46, 48, 38), "kieszen_ciemna.png")

# naszywka z nazwą (9-patch 48x20): khaki z obszyciem
img = Image.new("RGBA", (48, 20), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rectangle([0, 0, 47, 19], fill=(96, 92, 66, 255), outline=(40, 38, 28, 255), width=2)
for i in range(4, 44, 4):
    d.point((i, 3), fill=(150, 140, 100, 255))
    d.point((i, 16), fill=(150, 140, 100, 255))
img.save(OUT / "naszywka.png")

# komórka siatki: ciemne wnętrze kieszeni z delikatnym przeszyciem
a = splot(34, 34, (24, 25, 20), 5, 4)
img = Image.fromarray(a).convert("RGBA")
d = ImageDraw.Draw(img)
d.rectangle([0, 0, 33, 33], outline=(52, 52, 42, 255), width=1)
img.save(OUT / "komorka.png")
print("ui: ok")
