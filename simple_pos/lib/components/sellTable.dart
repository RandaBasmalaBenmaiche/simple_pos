import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/components/scrollArrowButtons.dart';
import 'package:simple_pos/services/formatters/display_formatters.dart';
import 'package:simple_pos/styles/my_colors.dart';

class POSItemsTable extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback sellItems;
  final Function(int index, String newQuantity) onQuantityChanged;
  final Function(int index) onDelete;

  const POSItemsTable({
    super.key,
    required this.items,
    required this.sellItems,
    required this.onQuantityChanged,
    required this.onDelete,
  });

  @override
  State<POSItemsTable> createState() => _POSItemsTableState();
}

class _POSItemsTableState extends State<POSItemsTable> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final ScrollController _verticalController = ScrollController();

  String _itemKey(Map<String, dynamic> item, int index) {
    final id = item['id'];
    if (id != null) {
      return 'id:$id';
    }
    final code = item['productCodeBar']?.toString() ?? '';
    final name = item['productName']?.toString() ?? '';
    return 'row:$index:$code:$name';
  }

  @override
  void didUpdateWidget(covariant POSItemsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Build a set of current item IDs
    final currentIds = <String>{};
    for (int i = 0; i < widget.items.length; i++) {
      currentIds.add(_itemKey(widget.items[i], i));
    }
    // Clean up controllers for removed items
    final keysToRemove = _controllers.keys.where((id) => !currentIds.contains(id)).toList();
    for (final key in keysToRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
      _focusNodes[key]?.dispose();
      _focusNodes.remove(key);
    }
    // Update controller text for existing items to reflect quantity changes
    for (int i = 0; i < widget.items.length; i++) {
      final itemId = _itemKey(widget.items[i], i);
      if (_controllers.containsKey(itemId)) {
        final itemQty =
            DisplayFormatters.quantity(widget.items[i]['productQuantity']);
        if (_controllers[itemId]!.text != itemQty &&
            !(_focusNodes[itemId]?.hasFocus ?? false)) {
          _controllers[itemId]!.text = itemQty;
        }
      }
    }
  }

  @override
  void dispose() {
    _verticalController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _handleQuantityChange(int index, String itemId, String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    final normalized = DisplayFormatters.quantity(digitsOnly);
    final controller = _controllers[itemId];
    if (controller != null && controller.text != normalized) {
      controller.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    widget.onQuantityChanged(index, int.parse(normalized).toString());
  }

  Future<void> _scrollBy(double delta) async {
    if (!_verticalController.hasClients) return;
    final position = _verticalController.position;
    final target =
        (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    await _verticalController.animateTo(
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
                Expanded(flex: 4, child: Text("المنتج", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                Expanded(flex: 2, child: Text("الكود", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                Expanded(flex: 2, child: Text("الكمية", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                Expanded(flex: 2, child: Text("السعر", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                Expanded(flex: 2, child: Text("الإجمالي", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
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
            child: ListView.separated(
              controller: _verticalController,
              padding: const EdgeInsets.all(12),
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final itemId = _itemKey(item, index);
                final total = item['total']?.toString() ?? '0.00';
                final price = item['productPrice']?.toString() ?? '0.00';
                final quantity = DisplayFormatters.quantity(item['productQuantity']);
                final productName = item['productName']?.toString() ?? 'بدون اسم';
                final productCodeBar = item['productCodeBar']?.toString() ?? '-';

                final controller = _controllers.putIfAbsent(
                  itemId,
                  () => TextEditingController(text: quantity),
                );
                final focusNode = _focusNodes.putIfAbsent(
                  itemId,
                  () => FocusNode(),
                );

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          productName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          productCodeBar,
                          style: const TextStyle(fontSize: 16),
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
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onTap: () {
                                controller.selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: controller.text.length,
                                );
                              },
                              onChanged: (value) =>
                                  _handleQuantityChange(index, itemId, value),
                              onEditingComplete: () {
                                controller.text =
                                    DisplayFormatters.quantity(controller.text);
                                FocusScope.of(context).unfocus();
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
                        flex: 2,
                        child: Text(
                          DisplayFormatters.price(price),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          DisplayFormatters.price(total),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => widget.onDelete(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
