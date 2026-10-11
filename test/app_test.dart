import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_flip_reader/flip_sounds.dart';
import 'package:pdf_flip_reader/goto_dialog.dart';
import 'package:pdf_flip_reader/l10n.dart';
import 'package:pdf_flip_reader/library_screen.dart';
import 'package:pdf_flip_reader/strings.g.dart';
import 'package:pdf_flip_reader/main.dart';
import 'package:pdf_flip_reader/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('folder label from Android links', () {
    expect(
      folderLabel(
        Uri.parse('content://com.android.externalstorage.documents/document/primary%3ADownload%2FBooks%2Fa.pdf'),
      ),
      'Download/Books',
    );
    expect(
      folderLabel(
        Uri.parse(
          'content://com.android.providers.downloads.documents/document/raw%3A%2Fstorage%2Femulated%2F0%2FDownload%2Fb.pdf',
        ),
      ),
      'Download',
    );
    expect(
      folderLabel(Uri.parse('content://com.android.providers.downloads.documents/document/msf%3A1234')),
      'Download',
    );
    expect(folderLabel(Uri.file('/storage/emulated/0/Documents/novels/c.pdf')), 'Documents/novels');
  });

  testWidgets('starts on the file chooser, single page by default, sound sheet lists 10 sounds', (tester) async {
    SharedPreferences.setMockInitialValues({
      'language': 'th',
      'recents': '[{"name":"book.pdf","folder":"Download/Books","path":"/nope/book.pdf","page":11}]',
    });
    final settings = await Settings.load();
    expect(settings.twoPage, isFalse);
    await tester.pumpWidget(PdfFlipReaderApp(settings: settings, sounds: FlipSounds(settings)));
    await tester.pumpAndSettle();
    expect(find.text('เลือกไฟล์ PDF จากเครื่อง'), findsOneWidget);
    expect(find.text('book.pdf'), findsOneWidget);
    expect(find.textContaining('โฟลเดอร์: Download/Books'), findsOneWidget);
    expect(find.textContaining('อ่านถึงหน้า 12'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.music_note));
    await tester.pumpAndSettle();
    expect(find.text('เสียงพลิกหน้ากระดาษ'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('10. ${'สมุดโน้ต'}'), 100, scrollable: find.byType(Scrollable).last);
    expect(find.text('10. ${'สมุดโน้ต'}'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(settings.soundOn, isFalse);
  });

  test('every language has every text', () {
    final keys = translations['en']!.keys.toSet();
    expect(translations.length, 23);
    for (final e in translations.entries) {
      expect(e.value.keys.toSet(), keys, reason: e.key);
      for (final v in e.value.values) {
        expect(v.trim(), isNotEmpty, reason: e.key);
      }
    }
  });

  test('phone locale maps to a supported language', () {
    expect(S.codeFor(const Locale('th', 'TH')), 'th');
    expect(S.codeFor(const Locale('zh', 'CN')), 'zh');
    expect(S.codeFor(const Locale('zh', 'TW')), 'zh_Hant');
    expect(S.codeFor(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')), 'zh_Hant');
    expect(S.codeFor(const Locale('sw')), 'en');
    expect(S.codeFor(const Locale('tl')), 'fil');
  });

  testWidgets('every language renders the menus without layout errors', (tester) async {
    for (final code in S.codes) {
      SharedPreferences.setMockInitialValues({
        'language': code,
        'recents': '[{"name":"book.pdf","folder":"Download","path":"/nope/book.pdf","page":3}]',
      });
      final settings = await Settings.load();
      await tester.pumpWidget(PdfFlipReaderApp(settings: settings, sounds: FlipSounds(settings)));
      await tester.pumpAndSettle();
      final s = S(code);
      expect(find.text(s.pickPdf), findsOneWidget, reason: code);
      expect(find.textContaining(s.readTo(4)), findsOneWidget, reason: code);

      await tester.tap(find.byIcon(Icons.music_note));
      await tester.pumpAndSettle();
      expect(find.text(s.soundSwitch), findsOneWidget, reason: code);
      Navigator.of(tester.element(find.text(s.soundSwitch))).pop();
      await tester.pumpAndSettle();

      showGoToPageDialog(tester.element(find.text(s.pickPdf)), 120);
      await tester.pumpAndSettle();
      expect(find.text(s.gotoTitle), findsOneWidget, reason: code);
      await tester.tap(find.text(s.cancel));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: code);
    }
  });

  testWidgets('language picker switches the app language', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'th'});
    final settings = await Settings.load();
    await tester.pumpWidget(PdfFlipReaderApp(settings: settings, sounds: FlipSounds(settings)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(languageNames['ja']!), 80, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text(languageNames['ja']!));
    await tester.pumpAndSettle();
    expect(settings.language, 'ja');
    expect(find.text(S('ja').pickPdf), findsOneWidget);
  });

  testWidgets('rotate button turns the whole app a quarter turn each tap', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    final settings = await Settings.load();
    await tester.pumpWidget(PdfFlipReaderApp(settings: settings, sounds: FlipSounds(settings)));
    await tester.pumpAndSettle();
    RotatedBox box() => tester.widget<RotatedBox>(find.byType(RotatedBox).first);
    expect(box().quarterTurns, 0);
    await tester.tap(find.byIcon(Icons.screen_rotation));
    await tester.pumpAndSettle();
    expect(box().quarterTurns, 1);
    await tester.tap(find.byIcon(Icons.screen_rotation));
    await tester.pumpAndSettle();
    expect(box().quarterTurns, 2);
    expect(find.text('Choose a PDF file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
