import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_flip_reader/book_painter.dart';

class FakePages extends ChangeNotifier implements PageImageSource {
  final Map<int, ui.Image> images = {};
  @override
  ui.Image? image(int? index) => index == null ? null : images[index];
}

Future<ui.Image> makePage(int n, Color color) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  const w = 300.0, h = 420.0;
  c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);
  c.drawRect(const Rect.fromLTWH(20, 20, w - 40, 60), Paint()..color = color);
  for (var i = 0; i < 12; i++) {
    c.drawRect(Rect.fromLTWH(20, 110.0 + i * 22, w - 40 - (i % 3) * 40, 10), Paint()..color = Colors.black54);
  }
  // Big arrow so orientation is visible.
  c.drawPath(
    Path()
      ..moveTo(150, 360)
      ..lineTo(110, 400)
      ..lineTo(190, 400)
      ..close(),
    Paint()..color = color,
  );
  return rec.endRecording().toImage(w.toInt(), h.toInt());
}

Future<void> save(BookPainter p, Size size, String name) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1E1B18));
  p.paint(c, size);
  final img = await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  Directory('build/flip_shots').createSync(recursive: true);
  File('build/flip_shots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('render page turn frames', (tester) async {
    await tester.runAsync(() async {
      final pages = FakePages();
      final colors = [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple];
      for (var i = 0; i < 5; i++) {
        pages.images[i] = await makePage(i, colors[i]);
      }
      const size = Size(900, 560);
      final two = BookLayout.compute(size, 1.4, true);
      const from = Spread(1, 2), to = Spread(3, 4);
      await save(BookPainter(cache: pages, layout: two, spread: from, flip: null), size, 'two_static');
      for (final t in [0.15, 0.4, 0.6, 0.85]) {
        final c0 = two.corner(true);
        final end = two.turnedCorner(true);
        final p = two.clampCorner(Offset.lerp(c0, end, t)! + Offset(0, -60 * (1 - (2 * t - 1).abs())), true);
        await save(
          BookPainter(
            cache: pages,
            layout: two,
            spread: from,
            flip: FlipState(from: from, to: to, corner: p, bottom: true),
          ),
          size,
          'two_flip_${(t * 100).round()}',
        );
      }
      final one = BookLayout.compute(const Size(420, 640), 1.4, false);
      final p = one.clampCorner(
        Offset.lerp(one.corner(false), one.turnedCorner(false), 0.3)! + const Offset(0, 50),
        false,
      );
      await save(
        BookPainter(
          cache: pages,
          layout: one,
          spread: const Spread(null, 1),
          flip: FlipState(from: const Spread(null, 1), to: const Spread(null, 2), corner: p, bottom: false),
        ),
        const Size(420, 640),
        'single_flip_top',
      );
    });
  });
}
