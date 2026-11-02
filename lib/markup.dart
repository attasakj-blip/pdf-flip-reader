import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'edit_tools.dart' show PageSlot, ToolBar;
import 'l10n.dart';
import 'pdf_edit.dart' show PageChar, PageRect, Stamp;
import 'text_box.dart' show TextNote, noteRect, paintNotes;

enum MarkTool { pen, highlighter, textHighlight, line, rect, circle, ellipse }

/// Sixteen colours for everyday marking.
const markColors = <Color>[
  Color(0xFF000000), Color(0xFF555555), Color(0xFFAAAAAA), Color(0xFFFFFFFF), //
  Color(0xFFE53935), Color(0xFF8E0000), Color(0xFFFF9800), Color(0xFFFFEB3B),
  Color(0xFF8BC34A), Color(0xFF1B7F3B), Color(0xFF00BCD4), Color(0xFF1E88E5),
  Color(0xFF1A237E), Color(0xFF8E24AA), Color(0xFFEC407A), Color(0xFF795548),
];

/// Five line widths as fractions of the page width (about 1 to 5 points on
/// an A4 page).
const markWidths = [0.0015, 0.0025, 0.004, 0.006, 0.009];

/// Five highlighter brush widths, fine to broad (about 5 to 27 points).
const highlightWidths = [0.008, 0.014, 0.022, 0.032, 0.045];

/// How see-through highlights are, so the text shows through.
const _highlightAlpha = 0.38;

/// One drawn mark. Points are fractions of the page (origin top-left), so
/// marks stay put when the page is zoomed or moved.
class Mark {
  Mark({required this.page, required this.tool, required this.color, required this.width, required this.dashed})
    : points = [],
      rects = [];

  final int page;
  final MarkTool tool;
  final Color color;
  final double width;
  final bool dashed;
  final List<Offset> points;

  /// For [MarkTool.textHighlight]: one box per line of highlighted text.
  final List<PageRect> rects;

  Mark copy() => Mark(page: page, tool: tool, color: color, width: width, dashed: dashed)
    ..points.addAll(points)
    ..rects.addAll(rects);

  bool get isShape => tool.index >= MarkTool.line.index;
  bool get isEmpty => tool == MarkTool.textHighlight ? rects.isEmpty : points.isEmpty;

  /// Draws the mark with the page occupying [page] on [canvas].
  void paint(Canvas canvas, Rect page) {
    if (tool == MarkTool.textHighlight) {
      final fill = Paint()..color = color.withValues(alpha: _highlightAlpha);
      // One path, so overlapping line boxes don't darken.
      final path = Path();
      for (final r in rects) {
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              page.left + r.left * page.width,
              page.top + r.top * page.height,
              r.width * page.width,
              r.height * page.height,
            ),
            Radius.circular(r.height * page.height * 0.15),
          ),
        );
      }
      canvas.drawPath(path, fill);
      return;
    }
    if (points.isEmpty) return;
    Offset at(Offset f) => Offset(page.left + f.dx * page.width, page.top + f.dy * page.height);
    final highlight = tool == MarkTool.highlighter;
    final paint = Paint()
      ..color = highlight ? color.withValues(alpha: _highlightAlpha) : color
      ..strokeWidth = width * page.width
      ..style = PaintingStyle.stroke
      ..strokeCap = highlight ? StrokeCap.butt : StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    final a = at(points.first), b = at(points.last);
    switch (tool) {
      case MarkTool.textHighlight:
        break;
      case MarkTool.pen:
      case MarkTool.highlighter:
        path.moveTo(a.dx, a.dy);
        if (points.length == 1) {
          path.lineTo(a.dx + 0.01, a.dy);
        }
        for (var i = 1; i < points.length - 1; i++) {
          final p = at(points[i]), mid = (p + at(points[i + 1])) / 2;
          path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
        }
        if (points.length > 1) path.lineTo(b.dx, b.dy);
      case MarkTool.line:
        path
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy);
      case MarkTool.rect:
        path.addRect(Rect.fromPoints(a, b));
      case MarkTool.circle:
      case MarkTool.ellipse:
        path.addOval(Rect.fromPoints(a, b));
    }
    canvas.drawPath(dashed && !highlight ? _dash(path, paint.strokeWidth) : path, paint);
  }

  /// Whether a circle of [radius] pixels at [p] touches the mark, with the
  /// page drawn at [page] on screen.
  bool touches(Offset p, double radius, Rect page) {
    Offset at(Offset f) => Offset(page.left + f.dx * page.width, page.top + f.dy * page.height);
    final reach = radius + width * page.width / 2;
    if (tool == MarkTool.textHighlight) {
      for (final r in rects) {
        final box = Rect.fromLTWH(
          page.left + r.left * page.width,
          page.top + r.top * page.height,
          r.width * page.width,
          r.height * page.height,
        );
        if (box.inflate(radius).contains(p)) return true;
      }
      return false;
    }
    if (points.isEmpty) return false;
    if (!isShape) {
      for (var i = 0; i < points.length; i++) {
        final a = at(points[i]), b = at(points[math.min(i + 1, points.length - 1)]);
        if (_segmentDistance(p, a, b) <= reach) return true;
      }
      return false;
    }
    return outlineDistance(p, page) <= reach;
  }

  /// Screen distance from [p] to a shape's outline.
  double outlineDistance(Offset p, Rect page) {
    Offset at(Offset f) => Offset(page.left + f.dx * page.width, page.top + f.dy * page.height);
    final a = at(points.first), b = at(points.last);
    switch (tool) {
      case MarkTool.line:
        return _segmentDistance(p, a, b);
      case MarkTool.rect:
        final r = Rect.fromPoints(a, b);
        return [
          _segmentDistance(p, r.topLeft, r.topRight),
          _segmentDistance(p, r.topRight, r.bottomRight),
          _segmentDistance(p, r.bottomRight, r.bottomLeft),
          _segmentDistance(p, r.bottomLeft, r.topLeft),
        ].reduce(math.min);
      case MarkTool.circle:
      case MarkTool.ellipse:
        final r = Rect.fromPoints(a, b);
        final rx = math.max(r.width / 2, 0.5), ry = math.max(r.height / 2, 0.5);
        final d = p - r.center;
        final k = math.sqrt(d.dx * d.dx / (rx * rx) + d.dy * d.dy / (ry * ry));
        return (k - 1).abs() * math.min(rx, ry);
      default:
        return double.infinity;
    }
  }

  /// Box around the mark, in page fractions, with room for the line width.
  PageRect bounds(double aspect) {
    if (tool == MarkTool.textHighlight) {
      var l = rects.first.left, t = rects.first.top, r = l + rects.first.width, b = t + rects.first.height;
      for (final x in rects) {
        l = math.min(l, x.left);
        t = math.min(t, x.top);
        r = math.max(r, x.left + x.width);
        b = math.max(b, x.top + x.height);
      }
      return (left: l, top: t, width: r - l, height: b - t);
    }
    var l = points.first.dx, t = points.first.dy, r = l, b = t;
    for (final p in points) {
      l = math.min(l, p.dx);
      t = math.min(t, p.dy);
      r = math.max(r, p.dx);
      b = math.max(b, p.dy);
    }
    final pad = width;
    final padY = pad / aspect; // width is relative to page width
    return (left: l - pad, top: t - padY, width: r - l + 2 * pad, height: b - t + 2 * padY);
  }
}

/// The boxes to highlight when a finger drags from [a] to [b] (page
/// fractions) over [chars]: every character between the ones nearest the
/// two points, merged into one box per line. Empty when [a] is not on text.
List<PageRect> highlightRects(List<PageChar> chars, Offset a, Offset b) {
  int? nearest(Offset p, double reach) {
    int? best;
    var bestD = reach;
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      if (c.blank) continue;
      final r = c.box;
      final dx = math.max(0.0, math.max(r.left - p.dx, p.dx - r.left - r.width));
      final dy = math.max(0.0, math.max(r.top - p.dy, p.dy - r.top - r.height));
      final d = dx * dx + dy * dy * 4; // prefer the line the finger is on
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  final i = nearest(a, 0.03 * 0.03);
  if (i == null) return const [];
  final j = nearest(b, double.infinity) ?? i;
  final from = math.min(i, j), to = math.max(i, j);
  final lines = <int, PageRect>{};
  for (var k = from; k <= to; k++) {
    final c = chars[k];
    if (c.blank) continue;
    final r = c.box, old = lines[c.line];
    if (old == null) {
      lines[c.line] = r;
    } else {
      final l = math.min(old.left, r.left), t = math.min(old.top, r.top);
      final rr = math.max(old.left + old.width, r.left + r.width),
          bb = math.max(old.top + old.height, r.top + r.height);
      lines[c.line] = (left: l, top: t, width: rr - l, height: bb - t);
    }
  }
  // A little air above and below, like a real highlighter.
  return [
    for (final r in lines.values) (left: r.left, top: r.top - r.height * 0.12, width: r.width, height: r.height * 1.24),
  ];
}

double _segmentDistance(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// Eraser sizes (radius in pixels): small, medium, large.
const eraserSizes = [8.0, 18.0, 34.0];

Path _dash(Path source, double width) {
  final dash = math.max(4.0, width * 3), gap = math.max(3.0, width * 2);
  final out = Path();
  for (final m in source.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, math.min(d + dash, m.length)), Offset.zero);
      d += dash + gap;
    }
  }
  return out;
}

/// Turns the marks on each page into images for [PdfEditor.stampAll].
/// [aspects] gives each page's height / width.
Future<List<Stamp>> markStamps(List<Mark> marks, Map<int, double> aspects) async {
  const pageWidthPx = 1700.0; // about 200 dpi on A4
  final stamps = <Stamp>[];
  for (final page in marks.map((m) => m.page).toSet()) {
    final aspect = aspects[page] ?? 1.414;
    final mine = marks.where((m) => m.page == page && !m.isEmpty).toList();
    if (mine.isEmpty) continue;
    var box = mine.first.bounds(aspect);
    for (final m in mine.skip(1)) {
      final b = m.bounds(aspect);
      final l = math.min(box.left, b.left), t = math.min(box.top, b.top);
      final r = math.max(box.left + box.width, b.left + b.width), bt = math.max(box.top + box.height, b.top + b.height);
      box = (left: l, top: t, width: r - l, height: bt - t);
    }
    // Keep it on the page.
    final l = box.left.clamp(0.0, 1.0), t = box.top.clamp(0.0, 1.0);
    final r = (box.left + box.width).clamp(0.0, 1.0), b = (box.top + box.height).clamp(0.0, 1.0);
    if (r <= l || b <= t) continue;
    box = (left: l, top: t, width: r - l, height: b - t);

    final pagePx = Size(pageWidthPx, pageWidthPx * aspect);
    final w = math.max(1, (box.width * pagePx.width).round()), h = math.max(1, (box.height * pagePx.height).round());
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final where = Rect.fromLTWH(-box.left * pagePx.width, -box.top * pagePx.height, pagePx.width, pagePx.height);
    for (final m in mine) {
      m.paint(canvas, where);
    }
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    img.dispose();
    stamps.add((page: page, rgba: data!.buffer.asUint8List(), w: w, h: h, rect: box));
  }
  return stamps;
}

/// Drawing over the visible pages. One finger draws with the chosen tool;
/// two fingers zoom and move the page (through [onZoom]).
class MarkupLayer extends StatefulWidget {
  const MarkupLayer({
    super.key,
    required this.slots,
    required this.marks,
    required this.zoom,
    required this.pan,
    required this.onZoom,
    required this.onDone,
    required this.onCancel,
    this.pageChars,
    this.erasing = false,
    this.canFinishEmpty = false,
    this.notes,
  });

  /// Text boxes taken back from saved steps: shown, and the eraser removes
  /// the ones it touches.
  final List<TextNote>? notes;

  /// Done stays available with no marks left (they were all erased).
  final bool canFinishEmpty;

  /// Start with the eraser rather than the pen.
  final bool erasing;

  /// Pages as they sit on screen right now (zoom included).
  final List<PageSlot> slots;
  final List<Mark> marks;
  final double zoom;
  final Offset pan;

  /// New zoom and offset in screen space; the reader clamps and applies them.
  final void Function(double zoom, Offset pan) onZoom;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  /// The text on a page, for [MarkTool.textHighlight].
  final Future<List<PageChar>> Function(int page)? pageChars;

  @override
  State<MarkupLayer> createState() => _MarkupLayerState();
}

class _MarkupLayerState extends State<MarkupLayer> {
  MarkTool _tool = MarkTool.pen;
  Color _color = markColors[4];
  Color _hiColor = markColors[7];
  int _width = 2;
  bool _dashed = false;

  // The eraser takes out whole marks it touches.
  late bool _erasing = widget.erasing;
  int _eraserSize = 1;
  Offset? _eraserAt;

  // A shape just drawn (or picked by its outline) can still be moved and
  // resized. Choosing another tool or Done keeps it as it is.
  Mark? _chosen;
  // What a drag on the chosen shape does: -1 move, 0/1 line ends,
  // 0-3 box corners (top-left, top-right, bottom-right, bottom-left).
  int? _grip;
  static const _gripReach = 18.0;

  // Page text for highlighting, loaded when first needed.
  final _chars = <int, List<PageChar>>{};
  final _loadingChars = <int>{};
  Offset _hlStart = Offset.zero;

  bool get _highlighting => _tool == MarkTool.highlighter || _tool == MarkTool.textHighlight;
  Color get _current => _highlighting ? _hiColor : _color;

  void _loadChars() {
    final load = widget.pageChars;
    if (load == null || _tool != MarkTool.textHighlight) return;
    for (final s in widget.slots) {
      if (_chars.containsKey(s.page) || !_loadingChars.add(s.page)) continue;
      load(s.page)
          .then((c) => _chars[s.page] = c, onError: (_) => _chars[s.page] = const <PageChar>[])
          .whenComplete(() => _loadingChars.remove(s.page));
    }
  }

  @override
  void didUpdateWidget(MarkupLayer old) {
    super.didUpdateWidget(old);
    _loadChars();
  }

  Mark? _drawing;
  PageSlot? _slot;
  Offset _start = Offset.zero;
  bool _zooming = false;
  // After a pinch, the finger left behind must not start drawing.
  bool _waitForLift = false;
  double _zoomAtStart = 1;
  Offset _panAtStart = Offset.zero, _focalAtStart = Offset.zero;

  Offset _frac(PageSlot s, Offset p) {
    final c = Offset(p.dx.clamp(s.rect.left, s.rect.right), p.dy.clamp(s.rect.top, s.rect.bottom));
    return Offset((c.dx - s.rect.left) / s.rect.width, (c.dy - s.rect.top) / s.rect.height);
  }

  void _onStart(ScaleStartDetails d) {
    _zooming = d.pointerCount >= 2;
    if (_zooming) {
      // A second finger: drop the mark the first finger had begun.
      if (_drawing != null) setState(() => widget.marks.remove(_drawing));
      _drawing = null;
      _zoomAtStart = widget.zoom;
      _panAtStart = widget.pan;
      _focalAtStart = d.localFocalPoint;
      return;
    }
    if (_waitForLift) return;
    final p = d.localFocalPoint;
    if (_erasing) {
      _erase(p);
      return;
    }
    if (_startEditing(p)) return;
    _slot = null;
    for (final s in widget.slots) {
      if (s.rect.contains(p)) _slot = s;
    }
    final s = _slot;
    if (s == null) return;
    _start = p;
    if (_tool == MarkTool.textHighlight) {
      final chars = _chars[s.page];
      if (chars == null) {
        _loadChars();
        return;
      }
      if (chars.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(S.of(context).noTextHere)));
        _slot = null;
        return;
      }
      _hlStart = _frac(s, p);
      final m = Mark(page: s.page, tool: _tool, color: _hiColor, width: 0, dashed: false);
      m.rects.addAll(highlightRects(chars, _hlStart, _hlStart));
      setState(() {
        _drawing = m;
        widget.marks.add(m);
      });
      return;
    }
    final m = Mark(
      page: s.page,
      tool: _tool,
      color: _current,
      width: (_tool == MarkTool.highlighter ? highlightWidths : markWidths)[_width],
      dashed: _dashed && !_highlighting,
    );
    m.points.add(_frac(s, p));
    if (m.isShape) m.points.add(_frac(s, p));
    setState(() {
      _drawing = m;
      widget.marks.add(m);
    });
  }

  PageSlot? _slotOfPage(int page) {
    for (final s in widget.slots) {
      if (s.page == page) return s;
    }
    return null;
  }

  /// Corners (or line ends) of a shape on screen.
  List<Offset> _grips(Mark m, Rect page) {
    Offset at(Offset f) => Offset(page.left + f.dx * page.width, page.top + f.dy * page.height);
    final a = at(m.points.first), b = at(m.points.last);
    if (m.tool == MarkTool.line) return [a, b];
    final r = Rect.fromPoints(a, b);
    return [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
  }

  /// A press on the chosen shape's grips or body starts moving or resizing
  /// it; a press on another shape's outline chooses that one. Anywhere else
  /// lets the chosen shape go and returns false (draw as usual).
  bool _startEditing(Offset p) {
    final m = _chosen;
    if (m != null) {
      final s = _slotOfPage(m.page);
      if (s != null) {
        final g = _grips(m, s.rect);
        for (var i = 0; i < g.length; i++) {
          if ((g[i] - p).distance <= _gripReach) {
            _grip = i;
            _start = p;
            return true;
          }
        }
        final box = Rect.fromPoints(g.first, g[g.length == 2 ? 1 : 2]).inflate(_gripReach);
        if (box.contains(p) || m.outlineDistance(p, s.rect) <= _gripReach) {
          _grip = -1;
          _start = p;
          return true;
        }
      }
    }
    // Pick up an earlier shape by its outline.
    for (final o in widget.marks.reversed) {
      if (!o.isShape) continue;
      final s = _slotOfPage(o.page);
      if (s != null && o.outlineDistance(p, s.rect) <= 10) {
        setState(() => _chosen = o);
        _grip = -1;
        _start = p;
        return true;
      }
    }
    if (_chosen != null) setState(() => _chosen = null);
    _grip = null;
    return false;
  }

  void _editUpdate(Offset p) {
    final m = _chosen, g = _grip;
    if (m == null || g == null) return;
    final s = _slotOfPage(m.page);
    if (s == null) return;
    final r = s.rect;
    Offset frac(Offset q) => Offset((q.dx - r.left) / r.width, (q.dy - r.top) / r.height);
    setState(() {
      if (g == -1) {
        final d = p - _start;
        final f = Offset(d.dx / r.width, d.dy / r.height);
        for (var i = 0; i < m.points.length; i++) {
          m.points[i] += f;
        }
        _start = p;
      } else if (m.tool == MarkTool.line) {
        m.points[g == 0 ? 0 : m.points.length - 1] = frac(p);
      } else {
        final grips = _grips(m, r);
        final fixed = grips[(g + 2) % 4];
        var q = p;
        if (m.tool == MarkTool.circle) {
          final dx = q.dx - fixed.dx, dy = q.dy - fixed.dy;
          final side = math.max(dx.abs(), dy.abs());
          q = fixed + Offset(side * (dx == 0 ? 1 : dx.sign), side * (dy == 0 ? 1 : dy.sign));
        }
        m.points
          ..[0] = frac(fixed)
          ..[m.points.length - 1] = frac(q);
      }
    });
  }

  void _erase(Offset p) {
    final r = eraserSizes[_eraserSize];
    final hit = <Mark>[];
    for (final m in widget.marks) {
      final s = _slotOfPage(m.page);
      if (s != null && m.touches(p, r, s.rect)) hit.add(m);
    }
    setState(() {
      _eraserAt = p;
      widget.marks.removeWhere(hit.contains);
      if (hit.contains(_chosen)) _chosen = null;
      widget.notes?.removeWhere((n) {
        final s = _slotOfPage(n.page);
        return s != null && noteRect(n, s.rect).inflate(r).contains(p);
      });
    });
  }

  void _setTool(MarkTool t) {
    setState(() {
      _tool = t;
      _erasing = false;
      _chosen = null; // keeps the chosen shape as it is
    });
    _loadChars();
  }

  void _onUpdate(ScaleUpdateDetails d) {
    if (!_zooming && _erasing) {
      _erase(d.localFocalPoint);
      return;
    }
    if (!_zooming && _grip != null) {
      _editUpdate(d.localFocalPoint);
      return;
    }
    if (_zooming) {
      final z = (_zoomAtStart * d.scale).clamp(1.0, 5.0);
      final anchor = (_focalAtStart - _panAtStart) / _zoomAtStart;
      widget.onZoom(z, d.localFocalPoint - anchor * z);
      return;
    }
    final m = _drawing, s = _slot;
    if (m == null || s == null) return;
    var p = d.localFocalPoint;
    if (_tool == MarkTool.circle) {
      // A circle: the box is kept square on screen (and so on the page).
      final dx = p.dx - _start.dx, dy = p.dy - _start.dy;
      final side = math.max(dx.abs(), dy.abs());
      p = _start + Offset(side * dx.sign, side * dy.sign);
    }
    setState(() {
      if (m.tool == MarkTool.textHighlight) {
        m.rects
          ..clear()
          ..addAll(highlightRects(_chars[s.page] ?? const [], _hlStart, _frac(s, p)));
      } else if (m.isShape) {
        m.points[1] = _frac(s, p);
      } else {
        m.points.add(_frac(s, p));
      }
    });
  }

  void _onEnd(ScaleEndDetails d) {
    final m = _drawing;
    _grip = null;
    // A tap with a shape tool leaves nothing worth keeping.
    if (m != null && (m.isEmpty || (m.isShape && m.points.first == m.points.last))) {
      setState(() => widget.marks.remove(m));
    } else if (m != null && m.isShape) {
      setState(() => _chosen = m); // ready to be moved or resized
    }
    if (_zooming && d.pointerCount > 0) _waitForLift = true;
    if (d.pointerCount == 0) _waitForLift = false;
    _drawing = null;
    _zooming = false;
  }

  Future<void> _pickColor() async {
    final c = await showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in markColors)
                InkWell(
                  onTap: () => Navigator.pop(ctx, c),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == _current ? Colors.lightBlueAccent : Colors.white38,
                        width: c == _current ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (c == null) return;
    setState(() => _highlighting ? _hiColor = c : _color = c);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget tool(MarkTool t, Widget icon, String tip) => IconButton(
      tooltip: tip,
      style: IconButton.styleFrom(
        backgroundColor: _tool == t && !_erasing ? Colors.lightBlueAccent.withValues(alpha: 0.3) : null,
      ),
      icon: icon,
      isSelected: _tool == t && !_erasing,
      onPressed: () => _setTool(t),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onStart,
            onScaleUpdate: _onUpdate,
            onScaleEnd: _onEnd,
            child: MouseRegion(
              cursor: _erasing ? SystemMouseCursors.none : MouseCursor.defer,
              onHover: _erasing ? (e) => setState(() => _eraserAt = e.localPosition) : null,
              onExit: (_) => setState(() => _eraserAt = null),
              child: CustomPaint(
                painter: _MarksPainter(
                  widget.marks,
                  widget.slots,
                  notes: widget.notes ?? const [],
                  chosen: _chosen,
                  grips: _chosen == null || _slotOfPage(_chosen!.page) == null
                      ? const []
                      : _grips(_chosen!, _slotOfPage(_chosen!.page)!.rect),
                  eraser: _erasing && _eraserAt != null ? (_eraserAt!, eraserSizes[_eraserSize]) : null,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ToolBar(
            hint: s.markHint,
            confirm: s.done,
            onCancel: widget.onCancel,
            onConfirm: widget.marks.isEmpty && (widget.notes?.isEmpty ?? true) && !widget.canFinishEmpty
                ? null
                : widget.onDone,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Material(
            color: Colors.black.withValues(alpha: 0.8),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    tool(MarkTool.pen, const Icon(Icons.gesture), s.toolPen),
                    tool(MarkTool.textHighlight, const Icon(Icons.format_color_text), s.toolTextHighlight),
                    tool(MarkTool.highlighter, const Icon(Icons.border_color), s.toolHighlighter),
                    tool(MarkTool.line, const Icon(Icons.horizontal_rule), s.toolLine),
                    tool(MarkTool.rect, const Icon(Icons.crop_square), s.toolRect),
                    tool(MarkTool.circle, const Icon(Icons.circle_outlined), s.toolCircle),
                    tool(MarkTool.ellipse, const _OvalIcon(), s.toolEllipse),
                    IconButton(
                      tooltip: s.eraser,
                      style: IconButton.styleFrom(
                        backgroundColor: _erasing ? Colors.lightBlueAccent.withValues(alpha: 0.3) : null,
                      ),
                      onPressed: () => setState(() {
                        _erasing = true;
                        _chosen = null;
                      }),
                      icon: const Icon(Icons.auto_fix_normal),
                    ),
                    if (_erasing)
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                        segments: [
                          ButtonSegment(value: 0, label: Text(s.sizeSmall)),
                          ButtonSegment(value: 1, label: Text(s.sizeMedium)),
                          ButtonSegment(value: 2, label: Text(s.sizeLarge)),
                        ],
                        selected: {_eraserSize},
                        onSelectionChanged: (v) => setState(() => _eraserSize = v.first),
                      ),
                    const SizedBox(height: 32, child: VerticalDivider()),
                    IconButton(
                      tooltip: s.color,
                      onPressed: _pickColor,
                      icon: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _current,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70),
                        ),
                      ),
                    ),
                    PopupMenuButton<int>(
                      tooltip: s.thickness,
                      enabled: _tool != MarkTool.textHighlight,
                      initialValue: _width,
                      onSelected: (w) => setState(() => _width = w),
                      itemBuilder: (_) => [
                        for (var i = 0; i < markWidths.length; i++)
                          PopupMenuItem(
                            value: i,
                            child: _WidthSample(i, highlight: _highlighting, color: _current),
                          ),
                      ],
                      icon: _WidthSample(_width, highlight: _highlighting, color: Colors.white, small: true),
                    ),
                    IconButton(
                      tooltip: _dashed ? s.lineDashed : s.lineSolid,
                      onPressed: _highlighting ? null : () => setState(() => _dashed = !_dashed),
                      icon: Icon(_dashed ? Icons.more_horiz : Icons.remove),
                    ),
                    IconButton(
                      tooltip: s.undo,
                      onPressed: widget.marks.isEmpty ? null : () => setState(() => widget.marks.removeLast()),
                      icon: const Icon(Icons.undo),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A stroke showing line width [index] (0 thinnest to 4 broadest).
class _WidthSample extends StatelessWidget {
  const _WidthSample(this.index, {required this.highlight, required this.color, this.small = false});
  final int index;
  final bool highlight;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final h = (highlight ? const [4.0, 7.0, 10.0, 14.0, 18.0] : const [1.5, 2.5, 4.0, 6.0, 9.0])[index];
    return SizedBox(
      width: small ? 26 : 120,
      height: small ? 24 : 28,
      child: Center(
        child: Container(
          height: small ? math.min(h, 12) : h,
          decoration: BoxDecoration(
            color: highlight && !small ? color.withValues(alpha: 0.6) : color,
            borderRadius: BorderRadius.circular(highlight ? 2 : h / 2),
          ),
        ),
      ),
    );
  }
}

class _OvalIcon extends StatelessWidget {
  const _OvalIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 15,
    decoration: BoxDecoration(
      border: Border.all(color: IconTheme.of(context).color ?? Colors.white, width: 2),
      borderRadius: const BorderRadius.all(Radius.elliptical(12, 7.5)),
    ),
  );
}

/// Shows [marks] without letting them be changed (under the text tool).
CustomPainter marksPainter(List<Mark> marks, List<PageSlot> slots) => _MarksPainter(marks, slots);

class _MarksPainter extends CustomPainter {
  _MarksPainter(this.marks, this.slots, {this.notes = const [], this.chosen, this.grips = const [], this.eraser});
  final List<Mark> marks;
  final List<TextNote> notes;
  final List<PageSlot> slots;
  final Mark? chosen;
  final List<Offset> grips;
  final (Offset, double)? eraser;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in slots) {
      canvas.save();
      canvas.clipRect(s.rect);
      paintNotes(canvas, notes, s.page, s.rect);
      for (final m in marks) {
        if (m.page == s.page) m.paint(canvas, s.rect);
      }
      canvas.restore();
    }
    // The chosen shape: a dashed box and round grips.
    if (chosen != null && grips.isNotEmpty) {
      final line = Paint()
        ..color = Colors.lightBlueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      if (grips.length == 4) {
        canvas.drawPath(_dash(Path()..addRect(Rect.fromPoints(grips[0], grips[2]).inflate(4)), 1.2), line);
      }
      for (final g in grips) {
        canvas.drawCircle(g, 7, Paint()..color = Colors.lightBlueAccent);
        canvas.drawCircle(
          g,
          7,
          Paint()
            ..color = Colors.black54
            ..style = PaintingStyle.stroke,
        );
      }
    }
    final e = eraser;
    if (e != null) {
      canvas.drawCircle(e.$1, e.$2, Paint()..color = Colors.white.withValues(alpha: 0.25));
      canvas.drawCircle(
        e.$1,
        e.$2,
        Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  // Marks are edited in place, so always repaint.
  @override
  bool shouldRepaint(_MarksPainter old) => true;
}
