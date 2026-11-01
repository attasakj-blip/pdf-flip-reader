import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_flip_reader/library_screen.dart';
import 'package:pdf_flip_reader/native_files.dart';
import 'package:pdf_flip_reader/page_scroller.dart';

void main() {
  test('Google Translate link carries the text and target language', () {
    final url = Uri.parse(NativeFiles.translateUrl('สวัสดี & hello', 'en'));
    expect(url.host, 'translate.google.com');
    expect(url.queryParameters['text'], 'สวัสดี & hello');
    expect(url.queryParameters['tl'], 'en');
    expect(NativeFiles.translateUrl('x' * 9000, 'th').length, lessThan(4200));
  });

  test('folder label of a Windows file', () {
    expect(folderLabel(Uri.parse('file:///C:/Users/me/Documents/book.pdf')), contains('Documents'));
  });

  testWidgets('dragging the scroll bar jumps through the book', (tester) async {
    await tester.pumpWidget(const _Host());
    final state = tester.state<_HostState>(find.byType(_Host));
    final box = tester.getRect(find.byType(PageScroller));
    // Drag the thumb from the top to the bottom: last page.
    final g = await tester.startGesture(Offset(box.right - 14, box.top + 20));
    await g.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(find.textContaining('p'), findsOneWidget); // page bubble
    await g.moveTo(Offset(box.right - 14, box.bottom + 50));
    await g.up();
    await tester.pump();
    expect(state.index, 100);
    expect(state.ends, 1);
    // Tap the middle of the track: about half way.
    await tester.tapAt(Offset(box.right - 14, box.center.dy));
    await tester.pump();
    expect(state.index, inInclusiveRange(45, 55));
  });
}

class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int index = 0;
  int ends = 0;
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 36,
          height: 400,
          child: PageScroller(
            count: 101,
            index: index,
            labelFor: (i) => 'p${i + 1}',
            onChanged: (i) => setState(() => index = i),
            onEnd: () => ends++,
          ),
        ),
      ),
    ),
  );
}
