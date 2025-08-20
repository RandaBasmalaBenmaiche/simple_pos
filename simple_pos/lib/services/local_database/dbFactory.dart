import 'dart:async';
import 'package:simple_pos/services/local_database/model/tableinvoice.dart';
import 'package:sqflite/sqflite.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:path/path.dart';



class DBfactory {
  static const _database_name = " POS_DB_tt.db";
  static const _database_version = 1;
  static var database;

  static List<String> sql_codes = [DStockTable.sql_code, DInvoiceTable.sql_code , DInvoiceItemsTable.sql_code];
  static Future<Database> getDatabase() async {

    if (database != null) {
      return database;
    }

    database = openDatabase(
      join(await getDatabasesPath(), _database_name),
      onCreate: (db, version) {
        for (var item in sql_codes) {
          db.execute(item);
        }
      },
      version: _database_version,
      onUpgrade: (db, oldVersion, newVersion) {
        //do nothing... to handle in case we change the db schema in other versions
      },
    );
    return database;
  }
}
