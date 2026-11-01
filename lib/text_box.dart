import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'edit_tools.dart';
import 'l10n.dart';
import 'pdf_edit.dart' show Stamp;

/// Style bits for each character of a [TextNote].
const kBold = 1, kItalic = 2, kUnderline = 4;

/// Font sizes are in points on an A4-wide page (595 pt), like a word
/// processor; on screen they scale with the page.
const _pageWidthPt = 595.0;

/// The most letters one text box may hold.
const maxNoteLength = 300;

/// Sizes offered, as in a word processor.
const textSizes = <double>[8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 60, 72];

/// Typed text placed on a page. Position and width are fractions of the
/// page; the height follows from the text.
class TextNote {
  TextNote({
    required this.text,
    required this.flags,
    required this.font,
    required this.size,
    required this.color,
    this.page = 0,
    this.left = 0,
    this.top = 0,
    this.width = 0.5,
    this.aspect = 1.414,
  });

  String text;
  List<int> flags;
  String font;
  double size;
  Color color;
  int page;
  double left, top, width;

  /// Page height / width, for working out the height as a page fraction.
  double aspect;

  /// The text as styled spans, with [fontSize] in pixels.
  TextSpan span(double fontSize) => styledSpan(text, flags, _style(fontSize));

  TextStyle _style(double fontSize) => TextStyle(fontFamily: font, fontSize: fontSize, color: color, height: 1.25);

  /// Lays the text out for a page drawn [pageWidth] pixels wide.
  TextPainter layout(double pageWidth) =>
      TextPainter(text: span(size / _pageWidthPt * pageWidth), textDirection: TextDirection.ltr)
        ..layout(maxWidth: math.max(1, width * pageWidth));
}

/// [text] as spans that follow the per-character [flags].
TextSpan styledSpan(String text, List<int> flags, TextStyle base) {
  final runs = <TextSpan>[];
  var i = 0;
  while (i < text.length) {
    final f = i < flags.length ? flags[i] : 0;
    var j = i + 1;
    while (j < text.length && (j < flags.length ? flags[j] : 0) == f) {
      j++;
    }
    runs.add(
      TextSpan(
        text: text.substring(i, j),
        style: TextStyle(
          fontWeight: f & kBold != 0 ? FontWeight.bold : null,
          fontStyle: f & kItalic != 0 ? FontStyle.italic : null,
          decoration: f & kUnderline != 0 ? TextDecoration.underline : null,
        ),
      ),
    );
    i = j;
  }
  return TextSpan(style: base, children: runs);
}

/// A text field whose characters can each be bold, italic or underlined.
class RichTextController extends TextEditingController {
  RichTextController({String text = '', List<int>? flags})
    : flags = List.of(flags ?? List.filled(text.length, 0)),
      super(text: text);

  List<int> flags;

  /// Style chosen with nothing selected, for the next letters typed.
  /// Otherwise new letters take the style of the letter before them.
  int? _pending;

  @override
  set value(TextEditingValue v) {
    final old = text, now = v.text;
    if (old != now) {
      var p = 0;
      while (p < old.length && p < now.length && old.codeUnitAt(p) == now.codeUnitAt(p)) {
        p++;
      }
      var s = 0;
      while (s < old.length - p &&
          s < now.length - p &&
          old.codeUnitAt(old.length - 1 - s) == now.codeUnitAt(now.length - 1 - s)) {
        s++;
      }
      final inserted = now.length - p - s;
      final style = _pending ?? (p > 0 ? flags[p - 1] : (flags.isNotEmpty ? flags.first : 0));
      flags = [...flags.take(p), ...List.filled(inserted, style), ...flags.skip(old.length - s)];
    } else if (v.selection != selection) {
      _pending = null; // moved elsewhere: back to the style found there
    }
    super.value = v;
  }

  int get _typingStyle {
    final p = selection.isValid ? selection.start : text.length;
    return _pending ?? (p > 0 && p <= flags.length ? flags[p - 1] : 0);
  }

  /// Whether every selected character has [bit] (or, with nothing
  /// selected, whether new typing will).
  bool has(int bit) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return _typingStyle & bit != 0;
    for (var i = sel.start; i < sel.end && i < flags.length; i++) {
      if (flags[i] & bit == 0) return false;
    }
    return true;
  }

  void toggle(int bit) {
    final on = !has(bit);
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) {
      final t = _typingStyle;
      _pending = on ? t | bit : t & ~bit;
    } else {
      for (var i = sel.start; i < sel.end && i < flags.length; i++) {
        flags[i] = on ? flags[i] | bit : flags[i] & ~bit;
      }
    }
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) =>
      styledSpan(text, flags, style ?? const TextStyle());
}

/// Fonts to choose from: on Windows every font installed on the computer
/// (the same list a word processor shows), elsewhere the app's own.
class TextFonts {
  static List<String>? _cache;

  static Future<List<String>> list() async {
    if (_cache != null) return _cache!;
    var fonts = <String>[];
    if (Platform.isWindows) {
      try {
        final r = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          '[Console]::OutputEncoding=[Text.Encoding]::UTF8; Add-Type -AssemblyName System.Drawing; '
              '(New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object { \$_.Name }',
        ], stdoutEncoding: utf8);
        fonts = '${r.stdout}'.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      } catch (_) {}
      if (fonts.isEmpty) {
        fonts = ['Arial', 'Calibri', 'Cambria', 'Leelawadee UI', 'Segoe UI', 'Tahoma', 'Times New Roman', 'Verdana'];
      }
    } else {
      fonts = ['Sarabun', 'sans-serif', 'serif', 'monospace'];
    }
    fonts = {...fonts}.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return _cache = fonts;
  }

  /// A font that reads Thai well, to start with.
  static String preferred(List<String> fonts) {
    for (final f in ['Leelawadee UI', 'TH Sarabun New', 'Tahoma', 'Sarabun', 'Segoe UI']) {
      if (fonts.contains(f)) return f;
    }
    return fonts.first;
  }
}

/// The window for typing (or changing) a note's text and its style.
/// Returns null if cancelled.
Future<TextNote?> showTextEditor(BuildContext context, {TextNote? note, required TextNote style}) async {
  final fonts = await TextFonts.list();
  if (!context.mounted) return null;
  return showDialog<TextNote>(
    context: context,
    builder: (_) => _TextEditor(note: note, style: style, fonts: fonts),
  );
}

class _TextEditor extends StatefulWidget {
  const _TextEditor({required this.note, required this.style, required this.fonts});
  final TextNote? note;
  final TextNote style;
  final List<String> fonts;

  @override
  State<_TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<_TextEditor> {
  late final RichTextController _ctl;
  late String _font;
  late double _size;
  late Color _color;

  @override
  void initState() {
    super.initState();
    final n = widget.note ?? widget.style;
    _ctl = RichTextController(text: widget.note?.text ?? '', flags: widget.note?.flags);
    _ctl.addListener(() => setState(() {}));
    _font = widget.fonts.contains(n.font) ? n.font : TextFonts.preferred(widget.fonts);
    _size = n.size;
    _color = n.color;
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _ok() {
    if (_ctl.text.trim().isEmpty) return;
    final n = widget.note;
    if (n != null) {
      n
        ..text = _ctl.text
        ..flags = List.of(_ctl.flags)
        ..font = _font
        ..size = _size
        ..color = _color;
      Navigator.pop(context, n);
    } else {
      Navigator.pop(
        context,
        TextNote(text: _ctl.text, flags: List.of(_ctl.flags), font: _font, size: _size, color: _color),
      );
    }
  }

  Widget _styleButton(int bit, IconData icon, String tip) {
    final on = _ctl.has(bit);
    return IconButton(
      tooltip: tip,
      isSelected: on,
      style: IconButton.styleFrom(backgroundColor: on ? Colors.amber.withValues(alpha: 0.35) : null),
      icon: Icon(icon),
      onPressed: () => _ctl.toggle(bit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final sizes = {...textSizes, _size}.toList()..sort();
    return AlertDialog(
      title: Text(s.insertText),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String>(
                    initialValue: _font,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: s.fontName, isDense: true),
                    menuMaxHeight: 420,
                    items: [
                      for (final f in widget.fonts)
                        DropdownMenuItem(
                          value: f,
                          child: Text(
                            f,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: f),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _font = v ?? _font),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: DropdownButtonFormField<double>(
                    initialValue: _size,
                    decoration: InputDecoration(labelText: s.fontSize, isDense: true),
                    menuMaxHeight: 420,
                    items: [for (final z in sizes) DropdownMenuItem(value: z, child: Text(z.toStringAsFixed(0)))],
                    onChanged: (v) => setState(() => _size = v ?? _size),
                  ),
                ),
                _styleButton(kBold, Icons.format_bold, s.bold),
                _styleButton(kItalic, Icons.format_italic, s.italic),
                _styleButton(kUnderline, Icons.format_underlined, s.underline),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                for (final c in [...signInks, Colors.white])
                  InkWell(
                    onTap: () => setState(() => _color = c),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c ? Colors.amber : Colors.white54,
                          width: _color == c ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minHeight: 140, maxHeight: 320),
              decoration: BoxDecoration(
                color: _color.computeLuminance() > 0.7 ? Colors.grey.shade700 : Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: _ctl,
                autofocus: true,
                maxLines: null,
                // At most 300 letters in one box; the counter shows how many are left.
                maxLength: maxNoteLength,
                keyboardType: TextInputType.multiline,
                cursorColor: Colors.blue,
                style: TextStyle(fontFamily: _font, fontSize: math.min(_size * 1.4, 40), color: _color, height: 1.25),
                decoration: InputDecoration.collapsed(
                  hintText: s.typeHere,
                  hintStyle: const TextStyle(color: Colors.black38),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _ctl.text.trim().isEmpty ? null : _ok, child: Text(s.done)),
      ],
    );
  }
}

/// Text boxes over the visible pages: drag to move, drag the right handle
/// to change the width (the text wraps), tap to choose one, then edit or
/// delete it. Boxes on other pages are kept while the reader turns pages.
class TextLayer extends StatefulWidget {
  const TextLayer({
    super.key,
    required this.slots,
    required this.notes,
    required this.onAdd,
    required this.onEdit,
    required this.onDone,
    required this.onCancel,
  });

  final List<PageSlot> slots;
  final List<TextNote> notes;
  final VoidCallback onAdd;
  final void Function(TextNote note) onEdit;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  @override
  State<TextLayer> createState() => _TextLayerState();
}

class _TextLayerState extends State<TextLayer> {
  TextNote? _chosen;
  static const _handle = 26.0;

  PageSlot? _slotOf(TextNote n) {
    for (final s in widget.slots) {
      if (s.page == n.page) return s;
    }
    return null;
  }

  Rect _rectOf(TextNote n, PageSlot s) {
    final tp = n.layout(s.rect.width);
    final r = Rect.fromLTWH(
      s.rect.left + n.left * s.rect.width,
      s.rect.top + n.top * s.rect.height,
      n.width * s.rect.width,
      tp.height,
    );
    tp.dispose();
    return r;
  }

  void _move(TextNote n, Offset d) {
    final s = _slotOf(n);
    if (s == null) return;
    setState(() {
      n.left += d.dx / s.rect.width;
      n.top += d.dy / s.rect.height;
      // Dragged onto the other page of a spread: it belongs there now.
      final c = _rectOf(n, s).center;
      for (final o in widget.slots) {
        if (o.page != n.page && o.rect.contains(c)) {
          n.left = (s.rect.left + n.left * s.rect.width - o.rect.left) / o.rect.width;
          n.top = (s.rect.top + n.top * s.rect.height - o.rect.top) / o.rect.height;
          n.width = n.width * s.rect.width / o.rect.width;
          n.page = o.page;
          n.aspect = o.rect.height / o.rect.width;
        }
      }
    });
  }

  void _resize(TextNote n, double dx) {
    final s = _slotOf(n);
    if (s == null) return;
    setState(() => n.width = math.max(24 / s.rect.width, n.width + dx / s.rect.width));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final shown = <(TextNote, Rect)>[];
    for (final n in widget.notes) {
      final slot = _slotOf(n);
      if (slot != null) shown.add((n, _rectOf(n, slot)));
    }
    return Stack(
      children: [
        // Taps on the page drop the choice; page-turn gestures are swallowed.
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => _chosen = null)),
        ),
        for (final (n, r) in shown) ...[
          Positioned.fromRect(
            rect: r.inflate(4),
            child: MouseRegion(
              key: ObjectKey(n),
              cursor: SystemMouseCursors.move,
              child: GestureDetector(
                onTap: () => setState(() => _chosen = n),
                onDoubleTap: () => widget.onEdit(n),
                onPanStart: (_) => setState(() => _chosen = n),
                onPanUpdate: (d) => _move(n, d.delta),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: identical(n, _chosen)
                          ? Colors.lightBlueAccent
                          : Colors.lightBlueAccent.withValues(alpha: 0.35),
                      width: identical(n, _chosen) ? 1.5 : 1,
                    ),
                  ),
                  child: CustomPaint(painter: _NotePainter(n, _slotOf(n)!.rect.width)),
                ),
              ),
            ),
          ),
          if (identical(n, _chosen)) ...[
            // Width handle on the right edge.
            Positioned(
              left: r.right + 4 - _handle / 2,
              top: r.center.dy - _handle / 2,
              width: _handle,
              height: _handle,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  onPanUpdate: (d) => _resize(n, d.delta.dx),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Colors.lightBlueAccent, shape: BoxShape.circle),
                    child: Icon(Icons.swap_horiz, size: 16, color: Colors.black),
                  ),
                ),
              ),
            ),
            Positioned(
              left: r.left - 4,
              top: r.top - 4 - 40,
              child: Material(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: s.editText,
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => widget.onEdit(n),
                    ),
                    IconButton(
                      tooltip: s.delete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => setState(() {
                        widget.notes.remove(n);
                        _chosen = null;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.black.withValues(alpha: 0.75),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(child: Text(s.textHint, style: const TextStyle(fontSize: 13))),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(s.addText),
                      onPressed: widget.onAdd,
                    ),
                    const SizedBox(width: 8),
                    TextButton(onPressed: widget.onCancel, child: Text(s.cancel)),
                    FilledButton(onPressed: widget.notes.isEmpty ? null : widget.onDone, child: Text(s.done)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotePainter extends CustomPainter {
  _NotePainter(this.note, this.pageWidth)
    : key = '${note.text}|${note.flags.join()}|${note.font}|${note.size}|${note.color.toARGB32()}|${note.width}';
  final TextNote note;
  final double pageWidth;
  final String key;

  @override
  void paint(Canvas canvas, Size size) {
    final tp = note.layout(pageWidth);
    tp.paint(canvas, Offset.zero);
    tp.dispose();
  }

  @override
  bool shouldRepaint(_NotePainter old) => old.key != key || old.pageWidth != pageWidth;
}

/// The notes as images to draw into the PDF, about 200 dpi on A4.
Future<List<Stamp>> textStamps(List<TextNote> notes) async {
  const pagePx = 1700.0;
  final stamps = <Stamp>[];
  for (final n in notes) {
    if (n.text.trim().isEmpty) continue;
    final tp = n.layout(pagePx);
    final w = math.max(1, (n.width * pagePx).ceil());
    final h = math.max(1, tp.height.ceil());
    final rec = ui.PictureRecorder();
    tp.paint(Canvas(rec), Offset.zero);
    tp.dispose();
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    img.dispose();
    stamps.add((
      page: n.page,
      rgba: data!.buffer.asUint8List(),
      w: w,
      h: h,
      rect: (left: n.left, top: n.top, width: n.width, height: h / (pagePx * n.aspect)),
    ));
  }
  return stamps;
}
