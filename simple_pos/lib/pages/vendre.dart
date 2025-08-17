import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/components/numericInputField.dart';
import 'package:simple_pos/components/sellButton.dart';
import 'package:simple_pos/components/sellTable.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/styles/my_colors.dart'; // your DB model

class POSPage extends StatefulWidget {
  const POSPage({Key? key}) : super(key: key);

  @override
  _POSPageState createState() => _POSPageState();
}

class _POSPageState extends State<POSPage> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  List<Map<String, dynamic>> items = [];
  double total = 0;
  
    // 🔥 two separate focus nodes
  final FocusNode codeFocusNode = FocusNode();
  final FocusNode quantityFocusNode = FocusNode();

  // 🔥 persistent node for RawKeyboardListener
  final FocusNode keyboardFocusNode = FocusNode();

    @override
  void initState() {
    super.initState();

    // Request focus when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(codeFocusNode);
    });
  }

  @override
  void dispose() {
    codeController.dispose();
    quantityController.dispose();
    codeFocusNode.dispose();
    quantityFocusNode.dispose();
    keyboardFocusNode.dispose();
    super.dispose();
  }


  void addItem() async {
    String code = codeController.text;
    int quantity = int.tryParse(quantityController.text) ?? 0;

    if (code.isEmpty || quantity <= 0){
       codeFocusNode.requestFocus();
       return;
    } 

    final exist_index = items.indexWhere(
      (p) => p['productCodeBar'] == code
    );

    if (exist_index != - 1){
      items[exist_index]['productQuantity'] =  (int.parse(items[exist_index]['productQuantity']) + quantity).toString();
      items[exist_index]['total'] =  (int.parse(items[exist_index]['productQuantity']) * double.parse(items[exist_index]['productPrice'])).toString();
      codeController.clear();
      quantityController.clear();
      total = items.fold<double>(
  0.0,
  (sum, item) => sum + (double.tryParse(item['total'].toString()) ?? 0.0),
);
      setState(() {});
      codeFocusNode.requestFocus(); 
      return;
    }

    final records = await DStockTable().getRecords();
    final product = records.firstWhere(
      (p) => p['productCodeBar'] == code,
      orElse: () => {},
    );

    if (product.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("خطأ"),
          content: const Text("الكود غير موجود في قاعدة البيانات"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("حسناً"),
            ),
          ],
        ),
      );
      codeFocusNode.requestFocus(); 
      return;
    }

    double price = double.tryParse(product['productPrice'].toString()) ?? 0;
    double itemTotal = price * quantity;

    Map<String, dynamic> item = {
      "productCodeBar": code,
      "productName": product['productName'],
      "productPrice": price.toStringAsFixed(2),
      "productQuantity": quantity.toString(),
      "total": itemTotal.toStringAsFixed(2),
    };

    setState(() {
      items.add(item);
      total += itemTotal;
    codeController.clear();
    quantityController.clear();
    codeFocusNode.requestFocus(); 
    });


  }

  void sellItems() async {
    for (var item in items) {
      String code = item['productCodeBar'];
      int soldQuantity = int.tryParse(item['productQuantity']) ?? 0;

      final records = await DStockTable().getRecords();
      final product = records.firstWhere((p) => p['productCodeBar'] == code, orElse: () => {});

      if (product.isNotEmpty) {
        int currentQuantity = int.tryParse(product['productQuantity'].toString()) ?? 0;
        int newQuantity = currentQuantity - soldQuantity;
        if (newQuantity < 0) newQuantity = 0;

        // Use your updateProduct function
        await DStockTable().updateProduct(
          codeBar: code,
          newQuantity: newQuantity.toString(),
        );
      }
    }

    setState(() {
      items.clear();
      total = 0;
    });
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: const CustomPOSAppBar(showReturnButton: true),
    body: RawKeyboardListener(
      focusNode: keyboardFocusNode,       
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          addItem();
          keyboardFocusNode.unfocus();
      Future.delayed(Duration(milliseconds: 50), () {
        FocusScope.of(context).requestFocus(codeFocusNode);
      });
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                NumericInputField(
                  controller: quantityController,
                  label: "الكمية",
                  defaultValue: "1",
                ),
                const SizedBox(width: 16),
                NumericInputField(
                  controller: codeController,
                  label: "الكود",
                  isAlphanumeric: true,
                  focusNode: codeFocusNode,
                ),
                const SizedBox(width: 16),
                CustomActionButton(
                  text: "اضافة للمشتريات",
                  onPressed: addItem,
                ),
              ],
            ),
            const SizedBox(height: 20),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: POSItemsTable(
              items: items,
              sellItems: sellItems,
              onQuantityChanged: (index, newQuantity) {
                setState(() {
                  items[index]["productQuantity"] = newQuantity;
                  items[index]["total"] = (int.parse(items[index]['productQuantity']) * double.parse(items[index]['productPrice'])).toString();
                  total = items.fold<double>(
                    0.0,
                    (sum, item) => sum + (double.tryParse(item['total'].toString()) ?? 0.0),
                  );

                });
              },
              onDelete: (index) {
                setState(() {
                  items.removeAt(index);
                });
              },
            ),
          ),

            const SizedBox(height: 20),
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: MyColors.secondColor,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      " المبلغ الكلي:    دج${total.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 35,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  CustomActionButton(
                    text: "بيع",
                    onPressed: sellItems,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

}
