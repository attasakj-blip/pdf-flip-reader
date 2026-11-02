import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_flip_reader/pdf_edit.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';

void main() {
  // Thai vowels and tone marks sit above and below the line; they used to
  // start new "lines", which cut Thai paragraphs into scraps before
  // translating (tester's chapter came out as nonsense in many sizes).
  test('Thai paragraphs stay whole, marks included', () async {
    final lib = File('build/native_assets/linux/libpdfium.so');
    if (lib.existsSync()) Pdfrx.pdfiumModulePath = lib.absolute.path;
    final font = pw.Font.ttf(File('assets/fonts/Sarabun-Regular.ttf').readAsBytesSync().buffer.asByteData());
    const title = 'บทที่ 4 ผลการทดลองและวิจารณ์';
    const body =
        'ในการผลิตน้ำมันเชื้อเพลิงอากาศยานชีวภาพจากน้ำมันมะพร้าวผ่านกระบวนการไฮโดรแครกกิ้ง '
        'ต้องศึกษาสมบัติของวัตถุดิบที่ใช้ในกระบวนการและอิทธิพลจากตัวแปรที่ส่งผลต่อปฏิกิริยา';
    final d = pw.Document();
    d.addPage(
      pw.Page(
        pageFormat: p.PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(font: font, fontSize: 18)),
            pw.SizedBox(height: 10),
            pw.Text(body, style: pw.TextStyle(font: font, fontSize: 14)),
          ],
        ),
      ),
    );
    final path = '${Directory.systemTemp.createTempSync('th').path}/thai.pdf';
    File(path).writeAsBytesSync(await d.save());
    final blocks = await PdfEditor.textBlocks(path, 0);
    expect(blocks.length, 2);
    expect(blocks[0].text, title);
    expect(blocks[1].text.replaceAll(' ', ''), body.replaceAll(' ', ''));
  });
}
