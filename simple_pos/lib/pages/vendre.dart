/**
 * maybe start using the loaded items instead of database calls?
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/components/AutoComplete.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/components/alphaNumericInputField.dart';
import 'package:simple_pos/components/paying.dart';
import 'package:simple_pos/components/sellButton.dart';
import 'package:simple_pos/components/sellTable.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/local_database/model/tablecustomers.dart';
import 'package:simple_pos/services/local_database/model/tableinvoice.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class POSPage extends StatefulWidget {
  const POSPage({Key? key}) : super(key: key);

  @override
  _POSPageState createState() => _POSPageState();
}

class _POSPageState extends State<POSPage> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController customerController = TextEditingController();
  final TextEditingController payingController = TextEditingController();

  List<Map<String, dynamic>> items = [];
  double total = 0;
  final FocusNode codeFocusNode = FocusNode();
  final FocusNode quantityFocusNode = FocusNode();
  final FocusNode keyboardFocusNode = FocusNode();

  List<String> allItems = [];
  List<String> allCustomers = [];

  void addItem(int store) async {
    String codeInput = codeController.text.trim();
    String nameInput = nameController.text.trim();
    int quantity = int.tryParse(quantityController.text) ?? 0;

    if ((codeInput.isEmpty && nameInput.isEmpty) || quantity <= 0) {
      codeFocusNode.requestFocus();
      return;
    }

    Map<String, dynamic>? product;

    // Priority: code first, fallback to name
    if (codeInput.isNotEmpty) {
      product = await DStockTable().getProductByCode(codeInput, store);
    } else if (nameInput.isNotEmpty) {
      product = await DStockTable().getProductByName(nameInput, store);
    }

    if (product == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("خطأ"),
          content: const Text("المنتج غير موجود في قاعدة البيانات"),
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

    codeController.text = product['productCodeBar'].toString();
    nameController.text = product['productName'].toString();

    // Check if already in invoice
    final existIndex =
        items.indexWhere((p) => p['productCodeBar'] == product!['productCodeBar']);
    if (existIndex != -1) {
      items[existIndex]['productQuantity'] =
          (int.parse(items[existIndex]['productQuantity']) + quantity).toString();
      items[existIndex]['total'] =
          (int.parse(items[existIndex]['productQuantity']) *
                  double.parse(items[existIndex]['productPrice']))
              .toStringAsFixed(2);

      codeController.clear();
      nameController.clear();
      customerController.clear();
      quantityController.clear();

      total = items.fold<double>(
        0.0,
        (sum, item) => sum + (double.tryParse(item['total'].toString()) ?? 0.0),
      );

      setState(() {});
      codeFocusNode.requestFocus();
      return;
    }

    // Add new item
    double price = double.tryParse(product['productPrice'].toString()) ?? 0;
    double itemTotal = price * quantity;
    Map<String, dynamic> item = {
      "productCodeBar": product['productCodeBar'],
      "productName": product['productName'],
      "productPrice": price.toStringAsFixed(2),
      "productBuyingPrice": product['productBuyingPrice'],
      "productQuantity": quantity.toString(),
      "total": itemTotal.toStringAsFixed(2),
    };
    setState(() {
      items.add(item);
      total += itemTotal;

      codeController.clear();
      nameController.clear();
      customerController.clear();
      quantityController.clear();

      codeFocusNode.requestFocus();
    });
  }

  void sellItems(int store) async {
    if (items.isEmpty) return;
    double totalProfit = 0;

    Map<String, Object> inv = {
      "store_id": store,
      "date": DateTime.now().toIso8601String(),
      "total": total,
    };

    // Attach customer if chosen
    if (customerController.text.isNotEmpty) {
      final cus =
          await DCustomersTable().getCustomerByName(customerController.text, store);
      if (cus.isNotEmpty) {
        inv.addAll({
          "customer_id": cus[0]["id"],
          "customer_name": cus[0]["name"],
        });
      }
    }

    // 1. Insert invoice
    final invoiceId = await DInvoiceTable().custinsertRecord(inv);

    // 2. Insert invoice items
    for (var item in items) {
      totalProfit += (double.parse(item['productPrice']) -
              double.parse(item['productBuyingPrice'])) *
          double.parse(item['productQuantity']);
      await DInvoiceItemsTable().insertRecord({
        "invoice_id": invoiceId,
        "productCodeBar": item['productCodeBar'],
        "productName": item['productName'],
        "quantity": int.parse(item['productQuantity']),
        "price": double.parse(item['productPrice']),
        "profit": (double.parse(item['productPrice']) -
                double.parse(item['productBuyingPrice'])) *
            double.parse(item['productQuantity']),
        "totalPrice": double.parse(item['total']),
      });

      // 3. Update stock
      final product =
          await DStockTable().getProductByCode(item['productCodeBar'], store);
      if (product != null) {
        int currentQuantity =
            int.tryParse(product['productQuantity'].toString()) ?? 0;
        int newQuantity = currentQuantity - int.parse(item['productQuantity']);
        if (newQuantity < 0) newQuantity = 0;
        await DStockTable().updateProduct(
          codeBar: product['productCodeBar'],
          storeId: store,
          newQuantity: newQuantity.toString(),
        );
      }

      // 4. update profit in invoice
      await DInvoiceTable().updateInvoice(id: invoiceId ?? 0,profit: totalProfit,);
      

    }

    // 5. Clear invoice
    setState(() {
      items.clear();
      total = 0;
      customerController.clear();
    });
  }

  Future<void> _loadItems() async {
    final rawItems = await DStockTable().getRecords();
    final rawCustomers = await DCustomersTable().getRecords();

    setState(() {
      allItems = rawItems.map((item) => item["productName"] as String).toList();
      allCustomers = rawCustomers.map((item) => item["name"] as String).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(codeFocusNode);
    });
  }

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
    quantityController.dispose();
    customerController.dispose();
    codeFocusNode.dispose();
    quantityFocusNode.dispose();
    keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStoreId = context.watch<StoreCubit>().state;
    return Scaffold(
      appBar: const CustomPOSAppBar(showReturnButton: true),
      body: RawKeyboardListener(
        focusNode: keyboardFocusNode,
        onKey: (RawKeyEvent event) {
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            addItem(currentStoreId);
            keyboardFocusNode.unfocus();
            Future.delayed(const Duration(milliseconds: 50), () {
              FocusScope.of(context).requestFocus(codeFocusNode);
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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

                  // 🔹 Product autocomplete
                  AutoCompleteInputField(
                    controller: nameController,
                    label: "المنتج",
                    isAlphanumeric: true,
                    suggestions: allItems,
                  ),
                  const SizedBox(width: 16),

                  // 🔹 Customer autocomplete
                  AutoCompleteInputField(
                    controller: customerController,
                    label: "الزبون",
                    isAlphanumeric: true,
                    suggestions: allCustomers,
                  ),
                  const SizedBox(width: 16),

                  NumericInputField(
                    controller: codeController,
                    label: "الكود",
                    isAlphanumeric: false,
                    focusNode: codeFocusNode,
                  ),
                  const SizedBox(width: 16),
                  CustomActionButton(
                    text: "اضافة للمشتريات",
                    onPressed: () => addItem(currentStoreId),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: POSItemsTable(
                    items: items,
                    sellItems: () => sellItems(currentStoreId),
                    onQuantityChanged: (index, newQuantity) {
                      setState(() {
                        items[index]["productQuantity"] = newQuantity;
                        items[index]["total"] =
                            (int.parse(items[index]['productQuantity']) *
                                    double.parse(items[index]['productPrice']))
                                .toStringAsFixed(2);
                        total = items.fold<double>(
                          0.0,
                          (sum, item) =>
                              sum + (double.tryParse(item['total'].toString()) ?? 0.0),
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
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.15,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: MyColors.secondColor(context),
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
                    Row(
                      children: [
                    CustomActionButton(
                      text: " بيع مجزئ",
                      onPressed: () async {
                        if (customerController.text.isEmpty){
                          showDialog(context: context, builder: 
                          (BuildContext context){
                            return AlertDialog( title: const Text("خطأ"),content: const Text("يجب اختيار زبون من اجل هذه الخدمة"),
                            actions: [TextButton(onPressed: () => Navigator.of(context).pop(),child: const Text("حسناً"), ),],);});}
                        else{
                        print("the total is:\t${total}");
                        showPayingAmountDialog(context, payingController,(amount) async {
                          // amount = the value customer paid
                          print("Customer paid: $amount");
                                final cus =
                          await DCustomersTable().getCustomerByName(customerController.text, currentStoreId);
                          print("ttttttttttttttttttttttttttt${total}");
                          await DCustomersTable().updateCustomer(id: cus[0]["id"], debt: cus[0]["debt"] + (total - amount));
                          sellItems(currentStoreId);
                          });
                          
                        }
                      },
                    ),
                    const SizedBox(width: 10,),
                        CustomActionButton(
                          text: "بيع",
                          onPressed: () => sellItems(currentStoreId),
                        ),
                        

                      ],
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
