import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n.dart';

/// Small window that asks which page to open. Returns the 1-based page
/// number, or null if cancelled.
Future<int?> showGoToPageDialog(BuildContext context, int total) {
  final s = S.of(context);
  final ctrl = TextEditingController();
  String? error;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        void submit() {
          final v = int.tryParse(ctrl.text.trim());
          if (v == null || v < 1 || v > total) {
            setLocal(() => error = s.gotoError(total));
            return;
          }
          Navigator.of(ctx).pop(v);
        }

        return AlertDialog(
          title: Text(s.gotoTitle),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.go,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(hintText: '1 – $total', errorText: error),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.cancel)),
            FilledButton(onPressed: submit, child: Text(s.go)),
          ],
        );
      },
    ),
  );
}
