import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_flip_reader/l10n.dart';
import 'package:pdf_flip_reader/text_box.dart';

TextNote note({String text = 'Hello world', int page = 0}) => TextNote(
  text: text,
  flags: List.filled(text.length, 0),
  font: 'Sarabun',
  size: 16,
  color: Colors.black,
  page: page,
  left: 0.2,
  top: 0.3,
  width: 0.4,
);

void main() {
  test('styles follow the characters while typing and deleting', () {
    final c = RichTextController(text: 'abcdef');
    c.selection = const TextSelection(baseOffset: 1, extentOffset: 3);
    c.toggle(kBold);
    expect(c.flags, [0, 1, 1, 0, 0, 0]);
    expect(c.has(kBold), isTrue);
    // Type in front: the bold part moves along with its letters.
    c.value = const TextEditingValue(text: 'XXabcdef', selection: TextSelection.collapsed(offset: 2));
    expect(c.flags, [0, 0, 0, 1, 1, 0, 0, 0]);
    // Delete "bc": the bold goes with them.
    c.value = const TextEditingValue(text: 'XXadef', selection: TextSelection.collapsed(offset: 3));
    expect(c.flags, [0, 0, 0, 0, 0, 0]);
    // Italic for new typing when nothing is selected.
    c.toggle(kItalic);
    c.value = const TextEditingValue(text: 'XXaQdef', selection: TextSelection.collapsed(offset: 4));
    expect(c.flags[3], kItalic);
    expect(c.flags[2], 0);
    // Toggling a mixed selection makes it all bold; again clears it.
    c.selection = const TextSelection(baseOffset: 0, extentOffset: 7);
    c.toggle(kBold);
    expect(c.flags.every((f) => f & kBold != 0), isTrue);
    c.toggle(kBold);
    expect(c.flags.every((f) => f & kBold == 0), isTrue);
  });

  test('styled spans split where the style changes', () {
    final s = styledSpan('ab cd', [kBold, kBold, 0, kUnderline, kUnderline], const TextStyle());
    expect(s.children!.length, 3);
    expect((s.children![0] as TextSpan).style!.fontWeight, FontWeight.bold);
    expect((s.children![2] as TextSpan).style!.decoration, TextDecoration.underline);
  });

  test('a narrower box wraps the text onto more lines', () {
    final n = note(text: 'one two three four five six seven eight nine ten');
    final wide = n.layout(600).computeLineMetrics().length;
    n.width = 0.1;
    final narrow = n.layout(600).computeLineMetrics().length;
    expect(narrow, greaterThan(wide));
  });

  testWidgets('text stamps keep the box position and grow with the text', (tester) async {
    await tester.runAsync(() async {
      final n = note();
      final stamps = await textStamps([n]);
      expect(stamps, hasLength(1));
      final s = stamps.first;
      expect(s.page, 0);
      expect(s.rect.left, 0.2);
      expect(s.rect.top, 0.3);
      expect(s.rect.width, 0.4);
      expect(s.rect.height, greaterThan(0));
      expect(s.rgba.length, s.w * s.h * 4);
      expect(s.rgba.any((b) => b != 0), isTrue);
    });
  });

  testWidgets('text boxes can be moved, widened and deleted', (tester) async {
    final notes = [note()];
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [SDelegate()],
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TextLayer(
              slots: const [(page: 0, rect: Rect.fromLTWH(100, 80, 400, 560))],
              notes: notes,
              onAdd: () {},
              onEdit: (_) {},
              onDone: () => done++,
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    final n = notes.first;
    await tester.pump();
    final start = tester.getCenter(find.byKey(ObjectKey(n)));
    await tester.dragFrom(start, const Offset(40, 56));
    await tester.pump();
    expect(n.left, closeTo(0.3, 0.05));
    expect(n.top, closeTo(0.4, 0.05));
    // Chosen now: the width handle and the delete button show.
    await tester.drag(find.byIcon(Icons.swap_horiz), const Offset(80, 0));
    await tester.pump();
    expect(n.width, closeTo(0.6, 0.05));
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(notes, isEmpty);
    expect(done, 0);
    await tester.pump(const Duration(seconds: 2)); // let tap and tooltip timers finish
  });

  testWidgets('the text window returns the typed text and its style', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TextNote? got;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [SDelegate()],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => got = await showTextEditor(context, style: note(text: '')),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'สวัสดี hello');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.format_bold)); // bold for what comes next
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(got, isNotNull);
    expect(got!.text, 'สวัสดี hello');
    expect(got!.flags, hasLength(got!.text.length));
    expect(got!.font, 'Sarabun');
  });
}
