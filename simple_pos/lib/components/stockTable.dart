import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/components/scrollArrowButtons.dart';
import 'package:simple_pos/services/formatters/display_formatters.dart';
import 'package:simple_pos/styles/my_colors.dart';

class POSStockItemsTable extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback sellItems;
  final Function(int index, String newQuantity) onQuantityChanged;
  final Function(int index) onDelete;

  const POSStockItemsTable({
    super.key,
    required this.items,
    required this.sellItems,
    required this.onQuantityChanged,
    required this.onDelete,
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
    final currentIds = widget.items.map((item) => item['id'] as int).toSet();
    final keysToRemove =
        _controllers.keys.where((id) => !currentIds.contains(id)).toList();
    for (final key in keysToRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
      _focusNodes[key]?.dispose();
      _focusNodes.remove(key);
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
                );
              },
            ),
          ),
      )],
      ),
    );
  }
}
