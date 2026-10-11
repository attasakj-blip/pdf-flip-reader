import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_flip_reader/edge_menu.dart';
import 'package:pdf_flip_reader/markup.dart';
import 'package:pdf_flip_reader/pdf_edit.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';

void main() {
  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('hl');
    final lib = File('build/native_assets/linux/libpdfium.so');
    if (lib.existsSync()) Pdfrx.pdfiumModulePath = lib.absolute.path;
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('dragging over text highlights whole lines between the two points', () async {
    final d = pw.Document()
      ..addPage(
        pw.Page(
          pageFormat: p.PdfPageFormat.a4,
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('First line of words here', style: const pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              pw.Text('Second line of words here', style: const pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              pw.Text('Third line stays clear', style: const pw.TextStyle(fontSize: 24)),
            ],
          ),
        ),
      );
    final src = '${dir.path}/t.pdf', out = '${dir.path}/t2.pdf';
    File(src).writeAsBytesSync(await d.save());

    final chars = await PdfEditor.pageChars(src, 0);
    expect(chars.map((c) => c.line).toSet(), {0, 1, 2});
    final first = chars.firstWhere((c) => !c.blank).box;
    final second = chars.firstWhere((c) => c.line == 1 && !c.blank).box;

    // From the middle of "First" to the middle of line two.
    final a = Offset(first.left + first.width / 2, first.top + first.height / 2);
    final b = Offset(second.left + 0.15, second.top + second.height / 2);
    final rects = highlightRects(chars, a, b);
    expect(rects, hasLength(2));
    expect(rects[0].top, lessThan(rects[1].top));

    // Starting away from any text highlights nothing.
    expect(highlightRects(chars, const Offset(0.5, 0.9), b), isEmpty);

    final m = Mark(page: 0, tool: MarkTool.textHighlight, color: markColors[7], width: 0, dashed: false)
      ..rects.addAll(rects);
    await PdfEditor.stampAll(src, out, await markStamps([m], {0: 841.89 / 595.28}));
    final doc = await PdfDocument.openFile(out);
    final page = doc.pages[0];
    final img = (await page.render(fullWidth: page.width, fullHeight: page.height))!;
    List<int> at(double fx, double fy) {
      final i = ((fy * img.height).round() * img.width + (fx * img.width).round()) * 4;
      return img.pixels.sublist(i, i + 4); // BGRA
    }

    // Yellow paper under line one (just above the letters), white under line three.
    final r0 = rects[0];
    final yellow = at(r0.left + r0.width * 0.5, r0.top + r0.height * 0.06);
    expect(yellow[0], lessThan(200), reason: 'blue drops under yellow $yellow');
    expect(yellow[2], greaterThan(220), reason: 'red stays $yellow');
    final third = chars.firstWhere((c) => c.line == 2 && !c.blank).box;
    expect(at(third.left + 0.05, third.top - 0.002), [255, 255, 255, 255]);
    await doc.dispose();
  });

  test('highlighter brush widths grow in five steps', () {
    expect(highlightWidths, hasLength(5));
    expect(markWidths, hasLength(5));
    for (var i = 1; i < 5; i++) {
      expect(highlightWidths[i], greaterThan(highlightWidths[i - 1]));
      expect(markWidths[i], greaterThan(markWidths[i - 1]));
    }
  });

  testWidgets('edge menu slides out, toggles stay open, actions run', (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final c = AnimationController(vsync: tester, duration: const Duration(milliseconds: 200));
    var night = false, signed = 0, closed = 0;
    final key = GlobalKey();
    Widget app() => MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: StatefulBuilder(
        builder: (context, setState) => RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFFF5EEDC),
            body: Stack(
              children: [
                const Center(child: Text('Page text', style: TextStyle(color: Colors.black, fontSize: 30))),
                Positioned.fill(
                  child: EdgeMenu(
                    left: false,
                    progress: c,
                    title: 'Translate and view',
                    icon: Icons.auto_awesome,
                    onClose: () => closed++,
                    items: [
                      EdgeMenuItem(icon: Icons.translate, label: 'Translate text', onTap: () => signed++),
                      EdgeMenuItem(icon: Icons.g_translate, label: 'Translate document', onTap: () {}),
                      EdgeMenuItem(icon: Icons.auto_stories, label: 'Cover alone', on: true, onTap: () {}),
                      EdgeMenuItem(icon: Icons.swap_horiz, label: 'Right to left', on: false, onTap: () {}),
                      EdgeMenuItem(
                        icon: Icons.dark_mode,
                        label: 'Night mode',
                        on: night,
                        onTap: () => setState(() => night = !night),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app());
    c.value = 1;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Night mode'));
    await tester.pumpAndSettle();
    expect(night, isTrue);
    await tester.tap(find.text('Translate text'));
    expect(signed, 1);
    // A tap beside the panel asks to close.
    await tester.tapAt(const Offset(40, 400));
    expect(closed, 1);

    final out = Platform.environment['SHOT_DIR'];
    if (out != null) {
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 1);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/edge_menu.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
  });
}
