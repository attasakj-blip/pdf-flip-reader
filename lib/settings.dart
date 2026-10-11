import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A PDF the reader has opened before. The app keeps its own copy at
/// [localPath] so it can reopen the book without asking for the file again.
class RecentBook {
  RecentBook({required this.name, required this.folder, required this.localPath, this.lastPage = 0, this.rtl});

  final String name;
  final String folder;
  final String localPath;
  int lastPage;

  /// Turn pages right to left (Arabic books, manga). Null until the reader
  /// chooses; the app then follows the menu language's direction.
  bool? rtl;

  Map<String, Object> toJson() => {'name': name, 'folder': folder, 'path': localPath, 'page': lastPage, 'rtl': ?rtl};

  static RecentBook fromJson(Map<String, dynamic> j) => RecentBook(
    name: j['name'] as String,
    folder: (j['folder'] as String?) ?? '',
    localPath: j['path'] as String,
    lastPage: (j['page'] as int?) ?? 0,
    rtl: j['rtl'] as bool?,
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

  int get soundIndex => (_prefs.getInt('soundIndex') ?? 0).clamp(0, 9);
  set soundIndex(int v) => _set(() => _prefs.setInt('soundIndex', v));

  double get volume => _prefs.getDouble('volume') ?? 0.8;
  set volume(double v) => _set(() => _prefs.setDouble('volume', v));

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
