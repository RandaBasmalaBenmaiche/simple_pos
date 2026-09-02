import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/services/local_database/model/tablealiases.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/services/cubits/import_cubit.dart';
import 'package:simple_pos/services/cubits/notification_cubit.dart';
import 'package:simple_pos/services/sync/sync_service.dart';

class ProductMatchingDialog extends StatefulWidget {
  final List<Map<String, String>> extractedProducts;
  final int storeId;

  const ProductMatchingDialog({
    super.key,
    required this.extractedProducts,
    required this.storeId,
  });

  @override
  State<ProductMatchingDialog> createState() => _ProductMatchingDialogState();
}

class _ProductMatchingDialogState extends State<ProductMatchingDialog> {
  List<Map<String, dynamic>> matchingData = [];
  bool isImporting = false;

  @override
  void initState() {
    super.initState();
    _initializeMatchingData();
  }

  @override
  void dispose() {
    for (var item in matchingData) {
      (item['nameController'] as TextEditingController).dispose();
      (item['qtyController'] as TextEditingController).dispose();
      (item['controller'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _initializeMatchingData() async {
    final aliasTable = DAliasesTable();
    final List<Map<String, dynamic>> data = [];

    for (var item in widget.extractedProducts) {
      final name = item['name']!;
      final qty = item['quantity']!;

      // Check for alias
      final aliasMatch = await aliasTable.getAliasForName(name, widget.storeId);
      int? matchedProductId;
      String? matchedProductName;

      if (aliasMatch != null) {
        final productSyncId = aliasMatch['product_sync_id']?.toString();

        if (productSyncId != null && productSyncId.isNotEmpty) {
          final stockTable = DStockTable();
          final product = await stockTable.getProductBySyncId(productSyncId);
          if (product != null) {
            matchedProductId = product['id'] as int;
            matchedProductName = product['productName'] as String?;
          }
        }

        if (matchedProductId == null) {
          final productId = aliasMatch['product_id'] as int;
          final stockTable = DStockTable();
          final product = await stockTable.getProductById(productId);
          matchedProductId = product?['id'] as int?;
          matchedProductName = product?['productName'] as String?;
        }
      } else {
        // Also check for exact name match
        final stockTable = DStockTable();
        final productMatch = await stockTable.getProductByName(name, widget.storeId);
        if (productMatch != null) {
          matchedProductId = productMatch['id'] as int;
          matchedProductName = productMatch['productName'] as String?;
        }
      }

      data.add({
        'extractedName': name,
        'extractedQuantity': qty,
        'matchedProductId': matchedProductId,
        'matchedProductName': matchedProductName,
        'nameController': TextEditingController(text: name),
        'qtyController': TextEditingController(text: qty),
        'controller': TextEditingController(text: matchedProductName ?? ''),
      });
    }

    setState(() {
      matchingData = data;
    });
  }

  Future<void> _confirmImport() async {
    final importCubit = context.read<ImportCubit>();
    final notificationCubit = context.read<NotificationCubit>();

    // Pass the matching data to the cubit for background processing
    importCubit.importProducts(
      matchingData: matchingData,
      storeId: widget.storeId,
      notificationCubit: notificationCubit,
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _suggestMatch(Map<String, dynamic> item) async {
    final name = (item['nameController'] as TextEditingController).text;
    if (name.trim().isEmpty) return;

    print('🔍 Suggesting match for: \"$name\" in store: ${widget.storeId}');

    final aliasTable = DAliasesTable();
    final stockTable = DStockTable();

    // 1. Try to find a match locally first
    Map<String, dynamic>? aliasMatch = await aliasTable.getAliasForName(name, widget.storeId);
    Map<String, dynamic>? productMatch = await stockTable.getProductByName(name, widget.storeId);

    // 2. If no match was found locally, try to sync from cloud and search again
    if (aliasMatch == null && productMatch == null) {
      print('⚠️ No local match found. Trying to sync from cloud...');

      // Wait if a sync is already running
      while (SyncService.instance.isSyncRunning) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await SyncService.instance.flush();
      print('✅ Cloud sync completed. Re-checking for matches...');

      // Re-check local database
      aliasMatch = await aliasTable.getAliasForName(name, widget.storeId);
      productMatch = await stockTable.getProductByName(name, widget.storeId);
    }

    // 3. If still no match, try searching for the alias GLOBALLY (across all stores)
    if (aliasMatch == null && productMatch == null) {
      print('🌍 Trying global alias search...');
      final globalAlias = await aliasTable.getAliasForNameGlobal(name);
      if (globalAlias != null) {
        print('✅ Global alias found: ${globalAlias['alias_name']}');
        final productSyncId = globalAlias['product_sync_id']?.toString();
        if (productSyncId != null && productSyncId.isNotEmpty) {
          final product = await stockTable.getProductBySyncId(productSyncId);
          if (product != null) {
            aliasMatch = globalAlias; // Treat as a match since the product exists locally
            print('🔗 Global alias linked to local product: ${product['productName']}');
          }
        }
      }
    }

    // 4. Handle alias match
    if (aliasMatch != null) {
      print('✅ Alias found: ${aliasMatch['alias_name']} -> ProductID: ${aliasMatch['product_id']}');

      final productSyncId = aliasMatch['product_sync_id']?.toString();
      int? matchedProductId;
      String? matchedProductName;

      if (productSyncId != null && productSyncId.isNotEmpty) {
        final product = await stockTable.getProductBySyncId(productSyncId);
        if (product != null) {
          matchedProductId = product['id'] as int;
          matchedProductName = product['productName'];
          print('🔗 Linked via SyncID: $matchedProductName');
        }
      }

      if (matchedProductId == null) {
        final productId = aliasMatch['product_id'] as int?;
        if (productId != null) {
          final product = await stockTable.getProductById(productId);
          if (product != null) {
            matchedProductId = product['id'] as int;
            matchedProductName = product['productName'];
            print('🔗 Linked via LocalID: $matchedProductName');
          } else {
            print('❌ Alias found, but Product ID $productId not found in local stock');
          }
        }
      }

      if (matchedProductId != null) {
        setState(() {
          item['matchedProductId'] = matchedProductId;
          item['matchedProductName'] = matchedProductName;
          (item['controller'] as TextEditingController).text = matchedProductName ?? '';
        });
        return;
      }
    }

    // 5. Handle exact name match in stock
    if (productMatch != null) {
      print('✅ Exact name match found: ${productMatch['productName']}');
      setState(() {
        item['matchedProductId'] = productMatch?['id'];
        item['matchedProductName'] = productMatch?['productName'];
        (item['controller'] as TextEditingController).text = productMatch?['productName'] ?? '';
      });
      return;
    }

    // No match found after local, remote, and global attempts
    print('❌ No match found for \"$name\" in store ${widget.storeId} (even after sync and global search)');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لم يتم العثور على منتج مطابق")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (matchingData.isEmpty) {
      return const AlertDialog(
        content: Text("جاري تحميل البيانات..."),
      );
    }

    return AlertDialog(
      title: const Text("مطابقة المنتجات", textAlign: TextAlign.center),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DataTable(
                columns: const [
                  DataColumn(label: Text("المنتج المستخرج")),
                  DataColumn(label: Text("الكمية")),
                  DataColumn(label: Text("مطابقة في المخزن")),
                ],
                rows: matchingData.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: item['nameController'] as TextEditingController,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: item['qtyController'] as TextEditingController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 250,
                          child: Row(
                            children: [
                              Expanded(
                                child: TypeAheadField<Map<String, dynamic>>(
                                  controller: item['controller'] as TextEditingController,
                                  suggestionsCallback: (pattern) async {
                                    final stockTable = DStockTable();
                                    final storeId = widget.storeId;
                                    final query = pattern.toLowerCase();

                                    final allProducts = await stockTable.getProductsByStore(storeId);

                                    // Find products where name matches OR any of its aliases match
                                    final matchingProducts = <Map<String, dynamic>>[];

                                    for (var p in allProducts) {
                                      final name = (p['productName'] as String).toLowerCase();
                                      if (name.contains(query)) {
                                        matchingProducts.add(p);
                                        continue;
                                      }

                                      // Check all aliases for this product
                                      final db = await DBfactory.getDatabase();
                                      final aliasSnapshots = await DBfactory.productAliasesStore.find(db);
                                      final hasMatchingAlias = aliasSnapshots.any((s) {
                                        final record = s.value;
                                        return record?['product_id'] == p['id'] &&
                                               record?['alias_name']?.toString().toLowerCase().contains(query) == true &&
                                               record?['store_id'] == storeId;
                                      });

                                      if (hasMatchingAlias) {
                                        matchingProducts.add(p);
                                      }
                                    }
                                    return matchingProducts;
                                  },
                                  itemBuilder: (context, product) {
                                    return ListTile(
                                      title: Text(product['productName'] ?? ''),
                                    );
                                  },
                                  onSelected: (product) {
                                    setState(() {
                                      item['matchedProductId'] = product['id'];
                                      item['matchedProductName'] = product['productName'];
                                      (item['controller'] as TextEditingController).text = product['productName'];
                                    });
                                  },
                                  builder: (context, controller, focusNode) {
                                    return TextField(
                                      controller: item['controller'] as TextEditingController,
                                      focusNode: focusNode,
                                      decoration: const InputDecoration(
                                        hintText: "بحث عن منتج...",
                                        isDense: true,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.link, size: 20, color: Colors.blue),
                                onPressed: () => _suggestMatch(item),
                                tooltip: "ربط تلقائي",
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("إلغاء"),
        ),
        ElevatedButton(
          onPressed: isImporting ? null : _confirmImport,
          child: isImporting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("تأكيد واستيراد"),
        ),
      ],
    );
  }
}
