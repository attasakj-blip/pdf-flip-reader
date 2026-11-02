import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_flip_reader/l10n.dart';
import 'package:pdf_flip_reader/markup.dart';
import 'package:pdf_flip_reader/pdf_edit.dart';
import 'package:pdf_flip_reader/text_box.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';

void main() {
  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('mk');
    final lib = File('build/native_assets/linux/libpdfium.so');
    if (lib.existsSync()) Pdfrx.pdfiumModulePath = lib.absolute.path;
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('a red box drawn on the page ends up in the PDF where it was drawn', () async {
    final d = pw.Document()..addPage(pw.Page(pageFormat: p.PdfPageFormat.a4, build: (_) => pw.Text('Hi')));
    final src = '${dir.path}/a.pdf', out = '${dir.path}/b.pdf';
    File(src).writeAsBytesSync(await d.save());
    final box = Mark(page: 0, tool: MarkTool.rect, color: markColors[4], width: markWidths[4], dashed: false)
      ..points.addAll(const [Offset(0.2, 0.3), Offset(0.6, 0.5)]);
    final pen = Mark(page: 0, tool: MarkTool.pen, color: markColors[11], width: markWidths[1], dashed: false)
      ..points.addAll(const [Offset(0.1, 0.8), Offset(0.5, 0.8), Offset(0.9, 0.8)]);
    final stamps = await markStamps([box, pen], {0: 841.89 / 595.28});
    expect(stamps.single.rect.left, closeTo(0.1 - markWidths[1], 0.001));
    await PdfEditor.stampAll(src, out, stamps);

    final doc = await PdfDocument.openFile(out);
    final page = doc.pages[0];
    final img = (await page.render(fullWidth: page.width, fullHeight: page.height))!;
    List<int> at(double fx, double fy) {
      final i = ((fy * img.height).round() * img.width + (fx * img.width).round()) * 4;
      return img.pixels.sublist(i, i + 4); // BGRA
    }

    final edge = at(0.4, 0.3), inside = at(0.4, 0.4), line = at(0.5, 0.8);
    expect(edge[2], greaterThan(180), reason: 'red edge $edge');
    expect(edge[0], lessThan(100), reason: 'red edge $edge');
    expect(inside, [255, 255, 255, 255], reason: 'box is only an outline');
    expect(line[0], greaterThan(150), reason: 'blue pen $line');
    expect(line[2], lessThan(100), reason: 'blue pen $line');
    await doc.dispose();
  });

  test('dashed lines have gaps', () async {
    final m = Mark(page: 0, tool: MarkTool.line, color: Colors.black, width: 0.01, dashed: true)
      ..points.addAll(const [Offset(0.1, 0.5), Offset(0.9, 0.5)]);
    final s = (await markStamps([m], {0: 1.0})).single;
    // Walk along the middle row: ink and gaps should alternate.
    final row = s.h ~/ 2;
    var changes = 0;
    var last = false;
    for (var x = 0; x < s.w; x++) {
      final ink = s.rgba[(row * s.w + x) * 4 + 3] > 128;
      if (ink != last) changes++;
      last = ink;
    }
    expect(changes, greaterThan(10));
  });

  testWidgets('one finger draws a circle, two fingers zoom', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    final marks = <Mark>[];
    double? zoomed;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [SDelegate()],
        home: Scaffold(
          body: MarkupLayer(
            slots: const [(page: 2, rect: Rect.fromLTWH(200, 0, 400, 600))],
            marks: marks,
            zoom: 1,
            pan: Offset.zero,
            onZoom: (z, _) => zoomed = z,
            onDone: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Circle'));
    await tester.pump();
    final g = await tester.startGesture(const Offset(300, 200));
    for (var i = 1; i <= 5; i++) {
      await g.moveTo(Offset(300 + 30.0 * i, 200 + 10.0 * i));
      await tester.pump();
    }
    await g.up();
    expect(marks.single.tool, MarkTool.circle);
    expect(marks.single.page, 2);
    final a = marks.single.points[0], b = marks.single.points[1];
    // Square on screen: equal width and height in pixels.
    expect(((b.dx - a.dx) * 400).abs(), closeTo(((b.dy - a.dy) * 600).abs(), 0.5));

    final f1 = await tester.startGesture(const Offset(350, 300));
    final f2 = await tester.startGesture(const Offset(450, 300));
    await tester.pump();
    for (var i = 1; i <= 5; i++) {
      await f1.moveTo(Offset(350 - 10.0 * i, 300));
      await f2.moveTo(Offset(450 + 10.0 * i, 300));
      await tester.pump();
    }
    await f1.up();
    await f2.up();
    expect(zoomed, greaterThan(1.5));
    expect(marks, hasLength(1));
  });

  testWidgets('the eraser also takes out saved text boxes it touches', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notes = [
      TextNote(
        text: 'Hello',
        flags: [0, 0, 0, 0, 0],
        font: 'Sarabun',
        size: 16,
        color: Colors.black,
        left: 0.1,
        top: 0.5,
        width: 0.4,
      ),
      TextNote(
        text: 'Keep',
        flags: [0, 0, 0, 0],
        font: 'Sarabun',
        size: 16,
        color: Colors.black,
        left: 0.1,
        top: 0.8,
        width: 0.4,
      ),
    ];
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [SDelegate()],
        home: Scaffold(
          body: MarkupLayer(
            slots: const [(page: 0, rect: Rect.fromLTWH(200, 0, 400, 600))],
            marks: <Mark>[],
            notes: notes,
            erasing: true,
            canFinishEmpty: true,
            zoom: 1,
            pan: Offset.zero,
            onZoom: (_, _) {},
            onDone: () => done++,
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Rub across the first box (page x 240..360, y 300..).
    final g = await tester.startGesture(const Offset(230, 305));
    for (var x = 240.0; x <= 380; x += 20) {
      await g.moveTo(Offset(x, 305));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(notes.map((n) => n.text), ['Keep']);
    await tester.tap(find.text('Done'));
    expect(done, 1);
  });

  testWidgets('a drawn box can be moved and resized, and the eraser takes marks out', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    final marks = <Mark>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [SDelegate()],
        home: Scaffold(
          body: MarkupLayer(
            slots: const [(page: 0, rect: Rect.fromLTWH(200, 0, 400, 600))],
            marks: marks,
            zoom: 1,
            pan: Offset.zero,
            onZoom: (_, _) {},
            onDone: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> drag(Offset from, Offset to) async {
      final g = await tester.startGesture(from);
      for (var i = 1; i <= 6; i++) {
        await g.moveTo(Offset.lerp(from, to, i / 6)!);
        await tester.pump();
      }
      await g.up();
      await tester.pump();
    }

    await tester.tap(find.byTooltip('Rectangle'));
    await tester.pump();
    await drag(const Offset(300, 100), const Offset(400, 200)); // box 100 x 100
    final box = marks.single;
    Rect onScreen() => Rect.fromPoints(
      Offset(200 + box.points.first.dx * 400, box.points.first.dy * 600),
      Offset(200 + box.points.last.dx * 400, box.points.last.dy * 600),
    );
    expect(onScreen().width, closeTo(100, 1));

    // Drag the bottom-right grip outwards: bigger.
    await drag(const Offset(400, 200), const Offset(460, 260));
    expect(marks, hasLength(1));
    expect(onScreen().width, closeTo(160, 3));
    expect(onScreen().height, closeTo(160, 3));

    // Drag the middle: it moves, same size.
    await drag(const Offset(380, 180), const Offset(330, 230));
    expect(onScreen().left, closeTo(250, 3));
    expect(onScreen().top, closeTo(150, 3));
    expect(onScreen().width, closeTo(160, 3));

    // A pen stroke elsewhere, then erase only the box.
    await tester.tap(find.byTooltip('Pen (free drawing)'));
    await tester.pump();
    await drag(const Offset(250, 500), const Offset(550, 520));
    expect(marks, hasLength(2));
    await tester.tap(find.byTooltip('Eraser'));
    await tester.pump();
    expect(find.text('Large'), findsOneWidget);
    await drag(Offset(onScreen().left - 5, onScreen().center.dy), Offset(onScreen().left + 5, onScreen().center.dy));
    expect(marks, hasLength(1));
    expect(marks.single.tool, MarkTool.pen);
  });
}
