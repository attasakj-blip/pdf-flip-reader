"""Synthesises 10 page-turn sounds from filtered noise. Fully original, no samples."""
import sys, wave
import numpy as np

SR = 44100
OUT = sys.argv[1]

def bandpass(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.exp(-0.5 * ((np.log(np.maximum(f, 1)) - np.log(np.sqrt(lo * hi))) / (np.log(hi / lo) / 2.5)) ** 2)
    return np.fft.irfft(X * g, len(x))

def env(n, attack, peak, decay_pow=1.5):
    t = np.linspace(0, 1, n)
    a = np.clip(t / attack, 0, 1) ** 0.7
    d = np.clip((1 - t) / (1 - peak), 0, 1) ** decay_pow
    return np.where(t < peak, a, d)

def make(dur, lo, hi, crackle, crack_lo, crack_hi, swish_peak, thump, thump_f, seed, sweep=0.0, flutter=0.0):
    rng = np.random.default_rng(seed)
    n = int(SR * dur)
    t = np.arange(n) / SR
    # Swish: air moving past the page, band-limited noise with a slow envelope.
    swish = bandpass(rng.standard_normal(n), lo, hi)
    if sweep:
        swish = swish * (1 + sweep * np.sin(np.pi * t / dur))
    swish *= env(n, swish_peak * 0.8, swish_peak)
    # Crackle: tiny paper creases as the sheet bends.
    cr = np.zeros(n)
    count = int(crackle * dur)
    for _ in range(count):
        pos = int(rng.beta(2, 2.5) * (n - 2000))
        L = rng.integers(60, 400)
        burst = rng.standard_normal(L) * np.exp(-np.arange(L) / (L / 4))
        cr[pos:pos + L] += burst * rng.uniform(0.3, 1.0)
    cr = bandpass(cr, crack_lo, crack_hi)
    # Flutter: amplitude wobble of a light page in the air.
    if flutter:
        swish *= 1 + 0.5 * np.sin(2 * np.pi * flutter * t)
    # Thump: the page landing on the other side.
    th = np.zeros(n)
    if thump:
        start = int(n * 0.78)
        L = n - start
        tt = np.arange(L) / SR
        th[start:] = np.sin(2 * np.pi * thump_f * tt) * np.exp(-tt * 40) * thump
        th += bandpass(np.concatenate([np.zeros(start), rng.standard_normal(L) * np.exp(-np.arange(L) / (SR * 0.02))]), 300, 3000) * thump * 0.6
    y = swish / (np.abs(swish).max() + 1e-9) * 0.6 + cr / (np.abs(cr).max() + 1e-9) * 0.45 + th
    fade = int(SR * 0.01)
    y[:fade] *= np.linspace(0, 1, fade)
    y[-fade:] *= np.linspace(1, 0, fade)
    return y / (np.abs(y).max() + 1e-9) * 0.85

SOUNDS = [
    # dur  lo    hi    crackle crack_lo crack_hi peak thump f   seed
    (0.55, 900, 7000, 60, 2500, 9000, 0.45, 0.15, 140, 1),            # 1 classic paperback
    (0.40, 1500, 9000, 90, 4000, 12000, 0.40, 0.05, 160, 2, 0, 0),    # 2 thin bible paper
    (0.70, 500, 4000, 25, 1500, 6000, 0.50, 0.45, 110, 3),            # 3 thick hardcover page
    (0.60, 700, 5500, 120, 1800, 7000, 0.40, 0.20, 120, 4, 0.3),      # 4 old crinkly book
    (0.45, 1200, 8000, 40, 3000, 10000, 0.35, 0.25, 150, 5),          # 5 glossy magazine
    (0.30, 1000, 7500, 30, 3000, 9000, 0.30, 0.10, 150, 6),           # 6 quick flick
    (0.95, 600, 5000, 45, 2000, 8000, 0.55, 0.20, 120, 7, 0.4),       # 7 slow gentle turn
    (0.55, 800, 6000, 70, 2200, 8500, 0.45, 0.10, 130, 8, 0, 9),      # 8 airy flutter
    (0.50, 400, 3000, 20, 1200, 5000, 0.45, 0.55, 90, 9),             # 9 cardboard / board book
    (0.65, 1800, 11000, 150, 5000, 14000, 0.40, 0.05, 170, 10, 0.2),  # 10 notebook / tracing paper
]

for i, s in enumerate(SOUNDS, 1):
    y = make(*s)
    pcm = (y * 32767).astype('<i2')
    with wave.open(f'{OUT}/flip_{i:02d}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(i, len(y) / SR)
