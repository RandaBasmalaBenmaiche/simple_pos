import 'file_text_io.dart';

Future<void> downloadTextFile(String fileName, String contents) {
  return writeTextFile(fileName, contents);
}
