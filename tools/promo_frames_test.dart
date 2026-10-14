// Renders page-turn frames for the promo video (transparent PNGs).
// Run: PAGES_DIR=<dir of page_XX.png> OUT_DIR=<out> flutter test tools/promo_frames_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_flip_reader/book_painter.dart';

class Pages extends ChangeNotifier implements PageImageSource {
  final Map<int, ui.Image> images = {};
  @override
  ui.Image? image(int? index) => index == null ? null : images[index];
}

final pagesDir = Platform.environment['PAGES_DIR']!;
final outDir = Platform.environment['OUT_DIR']!;
const size = Size(1600, 780);

Future<void> render(Pages pages, String seq, int n, Spread spread, FlipState? flip, {bool night = false}) async {
  final layout = BookLayout.compute(size, 1270 / 900, true);
  final rec = ui.PictureRecorder();
  BookPainter(cache: pages, layout: layout, spread: spread, flip: flip, night: night).paint(Canvas(rec), size);
  final img = await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  Directory('$outDir/$seq').createSync(recursive: true);
  File('$outDir/$seq/${n.toString().padLeft(4, '0')}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Holds [from] for [hold] frames, then turns to [to] over [turn] frames,
/// the corner lifting in an arc as a finger would carry it.
Future<int> turn(
  Pages pages,
  String seq,
  int n,
  Spread from,
  Spread to, {
  int hold = 20,
  int turn = 34,
  bool night = false,
}) async {
  final l = BookLayout.compute(size, 1270 / 900, true);
  for (var i = 0; i < hold; i++) {
    await render(pages, seq, n++, from, null, night: night);
  }
  for (var i = 1; i <= turn; i++) {
    final t = Curves.easeInOutCubic.transform(i / turn);
    final p = Offset.lerp(l.corner(true), l.turnedCorner(true), t)! + Offset(0, -110 * math.sin(math.pi * t));
    final flip = FlipState(from: from, to: to, corner: l.clampCorner(p, true), bottom: true);
    await render(pages, seq, n++, i == turn ? to : from, i == turn ? null : flip, night: night);
  }
  return n;
}

void main() {
  test('promo frames', () async {
    final pages = Pages();
    for (var i = 0; i < 7; i++) {
      final codec = await ui.instantiateImageCodec(
        File('$pagesDir/page_${i.toString().padLeft(2, '0')}.png').readAsBytesSync(),
      );
      pages.images[i] = (await codec.getNextFrame()).image;
    }
    var n = await turn(pages, 'day', 0, const Spread(1, 2), const Spread(3, 4), hold: 15);
    n = await turn(pages, 'day', n, const Spread(3, 4), const Spread(5, 6), hold: 18);
    for (var i = 0; i < 20; i++) {
      await render(pages, 'day', n++, const Spread(5, 6), null);
    }
    n = await turn(pages, 'night', 0, const Spread(3, 4), const Spread(5, 6), hold: 25, night: true);
    for (var i = 0; i < 30; i++) {
      await render(pages, 'night', n++, const Spread(5, 6), null, night: true);
    }
  }, timeout: Timeout.none);
}
