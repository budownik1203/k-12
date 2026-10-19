"""Dźwięki drzwi: otwarcie (klamka + zawiasy), powolne skrzypienie (uchylanie), zamknięcie (zatrzask),
kopniak w drewniane i metalowe drzwi, wyważenie (trzask futryny), trafienie kuli w drewno, wytrych w zamku drzwi.

Uruchomienie:  python3 narzedzia/generuj_dzwieki_drzwi.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402
from generuj_dzwieki import SR, t, szum, lp, hp, bp, env, poglos, zapisz, klik, sekwencja  # noqa: E402
from generuj_dzwieki_lup import skrzyp, stuk  # noqa: E402


def n(dl):
    return int(SR * dl)


def klamka():
    return sekwencja(0.25, [(0.0, klik(2400, 0.04, 0.8)), (0.08, klik(1700, 0.05, 0.9)), (0.09, lp(szum(0.08), 1500) * env(n(0.08), 0.001, 0.02) * 0.5)])


def drzwi_otworz():
    return poglos(sekwencja(1.1, [(0.0, klamka()), (0.18, skrzyp(0.6, 520, 380, 0.45)), (0.2, lp(szum(0.7), 400) * env(n(0.7), 0.05, 0.3) * 0.3)]), 0.5, 0.2)


def drzwi_skrzyp():
    # długie, przerywane skrzypienie przy powolnym uchylaniu
    x = sekwencja(1.6, [(0.0, skrzyp(0.5, 700, 560, 0.5)), (0.55, skrzyp(0.45, 610, 480, 0.4)), (1.05, skrzyp(0.5, 520, 420, 0.35))])
    return poglos(x, 0.5, 0.18)


def drzwi_zamknij():
    uderz = stuk(0.4, 85, 900, 0.07) * 1.2
    return poglos(sekwencja(0.7, [(0.0, uderz), (0.01, klik(2000, 0.05, 1.0)), (0.03, klik(1400, 0.06, 0.7))]), 0.6, 0.3)


def drzwi_kopniak():
    x = stuk(0.5, 70, 1200, 0.09) * 1.4
    # grzechot klamki i zawiasów
    for k in range(5):
        x = sekwencja(0.7, [(0.0, x), (0.05 + k * 0.04, klik(2600 - k * 250, 0.03, 0.5 - k * 0.07))])
    return poglos(x, 0.9, 0.35)


def drzwi_metal_kopniak():
    tt = t(1.4)
    dzwon = (np.sin(2 * np.pi * 110 * tt) + 0.6 * np.sin(2 * np.pi * 263 * tt) + 0.3 * np.sin(2 * np.pi * 517 * tt)) * env(n(1.4), 0.001, 0.35)
    return poglos(dzwon * 0.6 + stuk(1.4, 60, 800, 0.08), 1.2, 0.4)


def drzwi_wywaz():
    trzask = hp(szum(0.25), 800) * env(n(0.25), 0.001, 0.05) * 1.2
    drzazgi = sum_drzazgi(0.6)
    uderz = stuk(0.6, 60, 1000, 0.12) * 1.5
    return poglos(sekwencja(1.4, [(0.0, uderz), (0.0, trzask), (0.03, drzazgi), (0.45, stuk(0.4, 90, 1500, 0.06))]), 1.0, 0.4)


def sum_drzazgi(dl):
    rr = np.random.default_rng(5)
    x = np.zeros(n(dl))
    for k in range(14):
        o = rr.uniform(0, dl - 0.05)
        s = bp(szum(0.04), 1500, 6000) * env(n(0.04), 0.0005, 0.008) * rr.uniform(0.2, 0.7)
        i = int(o * SR)
        x[i:i + len(s)] += s
    return x


def trafienie_drewno():
    return sekwencja(0.4, [(0.0, stuk(0.3, 160, 2500, 0.03) * 0.9), (0.005, sum_drzazgi(0.2) * 0.9)])


if __name__ == "__main__":
    zapisz("drzwi_otworz", drzwi_otworz(), 0.6)
    zapisz("drzwi_skrzyp", drzwi_skrzyp(), 0.5)
    zapisz("drzwi_zamknij", drzwi_zamknij(), 0.75)
    zapisz("drzwi_kopniak", drzwi_kopniak(), 0.9)
    zapisz("drzwi_metal_kopniak", drzwi_metal_kopniak(), 0.85)
    zapisz("drzwi_wywaz", drzwi_wywaz(), 0.95)
    zapisz("trafienie_drewno", trafienie_drewno(), 0.7)


# ------------------------------------------------------------------ granat (dopisane)
def wybuch():
    dl = 3.5
    tt = t(dl)
    uderz = lp(szum(dl), 900) * env(n(dl), 0.001, 0.25) * 2.0
    bas = np.sin(2 * np.pi * (45 + 60 * np.exp(-tt / 0.08)) * tt) * env(n(dl), 0.001, 0.5) * 1.6
    trzask = hp(szum(dl), 2500) * env(n(dl), 0.0005, 0.04) * 0.9
    gruz = sum_drzazgi(1.5) * 0.5
    x = uderz + bas + trzask
    x = sekwencja(dl, [(0.0, x), (0.25, gruz)])
    return poglos(x, 2.5, 0.5, 1500)


def zawleczka():
    return sekwencja(0.4, [(0.0, klik(3500, 0.03, 0.7)), (0.05, bp(szum(0.08), 2000, 7000) * env(n(0.08), 0.002, 0.03) * 0.5), (0.18, klik(2600, 0.04, 0.6))])


def granat_odbicie():
    tt = t(0.25)
    return (np.sin(2 * np.pi * 1900 * tt) + 0.5 * np.sin(2 * np.pi * 3100 * tt)) * env(n(0.25), 0.0005, 0.03) + lp(szum(0.25), 1200) * env(n(0.25), 0.001, 0.02)


if __name__ == "__main__":
    zapisz("wybuch", wybuch(), 0.98)
    zapisz("zawleczka", zawleczka(), 0.6)
    zapisz("granat_odbicie", granat_odbicie(), 0.5)


# ------------------------------------------------------------------ zdarzenia strefy (dopisane)
def samolot():
    dl = 14.0
    tt = t(dl)
    # przelot: narasta, dopplerowe obniżenie tonu, oddala się
    obw = np.exp(-((tt - 6.5) / 3.2) ** 2)
    f = 92 * (1 + 0.08 * np.tanh((6.5 - tt) / 1.2))
    faza = np.cumsum(f) / SR
    silnik = (np.sin(2 * np.pi * faza) + 0.5 * np.sin(2 * np.pi * faza * 2) + 0.3 * np.sin(2 * np.pi * faza * 3.02)) * 0.4
    silnik += lp(szum(dl), 500) * 0.7
    x = silnik * obw
    return poglos(lp(x, 1800), 2.0, 0.4, 1200)


def prad():
    tt = t(1.2)
    bzz = np.sin(2 * np.pi * 100 * tt) * np.exp(-tt / 0.35) * 0.6
    return sekwencja(1.2, [(0.0, klik(900, 0.08, 1.0)), (0.0, bzz), (0.05, lp(szum(0.3), 600) * env(n(0.3), 0.001, 0.08) * 0.5)])


if __name__ == "__main__":
    zapisz("samolot", samolot(), 0.7)
    zapisz("prad", prad(), 0.7)
