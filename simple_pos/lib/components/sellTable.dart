import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
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
    }
    // Update controller text for existing items to reflect quantity changes
    for (int i = 0; i < widget.items.length; i++) {
      final itemId = _itemKey(widget.items[i], i);
      if (_controllers.containsKey(itemId)) {
        final itemQty = widget.items[i]['productQuantity']?.toString() ?? '0';
        if (_controllers[itemId]!.text != itemQty) {
          _controllers[itemId]!.text = itemQty;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DataTable2(
        headingRowColor: MaterialStateProperty.all(MyColors.mainColor(context)),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 20,
        ),
        dataRowColor: MaterialStateProperty.all(MyColors.secondColor(context)),
        dataRowHeight: 100,
        columnSpacing: 12,
        horizontalMargin: 12,
        minWidth: 700,
        columns: const [
          DataColumn2(label: Text("المبلغ الاجمالي"), size: ColumnSize.M),
          DataColumn2(label: Text("سعر الوحدة"), size: ColumnSize.M),
          DataColumn2(label: Text("الكمية"), size: ColumnSize.S),
          DataColumn2(label: Text("الاسم"), size: ColumnSize.L),
          DataColumn2(label: Text("الكود"), size: ColumnSize.L),
          DataColumn2(label: Text(""), size: ColumnSize.S), // delete column
        ],
        rows: List.generate(widget.items.length, (index) {
          final item = widget.items[index];
          final itemId = _itemKey(item, index);

          // Null-safe accessors with defaults
          final total = item['total']?.toString() ?? '0.00';
          final price = item['productPrice']?.toString() ?? '0.00';
          final quantity = item['productQuantity']?.toString() ?? '0';
          final productName = item['productName']?.toString() ?? 'بدون اسم';
          final productCodeBar = item['productCodeBar']?.toString() ?? '-';

          return DataRow(
            cells: [
              DataCell(Text(total,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20))),
              DataCell(Text(price,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20))),
              DataCell(
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _controllers.putIfAbsent(itemId, () => TextEditingController(
                      text: quantity,
                    )),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      widget.onQuantityChanged(index, value); // update live
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.all(8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              DataCell(Text(productName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20))),
              DataCell(Text(productCodeBar,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20))),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => widget.onDelete(index),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
