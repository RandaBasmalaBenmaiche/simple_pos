import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadTextFile(String fileName, String contents) async {
  final encoded = base64Encode(utf8.encode(contents));
  final anchor = html.AnchorElement(
    href: 'data:text/plain;charset=utf-8;base64,$encoded',
  )
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
