import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ads.dart';
import 'flip_sounds.dart';
import 'l10n.dart';
import 'library_screen.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  await initAds();
  runApp(PdfFlipReaderApp(settings: settings, sounds: FlipSounds(settings)));
}

class PdfFlipReaderApp extends StatelessWidget {
  const PdfFlipReaderApp({super.key, required this.settings, required this.sounds});

  final Settings settings;
  final FlipSounds sounds;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'PDF Flip Reader',
        locale: settings.language == null ? null : S.localeOf(settings.language!),
        supportedLocales: S.supportedLocales,
        localizationsDelegates: const [
          SDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        localeResolutionCallback: (locale, _) => S.localeOf(S.codeFor(locale ?? const Locale('en'))),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF8D6E63),
          brightness: Brightness.dark,
          useMaterial3: true,
          fontFamily: 'Sarabun',
        ),
        // "Rotate screen" turns the whole app, menus and dialogs included, so
        // it reads right on a projector or ceiling that shows it sideways.
        builder: (context, child) => RotatedBox(quarterTurns: settings.quarterTurns, child: child),
        home: LibraryScreen(settings: settings, sounds: sounds),
      ),
    );
  }
}
