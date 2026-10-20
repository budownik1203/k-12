"""Dźwięki pułapki z granatem: pękająca szklanka (trzask i brzęk odłamków) i odskakująca łyżka zapalnika.

Uruchomienie:  python3 narzedzia/generuj_dzwieki_pulapka.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402
from generuj_dzwieki import SR, t, szum, hp, bp, env, zapisz  # noqa: E402

R = np.random.default_rng(1212)


def dzwiek_szkla(dl, f):
    """Krótki szklany „ding”: kilka nieharmonicznych prążków z szybkim zanikiem."""
    tt = t(dl)
    x = np.zeros_like(tt)
    for mn, a in [(1.0, 1.0), (2.76, 0.6), (5.4, 0.35), (8.9, 0.2)]:
        x += np.sin(2 * np.pi * f * mn * tt + R.uniform(0, 6)) * a * np.exp(-tt * R.uniform(18, 40))
    return x


def szklo_pek():
    dl = 0.9
    n = int(SR * dl)
    x = np.zeros(n)
    # trzask: ostry szum wysokich częstotliwości
    tr = hp(szum(0.05), 2500) * env(int(SR * 0.05), 0.0005, 0.02)
    x[:len(tr)] += tr * 1.2
    # odłamki: kilkanaście „dingów” rozrzuconych w czasie, cichnących
    for _ in range(22):
        st = int(R.uniform(0.005, 0.6) * SR)
        d = dzwiek_szkla(0.25, R.uniform(2500, 6500)) * R.uniform(0.15, 0.5) * (1.0 - st / n)
        e = min(len(d), n - st)
        x[st:st + e] += d[:e]
    # chrzęst
    x += bp(szum(dl), 3000, 9000) * np.exp(-t(dl) * 9) * 0.25
    return x / np.max(np.abs(x)) * 0.9


def lyzka():
    """Łyżka zapalnika odskakuje: metaliczne „pink” i klik spłonki."""
    dl = 0.45
    tt = t(dl)
    x = np.sin(2 * np.pi * 3100 * tt) * np.exp(-tt * 22) * 0.6 + np.sin(2 * np.pi * 4700 * tt) * np.exp(-tt * 30) * 0.3
    kl = hp(szum(0.012), 3000) * env(int(SR * 0.012), 0.0003, 0.004)
    st = int(0.07 * SR)
    x[st:st + len(kl)] += kl * 0.9
    return x / np.max(np.abs(x)) * 0.8


if __name__ == "__main__":
    zapisz("szklo_pek", szklo_pek())
    zapisz("lyzka", lyzka())
    print("dźwięki pułapki: szklo_pek, lyzka")
