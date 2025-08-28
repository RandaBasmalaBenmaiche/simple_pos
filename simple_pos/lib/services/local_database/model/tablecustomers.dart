import 'package:sqflite/sqflite.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';
import 'package:simple_pos/services/local_database/dbTable.dart';

class DCustomersTable extends DBBaseTable {
  @override
  var db_table = 'customers';

  // ==========================
  // SQL: Create Customers Table
  // ==========================
  static String sql_code = '''
    CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      store_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      phone TEXT,
      debt REAL NOT NULL DEFAULT 0
    );
  ''';

  /// Insert new customer
  Future<int?> insertCustomer({
    required int storeId,
    required String name,
    String? phone,
    double debt = 0,
  }) async {
    try {
      final database = await DBfactory.getDatabase();
      return await database.insert(db_table, {
        'store_id': storeId,
        'name': name,
        'phone': phone,
        'debt': debt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  /// Get all customers for a store
  Future<List<Map<String, dynamic>>> getCustomers(int storeId) async {
    try {
      final database = await DBfactory.getDatabase();
      return await database.query(
        db_table,
        where: 'store_id = ?',
        whereArgs: [storeId],
        orderBy: 'id DESC',
      );
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
    }
  }

  /// Get customer by ID
  Future<Map<String, dynamic>?> getCustomerById(int id) async {
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

  /// Update customer's info or debt
  Future<bool> updateCustomer({
    required int id,
    String? name,
    String? phone,
    double? debt,
  }) async {
    try {
      final database = await DBfactory.getDatabase();
      final data = <String, Object?>{};
      if (name != null) data['name'] = name;
      if (phone != null) data['phone'] = phone;
      if (debt != null) data['debt'] = debt;

      if (data.isEmpty) return true;

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

/// Get customer(s) by Name
Future<List<Map<String, dynamic>>> getCustomerByName(String name, int storeId) async {
  try {
    final database = await DBfactory.getDatabase();
    final res = await database.query(
      db_table,
      where: 'store_id = ? AND name LIKE ?',
      whereArgs: [storeId, '%$name%'], // supports partial match
      orderBy: 'id DESC',
    );
    return res;
  } catch (e, stacktrace) {
    print('$e --> $stacktrace');
    return [];
  }
}


  /// Delete customer
  Future<bool> deleteCustomer(int id) async {
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
}
