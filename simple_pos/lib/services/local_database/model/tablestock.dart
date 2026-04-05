import 'package:csv/csv.dart';

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

  Future<bool> updateProductById({
    required int id,
    String? newCodeBar,
    String? newName,
    String? newPrice,
    String? newBuyingPrice,
    String? newQuantity,
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
      );
    } catch (e, stacktrace) {
      print('$e --> $stacktrace');
      return null;
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
    };
  }
}
