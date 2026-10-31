import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A PDF the reader has opened before. The app keeps its own copy at
/// [localPath] so it can reopen the book without asking for the file again.
class RecentBook {
  RecentBook({
    required this.name,
    required this.folder,
    required this.localPath,
    this.lastPage = 0,
    this.rtl,
    this.uri,
  });

  final String name;
  final String folder;
  final String localPath;
  int lastPage;

  /// The original file in the phone's storage (content:// link), when the
  /// app may write to it. Saving an edit can replace it.
  final String? uri;

  /// Turn pages right to left (Arabic books, manga). Null until the reader
  /// chooses; the app then follows the menu language's direction.
  bool? rtl;

  Map<String, Object> toJson() => {
    'name': name,
    'folder': folder,
    'path': localPath,
    'page': lastPage,
    'rtl': ?rtl,
    'uri': ?uri,
  };

  static RecentBook fromJson(Map<String, dynamic> j) => RecentBook(
    name: j['name'] as String,
    folder: (j['folder'] as String?) ?? '',
    localPath: j['path'] as String,
    lastPage: (j['page'] as int?) ?? 0,
    rtl: j['rtl'] as bool?,
    uri: j['uri'] as String?,
  );

  RecentBook copyWith({String? name, String? folder, String? localPath, String? uri}) => RecentBook(
    name: name ?? this.name,
    folder: folder ?? this.folder,
    localPath: localPath ?? this.localPath,
    lastPage: lastPage,
    rtl: rtl,
    uri: uri ?? this.uri,
  );
}

/// User preferences, saved on the phone between launches.
class Settings extends ChangeNotifier {
  Settings._(this._prefs);

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  bool get twoPage => _prefs.getBool('twoPage') ?? false; // single page by default
  set twoPage(bool v) => _set(() => _prefs.setBool('twoPage', v));

  bool get coverAlone => _prefs.getBool('coverAlone') ?? true;
  set coverAlone(bool v) => _set(() => _prefs.setBool('coverAlone', v));

  /// Night reading: dark, dimmed pages.
  bool get nightMode => _prefs.getBool('nightMode') ?? false;
  set nightMode(bool v) => _set(() => _prefs.setBool('nightMode', v));

  /// Reader rotation in quarter turns clockwise (0-3), for projectors or
  /// ceilings that show the picture sideways or upside down.
  int get quarterTurns => (_prefs.getInt('quarterTurns') ?? 0) % 4;
  set quarterTurns(int v) => _set(() => _prefs.setInt('quarterTurns', v % 4));

  /// Chosen UI language code, or null to follow the phone.
  String? get language {
    final v = _prefs.getString('language');
    return (v == null || v.isEmpty) ? null : v;
  }

  set language(String? v) => _set(() => _prefs.setString('language', v ?? ''));

  bool get soundOn => _prefs.getBool('soundOn') ?? true;
  set soundOn(bool v) => _set(() => _prefs.setBool('soundOn', v));

  /// Page-turn sound (0-2). A new key: the earlier ten sounds were replaced.
  int get soundIndex => (_prefs.getInt('flipSound2') ?? 0).clamp(0, 2);
  set soundIndex(int v) => _set(() => _prefs.setInt('flipSound2', v));

  /// Animate page turns (the curling page). Off: the next page just appears.
  bool get flipAnimation => _prefs.getBool('flipAnimation') ?? true;
  set flipAnimation(bool v) => _set(() => _prefs.setBool('flipAnimation', v));

  double get volume => _prefs.getDouble('volume') ?? 0.8;
  set volume(double v) => _set(() => _prefs.setDouble('volume', v));

  /// Background sound while reading: -1 off, else 0-8 (see ambient.dart).
  /// The earlier 30 sounds (key ambientIndex) were replaced by slow ones;
  /// whoever had the train keeps it.
  int get ambientIndex {
    final v = _prefs.getInt('ambient2');
    if (v != null) return v.clamp(-1, 8);
    return _prefs.getInt('ambientIndex') == 19 ? 0 : -1;
  }

  set ambientIndex(int v) => _set(() => _prefs.setInt('ambient2', v));

  double get ambientVolume => _prefs.getDouble('ambientVolume') ?? 0.4;
  set ambientVolume(double v) => _set(() => _prefs.setDouble('ambientVolume', v));

  /// Last language chosen for translating documents.
  String get translateTo => _prefs.getString('translateTo') ?? 'en';
  set translateTo(String v) => _set(() => _prefs.setString('translateTo', v));

  /// Languages for reading text from scans, as Tesseract codes ("tha+eng").
  String? get ocrLangs => _prefs.getString('ocrLangs');
  set ocrLangs(String? v) => _set(() => _prefs.setString('ocrLangs', v ?? ''));

  /// Whether the one-time pinch-to-zoom tip has been shown.
  bool get zoomTipShown => _prefs.getBool('zoomTipShown') ?? false;
  set zoomTipShown(bool v) => _set(() => _prefs.setBool('zoomTipShown', v));

  bool get edgeTipShown => _prefs.getBool('edgeTipShown') ?? false;
  set edgeTipShown(bool v) => _set(() => _prefs.setBool('edgeTipShown', v));

  List<RecentBook> get recents {
    final raw = _prefs.getString('recents');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => RecentBook.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  void saveRecents(List<RecentBook> list) =>
      _set(() => _prefs.setString('recents', jsonEncode(list.take(20).map((b) => b.toJson()).toList())));

  void _set(Future<bool> Function() write) {
    write();
    notifyListeners();
  }
}
