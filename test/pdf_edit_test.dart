import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_flip_reader/pdf_edit.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pd;
// ignore: implementation_imports
import 'package:pdfrx_engine/src/native/pdfium.dart' show pdfium;
import 'package:pdfrx_engine/pdfrx_engine.dart';

/// Three A4 pages; the third is turned a quarter clockwise by its /Rotate.
Future<String> samplePdf(Directory dir) async {
  final d = pw.Document();
  for (var i = 1; i <= 3; i++) {
    d.addPage(
      pw.Page(
        pageFormat: p.PdfPageFormat.a4,
        build: (_) => pw.Text('Page number $i', style: const pw.TextStyle(fontSize: 30)),
      ),
    );
  }
  final doc = await PdfDocument.openData(await d.save());
  await doc.useNativeDocumentHandle((h) {
    final page = pdfium.FPDF_LoadPage(pd.FPDF_DOCUMENT.fromAddress(h), 2);
    pdfium.FPDFPage_SetRotation(page, 1);
    pdfium.FPDF_ClosePage(page);
  });
  final path = '${dir.path}/sample.pdf';
  File(path).writeAsBytesSync(await doc.encodePdf());
  await doc.dispose();
  return path;
}

/// Half opaque red (left), half clear (right).
Uint8List redBox(int w, int h) {
  final rgba = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      rgba[i] = 220;
      rgba[i + 3] = x < w ~/ 2 ? 255 : 0;
    }
  }
  return rgba;
}

/// BGRA pixel at a fraction of the page as shown.
Future<List<int>> pixel(PdfPage page, double fx, double fy) async {
  final w = page.width.round(), h = page.height.round();
  final img = (await page.render(fullWidth: w.toDouble(), fullHeight: h.toDouble()))!;
  final i = ((fy * img.height).toInt() * img.width + (fx * img.width).toInt()) * 4;
  return img.pixels.sublist(i, i + 4);
}

bool isRed(List<int> bgra) => bgra[2] > 180 && bgra[0] < 60 && bgra[1] < 60;
bool isWhite(List<int> bgra) => bgra[0] > 200 && bgra[1] > 200 && bgra[2] > 200;

void main() {
  late Directory dir;
  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('edit');
    // `flutter test` builds PDFium for the host here but does not tell the
    // loader where it is.
    final lib = File('build/native_assets/linux/libpdfium.so');
    if (lib.existsSync()) Pdfrx.pdfiumModulePath = lib.absolute.path;
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('a signature lands where it was placed, on plain and rotated pages', () async {
    final src = await samplePdf(dir);
    final once = '${dir.path}/once.pdf', twice = '${dir.path}/twice.pdf';
    const rect = (left: 0.5, top: 0.7, width: 0.4, height: 0.1);
    await PdfEditor.stamp(src, once, 0, redBox(100, 50), 100, 50, rect);
    await PdfEditor.stamp(once, twice, 2, redBox(100, 50), 100, 50, rect);

    final doc = await PdfDocument.openFile(twice);
    expect(doc.pages.length, 3);
    for (final i in [0, 2]) {
      final page = doc.pages[i];
      expect(isRed(await pixel(page, 0.6, 0.75)), isTrue, reason: 'red half on page ${i + 1}');
      expect(isWhite(await pixel(page, 0.8, 0.75)), isTrue, reason: 'clear half on page ${i + 1}');
      expect(isWhite(await pixel(page, 0.6, 0.6)), isTrue, reason: 'above the box on page ${i + 1}');
      expect(isWhite(await pixel(page, 0.3, 0.75)), isTrue, reason: 'left of the box on page ${i + 1}');
    }
    expect(doc.pages[2].width, greaterThan(doc.pages[2].height)); // still turned
    expect((await doc.pages[0].loadText())!.fullText, contains('Page number 1'));
    expect(isWhite(await pixel(doc.pages[1], 0.6, 0.75)), isTrue);
    await doc.dispose();
  });

  test('deleting pages keeps the others and their text', () async {
    final src = await samplePdf(dir);
    final out = '${dir.path}/deleted.pdf';
    await PdfEditor.deletePages(src, out, [1]);
    final doc = await PdfDocument.openFile(out);
    expect(doc.pages.length, 2);
    expect((await doc.pages[0].loadText())!.fullText, contains('Page number 1'));
    expect((await doc.pages[1].loadText())!.fullText, contains('Page number 3'));
    await doc.dispose();

    final two = '${dir.path}/deleted2.pdf';
    await PdfEditor.deletePages(src, two, [0, 1]);
    final doc2 = await PdfDocument.openFile(two);
    expect(doc2.pages.length, 1);
    expect((await doc2.pages[0].loadText())!.fullText, contains('Page number 3'));
    await doc2.dispose();
  });

  test('text is grouped into paragraphs with their places on the page', () async {
    final d = pw.Document();
    d.addPage(
      pw.Page(
        pageFormat: p.PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('A Big Title', style: const pw.TextStyle(fontSize: 28)),
            pw.SizedBox(height: 30),
            pw.Paragraph(
              text:
                  'The first paragraph is long enough to wrap onto more than one line of the page, '
                  'so the reader must join its lines back into one piece of text before translating it.',
            ),
            pw.SizedBox(height: 20),
            pw.Paragraph(text: 'A second, short paragraph.'),
          ],
        ),
      ),
    );
    final path = '${dir.path}/para.pdf';
    File(path).writeAsBytesSync(await d.save());
    final blocks = await PdfEditor.textBlocks(path, 0);
    expect(blocks.map((b) => b.text).toList(), [
      'A Big Title',
      'The first paragraph is long enough to wrap onto more than one line of the page, '
          'so the reader must join its lines back into one piece of text before translating it.',
      'A second, short paragraph.',
    ]);
    // Title above the paragraphs, all near the left margin.
    expect(blocks[0].rect.top, lessThan(blocks[1].rect.top));
    expect(blocks[1].rect.top + blocks[1].rect.height, lessThan(blocks[2].rect.top));
    for (final b in blocks) {
      expect(b.rect.left, closeTo(0.1, 0.04));
    }
    expect(blocks[0].lineHeight, greaterThan(blocks[2].lineHeight));
    expect(blocks[1].rect.height, greaterThan(blocks[2].rect.height * 1.8));

    final inBox = await PdfEditor.textIn(path, 0, (left: 0, top: blocks[2].rect.top - 0.01, width: 1, height: 0.05));
    expect(inBox!.text, 'A second, short paragraph.');
  });

  test('text on a turned page is placed as shown', () async {
    final src = await samplePdf(dir);
    final blocks = await PdfEditor.textBlocks(src, 2);
    expect(blocks.single.text, 'Page number 3');
    // The page is turned a quarter clockwise, so its top-left text now sits
    // at the top right, running downwards.
    expect(blocks.single.rect.left, greaterThan(0.8));
    expect(blocks.single.rect.height, greaterThan(blocks.single.rect.width));
  });
}
