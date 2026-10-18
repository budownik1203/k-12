"""Dźwięki etapu 3: kroki wg podłoża (po 4 warianty), mechanizmy broni, łuski, głosy NPC (syntezowane
mruknięcia i krzyki), oddech, serce, szelest ubrania, tło strefy (brzęczenie świetlówki, kapanie,
odległe strzały, wycie, skrzypienie budynku, wiatr), dron napięcia.

Uruchomienie:  python3 narzedzia/generuj_dzwieki_3.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402
from scipy import signal  # noqa: E402
from generuj_dzwieki import SR, t, szum, lp, hp, bp, env, poglos, zapisz, klik, sekwencja  # noqa: E402

R = np.random.default_rng(303)


def n(dl):
    return int(SR * dl)


# ------------------------------------------------------------------ kroki
def krok(podl, i):
    dl = 0.22
    tt = t(dl)
    rr = np.random.default_rng(1000 + i * 17 + hash(podl) % 1000)
    pieta = lp(szum(dl), 600 + rr.uniform(-80, 80)) * env(n(dl), 0.002, 0.025)
    pieta += np.sin(2 * np.pi * rr.uniform(55, 80) * tt) * env(n(dl), 0.001, 0.03) * 0.8
    if podl == "lastryko":
        x = pieta + hp(szum(dl), 2500) * env(n(dl), 0.0008, 0.012) * 0.5      # twarde, klik podeszwy
        x = sekwencja(dl, [(0.0, x), (0.06 + rr.uniform(0, 0.02), hp(szum(0.05), 3000) * env(n(0.05), 0.001, 0.01) * 0.25)])
    elif podl == "parkiet":
        x = pieta * 1.1 + bp(szum(dl), 300, 1200) * env(n(dl), 0.002, 0.04) * 0.6
        # skrzypnięcie deski czasem
        if i % 2 == 0:
            f = np.linspace(rr.uniform(500, 700), rr.uniform(350, 450), n(0.12))
            sk = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * np.hanning(n(0.12)) * 0.12
            x = sekwencja(dl, [(0.0, x), (0.04, bp(sk, 300, 2000))])
    elif podl == "kafelki":
        x = pieta * 0.8 + hp(szum(dl), 3500) * env(n(dl), 0.0005, 0.008) * 0.8
    elif podl == "beton":
        x = pieta + bp(szum(dl), 1500, 6000) * env(n(dl), 0.003, 0.05) * 0.45   # piasek, chrzęst
    elif podl == "gruz":
        x = pieta * 0.7
        for k in range(6):
            o = rr.uniform(0, 0.12)
            x = sekwencja(dl, [(0.0, x), (o, hp(szum(0.03), 2000) * env(n(0.03), 0.0005, 0.008) * rr.uniform(0.2, 0.6))])
    elif podl == "dywan":
        x = lp(szum(dl), 350) * env(n(dl), 0.004, 0.04) * 0.8
    else:  # blacha
        x = pieta * 0.6 + (np.sin(2 * np.pi * 420 * tt) + 0.5 * np.sin(2 * np.pi * 1130 * tt)) * env(n(dl), 0.001, 0.08) * 0.35
    return x


# ------------------------------------------------------------------ broń
def metal(dl, f0, f1, zanik, jasn=4000):
    tt = t(dl)
    x = (np.sin(2 * np.pi * f0 * tt) + 0.6 * np.sin(2 * np.pi * f1 * tt)) * env(n(dl), 0.0005, zanik)
    return x + hp(szum(dl), jasn) * env(n(dl), 0.0003, 0.006) * 0.8


def mag_wyjmij():
    return sekwencja(0.45, [(0.0, metal(0.08, 1900, 3300, 0.015)), (0.04, bp(szum(0.25), 800, 4000) * env(n(0.25), 0.01, 0.06) * 0.6)])


def mag_wloz():
    return sekwencja(0.4, [(0.0, bp(szum(0.12), 600, 3000) * env(n(0.12), 0.01, 0.04) * 0.5), (0.1, metal(0.12, 1500, 2600, 0.03) * 1.2),
                           (0.12, lp(szum(0.1), 900) * env(n(0.1), 0.001, 0.02))])


def zamek_kb():
    # rączka do tyłu (zgrzyt), puszczona – trzask do przodu
    tyl = bp(szum(0.12), 1200, 5000) * np.linspace(0.4, 1.0, n(0.12)) * 0.5
    return sekwencja(0.5, [(0.0, tyl), (0.12, metal(0.06, 2200, 3600, 0.01)), (0.24, metal(0.2, 900, 1700, 0.05) * 1.3),
                           (0.25, lp(szum(0.1), 1200) * env(n(0.1), 0.001, 0.02))])


def zamek_pist():
    return sekwencja(0.35, [(0.0, metal(0.05, 2600, 4200, 0.008)), (0.08, metal(0.15, 1300, 2400, 0.03) * 1.1)])


def obrzyn_lam():
    return sekwencja(0.5, [(0.0, metal(0.06, 1700, 2900, 0.01)), (0.05, bp(szum(0.25), 500, 2500) * env(n(0.25), 0.01, 0.08) * 0.4),
                           (0.22, metal(0.2, 700, 1300, 0.05))])


def obrzyn_zamk():
    return sekwencja(0.35, [(0.0, metal(0.2, 800, 1500, 0.04) * 1.3), (0.01, lp(szum(0.08), 1000) * env(n(0.08), 0.001, 0.02))])


def naboj_wloz():
    return sekwencja(0.25, [(0.0, metal(0.06, 3100, 5200, 0.01) * 0.6), (0.05, bp(szum(0.08), 1500, 5000) * env(n(0.08), 0.005, 0.02) * 0.4)])


def przelacznik():
    return metal(0.12, 2800, 4400, 0.012)


def luska(i, srut=False):
    rr = np.random.default_rng(50 + i)
    x = np.zeros(n(0.6))
    o = 0.0
    a = 1.0
    for k in range(3 + i % 2):
        f = rr.uniform(3800, 5600) if not srut else rr.uniform(900, 1500)
        s = metal(0.12, f, f * 1.47, 0.03 if not srut else 0.02, 6000) * a
        x = sekwencja(0.6, [(0.0, x), (o, s)])
        o += rr.uniform(0.06, 0.13) * a
        a *= 0.55
    return x


# ------------------------------------------------------------------ głosy (syntezowane, bez słów)
def glos(dl, f0, ksztalt, formanty, szept=0.0, chrypa=0.3):
    tt = t(dl)
    f = f0 * ksztalt(tt / dl) * (1 + 0.02 * np.sin(2 * np.pi * 5.5 * tt))
    zrodlo = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * (1 - szept) + szum(dl) * (szept + chrypa * 0.3)
    x = np.zeros(len(tt))
    for fc, bw, a in formanty:
        x += bp(zrodlo, max(80, fc - bw), fc + bw) * a
    e = np.minimum(1, tt / 0.04) * np.minimum(1, (dl - tt) / 0.08)
    return x * e


A_ = [(700, 120, 1.0), (1200, 150, 0.6), (2500, 250, 0.25)]
O_ = [(500, 100, 1.0), (850, 120, 0.6), (2500, 250, 0.2)]
E_ = [(450, 100, 1.0), (1900, 200, 0.5), (2600, 250, 0.25)]


def sylaby(lista, przerwy=0.04):
    x = np.zeros(0)
    for s in lista:
        x = np.concatenate([x, s, np.zeros(n(przerwy))])
    return x


# ------------------------------------------------------------------ gracz
def oddech():
    dl = 2.4
    tt = t(dl)
    x = np.zeros(len(tt))
    for k, (st, d) in enumerate([(0.0, 0.55), (0.6, 0.5), (1.2, 0.55), (1.8, 0.5)]):
        s = bp(szum(d), 400 if k % 2 == 0 else 700, 2500 if k % 2 == 0 else 3500) * np.hanning(n(d)) * (0.9 if k % 2 == 0 else 0.6)
        i = int(st * SR)
        x[i:i + len(s)] += s[: len(x) - i]
    return x


def serce():
    x = np.zeros(n(0.5))
    for o, a in [(0.0, 1.0), (0.16, 0.7)]:
        s = np.sin(2 * np.pi * 52 * t(0.12)) * env(n(0.12), 0.004, 0.035) * a
        i = int(o * SR)
        x[i:i + len(s)] += s
    return lp(x, 200)


def szelest(i):
    rr = np.random.default_rng(700 + i)
    dl = 0.3
    return bp(szum(dl), 900, 5000) * np.hanning(n(dl)) * (0.5 + 0.5 * (rr.uniform(0, 1, n(dl)) > 0.5)) * 0.5


# ------------------------------------------------------------------ tło strefy
def brzeczenie():
    dl = 4.0
    tt = t(dl)
    x = (np.sin(2 * np.pi * 100 * tt) * 0.5 + np.sin(2 * np.pi * 200 * tt) * 0.25 + np.sin(2 * np.pi * 300 * tt) * 0.1)
    x += bp(szum(dl), 3000, 7000) * 0.05 * (1 + np.sin(2 * np.pi * 0.7 * tt))
    return x


def kapanie(i):
    rr = np.random.default_rng(900 + i)
    f = rr.uniform(900, 1600)
    tt = t(0.4)
    plusk = np.sin(2 * np.pi * (f + 900 * np.exp(-tt / 0.01)) * tt) * env(n(0.4), 0.0005, 0.03)
    return poglos(plusk, 1.2, 0.5, 3000)


def strzaly_daleko(i):
    rr = np.random.default_rng(1200 + i)
    dl = 4.0
    x = np.zeros(n(dl))
    o = 0.2
    for k in range(rr.integers(2, 7)):
        s = lp(szum(0.5), 500) * env(n(0.5), 0.001, 0.12) + np.sin(2 * np.pi * 60 * t(0.5)) * env(n(0.5), 0.001, 0.1)
        i0 = int(o * SR)
        x[i0:i0 + len(s)] += s[: len(x) - i0]
        o += rr.uniform(0.09, 0.6)
    return poglos(x, 2.5, 0.8, 900)


def wycie():
    dl = 3.0
    tt = t(dl)
    f = 380 + 140 * np.sin(np.pi * tt / dl) + 30 * np.sin(2 * np.pi * 6 * tt)
    x = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / dl) ** 2
    return poglos(bp(x, 300, 1800), 2.5, 0.9, 1500)


def skrzyp_budynku():
    dl = 2.2
    tt = t(dl)
    f = 70 + 25 * np.sin(2 * np.pi * 0.6 * tt)
    x = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 3.1 * tt))) * np.sin(np.pi * tt / dl)
    return poglos(lp(x, 700), 2.0, 0.6, 800)


def wiatr():
    dl = 12.0
    tt = t(dl)
    x = bp(szum(dl), 200, 1200) * (0.5 + 0.5 * np.sin(2 * np.pi * tt / dl * 2) ** 2)
    x += bp(szum(dl), 1500, 3000) * 0.15 * (0.5 + 0.5 * np.sin(2 * np.pi * tt / dl * 5 + 1) ** 2)
    f = n(0.5)
    x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f)
    return x[:-f]


def napiecie():
    dl = 16.0
    tt = t(dl)
    x = np.sin(2 * np.pi * 41 * tt) * 0.5 + np.sin(2 * np.pi * 61.5 * tt) * 0.3 * (0.5 + 0.5 * np.sin(2 * np.pi * tt / 8))
    x += bp(szum(dl), 80, 300) * 0.6 + np.sin(2 * np.pi * 123 * tt) * 0.06 * np.sin(2 * np.pi * tt / 4) ** 2
    f = n(0.5)
    x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f)
    return x[:-f]


if __name__ == "__main__":
    for p in ["lastryko", "parkiet", "kafelki", "beton", "gruz", "dywan", "blacha"]:
        for i in range(4):
            zapisz(f"krok_{p}_{i}", krok(p, i), 0.6)
    zapisz("mag_wyjmij", mag_wyjmij(), 0.6)
    zapisz("mag_wloz", mag_wloz(), 0.7)
    zapisz("zamek_kb", zamek_kb(), 0.75)
    zapisz("zamek_pist", zamek_pist(), 0.65)
    zapisz("obrzyn_lam", obrzyn_lam(), 0.65)
    zapisz("obrzyn_zamk", obrzyn_zamk(), 0.7)
    zapisz("naboj_wloz", naboj_wloz(), 0.5)
    zapisz("przelacznik", przelacznik(), 0.5)
    for i in range(3):
        zapisz(f"luska_{i}", luska(i), 0.35)
    zapisz("luska_srut", luska(5, True), 0.4)
    # głosy: krzyk (alarm), komenda, szept, ranny, śmierć – kilka barw
    for i, f0 in enumerate([118, 135, 102]):
        zapisz(f"glos_krzyk_{i}", sylaby([glos(0.22, f0 * 1.6, lambda x: 1 + 0.2 * x, A_), glos(0.32, f0 * 1.8, lambda x: 1.1 - 0.25 * x, O_)]), 0.8)
        zapisz(f"glos_komenda_{i}", sylaby([glos(0.14, f0 * 1.2, lambda x: 1.0 + 0.0 * x, E_), glos(0.2, f0 * 1.15, lambda x: 1 - 0.15 * x, A_), glos(0.12, f0, lambda x: 0.95 + 0 * x, O_)], 0.03), 0.7)
        zapisz(f"glos_ranny_{i}", glos(0.8, f0 * 1.1, lambda x: 1.2 - 0.4 * x, A_, chrypa=0.8), 0.7)
    zapisz("glos_szept", sylaby([glos(0.18, 110, lambda x: 1 + 0 * x, E_, szept=0.95), glos(0.25, 110, lambda x: 1 + 0 * x, A_, szept=0.95)]), 0.4)
    zapisz("glos_smierc", glos(0.9, 120, lambda x: 1.15 - 0.55 * x, O_, chrypa=0.6), 0.7)
    zapisz("oddech", oddech(), 0.45)
    zapisz("serce", serce(), 0.8)
    for i in range(3):
        zapisz(f"szelest_{i}", szelest(i), 0.3)
    zapisz("brzeczenie", brzeczenie(), 0.25)
    for i in range(3):
        zapisz(f"kapanie_{i}", kapanie(i), 0.4)
        zapisz(f"strzaly_daleko_{i}", strzaly_daleko(i), 0.5)
    zapisz("wycie", wycie(), 0.5)
    zapisz("skrzyp_budynku", skrzyp_budynku(), 0.5)
    zapisz("wiatr", wiatr(), 0.35)
    zapisz("napiecie", napiecie(), 0.4)
