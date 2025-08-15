import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/styles/my_colors.dart';

class NumberInputDialog {
  /// Shows a dialog with numeric code input, then displays product info
  static void show({
    required BuildContext context,
    required String title,
    required Null Function(dynamic value) onSubmit,
  }) {
    final TextEditingController codeController = TextEditingController();
    String? productName;
    String? productPrice;

    showDialog(
      context: context,
      builder: (context) {
        bool isSubmitted = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: MyColors.mainColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Step 1: Input code
                    if (!isSubmitted)
                      _buildTextField(
                        label: "الكود",
                        controller: codeController,
                        numbersOnly: true,
                      ),

                    // Step 2: Show product info
                    if (isSubmitted) ...[
                      _buildTextField(
                        label: "اسم المنتج",
                        controller:
                            TextEditingController(text: productName ?? ''),
                        readOnly: true,
                        fillColor: MyColors.secondColor, // retain original color
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        label: "ثمن المنتج",
                        controller:
                            TextEditingController(text: productPrice ?? ''),
                        readOnly: true,
                        fillColor: MyColors.secondColor, // retain original color
                      ),
                    ],

                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(
                              "خروج",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 25,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        if (!isSubmitted)
                          const SizedBox(width: 20),
                        if (!isSubmitted)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MyColors.mainColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              if (codeController.text.isEmpty) return;

                              // Fetch product from database
                              final items = await DStockTable().getRecords();
                              final product = items.firstWhere(
                                (e) =>
                                    e['productCodeBar'] == codeController.text,
                                orElse: () => {},
                              );

                              if (product.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("الكود غير موجود")),
                                );
                                return;
                              }

                              productName = product['productName'];
                              productPrice = product['productPrice'];

                              setState(() => isSubmitted = true);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text(
                                "تاكيد",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 25,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool numbersOnly = false,
    bool readOnly = false,
    Color? fillColor, // allows custom color
  }) {
    return TextField(
      controller: controller,
      keyboardType: numbersOnly ? TextInputType.number : TextInputType.text,
      inputFormatters:
          numbersOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: fillColor ?? MyColors.secondColor,
      ),
    );
  }
}
