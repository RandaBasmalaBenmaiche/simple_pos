import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<void> deleteDatabaseFile() async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, "SimplePos.db");

  try {
    await deleteDatabase(path);
    print("Database deleted successfully.");
  } catch (e) {
    print("Error deleting database: $e");
  }
}
