// Renders real app screens to PNG for the Play Store listing.
// Run: PAGES_DIR=<dir of page_XX.png> OUT_DIR=<out> flutter test tools/store_screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_flip_reader/book_painter.dart';
import 'package:pdf_flip_reader/flip_sounds.dart';
import 'package:pdf_flip_reader/goto_dialog.dart';
import 'package:pdf_flip_reader/l10n.dart';
import 'package:pdf_flip_reader/library_screen.dart';
import 'package:pdf_flip_reader/settings.dart';
import 'package:pdf_flip_reader/sound_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Pages extends ChangeNotifier implements PageImageSource {
  final Map<int, ui.Image> images = {};
  @override
  ui.Image? image(int? index) => index == null ? null : images[index];
}

final pagesDir = Platform.environment['PAGES_DIR']!;
final outDir = Platform.environment['OUT_DIR']!;
const dpr = 2.5;
final lang = Platform.environment['STORE_LANG'] ?? 'th';
// Comma-separated font files used for the app UI in this language.
final appFonts =
    (Platform.environment['APP_FONTS'] ?? 'assets/fonts/Sarabun-Regular.ttf,assets/fonts/Sarabun-SemiBold.ttf').split(
      ',',
    );

Future<void> loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

ThemeData theme() => ThemeData(
  colorSchemeSeed: const Color(0xFF8D6E63),
  brightness: Brightness.dark,
  useMaterial3: true,
  fontFamily: 'AppFont',
);

final shotKey = GlobalKey();

Widget frame(Widget child, Size size) => RepaintBoundary(
  key: shotKey,
  child: MediaQuery(
    data: MediaQueryData(size: size, devicePixelRatio: dpr),
    child: child,
  ),
);

Future<void> capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final ro = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: dpr);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$outDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget book(Pages pages, Size size, Spread spread, FlipState? flip, {bool twoPage = true}) {
  final layout = BookLayout.compute(size, 1270 / 900, twoPage);
  return ColoredBox(
    color: const Color(0xFF1E1B18),
    child: CustomPaint(
      size: size,
      painter: BookPainter(cache: pages, layout: layout, spread: spread, flip: flip),
    ),
  );
}

FlipState flipAt(Size size, bool twoPage, Spread from, Spread to, double t, bool bottom, double lift) {
  final l = BookLayout.compute(size, 1270 / 900, twoPage);
  final p = Offset.lerp(l.corner(bottom), l.turnedCorner(bottom), t)! + Offset(0, lift);
  return FlipState(from: from, to: to, corner: l.clampCorner(p, bottom), bottom: bottom);
}

Future<void> setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
}

/// Example recent books, named in the screenshot's language.
const sampleBooks = <String, List<String>>{
  'th': [
    'ห้องสมุดของยายจันทร์.pdf',
    'Download/นิทาน',
    'คู่มือการใช้งานโปรเจกเตอร์.pdf',
    'Documents',
    'หนังสือภาพดวงดาวและท้องฟ้า.pdf',
    'Download/หนังสือเด็ก',
  ],
  'en': [
    "Grandma's Library.pdf",
    'Download/Stories',
    'Projector user guide.pdf',
    'Documents',
    'Stars and Sky picture book.pdf',
    'Download/Kids books',
  ],
  'de': [
    'Omas Bibliothek.pdf',
    'Download/Geschichten',
    'Beamer-Bedienungsanleitung.pdf',
    'Documents',
    'Bilderbuch Sterne und Himmel.pdf',
    'Download/Kinderbücher',
  ],
  'fr': [
    'La bibliothèque de grand-mère.pdf',
    'Download/Histoires',
    'Guide du vidéoprojecteur.pdf',
    'Documents',
    'Les étoiles et le ciel.pdf',
    'Download/Livres enfants',
  ],
  'it': [
    'La biblioteca della nonna.pdf',
    'Download/Racconti',
    'Manuale del proiettore.pdf',
    'Documents',
    'Stelle e cielo, libro illustrato.pdf',
    'Download/Libri bambini',
  ],
  'es': [
    'La biblioteca de la abuela.pdf',
    'Download/Cuentos',
    'Manual del proyector.pdf',
    'Documents',
    'Estrellas y cielo, libro ilustrado.pdf',
    'Download/Libros infantiles',
  ],
  'ja': ['おばあちゃんの図書館.pdf', 'Download/物語', 'プロジェクター取扱説明書.pdf', 'Documents', '星と空の絵本.pdf', 'Download/子どもの本'],
  'zh_Hant': ['奶奶的圖書館.pdf', 'Download/故事', '投影機使用手冊.pdf', 'Documents', '星星與天空繪本.pdf', 'Download/童書'],
  'ar': [
    'مكتبة الجدة.pdf',
    'Download/قصص',
    'دليل جهاز العرض.pdf',
    'Documents',
    'كتاب النجوم والسماء المصور.pdf',
    'Download/كتب الأطفال',
  ],
};

String recentsJson() {
  final b = sampleBooks[lang] ?? sampleBooks['en']!;
  String e(String x) => x.replaceAll('"', '\\"');
  return '[{"name":"${e(b[0])}","folder":"${e(b[1])}","path":"/x/a.pdf","page":4},'
      '{"name":"${e(b[2])}","folder":"${e(b[3])}","path":"/x/b.pdf","page":11},'
      '{"name":"${e(b[4])}","folder":"${e(b[5])}","path":"/x/c.pdf","page":27}]';
}

void main() {
  testWidgets('store screens', (tester) async {
    final pages = Pages();
    await tester.runAsync(() async {
      final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/usr/local/flutter';
      await loadFont('AppFont', appFonts);
      await loadFont('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
      for (var i = 0; i < 7; i++) {
        final codec = await ui.instantiateImageCodec(
          File('$pagesDir/page_${i.toString().padLeft(2, '0')}.png').readAsBytesSync(),
        );
        pages.images[i] = (await codec.getNextFrame()).image;
      }
    });

    // 1. Two-page spread, mid turn (landscape, as on a projector).
    const land = Size(960, 432);
    await setSize(tester, land);
    await tester.pumpWidget(
      frame(
        book(
          pages,
          land,
          const Spread(1, 2),
          flipAt(land, true, const Spread(1, 2), const Spread(3, 4), 0.42, true, -40),
        ),
        land,
      ),
    );
    await capture(tester, 'shot1_two_page_flip');

    // 2. Single page portrait, turning from the top corner.
    const port = Size(432, 960);
    await setSize(tester, port);
    await tester.pumpWidget(
      frame(
        book(
          pages,
          port,
          const Spread(null, 3),
          flipAt(port, false, const Spread(null, 3), const Spread(null, 4), 0.28, false, 70),
          twoPage: false,
        ),
        port,
      ),
    );
    await capture(tester, 'shot2_single_page_flip');

    // 3. Go to page dialog over the spread.
    await setSize(tester, land);
    await tester.pumpWidget(
      frame(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme(),
          locale: S.localeOf(lang),
          supportedLocales: S.supportedLocales,
          localizationsDelegates: const [
            SDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (ctx) {
              return Scaffold(
                body: GestureDetector(
                  onTap: () => showGoToPageDialog(ctx, 6),
                  child: book(pages, land, const Spread(3, 4), null),
                ),
              );
            },
          ),
        ),
        land,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await capture(tester, 'shot3_goto_page');
    await tester.tap(find.text(S(lang).cancel));
    await tester.pumpAndSettle();

    // 4. File chooser with recent books.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({'soundOn': true, 'soundIndex': 2, 'recents': recentsJson()});
    final settings = await Settings.load();
    final sounds = FlipSounds(settings);
    await setSize(tester, port);
    await tester.pumpWidget(
      frame(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme(),
          locale: S.localeOf(lang),
          supportedLocales: S.supportedLocales,
          localizationsDelegates: const [
            SDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: LibraryScreen(settings: settings, sounds: sounds),
        ),
        port,
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'shot4_file_chooser');

    // 5. Sound picker.
    await tester.tap(find.byIcon(Icons.music_note));
    await tester.pumpAndSettle();
    await capture(tester, 'shot5_sounds');
    showSoundSettings; // keep import used
  });
}
