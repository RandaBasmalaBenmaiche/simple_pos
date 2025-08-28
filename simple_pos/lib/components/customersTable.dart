import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:simple_pos/styles/my_colors.dart';

class POSCustomersTable extends StatefulWidget {
  final List<Map<String, dynamic>> customers;
  final Function(int index) onDelete;
  final Function(int index) onEdit;
  final Function(int index) onPayDebt; // ✅ Added this

  const POSCustomersTable({
    super.key,
    required this.customers,
    required this.onDelete,
    required this.onEdit,
    required this.onPayDebt, // ✅ Required callback
  });

  @override
  State<POSCustomersTable> createState() => _POSCustomersTableState();
}

class _POSCustomersTableState extends State<POSCustomersTable> {
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
        minWidth: 800,
        columns: const [
          DataColumn2(label: Text("الديْن"), size: ColumnSize.M),
          DataColumn2(label: Text("الهاتف"), size: ColumnSize.L),
          DataColumn2(label: Text("الإسم"), size: ColumnSize.L),
          DataColumn2(label: Text(""), size: ColumnSize.S), // actions
        ],
        rows: List.generate(widget.customers.length, (index) {
          final customer = widget.customers[index];

          return DataRow(
            cells: [
              DataCell(
                Text(
                  (double.tryParse(customer['debt'].toString()) ?? 0.0).toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              DataCell(Text(
                customer['phone']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              )),
              DataCell(Text(
                customer['name'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              )),

              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => widget.onEdit(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_money, color: Colors.green),
                      onPressed: () => widget.onPayDebt(index), // ✅ Pay Debt Button
                    ),
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
