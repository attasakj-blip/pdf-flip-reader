"""Draws the Pagelume launcher icon: a glowing page turning over an open book.

Run: python3 tools/make_icon.py [out_dir]
Writes the Android launcher icons (legacy + adaptive) into the
app and the 512px Play Store icon (plus a 1024px copy) into out_dir.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 2048  # working size; everything is drawn in a 0..1 square scaled by S
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
RES = os.path.join(ROOT, 'android/app/src/main/res')
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'build/icon')

INK_TOP, INK_BOTTOM = (38, 22, 92), (10, 8, 34)  # night indigo
GLOW = (255, 196, 92)  # lamp gold


def P(x, y):
  return (x * S, y * S)


def bezier(p0, p1, p2, p3, n=60):
  pts = []
  for i in range(n + 1):
    t = i / n
    a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
    pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
  return pts


def lin_gradient(size, c0, c1, angle=90):
  """Gradient from c0 to c1; angle 90 = top to bottom."""
  w, h = size
  g = Image.linear_gradient('L').resize((w, h))
  if angle != 90:
    g = Image.linear_gradient('L').rotate(90 - angle, expand=False).resize((w, h))
  return Image.composite(Image.new('RGB', size, c1), Image.new('RGB', size, c0), g)


def radial(size, center, radius, color, power=1.6):
  w, h = size
  y, x = np.mgrid[0:h, 0:w]
  dist = np.hypot(x - center[0], y - center[1]) / radius
  a = (np.clip(1 - dist, 0, 1) ** power * 255).astype(np.uint8)
  out = Image.new('RGBA', size, color + (0,))
  out.putalpha(Image.fromarray(a, 'L'))
  return out


def mask(poly):
  m = Image.new('L', (S, S), 0)
  ImageDraw.Draw(m).polygon(poly, fill=255)
  return m


def fill(img, poly, src):
  img.paste(src, (0, 0), mask(poly))


def star(cx, cy, r, thin=0.18):
  pts = []
  for k in range(8):
    a = k * math.pi / 4 - math.pi / 2
    rr = r if k % 2 == 0 else r * thin
    pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
  return pts


def background():
  bg = lin_gradient((S, S), INK_TOP, INK_BOTTOM).convert('RGBA')
  bg.alpha_composite(radial((S, S), P(0.56, 0.44), 0.62 * S, (124, 70, 220), 1.4))
  bg.alpha_composite(radial((S, S), P(0.58, 0.46), 0.36 * S, GLOW, 2.2))
  return bg


def foreground(scale=1.0):
  """The book and the turning page on a transparent square. [scale] shrinks
  the art about the centre (adaptive icons need a safe margin)."""
  fg = Image.new('RGBA', (S, S), (0, 0, 0, 0))

  # Book geometry: spine at x=.5, pages slightly fanned like an open book.
  spine_top, spine_bot = P(0.5, 0.36), P(0.5, 0.78)
  l_top, l_bot = P(0.17, 0.31), P(0.17, 0.72)
  r_top, r_bot = P(0.83, 0.31), P(0.83, 0.72)

  # Soft shadow under the book.
  sh = Image.new('L', (S, S), 0)
  ImageDraw.Draw(sh).polygon([P(0.15, 0.36), P(0.5, 0.42), P(0.85, 0.36), P(0.86, 0.8), P(0.5, 0.86), P(0.14, 0.8)], fill=150)
  sh = sh.filter(ImageFilter.GaussianBlur(S * 0.03))
  fg.paste(Image.new('RGBA', (S, S), (6, 4, 20, 255)), (0, 0), sh)

  # Cover edge peeking out below the pages.
  cover = [P(0.14, 0.34), P(0.5, 0.40), P(0.86, 0.34), P(0.86, 0.755), P(0.5, 0.815), P(0.14, 0.755)]
  fill(fg, cover, lin_gradient((S, S), (255, 170, 70), (214, 92, 40)))

  page = lin_gradient((S, S), (255, 251, 240), (240, 226, 202))
  left = [l_top] + bezier(l_top, P(0.3, 0.29), P(0.42, 0.31), spine_top)[1:] + [spine_bot] + bezier(spine_bot, P(0.42, 0.73), P(0.3, 0.7), l_bot)[1:]
  right = [spine_top] + bezier(spine_top, P(0.58, 0.31), P(0.7, 0.29), r_top)[1:] + [r_bot] + bezier(r_bot, P(0.7, 0.7), P(0.58, 0.73), spine_bot)[1:]
  fill(fg, left, page)
  fill(fg, right, lin_gradient((S, S), (250, 240, 222), (232, 214, 186)))

  d = ImageDraw.Draw(fg)
  # Text lines on the left page, following its curve.
  for k in range(5):
    y = 0.405 + k * 0.062
    pts = bezier(P(0.23, y - 0.012), P(0.31, y - 0.02), P(0.4, y - 0.008), P(0.45, y + 0.012), 30)
    d.line(pts, fill=(196, 178, 210), width=int(S * 0.016), joint='curve')
  # Spine shadow.
  d.line([spine_top, spine_bot], fill=(190, 160, 140), width=int(S * 0.008))

  # Text lines on the right page (partly hidden by the turning page).
  for k in range(5):
    y = 0.405 + k * 0.062
    pts = bezier(P(0.55, y + 0.012), P(0.6, y - 0.008), P(0.69, y - 0.02), P(0.77, y - 0.012), 30)
    d.line(pts, fill=(214, 196, 220), width=int(S * 0.016), joint='curve')

  # The turning page: standing up from the spine and leaning right, its
  # far edge bending like paper mid-flip.
  o_top, o_bot = P(0.75, 0.13), P(0.79, 0.6)
  turn = (
      bezier(spine_top, P(0.56, 0.27), P(0.64, 0.15), o_top)
      + bezier(o_top, P(0.8, 0.27), P(0.8, 0.45), o_bot)[1:]
      + bezier(o_bot, P(0.7, 0.66), P(0.56, 0.72), spine_bot)[1:]
  )
  # Shadow it casts on the right page.
  cs = Image.new('L', (S, S), 0)
  ImageDraw.Draw(cs).polygon([spine_top, P(0.7, 0.36), P(0.8, 0.66), spine_bot], fill=120)
  cs = ImageChops.multiply(cs.filter(ImageFilter.GaussianBlur(S * 0.025)), mask(right))
  fg.paste(Image.new('RGBA', (S, S), (110, 70, 80, 255)), (0, 0), cs)
  # Warm light pouring from behind the page.
  gm = mask(turn).filter(ImageFilter.GaussianBlur(S * 0.045))
  glow = Image.new('RGBA', (S, S), GLOW + (0,))
  glow.putalpha(gm.point(lambda v: min(255, int(v * 1.5))))
  fg.alpha_composite(glow)
  # The page itself, brightest at its far edge.
  fill(fg, turn, lin_gradient((S, S), (255, 226, 160), (255, 255, 250), angle=0))
  d = ImageDraw.Draw(fg)
  d.line(bezier(o_top, P(0.8, 0.27), P(0.8, 0.45), o_bot), fill=(255, 250, 232), width=int(S * 0.012), joint='curve')
  d.line([spine_top, spine_bot], fill=(214, 170, 120), width=int(S * 0.008))

  # Sparkles of light.
  for cx, cy, r in [(0.84, 0.17, 0.075), (0.72, 0.1, 0.035), (0.93, 0.29, 0.03)]:
    halo = radial((S, S), P(cx, cy), r * S * 1.6, (255, 230, 160), 2.0)
    fg.alpha_composite(halo)
    d.polygon(star(cx * S, cy * S, r * S), fill=(255, 250, 230))

  if scale != 1.0:
    small = fg.resize((int(S * scale), int(S * scale)), Image.LANCZOS)
    fg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    o = (S - small.width) // 2
    fg.alpha_composite(small, (o, o))
  return fg


def rounded(im, r):
  m = Image.new('L', im.size, 0)
  ImageDraw.Draw(m).rounded_rectangle((0, 0, im.size[0] - 1, im.size[1] - 1), r, fill=255)
  out = Image.new('RGBA', im.size, (0, 0, 0, 0))
  out.paste(im, (0, 0), m)
  return out


def main():
  os.makedirs(OUT, exist_ok=True)
  bg = background()
  full = bg.copy()
  full.alpha_composite(foreground(0.86))
  full.convert('RGB').resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, 'icon_512.png'))
  full.convert('RGB').resize((1024, 1024), Image.LANCZOS).save(os.path.join(OUT, 'icon_1024.png'))

  # Adaptive icon: 108dp layers; launchers show the middle 72dp (a circle of
  # 66dp is always safe), so the art is drawn at 66/108 of the layer.
  fg = foreground(0.66)
  dens = [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]
  for name, k in dens:
    d = os.path.join(RES, f'mipmap-{name}')
    os.makedirs(d, exist_ok=True)
    px = int(48 * k)
    rounded(full.resize((px, px), Image.LANCZOS), px // 5).save(os.path.join(d, 'ic_launcher.png'))
    lp = int(108 * k)
    fg.resize((lp, lp), Image.LANCZOS).save(os.path.join(d, 'ic_launcher_foreground.png'))
    bg.convert('RGB').resize((lp, lp), Image.LANCZOS).save(os.path.join(d, 'ic_launcher_background.png'))
  any_dir = os.path.join(RES, 'mipmap-anydpi-v26')
  os.makedirs(any_dir, exist_ok=True)
  with open(os.path.join(any_dir, 'ic_launcher.xml'), 'w') as f:
    f.write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )
  # iOS: one opaque 1024px square; the system rounds the corners.
  ios = os.path.join(ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
  write_ios_icon(full.convert('RGB').resize((1024, 1024), Image.LANCZOS), ios)
  print('icons written to', OUT)


def write_ios_icon(img, folder):
  for old in os.listdir(folder):
    if old.endswith('.png'):
      os.remove(os.path.join(folder, old))
  img.save(os.path.join(folder, 'Icon-App-1024x1024@1x.png'))
  with open(os.path.join(folder, 'Contents.json'), 'w') as f:
    f.write(
        '{\n  "images" : [\n    {\n      "filename" : "Icon-App-1024x1024@1x.png",\n'
        '      "idiom" : "universal",\n      "platform" : "ios",\n      "size" : "1024x1024"\n    }\n  ],\n'
        '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n'
    )


if __name__ == '__main__':
  main()
