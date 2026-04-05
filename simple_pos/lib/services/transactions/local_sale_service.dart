import '../local_database/dbFactory.dart';
import '../local_database/hive_database.dart';
import '../sync/sync_service.dart';

class LocalSaleException implements Exception {
  LocalSaleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalSaleResult {
  const LocalSaleResult({
    required this.invoiceId,
    required this.invoiceSyncId,
    required this.total,
    required this.totalProfit,
    required this.customerDebtAfterSale,
  });

  final int invoiceId;
  final String invoiceSyncId;
  final double total;
  final double totalProfit;
  final double customerDebtAfterSale;
}

class LocalSaleService {
  Future<LocalSaleResult> sellCart({
    required int storeId,
    required List<Map<String, dynamic>> items,
    Map<String, dynamic>? customer,
    double? paidAmount,
  }) async {
    if (items.isEmpty) {
      throw LocalSaleException('السلة فارغة');
    }

    final db = await DBfactory.getDatabase();
    final deviceId = await DBfactory.getDeviceId();

    final result = await db.transaction((txn) async {
      final invoiceId = await DBfactory.allocateId(txn, 'invoices');
      final invoiceSyncId = DBfactory.withSyncMetadata(
        {'id': invoiceId},
        deviceId: deviceId,
      )['sync_id']!
          .toString();

      double invoiceTotal = 0;
      double invoiceProfit = 0;

      Map<String, Object?>? customerRecord;
      double customerDebtAfterSale = 0;

      if (customer != null) {
        customerRecord =
            await DBfactory.customersStore.record(customer['id'] as int).get(txn);
        if (customerRecord == null) {
          throw LocalSaleException('الزبون المحدد غير موجود');
        }
      }

      final productUpdates = <Map<String, Object?>>[];
      final invoiceItems = <Map<String, Object?>>[];

      for (final item in items) {
        final product = await _findProductForSale(txn, storeId, item);
        if (product == null) {
          throw LocalSaleException(
            'المنتج غير موجود: ${item['productName'] ?? item['productCodeBar'] ?? ''}',
          );
        }

        final requestedQty =
            int.tryParse(item['productQuantity']?.toString() ?? '0') ?? 0;
        if (requestedQty <= 0) {
          throw LocalSaleException('الكمية غير صالحة');
        }

        final availableQty =
            int.tryParse(product['productQuantity']?.toString() ?? '0') ?? 0;
        if (requestedQty > availableQty) {
          throw LocalSaleException(
            'الكمية المطلوبة (${requestedQty}) تفوق المخزون المتوفر (${availableQty}) للمنتج ${product['productName']}',
          );
        }

        final price =
            double.tryParse(item['productPrice']?.toString() ?? '0') ?? 0;
        final buyingPrice =
            double.tryParse(item['productBuyingPrice']?.toString() ?? '0') ?? 0;
        final lineTotal = price * requestedQty;
        final lineProfit = (price - buyingPrice) * requestedQty;

        invoiceTotal += lineTotal;
        invoiceProfit += lineProfit;

        final updatedProduct = DBfactory.withSyncMetadata(
          {
            ...product,
            'productQuantity': (availableQty - requestedQty).toString(),
          },
          syncId: product['sync_id']?.toString(),
          deviceId: product['device_id']?.toString(),
        );

        productUpdates.add(updatedProduct);
        invoiceItems.add({
          'productCodeBar': item['productCodeBar']?.toString() ?? '',
          'productName': item['productName']?.toString() ?? 'بدون اسم',
          'quantity': requestedQty.toString(),
          'price': price.toString(),
          'profit': lineProfit.toString(),
          'totalPrice': lineTotal.toStringAsFixed(2),
        });
      }

      if (paidAmount != null && paidAmount > invoiceTotal) {
        throw LocalSaleException('المبلغ المدفوع أكبر من مجموع الفاتورة');
      }

      if (customerRecord != null && paidAmount != null) {
        final currentDebt =
            (customerRecord['debt'] as num?)?.toDouble() ?? 0;
        final newDebt = currentDebt + (invoiceTotal - paidAmount);
        customerDebtAfterSale = newDebt;

        final updatedCustomer = DBfactory.withSyncMetadata(
          {
            ...customerRecord,
            'debt': newDebt,
          },
          syncId: customerRecord['sync_id']?.toString(),
          deviceId: customerRecord['device_id']?.toString(),
        );

        await DBfactory.customersStore
            .record(customer?['id'] as int)
            .put(txn, updatedCustomer);
        await DBfactory.queueUpsert(
          txn,
          table: 'customers',
          record: updatedCustomer,
        );
      } else if (customerRecord != null) {
        customerDebtAfterSale =
            (customerRecord['debt'] as num?)?.toDouble() ?? 0;
      }

      final invoiceRecord = DBfactory.withSyncMetadata({
        'id': invoiceId,
        'store_id': storeId,
        'date': DateTime.now().toUtc().toIso8601String(),
        'total': invoiceTotal.toStringAsFixed(2),
        'customer_name': customer?['name']?.toString(),
        'customer_id': customer?['id'] as int?,
        'customer_sync_id': customerRecord?['sync_id']?.toString(),
        'total_debt_customer': customerDebtAfterSale.toStringAsFixed(2),
        'profit': invoiceProfit.toStringAsFixed(2),
      }, syncId: invoiceSyncId, deviceId: deviceId);

      await DBfactory.invoicesStore.record(invoiceId).put(txn, invoiceRecord);
      await DBfactory.queueUpsert(
        txn,
        table: 'invoices',
        record: invoiceRecord,
      );

      for (final updatedProduct in productUpdates) {
        final productId = updatedProduct['id'] as int;
        await DBfactory.stockStore.record(productId).put(txn, updatedProduct);
        await DBfactory.queueUpsert(
          txn,
          table: 'stock',
          record: updatedProduct,
        );
      }

      for (final item in invoiceItems) {
        final invoiceItemId = await DBfactory.allocateId(txn, 'invoice_items');
        final invoiceItemRecord = DBfactory.withSyncMetadata({
          'id': invoiceItemId,
          'invoice_id': invoiceId,
          'invoice_sync_id': invoiceSyncId,
          ...item,
        }, deviceId: deviceId);

        await DBfactory.invoiceItemsStore
            .record(invoiceItemId)
            .put(txn, invoiceItemRecord);
        await DBfactory.queueUpsert(
          txn,
          table: 'invoice_items',
          record: invoiceItemRecord,
        );
      }

      return LocalSaleResult(
        invoiceId: invoiceId,
        invoiceSyncId: invoiceSyncId,
        total: invoiceTotal,
        totalProfit: invoiceProfit,
        customerDebtAfterSale: customerDebtAfterSale,
      );
    });

    await SyncService.instance.flush();
    return result;
  }

  Future<Map<String, Object?>?> _findProductForSale(
    DatabaseClient txn,
    int storeId,
    Map<String, dynamic> item,
  ) async {
    final code = item['productCodeBar']?.toString();
    final name = item['productName']?.toString()?.trim().toLowerCase();
    final snapshots = await DBfactory.stockStore.find(
      txn,
      finder: Finder(filter: Filter.equals('store_id', storeId)),
    );

    for (final snapshot in snapshots) {
      final record = Map<String, Object?>.from(snapshot.value);
      final recordName =
          record['productName']?.toString().trim().toLowerCase() ?? '';
      final sameCode = code != null &&
          code.isNotEmpty &&
          record['productCodeBar']?.toString() == code;
      final sameName = name != null &&
          name.isNotEmpty &&
          recordName == name;

      if (sameCode || sameName) {
        return {
          ...record,
          'id': snapshot.key,
        };
      }
    }

    return null;
  }
}
