import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n.dart';
import 'ocr.dart';
import 'strings.g.dart' show languageNames;

/// What the user chose in [OcrResultDialog]: read again in other
/// languages, or translate the (possibly corrected) text.
typedef OcrResult = ({List<String>? langs, String? translate});

/// Shows text read from a scan in an editable box, with copy, translate and
/// a way to read again in another language.
class OcrResultDialog extends StatefulWidget {
  const OcrResultDialog({super.key, required this.text, required this.langs, this.autoTranslate = false});

  final String text;
  final List<String> langs;

  /// Came from "translate" on a scanned page: the main button translates.
  final bool autoTranslate;

  @override
  State<OcrResultDialog> createState() => _OcrResultDialogState();
}

class _OcrResultDialogState extends State<OcrResultDialog> {
  late final _text = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _langLabel(List<String> langs) => langs.map((c) => languageNames[c] ?? c).join(' + ');

  Future<void> _changeLanguage() async {
    final s = S.of(context);
    final main = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.ocrLanguage),
        children: [
          RadioGroup<String>(
            groupValue: widget.langs.first,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final code in Ocr.tesseract.keys)
                  RadioListTile<String>(value: code, title: Text(languageNames[code] ?? code)),
              ],
            ),
          ),
        ],
      ),
    );
    if (main == null || !mounted) return;
    Navigator.pop<OcrResult>(context, (langs: main == 'en' ? ['en'] : [main, 'en'], translate: null));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final empty = widget.text.trim().isEmpty;
    return AlertDialog(
      title: Text(s.ocrTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ActionChip(
                avatar: const Icon(Icons.language, size: 18),
                label: Text('${s.ocrLanguage}: ${_langLabel(widget.langs)}'),
                onPressed: _changeLanguage,
              ),
              const SizedBox(height: 8),
              if (empty)
                Text(s.ocrNothing, style: const TextStyle(color: Colors.amberAccent))
              else ...[
                Text(s.ocrEditHint, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 6),
                TextField(
                  controller: _text,
                  maxLines: 12,
                  minLines: 4,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!empty)
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: Text(s.copyText),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _text.text));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.textCopied)));
            },
          ),
        if (!empty)
          TextButton.icon(
            icon: const Icon(Icons.translate, size: 18),
            label: Text(s.translateButton),
            onPressed: () => Navigator.pop<OcrResult>(context, (langs: null, translate: _text.text)),
          ),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(s.close)),
      ],
    );
  }
}
