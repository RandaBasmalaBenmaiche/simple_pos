import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local_database/dbFactory.dart';
import '../local_database/hive_database.dart';
import '../supabase/supabase_project_config.dart';
import '../supabase/supabase_row_mapper.dart';

class SyncService with WidgetsBindingObserver {
  SyncService._();

  static final SyncService instance = SyncService._();
  static const List<String> _pullOrder = [
    'stores',
    'customers',
    'stock',
    'invoices',
    'invoice_items',
    'debt_payments',
  ];

  bool _initialized = false;
  bool _isSyncRunning = false;
  Timer? _timer;

  bool get isConfigured => SupabaseProjectConfig.isConfigured;
  bool get isAuthenticated =>
      isConfigured && Supabase.instance.client.auth.currentSession != null;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    if (!isConfigured) {
      return;
    }

    _timer = Timer.periodic(
      SupabaseProjectConfig.syncInterval,
      (_) => scheduleSync(),
    );
    unawaited(triggerSync());
  }

  void scheduleSync() {
    if (!isAuthenticated) {
      return;
    }
    unawaited(triggerSync());
  }

  Future<void> flush() => triggerSync();

  Future<void> triggerSync() async {
    if (!isAuthenticated || _isSyncRunning) {
      return;
    }

    _isSyncRunning = true;
    try {
      final db = await DBfactory.getDatabase();
      await _pushPendingOperations(db);
      await _pullRemoteChanges(db);
    } finally {
      _isSyncRunning = false;
    }
  }

  Future<void> _pushPendingOperations(HiveDatabase db) async {
    final pending = await DBfactory.syncOutboxStore.find(
      db,
      finder: Finder(sortOrders: [SortOrder('id')]),
    );

    for (final operation in pending) {
      final synced = await _syncOperation(db, operation);
      if (!synced) {
        break;
      }
    }
  }

  Future<void> _pullRemoteChanges(HiveDatabase db) async {
    for (final table in _pullOrder) {
      await _pullRemoteTable(db, table);
    }
  }

  Future<void> _pullRemoteTable(HiveDatabase db, String table) async {
    final store = DBfactory.syncManagedStores[table];
    if (store == null) {
      return;
    }

    final response = await Supabase.instance.client
        .from(table)
        .select()
        .order('updated_at');

    final rows = (response as List)
        .map((row) => SupabaseRowMapper.fromRemote(
              table,
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();

    await db.transaction((txn) async {
      for (final row in rows) {
        await _mergeRemoteRow(txn, table, store, row);
      }
    });
  }

  Future<void> _mergeRemoteRow(
    DatabaseClient txn,
    String table,
    StoreRef<int, Map<String, Object?>> store,
    Map<String, dynamic> remoteRow,
  ) async {
    final remoteSyncId = remoteRow['sync_id']?.toString();
    if (remoteSyncId == null || remoteSyncId.isEmpty) {
      return;
    }

    final existing = await _findLocalBySyncId(txn, store, remoteSyncId);
    final remoteUpdatedAt = remoteRow['updated_at']?.toString() ?? DBfactory.nowIso();

    if (existing != null) {
      final local = existing.value;
      final localUpdatedAt = local['updated_at']?.toString() ?? '';
      final localPending = local['sync_status']?.toString() == 'pending';
      final shouldKeepLocal =
          localPending && _compareIso(localUpdatedAt, remoteUpdatedAt) > 0;

      if (shouldKeepLocal) {
        return;
      }

      final normalized = await _buildLocalRecord(
        txn,
        table: table,
        localId: existing.key,
        remoteRow: remoteRow,
      );

      await store.record(existing.key).put(txn, normalized);
      await DBfactory.removeOutboxForRecord(
        txn,
        table: table,
        recordSyncId: remoteSyncId,
      );
      return;
    }

    final localId = await _assignLocalId(
      txn,
      table: table,
      store: store,
      remotePreferredId: (remoteRow['local_id'] as num?)?.toInt(),
    );

    final normalized = await _buildLocalRecord(
      txn,
      table: table,
      localId: localId,
      remoteRow: remoteRow,
    );

    await store.record(localId).put(txn, normalized);
  }

  Future<Map<String, Object?>> _buildLocalRecord(
    DatabaseClient txn, {
    required String table,
    required int localId,
    required Map<String, dynamic> remoteRow,
  }) async {
    final row = Map<String, Object?>.from(remoteRow);
    row['id'] = localId;
    row['local_id'] = remoteRow['local_id'];
    row['sync_status'] = 'synced';
    row['last_synced_at'] = DBfactory.nowIso();

    if (table == 'invoices') {
      final customerSyncId = remoteRow['customer_sync_id']?.toString();
      if (customerSyncId != null && customerSyncId.isNotEmpty) {
        final customer = await _findRecordBySyncId(
          txn,
          DBfactory.customersStore,
          customerSyncId,
        );
        if (customer != null) {
          row['customer_id'] = customer.key;
        }
      }
    } else if (table == 'invoice_items') {
      final invoiceSyncId = remoteRow['invoice_sync_id']?.toString();
      if (invoiceSyncId != null && invoiceSyncId.isNotEmpty) {
        final invoice = await _findRecordBySyncId(
          txn,
          DBfactory.invoicesStore,
          invoiceSyncId,
        );
        if (invoice != null) {
          row['invoice_id'] = invoice.key;
        }
      }
    } else if (table == 'debt_payments') {
      final customerSyncId = remoteRow['customer_sync_id']?.toString();
      if (customerSyncId != null && customerSyncId.isNotEmpty) {
        final customer = await _findRecordBySyncId(
          txn,
          DBfactory.customersStore,
          customerSyncId,
        );
        if (customer != null) {
          row['customer_id'] = customer.key;
        }
      }
    }

    return row;
  }

  Future<int> _assignLocalId(
    DatabaseClient txn, {
    required String table,
    required StoreRef<int, Map<String, Object?>> store,
    required int? remotePreferredId,
  }) async {
    if (remotePreferredId != null) {
      final existing = await store.record(remotePreferredId).get(txn);
      if (existing == null) {
        await DBfactory.reserveId(txn, table, remotePreferredId);
        return remotePreferredId;
      }
    }

    return DBfactory.allocateId(txn, table);
  }

  Future<RecordSnapshot<int, Map<String, Object?>>?> _findLocalBySyncId(
    DatabaseClient txn,
    StoreRef<int, Map<String, Object?>> store,
    String syncId,
  ) {
    return _findRecordBySyncId(txn, store, syncId);
  }

  Future<RecordSnapshot<int, Map<String, Object?>>?> _findRecordBySyncId(
    DatabaseClient txn,
    StoreRef<int, Map<String, Object?>> store,
    String syncId,
  ) async {
    final matches = await store.find(
      txn,
      finder: Finder(
        filter: Filter.equals('sync_id', syncId),
        limit: 1,
      ),
    );
    if (matches.isEmpty) {
      return null;
    }
    return matches.first;
  }

  int _compareIso(String left, String right) {
    final leftDate = DateTime.tryParse(left);
    final rightDate = DateTime.tryParse(right);

    if (leftDate == null && rightDate == null) return 0;
    if (leftDate == null) return -1;
    if (rightDate == null) return 1;
    return leftDate.compareTo(rightDate);
  }

  Future<bool> _syncOperation(
    HiveDatabase db,
    RecordSnapshot<int, Map<String, Object?>> operation,
  ) async {
    final row = operation.value;
    final table = row['table']?.toString();
    final action = row['operation']?.toString();
    final rawPayload = row['payload'];
    final payload = rawPayload is Map
        ? SupabaseRowMapper.toRemote(
            table ?? '',
            Map<String, dynamic>.from(rawPayload),
          )
        : <String, dynamic>{};

    if (table == null || table.isEmpty || action == null || action.isEmpty) {
      await DBfactory.syncOutboxStore.record(operation.key).delete(db);
      return true;
    }

    try {
      final query = Supabase.instance.client.from(table);

      if (action == 'delete') {
        final syncId = payload['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) {
          await DBfactory.syncOutboxStore.record(operation.key).delete(db);
          return true;
        }
        await query.delete().eq('sync_id', syncId);
      } else {
        await query.upsert(payload, onConflict: 'sync_id');

        final recordId = payload['local_id'];
        final updatedAt = payload['updated_at']?.toString();
        if (recordId is int && updatedAt != null && updatedAt.isNotEmpty) {
          await DBfactory.markRecordSynced(
            table: table,
            recordId: recordId,
            expectedUpdatedAt: updatedAt,
          );
        }
      }

      await DBfactory.syncOutboxStore.record(operation.key).delete(db);
      return true;
    } catch (error) {
      final nextRetry = ((row['retry_count'] as int?) ?? 0) + 1;
      await DBfactory.syncOutboxStore.record(operation.key).put(db, {
        ...row,
        'status': 'failed',
        'retry_count': nextRetry,
        'last_error': error.toString(),
        'updated_at': DBfactory.nowIso(),
      });
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      scheduleSync();
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
      _initialized = false;
    }
  }
}
