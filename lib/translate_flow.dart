import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n.dart';
import 'pdf_edit.dart';
import 'settings.dart';
import 'strings.g.dart' show languageNames;
import 'translator.dart';

/// Asks which language to translate into; remembers the choice.
Future<String?> pickTargetLanguage(BuildContext context, Settings settings) {
  final s = S.of(context);
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(s.translateTo),
      children: [
        RadioGroup<String>(
          groupValue: settings.translateTo,
          onChanged: (v) {
            if (v != null) settings.translateTo = v;
            Navigator.pop(ctx, v);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final code in DocTranslator.languages)
                RadioListTile<String>(value: code, title: Text(languageNames[code]!)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Shows a progress dialog with [message] while [work] runs, then closes it.
Future<T> withProgress<T>(BuildContext context, ValueNotifier<String> message, Future<T> Function() work) async {
  final nav = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: ValueListenableBuilder(valueListenable: message, builder: (_, m, _) => Text(m)),
            ),
          ],
        ),
      ),
    ),
  );
  try {
    return await work();
  } finally {
    nav.pop();
  }
}

/// Translates [texts] (one language for all of them) into [to]. Returns
/// null when the language can't be told.
Future<List<String>?> translateAll(
  List<String> texts,
  String to, {
  required ValueNotifier<String> message,
  required S s,
  void Function(int done)? onProgress,
}) async {
  final t = DocTranslator.instance;
  final from = await t.detect(texts.join('\n'));
  if (from == null) return null;
  await t.prepare(from, to, onDownload: () => message.value = s.downloadingModel);
  message.value = s.translating;
  final out = <String>[];
  for (var i = 0; i < texts.length; i++) {
    out.add(await t.translate(texts[i], from, to));
    onProgress?.call(i + 1);
  }
  return out;
}

/// Shows the translation; returns true if the user wants it written onto
/// the page.
Future<bool> showTranslation(BuildContext context, String original, String translated) async {
  final s = S.of(context);
  final put = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.translationTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(translated, style: const TextStyle(fontSize: 16)),
            const Divider(height: 24),
            Text(original, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: translated));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.textCopied)));
          },
          child: Text(s.copyText),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.placeTranslation)),
        FilledButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.close)),
      ],
    ),
  );
  return put == true;
}

/// Asks which pages to translate (at most [maxPages]) and into which
/// language. [preselected] are ticked to start with.
Future<({List<int> pages, String to})?> askDocTranslation(
  BuildContext context,
  Settings settings,
  int pageCount,
  List<int> preselected, {
  int maxPages = 10,
}) => showDialog(
  context: context,
  builder: (_) =>
      _DocTranslateDialog(settings: settings, pageCount: pageCount, preselected: preselected, max: maxPages),
);

class _DocTranslateDialog extends StatefulWidget {
  const _DocTranslateDialog({
    required this.settings,
    required this.pageCount,
    required this.preselected,
    required this.max,
  });
  final Settings settings;
  final int pageCount;
  final List<int> preselected;
  final int max;

  @override
  State<_DocTranslateDialog> createState() => _DocTranslateDialogState();
}

class _DocTranslateDialogState extends State<_DocTranslateDialog> {
  late final Set<int> _pages = widget.preselected.take(widget.max).toSet();
  late String _to = widget.settings.translateTo;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.translateDoc.replaceAll('…', '')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.translateTo, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            DropdownButton<String>(
              isExpanded: true,
              value: _to,
              items: [
                for (final c in DocTranslator.languages) DropdownMenuItem(value: c, child: Text(languageNames[c]!)),
              ],
              onChanged: (v) => setState(() => _to = v ?? _to),
            ),
            const SizedBox(height: 12),
            Text(s.choosePages, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            Text(s.pagesChosen(_pages.length)),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var p = 0; p < widget.pageCount; p++)
                    CheckboxListTile(
                      dense: true,
                      value: _pages.contains(p),
                      title: Text(s.pageN(p + 1)),
                      onChanged: !_pages.contains(p) && _pages.length >= widget.max
                          ? null
                          : (v) => setState(() => v == true ? _pages.add(p) : _pages.remove(p)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(S.of(context).cancel)),
        FilledButton(
          onPressed: _pages.isEmpty
              ? null
              : () {
                  widget.settings.translateTo = _to;
                  Navigator.pop(context, (pages: _pages.toList()..sort(), to: _to));
                },
          child: Text(s.translateButton),
        ),
      ],
    );
  }
}

/// Draws [text] to cover [block] on a page: the paper colour behind it,
/// then the text as large as fits. Returns a [Stamp] for [PdfEditor].
Future<Stamp> renderTranslation(int page, TextBlock block, String text, PagePixels? pixels, Size pageSize) async {
  // A little margin so the old letters' edges are covered too.
  final padX = 1.5 / pageSize.width, padY = 1.5 / pageSize.height;
  final rect = (
    left: math.max(0.0, block.rect.left - padX),
    top: math.max(0.0, block.rect.top - padY),
    width: math.min(1.0, block.rect.width + 2 * padX),
    height: math.min(1.0, block.rect.height + 2 * padY),
  );
  final paper = pixels == null ? const Color(0xFFFFFFFF) : _paperColor(pixels, rect);
  final dark = paper.computeLuminance() > 0.45;
  final ink = dark ? const Color(0xFF111111) : const Color(0xFFF2F2F2);

  // Work at about 3 pixels per point.
  const k = 3.0;
  final boxW = rect.width * pageSize.width * k, boxH = rect.height * pageSize.height * k;
  final odd = block.turns.isOdd;
  // The text's own box, before turning it the way the page shows it.
  final tw = odd ? boxH : boxW, th = odd ? boxW : boxH;
  final w = math.max(1, boxW.round()), h = math.max(1, boxH.round());

  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = paper);
  final painter = fitText(text, Size(tw, th), ink, start: block.lineHeight * k * 0.8);
  canvas.save();
  canvas.translate(w / 2, h / 2);
  canvas.rotate(block.turns * math.pi / 2);
  painter.paint(canvas, Offset(-tw / 2, -th / 2 + math.max(0, (th - painter.height) / 2)));
  canvas.restore();
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  img.dispose();
  return (page: page, rgba: data!.buffer.asUint8List(), w: w, h: h, rect: rect);
}

/// Lays out [text] in [box] at the largest size up to [start] that fits.
TextPainter fitText(String text, Size box, Color color, {required double start}) {
  TextPainter layout(double size) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: size, color: color, height: 1.15),
    ),
    textDirection: _rtlText(text) ? TextDirection.rtl : TextDirection.ltr,
  )..layout(maxWidth: box.width);
  var lo = 2.0, hi = math.max(lo, start);
  var best = layout(lo);
  if (best.height > box.height) return best;
  for (var i = 0; i < 14; i++) {
    final mid = (lo + hi) / 2;
    final p = layout(mid);
    if (p.height <= box.height && p.width <= box.width + 0.5) {
      best = p;
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final top = layout(hi);
  return top.height <= box.height ? top : best;
}

bool _rtlText(String t) => RegExp(r'[֐-ࣿ]').hasMatch(t);

/// The most common colour just around [r] (the paper under the text).
Color _paperColor(PagePixels px, PageRect r) {
  final counts = <int, int>{};
  void sample(int x, int y) {
    if (x < 0 || y < 0 || x >= px.width || y >= px.height) return;
    final i = (y * px.width + x) * 4;
    // Quantise a little so near-identical shades count together.
    final key = ((px.bgra[i + 2] >> 3) << 10) | ((px.bgra[i + 1] >> 3) << 5) | (px.bgra[i] >> 3);
    counts[key] = (counts[key] ?? 0) + 1;
  }

  final l = (r.left * px.width).floor() - 1, t = (r.top * px.height).floor() - 1;
  final rr = ((r.left + r.width) * px.width).ceil() + 1, b = ((r.top + r.height) * px.height).ceil() + 1;
  for (var x = l; x <= rr; x++) {
    sample(x, t);
    sample(x, b);
  }
  for (var y = t; y <= b; y++) {
    sample(l, y);
    sample(rr, y);
  }
  if (counts.isEmpty) return const Color(0xFFFFFFFF);
  final key = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  int ch(int shift) => (((key >> shift) & 31) << 3) | 4;
  return Color.fromARGB(255, ch(10), ch(5), ch(0));
}

/// Builds the stamps for translated blocks on one page.
Future<List<Stamp>> translatedStamps(String path, int page, List<TextBlock> blocks, List<String> texts) async {
  final px = await PdfEditor.render(path, page);
  final size = Size(px.width.toDouble(), px.height.toDouble());
  return [for (var i = 0; i < blocks.length; i++) await renderTranslation(page, blocks[i], texts[i], px, size)];
}

/// Blocks worth translating: skip ones with no letters (page numbers,
/// stray symbols).
List<TextBlock> translatable(List<TextBlock> blocks) =>
    blocks.where((b) => RegExp(r'\p{L}', unicode: true).hasMatch(b.text)).toList();
