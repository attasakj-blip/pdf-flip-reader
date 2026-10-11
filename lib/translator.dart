import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Translates text. The app uses Google ML Kit, which runs on the phone:
/// nothing leaves the device, and each language pack is downloaded once.
abstract class TextTranslator {
  /// The language of [text] as one of [DocTranslator.languages], or null.
  Future<String?> detect(String text);

  /// Gets the language packs ready; [onDownload] is called if one has to be
  /// downloaded first.
  Future<void> prepare(String from, String to, {void Function()? onDownload});

  Future<String> translate(String text, String from, String to);
}

class DocTranslator {
  /// Languages offered, as the app's language codes (see strings.g.dart).
  /// Traditional Chinese is left out: ML Kit writes Simplified only.
  static const languages = [
    'en', 'th', 'zh', 'ja', 'ko', 'fr', 'de', 'it', 'es', 'pt', 'ru', //
    'uk', 'pl', 'nl', 'tr', 'ar', 'hi', 'bn', 'id', 'ms', 'vi', 'fil',
  ];

  /// The translator in use; tests swap in a fake.
  static TextTranslator instance = MlKitTranslator();
}

class MlKitTranslator implements TextTranslator {
  static String _ml(String code) => code == 'fil' ? 'tl' : code;
  static String _app(String code) => code == 'tl' || code == 'fil' ? 'fil' : code.split('-').first;

  static TranslateLanguage _lang(String code) => BCP47Code.fromRawValue(_ml(code)) ?? TranslateLanguage.english;

  final _models = OnDeviceTranslatorModelManager();
  final _translators = <String, OnDeviceTranslator>{};

  @override
  Future<String?> detect(String text) async {
    final id = LanguageIdentifier(confidenceThreshold: 0.4);
    try {
      final code = await id.identifyLanguage(text.length > 2000 ? text.substring(0, 2000) : text);
      if (code == id.undeterminedLanguageCode) return null;
      final app = _app(code);
      return DocTranslator.languages.contains(app) || BCP47Code.fromRawValue(code) != null ? app : null;
    } finally {
      await id.close();
    }
  }

  @override
  Future<void> prepare(String from, String to, {void Function()? onDownload}) async {
    for (final code in {from, to}) {
      final model = _lang(code).bcpCode;
      if (await _models.isModelDownloaded(model)) continue;
      onDownload?.call();
      final ok = await _models.downloadModel(model, isWifiRequired: false);
      if (!ok) throw StateError('language pack $code');
    }
  }

  @override
  Future<String> translate(String text, String from, String to) async {
    if (from == to || text.trim().isEmpty) return text;
    final t = _translators.putIfAbsent(
      '$from>$to',
      () => OnDeviceTranslator(sourceLanguage: _lang(from), targetLanguage: _lang(to)),
    );
    return t.translateText(text);
  }
}
