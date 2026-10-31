"""Synthesises the three page-turn sounds. Fully original, no samples.

Testers found the earlier ten sounds too alike, too hissy and too loud. A
real page turn is not smooth noise: it is paper rubbing on paper, which is
thousands of tiny, uneven ticks, plus a puff of air as the sheet swings and
a soft pat when it lands. So each sound here is built from
  - grains: random micro-impulses whose rate follows the movement, each
    ringing briefly at a paper-like resonance (1-4 kHz);
  - air: a gentle low-passed whoosh, loudest mid-turn;
  - landing: a short, dull pat (and for a thick page a faint thump);
then a touch of small-room reflection, a soft top end and a quiet level.

Usage: python3 tools/gen_sounds.py assets/sounds
"""
import sys
import wave

import numpy as np

SR = 44100


def lowpass(x, f):
    X = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / np.sqrt(1 + (fr / f) ** 4), len(x))


def highpass(x, f):
    X = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / np.sqrt(1 + (f / np.maximum(fr, 1)) ** 4), len(x))


def bump(t, at, width):
    """Smooth hump centred at [at] (0..1 of the sound)."""
    return np.exp(-0.5 * ((t - at) / width) ** 2)


def make(dur, seed, grain_rate, grain_gain, air_gain, air_cut, land_at, land_gain, thump_gain, lift_gain, level):
    rng = np.random.default_rng(seed)
    n = int(SR * dur)
    t = np.linspace(0, 1, n)

    # How fast the paper is moving: picks up, peaks a little before the
    # middle, eases off before landing.
    motion = bump(t, 0.38, 0.2) + 0.35 * bump(t, 0.7, 0.12)
    motion /= motion.max()

    # Grains: Poisson ticks, rate following the motion, amplitudes uneven
    # (a few louder creases among many faint ones).
    grains = np.zeros(n)
    prob = grain_rate * motion / SR
    hits = np.nonzero(rng.random(n) < prob)[0]
    for h in hits:
        L = int(rng.uniform(0.0006, 0.0025) * SR)
        if h + L >= n:
            continue
        f0 = rng.uniform(1100, 4200)
        tt = np.arange(L) / SR
        ring = np.sin(2 * np.pi * f0 * tt + rng.uniform(0, 6.28)) * np.exp(-tt / (L / SR / 3))
        grains[h:h + L] += ring * min(rng.pareto(2.5), 4) * motion[h]
    # The first lift of the page edge: a little cluster of crisper ticks.
    if lift_gain:
        for _ in range(int(rng.integers(5, 10))):
            h = int(rng.uniform(0.02, 0.12) * n)
            L = int(0.002 * SR)
            tt = np.arange(L) / SR
            grains[h:h + L] += (np.sin(2 * np.pi * rng.uniform(1800, 3500) * tt) * np.exp(-tt / 0.0006)
                                * lift_gain * rng.uniform(0.5, 1))
    grains = highpass(grains, 700)

    # Air: the sheet pushing air as it swings over.
    air = lowpass(rng.standard_normal(n), air_cut) * (0.15 + 0.85 * bump(t, 0.5, 0.18))
    air = highpass(air, 150)

    # Landing.
    land = np.zeros(n)
    if land_gain:
        s = int(land_at * n)
        L = n - s
        tt = np.arange(L) / SR
        pat = lowpass(rng.standard_normal(L), 2200) * np.exp(-tt / 0.018)
        land[s:] += pat / (np.abs(pat).max() + 1e-12) * land_gain
        if thump_gain:
            land[s:] += np.sin(2 * np.pi * 115 * tt) * np.exp(-tt / 0.03) * thump_gain

    def norm(x):
        return x / (np.sqrt(np.mean(x ** 2)) + 1e-12)

    y = norm(grains) * grain_gain + norm(air) * air_gain + land * 2.5

    # Small room: a few early reflections, quiet and dull.
    room = np.zeros(n + int(0.06 * SR))
    room[:n] += y
    dull = lowpass(y, 3500)
    for d_ms, g in [(7, 0.18), (13, 0.12), (21, 0.09), (34, 0.06), (49, 0.04)]:
        d = int(d_ms / 1000 * SR)
        room[d:d + n] += dull * g
    y = lowpass(room, 7500)

    # Gentle fade in/out so nothing clicks.
    fi, fo = int(0.012 * SR), int(0.04 * SR)
    y[:fi] *= np.linspace(0, 1, fi) ** 2
    y[-fo:] *= np.linspace(1, 0, fo) ** 2
    return y / (np.abs(y).max() + 1e-12) * level


SOUNDS = [
    # dur  seed rate  grains air  air_cut land_at land thump lift level
    (0.42, 11, 2200, 1.0, 0.55, 1300, 0.80, 0.55, 0.0, 0.5, 0.55),   # 1 soft page (default)
    (0.55, 23, 3000, 1.0, 0.65, 1100, 0.78, 0.8, 0.5, 1.0, 0.62),    # 2 book page
    (0.36, 37, 900, 0.45, 1.0, 1500, 0.0, 0.0, 0.0, 0.0, 0.42),      # 3 whisper-light
]


def main():
    out = sys.argv[1]
    for i, s in enumerate(SOUNDS, 1):
        y = make(*s)
        pcm = (y * 32767).astype('<i2')
        with wave.open(f'{out}/flip_{i:02d}.wav', 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        spec = np.abs(np.fft.rfft(y)) ** 2
        fr = np.fft.rfftfreq(len(y), 1 / SR)
        print(i, f'{len(y) / SR:.2f}s', f'centroid {np.sum(fr * spec) / np.sum(spec):.0f} Hz',
              f'rms {np.sqrt(np.mean(y ** 2)):.3f}')


if __name__ == '__main__':
    main()
