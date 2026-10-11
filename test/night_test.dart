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

Future<ui.Image> solid(Color c) async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 10, 10), Paint()..color = c);
  return rec.endRecording().toImage(10, 10);
}

Future<List<int>> paintedPixel(BookPainter p, Size size, Offset at) async {
  final rec = ui.PictureRecorder();
  p.paint(Canvas(rec), size);
  final img = await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
  final d = (await img.toByteData())!;
  final i = (at.dy.toInt() * img.width + at.dx.toInt()) * 4;
  return [d.getUint8(i), d.getUint8(i + 1), d.getUint8(i + 2)];
}

void main() {
  test('night mode turns white paper dark and black text light', () async {
    final pages = FakePages();
    pages.images[0] = await solid(Colors.white);
    pages.images[1] = await solid(Colors.black);
    const size = Size(400, 300);
    final l = BookLayout.compute(size, 1.4, true);
    BookPainter painter(bool night) =>
        BookPainter(cache: pages, layout: l, spread: const Spread(0, 1), flip: null, night: night);
    final paper = await paintedPixel(painter(true), size, l.left.center);
    final text = await paintedPixel(painter(true), size, l.right.center);
    expect(paper.every((v) => v < 60), isTrue, reason: '$paper');
    expect(text.every((v) => v > 150 && v < 230), isTrue, reason: '$text');
    final day = await paintedPixel(painter(false), size, l.left.center);
    expect(day.every((v) => v > 240), isTrue);
  });

  testWidgets('render night mode turn with a real sample page', (tester) async {
    final dir = Directory('/home/claude/storekit/pages_en');
    if (!dir.existsSync()) return;
    await tester.runAsync(() async {
      final pages = FakePages();
      for (var i = 0; i < 4; i++) {
        final codec = await ui.instantiateImageCodec(File('${dir.path}/page_0$i.png').readAsBytesSync());
        pages.images[i] = (await codec.getNextFrame()).image;
      }
      const size = Size(1000, 640);
      final l = BookLayout.compute(size, pages.images[0]!.height / pages.images[0]!.width, true);
      final p = Offset.lerp(l.corner(true), l.turnedCorner(true), 0.35)! + const Offset(0, -80);
      final painter = BookPainter(
        cache: pages,
        layout: l,
        spread: const Spread(0, 1),
        flip: FlipState(from: const Spread(0, 1), to: const Spread(2, 3), corner: l.clampCorner(p, true), bottom: true),
        night: true,
      );
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1E1B18));
      painter.paint(c, size);
      final img = await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/flip_shots').createSync(recursive: true);
      File('build/flip_shots/night_turn.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
