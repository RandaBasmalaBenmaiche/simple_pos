import 'dart:io';

Future<String> readTextFile(String path) {
  return File(path).readAsString();
}

Future<void> writeTextFile(String path, String contents) {
  return File(path).writeAsString(contents);
}
