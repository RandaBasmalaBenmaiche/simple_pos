import 'package:sembast/sembast.dart';

import '../dbFactory.dart';

class DStoresTable {
  DStoresTable();

  Future<int?> custinsertRecord(Map<String, dynamic> data) async {
    try {
      final db = await DBfactory.getDatabase();
      return db.transaction((txn) async {
        final id = await DBfactory.allocateId(txn, 'stores');
        await DBfactory.storesStore.record(id).put(txn, {
          'id': id,
          'name': data['name']?.toString() ?? '',
          'location': data['location']?.toString(),
          'is_active': (data['is_active'] as int? ?? 1),
        });
        return id;
      });
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  Future<int?> insertStore({
    required String name,
    String? location,
    bool isActive = true,
  }) async {
    return custinsertRecord({
      'name': name,
      'location': location,
      'is_active': isActive ? 1 : 0,
    });
  }

  Future<List<Map<String, dynamic>>> getStores({bool? onlyActive}) async {
    try {
      final db = await DBfactory.getDatabase();
      final snapshots = await DBfactory.storesStore.find(db);
      final stores = snapshots
          .map((snapshot) => _normalize(snapshot.key, snapshot.value))
          .where((store) => onlyActive == null
              ? true
              : ((store['is_active'] as int? ?? 0) == (onlyActive ? 1 : 0)))
          .toList()
        ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      return stores;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStoreById(int id) async {
    try {
      final db = await DBfactory.getDatabase();
      final record = await DBfactory.storesStore.record(id).get(db);
      if (record == null) return null;
      return _normalize(id, record);
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  Future<bool> updateStore({
    required int id,
    String? name,
    String? location,
    bool? isActive,
  }) async {
    try {
      final db = await DBfactory.getDatabase();
      final existing = await DBfactory.storesStore.record(id).get(db);
      if (existing == null) return false;

      final updated = Map<String, Object?>.from(existing);
      if (name != null) updated['name'] = name;
      if (location != null) updated['location'] = location;
      if (isActive != null) updated['is_active'] = isActive ? 1 : 0;

      await DBfactory.storesStore.record(id).put(db, updated);
      return true;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  Future<bool> deleteStore(int id) async {
    try {
      final db = await DBfactory.getDatabase();
      await DBfactory.storesStore.record(id).delete(db);
      return true;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  Future<int> countStores({bool? onlyActive}) async {
    final stores = await getStores(onlyActive: onlyActive);
    return stores.length;
  }

  Map<String, dynamic> _normalize(int id, Map<String, Object?> raw) {
    return {
      'id': id,
      'name': raw['name']?.toString() ?? '',
      'location': raw['location']?.toString(),
      'is_active': (raw['is_active'] as int? ?? 0),
    };
  }
}
