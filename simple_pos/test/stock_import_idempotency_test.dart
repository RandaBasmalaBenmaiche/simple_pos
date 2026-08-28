// Regression test for the export→import→import idempotency bug.
//
// The bug: importing a previously-exported CSV created duplicates because the
// import path always inserted a new product instead of recognizing the
// existing one.
//
// The fix: DStockTable.upsertRecord looks up an existing product in the same
// store by (store_id, productCodeBar) — the same identity the rest of the app
// already uses — and updates it in place when found.
//
// This test exercises the full code path against an in-memory Hive database
// and asserts:
//   1. A fresh import creates the products.
//   2. Importing the same rows again does not increase the product count.
//   3. Importing genuinely new products adds only those.
//   4. Existing products are updated, not duplicated, when fields change.
//   5. The exported CSV round-trips through the new importer without
//      duplication.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:simple_pos/services/local_database/dbFactory.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DStockTable stockTable;
  late Directory tempDir;

  // The path_provider plugin reads from a method channel. We intercept the
  // channel and answer with our temp directory so Hive.initFlutter can open
  // its boxes there.
  void registerPathProviderHandler() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'getApplicationDocumentsPath':
        case 'getApplicationSupportPath':
        case 'getTemporaryPath':
          return tempDir.path;
        case 'getExternalStoragePath':
          return null;
      }
      return null;
    });
  }

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('simple_pos_test_');
    registerPathProviderHandler();
  });

  setUp(() async {
    final db = await DBfactory.getDatabase();
    // Clear all rows in the stock box between tests so each test starts
    // with a clean slate.
    final box = await db.openBox('stock');
    await box.clear();
    await DBfactory.setMetaValue('stock_last_id', 0);
    stockTable = DStockTable();
  });

  test('importing the same export twice does not create duplicates', () async {
    const store = 1;

    // Round 1: import three products.
    const first = [
      ['Product A', '100', '60', '111', '5'],
      ['Product B', '200', '120', '222', '3'],
      ['Product C', '300', '180', '333', '7'],
    ];
    for (final cells in first) {
      final res = await stockTable.upsertRecord(_row(store, cells));
      expect(res.id, greaterThan(0));
      expect(res.created, isTrue, reason: 'first import should create');
    }
    expect((await stockTable.getProductsByStore(store)).length, 3);

    // Round 2: re-import the exact same rows. Product count must stay at 3.
    for (final cells in first) {
      final res = await stockTable.upsertRecord(_row(store, cells));
      expect(res.id, greaterThan(0));
      expect(res.created, isFalse,
          reason: 'second import should update, not create');
    }
    expect((await stockTable.getProductsByStore(store)).length, 3,
        reason: 'idempotent import must not duplicate products');

    // Round 3: re-import again. Still 3.
    for (final cells in first) {
      final res = await stockTable.upsertRecord(_row(store, cells));
      expect(res.created, isFalse);
    }
    expect((await stockTable.getProductsByStore(store)).length, 3);
  });

  test('importing a mix of existing and new products only adds the new ones',
      () async {
    const store = 1;

    const seed = [
      ['Product A', '100', '60', '111', '5'],
    ];
    for (final cells in seed) {
      await stockTable.upsertRecord(_row(store, cells));
    }
    expect((await stockTable.getProductsByStore(store)).length, 1);

    const mixed = [
      ['Product A', '100', '60', '111', '5'], // existing
      ['Product B', '200', '120', '222', '3'], // new
      ['Product C', '300', '180', '333', '7'], // new
    ];
    var created = 0;
    var updated = 0;
    for (final cells in mixed) {
      final res = await stockTable.upsertRecord(_row(store, cells));
      if (res.created) {
        created += 1;
      } else {
        updated += 1;
      }
    }
    expect(created, 2);
    expect(updated, 1);
    expect((await stockTable.getProductsByStore(store)).length, 3);
  });

  test('updating an existing product preserves its id and sync_id', () async {
    const store = 1;
    final original = await stockTable.upsertRecord(
      _row(store, ['Product A', '100', '60', '111', '5']),
    );
    final originalRow = await stockTable.getProductById(original.id);
    final originalId = originalRow!['id'];
    final originalSyncId = originalRow['sync_id'];

    // Re-import with a different price and quantity.
    await stockTable.upsertRecord(
      _row(store, ['Product A', '150', '60', '111', '9']),
    );

    final updatedRow = await stockTable.getProductById(originalId);
    expect(updatedRow, isNotNull);
    expect(updatedRow!['id'], originalId,
        reason: 'id must be preserved across re-imports');
    expect(updatedRow['sync_id'], originalSyncId,
        reason: 'sync_id must be preserved so multi-device sync keeps working');
    expect(updatedRow['productPrice'], '150');
    expect(updatedRow['productQuantity'], '9');

    final all = await stockTable.getProductsByStore(store);
    expect(all.length, 1, reason: 'still only one Product A');
  });

  test('CSV round-trip: export then import twice keeps the same product count',
      () async {
    const store = 1;
    const source = [
      ['Product A', '100', '60', '111', '5'],
      ['Product B', '200', '120', '222', '3'],
    ];
    for (final cells in source) {
      await stockTable.upsertRecord(_row(store, cells));
    }

    // Same code path the UI uses to build the CSV (exportProductsToCSV).
    final csv = await stockTable.exportToCsvString(store);

    // Parse the CSV (the importer would do this via the csv package).
    final lines = const LineSplitter().convert(csv);
    final dataLines = lines.skip(1).where((l) => l.trim().isNotEmpty);
    final rows = dataLines.map((line) => line.split(',')).toList();
    expect(rows.length, 2);

    // Reset and re-import from the CSV (simulates a fresh install importing
    // the export).
    final db = await DBfactory.getDatabase();
    final box = await db.openBox('stock');
    await box.clear();
    await DBfactory.setMetaValue('stock_last_id', 0);
    expect((await stockTable.getProductsByStore(store)).length, 0);

    for (final cells in rows) {
      await stockTable.upsertRecord(_importRow(store, cells));
    }
    expect((await stockTable.getProductsByStore(store)).length, 2);

    // Import the same CSV again — no duplicates.
    for (final cells in rows) {
      await stockTable.upsertRecord(_importRow(store, cells));
    }
    expect((await stockTable.getProductsByStore(store)).length, 2);
  });

  test('importing a product without a barcode falls back to name matching',
      () async {
    const store = 1;
    await stockTable.upsertRecord(
      _row(store, ['Café 250g', '500', '300', '', '10']),
    );
    // No barcode in the export, so identity falls back to (store_id, name).
    final res = await stockTable.upsertRecord(
      _row(store, ['Café 250g', '550', '300', '', '8']),
    );
    expect(res.created, isFalse);
    final all = await stockTable.getProductsByStore(store);
    expect(all.length, 1);
    expect(all.first['productPrice'], '550');
    expect(all.first['productQuantity'], '8');
  });
}

Map<String, dynamic> _row(int storeId, List<String> cells) {
  return {
    'store_id': storeId,
    'productName': cells[0],
    'productPrice': cells[1],
    'productBuyingPrice': cells[2],
    'productCodeBar': cells[3],
    'productQuantity': cells[4],
  };
}

Map<String, dynamic> _importRow(int storeId, List<String> cells) {
  String? emptyToNull(String s) => s.isEmpty ? null : s;
  return {
    'store_id': storeId,
    'productName': cells[0],
    'productPrice': emptyToNull(cells[1]),
    'productBuyingPrice': emptyToNull(cells[2]),
    'productCodeBar': emptyToNull(cells[3]),
    'productQuantity': emptyToNull(cells[4]),
  };
}
