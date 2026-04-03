import 'package:sqflite/sqflite.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';
import 'package:simple_pos/services/local_database/dbTable.dart';

// ==========================
// Invoice Table (summary)
// ==========================
class DInvoiceTable extends DBBaseTable {
  @override
  var db_table = 'invoices';

  // Updated table SQL
  static String sql_code = '''
    CREATE TABLE invoices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      store_id INTEGER NOT NULL,
      customer_id INTEGER,
      customer_name TEXT,
      total_debt_customer TEXT DEFAULT '0',
      date TEXT NOT NULL,
      total TEXT NOT NULL,
      profit TEXT NOT NULL DEFAULT '0'
    );
  ''';

  /// Insert a new invoice with items for a specific store
  Future<int?> insertInvoice({
    required int storeId,
    required String date,
    required String total,
    String? customerName,
    int? customerId,
    String? totalDebtCustomer,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final database = await DBfactory.getDatabase();

      // Insert invoice with store_id, customer details, and total debt
      int invoiceId = await database.insert(db_table, {
        'store_id': storeId,
        'customer_id': customerId,
        'customer_name': customerName,
        'total_debt_customer': totalDebtCustomer ?? '0',
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
          'price': item['price'],
          'profit': item['profit'],
          'totalPrice': item['totalPrice'],
        });
      }

      return invoiceId;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  /// Get all invoices for a specific store
  Future<List<Map<String, dynamic>>> getInvoices(int storeId) async {
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

  /// Insert custom record (with storeId)
  Future<int?> custinsertRecord(Map<String, dynamic> data) async {
    try {
      final database = await DBfactory.getDatabase();
      int id = await database.insert(
        db_table,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print("inserted:\t$data");
      return id;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
    }
    return null;
  }

  /// Update invoice with new profit (or other fields)
  Future<bool> updateInvoice({
    required int id,
    String? total,
    double? profit,
    String? customerName,
    int? customerId,
    String? totalDebtCustomer,
  }) async {
    try {
      final database = await DBfactory.getDatabase();
      Map<String, dynamic> updatedFields = {};
      if (total != null) updatedFields['total'] = total;
      if (profit != null) updatedFields['profit'] = profit.toString();
      if (customerName != null) updatedFields['customer_name'] = customerName;
      if (customerId != null) updatedFields['customer_id'] = customerId;
      if (totalDebtCustomer != null) updatedFields['total_debt_customer'] = totalDebtCustomer;

      if (updatedFields.isEmpty) return false;

      int count = await database.update(
        db_table,
        updatedFields,
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  /// Reset debt of the invoice by fetching the latest debt of the customer
  Future<bool> resetDebt({required int invoiceId}) async {
    try {
      final database = await DBfactory.getDatabase();
      // Get invoice
      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null || invoice['customer_id'] == null) return false;

      final customerId = invoice['customer_id'];

      // Get customer debt from customers table
      final customerResult = await database.query(
        'customers',
        columns: ['debt'],
        where: 'id = ?',
        whereArgs: [customerId],
      );

      if (customerResult.isEmpty) return false;
      final debt = customerResult.first['debt']?.toString() ?? '0';

      // Update invoice
      return await updateInvoice(id: invoiceId, totalDebtCustomer: debt);
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
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
    profit TEXT NOT NULL,
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
