import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import 'edit_tools.dart' show PageSlot;
import 'native_files.dart';
import 'page_cache.dart';

/// Copies pages, or a part of what is on screen, to the clipboard as PNG.
class PageClipboard {
  PageClipboard(this.cache);

  final PageCache cache;

  /// Largest image side we put on the clipboard.
  static const maxSide = 2400.0;

  Future<Uint8List> _renderPng(int index, double width) => cache.exclusive((doc) async {
    final page = await doc.getPage(index + 1);
    try {
      final w = width.clamp(64, maxSide).toDouble();
      final img = await page.render(
        width: w,
        height: w * page.height / page.width,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      return img!.bytes;
    } finally {
      await page.close();
    }
  });

  /// A whole page at print-like sharpness.
  Future<Uint8List> pagePng(int index) async {
    final size = await cache.exclusive((doc) async {
      final page = await doc.getPage(index + 1);
      final s = (page.width, page.height);
      await page.close();
      return s;
    });
    // About 200 dpi, but never wider or taller than [maxSide].
    final scale = math.min(200 / 72, maxSide / math.max(size.$1, size.$2));
    return _renderPng(index, size.$1 * scale);
  }

  /// The part of the screen inside [area], with each page in [slots] drawn
  /// sharp underneath. Outside the pages is white.
  Future<Uint8List> areaPng(List<PageSlot> slots, ui.Rect area) async {
    final k = math.min(4.0, maxSide / math.max(area.width, area.height));
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, area.width * k, area.height * k),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    canvas.scale(k);
    canvas.translate(-area.left, -area.top);
    for (final s in slots) {
      if (!s.rect.overlaps(area)) continue;
      final codec = await ui.instantiateImageCodec(await _renderPng(s.page, s.rect.width * k));
      final img = (await codec.getNextFrame()).image;
      canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        s.rect,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      img.dispose();
    }
    final out = await rec.endRecording().toImage((area.width * k).round(), (area.height * k).round());
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    return data!.buffer.asUint8List();
  }

  /// Puts [png] on the clipboard.
  static Future<void> copy(Uint8List png) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/clipboard');
    await dir.create(recursive: true);
    for (final old in dir.listSync()) {
      try {
        old.deleteSync();
      } catch (_) {}
    }
    final file = File('${dir.path}/page_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(png, flush: true);
    await NativeFiles.copyImage(file.path);
  }
}
