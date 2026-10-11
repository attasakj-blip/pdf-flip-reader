import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'l10n.dart';
import 'library_screen.dart' show folderLabel;
import 'native_files.dart';
import 'settings.dart';

/// Where an edited book went.
typedef SavedBook = ({RecentBook book, bool replaced});

/// Asks how to save the edited copy of [book] at [edited] (replace the
/// original, a new file, or a new folder), writes it and records it in the
/// recent list. Returns null if the user backs out; the original is then
/// untouched. [suffix] goes on suggested new file names, e.g. "signed".
Future<SavedBook?> saveEdited(
  BuildContext context,
  Settings settings,
  RecentBook book,
  String edited, {
  required String suffix,
}) async {
  final s = S.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(s.saveTitle, style: Theme.of(ctx).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.save),
            title: Text(s.saveReplace),
            subtitle: Text(s.saveReplaceHint),
            onTap: () => Navigator.pop(ctx, 'replace'),
          ),
          ListTile(
            leading: const Icon(Icons.save_as),
            title: Text(s.saveAsNew),
            subtitle: Text(s.saveAsNewHint),
            onTap: () => Navigator.pop(ctx, 'new'),
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder),
            title: Text(s.saveNewFolder),
            subtitle: Text(s.saveNewFolderHint),
            onTap: () => Navigator.pop(ctx, 'folder'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;

  final base = book.name.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
  final suggested = '${base}_$suffix.pdf';
  final messenger = ScaffoldMessenger.of(context);
  try {
    SavedBook? result;
    switch (choice) {
      case 'replace':
        result = await _replace(context, book, edited);
      case 'new':
        final ref = await NativeFiles.createPdf(suggested);
        if (ref == null) return null;
        result = await _asNew(book, edited, ref);
      case 'folder':
        final names = await _askFolder(context, suggested);
        if (names == null) return null;
        final ref = await NativeFiles.createInNewFolder(names.folder, names.file);
        if (ref == null) return null;
        result = await _asNew(book, edited, ref);
    }
    if (result == null) return null;
    final list = settings.recents.where((b) => !result!.replaced || b.localPath != book.localPath).toList();
    settings.saveRecents([result.book, ...list.where((b) => b.localPath != result!.book.localPath)]);
    messenger.showSnackBar(SnackBar(content: Text(s.savedAs(result.book.name))));
    return result;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(s.saveFailed(e))));
    return null;
  }
}

Future<String> _localCopy(String edited, String name) async {
  final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/books');
  await dir.create(recursive: true);
  final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$name';
  await File(edited).copy(path);
  return path;
}

Future<SavedBook?> _replace(BuildContext context, RecentBook book, String edited) async {
  var uri = book.uri;
  try {
    if (uri == null || !await NativeFiles.canWrite(uri)) {
      // Opened before the app kept write access: have the user point at the
      // original once.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context).pickOriginal)));
      }
      final tmp = await getTemporaryDirectory();
      final picked = await NativeFiles.openPdf(tmp.path);
      if (picked == null) return null;
      File(picked.path).delete().ignore();
      uri = picked.uri;
    }
    await NativeFiles.write(uri, edited);
  } on MissingPluginException {
    // No phone storage to write to (tests): only the app's copy changes.
  }
  final local = await _localCopy(edited, book.name);
  return (book: book.copyWith(localPath: local, uri: uri), replaced: true);
}

Future<SavedBook> _asNew(RecentBook book, String edited, DocRef ref) async {
  await NativeFiles.write(ref.uri, edited);
  final name = ref.name.isEmpty ? 'document.pdf' : ref.name;
  final local = await _localCopy(edited, name);
  return (
    book: book.copyWith(name: name, folder: folderLabel(Uri.parse(ref.uri)), localPath: local, uri: ref.uri),
    replaced: false,
  );
}

Future<({String folder, String file})?> _askFolder(BuildContext context, String suggested) {
  final s = S.of(context);
  final folder = TextEditingController();
  final file = TextEditingController(text: suggested);
  return showDialog<({String folder, String file})>(
    context: context,
    builder: (ctx) {
      void submit() {
        final f = folder.text.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        var n = file.text.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        if (f.isEmpty || n.isEmpty) return;
        if (!n.toLowerCase().endsWith('.pdf')) n = '$n.pdf';
        Navigator.pop(ctx, (folder: f, file: n));
      }

      return AlertDialog(
        title: Text(s.saveNewFolder.replaceAll('…', '')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: folder,
              autofocus: true,
              decoration: InputDecoration(labelText: s.folderName, prefixIcon: const Icon(Icons.folder)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: file,
              decoration: InputDecoration(labelText: s.fileName, prefixIcon: const Icon(Icons.picture_as_pdf)),
              onSubmitted: (_) => submit(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(onPressed: submit, child: Text(s.saveButton)),
        ],
      );
    },
  );
}
