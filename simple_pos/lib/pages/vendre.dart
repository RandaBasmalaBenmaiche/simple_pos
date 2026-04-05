/**
 * maybe start using the loaded items instead of database calls?
 */
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/components/AutoComplete.dart';
import 'package:simple_pos/components/clientSelector.dart';
import 'package:simple_pos/components/invoicePreviewPage.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/components/alphaNumericInputField.dart';
import 'package:simple_pos/components/paying.dart';
import 'package:simple_pos/components/sellButton.dart';
import 'package:simple_pos/components/sellTable.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/formatters/display_formatters.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/services/supabase/web_realtime_service.dart';
import 'package:simple_pos/services/supabase/web_runtime.dart';
import 'package:simple_pos/services/transactions/local_sale_service.dart';
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
  final TextEditingController payingController = TextEditingController();

  List<Map<String, dynamic>> items = [];
  double total = 0;
  final FocusNode codeFocusNode = FocusNode();
  final FocusNode nameFocusNode = FocusNode();
  final FocusNode quantityFocusNode = FocusNode();
  final FocusNode keyboardFocusNode = FocusNode();

  List<String> allItems = [];

  bool autoMode = true;
  bool quantity = true;
  int lastFcous = 0; // 0 for code, 1 for name
  int? _previousStoreId; // Track store to clear cart on switch
  final LocalSaleService _localSaleService = LocalSaleService();
  StreamSubscription<Set<String>>? _realtimeSub;

  // Selected client info
  Map<String, dynamic>? _selectedClient;

  void addItem(int store) async {
    bool isName = false;
    String codeInput = codeController.text.trim();
    String nameInput = nameController.text.trim();
    int quantity = int.tryParse(quantityController.text) ?? 0;

    if ((codeInput.isEmpty && nameInput.isEmpty) || quantity <= 0) {
      return;
    }

    Map<String, dynamic>? product;

    // Priority: code first, fallback to name
    if (codeInput.isNotEmpty) {
      product = await DStockTable().getProductByCode(codeInput, store);
    } else if (nameInput.isNotEmpty) {
      product = await DStockTable().getProductByName(nameInput, store);
      isName = true;
    }

    if (product == null) {
      if (!mounted) return;
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
      return;
    }

    // Null-safe values
    final codeBar = product['productCodeBar']?.toString() ?? '';
    final name = product['productName']?.toString() ?? 'بدون اسم';
    final price = double.tryParse(product['productPrice']?.toString() ?? '') ?? 0.0;
    final buyingPrice = double.tryParse(product['productBuyingPrice']?.toString() ?? '0') ?? 0.0;
    final availableStock = int.tryParse(product['productQuantity']?.toString() ?? '0') ?? 0;

    // Check if requested quantity exceeds available stock
    if (quantity > availableStock) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("خطأ"),
          content: Text("الكمية المطلوبة ($quantity) تفوق الكمية المتوفرة ($availableStock)"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("حسناً"),
            ),
          ],
        ),
      );
      return;
    }

    codeController.text = codeBar;
    nameController.text = name;

    // Check if already in invoice
    var existIndex = items.indexWhere((p) =>
      isName
        ? p['productName'] == name
        : p['productCodeBar'] == codeBar
    );

    if (existIndex != -1) {
      final currentQty = int.tryParse(items[existIndex]['productQuantity']?.toString() ?? '0') ?? 0;
      final newQty = currentQty + quantity;
      // Check if combined quantity exceeds stock
      if (newQty > availableStock) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("خطأ"),
            content: Text("الكمية في السلة تفوق الكمية المتوفرة ($availableStock)"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("حسناً"),
              ),
            ],
          ),
        );
        return;
      }
      // Create a new list with a new Map for the updated item to trigger Flutter's diffing
      final updatedItem = Map<String, dynamic>.from(items[existIndex]);
      updatedItem['productQuantity'] = newQty.toString();
      updatedItem['total'] = (newQty * price).toStringAsFixed(2);

      setState(() {
        items[existIndex] = updatedItem;
        _clearInputs();
        _updateTotal();
      });
      return;
    }

    // Add new item
    double itemTotal = price * quantity;
    Map<String, dynamic> item = {
      "productCodeBar": codeBar,
      "productName": name,
      "productPrice": price.toStringAsFixed(2),
      "productBuyingPrice": buyingPrice.toStringAsFixed(2),
      "productQuantity": quantity.toString(),
      "total": itemTotal.toStringAsFixed(2),
    };
    if (!mounted) return;
    setState(() {
      items.add(item);
      total += itemTotal;
      _clearInputs();
    });
  }

  void _clearInputs() {
    codeController.clear();
    nameController.clear();
    quantityController.clear();
  }

  void _updateTotal() {
    total = items.fold<double>(
      0.0,
      (sum, item) {
        final itemTotal = double.tryParse(item['total']?.toString() ?? '0') ?? 0.0;
        return sum + itemTotal;
      },
    );
  }

  Future<void> sellItems(int store) async {
    await _commitSale(store: store);
  }

  Future<int?> _commitSale({required int store, double? paidAmount}) async {
    if (items.isEmpty) {
      return null;
    }

    try {
      final result = await _localSaleService.sellCart(
        storeId: store,
        items: List<Map<String, dynamic>>.from(items),
        customer: _selectedClient,
        paidAmount: paidAmount,
      );

      if (!mounted) {
        return result.invoiceId;
      }

      setState(() {
        items.clear();
        total = 0;
        _selectedClient = null;
        payingController.clear();
      });
      return result.invoiceId;
    } on LocalSaleException catch (error) {
      if (!mounted) {
        return null;
      }
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("خطأ"),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("حسناً"),
            ),
          ],
        ),
      );
      return null;
    } catch (_) {
      if (!mounted) {
        return null;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تعذر إتمام عملية البيع")),
      );
      return null;
    }
  }

  Future<void> _loadItems() async {
    final currentStoreId = BlocProvider.of<StoreCubit>(context, listen: false).state;
    final rawItems = await DStockTable().getProductsByStore(currentStoreId);

    setState(() {
      allItems = rawItems
          .map((item) => item["productName"]?.toString() ?? 'بدون اسم')
          .toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(codeFocusNode);
    });
    if (useSupabaseWeb) {
      _realtimeSub = WebRealtimeService.instance.changes.listen((tables) {
        if ((tables.contains('stock') || tables.contains('customers')) && mounted) {
          _loadItems();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentStoreId = context.watch<StoreCubit>().state;
    // Clear cart and reload items when switching stores
    if (_previousStoreId != null && _previousStoreId != currentStoreId) {
      setState(() {
        items.clear();
        total = 0;
        _selectedClient = null;
      });
      _loadItems();
    }
    _previousStoreId = currentStoreId;
  }

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
    quantityController.dispose();
    payingController.dispose();
    codeFocusNode.dispose();
    nameFocusNode.dispose();
    quantityFocusNode.dispose();
    keyboardFocusNode.dispose();
    _realtimeSub?.cancel();
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
            if (autoMode) {
              addItem(currentStoreId);
              keyboardFocusNode.unfocus();
              if (lastFcous == 0) {
                Future.delayed(const Duration(milliseconds: 50), () {
                  FocusScope.of(context).requestFocus(codeFocusNode);
                });
              } else if (lastFcous == 1) {
                Future.delayed(const Duration(milliseconds: 50), () {
                  FocusScope.of(context).requestFocus(nameFocusNode);
                });
              }
            } else {
              if (quantity) {
                Future.delayed(const Duration(milliseconds: 50), () {
                  FocusScope.of(context).requestFocus(quantityFocusNode);
                });
                quantity = !quantity;
              } else {
                addItem(currentStoreId);
                keyboardFocusNode.unfocus();
                if (lastFcous == 0) {
                  Future.delayed(const Duration(milliseconds: 50), () {
                    FocusScope.of(context).requestFocus(codeFocusNode);
                  });
                } else if (lastFcous == 1) {
                  Future.delayed(const Duration(milliseconds: 50), () {
                    FocusScope.of(context).requestFocus(nameFocusNode);
                  });
                }
                quantity = !quantity;
              }
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Text("وضع يدوي",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: MyColors.mainColor(context))),
                        Switch(
                          value: autoMode,
                          onChanged: (value) {
                            autoMode = !autoMode;
                            setState(() {});
                          },
                        ),
                        Text("وضع تلقائي",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: MyColors.mainColor(context))),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Text("الاسم",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: MyColors.mainColor(context))),
                        Switch(
                          value: (lastFcous == 0) ? true : false,
                          onChanged: (value) {
                            lastFcous = (lastFcous == 0) ? 1 : 0;
                            setState(() {});
                          },
                        ),
                        Text("الكود",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: MyColors.mainColor(context))),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  NumericInputField(
                    controller: quantityController,
                    label: "الكمية",
                    defaultValue: "1",
                    focusNode: quantityFocusNode,
                  ),
                  const SizedBox(width: 16),
                  AutoCompleteInputField(
                    controller: nameController,
                    label: "المنتج",
                    isAlphanumeric: true,
                    suggestions: allItems,
                    focusNode: nameFocusNode,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ClientSelector(
                      storeId: currentStoreId,
                      onClientSelected: (client) {
                        setState(() {
                          _selectedClient = client;
                        });
                      },
                      initialClient: _selectedClient,
                    ),
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
              Flexible(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.68,
                  child: POSItemsTable(
                    items: items,
                    sellItems: () async => await sellItems(currentStoreId),
                    onQuantityChanged: (index, newQuantity) {
                      setState(() {
                        items[index]["productQuantity"] = newQuantity;
                        items[index]["total"] = ((int.tryParse(items[index]['productQuantity'] ?? '0') ?? 0) *
                                (double.tryParse(items[index]['productPrice'] ?? '0') ?? 0))
                            .toStringAsFixed(2);
                        _updateTotal();
                      });
                    },
                    onDelete: (index) {
                      setState(() {
                        items.removeAt(index);
                        _updateTotal();
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
                        " المبلغ الكلي:    دج${DisplayFormatters.price(total)}",
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
                            if (_selectedClient == null) {
                              showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text("خطأ"),
                                      content: const Text(
                                          "يجب اختيار زبون من اجل هذه الخدمة"),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text("حسناً"),
                                        ),
                                      ],
                                    );
                                  });
                            } else {
                              showPayingAmountDialog(
                                  context, payingController, (amount) async {
                                if (amount > total) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("المبلغ المدفوع أكبر من مجموع الفاتورة"),
                                    ),
                                  );
                                  return;
                                }
                                final invoiceId = await _commitSale(
                                  store: currentStoreId,
                                  paidAmount: amount,
                                );
                                if (mounted && invoiceId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            InvoicePreviewPage(invoiceId: invoiceId)),
                                  );
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        CustomActionButton(
                          text: "بيع",
                          onPressed: () async {
                            final invoiceId = await _commitSale(store: currentStoreId);
                            if (mounted && invoiceId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        InvoicePreviewPage(invoiceId: invoiceId)),
                              );
                            }
                          },
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
