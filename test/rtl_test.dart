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

/// A page with a marker in its top-left corner, so mirroring shows.
Future<ui.Image> makePage(Color color) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, 300, 420), Paint()..color = Colors.white);
  c.drawRect(const Rect.fromLTWH(10, 10, 80, 80), Paint()..color = color);
  return rec.endRecording().toImage(300, 420);
}

void main() {
  test('mirrored pages are flipped left to right', () async {
    final pages = FakePages();
    pages.images[0] = await makePage(Colors.red);
    final m = MirroredPages(pages);
    final img = m.image(0)!;
    final data = (await img.toByteData())!;
    int redAt(int x, int y) => data.getUint8((y * img.width + x) * 4);
    expect(redAt(300 - 40, 40), greaterThan(200)); // marker now top-right
    expect(m.image(0), same(img)); // cached
    m.dispose();
  });

  testWidgets('drags inside a horizontal flip arrive mirrored, velocity too', (tester) async {
    Offset? start, last;
    double? vx;
    await tester.pumpWidget(
      Transform.flip(
        flipX: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => start = d.localPosition,
          onHorizontalDragUpdate: (d) => last = d.localPosition,
          onHorizontalDragEnd: (d) => vx = d.velocity.pixelsPerSecond.dx,
          child: const SizedBox.expand(),
        ),
      ),
    );
    // Finger moves right on screen = next page in a right-to-left book.
    await tester.flingFrom(const Offset(200, 300), const Offset(300, 0), 1500);
    expect(last!.dx, lessThan(start!.dx));
    expect(vx, lessThan(-250));
  });

  testWidgets('render right-to-left turn frame', (tester) async {
    await tester.runAsync(() async {
      final pages = FakePages();
      final colors = [Colors.red, Colors.blue, Colors.green, Colors.orange];
      for (var i = 0; i < 4; i++) {
        pages.images[i] = await makePage(colors[i]);
      }
      const size = Size(900, 560);
      final l = BookLayout.compute(size, 1.4, true);
      final p = Offset.lerp(l.corner(true), l.turnedCorner(true), 0.4)!;
      final painter = BookPainter(
        cache: MirroredPages(pages),
        layout: l,
        spread: const Spread(0, 1),
        flip: FlipState(from: const Spread(0, 1), to: const Spread(2, 3), corner: l.clampCorner(p, true), bottom: true),
      );
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)
        ..translate(size.width, 0)
        ..scale(-1, 1);
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1E1B18));
      painter.paint(c, size);
      final img = await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/flip_shots').createSync(recursive: true);
      File('build/flip_shots/rtl_turn.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
