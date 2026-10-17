"""Generator mebli i wyposażenia biomu 1 (mieszkania, piwnice, magazyny).

Uruchomienie:  cd narzedzia && python3 generuj_meble.py
Wynik:         assets/models/meble/*.glb oraz assets/dane/meble.json (wymiary, osłony, typ pojemnika).

Każdy mebel: środek na podłodze pośrodku podstawy, przód patrzy w +z.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from gltf_mini import Mesh, write_glb

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "models" / "meble"
OUT.mkdir(parents=True, exist_ok=True)
TEX = ROOT / "assets" / "textures"


def tex_extra():
    r = np.random.default_rng(401)
    # dywan
    w, h = 64, 48
    img = Image.new("RGB", (w, h), (110, 34, 30))
    d = ImageDraw.Draw(img)
    d.rectangle([3, 3, w - 4, h - 4], outline=(160, 120, 60))
    d.rectangle([7, 7, w - 8, h - 8], outline=(40, 30, 50))
    for cx in (20, 44):
        d.polygon([(cx, 12), (cx + 9, 24), (cx, 36), (cx - 9, 24)], outline=(170, 130, 70), fill=(60, 40, 70))
    a = np.array(img).astype(float) * (0.75 + 0.3 * r.random((h, w, 1)))
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(TEX / "dywan.png")
    # apteczka ścienna
    img = Image.new("RGB", (32, 32), (200, 198, 186))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 31, 31], outline=(120, 118, 110))
    d.rectangle([13, 7, 18, 24], fill=(180, 30, 30))
    d.rectangle([7, 13, 24, 18], fill=(180, 30, 30))
    img.save(TEX / "apteczka_sciana.png")
    # półki z kartonami
    img = Image.new("RGB", (64, 128), (40, 40, 40))
    d = ImageDraw.Draw(img)
    for sy in range(0, 128, 32):
        d.rectangle([0, sy + 28, 63, sy + 31], fill=(70, 72, 74))
        x = 2
        while x < 60:
            bw = int(r.integers(8, 18))
            bh = int(r.integers(10, 24))
            c = tuple(int(v) for v in (r.integers(110, 160), r.integers(90, 120), r.integers(50, 80)))
            d.rectangle([x, sy + 28 - bh, min(62, x + bw), sy + 27], fill=c, outline=(60, 50, 30))
            x += bw + int(r.integers(1, 5))
    img.save(TEX / "regal_polki.png")


MAT = {
    "fornir": {"texture": "fornir.png"}, "tkanina": {"texture": "tkanina.png"},
    "metal_ciemny": {"texture": "metal_ciemny.png"}, "emalia": {"texture": "emalia.png"},
    "lastryko": {"texture": "lastryko.png"}, "ekran_tv": {"texture": "ekran_tv.png"},
    "metal_zielony": {"texture": "metal_zielony.png"}, "worek_piasek": {"texture": "worek_piasek.png"},
    "drewno": {"texture": "drewno.png"}, "materac": {"texture": "materac.png"},
    "zarowka_emit": {"texture": "zarowka.png"}, "dywan": {"texture": "dywan.png"},
    "apteczka_sciana": {"texture": "apteczka_sciana.png"}, "regal_polki": {"texture": "regal_polki.png"},
    "szafka": {"texture": "szafka.png"}, "beton": {"texture": "beton.png"},
    "znak_wyjscie_emit": {"texture": "znak_wyjscie.png"}, "okno_emit": {"texture": "okno.png"},
}

META = {}


def zapisz(nazwa, mesh, rozmiar, oslona=None, pojemnik=None, opis=""):
    write_glb(OUT / f"{nazwa}.glb", [(nazwa, mesh, [0, 0, 0])], MAT, texture_dir_rel="../../textures")
    META[nazwa] = {"rozmiar": rozmiar, "oslona": oslona, "pojemnik": pojemnik, "nazwa": opis}


def nogi(m, mat, w, d, h, t=0.04, inset=0.04):
    for sx in (-1, 1):
        for sz in (-1, 1):
            x = sx * (w / 2 - inset - t / 2)
            z = sz * (d / 2 - inset - t / 2)
            m.box(mat, (x - t / 2, 0, z - t / 2), (x + t / 2, h, z + t / 2))


def stol():
    m = Mesh()
    w, d, h = 1.2, 0.8, 0.75
    m.box("fornir", (-w / 2, h - 0.04, -d / 2), (w / 2, h, d / 2), tiles=1.5)
    nogi(m, "fornir", w, d, h - 0.04)
    zapisz("stol", m, [w, h, d], None, None, "Stół")


def krzeslo():
    m = Mesh()
    m.box("fornir", (-0.22, 0.44, -0.22), (0.22, 0.48, 0.22))
    nogi(m, "fornir", 0.44, 0.44, 0.44, 0.035, 0.02)
    m.box("fornir", (-0.22, 0.48, -0.22), (0.22, 0.9, -0.19))
    zapisz("krzeslo", m, [0.45, 0.9, 0.45], None, None, "Krzesło")


def wersalka():
    m = Mesh()
    m.box("tkanina", (-0.95, 0.12, -0.42), (0.95, 0.45, 0.42), tiles=2)
    m.box("tkanina", (-0.95, 0.45, -0.42), (0.95, 0.85, -0.22), tiles=2)
    for sx in (-1, 1):
        m.box("fornir", (sx * 0.95 - 0.06, 0.0, -0.42), (sx * 0.95 + 0.06, 0.6, 0.42))
    m.box("fornir", (-0.9, 0.0, -0.4), (0.9, 0.12, 0.4))
    zapisz("wersalka", m, [2.02, 0.85, 0.85], "niska", None, "Wersalka")


def lozko():
    m = Mesh()
    m.box("metal_ciemny", (-0.95, 0.25, -0.45), (0.95, 0.3, 0.45))
    nogi(m, "metal_ciemny", 1.9, 0.9, 0.3, 0.04, 0.0)
    m.box("materac", (-0.93, 0.3, -0.43), (0.93, 0.45, 0.43), tiles=2)
    m.box("metal_ciemny", (-0.97, 0.0, -0.45), (-0.93, 0.85, 0.45))
    m.box("metal_ciemny", (0.93, 0.0, -0.45), (0.97, 0.6, 0.45))
    zapisz("lozko", m, [1.94, 0.85, 0.9], None, None, "Łóżko")


def meblosciana():
    m = Mesh()
    w, h, d = 2.4, 2.0, 0.5
    m.box("fornir", (-w / 2, 0, -d / 2), (w / 2, h, d / 2), uv="world", tiles=1.2)
    # przeszklona część środkowa
    m.box("regal_polki", (-0.4, 0.9, d / 2), (0.4, 1.7, d / 2 + 0.01), uv="fit", faces="+z")
    for x in (-0.8, 0.0, 0.8):
        m.box("metal_ciemny", (x - 0.02, 0.5, d / 2), (x + 0.02, 0.6, d / 2 + 0.03))
    zapisz("meblosciana", m, [w, h, d], "wysoka", "szafa", "Meblościanka")


def szafa():
    m = Mesh()
    w, h, d = 1.0, 1.9, 0.6
    m.box("fornir", (-w / 2, 0, -d / 2), (w / 2, h, d / 2), tiles=1.3)
    m.box("metal_ciemny", (-0.02, 0.9, d / 2), (0.02, 1.05, d / 2 + 0.03))
    zapisz("szafa", m, [w, h, d], "wysoka", "szafa", "Szafa")


def kuchenka():
    m = Mesh()
    m.box("emalia", (-0.28, 0, -0.3), (0.28, 0.85, 0.3), uv="fit")
    for x in (-0.12, 0.12):
        for z in (-0.12, 0.12):
            m.box("metal_ciemny", (x - 0.07, 0.85, z - 0.07), (x + 0.07, 0.87, z + 0.07))
    m.box("metal_ciemny", (-0.22, 0.2, 0.3), (0.22, 0.6, 0.31), faces="+z")
    zapisz("kuchenka", m, [0.56, 0.87, 0.6], None, None, "Kuchenka")


def lodowka():
    m = Mesh()
    m.box("emalia", (-0.3, 0, -0.3), (0.3, 1.5, 0.3), uv="fit")
    m.box("metal_ciemny", (0.2, 0.9, 0.3), (0.24, 1.2, 0.34))
    m.box("metal_ciemny", (-0.3, 1.1, 0.3), (0.3, 1.11, 0.305), faces="+z")
    zapisz("lodowka", m, [0.6, 1.5, 0.6], "wysoka", "szafka_kuchenna", "Lodówka Mińsk")


def szafka_kuchenna():
    m = Mesh()
    m.box("fornir", (-0.6, 0.08, -0.3), (0.6, 0.85, 0.3))
    m.box("lastryko", (-0.62, 0.85, -0.31), (0.62, 0.89, 0.32))
    m.box("metal_ciemny", (-0.58, 0.0, -0.28), (0.58, 0.08, 0.26))
    for x in (-0.3, 0.3):
        m.box("metal_ciemny", (x - 0.06, 0.72, 0.3), (x + 0.06, 0.74, 0.32))
    zapisz("szafka_kuchenna", m, [1.24, 0.89, 0.62], "niska", "szafka_kuchenna", "Szafka kuchenna")


def regal_metalowy():
    m = Mesh()
    w, h, d = 1.0, 1.9, 0.45
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box("metal_ciemny", (sx * w / 2 - 0.03 * (sx > 0), 0, sz * d / 2 - 0.03 * (sz > 0)),
                  (sx * w / 2 + 0.03 * (sx < 0), h, sz * d / 2 + 0.03 * (sz < 0)))
    for y in (0.1, 0.55, 1.0, 1.45, 1.86):
        m.box("metal_ciemny", (-w / 2, y, -d / 2), (w / 2, y + 0.03, d / 2))
    m.box("regal_polki", (-w / 2 + 0.03, 0.13, -d / 2 + 0.05), (w / 2 - 0.03, 1.86, -d / 2 + 0.06), uv="fit", faces="+z")
    zapisz("regal_metalowy", m, [w, h, d], "wysoka", "regal", "Regał")


def skrzynia_wojskowa():
    m = Mesh()
    m.box("metal_zielony", (-0.5, 0, -0.27), (0.5, 0.5, 0.27), uv="fit")
    for x in (-0.38, 0.38):
        m.box("metal_ciemny", (x - 0.05, 0.3, 0.27), (x + 0.05, 0.38, 0.3))
    zapisz("skrzynia_wojskowa", m, [1.0, 0.5, 0.56], "niska", "skrzynia_wojskowa", "Skrzynia wojskowa")


def biurko():
    m = Mesh()
    m.box("fornir", (-0.65, 0.72, -0.35), (0.65, 0.76, 0.35))
    m.box("fornir", (0.2, 0.0, -0.33), (0.63, 0.72, 0.33))
    m.box("fornir", (-0.63, 0.0, -0.33), (-0.58, 0.72, 0.33))
    for y in (0.15, 0.4, 0.6):
        m.box("metal_ciemny", (0.38, y, 0.33), (0.45, y + 0.02, 0.35))
    m.box("fornir", (-0.58, 0.3, -0.33), (0.2, 0.72, -0.3))
    zapisz("biurko", m, [1.3, 0.76, 0.7], "niska", "biurko", "Biurko")


def telewizor():
    m = Mesh()
    m.box("fornir", (-0.35, 0, -0.25), (0.35, 0.55, 0.25))
    m.box("fornir", (-0.3, 0.55, -0.24), (0.3, 1.0, 0.2))
    m.box("ekran_tv", (-0.24, 0.6, 0.2), (0.18, 0.94, 0.21), uv="fit", faces="+z")
    for y in (0.66, 0.74, 0.82):
        m.box("metal_ciemny", (0.21, y, 0.2), (0.26, y + 0.04, 0.22))
    zapisz("telewizor", m, [0.7, 1.0, 0.5], None, None, "Telewizor Rubin")


def worki_piasek():
    m = Mesh()
    for row, y in enumerate((0.0, 0.2, 0.4, 0.6)):
        off = 0.2 if row % 2 else 0.0
        x = -0.8 + off
        while x < 0.8 - 0.35:
            m.box("worek_piasek", (x, y, -0.25), (x + 0.38, y + 0.2, 0.25), uv="fit")
            x += 0.4
    zapisz("worki_piasek", m, [1.6, 0.8, 0.5], "niska", None, "Worki z piaskiem")


def stol_warsztatowy():
    m = Mesh()
    m.box("drewno", (-0.9, 0.85, -0.35), (0.9, 0.9, 0.35), uv="fit")
    nogi(m, "metal_ciemny", 1.8, 0.7, 0.85, 0.05, 0.02)
    m.box("metal_ciemny", (-0.88, 0.2, -0.33), (0.88, 0.23, 0.33))
    m.box("metal_ciemny", (0.6, 0.9, 0.15), (0.8, 1.02, 0.32))
    zapisz("stol_warsztatowy", m, [1.8, 1.02, 0.7], "niska", "regal", "Stół warsztatowy")


def zarowka():
    m = Mesh()
    m.beam("metal_ciemny", (0, 0, 0), (0, -0.45, 0), 0.01, 0.01)
    m.box("metal_ciemny", (-0.025, -0.5, -0.025), (0.025, -0.45, 0.025))
    m.box("zarowka_emit", (-0.04, -0.6, -0.04), (0.04, -0.5, 0.04), uv="fit")
    zapisz("zarowka", m, [0.1, 0.6, 0.1], None, None, "Żarówka")


def krata():
    m = Mesh()
    w, h = 1.2, 1.4
    for i in range(7):
        x = -w / 2 + 0.05 + i * (w - 0.1) / 6
        m.beam("metal_ciemny", (x, 0, 0), (x, h, 0), 0.025, 0.025)
    for y in (0.05, h / 2, h - 0.05):
        m.beam("metal_ciemny", (-w / 2, y, 0), (w / 2, y, 0), 0.03, 0.02)
    zapisz("krata", m, [w, h, 0.05], None, None, "Krata")


def apteczka_scienna():
    m = Mesh()
    m.box("emalia", (-0.2, 0, 0), (0.2, 0.45, 0.14), uv="fit", mats={"+z": "apteczka_sciana"}, faces="+z+x-x+y-y")
    zapisz("apteczka_scienna", m, [0.4, 0.45, 0.14], None, "apteczka_scienna", "Apteczka ścienna")


def dywan():
    m = Mesh()
    m.quad("dywan", (-1.0, 0.005, 0.7), (1.0, 0.005, 0.7), (1.0, 0.005, -0.7), (-1.0, 0.005, -0.7),
           (0, 1), (1, 1), (1, 0), (0, 0), facing=np.array((0, 1.0, 0)))
    zapisz("dywan", m, [2.0, 0.01, 1.4], None, None, "Dywan")


def znak_wyjscie():
    m = Mesh()
    m.box("metal_ciemny", (-0.32, 0, 0), (0.32, 0.32, 0.04), faces="+x-x+y-y")
    m.box("znak_wyjscie_emit", (-0.3, 0.02, 0.04), (0.3, 0.3, 0.045), uv="fit", faces="+z")
    zapisz("znak_wyjscie", m, [0.64, 0.32, 0.05], None, None, "Znak wyjścia")


def szafka_metalowa():
    m = Mesh()
    m.box("szafka", (-0.25, 0, -0.22), (0.25, 1.8, 0.22), uv="fit", faces="+z+x-x+y")
    zapisz("szafka_metalowa", m, [0.5, 1.8, 0.45], "wysoka", "szafa", "Szafka ubraniowa")


if __name__ == "__main__":
    tex_extra()
    for f in (stol, krzeslo, wersalka, lozko, meblosciana, szafa, kuchenka, lodowka, szafka_kuchenna,
              regal_metalowy, skrzynia_wojskowa, biurko, telewizor, worki_piasek, stol_warsztatowy, zarowka,
              krata, apteczka_scienna, dywan, znak_wyjscie, szafka_metalowa):
        f()
    # rekwizyty z próbki też jako meble
    META["skrzynia"] = {"rozmiar": [0.6, 0.6, 0.6], "oslona": "niska", "pojemnik": "skrzynia", "nazwa": "Skrzynia"}
    META["beczka"] = {"rozmiar": [0.58, 0.88, 0.58], "oslona": "niska", "pojemnik": None, "nazwa": "Beczka"}
    META["kaloryfer"] = {"rozmiar": [0.75, 0.6, 0.13], "oslona": None, "pojemnik": None, "nazwa": "Kaloryfer"}
    META["skrzynki_pocztowe"] = {"rozmiar": [1.0, 0.62, 0.2], "oslona": None, "pojemnik": None, "nazwa": "Skrzynki pocztowe"}
    META["hydrant"] = {"rozmiar": [0.56, 0.56, 0.14], "oslona": None, "pojemnik": None, "nazwa": "Hydrant"}
    META["tablica_ogloszen"] = {"rozmiar": [0.84, 0.62, 0.03], "oslona": None, "pojemnik": None, "nazwa": "Tablica ogłoszeń"}
    (ROOT / "assets" / "dane" / "meble.json").write_text(json.dumps(META, ensure_ascii=False, indent=1), encoding="utf-8")
    print("meble:", len(META))
