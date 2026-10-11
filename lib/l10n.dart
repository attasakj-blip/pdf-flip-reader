import 'package:flutter/material.dart';

import 'strings.g.dart';

/// UI text in the reader's language. Texts live in strings.g.dart,
/// generated from tools/translations.py.
class S {
  S(this.code) : _t = translations[code] ?? translations['en']!;

  final String code;
  final Map<String, String> _t;

  static S of(BuildContext context) => Localizations.of<S>(context, S) ?? S('en');

  /// Language codes in the order shown in the picker.
  static List<String> get codes => languageNames.keys.toList();

  static Locale localeOf(String code) {
    final parts = code.split('_');
    return parts.length == 2 ? Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1]) : Locale(code);
  }

  static List<Locale> get supportedLocales => codes.map(localeOf).toList();

  /// Picks the closest language we have for a phone locale.
  static String codeFor(Locale locale) {
    final lang = locale.languageCode;
    if (lang == 'zh') {
      final traditional = locale.scriptCode == 'Hant' || const {'TW', 'HK', 'MO'}.contains(locale.countryCode);
      return traditional ? 'zh_Hant' : 'zh';
    }
    if (lang == 'tl') return 'fil';
    if (lang == 'in') return 'id';
    return translations.containsKey(lang) ? lang : 'en';
  }

  String _f(String key, [Map<String, Object> args = const {}]) {
    var s = _t[key] ?? translations['en']![key] ?? key;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  String get pickPdf => _f('pickPdf');
  String get pickHint => _f('pickHint');
  String get recent => _f('recent');
  String get unknownFolder => _f('unknownFolder');
  String folder(String x) => _f('folder', {'x': x});
  String readTo(int n) => _f('readTo', {'n': n});
  String get removeFromList => _f('removeFromList');
  String get fileMissing => _f('fileMissing');
  String openFailed(Object e) => _f('openFailed', {'e': e});
  String get flipSoundMenu => _f('flipSoundMenu');
  String get exitApp => _f('exitApp');
  String get language => _f('language');
  String get systemLanguage => _f('systemLanguage');
  String pageLabel(String range, int total) => _f('pageLabel', {'range': range, 'total': total});
  String get backToFiles => _f('backToFiles');
  String get singlePage => _f('singlePage');
  String get twoPage => _f('twoPage');
  String get goToPageMenu => _f('goToPageMenu');
  String get coverAlone => _f('coverAlone');
  String get rtlPages => _f('rtlPages');
  String get nightMode => _f('nightMode');
  String get rotateScreen => _f('rotateScreen');
  String get otherFile => _f('otherFile');
  String get soundSwitch => _f('soundSwitch');
  String get volume => _f('volume');
  String get preview => _f('preview');
  String get gotoTitle => _f('gotoTitle');
  String gotoError(int total) => _f('gotoError', {'total': total});
  String get cancel => _f('cancel');
  String get go => _f('go');
  String soundName(int i) => _f('s${i + 1}');
}

class SDelegate extends LocalizationsDelegate<S> {
  const SDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<S> load(Locale locale) async => S(S.codeFor(locale));

  @override
  bool shouldReload(SDelegate old) => false;
}

/// Language picker: "phone language" plus every supported language,
/// each written in its own script.
Future<String?> showLanguagePicker(BuildContext context, String? current) {
  final s = S.of(context);
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(s.language),
      children: [
        RadioGroup<String>(
          groupValue: current ?? '',
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(value: '', title: Text(s.systemLanguage)),
              for (final code in S.codes) RadioListTile<String>(value: code, title: Text(languageNames[code]!)),
            ],
          ),
        ),
      ],
    ),
  );
}
