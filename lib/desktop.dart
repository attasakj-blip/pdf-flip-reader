import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Things that differ on the Windows desktop version.
class Desktop {
  /// True in the Windows version.
  static final bool active = Platform.isWindows;

  /// Where the app keeps its own copies of books. On a phone this is the
  /// app's private documents folder; on Windows that would be the user's
  /// own Documents folder, so use the app's data folder instead.
  static Future<Directory> booksDir() async {
    final base = Platform.isWindows ? await getApplicationSupportDirectory() : await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/books');
    await dir.create(recursive: true);
    return dir;
  }

  /// Closes the app. Phones go back to the home screen; Windows closes the
  /// window (SystemNavigator does nothing there).
  static void quit() {
    if (Platform.isWindows) exit(0);
    SystemNavigator.pop();
  }

  /// Opens [url] in the default web browser.
  static Future<void> openUrl(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      throw StateError('could not open $url');
    }
  }

  /// Puts the picture in [path] on the Windows clipboard, so it can be
  /// pasted into Word, Paint, LINE and so on.
  static Future<void> copyImage(String path) async {
    // PowerShell's clipboard needs the single-threaded mode (-STA).
    final quoted = path.replaceAll("'", "''");
    final script = [
      'Add-Type -AssemblyName System.Windows.Forms, System.Drawing',
      "\$img = [System.Drawing.Image]::FromFile('$quoted')",
      '[System.Windows.Forms.Clipboard]::SetImage(\$img)',
      '\$img.Dispose()',
    ].join('; ');
    final r = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-STA',
      '-WindowStyle',
      'Hidden',
      '-EncodedCommand',
      base64.encode(_utf16le(script)),
    ]);
    if (r.exitCode != 0) throw ProcessException('powershell', const [], '${r.stderr}', r.exitCode);
  }

  /// Shows the file in File Explorer, selected, so it can be dragged or
  /// sent from there ("share" on a phone).
  static Future<void> showInFolder(String path) =>
      Process.run('explorer.exe', ['/select,${path.replaceAll('/', r'\')}']);

  static List<int> _utf16le(String s) {
    final out = <int>[];
    for (final c in s.codeUnits) {
      out
        ..add(c & 0xff)
        ..add(c >> 8);
    }
    return out;
  }
}
