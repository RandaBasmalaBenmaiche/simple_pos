import '../dbFactory.dart';
import '../../sync/sync_service.dart';
import '../../supabase/web_runtime.dart';

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
      final deviceId = await DBfactory.getDeviceId();
      final id = await db.transaction((txn) async {
        final id = await DBfactory.allocateId(txn, 'customers');
        final record = DBfactory.withSyncMetadata({
          'id': id,
          'store_id': storeId,
          'name': name,
          'phone': phone,
          'debt': debt,
        }, deviceId: deviceId);
        await DBfactory.customersStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(txn, table: 'customers', record: record);
        return id;
      });
      if (id != null) {
        if (useSupabaseWeb) {
          await SyncService.instance.flush();
        } else {
          SyncService.instance.scheduleSync();
        }
      }
      return id;
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
      final updated = await db.transaction((txn) async {
        final existing = await DBfactory.customersStore.record(id).get(txn);
        if (existing == null) return false;

        final merged = Map<String, Object?>.from(existing);
        if (name != null) merged['name'] = name;
        if (phone != null) merged['phone'] = phone;
        if (debt != null) merged['debt'] = debt;

        final record = DBfactory.withSyncMetadata(
          merged,
          syncId: existing['sync_id']?.toString(),
          deviceId: existing['device_id']?.toString(),
        );
        await DBfactory.customersStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(txn, table: 'customers', record: record);
        return true;
      });
      if (updated) {
        if (useSupabaseWeb) {
          await SyncService.instance.flush();
        } else {
          SyncService.instance.scheduleSync();
        }
      }
      return updated;
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
      final deleted = await db.transaction((txn) async {
        final existing = await DBfactory.customersStore.record(id).get(txn);
        if (existing == null) return false;

        final syncId = existing['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) return false;

        await DBfactory.customersStore.record(id).delete(txn);
        await DBfactory.queueDelete(
          txn,
          table: 'customers',
          recordId: id,
          recordSyncId: syncId,
        );
        return true;
      });
      if (deleted) {
        if (useSupabaseWeb) {
          await SyncService.instance.flush();
        } else {
          SyncService.instance.scheduleSync();
        }
      }
      return deleted;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  Map<String, dynamic> _normalize(int id, Map<String, Object?> raw) {
    return {
      'id': id,
      'sync_id': raw['sync_id']?.toString(),
      'sync_status': raw['sync_status']?.toString() ?? 'pending',
      'updated_at': raw['updated_at']?.toString(),
      'last_synced_at': raw['last_synced_at']?.toString(),
      'device_id': raw['device_id']?.toString(),
      'store_id': raw['store_id'] as int? ?? 0,
      'name': raw['name']?.toString() ?? '',
      'phone': raw['phone']?.toString(),
      'debt': (raw['debt'] as num?)?.toDouble() ?? 0,
    };
  }
}
