import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';

class DBfactory {
  static const String databaseName = 'simple_pos.db';

  static Database? _database;

  static final StoreRef<String, Object?> _metaStore =
      StoreRef<String, Object?>('meta');
  static final StoreRef<int, Map<String, Object?>> storesStore =
      intMapStoreFactory.store('stores');
  static final StoreRef<int, Map<String, Object?>> stockStore =
      intMapStoreFactory.store('stock');
  static final StoreRef<int, Map<String, Object?>> customersStore =
      intMapStoreFactory.store('customers');
  static final StoreRef<int, Map<String, Object?>> debtPaymentsStore =
      intMapStoreFactory.store('debt_payments');
  static final StoreRef<int, Map<String, Object?>> invoicesStore =
      intMapStoreFactory.store('invoices');
  static final StoreRef<int, Map<String, Object?>> invoiceItemsStore =
      intMapStoreFactory.store('invoice_items');

  static Future<Database> getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    if (kIsWeb) {
      _database = await databaseFactoryWeb.openDatabase(databaseName);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, databaseName);
      _database = await databaseFactoryIo.openDatabase(dbPath);
    }

    await _ensureSeedData(_database!);
    return _database!;
  }

  static Future<void> _ensureSeedData(Database db) async {
    final storesCount = await storesStore.count(db);
    if (storesCount > 0) return;

    await db.transaction((txn) async {
      final firstId = await _nextId(txn, 'stores');
      await storesStore.record(firstId).put(txn, {
        'id': firstId,
        'name': 'Kiosque Djalil Ranim',
        'location': 'Annaba',
        'is_active': 1,
      });

      final secondId = await _nextId(txn, 'stores');
      await storesStore.record(secondId).put(txn, {
        'id': secondId,
        'name': 'Quincaillerie',
        'location': 'Annaba',
        'is_active': 1,
      });
    });
  }

  static Future<int> nextId(String key) async {
    final db = await getDatabase();
    return db.transaction((txn) => _nextId(txn, key));
  }

  static Future<int> allocateId(DatabaseClient client, String key) {
    return _nextId(client, key);
  }

  static Future<int> _nextId(DatabaseClient client, String key) async {
    final metaKey = '${key}_last_id';
    final lastValue = await _metaStore.record(metaKey).get(client) as int?;
    final nextValue = (lastValue ?? 0) + 1;
    await _metaStore.record(metaKey).put(client, nextValue);
    return nextValue;
  }

  static Future<void> clearDatabase() async {
    if (kIsWeb) {
      await databaseFactoryWeb.deleteDatabase(databaseName);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, databaseName);
      await databaseFactoryIo.deleteDatabase(dbPath);
    }
    _database = null;
  }
}
