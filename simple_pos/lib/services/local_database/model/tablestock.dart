import 'package:simple_pos/services/local_database/dbFactory.dart';
import 'package:simple_pos/services/local_database/dbTable.dart';


class DStockTable extends DBBaseTable {
  @override
  var db_table = 'Products_Stock';

  static String sql_code = '''
  CREATE TABLE products_stock (
    id INTEGER PRIMARY KEY AUTOINCREMENT, 
    productName TEXT NOT NULL UNIQUE, 
    productPrice TEXT NOT NULL, 
    productCodeBar TEXT NOT NULL UNIQUE, 
    productQuantity TEXT NOT NULL
  );
  ''';


  /// Get product by code
  Future<Map<String, dynamic>?> getProductByCode(String codeBar) async {
    try {
      final database = await DBfactory.getDatabase();

      List<Map<String, dynamic>> results = await database.query(
        db_table,
        where: 'productCodeBar = ?',
        whereArgs: [codeBar],
      );

      return results.isNotEmpty ? results.first : null;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  /// Get product by name
  Future<Map<String, dynamic>?> getProductByName(String name) async {
    try {
      final database = await DBfactory.getDatabase();

      List<Map<String, dynamic>> results = await database.query(
        db_table,
        where: 'productName = ?',
        whereArgs: [name],
      );

      return results.isNotEmpty ? results.first : null;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  /// Update a product by its current code
  Future<bool> updateProduct({
    required String codeBar,
    String? newCodeBar,
    String? newName,
    String? newPrice,
    String? newQuantity,
  }) async {
    try {
      final database = await DBfactory.getDatabase();

      Map<String, dynamic> updatedFields = {};
      if (newCodeBar != null) updatedFields['productCodeBar'] = newCodeBar;
      if (newName != null) updatedFields['productName'] = newName;
      if (newPrice != null) updatedFields['productPrice'] = newPrice;
      if (newQuantity != null) updatedFields['productQuantity'] = newQuantity;

      if (updatedFields.isEmpty) return false;

      int count = await database.update(
        db_table,
        updatedFields,
        where: 'productCodeBar = ?',
        whereArgs: [codeBar],
      );

      return count > 0;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  /// Update a product by its current name
  Future<bool> updateProductByName({
    required String currentName,
    String? newCodeBar,
    String? newName,
    String? newPrice,
    String? newQuantity,
  }) async {
    try {
      final database = await DBfactory.getDatabase();

      Map<String, dynamic> updatedFields = {};
      if (newCodeBar != null) updatedFields['productCodeBar'] = newCodeBar;
      if (newName != null) updatedFields['productName'] = newName;
      if (newPrice != null) updatedFields['productPrice'] = newPrice;
      if (newQuantity != null) updatedFields['productQuantity'] = newQuantity;

      if (updatedFields.isEmpty) return false;

      int count = await database.update(
        db_table,
        updatedFields,
        where: 'productName = ?',
        whereArgs: [currentName],
      );

      return count > 0;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  /// Delete a product by its code
  Future<bool> deleteProduct(String codeBar) async {
    try {
      final database = await DBfactory.getDatabase();

      int count = await database.delete(
        db_table,
        where: 'productCodeBar = ?',
        whereArgs: [codeBar],
      );

      return count > 0;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  /// Delete a product by its name
  Future<bool> deleteProductByName(String name) async {
    try {
      final database = await DBfactory.getDatabase();

      int count = await database.delete(
        db_table,
        where: 'productName = ?',
        whereArgs: [name],
      );

      return count > 0;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

}
