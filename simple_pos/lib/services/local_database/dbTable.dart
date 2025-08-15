import 'package:sqflite/sqflite.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';

class DBBaseTable {
  var db_table = 'TABLE_NAME_MUST_OVERRIDE';

  Future<bool> insertRecord(Map<String, dynamic> data) async {
    try {
      final database = await DBfactory.getDatabase();
      database.insert(db_table, data,
          conflictAlgorithm: ConflictAlgorithm.replace);
      print("inserted:\t");
      print(data.toString());
      return true;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
    }
    return false;
  }

Future<List<Map<String, dynamic>>> getRecords() async {
  try {
    final database = await DBfactory.getDatabase();
    var data = await database.rawQuery("select * from $db_table");
    return data.cast<Map<String, dynamic>>();
  } catch (e, stacktrace) {
    print('$e --> $stacktrace');
  }
  return [];
}

}
