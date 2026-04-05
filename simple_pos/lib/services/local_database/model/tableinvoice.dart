import '../dbFactory.dart';
import 'tablecustomers.dart';
import '../../sync/sync_service.dart';
import '../../supabase/web_runtime.dart';

class DInvoiceTable {
  DInvoiceTable();

  Future<int?> insertInvoice({
    required int storeId,
    required String date,
    required String total,
    String? customerName,
    int? customerId,
    String? totalDebtCustomer,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final invoiceId = await custinsertRecord({
        'store_id': storeId,
        'date': date,
        'total': total,
        'customer_name': customerName,
        'customer_id': customerId,
        'total_debt_customer': totalDebtCustomer,
      });

      if (invoiceId == null) return null;

      for (final item in items) {
        await DInvoiceItemsTable().insertItem({
          'invoice_id': invoiceId,
          ...item,
        });
      }

      return invoiceId;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getInvoices(int storeId) async {
    try {
      final db = await DBfactory.getDatabase();
      final snapshots = await DBfactory.invoicesStore.find(db);
      final invoices = snapshots
          .map((snapshot) => _normalize(snapshot.key, snapshot.value))
          .where((invoice) => invoice['store_id'] == storeId)
          .toList()
        ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      return invoices;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getInvoiceById(int id) async {
    try {
      final db = await DBfactory.getDatabase();
      final record = await DBfactory.invoicesStore.record(id).get(db);
      if (record == null) return null;
      return _normalize(id, record);
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  Future<int?> custinsertRecord(Map<String, dynamic> data) async {
    try {
      final db = await DBfactory.getDatabase();
      final deviceId = await DBfactory.getDeviceId();
      final id = await db.transaction((txn) async {
        final id = await DBfactory.allocateId(txn, 'invoices');
        final record = DBfactory.withSyncMetadata({
          'id': id,
          'store_id': data['store_id'] as int? ?? 0,
          'date': data['date']?.toString() ?? '',
          'total': data['total']?.toString() ?? '',
          'customer_name': data['customer_name']?.toString(),
          'customer_id': data['customer_id'] as int?,
          'customer_sync_id': data['customer_sync_id']?.toString(),
          'total_debt_customer':
              data['total_debt_customer']?.toString() ?? '0',
          'profit': data['profit']?.toString() ?? '0',
        }, deviceId: deviceId);
        await DBfactory.invoicesStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(txn, table: 'invoices', record: record);
        print('inserted:\t$data');
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

  Future<bool> updateInvoice({
    required int id,
    String? total,
    double? profit,
    String? customerName,
    int? customerId,
    String? totalDebtCustomer,
  }) async {
    try {
      final db = await DBfactory.getDatabase();
      final updated = await db.transaction((txn) async {
        final existing = await DBfactory.invoicesStore.record(id).get(txn);
        if (existing == null) return false;

        final merged = Map<String, Object?>.from(existing);
        if (total != null) merged['total'] = total;
        if (profit != null) merged['profit'] = profit.toString();
        if (customerName != null) merged['customer_name'] = customerName;
        if (customerId != null) merged['customer_id'] = customerId;
        if (totalDebtCustomer != null) {
          merged['total_debt_customer'] = totalDebtCustomer;
        }

        final record = DBfactory.withSyncMetadata(
          merged,
          syncId: existing['sync_id']?.toString(),
          deviceId: existing['device_id']?.toString(),
        );
        await DBfactory.invoicesStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(txn, table: 'invoices', record: record);
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

  Future<bool> resetDebt({required int invoiceId}) async {
    try {
      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null || invoice['customer_id'] == null) return false;

      final customerId = invoice['customer_id'] as int;
      final customer = await DCustomersTable().getCustomerById(customerId);
      if (customer == null) return false;

      return updateInvoice(
        id: invoiceId,
        totalDebtCustomer: customer['debt'].toString(),
      );
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
      'customer_id': raw['customer_id'] as int?,
      'customer_sync_id': raw['customer_sync_id']?.toString(),
      'customer_name': raw['customer_name']?.toString(),
      'total_debt_customer': raw['total_debt_customer']?.toString() ?? '0',
      'date': raw['date']?.toString() ?? '',
      'total': raw['total']?.toString() ?? '',
      'profit': raw['profit']?.toString() ?? '0',
    };
  }
}

class DInvoiceItemsTable {
  DInvoiceItemsTable();

  Future<List<Map<String, dynamic>>> getItemsByInvoiceId(int invoiceId) async {
    try {
      final db = await DBfactory.getDatabase();
      final snapshots = await DBfactory.invoiceItemsStore.find(db);
      return snapshots
          .map((snapshot) => _normalize(snapshot.key, snapshot.value))
          .where((item) => item['invoice_id'] == invoiceId)
          .toList()
        ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
    }
  }

  Future<bool> deleteItemsByInvoiceId(int invoiceId) async {
    try {
      final db = await DBfactory.getDatabase();
      final items = await getItemsByInvoiceId(invoiceId);
      for (final item in items) {
        await DBfactory.invoiceItemsStore.record(item['id'] as int).delete(db);
      }
      return true;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  Future<int?> insertItem(Map<String, dynamic> item) async {
    try {
      final db = await DBfactory.getDatabase();
      final deviceId = await DBfactory.getDeviceId();
      final id = await db.transaction((txn) async {
        final id = await DBfactory.allocateId(txn, 'invoice_items');
        final record = DBfactory.withSyncMetadata({
          'id': id,
          'invoice_id': item['invoice_id'] as int? ?? 0,
          'invoice_sync_id': item['invoice_sync_id']?.toString(),
          'productCodeBar': item['productCodeBar']?.toString() ?? '',
          'productName': item['productName']?.toString() ?? '',
          'quantity': item['quantity']?.toString() ?? '',
          'price': item['price']?.toString() ?? '',
          'profit': item['profit']?.toString() ?? '',
          'totalPrice': item['totalPrice']?.toString() ?? '',
        }, deviceId: deviceId);
        await DBfactory.invoiceItemsStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(
          txn,
          table: 'invoice_items',
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

  Future<List<int>> insertItems(List<Map<String, dynamic>> items) async {
    final ids = <int>[];
    try {
      for (final item in items) {
        final id = await insertItem(item);
        if (id != null) {
          ids.add(id);
        }
      }
      return ids;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
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
      'invoice_id': raw['invoice_id'] as int? ?? 0,
      'invoice_sync_id': raw['invoice_sync_id']?.toString(),
      'productCodeBar': raw['productCodeBar']?.toString() ?? '',
      'productName': raw['productName']?.toString() ?? '',
      'quantity': raw['quantity']?.toString() ?? '',
      'price': raw['price']?.toString() ?? '',
      'totalPrice': raw['totalPrice']?.toString() ?? '',
      'profit': raw['profit']?.toString() ?? '',
    };
  }
}
