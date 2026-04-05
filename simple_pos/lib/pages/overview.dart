import 'package:flutter/material.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/services/local_database/model/tablecustomers.dart';
import 'package:simple_pos/services/local_database/model/tableinvoice.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class POSPageOverview extends StatefulWidget {
  const POSPageOverview({Key? key}) : super(key: key);

  @override
  _POSPageOverviewState createState() => _POSPageOverviewState();
}

class _POSPageOverviewState extends State<POSPageOverview> {
  List<Map<String, dynamic>> products = [];
  double totalDebts = 0;
  double totalProfit = 0;

  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    final store = BlocProvider.of<StoreCubit>(context, listen: false).state;
    _loadData(store);
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData(int store) async {
    if (!mounted) return;
    final rawProducts = await DStockTable().getProductsByStore(store);

    final loadedProducts = rawProducts.map((item) {
      return {
        ...item,
        'productName': item['productName'] ?? 'غير محدد',
        'productCodeBar': item['productCodeBar'] ?? '-',
        'productQuantity': item['productQuantity'] ?? 0,
        'productPrice': item['productPrice'] ?? 0,
        'productBuyingPrice': item['productBuyingPrice'] ?? 0,
      };
    }).toList();

    final invoiceTable = DInvoiceTable();
    final invoices = await invoiceTable.getInvoices(store);

    double profit = 0;
    for (var invoice in invoices) {
      if (invoice['profit'] != null) {
        DateTime invoiceDate =
            DateTime.tryParse(invoice['date'] ?? '') ?? DateTime.now();

        if ((startDate == null ||
                invoiceDate.isAfter(startDate!.subtract(const Duration(days: 1)))) &&
            (endDate == null ||
                invoiceDate.isBefore(endDate!.add(const Duration(days: 1))))) {
          profit += double.tryParse(invoice['profit'].toString()) ?? 0;
        }
      }
    }

    final customerTable = DCustomersTable();
    final customers = await customerTable.getCustomers(store);

    double debts = 0;
    for (var cust in customers) {
      debts += double.tryParse(cust['debt']?.toString() ?? '0') ?? 0;
    }

    if (!mounted) return;
    setState(() {
      products = loadedProducts;
      totalProfit = profit;
      totalDebts = debts;
    });
  }

  void _onSearchChanged() {
    final query = searchController.text.toLowerCase();
    if (query.isEmpty) {
      final store = BlocProvider.of<StoreCubit>(context, listen: false).state;
      _loadData(store);
      return;
    }

    final filtered = products.where((item) {
      final name = (item['productName'] ?? '').toString().toLowerCase();
      final code = (item['productCodeBar'] ?? '').toString().toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();

    setState(() {
      products = filtered;
    });
  }

  Future<void> _editProductPrice(Map<String, dynamic> product) async {
    final buyingController =
        TextEditingController(text: (product['productBuyingPrice'] ?? 0).toString());
    final sellingController =
        TextEditingController(text: (product['productPrice'] ?? 0).toString());

    final store = BlocProvider.of<StoreCubit>(context, listen: false).state;

    final buyingFocusNode = FocusNode();
    final sellingFocusNode = FocusNode();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("تعديل أسعار ${product['productName'] ?? 'غير محدد'}"),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: buyingController,
                    focusNode: buyingFocusNode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "سعر الشراء"),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      FocusScope.of(context).requestFocus(sellingFocusNode);
                    },
                  ),
                  TextField(
                    controller: sellingController,
                    focusNode: sellingFocusNode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "سعر البيع"),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      double newBuying =
                          double.tryParse(buyingController.text) ?? 0;
                      double newSelling =
                          double.tryParse(sellingController.text) ?? 0;

                      final stockTable = DStockTable();
                      bool success = false;
                      final productId = product['id'] as int?;

                      if (productId != null) {
                        success = await stockTable.updateProductById(
                          id: productId,
                          newBuyingPrice: newBuying.toString(),
                          newPrice: newSelling.toString(),
                        );
                      }

                      if (!success) {
                        success = await stockTable.updateProductPrices(
                          codeBar: product['productCodeBar'] ?? '',
                          storeId: store,
                          newBuyingPrice: newBuying,
                          newSellingPrice: newSelling,
                        );
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        _loadData(store);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء")),
            ElevatedButton(
                onPressed: () async {
                  double newBuying =
                      double.tryParse(buyingController.text) ?? 0;
                  double newSelling =
                      double.tryParse(sellingController.text) ?? 0;

                  final stockTable = DStockTable();
                  bool success = false;
                  final productId = product['id'] as int?;

                  if (productId != null) {
                    success = await stockTable.updateProductById(
                      id: productId,
                      newBuyingPrice: newBuying.toString(),
                      newPrice: newSelling.toString(),
                    );
                  }

                  if (!success) {
                    success = await stockTable.updateProductPrices(
                      codeBar: product['productCodeBar'] ?? '',
                      storeId: store,
                      newBuyingPrice: newBuying,
                      newSellingPrice: newSelling,
                    );
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadData(store);
                  }
                },
                child: const Text("حفظ")),
          ],
        );
      },
    );

    // Cleanup
    buyingController.dispose();
    sellingController.dispose();
    buyingFocusNode.dispose();
    sellingFocusNode.dispose();
  }

  Future<void> _pickStartDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        startDate = picked;
      });
      final store = BlocProvider.of<StoreCubit>(context, listen: false).state;
      _loadData(store);
    }
  }

  Future<void> _pickEndDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        endDate = picked;
      });
      final store = BlocProvider.of<StoreCubit>(context, listen: false).state;
      _loadData(store);
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
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "ابحث بالمنتج أو الكود",
                filled: true,
                fillColor: MyColors.secondColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.search, color: MyColors.mainColor(context)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _pickStartDate,
                  child: Text(
                    startDate != null
                        ? "من: ${DateFormat('yyyy-MM-dd').format(startDate!)}"
                        : "اختر تاريخ البداية",
                  ),
                ),
                ElevatedButton(
                  onPressed: _pickEndDate,
                  child: Text(
                    endDate != null
                        ? "إلى: ${DateFormat('yyyy-MM-dd').format(endDate!)}"
                        : "اختر تاريخ النهاية",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTotalCard("مجموع الديون", totalDebts),
                _buildTotalCard("الربح الكلي", totalProfit),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];

                  final name = (product['productName'] ?? 'غير محدد').toString();
                  final code = (product['productCodeBar'] ?? '-').toString();
                  final quantity = (product['productQuantity'] ?? 0).toString();
                  final price = (product['productPrice'] ?? 0).toString();
                  final buyingPrice = (product['productBuyingPrice'] ?? 0).toString();

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      onTap: () => _editProductPrice(product),
                      title: Text(name),
                      subtitle: Text("الكود: $code - الكمية: $quantity"),
                      trailing: SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("سعر البيع: $price دج"),
                            Text("سعر الشراء: $buyingPrice دج"),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: MyColors.secondColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
