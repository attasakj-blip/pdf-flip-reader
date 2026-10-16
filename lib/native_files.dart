import 'package:flutter/services.dart';

/// A file in the phone's storage, as the system file picker hands it out.
typedef DocRef = ({String uri, String name});

/// Android side: see MainActivity.kt; iOS side: AppDelegate.swift. Every
/// call throws [MissingPluginException] elsewhere (tests, other platforms).
class NativeFiles {
  static const _ch = MethodChannel('pdf_flip_reader/files');

  /// Lets the user pick a PDF and copies it into [dir]. The app keeps
  /// permission to write the original, so edits can replace it later.
  static Future<({String uri, String name, String path})?> openPdf(String dir) async {
    final m = await _ch.invokeMapMethod<String, String>('openPdf', {'dir': dir});
    if (m == null) return null;
    return (uri: m['uri']!, name: m['name']!, path: m['path']!);
  }

  /// System "save as" screen: the user picks the folder (and can make a new
  /// one there) and the file name.
  static Future<DocRef?> createPdf(String suggestedName) => _ref('createPdf', {'name': suggestedName});

  /// The user picks a place; a new folder [folder] is made there with [name]
  /// inside it.
  static Future<DocRef?> createInNewFolder(String folder, String name) =>
      _ref('createInNewFolder', {'folder': folder, 'name': name});

  static Future<DocRef?> _ref(String method, Map<String, String> args) async {
    final m = await _ch.invokeMapMethod<String, String>(method, args);
    if (m == null) return null;
    return (uri: m['uri']!, name: m['name']!);
  }

  /// Keeps the middle of the screen's side edges for the app's edge menus
  /// (instead of Android's "back" swipe) while [on].
  static Future<void> edgeSwipes(bool on) async {
    try {
      await _ch.invokeMethod('edgeSwipes', on);
    } on MissingPluginException {
      // Not on Android.
    }
  }

  /// Whether the app may still write to [uri].
  static Future<bool> canWrite(String uri) async => await _ch.invokeMethod<bool>('canWrite', {'uri': uri}) ?? false;

  /// Replaces the contents of [uri] with the file at [path].
  static Future<void> write(String uri, String path) => _ch.invokeMethod('write', {'uri': uri, 'path': path});

  /// Puts the image file at [path] (inside the app's cache/clipboard folder)
  /// on the clipboard.
  static Future<void> copyImage(String path) => _ch.invokeMethod('copyImage', {'path': path});
}
