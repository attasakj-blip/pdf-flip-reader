import 'package:flutter/material.dart';

import 'l10n.dart';

/// Page numbers written like "1-3, 5" as sorted 0-based indices, or null
/// when the text has a number outside 1..[total] or isn't a range list.
List<int>? parsePageRange(String text, int total) {
  final pages = <int>{};
  final parts = text.split(RegExp(r'[,;\s]+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return null;
  for (final part in parts) {
    final m = RegExp(r'^(\d+)(?:[-–](\d+))?$').firstMatch(part);
    if (m == null) return null;
    final a = int.parse(m[1]!);
    final b = m[2] == null ? a : int.parse(m[2]!);
    if (a < 1 || b < 1 || a > total || b > total) return null;
    for (var i = a < b ? a : b; i <= (a < b ? b : a); i++) {
      pages.add(i - 1);
    }
  }
  return pages.toList()..sort();
}

/// Asks which pages to print (Windows: its print window has no page choice).
/// Returns 0-based page indices, or null when cancelled.
Future<List<int>?> showPrintPages(BuildContext context, {required List<int> current, required int total}) {
  return showDialog<List<int>>(
    context: context,
    builder: (_) => _PrintPages(current: current, total: total),
  );
}

enum _Which { all, current, range }

class _PrintPages extends StatefulWidget {
  const _PrintPages({required this.current, required this.total});
  final List<int> current;
  final int total;

  @override
  State<_PrintPages> createState() => _PrintPagesState();
}

class _PrintPagesState extends State<_PrintPages> {
  var _which = _Which.all;
  final _range = TextEditingController();
  bool _bad = false;

  @override
  void dispose() {
    _range.dispose();
    super.dispose();
  }

  void _ok() {
    switch (_which) {
      case _Which.all:
        Navigator.pop(context, [for (var i = 0; i < widget.total; i++) i]);
      case _Which.current:
        Navigator.pop(context, List.of(widget.current)..sort());
      case _Which.range:
        final pages = parsePageRange(_range.text, widget.total);
        if (pages == null) {
          setState(() => _bad = true);
        } else {
          Navigator.pop(context, pages);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cur = widget.current.map((p) => p + 1).join(', ');
    return AlertDialog(
      title: Text(s.printDocument),
      content: SizedBox(
        width: 380,
        child: RadioGroup<_Which>(
          groupValue: _which,
          onChanged: (v) => setState(() => _which = v!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioListTile(value: _Which.all, title: Text('${s.printAll} (${widget.total})')),
              RadioListTile(value: _Which.current, title: Text('${s.printCurrent} ($cur)')),
              RadioListTile(
                value: _Which.range,
                title: TextField(
                  key: const ValueKey('printRange'),
                  controller: _range,
                  decoration: InputDecoration(
                    labelText: s.printRange,
                    hintText: s.printRangeHint,
                    errorText: _bad ? s.printBadRange : null,
                  ),
                  onTap: () => setState(() => _which = _Which.range),
                  onChanged: (_) => setState(() {
                    _which = _Which.range;
                    _bad = false;
                  }),
                  onSubmitted: (_) => _ok(),
                ),
              ),
              const SizedBox(height: 12),
              Text(s.printNote, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _ok, child: Text(s.printNext)),
      ],
    );
  }
}
