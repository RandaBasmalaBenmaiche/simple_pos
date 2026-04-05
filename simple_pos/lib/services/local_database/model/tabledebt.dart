import 'package:sembast/sembast.dart';

import '../dbFactory.dart';

class DDebtPaymentsTable {
  DDebtPaymentsTable();

  Future<int?> insertPayment({
    required int storeId,
    required int customerId,
    required String customerName,
    String? customerPhone,
    required double amountPaid,
    required String paymentDate,
  }) async {
    try {
      final db = await DBfactory.getDatabase();
      return db.transaction((txn) async {
        final id = await DBfactory.allocateId(txn, 'debt_payments');
        await DBfactory.debtPaymentsStore.record(id).put(txn, {
          'id': id,
          'store_id': storeId,
          'customer_id': customerId,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'amount_paid': amountPaid,
          'payment_date': paymentDate,
        });
        return id;
      });
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
      await DBfactory.debtPaymentsStore.record(id).delete(db);
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
      'customer_id': raw['customer_id'] as int? ?? 0,
      'customer_name': raw['customer_name']?.toString() ?? '',
      'customer_phone': raw['customer_phone']?.toString(),
      'amount_paid': (raw['amount_paid'] as num?)?.toDouble() ?? 0,
      'payment_date': raw['payment_date']?.toString() ?? '',
    };
  }
}
