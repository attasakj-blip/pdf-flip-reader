import 'dart:io';

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

  testWidgets('whole-document translation allows at most 10 pages', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    ({List<int> pages, String to})? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [SDelegate()],
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => result = await askDocTranslation(ctx, settings, 14, List.generate(14, (i) => i)),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('10 of 10 pages chosen'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Translate'));
    await tester.pumpAndSettle();
    expect(result!.pages, List.generate(10, (i) => i));
    expect(result!.to, 'en');
  });
}
