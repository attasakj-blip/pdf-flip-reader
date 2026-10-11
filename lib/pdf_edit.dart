import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pd;
// ignore: implementation_imports
import 'package:pdfrx_engine/src/native/pdfium.dart' show pdfium;
import 'package:pdfrx_engine/pdfrx_engine.dart';

/// A rectangle on a page, as fractions of the page size (origin top-left).
typedef PageRect = ({double left, double top, double width, double height});

/// An image to draw on a page; see [PdfEditor.stampAll].
typedef Stamp = ({int page, Uint8List rgba, int w, int h, PageRect rect});

/// A run of text on a page (a paragraph or a heading) and where it sits,
/// as fractions of the page as shown. [lineHeight] is in points. [turns]
/// is how far the text is turned on screen (quarter turns clockwise), from
/// the page's own rotation.
typedef TextBlock = ({String text, PageRect rect, double lineHeight, int turns});

/// A page as shown on screen, as BGRA pixels at one pixel per point.
typedef PagePixels = ({Uint8List bgra, int width, int height});

/// One character of page text for highlighting: its box as the page is
/// shown, the line it sits on (counted in reading order), and whether it is
/// a space or line break.
typedef PageChar = ({PageRect box, int line, bool blank});

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

  /// Draws all [stamps] in one go and writes the result to [dest].
  /// With [replaceText], the page's own text under each stamp is removed
  /// first (for translations: the old words would otherwise still turn up
  /// when searching or copying).
  static Future<void> stampAll(String src, String dest, List<Stamp> stamps, {bool replaceText = false}) =>
      _edit(src, dest, (doc) {
        for (final s in stamps) {
          _stamp(doc, s.page, s.rgba, s.w, s.h, s.rect, replaceText: replaceText);
        }
      });

  /// Paragraphs of text on page [pageIndex] (0-based), in reading order.
  /// Empty for scanned pages, which carry pictures of text only.
  static Future<List<TextBlock>> textBlocks(String path, int pageIndex) =>
      _read(path, pageIndex, (page, text) => _shown(page, groupBlocks(_chars(page, text))));

  /// The text inside [area] on page [pageIndex], and the box around it.
  static Future<TextBlock?> textIn(String path, int pageIndex, PageRect area) => _read(path, pageIndex, (page, text) {
    final turns = page.rotation.index;
    final inside = _chars(page, text).where((c) {
      final r = _turn((left: c.l, top: c.t, width: c.r - c.l, height: c.b - c.t), turns);
      final cx = r.left + r.width / 2, cy = r.top + r.height / 2;
      return cx >= area.left && cx <= area.left + area.width && cy >= area.top && cy <= area.top + area.height;
    }).toList();
    final blocks = _shown(page, groupBlocks(inside));
    if (blocks.isEmpty) return null;
    var r = blocks.first.rect;
    for (final b in blocks.skip(1)) {
      r = _union(r, b.rect);
    }
    final lh = blocks.map((b) => b.lineHeight).reduce((a, b) => a + b) / blocks.length;
    return (text: blocks.map((b) => b.text).join('\n\n'), rect: r, lineHeight: lh, turns: turns);
  });

  /// Every character on page [pageIndex] in reading order, for snapping a
  /// highlight to the text. Empty for scanned pages.
  static Future<List<PageChar>> pageChars(String path, int pageIndex) => _read(path, pageIndex, (page, text) {
    final turns = page.rotation.index;
    return [for (final c in lineChars(_chars(page, text))) (box: _turn(c.box, turns), line: c.line, blank: c.blank)];
  });

  /// Renders page [pageIndex] as shown (rotation applied), white paper.
  static Future<PagePixels> render(String path, int pageIndex) async {
    await _init();
    final doc = await PdfDocument.openFile(path);
    try {
      final page = doc.pages[pageIndex];
      final w = page.width.round(), h = page.height.round();
      final img = (await page.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), backgroundColor: 0xFFFFFFFF))!;
      final px = Uint8List.fromList(img.pixels);
      img.dispose();
      return (bgra: px, width: img.width, height: img.height);
    } finally {
      await doc.dispose();
    }
  }

  static Future<T> _read<T>(String path, int pageIndex, T Function(PdfPage page, PdfPageRawText? text) task) async {
    await _init();
    final doc = await PdfDocument.openFile(path);
    try {
      final page = doc.pages[pageIndex];
      return task(page, await page.loadText());
    } finally {
      await doc.dispose();
    }
  }

  /// Characters with their boxes as fractions of the page before its own
  /// rotation (so text runs left to right), origin top-left.
  static List<TextChar> _chars(PdfPage page, PdfPageRawText? text) {
    if (text == null) return const [];
    final odd = page.rotation.index.isOdd;
    final w = odd ? page.height : page.width, h = odd ? page.width : page.height;
    final out = <TextChar>[];
    for (var i = 0; i < text.fullText.length && i < text.charRects.length; i++) {
      final r = text.charRects[i];
      out.add(TextChar(text.fullText[i], r.left / w, (h - r.top) / h, r.right / w, (h - r.bottom) / h, h));
    }
    return out;
  }

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

  static void _stamp(
    int handle,
    int pageIndex,
    Uint8List rgba,
    int w,
    int h,
    PageRect rect, {
    bool replaceText = false,
  }) {
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
      if (replaceText) _removeText(page, m);
      pdfium.FPDFPage_InsertObject(page, obj);
      pdfium.FPDFPage_GenerateContent(page);
    } finally {
      malloc.free(buf);
      malloc.free(pages);
      pdfium.FPDF_ClosePage(page);
    }
  }

  /// Removes top-level text objects whose middle lies inside the image
  /// placed by matrix [m].
  static void _removeText(pd.FPDF_PAGE page, List<double> m) {
    final xs = [m[4], m[0] + m[4], m[2] + m[4], m[0] + m[2] + m[4]];
    final ys = [m[5], m[1] + m[5], m[3] + m[5], m[1] + m[3] + m[5]];
    final l = xs.reduce(math.min), r = xs.reduce(math.max), b = ys.reduce(math.min), t = ys.reduce(math.max);
    final box = malloc<Float>(4);
    try {
      for (var i = pdfium.FPDFPage_CountObjects(page) - 1; i >= 0; i--) {
        final o = pdfium.FPDFPage_GetObject(page, i);
        if (pdfium.FPDFPageObj_GetType(o) != pd.FPDF_PAGEOBJ_TEXT) continue;
        if (pdfium.FPDFPageObj_GetBounds(o, box, box + 1, box + 2, box + 3) == 0) continue;
        final cx = (box[0] + box[2]) / 2, cy = (box[1] + box[3]) / 2;
        if (cx >= l && cx <= r && cy >= b && cy <= t && pdfium.FPDFPage_RemoveObject(page, o) != 0) {
          pdfium.FPDFPageObj_Destroy(o);
        }
      }
    } finally {
      malloc.free(box);
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

  /// Blocks found on the unrotated page, placed as the page is shown.
  static List<TextBlock> _shown(PdfPage page, List<TextBlock> blocks) {
    final turns = page.rotation.index;
    return [for (final b in blocks) (text: b.text, rect: _turn(b.rect, turns), lineHeight: b.lineHeight, turns: turns)];
  }
}

/// Where a rectangle on the unrotated page appears once the page is turned
/// [turns] quarter turns clockwise.
PageRect _turn(PageRect r, int turns) => switch (turns & 3) {
  1 => (left: 1 - r.top - r.height, top: r.left, width: r.height, height: r.width),
  2 => (left: 1 - r.left - r.width, top: 1 - r.top - r.height, width: r.width, height: r.height),
  3 => (left: r.top, top: 1 - r.left - r.width, width: r.height, height: r.width),
  _ => r,
};

PageRect _union(PageRect a, PageRect b) {
  final l = a.left < b.left ? a.left : b.left, t = a.top < b.top ? a.top : b.top;
  final r = (a.left + a.width) > (b.left + b.width) ? a.left + a.width : b.left + b.width;
  final bt = (a.top + a.height) > (b.top + b.height) ? a.top + a.height : b.top + b.height;
  return (left: l, top: t, width: r - l, height: bt - t);
}

/// One character of page text; the box is in fractions of the page as
/// shown (origin top-left). [pageHeight] is in points.
class TextChar {
  TextChar(this.ch, this.l, this.t, this.r, this.b, this.pageHeight);
  final String ch;
  final double l, t, r, b;
  final double pageHeight;

  bool get blank => ch.trim().isEmpty || r <= l || b <= t;
}

/// Scripts written without spaces between words.
bool _noSpaces(String ch) {
  if (ch.isEmpty) return false;
  final c = ch.codeUnitAt(0);
  return (c >= 0x0E00 && c <= 0x0E7F) || // Thai
      (c >= 0x0E80 && c <= 0x0EFF) || // Lao
      (c >= 0x3000 && c <= 0x9FFF) || // CJK, kana
      (c >= 0xAC00 && c <= 0xD7AF) || // Hangul (spaced, but safe to join tightly)
      (c >= 0xFF00 && c <= 0xFFEF);
}

/// Groups characters into lines, then lines into paragraphs: a line joins
/// the paragraph above when it is close below it, about the same size, and
/// overlaps it sideways.
/// Numbers the lines of [chars] (on the unrotated page, in text order): a
/// new line starts when a character sits clearly above or below the line so
/// far, or jumps far back to the left.
List<PageChar> lineChars(List<TextChar> chars) {
  final out = <PageChar>[];
  var line = -1;
  double? cy, lh, right;
  for (final c in chars) {
    final box = (left: c.l, top: c.t, width: c.r - c.l, height: c.b - c.t);
    if (c.blank) {
      out.add((box: box, line: math.max(0, line), blank: true));
      continue;
    }
    final y = (c.t + c.b) / 2, h = c.b - c.t;
    final newLine = cy == null || (y - cy).abs() > 0.6 * math.max(h, lh!) || c.l < right! - 2 * math.max(h, lh);
    if (newLine) {
      line++;
      cy = y;
      lh = h;
    }
    right = c.r;
    out.add((box: box, line: line, blank: false));
  }
  return out;
}

List<TextBlock> groupBlocks(List<TextChar> chars) {
  // Lines.
  final lines = <List<TextChar>>[];
  var cur = <TextChar>[];
  double? lineMid, lineH;
  for (final c in chars) {
    if (c.ch == '\n' || c.ch == '\r') {
      if (cur.isNotEmpty) lines.add(cur);
      cur = [];
      lineMid = null;
      continue;
    }
    if (c.blank) {
      if (cur.isNotEmpty) cur.add(c);
      continue;
    }
    final mid = (c.t + c.b) / 2, hh = c.b - c.t;
    final last = cur.lastWhere((x) => !x.blank, orElse: () => c);
    final newLine = lineMid != null && ((mid - lineMid).abs() > 0.6 * lineH! || c.l < last.l - 3 * lineH);
    if (newLine) {
      lines.add(cur);
      cur = [];
      lineMid = null;
    }
    cur.add(c);
    if (lineMid == null) {
      lineMid = mid;
      lineH = hh;
    } else {
      lineH = lineH! > hh ? lineH : hh;
    }
  }
  if (cur.isNotEmpty) lines.add(cur);

  final boxes = <({String text, double l, double t, double r, double b, double h})>[];
  for (final line in lines) {
    final ink = line.where((c) => !c.blank).toList();
    if (ink.isEmpty) continue;
    var l = ink.first.l, t = ink.first.t, r = ink.first.r, b = ink.first.b;
    for (final c in ink) {
      if (c.l < l) l = c.l;
      if (c.t < t) t = c.t;
      if (c.r > r) r = c.r;
      if (c.b > b) b = c.b;
    }
    final text = line.map((c) => c.ch).join().replaceAll(RegExp(r'\s+'), ' ').trim();
    boxes.add((text: text, l: l, t: t, r: r, b: b, h: b - t));
  }

  final blocks = <TextBlock>[];
  String? text;
  late double bl, bt, br, bb, sumH;
  var n = 0;
  void flush() {
    if (text == null) return;
    final pageH = chars.first.pageHeight;
    blocks.add((
      text: text!,
      rect: (left: bl, top: bt, width: br - bl, height: bb - bt),
      lineHeight: sumH / n * pageH,
      turns: 0,
    ));
    text = null;
  }

  for (final x in boxes) {
    final joins =
        text != null &&
        x.t - bb < 0.9 * (sumH / n) &&
        x.t > bt &&
        (x.h - sumH / n).abs() < 0.4 * (sumH / n) &&
        x.l < br &&
        x.r > bl;
    if (!joins) {
      flush();
      text = x.text;
      bl = x.l;
      bt = x.t;
      br = x.r;
      bb = x.b;
      sumH = x.h;
      n = 1;
      continue;
    }
    final prev = text!;
    if (prev.endsWith('-') && !prev.endsWith(' -')) {
      text = prev.substring(0, prev.length - 1) + x.text;
    } else if (_noSpaces(prev[prev.length - 1]) || _noSpaces(x.text[0])) {
      text = prev + x.text;
    } else {
      text = '$prev ${x.text}';
    }
    if (x.l < bl) bl = x.l;
    if (x.r > br) br = x.r;
    bb = x.b;
    sumH += x.h;
    n++;
  }
  flush();
  return blocks;
}
