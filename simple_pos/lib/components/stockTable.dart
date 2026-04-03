import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
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
  // Track which rows have visibility unlocked

  @override
  void didUpdateWidget(covariant POSStockItemsTable oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If items length changes, resize the visibility list safely

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
        dataRowHeight: 60,
        columnSpacing: 12,
        horizontalMargin: 12,
        minWidth: 700,
        columns: const [
          DataColumn2(label: Text("سعر الوحدة"), size: ColumnSize.S),
          DataColumn2(label: Text("الكمية"), size: ColumnSize.S),
          DataColumn2(label: Text("الاسم"), size: ColumnSize.L),
          DataColumn2(label: Text("الكود"), size: ColumnSize.M),
          DataColumn2(label: Text(""), size: ColumnSize.S), // actions column
        ],
        rows: List.generate(widget.items.length, (index) {
          final item = widget.items[index];

          // Handle optional fields with safe defaults
          final price = item['productPrice']?.toString();
          final quantity = item['productQuantity']?.toString();
          final name = item['productName']?.toString();
          final codeBar = item['productCodeBar']?.toString();

          return DataRow(
            cells: [


              // Selling Price (null-safe with default 0.00)
              DataCell(
                Text(
                  double.tryParse(price ?? '')?.toStringAsFixed(2) ?? '0.00',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),

              // Quantity (null-safe with default 0)
              DataCell(
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: TextEditingController.fromValue(
                      TextEditingValue(
                        text: quantity ?? '0',
                        selection: TextSelection.collapsed(offset: (quantity ?? '0').length),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      widget.onQuantityChanged(index, value);
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.all(8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),

              // Product Name (null-safe with default)
              DataCell(Text(
                name ?? 'بدون اسم',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              )),

              // Product Code (null-safe with default)
              DataCell(Text(
                codeBar ?? 'بدون كود',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              )),

              // Actions
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => widget.onDelete(index),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
