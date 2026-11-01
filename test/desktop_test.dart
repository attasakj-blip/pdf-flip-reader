import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_flip_reader/library_screen.dart';
import 'package:pdf_flip_reader/native_files.dart';

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
}
