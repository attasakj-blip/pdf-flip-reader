import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Reads text from a picture (a scanned page). Android uses Tesseract
/// (on the phone; each language's data is downloaded once, about 1-8 MB);
/// iOS uses Apple's Vision; Windows runs the Tesseract program that comes
/// with the app (in the "tesseract" folder next to Pagelume.exe). Nothing
/// is sent anywhere.
abstract class TextReader {
  /// Text in the PNG [png]. [langs] are app language codes, main one first.
  Future<String> read(Uint8List png, List<String> langs, {void Function()? onDownload});
}

class Ocr {
  /// Languages offered, as the app's language codes, with Tesseract's names.
  static const tesseract = {
    'th': 'tha', 'en': 'eng', 'zh': 'chi_sim', 'zh_Hant': 'chi_tra', 'ja': 'jpn', 'ko': 'kor', 'fr': 'fra', //
    'de': 'deu', 'it': 'ita', 'es': 'spa', 'pt': 'por', 'ru': 'rus', 'uk': 'ukr', 'pl': 'pol', 'nl': 'nld',
    'tr': 'tur', 'ar': 'ara', 'hi': 'hin', 'bn': 'ben', 'id': 'ind', 'ms': 'msa', 'vi': 'vie', 'fil': 'tgl',
  };

  /// The reader in use; tests swap in a fake.
  static TextReader instance = Platform.isIOS
      ? _VisionReader()
      : Platform.isWindows
      ? _WindowsTesseractReader()
      : _TesseractReader();

  /// Languages to read for a menu language: it plus English.
  static List<String> defaultsFor(String uiCode) =>
      tesseract.containsKey(uiCode) && uiCode != 'en' ? [uiCode, 'en'] : ['en'];

  /// Tidies OCR output: Thai has no spaces between words, but Tesseract
  /// often puts some in; lines broken inside a paragraph are joined.
  static String tidy(String text) {
    var t = text.replaceAll('\r', '');
    t = t.replaceAllMapped(RegExp(r'([฀-๿]) +(?=[฀-๿])'), (m) => m[1]!);
    final paragraphs = t.split(RegExp(r'\n\s*\n'));
    return paragraphs
        .map(
          (p) => p.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).fold<String>('', (a, l) {
            if (a.isEmpty) return l;
            if (a.endsWith('-')) return a.substring(0, a.length - 1) + l;
            final thai = RegExp(r'[฀-๿]$').hasMatch(a) && RegExp(r'^[฀-๿]').hasMatch(l);
            return thai ? '$a$l' : '$a $l';
          }),
        )
        .where((p) => p.isNotEmpty)
        .join('\n\n');
  }
}

const _channel = MethodChannel('pdf_flip_reader/ocr');

class _TesseractReader implements TextReader {
  // Thai reads much better with the larger "best" data; others use "fast".
  static String _url(String name) {
    final kind = name == 'tha' ? 'tessdata_best' : 'tessdata_fast';
    return 'https://raw.githubusercontent.com/tesseract-ocr/$kind/main/$name.traineddata';
  }

  /// Makes sure the language data for [names] is on the device; returns
  /// the folder that holds the "tessdata" folder.
  static Future<Directory> ensureData(List<String> names, void Function()? onDownload) async {
    final root = Directory('${(await getApplicationSupportDirectory()).path}/tesseract');
    final data = Directory('${root.path}/tessdata');
    await data.create(recursive: true);
    for (final name in names) {
      final file = File('${data.path}/$name.traineddata');
      if (await file.exists()) continue;
      onDownload?.call();
      await _download(_url(name), file);
    }
    return root;
  }

  @override
  Future<String> read(Uint8List png, List<String> langs, {void Function()? onDownload}) async {
    final names = [for (final l in langs) Ocr.tesseract[l] ?? 'eng'];
    final root = await ensureData(names, onDownload);
    final img = File('${(await getTemporaryDirectory()).path}/ocr_${DateTime.now().microsecondsSinceEpoch}.png');
    await img.writeAsBytes(png, flush: true);
    try {
      final text = await _channel.invokeMethod<String>('read', {
        'dataPath': root.path,
        'langs': names.join('+'),
        'image': img.path,
      });
      return Ocr.tidy(text ?? '');
    } finally {
      img.delete().ignore();
    }
  }

  static Future<void> _download(String url, File dest) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
      final part = File('${dest.path}.part');
      final sink = part.openWrite();
      await res.pipe(sink);
      await part.rename(dest.path);
    } finally {
      client.close();
    }
  }
}

class _WindowsTesseractReader implements TextReader {
  static String get _exe => '${File(Platform.resolvedExecutable).parent.path}\\tesseract\\tesseract.exe';

  @override
  Future<String> read(Uint8List png, List<String> langs, {void Function()? onDownload}) async {
    if (!File(_exe).existsSync()) throw MissingPluginException('tesseract.exe');
    final names = [for (final l in langs) Ocr.tesseract[l] ?? 'eng'];
    final root = await _TesseractReader.ensureData(names, onDownload);
    final img = File('${(await getTemporaryDirectory()).path}\\ocr_${DateTime.now().microsecondsSinceEpoch}.png');
    await img.writeAsBytes(png, flush: true);
    try {
      final r = await Process.run(
        _exe,
        [img.path, 'stdout', '-l', names.join('+'), '--psm', '3', '--tessdata-dir', '${root.path}\\tessdata'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (r.exitCode != 0) throw ProcessException(_exe, const [], '${r.stderr}'.trim(), r.exitCode);
      return Ocr.tidy('${r.stdout}');
    } finally {
      img.delete().ignore();
    }
  }
}

class _VisionReader implements TextReader {
  @override
  Future<String> read(Uint8List png, List<String> langs, {void Function()? onDownload}) async {
    final img = File('${(await getTemporaryDirectory()).path}/ocr_${DateTime.now().microsecondsSinceEpoch}.png');
    await img.writeAsBytes(png, flush: true);
    try {
      final text = await _channel.invokeMethod<String>('read', {'langs': langs, 'image': img.path});
      return Ocr.tidy(text ?? '');
    } finally {
      img.delete().ignore();
    }
  }
}
