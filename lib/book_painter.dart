import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Supplies rendered page bitmaps; notifies when more become available.
abstract class PageImageSource implements Listenable {
  ui.Image? image(int? index);
}

/// Which pages are visible side by side. In single-page mode [left] is
/// always null and [right] holds the page.
class Spread {
  const Spread(this.left, this.right);
  final int? left;
  final int? right;

  Iterable<int> get pages => [left, right].whereType<int>();
}

/// Where the pages sit on screen. The turning page always pivots on
/// [spineX]; in single-page mode the (empty) left page is off to the side.
class BookLayout {
  BookLayout._(this.left, this.right, this.twoPage);

  factory BookLayout.compute(Size size, double aspect, bool twoPage) {
    const margin = 8.0;
    final aw = math.max(1.0, size.width - margin * 2);
    final ah = math.max(1.0, size.height - margin * 2);
    final cx = size.width / 2;
    final cy = size.height / 2;
    if (twoPage) {
      final pw = math.min(aw / 2, ah / aspect);
      final ph = pw * aspect;
      return BookLayout._(Rect.fromLTWH(cx - pw, cy - ph / 2, pw, ph), Rect.fromLTWH(cx, cy - ph / 2, pw, ph), true);
    }
    final pw = math.min(aw, ah / aspect);
    final ph = pw * aspect;
    final right = Rect.fromLTWH(cx - pw / 2, cy - ph / 2, pw, ph);
    return BookLayout._(right.shift(Offset(-pw, 0)), right, false);
  }

  final Rect left;
  final Rect right;
  final bool twoPage;

  double get pageWidth => right.width;
  double get spineX => right.left;

  /// The free corner of the right-hand page.
  Offset corner(bool bottom) => Offset(right.right, bottom ? right.bottom : right.top);

  /// Where that corner lands once the page has been turned completely.
  Offset turnedCorner(bool bottom) => Offset(spineX - pageWidth, bottom ? right.bottom : right.top);

  /// Keeps a dragged corner physically possible: the page is glued to the
  /// spine, so the corner can never be farther from it than the page allows.
  Offset clampCorner(Offset p, bool bottom) {
    final near = Offset(spineX, bottom ? right.bottom : right.top);
    final far = Offset(spineX, bottom ? right.top : right.bottom);
    final w = pageWidth;
    final diag = math.sqrt(w * w + right.height * right.height);
    var q = p;
    for (var i = 0; i < 3; i++) {
      q = _limit(q, near, w);
      q = _limit(q, far, diag);
    }
    return q;
  }

  static Offset _limit(Offset p, Offset c, double r) {
    final d = p - c;
    final len = d.distance;
    if (len <= r || len == 0) return p;
    return c + d / len * r;
  }
}

/// A page turn in progress: the right page of [from] is being lifted at one
/// corner and laid down on the left, revealing [to]. Turning backwards is the
/// same picture played in reverse (from = previous spread).
class FlipState {
  const FlipState({required this.from, required this.to, required this.corner, required this.bottom});
  final Spread from;
  final Spread to;
  final Offset corner;
  final bool bottom;
}

class BookPainter extends CustomPainter {
  BookPainter({required this.cache, required this.layout, required this.spread, required this.flip, this.night = false})
    : paper = night ? nightPaper : dayPaper,
      super(repaint: cache);

  final PageImageSource cache;
  final BookLayout layout;
  final Spread spread;
  final FlipState? flip;

  /// Night mode: pages become light text on dark paper, dimmed, for reading
  /// in a dark room (e.g. projected on the ceiling).
  final bool night;
  final Color paper;

  static const dayPaper = Color(0xFFFFFDF8);
  static const nightPaper = Color(0xFF222222);

  /// Inverts brightness but keeps hues (invert, then rotate hue by 180°),
  /// mapping white paper to [nightPaper] and black text to a soft grey.
  static final nightFilter = () {
    const lo = 0x22, hi = 0xC8;
    const k = (hi - lo) / 255;
    const h = [
      [-0.574, 1.43, 0.144],
      [0.426, 0.43, 0.144],
      [0.426, 1.43, -0.856],
    ];
    return ColorFilter.matrix([
      for (final row in h) ...[-k * row[0], -k * row[1], -k * row[2], 0, hi.toDouble()],
      0,
      0,
      0,
      1,
      0,
    ]);
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final f = flip;
    if (f == null) {
      _bookShadow(canvas, spread);
      _page(canvas, layout.left, spread.left);
      _page(canvas, layout.right, spread.right);
      _spineShadow(canvas, 1);
      return;
    }
    _paintFlip(canvas, f);
  }

  void _paintFlip(Canvas canvas, FlipState f) {
    final r = layout.right;
    final c0 = layout.corner(f.bottom);
    final p = f.corner;

    _bookShadow(canvas, Spread(f.from.left ?? f.to.left, f.to.right ?? f.from.right));
    _page(canvas, layout.left, f.from.left);
    _page(canvas, r, f.to.right);

    final delta = c0 - p;
    if (delta.distance < 0.5) {
      _page(canvas, r, f.from.right);
      _spineShadow(canvas, 1);
      return;
    }

    // Fold line: perpendicular bisector of the corner and the finger.
    final mid = (c0 + p) / 2;
    final n = delta / delta.distance; // points towards the lifted corner
    final rect = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
    final flat = _clipHalf(rect, mid, n, keepPositive: false);
    final lifted = _clipHalf(rect, mid, n, keepPositive: true);
    final flap = lifted.map((q) => _reflect(q, mid, n)).toList();

    final t = ((c0.dx - p.dx) / (2 * layout.pageWidth)).clamp(0.0, 1.0);
    final s = math.sin(math.pi * t); // shadow strength, strongest mid-turn
    final w = layout.pageWidth;

    // The part of the turning page that still lies flat.
    if (flat.length >= 3) {
      canvas.save();
      canvas.clipPath(_path(flat));
      _page(canvas, r, f.from.right);
      canvas.restore();
    }

    // Shadow on the newly revealed page, next to the fold.
    if (lifted.length >= 3) {
      canvas.save();
      canvas.clipPath(_path(lifted));
      final sw = w * (0.08 + 0.25 * s);
      canvas.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(mid, mid + n * sw, [
            Colors.black.withValues(alpha: 0.45 * s + 0.1),
            Colors.black.withValues(alpha: 0),
          ]),
      );
      canvas.restore();
    }

    _spineShadow(canvas, 1 - s * 0.6);

    if (flap.length < 3) return;
    final flapPath = _path(flap);

    // Soft shadow the lifted page casts on whatever is beneath it.
    canvas.save();
    canvas.clipRect(layout.left.expandToInclude(r).inflate(20));
    canvas.drawPath(
      flapPath.shift(Offset(-n.dx * 4, -n.dy * 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35 * s + 0.05)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 14 * s),
    );
    canvas.restore();

    // Back side of the turning page.
    canvas.save();
    canvas.clipPath(flapPath);
    final back = cache.image(f.to.left);
    if (layout.twoPage && f.to.left != null) {
      canvas.transform(_backTransform(mid, n));
      _page(canvas, layout.left, f.to.left, image: back);
    } else {
      canvas.drawPath(flapPath, Paint()..color = paper);
      final front = cache.image(f.from.right);
      if (front != null) {
        // Faint show-through of the printed side, like thin paper.
        canvas.transform(_reflectTransform(mid, n));
        canvas.drawImageRect(
          front,
          Rect.fromLTWH(0, 0, front.width.toDouble(), front.height.toDouble()),
          r,
          Paint()
            ..filterQuality = FilterQuality.low
            ..colorFilter = night ? nightFilter : null
            ..color = Colors.white.withValues(alpha: 0.12),
        );
      }
    }
    canvas.restore();

    // Curvature shading on the flap: darker at the fold, lighter beyond.
    canvas.save();
    canvas.clipPath(flapPath);
    final fw = w * 0.5;
    canvas.drawPath(
      flapPath,
      Paint()
        ..shader = ui.Gradient.linear(
          mid,
          mid - n * fw,
          [
            Colors.black.withValues(alpha: 0.25 * s + 0.05),
            Colors.white.withValues(alpha: 0.10 * s),
            Colors.black.withValues(alpha: 0.06 * s),
          ],
          [0, 0.35, 1],
        ),
    );
    canvas.restore();
    canvas.drawPath(
      flapPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.black.withValues(alpha: 0.15),
    );
  }

  void _page(Canvas canvas, Rect rect, int? index, {ui.Image? image}) {
    if (index == null) return;
    canvas.drawRect(rect, Paint()..color = paper);
    final img = image ?? cache.image(index);
    if (img != null) {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        rect,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = night ? nightFilter : null,
      );
    } else {
      final tp = TextPainter(
        text: TextSpan(
          text: '${index + 1}',
          style: TextStyle(
            color: (night ? Colors.white : Colors.black).withValues(alpha: 0.25),
            fontSize: rect.width / 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _bookShadow(Canvas canvas, Spread s) {
    Rect? area;
    if (s.left != null && layout.twoPage) area = layout.left;
    if (s.right != null) area = area == null ? layout.right : area.expandToInclude(layout.right);
    if (area == null) return;
    canvas.drawRect(
      area.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _spineShadow(Canvas canvas, double strength) {
    if (!layout.twoPage) return;
    final x = layout.spineX;
    final r = layout.right;
    final w = layout.pageWidth * 0.06;
    final band = Rect.fromLTRB(x - w, r.top, x + w, r.bottom);
    canvas.drawRect(
      band,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x - w, 0),
          Offset(x + w, 0),
          [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.22 * strength),
            Colors.black.withValues(alpha: 0),
          ],
          [0, 0.5, 1],
        ),
    );
  }

  static Offset _reflect(Offset x, Offset mid, Offset n) {
    final d = (x - mid).dx * n.dx + (x - mid).dy * n.dy;
    return x - n * (2 * d);
  }

  /// Pure reflection across the fold line.
  static Float64List _reflectTransform(Offset mid, Offset n) {
    final a11 = 1 - 2 * n.dx * n.dx;
    final a12 = -2 * n.dx * n.dy;
    final a22 = 1 - 2 * n.dy * n.dy;
    final k = mid.dx * n.dx + mid.dy * n.dy;
    return _affine(a11, a12, a12, a22, 2 * k * n.dx, 2 * k * n.dy);
  }

  /// Maps the left-page rectangle onto the flap: mirror about the spine, then
  /// reflect across the fold. Two mirrors make a rotation, so the back page
  /// reads the right way round.
  Float64List _backTransform(Offset mid, Offset n) {
    final a11 = 1 - 2 * n.dx * n.dx;
    final a12 = -2 * n.dx * n.dy;
    final a22 = 1 - 2 * n.dy * n.dy;
    final k = mid.dx * n.dx + mid.dy * n.dy;
    final s2 = 2 * layout.spineX;
    return _affine(-a11, a12, -a12, a22, a11 * s2 + 2 * k * n.dx, a12 * s2 + 2 * k * n.dy);
  }

  /// x' = a*x + c*y + e, y' = b*x + d*y + f as a column-major 4x4 matrix.
  static Float64List _affine(double a, double c, double b, double d, double e, double f) =>
      Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1]);

  static List<Offset> _clipHalf(List<Offset> poly, Offset mid, Offset n, {required bool keepPositive}) {
    double side(Offset q) {
      final v = (q - mid).dx * n.dx + (q - mid).dy * n.dy;
      return keepPositive ? v : -v;
    }

    final out = <Offset>[];
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      final sa = side(a);
      final sb = side(b);
      if (sa >= 0) out.add(a);
      if ((sa >= 0) != (sb >= 0)) {
        final t = sa / (sa - sb);
        out.add(Offset.lerp(a, b, t)!);
      }
    }
    return out;
  }

  static Path _path(List<Offset> pts) => Path()..addPolygon(pts, true);

  @override
  bool shouldRepaint(BookPainter old) =>
      old.flip != flip ||
      old.spread.left != spread.left ||
      old.spread.right != spread.right ||
      old.layout.right != layout.right ||
      old.layout.twoPage != layout.twoPage ||
      old.night != night ||
      !identical(old.cache, cache);
}

/// Wraps a [PageImageSource] and hands out left-right mirrored page images.
/// Right-to-left books are drawn by mirroring the whole book; mirroring the
/// pages too makes their content read the right way round again.
class MirroredPages implements PageImageSource {
  MirroredPages(this.source);

  final PageImageSource source;
  final Map<int, (ui.Image, ui.Image)> _flipped = {};

  @override
  ui.Image? image(int? index) {
    if (index == null) return null;
    final base = source.image(index);
    if (base == null) return null;
    final hit = _flipped[index];
    if (hit != null && identical(hit.$1, base)) {
      _flipped.remove(index); // keep recently used mirrors at the end
      _flipped[index] = hit;
      return hit.$2;
    }
    hit?.$2.dispose();
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..translate(base.width.toDouble(), 0)
      ..scale(-1, 1)
      ..drawImage(base, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    final picture = recorder.endRecording();
    final img = picture.toImageSync(base.width, base.height);
    picture.dispose();
    _flipped.remove(index);
    _flipped[index] = (base, img);
    while (_flipped.length > 16) {
      _flipped.remove(_flipped.keys.first)!.$2.dispose();
    }
    return img;
  }

  @override
  void addListener(VoidCallback listener) => source.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => source.removeListener(listener);

  void dispose() {
    for (final e in _flipped.values) {
      e.$2.dispose();
    }
    _flipped.clear();
  }
}
