"""Dźwięki lootowania: szuflada, wieko skrzyni, szafka (skrzypnięcie), grzebanie, rzep, zamek błyskawiczny,
upadek metalu i miękkiego przedmiotu, wytrych, łom.

Uruchomienie:  python3 narzedzia/generuj_dzwieki_lup.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402
from generuj_dzwieki import SR, t, szum, lp, hp, bp, env, poglos, zapisz, klik, sekwencja  # noqa: E402

R = np.random.default_rng(77)


def skrzyp(dl, f0, f1, glos=1.0):
    tt = t(dl)
    f = np.linspace(f0, f1, len(tt)) * (1 + 0.04 * np.sin(2 * np.pi * 9 * tt))
    faza = np.cumsum(f) / SR
    # tarcie: impulsy o zmiennym odstępie przepuszczone przez rezonans
    x = signal_saw(faza) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 23 * tt)))
    x = bp(x, 400, 2600)
    e = np.minimum(1, tt / 0.05) * np.minimum(1, (dl - tt) / 0.08)
    return x * e * glos


def signal_saw(faza):
    return 2 * (faza % 1.0) - 1


def stuk(dl=0.25, f=120, jasn=1500, zanik=0.06):
    n = int(SR * dl)
    x = lp(szum(dl), jasn) * env(n, 0.001, zanik)
    x += np.sin(2 * np.pi * f * t(dl)) * env(n, 0.001, zanik * 1.3) * 0.9
    return x


def szuflada():
    dl = 0.55
    tarcie = bp(szum(dl), 300, 1800) * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 14 * t(dl))))
    tarcie *= np.minimum(1, t(dl) / 0.04) * np.exp(-np.maximum(0, t(dl) - 0.32) / 0.05)
    x = sekwencja(dl, [(0.0, tarcie * 0.6), (0.33, stuk(0.2, 160, 2200, 0.04) * 0.9),
                       (0.36, klik(2400, 0.05) * 0.3)])
    return poglos(x, 0.4, 0.2)


def wieko():
    dl = 0.9
    x = sekwencja(dl, [(0.0, skrzyp(0.45, 520, 380, 0.5)), (0.42, stuk(0.35, 90, 900, 0.09))])
    return poglos(x, 0.6, 0.25)


def szukanie():
    dl = 0.45
    x = np.zeros(int(SR * dl))
    for i in range(7):
        st = R.uniform(0, dl - 0.08)
        d = R.uniform(0.03, 0.09)
        s = bp(szum(d), 1200, 6000) * env(int(SR * d), 0.004, d * 0.4)
        k = int(st * SR)
        x[k:k + len(s)] += s * R.uniform(0.4, 1.0)
    # stuknięcie przedmiotów o siebie
    x = sekwencja(dl, [(0.0, x), (R.uniform(0.1, 0.3), klik(1800, 0.04) * 0.25)])
    return x


def zamek():
    dl = 0.5
    tt = t(dl)
    zeby = (np.sin(2 * np.pi * np.cumsum(np.linspace(60, 140, len(tt))) / SR) > 0.7).astype(float)
    x = hp(zeby * szum(dl), 1500) * np.minimum(1, tt / 0.03) * np.minimum(1, (dl - tt) / 0.05)
    return x


def rzep():
    dl = 0.35
    tt = t(dl)
    x = bp(szum(dl), 900, 7000) * (0.5 + 0.5 * (R.uniform(0, 1, len(tt)) > 0.6)) * np.exp(-tt / 0.2)
    return x


def upadek_metal():
    dl = 0.5
    x = sekwencja(dl, [(0.0, stuk(0.3, 220, 3500, 0.03)), (0.0, klik(2900, 0.2) * 0.4), (0.09, stuk(0.2, 260, 3000, 0.02) * 0.4)])
    return poglos(x, 0.5, 0.25)


def upadek_miekki():
    dl = 0.35
    n = int(SR * dl)
    x = lp(szum(dl), 600) * env(n, 0.004, 0.05) + np.sin(2 * np.pi * 60 * t(dl)) * env(n, 0.003, 0.05) * 0.7
    x += bp(szum(dl), 1500, 5000) * env(n, 0.01, 0.06) * 0.25
    return x


def wytrych():
    dl = 0.6
    zd = []
    for i in range(6):
        zd.append((0.05 + i * 0.09 + R.uniform(-0.02, 0.02), klik(R.uniform(3200, 5200), 0.03) * R.uniform(0.3, 0.8)))
    zd.append((0.02, bp(szum(0.55), 3000, 8000) * 0.05))
    return sekwencja(dl, zd)


def lom():
    dl = 1.1
    x = sekwencja(dl, [(0.0, skrzyp(0.5, 300, 700, 0.6)), (0.48, stuk(0.4, 140, 4500, 0.05) * 1.2),
                       (0.5, klik(1900, 0.3) * 0.6), (0.62, stuk(0.3, 300, 3000, 0.04) * 0.5)])
    return poglos(x, 0.7, 0.3)


if __name__ == "__main__":
    zapisz("szuflada", szuflada(), 0.8)
    zapisz("wieko", wieko(), 0.85)
    zapisz("szukanie", szukanie(), 0.6)
    zapisz("zamek", zamek(), 0.6)
    zapisz("rzep", rzep(), 0.6)
    zapisz("upadek_metal", upadek_metal(), 0.85)
    zapisz("upadek_miekki", upadek_miekki(), 0.7)
    zapisz("wytrych", wytrych(), 0.6)
    zapisz("lom", lom(), 0.95)
