import 'package:sqflite/sqflite.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';
import 'package:simple_pos/services/local_database/dbTable.dart';

class DDebtPaymentsTable extends DBBaseTable {
  @override
  var db_table = 'debt_payments';

  // ==========================
  // SQL: Create Debt Payments Table
  // ==========================
  static String sql_code = '''
    CREATE TABLE debt_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      store_id INTEGER NOT NULL,
      customer_id INTEGER NOT NULL,
      customer_name TEXT NOT NULL,
      customer_phone TEXT,
      amount_paid REAL NOT NULL,
      payment_date TEXT NOT NULL
    );
  ''';

  /// Insert new payment
  Future<int?> insertPayment({
    required int storeId,
    required int customerId,
    required String customerName,
    String? customerPhone,
    required double amountPaid,
    required String paymentDate, // ISO format: YYYY-MM-DD HH:mm:ss
  }) async {
    try {
      final database = await DBfactory.getDatabase();
      return await database.insert(db_table, {
        'store_id': storeId,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'amount_paid': amountPaid,
        'payment_date': paymentDate,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  /// Get all payments for a customer
  Future<List<Map<String, dynamic>>> getPaymentsByCustomer(int customerId) async {
    try {
      final database = await DBfactory.getDatabase();
      return await database.query(
        db_table,
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'id DESC',
      );
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
    }
  }

  /// Get all payments for a store
  Future<List<Map<String, dynamic>>> getPaymentsByStore(int storeId) async {
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

  /// Delete payment
  Future<bool> deletePayment(int id) async {
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
