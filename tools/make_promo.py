"""Builds the store promo video: English captions over the app's own page
turns, with a soft piano piece made here and the app's flip sound.

1. Render the page-turn frames:
   PAGES_DIR=/home/claude/storekit/pages_en OUT_DIR=/home/claude/promo \
     flutter test tools/promo_frames_test.dart
2. python3 tools/make_promo.py [out.mp4]
"""
import math
import os
import shutil
import subprocess
import sys
import wave

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

F = '/home/claude/fonts/'
PROMO = os.environ.get('PROMO_DIR', '/home/claude/promo')
ICON = '/home/claude/storekit/icon_1024.png'
SOUNDS = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
OUT = sys.argv[1] if len(sys.argv) > 1 else '/mnt/project-files/store-kit/video/pagelume-promo.mp4'
WORK = os.environ.get('WORK_DIR', '/tmp/pagelume-promo')
W, H, FPS = 1920, 1080, 30
BOOK_X, BOOK_Y = 160, 262  # where the 1600x780 book frames sit
FADE = 12  # crossfade frames between scenes

_fonts = {}


def font(name, size):
    key = (name, size)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(F + name, size)
    return _fonts[key]


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def ease(x):
    x = clamp(x)
    return x * x * (3 - 2 * x)


def background():
    top, bottom = np.array([52, 30, 112], float), np.array([14, 10, 40], float)
    y = np.linspace(0, 1, H)[:, None, None]
    img = top * (1 - y) + bottom * y
    # a soft glow behind the book
    yy, xx = np.mgrid[0:H, 0:W]
    glow = np.exp(-(((xx - W / 2) / 900) ** 2 + ((yy - 640) / 420) ** 2))[..., None]
    img = img + glow * np.array([40, 30, 70])
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), 'RGB')


BG = background()

_frames = {}


def book(seq, n):
    key = (seq, n)
    if key not in _frames:
        if len(_frames) > 40:
            _frames.clear()
        _frames[key] = Image.open(f'{PROMO}/{seq}/{n:04d}.png').convert('RGBA')
    return _frames[key]


def count(seq):
    return len([f for f in os.listdir(f'{PROMO}/{seq}') if f.endswith('.png')])


def centered(d, y, text, f, fill):
    d.text(((W - f.getlength(text)) / 2, y), text, font=f, fill=fill)


def caption(img, i, title, sub):
    """Title and subtitle at the top, sliding up as they fade in."""
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    a = ease((i - 4) / 14)
    b = ease((i - 10) / 14)
    centered(d, 70 + 20 * (1 - a), title, font('Kanit-SemiBold.ttf', 76), (255, 255, 255, int(255 * a)))
    centered(d, 172 + 20 * (1 - b), sub, font('NotoSans-Regular.ttf', 38), (208, 198, 250, int(255 * b)))
    img.alpha_composite(layer)


def canvas():
    return BG.convert('RGBA')


def wrap(text, f, maxw):
    lines, line = [], ''
    for word in text.split():
        trial = (line + ' ' + word).strip()
        if f.getlength(trial) > maxw and line:
            lines.append(line)
            line = word
        else:
            line = trial
    return lines + [line]


def rounded_card(img, box, fill, radius=28, shadow=True):
    if shadow:
        sh = Image.new('RGBA', img.size, (0, 0, 0, 0))
        x0, y0, x1, y1 = box
        ImageDraw.Draw(sh).rounded_rectangle((x0, y0 + 14, x1, y1 + 14), radius, fill=(0, 0, 0, 110))
        img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(18)))
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius, fill=fill)
    img.alpha_composite(layer)


# ---------------------------------------------------------------- scenes

class Scene:
    length = 105
    flips = ()  # local frames where a page starts to turn

    def frame(self, i):
        raise NotImplementedError


class Title(Scene):
    def __init__(self, sub, length=96, extra=None):
        self.sub, self.length, self.extra = sub, length, extra
        self.icon = Image.open(ICON).convert('RGBA').resize((300, 300), Image.LANCZOS)

    def frame(self, i):
        img = canvas()
        a = ease(i / 22)
        s = 0.86 + 0.14 * a
        icon = self.icon.resize((int(300 * s), int(300 * s)), Image.LANCZOS)
        icon.putalpha(icon.getchannel('A').point(lambda v: int(v * a)))
        img.alpha_composite(icon, ((W - icon.width) // 2, 250 + (300 - icon.height) // 2))
        layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        b, c, e = ease((i - 12) / 18), ease((i - 24) / 18), ease((i - 36) / 18)
        centered(d, 590 + 16 * (1 - b), 'Pagelume', font('Kanit-Bold.ttf', 110), (255, 255, 255, int(255 * b)))
        centered(d, 745 + 16 * (1 - c), self.sub, font('NotoSans-Regular.ttf', 46), (215, 205, 255, int(255 * c)))
        if self.extra:
            centered(d, 840 + 16 * (1 - e), self.extra, font('Kanit-Regular.ttf', 36), (255, 214, 102, int(255 * e)))
        img.alpha_composite(layer)
        return img


class Flip(Scene):
    """Plays rendered page-turn frames, holding the last one if needed."""

    def __init__(self, seq, title, sub, length=None, turns=()):
        self.seq, self.title, self.sub = seq, title, sub
        self.n = count(seq)
        self.length = length or self.n
        self.flips = turns

    def frame(self, i):
        img = canvas()
        img.alpha_composite(book(self.seq, min(i, self.n - 1)), (BOOK_X, BOOK_Y))
        caption(img, i, self.title, self.sub)
        return img


def spread():
    return book('day', count('day') - 1)


class Markup(Scene):
    """Highlights two lines, circles the sun and signs the page."""

    def __init__(self):
        # a quick cursive flourish written across the sky of the picture
        t = np.linspace(0, 1, 500)
        k = 5.5
        amp = 24 * (0.7 + 0.3 * np.sin(2 * math.pi * 1.7 * t + 0.5))
        xs = 900 + 250 * t - 15 * np.sin(2 * math.pi * k * t)
        ys = 440 - amp * np.cos(2 * math.pi * k * t) - 30 * t
        tail = np.linspace(0, 1, 90)
        xs = np.concatenate([xs, 1150 - 270 * tail + 30 * tail ** 2])
        ys = np.concatenate([ys, 425 + 40 * tail - 25 * tail ** 2])
        self.sig = list(zip(xs + BOOK_X, ys + BOOK_Y))

    def frame(self, i):
        img = canvas()
        img.alpha_composite(spread(), (BOOK_X, BOOK_Y))
        # highlighter: multiply a yellow band over the text
        hl = Image.new('RGB', (W, H), (255, 255, 255))
        d = ImageDraw.Draw(hl)
        for k, (y, x1) in enumerate([(224, 1293), (263, 1276)]):
            p = ease((i - 10 - 14 * k) / 16)
            if p > 0:
                d.rectangle((BOOK_X + 850, BOOK_Y + y - 17, BOOK_X + 850 + (x1 - 850) * p, BOOK_Y + y + 17), fill=(255, 236, 110))
        img = ImageChops.multiply(img.convert('RGB'), hl).convert('RGBA')
        d = ImageDraw.Draw(img)
        # circle round the sun on the left page
        p = ease((i - 42) / 16)
        if p > 0:
            cx, cy, r = BOOK_X + 661, BOOK_Y + 579, 54
            d.arc((cx - r, cy - r, cx + r, cy + r), -100, -100 + 370 * p, fill=(222, 52, 66), width=7)
        # signature
        p = clamp((i - 58) / 30)
        if p > 0:
            pts = self.sig[: max(2, int(len(self.sig) * p))]
            d.line(pts, fill=(28, 58, 160), width=5, joint='curve')
        caption(img, i, 'Sign, draw and highlight', 'Mark up any page, then save it as a new PDF')
        return img


class Translate(Scene):
    TEXT = ('Ella eligió un libro nuevo cada semana. Algunos eran cuentos populares, '
            'otros hablaban de las estrellas y del cielo. Los niños escuchaban sin apartar la vista.')

    def frame(self, i):
        img = canvas()
        img.alpha_composite(spread(), (BOOK_X, BOOK_Y))
        sel = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(sel)
        for k, (y, x1) in enumerate([(347, 738), (385, 734), (424, 700), (463, 366)]):
            p = ease((i - 8 - 5 * k) / 7)
            if p > 0:
                d.rectangle((BOOK_X + 308, BOOK_Y + y - 19, BOOK_X + 308 + (x1 - 308) * p, BOOK_Y + y + 19), fill=(66, 133, 244, 70))
        img.alpha_composite(sel)
        p = ease((i - 34) / 14)
        if p > 0:
            x0, y0 = BOOK_X + 815, BOOK_Y + 330 + int(60 * (1 - p))
            card = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            rounded_card(card, (x0, y0, x0 + 560, y0 + 400), (255, 255, 255, 255))
            d = ImageDraw.Draw(card)
            d.text((x0 + 34, y0 + 26), 'Translation', font=font('Kanit-SemiBold.ttf', 38), fill=(52, 30, 112))
            d.text((x0 + 34, y0 + 78), 'English to Spanish', font=font('NotoSans-Regular.ttf', 26), fill=(120, 110, 150))
            d.line((x0 + 34, y0 + 124, x0 + 526, y0 + 124), fill=(225, 220, 240), width=2)
            shown = self.TEXT[: int(len(self.TEXT) * clamp((i - 46) / 40))]
            f = font('NotoSans-Regular.ttf', 29)
            for k, line in enumerate(wrap(shown, f, 492)):
                d.text((x0 + 34, y0 + 142 + 42 * k), line, font=f, fill=(40, 34, 56))
            card.putalpha(card.getchannel('A').point(lambda v: int(v * p)))
            img.alpha_composite(card)
        caption(img, i, 'Translate on your phone', 'Free and private: translation runs on your device')
        return img


class Sounds(Scene):
    NAMES = ['Ocean waves', 'Light rain', 'Thunderstorm', 'Campfire',
             'Morning birds', 'Crickets at night', 'Babbling brook', 'Rain on the window',
             'Train journey', 'Soft piano', 'Music box', 'Kalimba']

    def frame(self, i):
        img = canvas()
        cw, ch, gap = 380, 116, 30
        x0 = (W - (4 * cw + 3 * gap)) // 2
        active = clamp((i - 30) // 18, 0, 3)
        order = [1, 9, 0, 4]
        for k, name in enumerate(self.NAMES):
            p = ease((i - 6 - 2.5 * k) / 12)
            if p <= 0:
                continue
            col, row = k % 4, k // 4
            x, y = x0 + col * (cw + gap), 340 + row * (ch + gap) + int(30 * (1 - p))
            on = i >= 30 and k == order[int(active)]
            layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            d = ImageDraw.Draw(layer)
            fill = (232, 222, 255, 255) if on else (255, 255, 255, 34)
            d.rounded_rectangle((x, y, x + cw, y + ch), 26, fill=fill,
                                outline=None if on else (255, 255, 255, 60), width=2)
            f = font('Kanit-Regular.ttf', 34)
            d.text((x + 30, y + ch / 2), name, font=f, anchor='lm', fill=(52, 30, 112) if on else (240, 236, 255))
            if on:  # little level meter
                for b in range(4):
                    hgt = 14 + 26 * abs(math.sin(i * 0.35 + b * 1.3))
                    bx = x + cw - 70 + b * 12
                    d.rounded_rectangle((bx, y + ch / 2 - hgt / 2, bx + 7, y + ch / 2 + hgt / 2), 3, fill=(110, 70, 220))
            layer.putalpha(layer.getchannel('A').point(lambda v: int(v * p)))
            img.alpha_composite(layer)
        d = ImageDraw.Draw(img)
        a = ease((i - 40) / 16)
        centered(d, 820, '+ 18 more', font('Kanit-Regular.ttf', 36), (255, 214, 102, int(255 * a)))
        caption(img, i, '30 calm background sounds', 'Rain, ocean, birds, piano and more while you read')
        return img


class Mirror(Scene):
    """The phone's book shown again on a big screen."""

    def __init__(self):
        self.start = 49  # day frames: hold on 3-4, then turn to 5-6
        self.flips = (67 - self.start,)
        self.length = 108

    def frame(self, i):
        img = canvas()
        n = min(self.start + i, count('day') - 1)
        f = book('day', n)
        # big screen
        sx, sy, sw, sh = 760, 300, 1020, 560
        rounded_card(img, (sx - 14, sy - 14, sx + sw + 14, sy + sh + 14), (20, 16, 34, 255), radius=18)
        ImageDraw.Draw(img).rectangle((sx, sy, sx + sw, sy + sh), fill=(250, 248, 242))
        big = f.resize((sw, int(sw * 780 / 1600)), Image.LANCZOS)
        img.alpha_composite(big, (sx, sy + (sh - big.height) // 2))
        # stand
        d = ImageDraw.Draw(img)
        d.rectangle((sx + sw / 2 - 8, sy + sh + 14, sx + sw / 2 + 8, sy + sh + 70), fill=(20, 16, 34))
        d.rounded_rectangle((sx + sw / 2 - 120, sy + sh + 66, sx + sw / 2 + 120, sy + sh + 80), 6, fill=(20, 16, 34))
        # phone, landscape
        px, py, pw, ph = 150, 560, 470, 236
        rounded_card(img, (px, py, px + pw, py + ph), (24, 20, 38, 255), radius=34)
        scr = (px + 22, py + 16, px + pw - 22, py + ph - 16)
        ImageDraw.Draw(img).rectangle(scr, fill=(250, 248, 242))
        small = f.resize((scr[2] - scr[0], int((scr[2] - scr[0]) * 780 / 1600)), Image.LANCZOS)
        img.alpha_composite(small, (scr[0], scr[1] + (scr[3] - scr[1] - small.height) // 2))
        # beam between them
        a = ease((i - 6) / 16)
        beam = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(beam).polygon(
            [(px + pw + 6, py + 70), (sx - 20, sy + 40), (sx - 20, sy + sh - 40), (px + pw + 6, py + ph - 70)],
            fill=(255, 236, 170, int(60 * a)))
        img.alpha_composite(beam.filter(ImageFilter.GaussianBlur(10)))
        d = ImageDraw.Draw(img)
        d.text((px + pw / 2, py + ph + 40), 'Phone', font=font('Kanit-Regular.ttf', 32), anchor='mm', fill=(215, 205, 255))
        caption(img, i, 'Read together on a big screen', 'Mirror to a projector, TV or AI glasses')
        return img


def scenes():
    day_turns = (15, 15 + 34 + 18)
    return [
        Title('Read PDFs like a real book'),
        Flip('day', 'Turn pages like a real book', 'Pages curl under your finger, just like paper', turns=day_turns),
        Markup(),
        Translate(),
        Flip('night', 'Night mode for bedtime reading', 'Soft, dark pages that are easy on the eyes', length=100, turns=(25,)),
        Sounds(),
        Mirror(),
        Title('Read PDFs like a real book', length=120, extra='Free on Google Play'),
    ]


# ---------------------------------------------------------------- music

SR = 44100


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def piano(freq, dur, vel):
    n = int((dur + 2.5) * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for h in range(1, 9):
        fh = h * freq * math.sqrt(1 + 0.0004 * h * h)
        if fh > SR / 2.2:
            break
        decay = 0.9 + 0.55 * h + freq / 900
        out += np.sin(2 * math.pi * fh * t + h) * np.exp(-t * decay) / h ** 1.4
    out *= 1 - np.exp(-t / 0.004)
    rel = np.clip((t - dur) / 0.35, 0, 1)  # damper after the note's length
    out *= np.where(t > dur, np.exp(-rel * 6), 1)
    return out * vel


def music(seconds):
    beat = 60 / 76
    bar = 4 * beat
    # C, Am, F, G: (bass root, chord tones for the arpeggio)
    chords = [(48, [55, 60, 64, 67]), (45, [52, 57, 60, 64]), (41, [48, 53, 57, 60]), (43, [50, 55, 59, 62])]
    # melody per 4-bar phrase: (beat offset, midi, beats)
    phrases = [
        [(0, 76, 2), (2, 74, 1), (3, 72, 1), (4, 72, 3), (7, 71, 1), (8, 69, 2), (10, 72, 2), (12, 74, 3), (15, 67, 1)],
        [(0, 76, 1.5), (1.5, 79, 0.5), (2, 76, 2), (4, 76, 2), (6, 72, 2), (8, 77, 2), (10, 76, 1), (11, 74, 1), (12, 71, 2), (14, 74, 2)],
    ]
    L = np.zeros(int((seconds + 4) * SR))
    R = np.zeros_like(L)
    rng = np.random.default_rng(7)

    def add(buf, start, sig):
        i = int(start * SR)
        if i >= len(buf):
            return
        j = min(len(buf), i + len(sig))
        buf[i:j] += sig[: j - i]

    bars = int(seconds // bar)
    for b in range(bars):
        last = b == bars - 1
        root, tones = chords[0] if last else chords[b % 4]
        t0 = b * bar
        s = piano(midi(root), bar * (2 if last else 1), 0.32)
        add(L, t0, s * 0.8)
        add(R, t0, s * 0.5)
        if last:
            for k, n in enumerate(tones + [72]):
                s = piano(midi(n), bar * 2, 0.16)
                add(L, t0 + 0.06 * k, s * 0.6)
                add(R, t0 + 0.06 * k, s * 0.8)
            continue
        pattern = [0, 1, 2, 3, 2, 1, 2, 3]
        for k, p in enumerate(pattern):
            s = piano(midi(tones[p]), beat * 0.9, 0.12 + 0.02 * rng.random())
            add(L, t0 + k * beat / 2 + 0.006 * rng.random(), s * 0.7)
            add(R, t0 + k * beat / 2, s * 0.55)
    phrase_len = 4 * bar
    for ph in range(int(math.ceil(bars / 4))):
        for off, n, dur in phrases[ph % 2]:
            start = ph * phrase_len + off * beat
            if start >= (bars - 1) * bar:
                break
            s = piano(midi(n), dur * beat, 0.2 + 0.03 * rng.random())
            add(L, start, s * 0.5)
            add(R, start, s * 0.8)
    # reverb: decaying noise impulse, a different one per side
    for buf in (L, R):
        ir_t = np.arange(int(2.2 * SR)) / SR
        ir = rng.standard_normal(len(ir_t)) * np.exp(-ir_t * 3.2)
        ir[: int(0.012 * SR)] = 0
        n = len(buf) + len(ir)
        size = 1 << (n - 1).bit_length()
        wet = np.fft.irfft(np.fft.rfft(buf, size) * np.fft.rfft(ir, size), size)[: len(buf)]
        buf += wet / np.max(np.abs(wet) + 1e-9) * np.max(np.abs(buf)) * 0.32
    st = np.stack([L, R], 1)[: int(seconds * SR)]
    t = np.arange(len(st)) / SR
    env = np.clip(t / 1.0, 0, 1) * np.clip((seconds - t) / 2.5, 0, 1)
    st *= env[:, None]
    return st / np.max(np.abs(st)) * 0.5


def read_wav(path):
    with wave.open(path) as w:
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float) / 32768
        if w.getnchannels() == 2:
            data = data.reshape(-1, 2).mean(1)
        rate = w.getframerate()
    if rate != SR:
        x = np.arange(0, len(data), rate / SR)
        data = np.interp(x, np.arange(len(data)), data)
    return data


def soundtrack(seconds, flip_times):
    st = music(seconds)
    flip = read_wav(os.path.join(SOUNDS, 'flip_01.wav'))
    flip = flip / np.max(np.abs(flip)) * 0.42
    for ft in flip_times:
        i = int(ft * SR)
        j = min(len(st), i + len(flip))
        st[i:j] += flip[: j - i, None]
    st = st / max(1.0, np.max(np.abs(st)) / 0.89)
    path = os.path.join(WORK, 'audio.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((st * 32767).astype(np.int16).tobytes())
    return path


# ---------------------------------------------------------------- main

def main():
    shutil.rmtree(WORK, ignore_errors=True)
    os.makedirs(f'{WORK}/frames')
    n, prev, flips = 0, None, []
    for scene in scenes():
        flips += [(n + f + 4) / FPS for f in scene.flips]
        for i in range(scene.length):
            img = scene.frame(i).convert('RGB')
            if prev is not None and i < FADE:
                img = Image.blend(prev, img, ease((i + 1) / (FADE + 1)))
            img.save(f'{WORK}/frames/{n:05d}.jpg', quality=94)
            n += 1
        prev = img
    seconds = n / FPS
    audio = soundtrack(seconds, flips)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(FPS), '-i', f'{WORK}/frames/%05d.jpg',
                    '-i', audio, '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p',
                    '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', OUT], check=True)
    print(f'{OUT}: {n} frames, {seconds:.1f} s')


if __name__ == '__main__':
    main()
