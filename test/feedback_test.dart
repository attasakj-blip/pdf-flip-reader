import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_flip_reader/l10n.dart';
import 'package:pdf_flip_reader/ocr.dart';
import 'package:pdf_flip_reader/ocr_dialog.dart';
import 'package:pdf_flip_reader/translate_flow.dart';

void main() {
  test('Thai text from old PDF fonts is repaired before translating', () {
    // Private-use tone marks and a split sara am, as old Thai fonts store them.
    expect(cleanText('กา'), 'ก้า');
    expect(cleanText('นํา'), 'นำ');
    expect(cleanText('a​b   c'), 'ab c');
  });

  test('text read from a scan is tidied: Thai spaces dropped, lines joined', () {
    expect(Ocr.tidy('สวัสดี ครับ\nวันนี้ อากาศดี'), 'สวัสดีครับวันนี้อากาศดี');
    expect(Ocr.tidy('Hello\nworld\n\nNew para-\ngraph'), 'Hello world\n\nNew paragraph');
    expect(Ocr.defaultsFor('th'), ['th', 'en']);
    expect(Ocr.defaultsFor('en'), ['en']);
    expect(Ocr.defaultsFor('sw'), ['en']);
  });

  testWidgets('scan result: text can be fixed, copied and sent to translate', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    Object? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        localizationsDelegates: const [
          SDelegate(),
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showDialog<OcrResult>(
                context: context,
                builder: (_) => const OcrResultDialog(text: 'Helo world', langs: ['th', 'en']),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final s = S('en');
    expect(find.text(s.ocrTitle), findsOneWidget);
    expect(find.textContaining('ไทย + English'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Hello world');
    await tester.tap(find.text(s.copyText));
    await tester.pump();
    expect(copied, ['Hello world']);
    await tester.tap(find.text(s.translateButton));
    await tester.pumpAndSettle();
    expect(result, (langs: null, translate: 'Hello world'));
  });
}
