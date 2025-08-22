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
  List<bool> _isBuyingPriceVisible = [];

  @override
  void didUpdateWidget(covariant POSStockItemsTable oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If items length changes, resize the visibility list safely
    if (_isBuyingPriceVisible.length != widget.items.length) {
      _isBuyingPriceVisible = List.generate(
        widget.items.length,
        (index) => index < _isBuyingPriceVisible.length
            ? _isBuyingPriceVisible[index]
            : false,
      );
    }
  }

  void _toggleVisibility(int index) async {
    if (_isBuyingPriceVisible[index]) {
      // Already visible → hide it
      setState(() {
        _isBuyingPriceVisible[index] = false;
      });
    } else {
      // Hidden → ask for password
      final TextEditingController passwordController = TextEditingController();

      bool? success = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("أدخل كلمة المرور"),
            content: TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "كلمة المرور",
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("إلغاء"),
              ),
              TextButton(
                onPressed: () {
                  if (passwordController.text == "1234") {
                    Navigator.of(context).pop(true); // correct password
                  } else {
                    Navigator.of(context).pop(false);
                  }
                },
                child: const Text("تأكيد"),
              ),
            ],
          );
        },
      );

      if (success == true) {
        setState(() {
          _isBuyingPriceVisible[index] = true;
        });
      } else if (success == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("كلمة المرور غير صحيحة")),
        );
      }
    }
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
          DataColumn2(label: Text("سعر الشراء"), size: ColumnSize.S),
          DataColumn2(label: Text("سعر الوحدة"), size: ColumnSize.S),
          DataColumn2(label: Text("الكمية"), size: ColumnSize.S),
          DataColumn2(label: Text("الاسم"), size: ColumnSize.L),
          DataColumn2(label: Text("الكود"), size: ColumnSize.L),
          DataColumn2(label: Text(""), size: ColumnSize.S), // actions column
        ],
        rows: List.generate(widget.items.length, (index) {
          final item = widget.items[index];

          return DataRow(
            cells: [
              DataCell(
                Text(
                  _isBuyingPriceVisible[index]
                      ? item['productBuyingPrice'].toString()
                      : "****",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              DataCell(Text(
                item['productPrice'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              )),
              DataCell(
                SizedBox(
                  width: 60,
                  child: TextField(
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
              DataCell(Text(
                item['productName'].toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              )),
              DataCell(Text(
                item['productCodeBar'].toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              )),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => widget.onDelete(index),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: Icon(
                        _isBuyingPriceVisible[index]
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.cyan,
                      ),
                      onPressed: () => _toggleVisibility(index),
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
