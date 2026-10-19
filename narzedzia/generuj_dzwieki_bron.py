"""Dźwięki choreografii przeładowań: dźwignia obrzyna, wyciąganie plastikowej łuski z komory,
praca zamka przy strzale (blisko ucha).

Uruchomienie:  python3 narzedzia/generuj_dzwieki_bron.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402
from generuj_dzwieki import SR, t, szum, lp, hp, bp, env, zapisz, sekwencja  # noqa: E402
from generuj_dzwieki_3 import metal, n  # noqa: E402


def dzwignia():
    # kciuk przesuwa dźwignię (sprężyna – krótki zgrzyt), zapadka puszcza
    zgrzyt = bp(szum(0.07), 2000, 6000) * np.linspace(0.3, 1.0, n(0.07)) * 0.35
    return sekwencja(0.25, [(0.0, zgrzyt), (0.06, metal(0.07, 2400, 3900, 0.008) * 0.9)])


def luska_wyjmij():
    # plastikowa łuska ślizga się w komorze: głuchy szmer, puste stuknięcie mosiężnej główki
    tt = t(0.3)
    szmer = bp(szum(0.2), 400, 2200) * np.linspace(1.0, 0.3, n(0.2)) * 0.5
    puste = np.sin(2 * np.pi * 520 * t(0.08)) * env(n(0.08), 0.001, 0.02) * 0.5
    return sekwencja(0.3, [(0.0, metal(0.04, 2900, 4600, 0.006) * 0.5), (0.02, szmer), (0.18, puste + lp(szum(0.08), 1500) * env(n(0.08), 0.001, 0.015) * 0.3)])


def mechanizm():
    # zamek chodzi tam i z powrotem przy strzale: dwa szybkie metaliczne trzaski
    return sekwencja(0.12, [(0.0, metal(0.05, 1800, 3100, 0.007)), (0.035, metal(0.05, 1300, 2500, 0.009) * 0.8)])


if __name__ == "__main__":
    zapisz("dzwignia", dzwignia(), 0.55)
    zapisz("luska_wyjmij", luska_wyjmij(), 0.6)
    zapisz("mechanizm", mechanizm(), 0.5)
