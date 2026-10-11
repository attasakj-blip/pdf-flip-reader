import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'ads.dart';
import 'flip_sounds.dart';
import 'l10n.dart';
import 'native_files.dart';
import 'reader_screen.dart';
import 'settings.dart';
import 'sound_settings.dart';

/// First screen: choose a PDF from the phone (the system picker lets the user
/// browse folders), or reopen one of the recent books.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.settings, required this.sounds});

  final Settings settings;
  final FlipSounds sounds;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _busy = false;

  Settings get _settings => widget.settings;

  Future<void> _pick() async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/books');
    await dir.create(recursive: true);
    ({String name, String folder, String path, String? uri})? picked;
    try {
      // Keeps permission to write the original, for saving signed copies.
      final p = await NativeFiles.openPdf(dir.path);
      if (p == null) return;
      picked = (name: p.name, folder: folderLabel(Uri.parse(p.uri)), path: p.path, uri: p.uri);
    } on MissingPluginException {
      picked = null;
    }
    setState(() => _busy = true);
    try {
      if (picked == null) {
        final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
        if (files.isEmpty) return;
        final file = files.first;
        // Keep our own copy: Android only lends the picked file for a while.
        final local = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
        final sink = local.openWrite();
        await sink.addStream(file.readAsByteStream());
        await sink.close();
        picked = (name: file.name, folder: folderLabel(file.uri), path: local.path, uri: null);
      }
      final recents = _settings.recents;
      final existing = recents.where((b) => b.name == picked!.name && b.folder == picked.folder).toList();
      for (final old in existing) {
        _deleteCopy(old);
        recents.remove(old);
      }
      final book = RecentBook(
        name: picked.name,
        folder: picked.folder,
        localPath: picked.path,
        lastPage: existing.isEmpty ? 0 : existing.first.lastPage,
        rtl: existing.isEmpty ? null : existing.first.rtl,
        uri: picked.uri,
      );
      _settings.saveRecents([book, ...recents]);
      if (mounted) await _open(book);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context).openFailed(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(RecentBook book) async {
    if (!File(book.localPath).existsSync()) {
      _remove(book);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context).fileMissing)));
      return;
    }
    // Move it to the top of the list.
    final rest = _settings.recents.where((b) => b.localPath != book.localPath).toList();
    _settings.saveRecents([book, ...rest]);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(book: book, settings: _settings, sounds: widget.sounds),
      ),
    );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) setState(() {});
  }

  void _remove(RecentBook book) {
    _deleteCopy(book);
    _settings.saveRecents(_settings.recents.where((b) => b.localPath != book.localPath).toList());
    setState(() {});
  }

  void _deleteCopy(RecentBook b) {
    try {
      File(b.localPath).deleteSync();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final recents = _settings.recents;
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Flip Reader'),
        actions: [
          IconButton(
            tooltip: s.language,
            icon: const Icon(Icons.translate),
            onPressed: () async {
              final v = await showLanguagePicker(context, _settings.language);
              if (v != null) _settings.language = v.isEmpty ? null : v;
            },
          ),
          IconButton(
            tooltip: s.rotateScreen,
            icon: const Icon(Icons.screen_rotation),
            onPressed: () => _settings.quarterTurns += 1,
          ),
          IconButton(
            tooltip: s.flipSoundMenu,
            icon: const Icon(Icons.music_note),
            onPressed: () => showSoundSettings(context, _settings, widget.sounds),
          ),
          IconButton(
            tooltip: s.exitApp,
            icon: const Icon(Icons.power_settings_new),
            onPressed: () => SystemNavigator.pop(),
          ),
        ],
      ),
      bottomNavigationBar: const Center(heightFactor: 1, child: BannerSlot()),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _busy ? null : _pick,
            icon: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.folder_open),
            label: Text(s.pickPdf),
          ),
          const SizedBox(height: 8),
          Text(
            s.pickHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          if (recents.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(s.recent, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final b in recents)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  title: Text(b.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${b.folder.isEmpty ? s.unknownFolder : s.folder(b.folder)}\n${s.readTo(b.lastPage + 1)}',
                  ),
                  isThreeLine: true,
                  onTap: () => _open(b),
                  trailing: IconButton(
                    tooltip: s.removeFromList,
                    icon: const Icon(Icons.close),
                    onPressed: () => _remove(b),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Best-effort human folder name for a picked file, e.g. "Download/Books".
/// Android hands out content:// links whose document id usually carries the
/// path ("primary:Download/Books/a.pdf"); some providers hide it.
String folderLabel(Uri uri) {
  String path;
  if (uri.scheme == 'file') {
    path = uri.toFilePath();
  } else {
    final last = uri.pathSegments.isEmpty ? '' : Uri.decodeComponent(uri.pathSegments.last);
    final colon = last.indexOf(':');
    path = colon >= 0 ? last.substring(colon + 1) : last;
  }
  path = path.replaceFirst(RegExp(r'^/storage/emulated/0/'), '').replaceFirst(RegExp(r'^/sdcard/'), '');
  final slash = path.lastIndexOf('/');
  if (slash > 0) return path.substring(0, slash);
  if (uri.authority.contains('downloads')) return 'Download';
  return '';
}
