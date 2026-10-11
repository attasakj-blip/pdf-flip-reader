import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';

import 'book_painter.dart';

/// Renders PDF pages to [ui.Image]s in the background and keeps a small
/// LRU cache of them. Notifies listeners whenever a new page is ready so the
/// book painter can repaint.
class PageCache extends ChangeNotifier implements PageImageSource {
  PageCache(this.document, {this.maxEntries = 14});

  final PdfDocument document;
  final int maxEntries;

  /// Target render width in physical pixels for one page.
  double renderWidth = 1200;

  final LinkedHashMap<int, ui.Image> _images = LinkedHashMap();
  final Set<int> _queued = {};
  Future<void> _chain = Future.value();
  bool _disposed = false;
  double _aspect = 1.414;

  int get pageCount => document.pagesCount;

  /// Height / width of the first page.
  double get aspect => _aspect;

  Future<void> init() async {
    final page = await document.getPage(1);
    if (page.width > 0) _aspect = page.height / page.width;
    await page.close();
  }

  @override
  ui.Image? image(int? index) {
    if (index == null) return null;
    final img = _images.remove(index);
    if (img != null) _images[index] = img; // mark as recently used
    return img;
  }

  /// Changes the render resolution; drops cached pages that are too small.
  void setRenderWidth(double width) {
    final w = width.clamp(400, 2400).toDouble();
    if ((w - renderWidth).abs() < 50) return;
    renderWidth = w;
    final small = _images.entries.where((e) => e.value.width < w * 0.8).map((e) => e.key).toList();
    for (final k in small) {
      _images.remove(k)?.dispose();
    }
  }

  /// Ask for these pages, in priority order.
  void request(Iterable<int?> indices) {
    for (final i in indices) {
      if (i == null || i < 0 || i >= pageCount) continue;
      if (_images.containsKey(i) || _queued.contains(i)) continue;
      _queued.add(i);
      _chain = _chain.then((_) => _render(i)).catchError((Object e) {
        debugPrint('render page $i failed: $e');
      });
    }
  }

  Future<void> _render(int index) async {
    if (_disposed) return;
    try {
      final page = await document.getPage(index + 1);
      final w = renderWidth;
      final h = w * (page.height / page.width);
      final rendered = await page.render(
        width: w,
        height: h,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      if (rendered == null || _disposed) return;
      final codec = await ui.instantiateImageCodec(rendered.bytes);
      final frame = await codec.getNextFrame();
      if (_disposed) {
        frame.image.dispose();
        return;
      }
      _images.remove(index)?.dispose();
      _images[index] = frame.image;
      while (_images.length > maxEntries) {
        final oldest = _images.keys.first;
        _images.remove(oldest)?.dispose();
      }
      notifyListeners();
    } finally {
      _queued.remove(index);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    document.close();
    super.dispose();
  }
}
