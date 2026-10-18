"""Dźwięki pełzacza (mutanta chodzącego po ścianach): klekot, wrzask, drapanie. python3 narzedzia/generuj_dzwieki_mutant.py"""
from pathlib import Path
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
R = np.random.default_rng(77)


def t(dl):
    return np.arange(int(SR * dl)) / SR


def szum(dl):
    return R.uniform(-1, 1, int(SR * dl))


def bp(x, f0, f1, rz=2):
    b, a = signal.butter(rz, [f0 / (SR / 2), f1 / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def lp(x, f, rz=2):
    b, a = signal.butter(rz, f / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def env(n, atak=0.002, zanik=0.2):
    tt = np.arange(n) / SR
    e = np.exp(-tt / zanik)
    a = int(atak * SR)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def zapisz(nazwa, x, g=0.9):
    x = np.asarray(x, float)
    x = x / (np.max(np.abs(x)) + 1e-9) * g
    f = int(0.01 * SR)
    x[-f:] *= np.linspace(1, 0, f)
    wavfile.write(OUT / f"{nazwa}.wav", SR, (x * 32767).astype(np.int16))
    print(nazwa)


# klekot: nieregularne kliknięcia żuwaczek z rezonansem
dl = 0.9
x = np.zeros(int(SR * dl))
pos = 0.0
while pos < dl - 0.05:
    n = int(SR * 0.03)
    k = bp(szum(0.03), R.uniform(1800, 2600), R.uniform(3600, 5200)) * env(n, 0.0005, 0.006)
    i = int(pos * SR)
    x[i:i + n] += k * R.uniform(0.5, 1.0)
    pos += R.uniform(0.025, 0.09)
x += bp(szum(dl), 300, 800) * 0.08 * np.sin(np.pi * t(dl) / dl)
zapisz("mutant_klik", x, 0.75)

# wrzask: piłokształtny z narastającą wysokością, chrypa i formanty
dl = 0.75
tt = t(dl)
f0 = 260 + 700 * (tt / dl) ** 0.6 + 40 * np.sin(2 * np.pi * 23 * tt)
w = signal.sawtooth(2 * np.pi * np.cumsum(f0) / SR)
w = bp(w, 600, 3200) + bp(szum(dl), 1500, 4500) * 0.5
w *= env(len(tt), 0.03, 0.45) * (0.7 + 0.3 * np.sin(2 * np.pi * 31 * tt))
zapisz("mutant_wrzask", w, 0.85)

# drapanie po betonie
dl = 0.6
x = np.zeros(int(SR * dl))
for i in range(5):
    n = int(SR * 0.09)
    s = bp(szum(0.09), 900, 3500) * np.hanning(n)
    st = int(R.uniform(0, dl - 0.1) * SR)
    x[st:st + n] += s
zapisz("mutant_drap", lp(x, 3000), 0.5)
