import '../dbFactory.dart';
import '../../sync/sync_service.dart';

class DStoresTable {
  DStoresTable();

  Future<int?> custinsertRecord(Map<String, dynamic> data) async {
    try {
      final db = await DBfactory.getDatabase();
      final deviceId = await DBfactory.getDeviceId();
      final id = await db.transaction((txn) async {
        final id = await DBfactory.allocateId(txn, 'stores');
        final record = DBfactory.withSyncMetadata({
          'id': id,
          'name': data['name']?.toString() ?? '',
          'location': data['location']?.toString(),
          'is_active': (data['is_active'] as int? ?? 1),
        }, deviceId: deviceId);
        await DBfactory.storesStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(txn, table: 'stores', record: record);
        return id;
      });
      if (id != null) {
        SyncService.instance.scheduleSync();
      }
      return id;
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
      final updated = await db.transaction((txn) async {
        final existing = await DBfactory.storesStore.record(id).get(txn);
        if (existing == null) return false;

        final merged = Map<String, Object?>.from(existing);
        if (name != null) merged['name'] = name;
        if (location != null) merged['location'] = location;
        if (isActive != null) merged['is_active'] = isActive ? 1 : 0;

        final record = DBfactory.withSyncMetadata(
          merged,
          syncId: existing['sync_id']?.toString(),
          deviceId: existing['device_id']?.toString(),
        );
        await DBfactory.storesStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(txn, table: 'stores', record: record);
        return true;
      });
      if (updated) {
        SyncService.instance.scheduleSync();
      }
      return updated;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  Future<bool> deleteStore(int id) async {
    try {
      final db = await DBfactory.getDatabase();
      final deleted = await db.transaction((txn) async {
        final existing = await DBfactory.storesStore.record(id).get(txn);
        if (existing == null) return false;

        final syncId = existing['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) return false;

        await DBfactory.storesStore.record(id).delete(txn);
        await DBfactory.queueDelete(
          txn,
          table: 'stores',
          recordId: id,
          recordSyncId: syncId,
        );
        return true;
      });
      if (deleted) {
        SyncService.instance.scheduleSync();
      }
      return deleted;
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
      'sync_id': raw['sync_id']?.toString(),
      'sync_status': raw['sync_status']?.toString() ?? 'pending',
      'updated_at': raw['updated_at']?.toString(),
      'last_synced_at': raw['last_synced_at']?.toString(),
      'device_id': raw['device_id']?.toString(),
      'name': raw['name']?.toString() ?? '',
      'location': raw['location']?.toString(),
      'is_active': (raw['is_active'] as int? ?? 0),
    };
  }
}
