import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'edit_tools.dart' show PageSlot, ToolBar;
import 'l10n.dart';
import 'pdf_edit.dart' show PageChar, PageRect, Stamp;

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
  });

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

  void _onUpdate(ScaleUpdateDetails d) {
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
    // A tap with a shape tool leaves nothing worth keeping.
    if (m != null && (m.isEmpty || (m.isShape && m.points.first == m.points.last))) {
      setState(() => widget.marks.remove(m));
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
      isSelected: _tool == t,
      style: IconButton.styleFrom(backgroundColor: _tool == t ? Colors.lightBlueAccent.withValues(alpha: 0.3) : null),
      icon: icon,
      onPressed: () {
        setState(() => _tool = t);
        _loadChars();
      },
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onStart,
            onScaleUpdate: _onUpdate,
            onScaleEnd: _onEnd,
            child: CustomPaint(painter: _MarksPainter(widget.marks, widget.slots)),
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
            onConfirm: widget.marks.isEmpty ? null : widget.onDone,
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

class _MarksPainter extends CustomPainter {
  _MarksPainter(this.marks, this.slots);
  final List<Mark> marks;
  final List<PageSlot> slots;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in slots) {
      canvas.save();
      canvas.clipRect(s.rect);
      for (final m in marks) {
        if (m.page == s.page) m.paint(canvas, s.rect);
      }
      canvas.restore();
    }
  }

  // Marks are edited in place, so always repaint.
  @override
  bool shouldRepaint(_MarksPainter old) => true;
}
