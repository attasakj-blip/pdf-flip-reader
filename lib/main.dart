import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ads.dart';
import 'flip_sounds.dart';
import 'l10n.dart';
import 'library_screen.dart';
import 'purchases.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _addLicenses();
  final settings = await Settings.load();
  final purchases = await Purchases.load();
  // A look or sound chosen while everything was free stays only with Gold.
  if (!purchases.flipStyleOk(settings.flipStyle)) settings.flipStyle = 0;
  if (!purchases.ambientOk(settings.ambientIndex)) settings.ambientIndex = -1;
  runApp(PdfFlipReaderApp(settings: settings, sounds: FlipSounds(settings)));
  initAds();
  purchases.start();
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
        navigatorKey: appNavigator,
        title: 'Pagelume',
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

/// Licences that Flutter does not collect by itself: the bundled Sarabun
/// font and, on Windows, the bundled Tesseract OCR program. Package
/// licences are listed automatically on the licences page.
void _addLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Sarabun font'], await rootBundle.loadString('assets/fonts/OFL.txt'));
    if (defaultTargetPlatform == TargetPlatform.windows) {
      yield const LicenseEntryWithLineBreaks(
        ['Tesseract OCR'],
        '''
Tesseract OCR (https://github.com/tesseract-ocr/tesseract), included as tesseract.exe.
Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
The full licence text is in tesseract\\LICENSE.txt next to Pagelume.exe.''',
      );
    }
  });
}
