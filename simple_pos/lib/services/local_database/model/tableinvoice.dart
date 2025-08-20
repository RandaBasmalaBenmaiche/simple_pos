import 'package:sqflite/sqflite.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';
import 'package:simple_pos/services/local_database/dbTable.dart';

// ==========================
// Invoice Table (summary)
// ==========================
class DInvoiceTable extends DBBaseTable {
  @override
  var db_table = 'invoices';

  // Create table SQL
  static String sql_code = '''
    CREATE TABLE invoices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      total TEXT NOT NULL
    );
  ''';

  /// Insert a new invoice and its items
  Future<int?> insertInvoice({
    required String date,
    required String total,
    required List<Map<String, dynamic>> items, // list of products
  }) async {
    try {
      final database = await DBfactory.getDatabase();

      // Insert invoice and get the inserted id
      int invoiceId = await database.insert(db_table, {
        'date': date,
        'total': total,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Insert items for this invoice
      final itemTable = DInvoiceItemsTable();
      for (var item in items) {
        await itemTable.insertRecord({
          'invoice_id': invoiceId,
          'productCodeBar': item['productCodeBar'],
          'productName': item['productName'],
          'quantity': item['quantity'],
          'totalPrice': item['totalPrice'],
        });
      }

      return invoiceId;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  /// Get all invoices
  Future<List<Map<String, dynamic>>> getInvoices() async {
    try {
      final database = await DBfactory.getDatabase();
      return await database.query(db_table, orderBy: 'id DESC');
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
    }
  }

  /// Get a specific invoice by ID
  Future<Map<String, dynamic>?> getInvoiceById(int id) async {
    try {
      final database = await DBfactory.getDatabase();
      List<Map<String, dynamic>> results =
          await database.query(db_table, where: 'id = ?', whereArgs: [id]);
      return results.isNotEmpty ? results.first : null;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

Future<int?> custinsertRecord(Map<String, dynamic> data) async {
  try {
    final database = await DBfactory.getDatabase();
    // Insert and get the row ID
    int id = await database.insert(
      db_table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print("inserted:\t");
    print(data.toString());
    return id; // return the inserted row ID
  } catch (e, stacktrace) {
    print('$e --> $stacktrace');
  }
  return null; // return null on failure
}

}

// ==========================
// Invoice Items Table
// ==========================
class DInvoiceItemsTable extends DBBaseTable {
  @override
  var db_table = 'invoice_items';

  static String sql_code = '''
    CREATE TABLE invoice_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL,
      productCodeBar TEXT NOT NULL,
      productName TEXT NOT NULL,
      quantity TEXT NOT NULL,
      price TEXT NOT NULL,
      totalPrice TEXT NOT NULL,
      FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
    );
  ''';

  /// Get all items for a specific invoice
  Future<List<Map<String, dynamic>>> getItemsByInvoiceId(int invoiceId) async {
    try {
      final database = await DBfactory.getDatabase();
      return await database.query(db_table,
          where: 'invoice_id = ?', whereArgs: [invoiceId]);
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
    }
  }

  /// Delete all items for a specific invoice
  Future<bool> deleteItemsByInvoiceId(int invoiceId) async {
    try {
      final database = await DBfactory.getDatabase();
      int count = await database
          .delete(db_table, where: 'invoice_id = ?', whereArgs: [invoiceId]);
      return count > 0;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }
}
