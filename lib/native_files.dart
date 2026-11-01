import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import 'desktop.dart';

/// A file in the phone's storage, as the system file picker hands it out.
typedef DocRef = ({String uri, String name});

/// Android side: see MainActivity.kt; iOS side: AppDelegate.swift; Windows
/// side: [_Win] below (plain file paths, as file: URIs). Every call throws
/// [MissingPluginException] elsewhere (tests, other platforms).
class NativeFiles {
  static const _ch = MethodChannel('pdf_flip_reader/files');

  /// Lets the user pick a PDF and copies it into [dir]. The app keeps
  /// permission to write the original, so edits can replace it later.
  static Future<({String uri, String name, String path})?> openPdf(String dir) async {
    if (Desktop.active) return _Win.openPdf(dir);
    final m = await _ch.invokeMapMethod<String, String>('openPdf', {'dir': dir});
    if (m == null) return null;
    return (uri: m['uri']!, name: m['name']!, path: m['path']!);
  }

  /// System "save as" screen: the user picks the folder (and can make a new
  /// one there) and the file name.
  static Future<DocRef?> createPdf(String suggestedName) =>
      Desktop.active ? _Win.createPdf(suggestedName) : _ref('createPdf', {'name': suggestedName});

  /// The user picks a place; a new folder [folder] is made there with [name]
  /// inside it.
  static Future<DocRef?> createInNewFolder(String folder, String name) => Desktop.active
      ? _Win.createInNewFolder(folder, name)
      : _ref('createInNewFolder', {'folder': folder, 'name': name});

  static Future<DocRef?> _ref(String method, Map<String, String> args) async {
    final m = await _ch.invokeMapMethod<String, String>(method, args);
    if (m == null) return null;
    return (uri: m['uri']!, name: m['name']!);
  }

  /// Keeps the middle of the screen's side edges for the app's edge menus
  /// (instead of Android's "back" swipe) while [on].
  static Future<void> edgeSwipes(bool on) async {
    if (Desktop.active) return;
    try {
      await _ch.invokeMethod('edgeSwipes', on);
    } on MissingPluginException {
      // Not on Android.
    }
  }

  /// Whether the app may still write to [uri].
  static Future<bool> canWrite(String uri) async {
    if (Desktop.active) return _Win.canWrite(uri);
    return await _ch.invokeMethod<bool>('canWrite', {'uri': uri}) ?? false;
  }

  /// Replaces the contents of [uri] with the file at [path].
  static Future<void> write(String uri, String path) async {
    if (Desktop.active) {
      await File(path).copy(Uri.parse(uri).toFilePath());
      return;
    }
    await _ch.invokeMethod('write', {'uri': uri, 'path': path});
  }

  /// Puts the image file at [path] (inside the app's cache/clipboard folder)
  /// on the clipboard.
  static Future<void> copyImage(String path) =>
      Desktop.active ? Desktop.copyImage(path) : _ch.invokeMethod('copyImage', {'path': path});

  /// Opens the system share sheet for the image file at [path].
  /// On Windows: shows it in File Explorer instead.
  static Future<void> shareImage(String path) =>
      Desktop.active ? Desktop.showInFolder(path) : _ch.invokeMethod('shareImage', {'path': path});

  /// Shows [text] in Google Translate: the app if it is installed, else the
  /// website. [to] is an app language code.
  static Future<void> openTranslate(String text, String to) {
    final code = switch (to) {
      'fil' => 'tl',
      'zh' => 'zh-CN',
      'zh_Hant' => 'zh-TW',
      _ => to,
    };
    if (Desktop.active) {
      return Desktop.openUrl(translateUrl(text, code));
    }
    return _ch.invokeMethod('openTranslate', {'text': text, 'to': code});
  }

  /// The Google Translate website with [text] filled in. Very long text is
  /// cut, since a web address has a length limit.
  static String translateUrl(String text, String to) {
    final t = text.length > 4000 ? text.substring(0, 4000) : text;
    return Uri.https('translate.google.com', '/', {'sl': 'auto', 'tl': to, 'text': t, 'op': 'translate'}).toString();
  }
}

/// Windows: the books are ordinary files, so the "URI" kept for writing back
/// is the file's own path.
class _Win {
  static Future<({String uri, String name, String path})?> openPdf(String dir) async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
    if (files.isEmpty || files.first.path == null) return null;
    final src = File(files.first.path!);
    final name = src.uri.pathSegments.last;
    final copy = '$dir/${DateTime.now().millisecondsSinceEpoch}_$name';
    await src.copy(copy);
    return (uri: Uri.file(src.path).toString(), name: name, path: copy);
  }

  static Future<DocRef?> createPdf(String suggestedName) async {
    final uri = await FilePicker.saveFile(
      fileName: suggestedName,
      bytes: Uint8List(0),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (uri == null || uri.scheme != 'file') return null;
    var path = uri.toFilePath();
    if (!path.toLowerCase().endsWith('.pdf')) path = '$path.pdf';
    return (uri: Uri.file(path).toString(), name: File(path).uri.pathSegments.last);
  }

  static Future<DocRef?> createInNewFolder(String folder, String name) async {
    final parent = await FilePicker.getDirectoryPath();
    if (parent == null) return null;
    final dir = Directory('$parent${Platform.pathSeparator}$folder');
    await dir.create(recursive: true);
    final path = '${dir.path}${Platform.pathSeparator}$name';
    return (uri: Uri.file(path).toString(), name: name);
  }

  static Future<bool> canWrite(String uri) async {
    try {
      final f = File(Uri.parse(uri).toFilePath());
      if (!await f.exists()) return false;
      final raf = await f.open(mode: FileMode.append);
      await raf.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}
