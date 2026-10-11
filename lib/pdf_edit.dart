import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pd;
// ignore: implementation_imports
import 'package:pdfrx_engine/src/native/pdfium.dart' show pdfium;
import 'package:pdfrx_engine/pdfrx_engine.dart';

/// A rectangle on a page, as fractions of the page size (origin top-left).
typedef PageRect = ({double left, double top, double width, double height});

/// Editing (signatures, page deletion) goes through PDFium, which keeps the
/// rest of the file (text, links, fonts) as it was. Viewing still uses pdfx.
class PdfEditor {
  static bool _ready = false;

  /// A writable folder for PDFium's scratch files (the app's cache on
  /// Android, where the system temp folder is not writable).
  static String? cacheDir;

  static Future<void> _init() async {
    if (_ready) return;
    await pdfrxInitialize(tmpPath: cacheDir ?? Directory.systemTemp.path);
    _ready = true;
  }

  /// Draws an RGBA image (straight alpha) on page [pageIndex] (0-based) of
  /// [src] inside [rect], and writes the result to [dest].
  static Future<void> stamp(String src, String dest, int pageIndex, Uint8List rgba, int w, int h, PageRect rect) =>
      _edit(src, dest, (doc) => _stamp(doc, pageIndex, rgba, w, h, rect));

  /// Writes [src] without the pages at [indices] (0-based) to [dest].
  static Future<void> deletePages(String src, String dest, List<int> indices) => _edit(src, dest, (handle) {
    final document = pd.FPDF_DOCUMENT.fromAddress(handle);
    final sorted = indices.toSet().toList()..sort((a, b) => b.compareTo(a));
    for (final i in sorted) {
      pdfium.FPDFPage_Delete(document, i);
    }
  });

  static Future<void> _edit(String src, String dest, void Function(int handle) task) async {
    await _init();
    final doc = await PdfDocument.openFile(src);
    try {
      await doc.useNativeDocumentHandle(task);
      // The page list of [doc] is stale now; encode it once and drop it.
      final bytes = await doc.encodePdf();
      await File(dest).writeAsBytes(bytes, flush: true);
    } finally {
      await doc.dispose();
    }
  }

  static void _stamp(int handle, int pageIndex, Uint8List rgba, int w, int h, PageRect rect) {
    final document = pd.FPDF_DOCUMENT.fromAddress(handle);
    final page = pdfium.FPDF_LoadPage(document, pageIndex);
    if (page == nullptr) throw StateError('page $pageIndex not found');
    final buf = malloc<Uint8>(w * h * 4);
    final pages = malloc<pd.FPDF_PAGE>(1)..value = page;
    try {
      final dst = buf.asTypedList(w * h * 4);
      for (var i = 0; i < w * h * 4; i += 4) {
        dst[i] = rgba[i + 2];
        dst[i + 1] = rgba[i + 1];
        dst[i + 2] = rgba[i];
        dst[i + 3] = rgba[i + 3];
      }
      final bitmap = pdfium.FPDFBitmap_CreateEx(w, h, pd.FPDFBitmap_BGRA, buf.cast(), w * 4);
      final obj = pdfium.FPDFPageObj_NewImageObj(document);
      pdfium.FPDFImageObj_SetBitmap(pages, 1, obj, bitmap);
      pdfium.FPDFBitmap_Destroy(bitmap);
      final m = _placement(
        rect,
        rotation: pdfium.FPDFPage_GetRotation(page),
        width: pdfium.FPDF_GetPageWidthF(page),
        height: pdfium.FPDF_GetPageHeightF(page),
        box: _box(page),
      );
      pdfium.FPDFImageObj_SetMatrix(obj, m[0], m[1], m[2], m[3], m[4], m[5]);
      pdfium.FPDFPage_InsertObject(page, obj);
      pdfium.FPDFPage_GenerateContent(page);
    } finally {
      malloc.free(buf);
      malloc.free(pages);
      pdfium.FPDF_ClosePage(page);
    }
  }

  /// Lower-left corner of the visible page area, in PDF points.
  static (double, double) _box(pd.FPDF_PAGE page) {
    final r = malloc<pd.FS_RECTF>();
    try {
      if (pdfium.FPDF_GetPageBoundingBox(page, r) != 0) return (r.ref.left, r.ref.bottom);
      return (0, 0);
    } finally {
      malloc.free(r);
    }
  }

  /// The image matrix (a, b, c, d, e, f) that puts an image upright at [rect]
  /// as the reader sees the page. [width] and [height] are the page size as
  /// shown (after the page's own [rotation], in quarter turns clockwise).
  static List<double> _placement(
    PageRect rect, {
    required int rotation,
    required double width,
    required double height,
    (double, double) box = (0, 0),
  }) {
    final odd = rotation.isOdd;
    final uw = odd ? height : width, uh = odd ? width : height; // unrotated page size
    // Shown position (points, origin top-left) -> PDF user space.
    (double, double) user(double dx, double dy) {
      final (x, y) = switch (rotation % 4) {
        1 => (dy, dx),
        2 => (uw - dx, dy),
        3 => (uw - dy, uh - dx),
        _ => (dx, uh - dy),
      };
      return (x + box.$1, y + box.$2);
    }

    final l = rect.left * width, t = rect.top * height;
    final w = rect.width * width, h = rect.height * height;
    // Image space is the unit square with its origin at the image's
    // bottom-left corner.
    final (ex, ey) = user(l, t + h);
    final (sx, sy) = user(l + w, t + h);
    final (tx, ty) = user(l, t);
    return [sx - ex, sy - ey, tx - ex, ty - ey, ex, ey];
  }
}
