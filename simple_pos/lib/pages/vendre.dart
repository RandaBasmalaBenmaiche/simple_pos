library vendre;

/// redesigned POS page with responsive layout for mobile and desktop.
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
import 'package:simple_pos/components/cart_item_card.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/formatters/display_formatters.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/services/supabase/web_realtime_service.dart';
import 'package:simple_pos/services/supabase/web_runtime.dart';
import 'package:simple_pos/services/transactions/local_sale_service.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class POSPage extends StatefulWidget {
  const POSPage({super.key});

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
    int quantityValue = int.tryParse(quantityController.text) ?? 0;

    if ((codeInput.isEmpty && nameInput.isEmpty) || quantityValue <= 0) {
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
    if (quantityValue > availableStock) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("خطأ"),
          content: Text("الكمية المطلوبة ($quantityValue) تفوق الكمية المتوفرة ($availableStock)"),
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
      final newQty = currentQty + quantityValue;
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
    double itemTotal = price * quantityValue;
    Map<String, dynamic> item = {
      "productCodeBar": codeBar,
      "productName": name,
      "productPrice": price.toStringAsFixed(2),
      "productBuyingPrice": buyingPrice.toStringAsFixed(2),
      "productQuantity": quantityValue.toString(),
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: const CustomPOSAppBar(showReturnButton: true, showTitle: false),
      body: KeyboardListener(
        focusNode: keyboardFocusNode,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
            if (autoMode) {
              addItem(currentStoreId);
              keyboardFocusNode.unfocus();
              if (lastFcous == 0) {
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) FocusScope.of(context).requestFocus(codeFocusNode);
                });
              } else if (lastFcous == 1) {
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) FocusScope.of(context).requestFocus(nameFocusNode);
                });
              }
            } else {
              if (quantity) {
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) FocusScope.of(context).requestFocus(quantityFocusNode);
                });
                quantity = !quantity;
              } else {
                addItem(currentStoreId);
                keyboardFocusNode.unfocus();
                if (lastFcous == 0) {
                  Future.delayed(const Duration(milliseconds: 50), () {
                    if (mounted) FocusScope.of(context).requestFocus(codeFocusNode);
                  });
                } else if (lastFcous == 1) {
                  Future.delayed(const Duration(milliseconds: 50), () {
                    if (mounted) FocusScope.of(context).requestFocus(nameFocusNode);
                  });
                }
                quantity = !quantity;
              }
            }
          }
        },
        child: isMobile ? _buildMobileLayout(context, currentStoreId) : _buildDesktopLayout(context, currentStoreId),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, int storeId) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MyColors.secondColor(context).withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildModeSwitch("وضع يدوي", "وضع تلقائي", autoMode, (val) {
                    setState(() => autoMode = val);
                  }),
                  _buildModeSwitch("الاسم", "الكود", lastFcous == 0, (val) {
                    setState(() => lastFcous = val ? 0 : 1);
                  }),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: NumericInputField(
                      controller: quantityController,
                      label: "الكمية",
                      defaultValue: "1",
                      focusNode: quantityFocusNode,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: AutoCompleteInputField(
                      controller: nameController,
                      label: "المنتج",
                      isAlphanumeric: true,
                      suggestions: allItems,
                      focusNode: nameFocusNode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: NumericInputField(
                      controller: codeController,
                      label: "الكود",
                      isAlphanumeric: false,
                      focusNode: codeFocusNode,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.mainColor(context),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    onPressed: () => addItem(storeId),
                    child: const Text("إضافة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClientSelector(
                storeId: storeId,
                onClientSelected: (client) => setState(() => _selectedClient = client),
                initialClient: _selectedClient,
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text("السلة فارغة", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return CartItemCard(
                      item: items[index],
                      onQuantityChanged: (newQty) {
                        setState(() {
                          items[index]["productQuantity"] = newQty;
                          items[index]["total"] = ((newQty * (double.tryParse(items[index]['productPrice'] ?? '0') ?? 0.0)).toStringAsFixed(2));
                          _updateTotal();
                        });
                      },
                      onDelete: () {
                        setState(() {
                          items.removeAt(index);
                          _updateTotal();
                        });
                      },
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "المبلغ الكلي: ${DisplayFormatters.price(total)} دج",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: MyColors.mainColor(context)),
                    ),
                    const Icon(Icons.calculate, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: MyColors.mainColor(context)),
                        ),
                        onPressed: () => _handlePartialSell(context, storeId),
                        child: Text("بيع مجزئ", style: TextStyle(color: MyColors.mainColor(context), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyColors.mainColor(context),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => _handleFullSell(context, storeId),
                        child: const Text("بيع", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, int storeId) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildDesktopInputs(context, storeId),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: POSItemsTable(
                        items: items,
                        sellItems: () async => await sellItems(storeId),
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
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MyColors.secondColor(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "إتمام العملية",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 30),
                  ClientSelector(
                    storeId: storeId,
                    onClientSelected: (client) => setState(() => _selectedClient = client),
                    initialClient: _selectedClient,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        const Text("المجموع الكلي", style: TextStyle(color: Colors.white70, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          "${DisplayFormatters.price(total)} دج",
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomActionButton(
                    text: "بيع مجزئ",
                    onPressed: () => _handlePartialSell(context, storeId),
                  ),
                  const SizedBox(height: 12),
                  CustomActionButton(
                    text: "تأكيد البيع",
                    onPressed: () => _handleFullSell(context, storeId),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopInputs(BuildContext context, int storeId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildModeSwitch("وضع يدوي", "وضع تلقائي", autoMode, (val) {
                setState(() => autoMode = val);
              }),
              _buildModeSwitch("الاسم", "الكود", lastFcous == 0, (val) {
                setState(() => lastFcous = val ? 0 : 1);
              }),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              NumericInputField(
                controller: quantityController,
                label: "الكمية",
                defaultValue: "1",
                focusNode: quantityFocusNode,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AutoCompleteInputField(
                  controller: nameController,
                  label: "المنتج",
                  isAlphanumeric: true,
                  suggestions: allItems,
                  focusNode: nameFocusNode,
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
                text: "إضافة",
                onPressed: () => addItem(storeId),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitch(String left, String right, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Text(left, style: TextStyle(fontWeight: FontWeight.bold, color: MyColors.mainColor(context))),
        Switch(value: value, onChanged: onChanged),
        Text(right, style: TextStyle(fontWeight: FontWeight.bold, color: MyColors.mainColor(context))),
      ],
    );
  }

  Future<void> _handlePartialSell(BuildContext context, int storeId) async {
    if (_selectedClient == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("خطأ"),
            content: const Text("يجب اختيار زبون من اجل هذه الخدمة"),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("حسناً")),
            ],
          );
        },
      );
      return;
    }
    showPayingAmountDialog(context, payingController, (amount) async {
      if (amount > total) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("المبلغ المدفوع أكبر من مجموع الفاتورة")),
        );
        return;
      }
      final invoiceId = await _commitSale(store: storeId, paidAmount: amount);
      if (context.mounted && invoiceId != null) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => InvoicePreviewPage(invoiceId: invoiceId)));
      }
    });
  }

  Future<void> _handleFullSell(BuildContext context, int storeId) async {
    final invoiceId = await _commitSale(store: storeId);
    if (context.mounted && invoiceId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => InvoicePreviewPage(invoiceId: invoiceId)));
    }
  }
}
