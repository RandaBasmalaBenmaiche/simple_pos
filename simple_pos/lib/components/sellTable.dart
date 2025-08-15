import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart'; // Add this to pubspec.yaml
import 'package:simple_pos/styles/my_colors.dart';

class POSItemsTable extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback sellItems;

  const POSItemsTable({
    super.key,
    required this.items,
    required this.sellItems,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DataTable2(
        headingRowColor: MaterialStateProperty.all(MyColors.mainColor),
        headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
        dataRowColor: MaterialStateProperty.all(MyColors.secondColor),
        columnSpacing: 12,
        horizontalMargin: 12,
        minWidth: 600,
        columns: const [
          DataColumn2(label: Text("المبلغ الاجمالي"), size: ColumnSize.M),
          DataColumn2(label: Text("سعر الوحدة"), size: ColumnSize.M),
          DataColumn2(label: Text("الكمية"), size: ColumnSize.S),
          DataColumn2(label: Text("الاسم"), size: ColumnSize.L),
          DataColumn2(label: Text("الكود"), size: ColumnSize.S),
          
          
          
          
        ],
        rows: items
            .map(
              (item) => DataRow(
                cells: [
                  DataCell(Text(item['total'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20))),
                  DataCell(Text(item['productPrice'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20))),
                  DataCell(Text(item['productQuantity'].toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20))),
                  DataCell(Text(item['productName'].toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20))),
                  DataCell(Text(item['productCodeBar'].toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
