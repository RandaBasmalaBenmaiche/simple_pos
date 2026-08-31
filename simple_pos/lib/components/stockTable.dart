import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/components/scrollArrowButtons.dart';
import 'package:simple_pos/services/formatters/display_formatters.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';

class POSStockItemsTable extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback sellItems;
  final Function(int index, String newQuantity) onQuantityChanged;
  final Function(int index, int newMinStock) onMinStockChanged;
  final Function(int index) onDelete;
  final VoidCallback onStockUpdated;

  const POSStockItemsTable({
    super.key,
    required this.items,
    required this.sellItems,
    required this.onQuantityChanged,
    required this.onMinStockChanged,
    required this.onDelete,
    required this.onStockUpdated,
  });

  @override
  State<POSStockItemsTable> createState() => _POSStockItemsTableState();
}

class _POSStockItemsTableState extends State<POSStockItemsTable> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, FocusNode> _focusNodes = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant POSStockItemsTable oldWidget) {
    super.didUpdateWidget(oldWidget);

    for (var item in widget.items) {
      final itemId = item['id'] as int;
      final controller = _controllers[itemId];
      if (controller != null) {
        final currentVal = DisplayFormatters.quantity(item['productQuantity']);
        if (controller.text != currentVal) {
          controller.text = currentVal;
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Color _getCardColor(Map<String, dynamic> item) {
    final stock = double.tryParse(item['productQuantity']?.toString() ?? '0') ?? 0;
    final minStock = item['min_stock'] as int? ?? 0;

    if (stock == 0) {
      return Colors.red[100]!;
    } else if (stock <= minStock) {
      return Colors.yellow[100]!;
    } else {
      return Colors.green[100]!;
    }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MyColors.secondColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MyColors.mainColor(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text("سعر البيع", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                Expanded(flex: 2, child: Text("الكمية", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                Expanded(flex: 4, child: Text("الاسم", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                Expanded(flex: 3, child: Text("الكود", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                SizedBox(width: 48),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: ScrollArrowButtons(
              onScrollUp: () => _scrollBy(-220),
              onScrollDown: () => _scrollBy(220),
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                final itemId = item['id'] as int;
                final controller = _controllers.putIfAbsent(
                  itemId,
                  () => TextEditingController(
                    text: DisplayFormatters.quantity(item['productQuantity']),
                  ),
                );
                final focusNode =
                    _focusNodes.putIfAbsent(itemId, () => FocusNode());

                return InkWell(
                  onTap: () async {
                    final currentQty = item['productQuantity']?.toString() ?? '0';
                    final currentMinStock = item['min_stock'] as int? ?? 0;
                    final addStockController = TextEditingController();
                    final minStockController = TextEditingController(text: currentMinStock.toString());

                    await showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item['productName']?.toString() ?? 'منتج',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              _buildStockTextField(
                                label: "الكمية الحالية",
                                value: currentQty,
                                readOnly: true,
                              ),
                              const SizedBox(height: 10),
                              _buildStockTextField(
                                label: "إضافة كمية",
                                controller: addStockController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly],
                              ),
                              const SizedBox(height: 10),
                              _buildStockTextField(
                                label: "الحد الأدنى للمخزون",
                                controller: minStockController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("إلغاء"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final addAmount = double.tryParse(
                                          addStockController.text);
                                      final minStock = int.tryParse(
                                          minStockController.text);

                                      final productId = item['id'] as int;
                                      final stockTable = DStockTable();
                                      final success = await stockTable.updateStockAndMinStock(
                                        id: productId,
                                        addAmount: addAmount,
                                        newMinStock: minStock,
                                      );

                                      if (success) {
                                        Navigator.pop(context);
                                        widget.onStockUpdated();
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("حدث خطأ أثناء التحديث")),
                                        );
                                      }
                                    },
                                    child: const Text("حفظ"),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: _getCardColor(item),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            DisplayFormatters.price(item['productPrice']),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 68,
                              height: 42,
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onTap: () {
                                  controller.selection = TextSelection(
                                    baseOffset: 0,
                                    extentOffset: controller.text.length,
                                  );
                                },
                                onChanged: (value) {
                                  final normalized = DisplayFormatters.quantity(value);
                                  if (controller.text != normalized) {
                                    controller.value = TextEditingValue(
                                      text: normalized,
                                      selection: TextSelection.collapsed(
                                        offset: normalized.length,
                                      ),
                                    );
                                  }
                                  widget.onQuantityChanged(
                                    index,
                                    int.parse(normalized).toString(),
                                  );
                                },
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            item['productName']?.toString() ?? 'بدون اسم',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            item['productCodeBar']?.toString() ?? 'بدون كود',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => widget.onDelete(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ),],
      ),
    );
  }

  Widget _buildStockTextField({
    required String label,
    TextEditingController? controller,
    String? value,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller ?? (value != null ? TextEditingController(text: value) : null),
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
