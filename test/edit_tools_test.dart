import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_flip_reader/edit_tools.dart';
import 'package:pdf_flip_reader/l10n.dart';

Widget host(Widget child) => MaterialApp(
  localizationsDelegates: const [SDelegate()],
  home: Scaffold(
    body: Stack(children: [Positioned.fill(child: child)]),
  ),
);

void main() {
  test('screen box to page fractions', () {
    final r = pageRectOf((
      page: 3,
      rect: const Rect.fromLTWH(100, 50, 200, 400),
    ), const Rect.fromLTWH(150, 250, 100, 40));
    expect(r.left, 0.25);
    expect(r.top, 0.5);
    expect(r.width, 0.5);
    expect(r.height, 0.1);
  });

  test('a signature is trimmed to its ink and rendered with alpha', () async {
    final sig = Signature.trim(
      [
        [const Offset(100, 100), const Offset(200, 120)],
        [const Offset(150, 80), const Offset(150, 140)],
      ],
      const Color(0xFF1A3FA8),
      4,
    )!;
    expect(sig.size.width, closeTo(108, 0.01));
    expect(sig.size.height, closeTo(68, 0.01));
    final img = await sig.toRgba(216);
    expect(img.w, 216);
    expect(img.h, 136);
    expect(img.rgba[3], 0); // corner is clear
    // Somewhere along the strokes is solid blue ink.
    var inked = 0;
    for (var i = 0; i < img.rgba.length; i += 4) {
      if (img.rgba[i + 3] == 255 && img.rgba[i + 2] > 150) inked++;
    }
    expect(inked, greaterThan(200));
  });

  testWidgets('placing a signature reports the page under it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    final sig = Signature.trim(
      [
        [const Offset(0, 0), const Offset(100, 50)],
      ],
      Colors.black,
      3,
    )!;
    const slots = [
      (page: 4, rect: Rect.fromLTWH(100, 50, 300, 500)),
      (page: 5, rect: Rect.fromLTWH(400, 50, 300, 500)),
    ];
    PageSlot? doneSlot;
    Rect? doneBox;
    await tester.pumpWidget(
      host(
        PlaceSignature(
          signature: sig,
          slots: slots,
          onDone: (s, b) {
            doneSlot = s;
            doneBox = b;
          },
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Starts on the last (right-hand) page; drag it onto the left page.
    await tester.drag(find.byKey(const ValueKey('signatureBox')), const Offset(-300, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    expect(doneSlot!.page, 4);
    expect(doneBox!.width, closeTo(120, 0.5));
    expect(slots[0].rect.contains(doneBox!.center), isTrue);
  });

  testWidgets('dragging out an area enables Copy and returns it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    Rect? area;
    await tester.pumpWidget(host(SelectArea(onDone: (a) => area = a, onCancel: () {})));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Copy')).onPressed, isNull);
    final g = await tester.startGesture(const Offset(200, 200));
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset(200 + 20.0 * i, 200 + 15.0 * i));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Copy'));
    expect(area!.width, greaterThan(150));
    expect(area!.height, greaterThan(100));
  });
}
