import 'dbFactory.dart';

Future<void> deleteDatabaseFile() async {
  try {
    await DBfactory.clearDatabase();
    print('Database deleted successfully.');
  } catch (e) {
    print('Error deleting database: $e');
  }
}
