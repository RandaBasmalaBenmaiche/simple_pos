import 'package:flutter/material.dart';
import 'package:simple_pos/components/addProductDialog.dart';
import 'package:simple_pos/components/deleteProductDialog.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/components/sellButton.dart';
import 'package:simple_pos/components/sellTable.dart';
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
  double total = 0;
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
        'total': '-', 
        'considerTotal': false,
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

  void _resetSearch() {
    searchController.clear();
    setState(() => items = List.from(allItems));
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
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyColors.mainColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _resetSearch,
                  child: const Text(
                    "استعادة",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(width: 16),
                CustomActionButton(
                  text: "اضافة للسلع",
                  onPressed: () {
                    showAddProductDialog(context, (name, price, quantity, code) async {
                      await DStockTable().insertRecord({
                        "productName": name,
                        "productPrice": price,
                        "productQuantity": quantity,
                        "productCodeBar": code
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
                const SizedBox(width: 20),
                CustomActionButton(
                  text: "ازالة منتج",
                  onPressed: () {
                    showDeleteProductDialog(context, () async {
                      await _loadItems();
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Table
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: POSItemsTable(
              items: items,
              sellItems: (){},
              onQuantityChanged: (index, newQuantity) {
                setState(() {
                  items[index]["productQuantity"] = newQuantity;
                });
              },
              onDelete: (index) {
                setState(() {
                  items.removeAt(index);
                });
              },
            ),
            ),
          ],
        ),
      ),
    );
  }
}
