import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/styles/my_colors.dart';

Future<void> showPayingAmountDialog(
  BuildContext context,
  TextEditingController amount,
  void Function(double payingAmount) onSell,
) {
  final TextEditingController amountController = amount;
  final FocusNode amountFocus = FocusNode();

  return showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                focusNode: amountFocus,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: "المبلغ المدفوع",
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: MyColors.secondColor(context),
                ),
                onSubmitted: (_) {
                  final value = double.tryParse(amountController.text);
                  if (value == null || value <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("الرجاء إدخال مبلغ صحيح")),
                    );
                    return;
                  }
                  onSell(value);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("إلغاء", style: TextStyle(fontSize: 20, color: Colors.white)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.mainColor(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final value = double.tryParse(amountController.text);
                      if (value == null || value <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("الرجاء إدخال مبلغ صحيح")),
                        );
                        return;
                      }
                      onSell(value);
                      Navigator.pop(context);
                    },
                    child: const Text("بيع", style: TextStyle(fontSize: 20, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
