import 'dart:async';
import 'package:flutter/material.dart';
import 'package:simple_pos/components/scrollArrowButtons.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/services/local_database/model/tablecustomers.dart';
import 'package:simple_pos/services/local_database/model/tableinvoice.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/formatters/display_formatters.dart';
import 'package:simple_pos/services/supabase/web_realtime_service.dart';
import 'package:simple_pos/services/supabase/web_runtime.dart';
import 'package:simple_pos/services/utils/sort_utils.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:bidi/bidi.dart' as bidi_lib;

class POSPageOverview extends StatefulWidget {
  const POSPageOverview({Key? key}) : super(key: key);

  @override
  _POSPageOverviewState createState() => _POSPageOverviewState();
}

class _POSPageOverviewState extends State<POSPageOverview> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> allProducts = [];
  double totalDebts = 0;
  double totalProfit = 0;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Set<String>>? _realtimeSub;

  TextEditingController searchController = TextEditingController();
  TextEditingController applyAllController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  SortMode _sortMode = SortMode.latin;
  SortOrder _sortOrder = SortOrder.ascending;

  @override
  void initState() {
    super.initState();
    final store = BlocProvider.of<StoreCubit>(context, listen: false).state;
    _loadData(store);
    searchController.addListener(_onSearchChanged);
    if (useSupabaseWeb) {
      _realtimeSub = WebRealtimeService.instance.changes.listen((tables) {
        if ((tables.contains('stock') ||
                tables.contains('customers') ||
                tables.contains('invoices')) &&
            mounted) {
          final currentStore =
              BlocProvider.of<StoreCubit>(context, listen: false).state;
          _loadData(currentStore);
        }
      });
    }
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    _realtimeSub?.cancel();
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _scrollBy(double delta) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target =
        (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
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
      allProducts = loadedProducts;
      products = sortProducts(allProducts, _sortMode, order: _sortOrder);
      totalProfit = profit;
      totalDebts = debts;
    });
  }

  void _toggleSortMode() {
    setState(() {
      _sortMode = _sortMode == SortMode.latin ? SortMode.arabic : SortMode.latin;
      _sortOrder = SortOrder.ascending; // Reset to ascending when changing mode
      products = sortProducts(allProducts, _sortMode, order: _sortOrder);
    });
  }

  void _toggleSortOrder() {
    setState(() {
      _sortOrder = _sortOrder == SortOrder.ascending ? SortOrder.descending : SortOrder.ascending;
      products = sortProducts(allProducts, _sortMode, order: _sortOrder);
    });
  }

  void _onSearchChanged() {
    final query = searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        products = sortProducts(allProducts, _sortMode, order: _sortOrder);
      });
      return;
    }

    final filtered = allProducts.where((item) {
      final name = (item['productName'] ?? '').toString().toLowerCase();
      final code = (item['productCodeBar'] ?? '').toString().toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();

    setState(() {
      products = sortProducts(filtered, _sortMode, order: _sortOrder);
    });
  }

  String _fixArabic(String text) {
    try {
      final reshaped = ArabicReshaper().reshape(text);
      final visualCodes = bidi_lib.logicalToVisual(reshaped);
      return String.fromCharCodes(visualCodes);
    } catch (e) {
      return text;
    }
  }

  Color _getProductPastelColor(Map<String, dynamic> product) {
    final stock = double.tryParse(product['productQuantity']?.toString() ?? '0') ?? 0;
    final minStock = double.tryParse(product['min_stock']?.toString() ?? '0') ?? 0;

    if (stock <= 0) {
      return const Color(0xFFFFCDD2); // Pastel Red
    } else if (stock <= minStock) {
      return const Color(0xFFFFF9C4); // Pastel Yellow
    } else {
      return const Color(0xFFC8E6C9); // Pastel Green
    }
  }

  Future<void> _applyAllMinStock(int store) async {
    final valueText = applyAllController.text;
    final minStock = int.tryParse(valueText);

    if (minStock == null || minStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال رقم صحيح غير سالب')),
      );
      return;
    }

    final allProducts = await DStockTable().getProductsByStore(store);
    for (var product in allProducts) {
      await DStockTable().updateProductById(
        id: product['id'] as int,
        newMinStock: minStock,
      );
    }

    await _loadData(store);
    applyAllController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث الحد الأدنى لجميع المنتجات')),
    );
  }

  Future<void> _exportLowStockPdf(int store) async {
    final options = <String, String>{
      'low': 'المنتجات ذات المخزون المنخفض',
      'out': 'المنتجات المنتهية',
      'yellow': 'المنتجات ذات المخزون المنخفض فقط',
    };

    final selection = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تصدير تقرير المخزون", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(options['low']!),
              subtitle: const Text("المنتجات الصفراء والحمراء"),
              onTap: () => Navigator.pop(context, 'low'),
            ),
            ListTile(
              title: Text(options['yellow']!),
              subtitle: const Text("المنتجات الصفراء فقط"),
              onTap: () => Navigator.pop(context, 'yellow'),
            ),
            ListTile(
              title: Text(options['out']!),
              subtitle: const Text("المنتجات الحمراء فقط"),
              onTap: () => Navigator.pop(context, 'out'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
        ],
      ),
    );

    if (selection == null) return;

    final allProducts = await DStockTable().getProductsByStore(store);
    final filtered = allProducts.where((dynamic itemObj) {
      final item = itemObj as Map<String, dynamic>;

      final stockStr = item['productQuantity']?.toString() ?? '0';
      final minStockStr = item['min_stock']?.toString() ?? '0';

      final stock = double.tryParse(stockStr) ?? 0.0;
      final minStock = double.tryParse(minStockStr) ?? 0.0;

      if (selection == 'out') {
        return stock <= 0;
      } else if (selection == 'yellow') {
        return stock > 0 && stock <= minStock;
      } else if (selection == 'low') {
        return stock <= minStock;
      }

      return false;
    }).toList();

    if (filtered.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا توجد منتجات تطابق هذا الشرط ($selection) - العدد: 0')),
      );
      return;
    }

    final fontData = await rootBundle.load("assets/fonts/NotoNaskhArabic-VariableFont_wght.ttf");
    final ttf = pw.Font.ttf(fontData);

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.ltr,
        build: (pw.Context context) {
          return [
            pw.Text(
              _fixArabic(selection == 'low' ? options['low']! : (selection == 'out' ? options['out']! : options['yellow']!)),
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: ttf),
              textAlign: pw.TextAlign.right,
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: [
                _fixArabic("المخزون الحالي"),
                _fixArabic("اسم المنتج"),
              ],
              data: filtered.map((item) {
                final product = item as Map<String, dynamic>;
                return [
                  product['productQuantity']?.toString() ?? '0',
                  _fixArabic(product['productName']?.toString() ?? ''),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
              cellStyle: pw.TextStyle(font: ttf),
              cellAlignment: pw.Alignment.centerRight,
              border: pw.TableBorder.all(width: 0.5),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _editProductDetails(Map<String, dynamic> product) async {
    final buyingController =
        TextEditingController(text: (product['productBuyingPrice'] ?? 0).toString());
    final sellingController =
        TextEditingController(text: (product['productPrice'] ?? 0).toString());
    final minStockController =
        TextEditingController(text: (product['min_stock'] ?? 0).toString());

    final store = BlocProvider.of<StoreCubit>(context, listen: false).state;

    final buyingFocusNode = FocusNode();
    final sellingFocusNode = FocusNode();
    final minStockFocusNode = FocusNode();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("تعديل ${product['productName'] ?? 'غير محدد'}"),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
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
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      FocusScope.of(context).requestFocus(minStockFocusNode);
                    },
                  ),
                  TextField(
                    controller: minStockController,
                    focusNode: minStockFocusNode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "الحد الأدنى للمخزون"),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      double newBuying =
                          double.tryParse(buyingController.text) ?? 0;
                      double newSelling =
                          double.tryParse(sellingController.text) ?? 0;
                      int newMinStock =
                          int.tryParse(minStockController.text) ?? 0;

                      final stockTable = DStockTable();
                      bool success = false;
                      final productId = product['id'] as int?;

                      if (productId != null) {
                        success = await stockTable.updateProductById(
                          id: productId,
                          newBuyingPrice: newBuying.toString(),
                          newPrice: newSelling.toString(),
                          newMinStock: newMinStock,
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
                  int newMinStock =
                      int.tryParse(minStockController.text) ?? 0;

                  final stockTable = DStockTable();
                  bool success = false;
                  final productId = product['id'] as int?;

                  if (productId != null) {
                    success = await stockTable.updateProductById(
                      id: productId,
                      newBuyingPrice: newBuying.toString(),
                      newPrice: newSelling.toString(),
                      newMinStock: newMinStock,
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
    minStockController.dispose();
    buyingFocusNode.dispose();
    sellingFocusNode.dispose();
    minStockFocusNode.dispose();
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

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "لوحة التحكم",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text("تصفية حسب التاريخ", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _pickStartDate,
                  child: Text(
                    startDate != null
                        ? DateFormat('yyyy-MM-dd').format(startDate!)
                        : "البداية",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _pickEndDate,
                  child: Text(
                    endDate != null
                        ? DateFormat('yyyy-MM-dd').format(endDate!)
                        : "النهاية",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text("ترتيب المنتجات", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _toggleSortMode,
                  icon: Icon(_sortMode == SortMode.latin ? Icons.sort : Icons.sort_outlined, size: 18),
                  label: Text(
                    _sortMode == SortMode.latin ? "A-Z" : "عربي",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _toggleSortOrder,
                  icon: Icon(_sortOrder == SortOrder.ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
                  label: Text(
                    _sortOrder == SortOrder.ascending ? "تصاعدي" : "تنازلي",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text("إدارة المخزون", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              children: [
                TextField(
                  controller: applyAllController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "الحد الأدنى للكل",
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final store = BlocProvider.of<StoreCubit>(context, listen: false).state;
                      _applyAllMinStock(store);
                    },
                    child: const Text("تطبيق على الكل"),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final store = BlocProvider.of<StoreCubit>(context, listen: false).state;
                      _exportLowStockPdf(store);
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text("تصدير PDF"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Padding(
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
              _buildTotalCard("مجموع الديون", totalDebts),
              _buildTotalCard("الربح الكلي", totalProfit),
            ],
          ),
          const SizedBox(height: 20),
          ScrollArrowButtons(
            onScrollUp: () => _scrollBy(-220),
            onScrollDown: () => _scrollBy(220),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final name = (product['productName'] ?? 'غير محدد').toString();
                final code = (product['productCodeBar'] ?? '-').toString();
                final quantity = (product['productQuantity'] ?? 0).toString();
                final price = DisplayFormatters.price(product['productPrice']);
                final buyingPrice =
                    DisplayFormatters.price(product['productBuyingPrice']);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  color: _getProductPastelColor(product),
                  child: ListTile(
                    onTap: () => _editProductDetails(product),
                    title: Text(name),
                    subtitle: Text(
                      "الكود: $code - الكمية: ${DisplayFormatters.quantity(quantity)}",
                    ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: const CustomPOSAppBar(showReturnButton: true, showTitle: false),
      body: isWideScreen
          ? Row(
              children: [
                _buildSidebar(context),
                Expanded(child: _buildMainContent(context)),
              ],
            )
          : Padding(
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _toggleSortMode,
                        icon: Icon(_sortMode == SortMode.latin ? Icons.sort : Icons.sort_outlined),
                        label: Text(
                          _sortMode == SortMode.latin ? "A-Z ↔️ العربية" : "العربية ↔️ A-Z",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyColors.mainColor(context),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _toggleSortOrder,
                        icon: Icon(_sortOrder == SortOrder.ascending ? Icons.arrow_upward : Icons.arrow_downward),
                        label: Text(
                          _sortOrder == SortOrder.ascending ? "تصاعدي ↑" : "تنازلي ↓",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyColors.mainColor(context),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: applyAllController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "الحد الأدنى للكل",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                final store = BlocProvider.of<StoreCubit>(context, listen: false).state;
                                _applyAllMinStock(store);
                              },
                              child: const Text("تطبيق"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final store = BlocProvider.of<StoreCubit>(context, listen: false).state;
                              _exportLowStockPdf(store);
                            },
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text("تصدير تقرير المخزون"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                  ScrollArrowButtons(
                    onScrollUp: () => _scrollBy(-220),
                    onScrollDown: () => _scrollBy(220),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final name = (product['productName'] ?? 'غير محدد').toString();
                        final code = (product['productCodeBar'] ?? '-').toString();
                        final quantity = (product['productQuantity'] ?? 0).toString();
                        final price = DisplayFormatters.price(product['productPrice']);
                        final buyingPrice =
                            DisplayFormatters.price(product['productBuyingPrice']);

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          color: _getProductPastelColor(product),
                          child: ListTile(
                            onTap: () => _editProductDetails(product),
                            title: Text(name),
                            subtitle: Text(
                              "الكود: $code - الكمية: ${DisplayFormatters.quantity(quantity)}",
                            ),
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
