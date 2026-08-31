import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/components/addProductDialog.dart';
import 'package:simple_pos/components/sellButton.dart';
import 'package:simple_pos/components/stockTable.dart';
import 'package:simple_pos/components/updateProductDialog.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/services/platform/download_text.dart';
import 'package:simple_pos/services/platform/file_text.dart';
import 'package:simple_pos/services/supabase/web_realtime_service.dart';
import 'package:simple_pos/services/supabase/web_runtime.dart';
import 'package:simple_pos/services/utils/sort_utils.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/main.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:bidi/bidi.dart' as bidi_lib;

class POSPageStock extends StatefulWidget {
  const POSPageStock({super.key});

  @override
  _POSPageState createState() => _POSPageState();
}

class _POSPageState extends State<POSPageStock> with RouteAware {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> allItems = [];
  TextEditingController searchController = TextEditingController();
  TextEditingController applyAllController = TextEditingController();
  StreamSubscription<Set<String>>? _realtimeSub;
  late final DStockTable _stockTable;
  late int _currentStoreId;
  SortMode _sortMode = SortMode.latin;
  SortOrder _sortOrder = SortOrder.ascending;

  @override
  void initState() {
    super.initState();
    _stockTable = DStockTable();
    _currentStoreId = BlocProvider.of<StoreCubit>(context, listen: false).state;
    _loadItems(_currentStoreId);
    searchController.addListener(_onSearchChanged);
    if (useSupabaseWeb) {
      _realtimeSub = WebRealtimeService.instance.changes.listen((tables) {
        if (tables.contains('stock') && mounted) {
          _loadItems(_currentStoreId);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _realtimeSub?.cancel();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadItems(_currentStoreId);
  }

  Future<void> _loadItems(int store) async {
    final rawItems = await _stockTable.getProductsByStore(store);

    final loadedItems = rawItems.map((item) {
      return {
        ...item,
        'productPrice': item['productPrice'] ?? '',
        'productBuyingPrice': item['productBuyingPrice'] ?? '',
        'productCodeBar': item['productCodeBar'] ?? '',
        'productQuantity': item['productQuantity'] ?? '',
      };
    }).toList();

    if (mounted) {
      setState(() {
        allItems = loadedItems;
        items = sortProducts(allItems, _sortMode, order: _sortOrder);
      });
    }
  }

  void _toggleSortMode() {
    setState(() {
      _sortMode = _sortMode == SortMode.latin ? SortMode.arabic : SortMode.latin;
      _sortOrder = SortOrder.ascending;
      items = sortProducts(allItems, _sortMode, order: _sortOrder);
    });
  }

  void _toggleSortOrder() {
    setState(() {
      _sortOrder = _sortOrder == SortOrder.ascending ? SortOrder.descending : SortOrder.ascending;
      items = sortProducts(allItems, _sortMode, order: _sortOrder);
    });
  }

  void _onSearchChanged() {
    final query = searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() => items = sortProducts(allItems, _sortMode, order: _sortOrder));
      return;
    }

    final filtered = allItems.where((item) {
      final code = (item['productCodeBar'] ?? '').toString().toLowerCase();
      final name = (item['productName'] ?? '').toString().toLowerCase();
      return code.contains(query) || name.contains(query);
    }).toList();

    setState(() => items = sortProducts(filtered, _sortMode, order: _sortOrder));
  }

  Future<void> importProductsFromCSV(int store) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null) {
      final picked = result.files.single;
      String? csvString;

      if (picked.bytes != null) {
        csvString = utf8.decode(picked.bytes!);
      } else if (picked.path != null) {
        csvString = await readTextFile(picked.path!);
      }

      if (csvString == null) return;
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);

      int added = 0;
      int updated = 0;
      for (var i = 1; i < csvTable.length; i++) {
        var row = csvTable[i];
        final result = await _stockTable.upsertRecord({
          'store_id': store,
          'productName': row[0].toString(),
          'productPrice': row[1]?.toString().isNotEmpty == true ? row[1].toString() : null,
          'productBuyingPrice': row[2]?.toString().isNotEmpty == true ? row[2].toString() : null,
          'productCodeBar': row[3]?.toString().isNotEmpty == true ? row[3].toString() : null,
          'productQuantity': row[4]?.toString().isNotEmpty == true ? row[4].toString() : null,
        });
        if (result.id < 0) continue;
        if (result.created) {
          added += 1;
        } else {
          updated += 1;
        }
      }

      await _loadItems(store);
      if (!mounted) return;
      if (added == 0 && updated == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على منتجات في الملف')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم استيراد المنتجات: $added جديد، $updated محدث',
            ),
          ),
        );
      }
    }
  }

  Future<void> exportProductsToCSV() async {
    final currentStore = BlocProvider.of<StoreCubit>(context, listen: false).state;
    final allProducts = await _stockTable.getProductsByStore(currentStore);
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

    if (kIsWeb) {
      await downloadTextFile('products_export.csv', csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تنزيل ملف المنتجات')),
      );
      return;
    }

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'اختر مكان حفظ الملف',
      fileName: 'products_export.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputFile != null) {
      await writeTextFile(outputFile, csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تصدير المنتجات إلى $outputFile')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء التصدير')),
      );
    }
  }

  String _fixArabic(String text) {
    try {
      final reshaped = ArabicReshaper().reshape(text);
      return String.fromCharCodes(bidi_lib.logicalToVisual(reshaped));
    } catch (e) {
      return text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreCubit>().state;
    if (_currentStoreId != store) {
      _currentStoreId = store;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadItems(store);
        }
      });
    }
    return Scaffold(
      appBar: const CustomPOSAppBar(showReturnButton: true, showTitle: false),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
                      prefixIcon: Icon(Icons.search, color: MyColors.mainColor(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _loadItems(store),
                    icon: const Icon(Icons.refresh),
                    style: IconButton.styleFrom(
                      backgroundColor: MyColors.mainColor(context).withOpacity(0.1),
                      shape: const CircleBorder(),
                    ),
                    tooltip: "تحديث",
                  ),
                  const SizedBox(width: 10),
                  CustomActionButton(
                    text: "اضافة للسلع",
                    onPressed: () {
                      showAddProductDialog(context, (String name, String price, String buyingPrice, String quantity, String code) async {
                        await _stockTable.insertRecord(<String, dynamic>{
                          "productName": name,
                          "store_id": store,
                          "productPrice": price.isNotEmpty ? price : null,
                          "productBuyingPrice": buyingPrice.isNotEmpty ? buyingPrice : null,
                          "productQuantity": quantity.isNotEmpty ? quantity : null,
                          "productCodeBar": code.isNotEmpty ? code : null,
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
                  const SizedBox(width: 10),
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
            ),
            const SizedBox(height: 20),
            Expanded(
              child: POSStockItemsTable(
                items: items,
                sellItems: () {},
                onQuantityChanged: (index, newQuantity) async {
                  final product = items[index];
                  final productKeyId = product['id'];

                  setState(() {
                    items[index]["productQuantity"] = newQuantity;
                    final allIndex =
                        allItems.indexWhere((e) => e['id'] == productKeyId);
                    if (allIndex != -1) allItems[allIndex]["productQuantity"] = newQuantity;
                  });

                  final productId = product['id'] as int?;
                  final success = productId != null
                      ? await _stockTable.updateProductById(
                          id: productId,
                          newQuantity:
                              newQuantity.isNotEmpty ? newQuantity : null,
                        )
                      : await _stockTable.updateProduct(
                          codeBar: product['productCodeBar'] ?? '',
                          newQuantity:
                              newQuantity.isNotEmpty ? newQuantity : null,
                          storeId: store,
                        );
                  if (!success && mounted) {
                    await _loadItems(store);
                  }
                },
                onMinStockChanged: (index, newMinStock) async {
                  final product = items[index];
                  final productId = product['id'] as int?;

                  setState(() {
                    items[index]["min_stock"] = newMinStock;
                    final allIndex = allItems.indexWhere((e) => e['id'] == productId);
                    if (allIndex != -1) allItems[allIndex]["min_stock"] = newMinStock;
                  });

                  final success = productId != null
                      ? await _stockTable.updateProductById(
                          id: productId,
                          newMinStock: newMinStock,
                        )
                      : false; // MinStock update by ID is preferred

                  if (!success && mounted) {
                    await _loadItems(store);
                  }
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
                    final productId = product['id'] as int?;
                    final success = productId != null
                        ? await _stockTable.deleteProductById(productId)
                        : await _stockTable.deleteProduct(
                            product['productCodeBar'] ?? '',
                            store,
                          );
                              if (success) {
                        setState(() {
                          items.removeAt(index);
                          if (productId != null) {
                            allItems.removeWhere((e) => e['id'] == productId);
                          }
                        });
                      } else if (mounted) {
                        await _loadItems(store);
                      }
                    }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
