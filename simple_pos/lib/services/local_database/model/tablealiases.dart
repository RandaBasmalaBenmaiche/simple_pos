import 'package:simple_pos/services/local_database/dbFactory.dart';
import 'package:simple_pos/services/local_database/hive_database.dart';
import '../../supabase/web_runtime.dart';
import '../../sync/sync_service.dart';

class DAliasesTable {
  Future<int?> saveAlias({
    required int productId,
    required String productSyncId,
    required int storeId,
    required String storeSyncId,
    required String aliasName,
  }) async {
    try {
      final db = await DBfactory.getDatabase();
      final deviceId = await DBfactory.getDeviceId();

      // Check if alias already exists for this product and name to avoid duplicates
      final existing = await _findAliasByName(aliasName, storeId);
      if (existing != null && existing['product_id'] == productId) {
        return existing['id'] as int;
      }

      final id = await db.transaction((txn) async {
        final id = await DBfactory.allocateId(txn, 'product_aliases');
        final record = DBfactory.withSyncMetadata({
          'id': id,
          'product_id': productId,
          'product_sync_id': productSyncId,
          'alias_name': aliasName,
          'store_id': storeId,
          'store_sync_id': storeSyncId,
        }, deviceId: deviceId);
        await DBfactory.productAliasesStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(txn, table: 'product_aliases', record: record);
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
      print('Save alias error: $e --> $stacktrace');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAliasForName(String name, int storeId) async {
    try {
      final db = await DBfactory.getDatabase();
      final normalizedName = name.trim().toLowerCase();
      final snapshots = await DBfactory.productAliasesStore.find(db);
      for (final snapshot in snapshots) {
        final record = snapshot.value as Map<String, Object?>;
        if (record['alias_name']?.toString().trim().toLowerCase() == normalizedName &&
            record['store_id'] == storeId) {
          return _normalize(snapshot.key, record);
        }
      }
      return null;
    } catch (e, stacktrace) {
      print('Get alias error: $e --> $stacktrace');
      return null;
    }
  }

  Future<bool> deleteAlias(int id) async {
    try {
      final db = await DBfactory.getDatabase();
      final deleted = await db.transaction((txn) async {
        final existing = await DBfactory.productAliasesStore.record(id).get(txn);
        if (existing == null) return false;

        final syncId = existing['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) return false;

        await DBfactory.productAliasesStore.record(id).delete(txn);
        await DBfactory.queueDelete(
          txn,
          table: 'product_aliases',
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
      print('Delete alias error: $e --> $stacktrace');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _findAliasByName(String name, int storeId) async {
    final db = await DBfactory.getDatabase();
    final normalizedName = name.trim().toLowerCase();
    final snapshots = await DBfactory.productAliasesStore.find(db);
    for (final snapshot in snapshots) {
      final record = snapshot.value as Map<String, Object?>;
      if (record['alias_name']?.toString().trim().toLowerCase() == normalizedName &&
          record['store_id'] == storeId) {
        return _normalize(snapshot.key, record);
      }
    }
    return null;
  }

  Map<String, dynamic> _normalize(int id, Map<String, Object?> raw) {
    return {
      'id': id,
      'sync_id': raw['sync_id']?.toString(),
      'sync_status': raw['sync_status']?.toString() ?? 'pending',
      'updated_at': raw['updated_at']?.toString(),
      'last_synced_at': raw['last_synced_at']?.toString(),
      'device_id': raw['device_id']?.toString(),
      'product_id': raw['product_id'] as int? ?? 0,
      'product_sync_id': raw['product_sync_id']?.toString() ?? '',
      'alias_name': raw['alias_name']?.toString() ?? '',
      'store_id': raw['store_id'] as int? ?? 0,
      'store_sync_id': raw['store_sync_id']?.toString() ?? '',
    };
  }
}
