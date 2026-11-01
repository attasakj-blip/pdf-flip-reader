import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'desktop.dart';
import 'l10n.dart';
import 'native_files.dart';
import 'pdf_edit.dart';
import 'settings.dart';
import 'strings.g.dart' show languageNames;
import 'translator.dart';

/// Asks which language to translate into; remembers the choice. Tap a
/// language (the last one used is ticked), then the Translate button.
Future<String?> pickTargetLanguage(BuildContext context, Settings settings) => showDialog<String>(
  context: context,
  builder: (_) => _TargetLanguageDialog(settings: settings),
);

class _TargetLanguageDialog extends StatefulWidget {
  const _TargetLanguageDialog({required this.settings});
  final Settings settings;

  @override
  State<_TargetLanguageDialog> createState() => _TargetLanguageDialogState();
}

class _TargetLanguageDialogState extends State<_TargetLanguageDialog> {
  late String _to = DocTranslator.languages.contains(widget.settings.translateTo) ? widget.settings.translateTo : 'en';

  void _go() {
    widget.settings.translateTo = _to;
    Navigator.pop(context, _to);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.translateTo),
      contentPadding: const EdgeInsets.only(top: 12),
      content: SizedBox(
        width: 360,
        child: RadioGroup<String>(
          groupValue: _to,
          onChanged: (v) => setState(() => _to = v ?? _to),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final code in DocTranslator.languages)
                RadioListTile<String>(value: code, dense: true, title: Text(languageNames[code]!)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton.icon(icon: const Icon(Icons.translate, size: 18), label: Text(s.startTranslate), onPressed: _go),
      ],
    );
  }
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
  texts = [for (final x in texts) cleanText(x)];
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
/// the page (only offered when [canPlace]). [to] is the target language.
Future<bool> showTranslation(
  BuildContext context,
  String original,
  String translated, {
  required String to,
  bool canPlace = true,
}) async {
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
            const SizedBox(height: 16),
            Text(s.translateNote, style: const TextStyle(fontSize: 12, color: Colors.amberAccent)),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.g_translate, size: 18),
                label: Text(s.openGoogleTranslate),
                onPressed: () => openGoogleTranslate(ctx, original, to),
              ),
            ),
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
        if (canPlace) TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.placeTranslation)),
        FilledButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.close)),
      ],
    ),
  );
  return put == true;
}

/// Windows version: there is no translator on the computer, so show the
/// text with a clear button that opens Google Translate in the web browser
/// with the text already filled in.
Future<void> showWebTranslation(BuildContext context, String text, String to) {
  final s = S.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${s.translationTitle} → ${languageNames[to] ?? to}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.webTranslateNote, style: const TextStyle(fontSize: 13, color: Colors.amberAccent)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(text, style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 18),
          label: Text(s.copyText),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.textCopied)));
          },
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close)),
        FilledButton.icon(
          icon: const Icon(Icons.g_translate, size: 18),
          label: Text(s.startTranslate),
          onPressed: () {
            Navigator.pop(ctx);
            openGoogleTranslate(context, text, to);
          },
        ),
      ],
    ),
  );
}

/// Windows: opens Google Translate's page for translating whole documents
/// (upload the PDF there; it keeps the layout), after saying so.
Future<void> openGoogleTranslateDocs(BuildContext context) async {
  final s = S.of(context);
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.translateDoc.replaceAll('…', '')),
      content: Text(s.webTranslateDocNote),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
        FilledButton.icon(
          icon: const Icon(Icons.g_translate, size: 18),
          label: Text(s.openGoogleTranslate),
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  if (go != true) return;
  try {
    await Desktop.openUrl('https://translate.google.com/?op=docs');
  } catch (_) {}
}

/// Opens [text] in Google Translate (app or website).
Future<void> openGoogleTranslate(BuildContext context, String text, String to) async {
  try {
    await NativeFiles.openTranslate(text, to);
  } catch (_) {
    // No platform side (tests): copy instead, so the text is not lost.
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context).textCopied)));
    }
  }
}

/// Repairs text taken from a PDF before translating it. Many Thai PDFs use
/// old fonts that store vowels and tone marks as private-use characters
/// (U+F700-F71A) or write sara am as nikhahit + sara aa; the translator
/// cannot read those, which made Thai translations come out garbled.
String cleanText(String text) {
  final b = StringBuffer();
  for (final r in text.runes) {
    final m = _thaiPua[r];
    if (m != null) {
      b.writeCharCode(m);
    } else if (r == 0x200B || r == 0xFEFF || r == 0x00AD) {
      // zero-width space, byte-order mark, soft hyphen
    } else {
      b.writeCharCode(r);
    }
  }
  return b
      .toString()
      .replaceAll('\u0E4D\u0E32', '\u0E33')
      .replaceAll('\u0E32\u0E4D', '\u0E33')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();
}

/// Thai glyph variants in the private-use area (shifted or tail-less forms
/// in Windows and Mac Thai fonts) and the letters they stand for.
const _thaiPua = <int, int>{
  0xF700: 0x0E10, 0xF701: 0x0E34, 0xF702: 0x0E35, 0xF703: 0x0E36, 0xF704: 0x0E37, //
  0xF705: 0x0E48, 0xF706: 0x0E49, 0xF707: 0x0E4A, 0xF708: 0x0E4B, 0xF709: 0x0E4C,
  0xF70A: 0x0E48, 0xF70B: 0x0E49, 0xF70C: 0x0E4A, 0xF70D: 0x0E4B, 0xF70E: 0x0E4C,
  0xF70F: 0x0E0D, 0xF710: 0x0E31, 0xF711: 0x0E4D, 0xF712: 0x0E47, 0xF713: 0x0E48,
  0xF714: 0x0E49, 0xF715: 0x0E4A, 0xF716: 0x0E4B, 0xF717: 0x0E4C, 0xF718: 0x0E38,
  0xF719: 0x0E39, 0xF71A: 0x0E3A,
};

/// Asks which pages to translate (at most [maxPages]) and into which
/// language. [preselected] are ticked to start with.
Future<({List<int> pages, String to})?> askDocTranslation(
  BuildContext context,
  Settings settings,
  int pageCount,
  List<int> preselected, {
  int maxPages = 20,
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
  late final _from = TextEditingController(text: '${_first + 1}');
  late final _to = TextEditingController(text: '${_last + 1}');
  late String _lang = DocTranslator.languages.contains(widget.settings.translateTo)
      ? widget.settings.translateTo
      : 'en';

  int get _first => widget.preselected.isEmpty ? 0 : widget.preselected.reduce(math.min);
  int get _last {
    final wanted = widget.preselected.isEmpty ? _first : widget.preselected.reduce(math.max);
    return math.min(wanted, math.min(_first + widget.max - 1, widget.pageCount - 1));
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  /// The chosen pages (0-based), or null with the reason shown.
  List<int>? get _pages {
    final a = int.tryParse(_from.text.trim()), b = int.tryParse(_to.text.trim());
    if (a == null || b == null || a < 1 || b < a || b > widget.pageCount) return null;
    if (b - a + 1 > widget.max) return null;
    return [for (var p = a - 1; p < b; p++) p];
  }

  Widget _number(TextEditingController c, String label) => Expanded(
    child: TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      onChanged: (_) => setState(() {}),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final pages = _pages;
    return AlertDialog(
      title: Text(s.translateDoc.replaceAll('…', '')),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.choosePages(widget.max), style: const TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 10),
              Row(children: [_number(_from, s.fromPage), const SizedBox(width: 12), _number(_to, s.toPage)]),
              const SizedBox(height: 6),
              Text(
                pages == null ? '1 – ${widget.pageCount}' : s.pagesChosen(pages.length, widget.max),
                style: TextStyle(fontSize: 12, color: pages == null ? Colors.amberAccent : Colors.white70),
              ),
              const SizedBox(height: 14),
              Text(s.translateTo, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              DropdownButton<String>(
                isExpanded: true,
                value: _lang,
                items: [
                  for (final c in DocTranslator.languages) DropdownMenuItem(value: c, child: Text(languageNames[c]!)),
                ],
                onChanged: (v) => setState(() => _lang = v ?? _lang),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(S.of(context).cancel)),
        FilledButton.icon(
          icon: const Icon(Icons.translate, size: 18),
          label: Text(s.startTranslate),
          onPressed: pages == null
              ? null
              : () {
                  widget.settings.translateTo = _lang;
                  Navigator.pop(context, (pages: pages, to: _lang));
                },
        ),
      ],
    );
  }
}

/// Draws [text] to cover [block] on a page: the paper colour behind it,
/// then the text as large as fits. Returns a [Stamp] for [PdfEditor].
///
/// With [fill] false the background stays see-through (for a translated
/// copy, where the old text has been taken out). [fontSize] (points) sets
/// the size instead of the largest that fits.
Future<Stamp> renderTranslation(
  int page,
  TextBlock block,
  String text,
  PagePixels? pixels,
  Size pageSize, {
  bool fill = true,
  double? fontSize,
}) async {
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
  if (fill) canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = paper);
  final painter = fitText(text, Size(tw, th), ink, start: (fontSize ?? block.lineHeight * 0.8) * k);
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

/// Stamps for a translated copy of one page (see
/// [PdfEditor.translatedCopy]). Text of the same kind (body text, headings)
/// gets one size across the page, so the page reads evenly; each block may
/// grow into the empty space below it before its text is made smaller.
Future<List<Stamp>> translatedPageStamps(String path, int page, List<TextBlock> blocks, List<String> texts) async {
  final px = await PdfEditor.render(path, page);
  final size = Size(px.width.toDouble(), px.height.toDouble());
  final boxes = roomyBlocks(blocks, pixels: px);
  final sizes = evenSizes(boxes, texts, size);
  return [
    for (var i = 0; i < boxes.length; i++)
      await renderTranslation(page, boxes[i], texts[i], px, size, fill: false, fontSize: sizes[i]),
  ];
}

/// [blocks] with each one's box stretched down into the free space below
/// it (up to the next block it would run into, or the bottom margin), so a
/// longer translation has room. Sideways text keeps its box.
///
/// With [pixels] (the page as shown), the free space ends at the first
/// thing drawn below the block, such as a picture or a table line.
List<TextBlock> roomyBlocks(List<TextBlock> blocks, {PagePixels? pixels}) {
  double limit(TextBlock b) {
    var y = _roomBelow(b, blocks);
    if (pixels != null) y = math.min(y, _emptyBelow(b.rect, pixels, y));
    return y;
  }

  return [
    for (final b in blocks)
      if (b.turns.isOdd)
        b
      else
        (
          text: b.text,
          rect: (
            left: b.rect.left,
            top: b.rect.top,
            width: b.rect.width,
            height: math.max(b.rect.height, limit(b) - b.rect.top),
          ),
          lineHeight: b.lineHeight,
          turns: b.turns,
        ),
  ];
}

/// How far down (fraction of the page, at most [until]) the paper under
/// [r] stays empty.
double _emptyBelow(PageRect r, PagePixels px, double until) {
  final paper = _paperColor(px, r);
  final pr = (paper.r * 255).round(), pg = (paper.g * 255).round(), pb = (paper.b * 255).round();
  final x0 = (r.left * px.width).floor().clamp(0, px.width - 1);
  final x1 = ((r.left + r.width) * px.width).ceil().clamp(0, px.width - 1);
  final y0 = ((r.top + r.height) * px.height).ceil() + 2;
  final y1 = math.min(px.height - 1, (until * px.height).floor());
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      final i = (y * px.width + x) * 4;
      if ((px.bgra[i + 2] - pr).abs() > 40 || (px.bgra[i + 1] - pg).abs() > 40 || (px.bgra[i] - pb).abs() > 40) {
        return math.max(r.top + r.height, (y - 2) / px.height);
      }
    }
  }
  return until;
}

double _roomBelow(TextBlock b, List<TextBlock> all) {
  final bottom = b.rect.top + b.rect.height;
  var limit = 0.95; // bottom margin
  for (final o in all) {
    if (identical(o, b)) continue;
    final overlaps = o.rect.left < b.rect.left + b.rect.width && o.rect.left + o.rect.width > b.rect.left;
    if (overlaps && o.rect.top >= bottom - 0.002) limit = math.min(limit, o.rect.top - 0.004);
  }
  // Don't stretch a block more than about three times its height.
  return math.min(limit, b.rect.top + b.rect.height * 3);
}

/// One font size (points) per kind of text on the page. Blocks whose
/// original line heights are within about 20% count as the same kind; the
/// kind's size is the smallest that fits all of them, but never below 60%
/// of the original, and a block that still doesn't fit at that size gets
/// its own smaller size.
List<double> evenSizes(List<TextBlock> boxes, List<String> texts, Size page) {
  double fits(int i, double start) {
    final b = boxes[i];
    final w = b.rect.width * page.width, h = b.rect.height * page.height;
    final box = b.turns.isOdd ? Size(h, w) : Size(w, h);
    return fitText(texts[i], box, const Color(0xFF000000), start: start).text!.style!.fontSize!;
  }

  final natural = [for (final b in boxes) b.lineHeight * 0.8];
  final fitted = [for (var i = 0; i < boxes.length; i++) fits(i, natural[i])];
  final out = List<double>.from(fitted);
  final done = <int>{};
  for (var i = 0; i < boxes.length; i++) {
    if (done.contains(i)) continue;
    final group = [
      for (var j = i; j < boxes.length; j++)
        if (!done.contains(j) && (natural[j] - natural[i]).abs() <= 0.2 * math.max(natural[i], natural[j])) j,
    ];
    done.addAll(group);
    final base = group.map((j) => natural[j]).reduce(math.min);
    final even = math.max(group.map((j) => fitted[j]).reduce(math.min), base * 0.6);
    for (final j in group) {
      out[j] = math.min(fitted[j], even);
    }
  }
  return out;
}

/// Blocks worth translating: skip ones with no letters (page numbers,
/// stray symbols).
List<TextBlock> translatable(List<TextBlock> blocks) =>
    blocks.where((b) => RegExp(r'\p{L}', unicode: true).hasMatch(b.text)).toList();
