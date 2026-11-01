import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_flip_reader/l10n.dart';
import 'package:pdf_flip_reader/pdf_edit.dart';
import 'package:pdf_flip_reader/settings.dart';
import 'package:pdf_flip_reader/translate_flow.dart';
import 'package:pdf_flip_reader/translator.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTranslator implements TextTranslator {
  final prepared = <String>[];
  @override
  Future<String?> detect(String text) async => 'en';
  @override
  Future<void> prepare(String from, String to, {void Function()? onDownload}) async => prepared.add('$from>$to');
  @override
  Future<String> translate(String text, String from, String to) async => 'XX ${text.toUpperCase()}';
}

void main() {
  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('tr');
    final lib = File('build/native_assets/linux/libpdfium.so');
    if (lib.existsSync()) Pdfrx.pdfiumModulePath = lib.absolute.path;
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('translated text replaces the old words on cream paper, the rest stays', () async {
    final d = pw.Document();
    d.addPage(
      pw.Page(
        pageFormat: p.PdfPageFormat.a4,
        build: (_) => pw.Container(
          color: const p.PdfColor(1, 0.95, 0.8), // cream
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Hello reader', style: const pw.TextStyle(fontSize: 26)),
              pw.SizedBox(height: 30),
              pw.Paragraph(text: 'Keep this line as it is.'),
              pw.SizedBox(height: 200),
              pw.Text('7'),
            ],
          ),
        ),
      ),
    );
    final src = '${dir.path}/src.pdf', out = '${dir.path}/out.pdf';
    File(src).writeAsBytesSync(await d.save());

    final blocks = translatable(await PdfEditor.textBlocks(src, 0));
    expect(blocks.map((b) => b.text), ['Hello reader', 'Keep this line as it is.']); // '7' has no letters
    final title = blocks.first;
    final stamps = await translatedStamps(src, 0, [title], ['XX HELLO READER']);
    await PdfEditor.stampAll(src, out, stamps, replaceText: true);

    final doc = await PdfDocument.openFile(out);
    final text = (await doc.pages[0].loadText())!.fullText;
    expect(text, isNot(contains('Hello reader')));
    expect(text, contains('Keep this line as it is.'));
    final page = doc.pages[0];
    final img = (await page.render(fullWidth: page.width, fullHeight: page.height))!;
    // Inside the old title box: cream paper and some dark ink.
    var cream = 0, ink = 0;
    final r = title.rect;
    for (var y = (r.top * img.height).ceil(); y < ((r.top + r.height) * img.height).floor(); y++) {
      for (var x = (r.left * img.width).ceil(); x < ((r.left + r.width) * img.width).floor(); x++) {
        final i = (y * img.width + x) * 4;
        final b = img.pixels[i], g = img.pixels[i + 1], rr = img.pixels[i + 2];
        if (rr > 240 && g > 230 && b > 190 && b < 220) cream++;
        if (rr < 90 && g < 90 && b < 90) ink++;
      }
    }
    expect(cream, greaterThan(ink));
    expect(ink, greaterThan(30));
    await doc.dispose();
  });

  test('translated copy keeps chosen pages, pictures and tables, without the old text', () async {
    final d = pw.Document();
    for (var n = 1; n <= 3; n++) {
      d.addPage(
        pw.Page(
          pageFormat: p.PdfPageFormat.a4,
          build: (_) => pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Chapter $n', style: const pw.TextStyle(fontSize: 28)),
                pw.SizedBox(height: 12),
                pw.Paragraph(
                  text:
                      'This is the first paragraph of page $n. It has a few sentences so that it wraps '
                      'over several lines, like the text in a real book does.',
                ),
                pw.Container(width: 200, height: 80, color: const p.PdfColor(0.1, 0.5, 0.9)), // a picture
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  data: [
                    ['Name', 'Amount'],
                    ['Apples', '12'],
                    ['Pears', '7'],
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Paragraph(text: 'A closing note under the table.'),
              ],
            ),
          ),
        ),
      );
    }
    final src = '${dir.path}/book.pdf', out = '${dir.path}/book_th.pdf';
    File(src).writeAsBytesSync(await d.save());

    final stamps = <Stamp>[];
    for (final page in [0, 2]) {
      final blocks = translatable(await PdfEditor.textBlocks(src, page));
      expect(blocks, isNotEmpty);
      final texts = [for (final b in blocks) 'XX ${b.text.toUpperCase()} (A LONGER TRANSLATION)'];
      stamps.addAll(await translatedPageStamps(src, page, blocks, texts));
    }
    await PdfEditor.translatedCopy(src, out, [0, 2], stamps);

    final doc = await PdfDocument.openFile(out);
    expect(doc.pages.length, 2);
    for (final page in doc.pages) {
      final text = (await page.loadText())?.fullText ?? '';
      expect(text, isNot(contains('paragraph')));
      final img = (await page.render(fullWidth: page.width, fullHeight: page.height))!;
      var blue = 0, ink = 0;
      for (var i = 0; i < img.pixels.length; i += 4) {
        final b = img.pixels[i], g = img.pixels[i + 1], r = img.pixels[i + 2];
        if (b > 200 && r < 60 && g > 100 && g < 150) blue++;
        if (r < 80 && g < 80 && b < 80) ink++;
      }
      expect(blue, greaterThan(10000)); // the picture is still there
      expect(ink, greaterThan(500)); // translated text drawn
      final shots = Directory('build/translate_shots')..createSync(recursive: true);
      final png = await _png(img.pixels, img.width, img.height);
      File('${shots.path}/page_${page.pageNumber}.png').writeAsBytesSync(png);
      img.dispose();
    }
    await doc.dispose();
  });

  test('translateAll prepares the language packs once and keeps order', () async {
    final fake = FakeTranslator();
    DocTranslator.instance = fake;
    final out = await translateAll(['a', 'b'], 'th', message: ValueNotifier(''), s: S('en'));
    expect(out, ['XX A', 'XX B']);
    expect(fake.prepared, ['en>th']);
  });

  test('text is fitted to its box', () {
    final big = fitText('A fairly long sentence that must wrap.', const Size(300, 200), Colors.black, start: 80);
    expect(big.width, lessThanOrEqualTo(300.5));
    expect(big.height, lessThanOrEqualTo(200));
    final small = fitText('A fairly long sentence that must wrap.', const Size(300, 40), Colors.black, start: 80);
    expect(small.height, lessThanOrEqualTo(40));
    expect(small.text!.style!.fontSize!, lessThan(big.text!.style!.fontSize!));
  });

  testWidgets('language picker has a Translate button, even for the language already chosen', (tester) async {
    SharedPreferences.setMockInitialValues({'translateTo': 'th'});
    final settings = await Settings.load();
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [SDelegate()],
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => result = await pickTargetLanguage(ctx, settings),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ไทย')); // already chosen: nothing should happen yet
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Translate'));
    await tester.pumpAndSettle();
    expect(result, 'th');
  });

  testWidgets('whole-document translation allows at most 20 pages', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    ({List<int> pages, String to})? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [SDelegate()],
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => result = await askDocTranslation(ctx, settings, 24, List.generate(24, (i) => i)),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('20 of 20 pages chosen'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Translate'));
    await tester.pumpAndSettle();
    expect(result!.pages, List.generate(20, (i) => i));
    expect(result!.to, 'en');
  });
}

Future<Uint8List> _png(Uint8List bgra, int w, int h) async {
  final rgba = Uint8List(bgra.length);
  for (var i = 0; i < bgra.length; i += 4) {
    rgba[i] = bgra[i + 2];
    rgba[i + 1] = bgra[i + 1];
    rgba[i + 2] = bgra[i];
    rgba[i + 3] = 255;
  }
  final buf = await ui.ImmutableBuffer.fromUint8List(rgba);
  final desc = ui.ImageDescriptor.raw(buf, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
  final frame = await (await desc.instantiateCodec()).getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
