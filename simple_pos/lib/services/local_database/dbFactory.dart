import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'hive_database.dart';

class DBfactory {
  static const String databaseName = 'simple_pos.db';
  static const _uuid = Uuid();

  static HiveDatabase? _database;

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
  static final StoreRef<int, Map<String, Object?>> syncOutboxStore =
      intMapStoreFactory.store('sync_outbox');

  static Map<String, StoreRef<int, Map<String, Object?>>> get syncManagedStores => {
        'stores': storesStore,
        'stock': stockStore,
        'customers': customersStore,
        'debt_payments': debtPaymentsStore,
        'invoices': invoicesStore,
        'invoice_items': invoiceItemsStore,
      };

  static Future<HiveDatabase> getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    _database = await HiveDatabase.open(databaseName);

    await _ensureSeedData(_database!);
    await _ensureSyncMetadata(_database!);
    return _database!;
  }

  static Future<void> _ensureSeedData(HiveDatabase db) async {
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
    if (_database != null) {
      await deleteHiveDatabase(_database!);
    }
    _database = null;
  }

  static Future<Object?> getMetaValue(String key) async {
    final db = await getDatabase();
    return _metaStore.record(key).get(db);
  }

  static Future<void> setMetaValue(String key, Object? value) async {
    final db = await getDatabase();
    if (value == null) {
      await _metaStore.record(key).delete(db);
      return;
    }
    await _metaStore.record(key).put(db, value);
  }

  static String nowIso() => DateTime.now().toUtc().toIso8601String();

  static Future<String> getDeviceId() async {
    final db = await getDatabase();
    return _getDeviceId(db);
  }

  static Future<String> _getDeviceId(DatabaseClient client) async {
    final existing = await _metaStore.record('device_id').get(client) as String?;
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final deviceId = _uuid.v4();
    await _metaStore.record('device_id').put(client, deviceId);
    return deviceId;
  }

  static Map<String, Object?> withSyncMetadata(
    Map<String, Object?> record, {
    String? syncId,
    String syncStatus = 'pending',
    String? updatedAt,
    String? lastSyncedAt,
    String? deviceId,
  }) {
    final now = updatedAt ?? nowIso();
    return {
      ...record,
      'sync_id': syncId ?? record['sync_id']?.toString() ?? _uuid.v4(),
      'sync_status': syncStatus,
      'updated_at': now,
      'last_synced_at': lastSyncedAt ?? record['last_synced_at']?.toString(),
      'device_id': deviceId ?? record['device_id']?.toString(),
    };
  }

  static Future<void> queueUpsert(
    DatabaseClient client, {
    required String table,
    required Map<String, Object?> record,
  }) async {
    final recordSyncId = record['sync_id']?.toString();
    if (recordSyncId == null || recordSyncId.isEmpty) {
      throw StateError('Cannot queue sync without sync_id for table $table');
    }

    final now = nowIso();
    final payload = Map<String, Object?>.from(record)
      ..['local_id'] = record['id']
      ..remove('id')
      ..remove('sync_status')
      ..remove('last_synced_at');
    final existing = await _findOutboxRecord(client, table, recordSyncId);

    final outboxData = <String, Object?>{
      'table': table,
      'record_id': record['id'],
      'record_sync_id': recordSyncId,
      'operation': 'upsert',
      'payload': payload,
      'status': 'pending',
      'retry_count': 0,
      'last_error': null,
      'created_at': existing?.value['created_at']?.toString() ?? now,
      'updated_at': now,
    };

    if (existing != null) {
      await syncOutboxStore.record(existing.key).put(client, {
        'id': existing.key,
        ...outboxData,
      });
      return;
    }

    final outboxId = await allocateId(client, 'sync_outbox');
    await syncOutboxStore.record(outboxId).put(client, {
      'id': outboxId,
      ...outboxData,
    });
  }

  static Future<void> queueDelete(
    DatabaseClient client, {
    required String table,
    required int recordId,
    required String recordSyncId,
  }) async {
    final existing = await _findOutboxRecord(client, table, recordSyncId);
    final now = nowIso();
    final payload = <String, Object?>{
      'sync_id': recordSyncId,
      'local_id': recordId,
      'deleted_at': now,
    };

    final outboxData = <String, Object?>{
      'table': table,
      'record_id': recordId,
      'record_sync_id': recordSyncId,
      'operation': 'delete',
      'payload': payload,
      'status': 'pending',
      'retry_count': 0,
      'last_error': null,
      'created_at': existing?.value['created_at']?.toString() ?? now,
      'updated_at': now,
    };

    if (existing != null) {
      await syncOutboxStore.record(existing.key).put(client, {
        'id': existing.key,
        ...outboxData,
      });
      return;
    }

    final outboxId = await allocateId(client, 'sync_outbox');
    await syncOutboxStore.record(outboxId).put(client, {
      'id': outboxId,
      ...outboxData,
    });
  }

  static Future<RecordSnapshot<int, Map<String, Object?>>?> _findOutboxRecord(
    DatabaseClient client,
    String table,
    String recordSyncId,
  ) async {
    final matches = await syncOutboxStore.find(
      client,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('table', table),
          Filter.equals('record_sync_id', recordSyncId),
        ]),
        limit: 1,
      ),
    );
    if (matches.isEmpty) {
      return null;
    }
    return matches.first;
  }

  static Future<void> removeOutboxForRecord(
    DatabaseClient client, {
    required String table,
    required String recordSyncId,
  }) async {
    final existing = await _findOutboxRecord(client, table, recordSyncId);
    if (existing == null) {
      return;
    }
    await syncOutboxStore.record(existing.key).delete(client);
  }

  static Future<void> reserveId(
    DatabaseClient client,
    String key,
    int id,
  ) async {
    final metaKey = '${key}_last_id';
    final lastValue = await _metaStore.record(metaKey).get(client) as int?;
    if (lastValue == null || id > lastValue) {
      await _metaStore.record(metaKey).put(client, id);
    }
  }

  static Future<void> markRecordSynced({
    required String table,
    required int recordId,
    required String expectedUpdatedAt,
  }) async {
    final store = syncManagedStores[table];
    if (store == null) return;

    final db = await getDatabase();
    await db.transaction((txn) async {
      final existing = await store.record(recordId).get(txn);
      if (existing == null) return;

      if (existing['updated_at']?.toString() != expectedUpdatedAt) {
        return;
      }

      await store.record(recordId).put(txn, {
        ...existing,
        'sync_status': 'synced',
        'last_synced_at': nowIso(),
      });
    });
  }

  static Future<void> _ensureSyncMetadata(HiveDatabase db) async {
    await db.transaction((txn) async {
      final deviceId = await _getDeviceId(txn);

      for (final entry in syncManagedStores.entries) {
        final tableName = entry.key;
        final store = entry.value;
        final snapshots = await store.find(txn);

        for (final snapshot in snapshots) {
          final raw = Map<String, Object?>.from(snapshot.value);
          final syncId = raw['sync_id']?.toString();
          final syncStatus = raw['sync_status']?.toString();

          final normalized = withSyncMetadata(
            raw,
            syncId: syncId,
            syncStatus: syncStatus ?? 'pending',
            updatedAt: raw['updated_at']?.toString(),
            lastSyncedAt: raw['last_synced_at']?.toString(),
            deviceId: raw['device_id']?.toString() ?? deviceId,
          );

          final changed =
              syncId == null ||
              syncId.isEmpty ||
              syncStatus == null ||
              raw['updated_at'] == null ||
              raw['device_id'] == null;

          if (changed) {
            await store.record(snapshot.key).put(txn, normalized);
          }

          if (changed || normalized['sync_status'] != 'synced') {
            await queueUpsert(
              txn,
              table: tableName,
              record: {
                ...normalized,
                'id': snapshot.key,
              },
            );
          }
        }
      }
    });
  }
}
