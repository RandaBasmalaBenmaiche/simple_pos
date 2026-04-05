import '../dbFactory.dart';
import '../../sync/sync_service.dart';
import '../../supabase/web_runtime.dart';

class DDebtPaymentsTable {
  DDebtPaymentsTable();

  Future<int?> insertPayment({
    required int storeId,
    required int customerId,
    String? customerSyncId,
    required String customerName,
    String? customerPhone,
    required double amountPaid,
    required String paymentDate,
  }) async {
    try {
      final db = await DBfactory.getDatabase();
      final deviceId = await DBfactory.getDeviceId();
      final id = await db.transaction((txn) async {
        final id = await DBfactory.allocateId(txn, 'debt_payments');
        final record = DBfactory.withSyncMetadata({
          'id': id,
          'store_id': storeId,
          'customer_id': customerId,
          'customer_sync_id': customerSyncId,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'amount_paid': amountPaid,
          'payment_date': paymentDate,
        }, deviceId: deviceId);
        await DBfactory.debtPaymentsStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(
          txn,
          table: 'debt_payments',
          record: record,
        );
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

  Future<List<Map<String, dynamic>>> getPaymentsByCustomer(int customerId) async {
    try {
      final db = await DBfactory.getDatabase();
      final snapshots = await DBfactory.debtPaymentsStore.find(db);
      final payments = snapshots
          .map((snapshot) => _normalize(snapshot.key, snapshot.value))
          .where((payment) => payment['customer_id'] == customerId)
          .toList()
        ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      return payments;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPaymentsByStore(int storeId) async {
    try {
      final db = await DBfactory.getDatabase();
      final snapshots = await DBfactory.debtPaymentsStore.find(db);
      final payments = snapshots
          .map((snapshot) => _normalize(snapshot.key, snapshot.value))
          .where((payment) => payment['store_id'] == storeId)
          .toList()
        ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      return payments;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
    }
  }

  Future<bool> deletePayment(int id) async {
    try {
      final db = await DBfactory.getDatabase();
      final deleted = await db.transaction((txn) async {
        final existing = await DBfactory.debtPaymentsStore.record(id).get(txn);
        if (existing == null) return false;

        final syncId = existing['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) return false;

        await DBfactory.debtPaymentsStore.record(id).delete(txn);
        await DBfactory.queueDelete(
          txn,
          table: 'debt_payments',
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
      'customer_id': raw['customer_id'] as int? ?? 0,
      'customer_sync_id': raw['customer_sync_id']?.toString(),
      'customer_name': raw['customer_name']?.toString() ?? '',
      'customer_phone': raw['customer_phone']?.toString(),
      'amount_paid': (raw['amount_paid'] as num?)?.toDouble() ?? 0,
      'payment_date': raw['payment_date']?.toString() ?? '',
    };
  }
}
