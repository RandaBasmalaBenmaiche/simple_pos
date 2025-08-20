import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:simple_pos/styles/my_colors.dart';

class POSItemsTable extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DataTable2(
        headingRowColor: MaterialStateProperty.all(MyColors.mainColor),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 20,
        ),
        dataRowColor: MaterialStateProperty.all(MyColors.secondColor),
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
        rows: List.generate(items.length, (index) {
          final item = items[index];

          return DataRow(
            cells: [
              DataCell(Text(item['total'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20))),
              DataCell(Text(item['productPrice'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20))),
              DataCell(
                SizedBox(
                  width: 60,
                  child: TextField(
                    // instead of creating a controller, use initial value directly
                    controller: TextEditingController.fromValue(
                      TextEditingValue(
                        text: item['productQuantity'].toString(),
                        selection: TextSelection.collapsed(
                          offset: item['productQuantity'].toString().length,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      onQuantityChanged(index, value); // update live
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.all(8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              DataCell(Text(item['productName'].toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20))),
              DataCell(Text(item['productCodeBar'].toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20))),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => onDelete(index),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
