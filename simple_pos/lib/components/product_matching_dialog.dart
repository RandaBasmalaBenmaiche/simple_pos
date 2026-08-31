import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/services/local_database/model/tablealiases.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';

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
        matchedProductId = aliasMatch['product_id'] as int;
        final stockTable = DStockTable();
        final product = await stockTable.getProductById(matchedProductId);
        matchedProductName = product?['productName'] as String?;
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
    setState(() {
      isImporting = true;
    });

    final stockTable = DStockTable();
    final aliasTable = DAliasesTable();
    bool overallSuccess = true;

    for (var item in matchingData) {
      final productId = item['matchedProductId'] as int?;
      if (productId == null) {
        overallSuccess = false;
        continue;
      }

      final qty = double.tryParse((item['qtyController'] as TextEditingController).text) ?? 0;

      // Update stock quantity
      final product = await stockTable.getProductById(productId);
      if (product != null) {
        final currentQty = double.tryParse(product['productQuantity']?.toString() ?? '0') ?? 0;
        final newQty = (currentQty + qty).toString();

        await stockTable.updateProductById(
          id: productId,
          newQuantity: newQty,
        );

        // Save as alias if it's different from the original product name
        final originalName = product['productName'] as String;
        final extractedName = (item['nameController'] as TextEditingController).text;
        if (extractedName.trim().toLowerCase() != originalName.trim().toLowerCase()) {
          await aliasTable.saveAlias(
            productId: productId,
            productSyncId: product['sync_id']?.toString() ?? '',
            aliasName: extractedName,
            storeId: widget.storeId,
            storeSyncId: (await DBfactory.storesStore.record(widget.storeId).get(await DBfactory.getDatabase()))?['sync_id']?.toString() ?? '',
          );
        }
      } else {
        overallSuccess = false;
      }
    }

    setState(() {
      isImporting = false;
    });

    if (mounted) {
      Navigator.pop(context, overallSuccess);
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
                          width: 200,
                          child: TypeAheadField<Map<String, dynamic>>(
                            suggestionsCallback: (pattern) async {
                              final stockTable = DStockTable();
                              final allProducts = await stockTable.getProductsByStore(widget.storeId);
                              return allProducts.where((p) {
                                final name = (p['productName'] as String).toLowerCase();
                                return name.contains(pattern.toLowerCase());
                              }).toList();
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
