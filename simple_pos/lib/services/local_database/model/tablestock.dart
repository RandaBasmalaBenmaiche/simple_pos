import 'dart:io';
import 'package:simple_pos/services/local_database/dbFactory.dart';
import 'package:simple_pos/services/local_database/dbTable.dart';
import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';


class DStockTable extends DBBaseTable {
  @override
  var db_table = 'products_stock';

  static String sql_code = '''
  CREATE TABLE products_stock (
    id INTEGER PRIMARY KEY AUTOINCREMENT, 
    store_id INTEGER NOT NULL,
    productName TEXT NOT NULL,
    productPrice TEXT NOT NULL, 
    productBuyingPrice TEXT NOT NULL,
    productCodeBar TEXT NOT NULL, 
    productQuantity TEXT NOT NULL,
    UNIQUE(store_id, productCodeBar),
    UNIQUE(store_id, productName)
  );
  ''';

  /// Insert new product
  Future<int?> insertProduct({
    required int storeId,
    required String name,
    required String price,
    required String buyingPrice,
    required String codeBar,
    required String quantity,
  }) async {
    print("the insert func was called");
    try {
      final database = await DBfactory.getDatabase();
      return await database.insert(
        db_table,
        {
          'store_id': storeId,
          'productName': name,
          'productPrice': price,
          'productBuyingPrice': buyingPrice,
          'productCodeBar': codeBar,
          'productQuantity': quantity,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stacktrace) {
      print('Insert error: $e --> $stacktrace');
      return null;
    }
  }

  /// Get product by code for specific store
  Future<Map<String, dynamic>?> getProductByCode(String codeBar, int storeId) async {
    try {
      final database = await DBfactory.getDatabase();
      List<Map<String, dynamic>> results = await database.query(
        db_table,
        where: 'productCodeBar = ? AND store_id = ?',
        whereArgs: [codeBar, storeId],
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  /// Get product by name for specific store
  Future<Map<String, dynamic>?> getProductByName(String name, int storeId) async {
    try {
      final database = await DBfactory.getDatabase();
      List<Map<String, dynamic>> results = await database.query(
        db_table,
        where: 'productName = ? AND store_id = ?',
        whereArgs: [name, storeId],
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  /// Update product by code for specific store
  Future<bool> updateProduct({
    required String codeBar,
    required int storeId,
    String? newCodeBar,
    String? newName,
    String? newPrice,
    String? newBuyingPrice,
    String? newQuantity,
  }) async {
    try {
      final database = await DBfactory.getDatabase();
      Map<String, dynamic> updatedFields = {};
      if (newCodeBar != null) updatedFields['productCodeBar'] = newCodeBar;
      if (newName != null) updatedFields['productName'] = newName;
      if (newPrice != null) updatedFields['productPrice'] = newPrice;
      if (newBuyingPrice != null) updatedFields['productBuyingPrice'] = newBuyingPrice;
      if (newQuantity != null) updatedFields['productQuantity'] = newQuantity;
      if (updatedFields.isEmpty) return false;

      int count = await database.update(
        db_table,
        updatedFields,
        where: 'productCodeBar = ? AND store_id = ?',
        whereArgs: [codeBar, storeId],
      );
      return count > 0;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  /// Delete a product for specific store
  Future<bool> deleteProduct(String codeBar, int storeId) async {
    try {
      final database = await DBfactory.getDatabase();
      int count = await database.delete(
        db_table,
        where: 'productCodeBar = ? AND store_id = ?',
        whereArgs: [codeBar, storeId],
      );
      return count > 0;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  /// Get all products for a store
  Future<List<Map<String, dynamic>>> getProductsByStore(int storeId) async {
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

  /// Import products from CSV for a specific store
  Future<void> importFromCsv(File csvFile, int storeId) async {
    try {
      final database = await DBfactory.getDatabase();
      final content = await csvFile.readAsString();
      List<List<dynamic>> rows = const CsvToListConverter().convert(content);

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        await database.insert(
          db_table,
          {
            'store_id': storeId,
            'productName': row[0].toString(),
            'productPrice': row[1].toString(),
            'productBuyingPrice': row[2].toString(),
            'productCodeBar': row[3].toString(),
            'productQuantity': row[4].toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e, stacktrace) {
      print("Error importing CSV: $e --> $stacktrace");
    }
  }

  /// Export products for a specific store
  Future<void> exportToCsv(File csvFile, int storeId) async {
    try {
      final database = await DBfactory.getDatabase();
      final records = await database.query(
        db_table,
        where: 'store_id = ?',
        whereArgs: [storeId],
      );
      List<List<dynamic>> rows = [
        ['productName','productPrice','productBuyingPrice','productCodeBar','productQuantity'],
        ...records.map((r) => [
          r['productName'],
          r['productPrice'],
          r['productBuyingPrice'],
          r['productCodeBar'],
          r['productQuantity'],
        ])
      ];
      String csv = const ListToCsvConverter().convert(rows);
      await csvFile.writeAsString(csv);
    } catch (e, stacktrace) {
      print("Error exporting CSV: $e --> $stacktrace");
    }
  }
}

