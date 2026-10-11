import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'l10n.dart';
import 'pdf_edit.dart' show PageRect;

/// A page as it sits on screen right now.
typedef PageSlot = ({int page, Rect rect});

/// Where [rect] (screen coordinates) falls on [slot], as fractions of the page.
PageRect pageRectOf(PageSlot slot, Rect rect) {
  final r = slot.rect;
  return (
    left: (rect.left - r.left) / r.width,
    top: (rect.top - r.top) / r.height,
    width: rect.width / r.width,
    height: rect.height / r.height,
  );
}

/// A drawn signature: strokes in their own box of [size] (logical pixels),
/// trimmed to the ink.
class Signature {
  Signature(this.strokes, this.size, this.color, this.width);

  final List<List<Offset>> strokes;
  final Size size;
  final Color color;
  final double width;

  double get aspect => size.height / size.width;

  void paint(Canvas canvas, Rect into) {
    canvas.save();
    canvas.translate(into.left, into.top);
    final k = into.width / size.width;
    canvas.scale(k);
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first, width / 2, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (var i = 1; i < s.length - 1; i++) {
        final mid = (s[i] + s[i + 1]) / 2;
        path.quadraticBezierTo(s[i].dx, s[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(s.last.dx, s.last.dy);
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  /// RGBA pixels (straight alpha) of the signature [w] pixels wide.
  Future<({Uint8List rgba, int w, int h})> toRgba(int w) async {
    final h = math.max(1, (w * aspect).round());
    final rec = ui.PictureRecorder();
    paint(Canvas(rec), Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    img.dispose();
    return (rgba: data!.buffer.asUint8List(), w: w, h: h);
  }

  static Signature? trim(List<List<Offset>> strokes, Color color, double width) {
    final pts = strokes.expand((s) => s).toList();
    if (pts.isEmpty) return null;
    var l = pts.first.dx, t = pts.first.dy, r = l, b = t;
    for (final p in pts) {
      l = math.min(l, p.dx);
      t = math.min(t, p.dy);
      r = math.max(r, p.dx);
      b = math.max(b, p.dy);
    }
    final pad = width;
    final origin = Offset(l - pad, t - pad);
    return Signature(
      [
        for (final s in strokes) [for (final p in s) p - origin],
      ],
      Size(r - l + pad * 2, b - t + pad * 2),
      color,
      width,
    );
  }
}

/// Full-screen pad to draw a signature with a finger.
Future<Signature?> showSignaturePad(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _SignaturePad()));

class _SignaturePad extends StatefulWidget {
  const _SignaturePad();

  @override
  State<_SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  static const _inks = [Color(0xFF111111), Color(0xFF1A3FA8), Color(0xFFB0121B)];
  final _strokes = <List<Offset>>[];
  Color _ink = _inks[0];
  static const _width = 3.5;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.signPadTitle),
        actions: [
          for (final c in _inks)
            IconButton(
              icon: Icon(
                c == _ink ? Icons.radio_button_checked : Icons.circle,
                color: c == _inks[0] ? Colors.white : c,
              ),
              onPressed: () => setState(() => _ink = c),
            ),
          TextButton(onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear), child: Text(s.clear)),
          FilledButton(
            onPressed: _strokes.isEmpty
                ? null
                : () => Navigator.of(context).pop(Signature.trim(_strokes, _ink, _width)),
            child: Text(s.done),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: Colors.white,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
              onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
              child: CustomPaint(painter: _PadPainter(_strokes, _ink, _width), child: const SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter(this.strokes, this.ink, this.width);
  final List<List<Offset>> strokes;
  final Color ink;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.7;
    canvas.drawLine(
      Offset(24, y),
      Offset(size.width - 24, y),
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 1,
    );
    Signature(strokes, size, ink, width).paint(canvas, Offset.zero & size);
  }

  @override
  bool shouldRepaint(_PadPainter old) => true;
}

/// Bar with a hint and Cancel / confirm, shown over the page while a tool is
/// active.
class ToolBar extends StatelessWidget {
  const ToolBar({super.key, required this.hint, required this.confirm, required this.onCancel, this.onConfirm});

  final String hint;
  final String confirm;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.75),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(child: Text(hint, style: const TextStyle(fontSize: 13))),
            TextButton(onPressed: onCancel, child: Text(S.of(context).cancel)),
            FilledButton(onPressed: onConfirm, child: Text(confirm)),
          ],
        ),
      ),
    ),
  );
}

/// Lets the user move and resize the signature over the visible pages.
class PlaceSignature extends StatefulWidget {
  const PlaceSignature({
    super.key,
    required this.signature,
    required this.slots,
    required this.onDone,
    required this.onCancel,
  });

  final Signature signature;
  final List<PageSlot> slots;
  final void Function(PageSlot slot, Rect rect) onDone;
  final VoidCallback onCancel;

  @override
  State<PlaceSignature> createState() => _PlaceSignatureState();
}

class _PlaceSignatureState extends State<PlaceSignature> {
  late Rect _box;
  static const _handle = 28.0;

  @override
  void initState() {
    super.initState();
    final page = widget.slots.last.rect;
    final w = page.width * 0.4;
    final h = w * widget.signature.aspect;
    _box = Rect.fromLTWH(page.center.dx - w / 2, page.top + page.height * 0.72, w, h);
  }

  PageSlot? get _slot {
    for (final s in widget.slots) {
      if (s.rect.contains(_box.center)) return s;
    }
    return null;
  }

  void _move(Offset d) {
    setState(() => _box = _box.shift(d));
  }

  void _resize(Offset d) {
    final w = math.max(24.0, _box.width + d.dx);
    setState(() => _box = Rect.fromLTWH(_box.left, _box.top, w, w * widget.signature.aspect));
  }

  @override
  Widget build(BuildContext context) {
    final slot = _slot;
    return Stack(
      children: [
        // Swallow page-turn gestures while placing.
        const Positioned.fill(child: AbsorbPointer(child: SizedBox.expand())),
        Positioned.fromRect(
          rect: _box,
          child: GestureDetector(
            key: const ValueKey('signatureBox'),
            onPanUpdate: (d) => _move(d.delta),
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: Colors.lightBlueAccent, width: 1.5)),
              child: CustomPaint(painter: _SignaturePainter(widget.signature)),
            ),
          ),
        ),
        Positioned(
          left: _box.right - _handle / 2,
          top: _box.bottom - _handle / 2,
          width: _handle,
          height: _handle,
          child: GestureDetector(
            onPanUpdate: (d) => _resize(d.delta),
            child: const DecoratedBox(
              decoration: BoxDecoration(color: Colors.lightBlueAccent, shape: BoxShape.circle),
              child: Icon(Icons.open_in_full, size: 16, color: Colors.black),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ToolBar(
            hint: S.of(context).placeHint,
            confirm: S.of(context).done,
            onCancel: widget.onCancel,
            onConfirm: slot == null ? null : () => widget.onDone(slot, _box),
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.signature);
  final Signature signature;

  @override
  void paint(Canvas canvas, Size size) => signature.paint(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(_SignaturePainter old) => old.signature != signature;
}

/// Lets the user drag out a box to copy, then adjust it by its corners.
class SelectArea extends StatefulWidget {
  const SelectArea({super.key, required this.onDone, required this.onCancel, this.hint, this.confirm});

  final void Function(Rect area) onDone;
  final VoidCallback onCancel;

  /// Defaults: the copy tool's texts.
  final String? hint;
  final String? confirm;

  @override
  State<SelectArea> createState() => _SelectAreaState();
}

class _SelectAreaState extends State<SelectArea> {
  Rect? _area;
  Offset? _start;
  static const _handle = 28.0;

  void _corner(int i, Offset d) {
    final a = _area!;
    final isLeft = i == 0 || i == 3, isTop = i < 2;
    final l = a.left + (isLeft ? d.dx : 0), r = a.right + (isLeft ? 0 : d.dx);
    final t = a.top + (isTop ? d.dy : 0), b = a.bottom + (isTop ? 0 : d.dy);
    setState(() => _area = Rect.fromLTRB(math.min(l, r), math.min(t, b), math.max(l, r), math.max(t, b)));
  }

  @override
  Widget build(BuildContext context) {
    final a = _area;
    final corners = a == null ? const <Offset>[] : [a.topLeft, a.topRight, a.bottomRight, a.bottomLeft];
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => setState(() {
              _start = d.localPosition;
              _area = Rect.fromPoints(d.localPosition, d.localPosition);
            }),
            onPanUpdate: (d) => setState(() => _area = Rect.fromPoints(_start!, d.localPosition)),
            child: CustomPaint(painter: _ShadePainter(a)),
          ),
        ),
        for (var i = 0; i < corners.length; i++)
          Positioned(
            left: corners[i].dx - _handle / 2,
            top: corners[i].dy - _handle / 2,
            width: _handle,
            height: _handle,
            child: GestureDetector(
              onPanUpdate: (d) => _corner(i, d.delta),
              child: const DecoratedBox(
                decoration: BoxDecoration(color: Colors.lightBlueAccent, shape: BoxShape.circle),
              ),
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ToolBar(
            hint: widget.hint ?? S.of(context).selectAreaHint,
            confirm: widget.confirm ?? S.of(context).copy,
            onCancel: widget.onCancel,
            onConfirm: a == null || a.width < 8 || a.height < 8 ? null : () => widget.onDone(a),
          ),
        ),
      ],
    );
  }
}

class _ShadePainter extends CustomPainter {
  _ShadePainter(this.area);
  final Rect? area;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = Colors.black.withValues(alpha: 0.35);
    final a = area;
    if (a == null) {
      canvas.drawRect(Offset.zero & size, shade);
      return;
    }
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRect(a)),
      shade,
    );
    canvas.drawRect(
      a,
      Paint()
        ..color = Colors.lightBlueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_ShadePainter old) => old.area != area;
}
