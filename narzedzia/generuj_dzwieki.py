"""Syntezator efektów dźwiękowych Strefy K-12 (numpy + scipy), bez nagrań zewnętrznych.

Uruchomienie:  python3 narzedzia/generuj_dzwieki.py
Wynik:         assets/audio/*.wav (22 050 Hz, mono, 16 bit)
"""
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
R = np.random.default_rng(12)


def t(dl):
    return np.arange(int(SR * dl)) / SR


def szum(dl):
    return R.uniform(-1, 1, int(SR * dl))


def lp(x, f, rz=2):
    b, a = signal.butter(rz, f / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, f, rz=2):
    b, a = signal.butter(rz, f / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, f0, f1, rz=2):
    b, a = signal.butter(rz, [f0 / (SR / 2), f1 / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def env(n, atak=0.002, zanik=0.2):
    tt = np.arange(n) / SR
    e = np.exp(-tt / zanik)
    a = int(atak * SR)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def poglos(x, dl=0.6, mix=0.25, ciemny=2500):
    """Prosty pogłos: splot z zanikającym szumem (jak beton klatki schodowej)."""
    ir = szum(dl) * np.exp(-np.arange(int(SR * dl)) / SR / (dl / 4))
    ir = lp(ir, ciemny)
    w = signal.fftconvolve(x, ir)[: len(x) + len(ir) - 1]
    w = w / (np.max(np.abs(w)) + 1e-9) * np.max(np.abs(x))
    out = np.zeros(len(w))
    out[: len(x)] += x
    out += w * mix
    return out


def zapisz(nazwa, x, glosnosc=0.9):
    x = np.asarray(x, dtype=float)
    m = np.max(np.abs(x)) + 1e-9
    x = x / m * glosnosc
    # krótkie wyciszenie końca (bez trzasków)
    f = min(len(x), int(0.01 * SR))
    x[-f:] *= np.linspace(1, 0, f)
    wavfile.write(OUT / f"{nazwa}.wav", SR, (x * 32767).astype(np.int16))
    print(f"{nazwa}.wav  {len(x) / SR:.2f} s")


def strzal(dl, ton, ostrosc, bas, pog=0.8):
    n = int(SR * dl)
    tt = t(dl)
    trzask = hp(szum(dl), ostrosc) * env(n, 0.0005, 0.02)
    cialo = lp(szum(dl), 2200) * env(n, 0.001, dl * 0.18)
    thump = np.sin(2 * np.pi * ton * tt * (1 - tt * 0.6)) * env(n, 0.001, 0.07) * bas
    x = trzask * 1.0 + cialo * 0.9 + thump
    x = np.tanh(x * 2.2)
    return poglos(x, pog, 0.35)


def klik(f=3200, dl=0.05, glosnosc=1.0):
    n = int(SR * dl)
    tt = t(dl)
    x = (np.sin(2 * np.pi * f * tt) + 0.6 * np.sin(2 * np.pi * f * 1.73 * tt)) * env(n, 0.0002, 0.008)
    x += hp(szum(dl), 2000) * env(n, 0.0001, 0.004)
    return x * glosnosc


def sekwencja(dl, zdarzenia):
    out = np.zeros(int(SR * dl))
    for czas, x in zdarzenia:
        i = int(czas * SR)
        k = min(len(x), len(out) - i)
        out[i:i + k] += x[:k]
    return out


def krok(dl=0.12, jasnosc=900):
    n = int(SR * dl)
    x = lp(szum(dl), jasnosc) * env(n, 0.003, 0.03)
    x += np.sin(2 * np.pi * 70 * t(dl)) * env(n, 0.002, 0.025) * 0.8
    x += hp(szum(dl), 3000) * env(n, 0.001, 0.01) * 0.15  # piasek, gruz
    return x


def main():
    zapisz("strzal_pistolet", strzal(0.9, 120, 3500, 0.7, 0.9))
    zapisz("strzal_karabin", strzal(1.3, 85, 2500, 1.2, 1.2))
    zapisz("strzal_strzelba", strzal(1.4, 65, 1800, 1.5, 1.3))
    zapisz("sucho", klik(2600, 0.06), 0.6)
    zapisz("klik", klik(3000, 0.04), 0.5)
    zapisz("przeladowanie", sekwencja(1.4, [(0.0, klik(1800, 0.08)), (0.05, krok(0.06, 2500) * 0.5), (0.55, klik(2300, 0.07)),
                                            (0.62, klik(1600, 0.09)), (1.05, klik(2800, 0.06)), (1.12, klik(2000, 0.08))]), 0.7)
    zapisz("napelnianie", sekwencja(1.0, [(i * 0.32, klik(3400 + R.uniform(-200, 200), 0.03)) for i in range(3)]), 0.5)
    zapisz("krok", krok(0.14, 800), 0.6)
    zapisz("krok_wrog", krok(0.14, 650), 0.6)
    n = int(SR * 0.4)
    zapisz("trafienie_beton", poglos(hp(szum(0.4), 1500) * env(n, 0.0003, 0.02) + lp(szum(0.4), 900) * env(n, 0.002, 0.06) * 0.6, 0.4, 0.2), 0.7)
    zapisz("trafienie_cialo", lp(szum(0.3), 700) * env(int(SR * 0.3), 0.001, 0.05) + np.sin(2 * np.pi * 90 * t(0.3)) * env(int(SR * 0.3), 0.001, 0.04), 0.8)
    tt = t(0.6)
    ping = (np.sin(2 * np.pi * 1850 * tt) + 0.5 * np.sin(2 * np.pi * 2770 * tt) + 0.3 * np.sin(2 * np.pi * 4100 * tt)) * env(len(tt), 0.0005, 0.12)
    zapisz("trafienie_pancerz", ping + hp(szum(0.6), 2500) * env(len(tt), 0.0002, 0.01), 0.7)
    dl = 0.35
    tt = t(dl)
    sw = bp(szum(dl), 1800, 5000) * np.sin(np.pi * tt / dl) ** 2
    zapisz("swist", sw, 0.5)
    rus = bp(szum(1.0), 600, 4000) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t(1.0))) * env(int(SR * 1.0), 0.05, 0.6)
    zapisz("leczenie", rus, 0.5)
    zapisz("podnies", bp(szum(0.25), 400, 3000) * env(int(SR * 0.25), 0.01, 0.06), 0.45)
    zapisz("odloz", lp(szum(0.15), 1200) * env(int(SR * 0.15), 0.002, 0.03), 0.45)
    zapisz("zaloz", bp(szum(0.4), 300, 2000) * env(int(SR * 0.4), 0.02, 0.12), 0.5)
    zapisz("plecak", bp(szum(0.5), 250, 2500) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t(0.5))) * env(int(SR * 0.5), 0.02, 0.15), 0.45)
    zapisz("szukanie", bp(szum(0.3), 500, 3500) * env(int(SR * 0.3), 0.01, 0.08), 0.35)
    # drzwi metalowe: skrzypienie + trzask
    tt = t(1.4)
    f = 300 + 120 * np.sin(2 * np.pi * 1.3 * tt) + 40 * np.sin(2 * np.pi * 7 * tt)
    skrz = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.1, 0.5) * 0.3
    skrz = bp(skrz, 400, 2500)
    trzask = np.zeros(len(tt))
    i = int(1.05 * SR)
    trzask[i:] = (lp(szum(1.4 - 1.05), 900) * env(len(tt) - i, 0.001, 0.12))[: len(tt) - i]
    zapisz("drzwi", poglos(skrz + trzask * 1.5, 0.8, 0.3), 0.8)
    tt = t(0.9)
    dzw = (np.sin(2 * np.pi * 2100 * tt) + 0.6 * np.sin(2 * np.pi * 3150 * tt)) * env(len(tt), 0.001, 0.25)
    zapisz("kasa", sekwencja(0.9, [(0.0, klik(1500, 0.05)), (0.08, klik(1200, 0.06)), (0.15, dzw)]), 0.6)
    zapisz("pieczatka", poglos(lp(szum(0.3), 500) * env(int(SR * 0.3), 0.001, 0.05) + np.sin(2 * np.pi * 80 * t(0.3)) * env(int(SR * 0.3), 0.001, 0.05), 0.3, 0.2), 0.8)
    # start rajdu: szum radia i sygnał
    st = bp(szum(1.6), 800, 3500) * env(int(SR * 1.6), 0.05, 0.8) * 0.5
    beep = np.sin(2 * np.pi * 1000 * t(0.15)) * 0.6
    zapisz("start_rajdu", sekwencja(1.6, [(0.0, st), (0.9, beep), (1.15, beep)]), 0.5)
    # ambient rajdu: niski szum wentylacji, buczenie i odległe trzaski (pętla 24 s)
    dl = 24.0
    tt = t(dl)
    hum = (np.sin(2 * np.pi * 50 * tt) * 0.25 + np.sin(2 * np.pi * 100 * tt) * 0.12) * (0.7 + 0.3 * np.sin(2 * np.pi * tt / dl * 3))
    wiatr = lp(szum(dl), 300) * (0.6 + 0.4 * np.sin(2 * np.pi * tt / dl * 2 + 1.0)) * 1.5
    amb = hum + wiatr
    for _ in range(7):
        c = R.uniform(1, dl - 2)
        x = poglos(lp(szum(0.3), 1200) * env(int(SR * 0.3), 0.01, 0.08), 1.5, 0.6, 1200) * R.uniform(0.2, 0.5)
        i = int(c * SR)
        amb[i:i + len(x)] += x[: len(amb) - i]
    # płynna pętla
    f = int(SR * 0.5)
    amb[:f] = amb[:f] * np.linspace(0, 1, f) + amb[-f:] * np.linspace(1, 0, f)
    zapisz("ambient_rajd", amb[:-f], 0.35)
    dl = 16.0
    tt = t(dl)
    baza = np.sin(2 * np.pi * 50 * tt) * 0.2 + lp(szum(dl), 200) * 0.8 + np.sin(2 * np.pi * 120 * tt) * 0.05
    f = int(SR * 0.5)
    baza[:f] = baza[:f] * np.linspace(0, 1, f) + baza[-f:] * np.linspace(1, 0, f)
    zapisz("ambient_baza", baza[:-f], 0.25)


if __name__ == "__main__":
    main()
