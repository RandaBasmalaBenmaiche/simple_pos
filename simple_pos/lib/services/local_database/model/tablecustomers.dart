import 'package:sembast/sembast.dart';

import '../dbFactory.dart';

class DCustomersTable {
  DCustomersTable();

  Future<int?> insertCustomer({
    required int storeId,
    required String name,
    String? phone,
    double debt = 0,
  }) async {
    try {
      final db = await DBfactory.getDatabase();
      return db.transaction((txn) async {
        final id = await DBfactory.allocateId(txn, 'customers');
        await DBfactory.customersStore.record(id).put(txn, {
          'id': id,
          'store_id': storeId,
          'name': name,
          'phone': phone,
          'debt': debt,
        });
        return id;
      });
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCustomers(int storeId) async {
    try {
      final db = await DBfactory.getDatabase();
      final snapshots = await DBfactory.customersStore.find(db);
      final customers = snapshots
          .map((snapshot) => _normalize(snapshot.key, snapshot.value))
          .where((customer) => customer['store_id'] == storeId)
          .toList()
        ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      return customers;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    try {
      final db = await DBfactory.getDatabase();
      final record = await DBfactory.customersStore.record(id).get(db);
      if (record == null) return null;
      return _normalize(id, record);
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  Future<int> getNextCustomerId() async {
    try {
      final db = await DBfactory.getDatabase();
      final snapshots = await DBfactory.customersStore.find(db);
      if (snapshots.isEmpty) return 1;
      final maxId = snapshots
          .map((snapshot) => snapshot.key)
          .fold<int>(0, (prev, id) => id > prev ? id : prev);
      return maxId + 1;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return 1;
    }
  }

  static String formatCustomerId(int id) {
    return id.toString().padLeft(3, '0');
  }

  Future<bool> updateCustomer({
    required int id,
    String? name,
    String? phone,
    double? debt,
  }) async {
    try {
      final db = await DBfactory.getDatabase();
      final existing = await DBfactory.customersStore.record(id).get(db);
      if (existing == null) return false;

      final updated = Map<String, Object?>.from(existing);
      if (name != null) updated['name'] = name;
      if (phone != null) updated['phone'] = phone;
      if (debt != null) updated['debt'] = debt;

      await DBfactory.customersStore.record(id).put(db, updated);
      return true;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerByName(
    String name,
    int storeId,
  ) async {
    try {
      final normalizedQuery = name.trim().toLowerCase();
      final customers = await getCustomers(storeId);
      return customers
          .where((customer) => customer['name']
              .toString()
              .toLowerCase()
              .contains(normalizedQuery))
          .toList()
        ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
    }
  }

  Future<bool> deleteCustomer(int id) async {
    try {
      final db = await DBfactory.getDatabase();
      await DBfactory.customersStore.record(id).delete(db);
      return true;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  Map<String, dynamic> _normalize(int id, Map<String, Object?> raw) {
    return {
      'id': id,
      'store_id': raw['store_id'] as int? ?? 0,
      'name': raw['name']?.toString() ?? '',
      'phone': raw['phone']?.toString(),
      'debt': (raw['debt'] as num?)?.toDouble() ?? 0,
    };
  }
}
