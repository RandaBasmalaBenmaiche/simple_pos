import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/components/addProductDialog.dart';
import 'package:simple_pos/components/sellButton.dart';
import 'package:simple_pos/components/stockTable.dart';
import 'package:simple_pos/components/updateProductDialog.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class POSPageStock extends StatefulWidget {
  const POSPageStock({Key? key}) : super(key: key);

  @override
  _POSPageState createState() => _POSPageState();
}

class _POSPageState extends State<POSPageStock> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> allItems = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentStoreId = BlocProvider.of<StoreCubit>(context, listen: false).state;
    _loadItems(currentStoreId);
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems(int store) async {
    final rawItems = await DStockTable().getProductsByStore(store);

    // Add default values for null fields
    final loadedItems = rawItems.map((item) {
      return {
        ...item,
        'productPrice': item['productPrice'] ?? '',
        'productBuyingPrice': item['productBuyingPrice'] ?? '',
        'productCodeBar': item['productCodeBar'] ?? '',
        'productQuantity': item['productQuantity'] ?? '',
      };
    }).toList();

    setState(() {
      items = loadedItems;
      allItems = loadedItems;
    });
  }

  void _onSearchChanged() {
    final query = searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() => items = List.from(allItems));
      return;
    }

    final filtered = allItems.where((item) {
      final code = (item['productCodeBar'] ?? '').toString().toLowerCase();
      final name = (item['productName'] ?? '').toString().toLowerCase();
      return code.contains(query) || name.contains(query);
    }).toList();

    setState(() => items = filtered);
  }

  // ================= Import CSV =================
  Future<void> importProductsFromCSV(int store) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final csvString = await file.readAsString();
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);

      for (var i = 1; i < csvTable.length; i++) {
        var row = csvTable[i];
        await DStockTable().insertRecord({
          'store_id': store,
          'productName': row[0].toString(),
          'productPrice': row[1]?.toString().isNotEmpty == true ? row[1].toString() : null,
          'productBuyingPrice': row[2]?.toString().isNotEmpty == true ? row[2].toString() : null,
          'productCodeBar': row[3]?.toString().isNotEmpty == true ? row[3].toString() : null,
          'productQuantity': row[4]?.toString().isNotEmpty == true ? row[4].toString() : null,
        });
      }

      await _loadItems(store);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم استيراد المنتجات بنجاح')),
      );
    }
  }

  // ================= Export CSV =================
  Future<void> exportProductsToCSV() async {
    final allProducts = await DStockTable().getRecords();
    List<List<dynamic>> rows = [
      ['productName', 'productPrice', 'productBuyingPrice', 'productCodeBar', 'productQuantity']
    ];

    for (var product in allProducts) {
      rows.add([
        product['productName'] ?? '',
        product['productPrice'] ?? '',
        product['productBuyingPrice'] ?? '',
        product['productCodeBar'] ?? '',
        product['productQuantity'] ?? '',
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'اختر مكان حفظ الملف',
      fileName: 'products_export.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تصدير المنتجات إلى $outputFile')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء التصدير')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreCubit>().state;
    return Scaffold(
      appBar: const CustomPOSAppBar(showReturnButton: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "ابحث بالكود أو الاسم",
                      filled: true,
                      fillColor: MyColors.secondColor(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.search, color: MyColors.secondColor(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  CustomActionButton(
                    text: "اضافة للسلع",
                    onPressed: () {
                      showAddProductDialog(context, (name, price, buyingPrice, quantity, code) async {
                        await DStockTable().insertRecord({
                          "productName": name,
                          "store_id": store,
                          "productPrice": price.isNotEmpty ? price : null,
                          "productQuantity": quantity.isNotEmpty ? quantity : null,
                          "productCodeBar": code.isNotEmpty ? code : null,
                          "productBuyingPrice": buyingPrice.isNotEmpty ? buyingPrice : null,
                        });
                        await _loadItems(store);
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  CustomActionButton(
                    text: "تغيير السلع",
                    onPressed: () async {
                      await showEditProductDialog(context, () async {
                        await _loadItems(store);
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  CustomActionButton(
                    text: "استيراد CSV",
                    onPressed: () async {
                      await importProductsFromCSV(store);
                    },
                  ),
                  const SizedBox(width: 10),
                  CustomActionButton(
                    text: "تصدير CSV",
                    onPressed: () async {
                      await exportProductsToCSV();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Table
            Flexible(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: POSStockItemsTable(
                  items: items,
                  sellItems: () {},
                  onQuantityChanged: (index, newQuantity) async {
                    final product = items[index];

                    setState(() {
                      items[index]["productQuantity"] = newQuantity;
                    });

                    await DStockTable().updateProduct(
                      codeBar: product['productCodeBar'] ?? '',
                      newQuantity: newQuantity.isNotEmpty ? newQuantity : null,
                      storeId: store,
                    );
                  },
                  onDelete: (index) async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("هل أنت متأكد؟", textAlign: TextAlign.center),
                          content: const Text("سيتم حذف هذا المنتج نهائيًا!", textAlign: TextAlign.center),
                          actionsAlignment: MainAxisAlignment.center,
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("حذف", style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirm == true) {
                      final product = items[index];
                      await DStockTable().deleteProduct(product['productCodeBar'] ?? '', store);

                      setState(() {
                        items.removeAt(index);
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
