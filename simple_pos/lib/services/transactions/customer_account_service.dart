import '../local_database/dbFactory.dart';
import '../sync/sync_service.dart';

class CustomerAccountService {
  Future<void> recordDebtPayment({
    required int storeId,
    required Map<String, dynamic> customer,
    required double amount,
  }) async {
    final db = await DBfactory.getDatabase();
    final deviceId = await DBfactory.getDeviceId();

    await db.transaction((txn) async {
      final customerId = customer['id'] as int;
      final existing = await DBfactory.customersStore.record(customerId).get(txn);
      if (existing == null) {
        throw StateError('Customer not found: $customerId');
      }

      final currentDebt = (existing['debt'] as num?)?.toDouble() ?? 0;
      final nextDebt = currentDebt - amount;

      final updatedCustomer = DBfactory.withSyncMetadata(
        {
          ...existing,
          'debt': nextDebt,
        },
        syncId: existing['sync_id']?.toString(),
        deviceId: existing['device_id']?.toString(),
      );

      await DBfactory.customersStore.record(customerId).put(txn, updatedCustomer);
      await DBfactory.queueUpsert(
        txn,
        table: 'customers',
        record: updatedCustomer,
      );

      final paymentId = await DBfactory.allocateId(txn, 'debt_payments');
      final paymentRecord = DBfactory.withSyncMetadata(
        {
          'id': paymentId,
          'store_id': storeId,
          'customer_id': customerId,
          'customer_sync_id': existing['sync_id']?.toString(),
          'customer_name': customer['name']?.toString() ?? '',
          'customer_phone': customer['phone']?.toString(),
          'amount_paid': amount,
          'payment_date': DateTime.now().toUtc().toIso8601String(),
        },
        deviceId: deviceId,
      );

      await DBfactory.debtPaymentsStore.record(paymentId).put(txn, paymentRecord);
      await DBfactory.queueUpsert(
        txn,
        table: 'debt_payments',
        record: paymentRecord,
      );
    });

    await SyncService.instance.flush();
  }
}
