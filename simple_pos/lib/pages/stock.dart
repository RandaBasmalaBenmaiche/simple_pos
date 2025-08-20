import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/components/addProductDialog.dart';
import 'package:simple_pos/components/sellButton.dart';
import 'package:simple_pos/components/stockTable.dart';
import 'package:simple_pos/components/updateProductDialog.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/styles/my_colors.dart';

class POSPageStock extends StatefulWidget {
  const POSPageStock({Key? key}) : super(key: key);

  @override
  _POSPageState createState() => _POSPageState();
}

class _POSPageState extends State<POSPageStock> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> allItems = []; // Keep full list
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final rawItems = await DStockTable().getRecords();
    final loadedItems = rawItems.map((item) {
      return {
        ...item,
        'productBuyingPrice': item['productBuyingPrice'] ?? 200, 
      };
    }).toList();

    setState(() {
      items = loadedItems;
      allItems = loadedItems; // Save full list
    });
  }

  void _onSearchChanged() {
    final query = searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() => items = List.from(allItems));
      return;
    }

    final filtered = allItems.where((item) {
      final code = item['productCodeBar'].toString().toLowerCase();
      final name = item['productName'].toString().toLowerCase();
      return code.contains(query) || name.contains(query);
    }).toList();

    setState(() => items = filtered);
  }

  // ================= Import CSV =================
  Future<void> importProductsFromCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final csvString = await file.readAsString();
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);

      // Assuming header: productName,productPrice,productBuyingPrice,productCodeBar,productQuantity
      for (var i = 1; i < csvTable.length; i++) {
        var row = csvTable[i];
        await DStockTable().insertRecord({
          'productName': row[0].toString(),
          'productPrice': row[1].toString(),
          'productBuyingPrice': row[2].toString(),
          'productCodeBar': row[3].toString(),
          'productQuantity': row[4].toString(),
        });
      }

      await _loadItems();
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
        product['productName'],
        product['productPrice'],
        product['productBuyingPrice'],
        product['productCodeBar'],
        product['productQuantity'],
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    // Let user pick a location and file name
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
                      fillColor: MyColors.secondColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.search, color: MyColors.mainColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action buttons (Add, Edit, Import, Export)
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
                          "productPrice": price,
                          "productQuantity": quantity,
                          "productCodeBar": code,
                          "productBuyingPrice": buyingPrice,
                        });
                        await _loadItems();
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  CustomActionButton(
                    text: "تغيير السلع",
                    onPressed: () async {
                      await showEditProductDialog(context, () async {
                        await _loadItems();
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  CustomActionButton(
                    text: "استيراد CSV",
                    onPressed: () async {
                      await importProductsFromCSV();
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

                    // Update locally
                    setState(() {
                      items[index]["productQuantity"] = newQuantity;
                    });

                    // Update in database
                    await DStockTable().updateProduct(
                      codeBar: product['productCodeBar'],
                      newQuantity: newQuantity.toString(),
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
                      await DStockTable().deleteProduct(product['productCodeBar']);

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
