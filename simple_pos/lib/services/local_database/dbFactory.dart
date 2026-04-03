import 'dart:async';
import 'package:simple_pos/services/local_database/model/tablecustomers.dart';
import 'package:simple_pos/services/local_database/model/tabledebt.dart';
import 'package:simple_pos/services/local_database/model/tableinvoice.dart';
import 'package:simple_pos/services/local_database/model/tablestores.dart';
import 'package:sqflite/sqflite.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:path/path.dart';



class DBfactory {
  static const _database_name = " POS_test_empty.db";
  static const _database_version = 1;
  static var database;

  static List<String> sql_codes = [DStoresTable.sql_code , DStoresTable.sql_code_create ,DStockTable.sql_code, DCustomersTable.sql_code, DDebtPaymentsTable.sql_code ,DInvoiceTable.sql_code , DInvoiceItemsTable.sql_code];
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
