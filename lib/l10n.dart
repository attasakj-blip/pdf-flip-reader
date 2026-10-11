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
  String get signDocument => _f('signDocument');
  String get signPadTitle => _f('signPadTitle');
  String get clear => _f('clear');
  String get done => _f('done');
  String get placeHint => _f('placeHint');
  String get saveTitle => _f('saveTitle');
  String get saveReplace => _f('saveReplace');
  String get saveReplaceHint => _f('saveReplaceHint');
  String get saveAsNew => _f('saveAsNew');
  String get saveAsNewHint => _f('saveAsNewHint');
  String get saveNewFolder => _f('saveNewFolder');
  String get saveNewFolderHint => _f('saveNewFolderHint');
  String get folderName => _f('folderName');
  String get fileName => _f('fileName');
  String get saveButton => _f('saveButton');
  String savedAs(String x) => _f('savedAs', {'x': x});
  String saveFailed(Object e) => _f('saveFailed', {'e': e});
  String get pickOriginal => _f('pickOriginal');
  String get copyPage => _f('copyPage');
  String get copyArea => _f('copyArea');
  String get selectAreaHint => _f('selectAreaHint');
  String get copy => _f('copy');
  String get copied => _f('copied');
  String get whichPage => _f('whichPage');
  String pageN(int n) => _f('pageN', {'n': n});
  String get deletePages => _f('deletePages');
  String get deleteTitle => _f('deleteTitle');
  String get deleteChoose => _f('deleteChoose');
  String deleteThisPage(int n) => _f('deleteThisPage', {'n': n});
  String get delete => _f('delete');
  String get keepOnePage => _f('keepOnePage');
  String get ambientMenu => _f('ambientMenu');
  String get ambientOff => _f('ambientOff');
  String get ambientHint => _f('ambientHint');
  String get working => _f('working');
  String ambientName(int i) => _f('a$i');
  String get translateArea => _f('translateArea');
  String get translateDoc => _f('translateDoc');
  String get selectTextHint => _f('selectTextHint');
  String get translateTo => _f('translateTo');
  String get translateButton => _f('translateButton');
  String get translationTitle => _f('translationTitle');
  String get translating => _f('translating');
  String pageProgress(int n, int total) => _f('pageProgress', {'n': n, 'total': total});
  String get downloadingModel => _f('downloadingModel');
  String get noText => _f('noText');
  String get copyText => _f('copyText');
  String get textCopied => _f('textCopied');
  String get placeTranslation => _f('placeTranslation');
  String get close => _f('close');
  String get choosePages => _f('choosePages');
  String pagesChosen(int n) => _f('pagesChosen', {'n': n});
  String translateFailed(Object e) => _f('translateFailed', {'e': e});
  String get unknownLanguage => _f('unknownLanguage');
  String get zoomHint => _f('zoomHint');
  String get unsavedTitle => _f('unsavedTitle');
  String get unsavedBody => _f('unsavedBody');
  String get saveChanges => _f('saveChanges');
  String get discardChanges => _f('discardChanges');
  String get saveMenu => _f('saveMenu');
  String get unsavedMark => _f('unsavedMark');
  String get markup => _f('markup');
  String get markHint => _f('markHint');
  String get toolPen => _f('toolPen');
  String get toolHighlighter => _f('toolHighlighter');
  String get toolLine => _f('toolLine');
  String get toolRect => _f('toolRect');
  String get toolCircle => _f('toolCircle');
  String get toolEllipse => _f('toolEllipse');
  String get color => _f('color');
  String get thickness => _f('thickness');
  String get lineSolid => _f('lineSolid');
  String get lineDashed => _f('lineDashed');
  String get undo => _f('undo');
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
