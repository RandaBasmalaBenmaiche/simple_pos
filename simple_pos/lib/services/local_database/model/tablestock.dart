import 'package:csv/csv.dart';
import 'package:simple_pos/services/notification_service.dart';

import '../dbFactory.dart';
import '../../sync/sync_service.dart';
import '../../supabase/web_runtime.dart';

class DStockTable {
  DStockTable({Object? isar});

  Future<int?> insertProduct({
    int? storeId,
    required String name,
    String? price,
    String? buyingPrice,
    String? codeBar,
    String? quantity,
    int? minStock,
  }) async {
    try {
      final db = await DBfactory.getDatabase();
      final deviceId = await DBfactory.getDeviceId();
      final id = await db.transaction((txn) async {
        final id = await DBfactory.allocateId(txn, 'stock');
        final record = DBfactory.withSyncMetadata({
          'id': id,
          'store_id': storeId ?? 0,
          'productName': name,
          'productPrice': price,
          'productBuyingPrice': buyingPrice,
          'productCodeBar': codeBar,
          'productQuantity': quantity,
          'min_stock': minStock ?? 0,
        }, deviceId: deviceId);
        await DBfactory.stockStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(txn, table: 'stock', record: record);
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
      print('Insert error: $e --> $stacktrace');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getProductById(int id) async {
    try {
      final db = await DBfactory.getDatabase();
      final record = await DBfactory.stockStore.record(id).get(db);
      if (record == null) return null;
      return _normalize(id, record);
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getProductByCode(String codeBar, int? storeId) async {
    try {
      final products = await getProductsByStore(storeId);
      for (final product in products) {
        if ((product['productCodeBar'] ?? '') == codeBar) {
          return product;
        }
      }
      return null;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getProductByName(String name, int? storeId) async {
    try {
      final normalizedName = name.trim().toLowerCase();
      final products = await getProductsByStore(storeId);
      for (final product in products) {
        if (product['productName'].toString().trim().toLowerCase() ==
            normalizedName) {
          return product;
        }
      }
      return null;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  Future<bool> updateProduct({
    required String codeBar,
    int? storeId,
    String? newCodeBar,
    String? newName,
    String? newPrice,
    String? newBuyingPrice,
    String? newQuantity,
  }) async {
    try {
      final product = await getProductByCode(codeBar, storeId);
      if (product == null) return false;
      return updateProductById(
        id: product['id'] as int,
        newCodeBar: newCodeBar,
        newName: newName,
        newPrice: newPrice,
        newBuyingPrice: newBuyingPrice,
        newQuantity: newQuantity,
      );
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  Future<bool> updateProductByName({
    required String name,
    int? storeId,
    String? newCodeBar,
    String? newName,
    String? newPrice,
    String? newBuyingPrice,
    String? newQuantity,
  }) async {
    try {
      final product = await getProductByName(name, storeId);
      if (product == null) return false;
      return updateProductById(
        id: product['id'] as int,
        newCodeBar: newCodeBar,
        newName: newName,
        newPrice: newPrice,
        newBuyingPrice: newBuyingPrice,
        newQuantity: newQuantity,
      );
    } catch (e, stacktrace) {
      print('Error updating by name: $e --> $stacktrace');
      return false;
    }
  }

  Future<bool> deleteProduct(String codeBar, int? storeId) async {
    try {
      final product = await getProductByCode(codeBar, storeId);
      if (product == null) return false;
      return deleteProductById(product['id'] as int);
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return false;
    }
  }

  Future<bool> updateStockAndMinStock({
    required int id,
    double? addAmount,
    int? newMinStock,
  }) async {
    try {
      final db = await DBfactory.getDatabase();
      final updated = await db.transaction((txn) async {
        final existing = await DBfactory.stockStore.record(id).get(txn);
        if (existing == null) return false;

        final merged = Map<String, Object?>.from(existing);

        if (addAmount != null) {
          final currentQty = double.tryParse(existing['productQuantity']?.toString() ?? '0') ?? 0;
          merged['productQuantity'] = (currentQty + addAmount).toString();
        }

        if (newMinStock != null) {
          merged['min_stock'] = newMinStock;
        }

        final record = DBfactory.withSyncMetadata(
          merged,
          syncId: existing['sync_id']?.toString(),
          deviceId: existing['device_id']?.toString(),
        );
        await DBfactory.stockStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(txn, table: 'stock', record: record);
        return true;
      });

      if (updated) {
        if (useSupabaseWeb) {
          await SyncService.instance.flush();
        } else {
          SyncService.instance.scheduleSync();
        }

        // Trigger notification check
        final product = await getProductById(id);
        if (product != null) {
          await NotificationService.instance.checkAndCreateNotification(
            storeId: product['store_id'] as int? ?? 0,
            productId: id,
            currentQty: double.tryParse(product['productQuantity']?.toString() ?? '0') ?? 0,
            minStock: product['min_stock'] as int? ?? 0,
          );
        }
      }
      return updated;
    } catch (e, stacktrace) {
      print('Error updating stock and min stock: $e --> $stacktrace');
      return false;
    }
  }

  Future<bool> addStock({
    required int id,
    required double amount,
  }) async {
    try {
      final db = await DBfactory.getDatabase();
      final updated = await db.transaction((txn) async {
        final existing = await DBfactory.stockStore.record(id).get(txn);
        if (existing == null) return false;

        final currentQty = double.tryParse(existing['productQuantity']?.toString() ?? '0') ?? 0;
        final newQty = currentQty + amount;

        final merged = Map<String, Object?>.from(existing);
        merged['productQuantity'] = newQty.toString();

        final record = DBfactory.withSyncMetadata(
          merged,
          syncId: existing['sync_id']?.toString(),
          deviceId: existing['device_id']?.toString(),
        );
        await DBfactory.stockStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(txn, table: 'stock', record: record);
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
      print('Error adding stock: $e --> $stacktrace');
      return false;
    }
  }

  Future<bool> updateProductById({
    required int id,
    String? newCodeBar,
    String? newName,
    String? newPrice,
    String? newBuyingPrice,
    String? newQuantity,
    int? newMinStock,
  }) async {
    try {
      final db = await DBfactory.getDatabase();
      final updated = await db.transaction((txn) async {
        final existing = await DBfactory.stockStore.record(id).get(txn);
        if (existing == null) return false;

        final merged = Map<String, Object?>.from(existing);
        if (newCodeBar != null) merged['productCodeBar'] = newCodeBar;
        if (newName != null) merged['productName'] = newName;
        if (newPrice != null) merged['productPrice'] = newPrice;
        if (newBuyingPrice != null) {
          merged['productBuyingPrice'] = newBuyingPrice;
        }
        if (newQuantity != null) merged['productQuantity'] = newQuantity;
        if (newMinStock != null) merged['min_stock'] = newMinStock;

        final record = DBfactory.withSyncMetadata(
          merged,
          syncId: existing['sync_id']?.toString(),
          deviceId: existing['device_id']?.toString(),
        );
        await DBfactory.stockStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(txn, table: 'stock', record: record);
        return true;
      });

      if (updated) {
        if (useSupabaseWeb) {
          await SyncService.instance.flush();
        } else {
          SyncService.instance.scheduleSync();
        }

        // Trigger notification check
        final product = await getProductById(id);
        if (product != null) {
          await NotificationService.instance.checkAndCreateNotification(
            storeId: product['store_id'] as int? ?? 0,
            productId: id,
            currentQty: double.tryParse(product['productQuantity']?.toString() ?? '0') ?? 0,
            minStock: product['min_stock'] as int? ?? 0,
          );
        }
      }
      return updated;
    } catch (e, stacktrace) {
      print('Error updating by id: $e --> $stacktrace');
      return false;
    }
  }

  Future<bool> deleteProductById(int id) async {
    try {
      final db = await DBfactory.getDatabase();
      final deleted = await db.transaction((txn) async {
        final existing = await DBfactory.stockStore.record(id).get(txn);
        if (existing == null) return false;

        final syncId = existing['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) return false;

        await DBfactory.stockStore.record(id).delete(txn);
        await DBfactory.queueDelete(
          txn,
          table: 'stock',
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
      print('Error deleting by id: $e --> $stacktrace');
      return false;
    }
  }

  Future<bool> updateProductPrices({
    required String codeBar,
    int? storeId,
    double? newBuyingPrice,
    double? newSellingPrice,
  }) async {
    return updateProduct(
      codeBar: codeBar,
      storeId: storeId,
      newBuyingPrice: newBuyingPrice?.toString(),
      newPrice: newSellingPrice?.toString(),
    );
  }

  Future<List<String>> getAllProductNames(int? storeId) async {
    try {
      final products = await getProductsByStore(storeId);
      return products
          .map((product) => product['productName']?.toString() ?? 'بدون اسم')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e, stacktrace) {
      print('Error fetching product names: $e --> $stacktrace');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProductsByStore(int? storeId) async {
    try {
      final db = await DBfactory.getDatabase();
      final snapshots = await DBfactory.stockStore.find(db);
      final stocks = snapshots
          .map((snapshot) => _normalize(snapshot.key, snapshot.value))
          .where((stock) => stock['store_id'] == (storeId ?? 0))
          .toList()
        ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      return stocks;
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return [];
    }
  }

  Future<String> exportToCsvString(int? storeId) async {
    final stocks = await getProductsByStore(storeId);
    final rows = <List<dynamic>>[
      ['productName', 'productPrice', 'productBuyingPrice', 'productCodeBar', 'productQuantity'],
      ...stocks.map((s) => [
            s['productName'] ?? '',
            s['productPrice'] ?? '',
            s['productBuyingPrice'] ?? '',
            s['productCodeBar'] ?? '',
            s['productQuantity'] ?? '',
          ])
    ];
    return const ListToCsvConverter().convert(rows);
  }

  Future<int?> insertRecord(Map<String, dynamic> data) async {
    try {
      return insertProduct(
        storeId: data['store_id'] as int?,
        name: data['productName']?.toString() ?? '',
        price: data['productPrice']?.toString(),
        buyingPrice: data['productBuyingPrice']?.toString(),
        codeBar: data['productCodeBar']?.toString(),
        quantity: data['productQuantity']?.toString(),
        minStock: data['min_stock'] as int?,
      );
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
    }
  }

  /// Idempotent import entry point used by the CSV importer.
  ///
  /// Looks up an existing product in the same store using the same identity
  /// the rest of the app uses: `(store_id, productCodeBar)` when a barcode is
  /// present, otherwise `(store_id, productName)`. If a match is found, the
  /// existing row is updated in place (preserving its `id` and `sync_id`).
  /// Otherwise a new product is inserted.
  ///
  /// Returns a record describing what happened so the caller can report
  /// counts back to the user.
  Future<({int id, bool created})> upsertRecord(
    Map<String, dynamic> data,
  ) async {
    final storeId = data['store_id'] as int?;
    final name = data['productName']?.toString() ?? '';
    final price = data['productPrice']?.toString();
    final buyingPrice = data['productBuyingPrice']?.toString();
    final codeBar = data['productCodeBar']?.toString();
    final quantity = data['productQuantity']?.toString();
    final minStock = data['min_stock'] as int?;

    try {
      // 1) Try to find an existing product using the same identity rules
      //    used elsewhere in the app: barcode within a store, then name.
      Map<String, dynamic>? existing;
      final trimmedCode = (codeBar ?? '').trim();
      if (trimmedCode.isNotEmpty) {
        existing = await getProductByCode(trimmedCode, storeId);
      }
      existing ??= await getProductByName(name, storeId);

      if (existing != null) {
        final ok = await updateProductById(
          id: existing['id'] as int,
          newCodeBar: (codeBar == null || codeBar.isEmpty) ? null : codeBar,
          newName: name.isEmpty ? null : name,
          newPrice: (price == null || price.isEmpty) ? null : price,
          newBuyingPrice:
              (buyingPrice == null || buyingPrice.isEmpty) ? null : buyingPrice,
          newQuantity: (quantity == null || quantity.isEmpty) ? null : quantity,
          newMinStock: minStock,
        );
        return (id: existing['id'] as int, created: !ok);
      }

      // 2) No match — insert a brand new product.
      final newId = await insertProduct(
        storeId: storeId,
        name: name,
        price: price,
        buyingPrice: buyingPrice,
        codeBar: codeBar,
        quantity: quantity,
        minStock: minStock,
      );
      return (id: newId ?? -1, created: newId != null);
    } catch (e, stacktrace) {
      print('upsertRecord error: $e --> $stacktrace');
      return (id: -1, created: false);
    }
  }

  Future<bool> updateQuantity({
    required String codeBar,
    int? storeId,
    required double delta,
  }) async {
    try {
      final product = await getProductByCode(codeBar, storeId);
      if (product == null) return false;

      final current = double.tryParse(product['productQuantity']?.toString() ?? '0') ?? 0;
      return updateProductById(
        id: product['id'] as int,
        newQuantity: (current + delta).toString(),
      );
    } catch (e, stacktrace) {
      print('Error updating quantity: $e --> $stacktrace');
      return false;
    }
  }

  Future<List<int>> insertRecords(List<Map<String, dynamic>> records) async {
    final ids = <int>[];
    try {
      for (final record in records) {
        final id = await insertRecord(record);
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
      'store_id': raw['store_id'] as int? ?? 0,
      'productName': raw['productName']?.toString() ?? '',
      'productPrice': raw['productPrice']?.toString(),
      'productBuyingPrice': raw['productBuyingPrice']?.toString(),
      'productCodeBar': raw['productCodeBar']?.toString(),
      'productQuantity': raw['productQuantity']?.toString(),
      'min_stock': raw['min_stock'] as int? ?? 0,
    };
  }
}
