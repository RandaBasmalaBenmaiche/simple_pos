import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/styles/my_colors.dart';

Future<void> showPayDebtDialog(
  BuildContext context,
  Map<String, dynamic> customer,
  String title,
  void Function(double amount) onPay,
) {
  final TextEditingController amountController = TextEditingController();

  return showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("$title ${customer['name']}",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: "المبلغ",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("إلغاء", style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: MyColors.mainColor(context)),
                    onPressed: () {
                      if (amountController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("الرجاء إدخال المبلغ")),
                        );
                        return;
                      }
                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("المبلغ غير صالح")),
                        );
                        return;
                      }
                      onPay(amount);
                      Navigator.pop(context);
                    },
                    child: const Text("تأكيد", style: TextStyle(color: Colors.white)),
                  ),
                ],
              )
            ],
          ),
        ),
      );
    },
  );
}
