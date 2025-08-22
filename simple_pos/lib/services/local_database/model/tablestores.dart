// db_stores_table.dart
import 'package:sqflite/sqflite.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';
import 'package:simple_pos/services/local_database/dbTable.dart';

class DStoresTable extends DBBaseTable {
  @override
  var db_table = 'stores';

  // ==========================
  // Create table SQL (match your pattern)
  // ==========================
  static String sql_code = '''
    CREATE TABLE stores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      location TEXT,
      is_active INTEGER NOT NULL DEFAULT 1
    );
  ''';

  static String sql_code_create = '''
    INSERT INTO stores (name, location, is_active) VALUES
      ('Kiosque Djalil Ranim', 'Annaba', 1),
      ('Quincaillerie', 'Annaba', 1);
  ''';

  /// Insert a new store (returns inserted row id)
  Future<int?> custinsertRecord(Map<String, dynamic> data) async {
    try {
      final database = await DBfactory.getDatabase();
      final id = await database.insert(
        db_table,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print("inserted:\t");
      print(data.toString());
      return id;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
    }
    return null;
  }

  /// Convenience: insert by fields (returns id)
  Future<int?> insertStore({
    required String name,
    String? location,
    bool isActive = true,
  }) async {
    return await custinsertRecord({
      'name': name,
      'location': location,
      'is_active': isActive ? 1 : 0,
    });
  }

  /// Get all stores (optionally only active)
  Future<List<Map<String, dynamic>>> getStores({bool? onlyActive}) async {
    try {
      final database = await DBfactory.getDatabase();
      if (onlyActive == null) {
        return await database.query(db_table, orderBy: 'id DESC');
      }
      return await database.query(
        db_table,
        where: 'is_active = ?',
        whereArgs: [onlyActive ? 1 : 0],
        orderBy: 'id DESC',
      );
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
    }
  }

  /// Get store by ID
  Future<Map<String, dynamic>?> getStoreById(int id) async {
    try {
      final database = await DBfactory.getDatabase();
      final res = await database.query(
        db_table,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return res.isNotEmpty ? res.first : null;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  /// Update store
  Future<bool> updateStore({
    required int id,
    String? name,
    String? location,
    bool? isActive,
  }) async {
    try {
      final database = await DBfactory.getDatabase();
      final data = <String, Object?>{};
      if (name != null) data['name'] = name;
      if (location != null) data['location'] = location;
      if (isActive != null) data['is_active'] = isActive ? 1 : 0;

      if (data.isEmpty) return true; // nothing to update

      final count = await database.update(
        db_table,
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  /// Delete store
  Future<bool> deleteStore(int id) async {
    try {
      final database = await DBfactory.getDatabase();
      final count = await database.delete(
        db_table,
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  /// Count stores
  Future<int> countStores({bool? onlyActive}) async {
    try {
      final database = await DBfactory.getDatabase();
      if (onlyActive == null) {
        final res = await database
            .rawQuery('SELECT COUNT(*) as c FROM $db_table');
        return Sqflite.firstIntValue(res) ?? 0;
      } else {
        final res = await database.rawQuery(
          'SELECT COUNT(*) as c FROM $db_table WHERE is_active = ?',
          [onlyActive ? 1 : 0],
        );
        return Sqflite.firstIntValue(res) ?? 0;
      }
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return 0;
    }
  }
}
