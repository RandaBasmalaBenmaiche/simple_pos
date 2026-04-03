import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/styles/my_colors.dart';

Future<void> showAddProductDialog(
  BuildContext context,
  void Function(
    String name,
    String price,
    String buyingPrice,
    String quantity,
    String code,
  ) onAdd,
) {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController buyingPriceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController codeController = TextEditingController();

  // Focus nodes for moving between fields
  final FocusNode nameFocus = FocusNode();
  final FocusNode priceFocus = FocusNode();
  final FocusNode buyingPriceFocus = FocusNode();
  final FocusNode quantityFocus = FocusNode();
  final FocusNode codeFocus = FocusNode();

  void submitForm() async {
    // Validate only the product name
    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("الرجاء إدخال اسم المنتج"),
        ),
      );
      return;
    }

    // Check if code exists only if code is provided
    if (codeController.text.isNotEmpty) {
      final items = await DStockTable().getRecords();
      final existingProduct = items.firstWhere(
        (e) => e['productCodeBar'] == codeController.text,
        orElse: () => {},
      );

      if (existingProduct.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("الكود موجود بالفعل"),
          ),
        );
        return;
      }
    }

    // Use defaults for optional fields
    final price = priceController.text.isEmpty ? '0' : priceController.text;
    final buyingPrice = buyingPriceController.text.isEmpty ? '0' : buyingPriceController.text;
    final quantity = quantityController.text.isEmpty ? '1' : quantityController.text;
    final code = codeController.text.isEmpty ? '' : codeController.text;

    // Add product
    onAdd(
      nameController.text,
      price,
      buyingPrice,
      quantity,
      code,
    );
    Navigator.pop(context);
  }

  return showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          // Auto-focus the first field when the dialog appears
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!nameFocus.hasFocus) {
              FocusScope.of(context).requestFocus(nameFocus);
            }
          });

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(
                    label: "اسم المنتج",
                    controller: nameController,
                    focusNode: nameFocus,
                    nextFocus: priceFocus,
                    context: context,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    label: "ثمن البيع (اختياري)",
                    controller: priceController,
                    focusNode: priceFocus,
                    nextFocus: buyingPriceFocus,
                    keyboardType: TextInputType.number,
                    numbersOnly: true,
                    context: context,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    label: "سعر الشراء (اختياري)",
                    controller: buyingPriceController,
                    focusNode: buyingPriceFocus,
                    nextFocus: quantityFocus,
                    keyboardType: TextInputType.number,
                    numbersOnly: true,
                    context: context,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    label: "الكمية (اختياري)",
                    controller: quantityController,
                    focusNode: quantityFocus,
                    nextFocus: codeFocus,
                    keyboardType: TextInputType.number,
                    numbersOnly: true,
                    context: context,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    label: "الكود (اختياري)",
                    controller: codeController,
                    focusNode: codeFocus,
                    onSubmit: submitForm, // Submit when pressing enter
                    keyboardType: TextInputType.number,
                    numbersOnly: true,
                    context: context,
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
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            "إلغاء",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 25,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyColors.mainColor(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: submitForm,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            "إضافة",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 25,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildTextField({
  required String label,
  required TextEditingController controller,
  required FocusNode focusNode,
  FocusNode? nextFocus,
  TextInputType keyboardType = TextInputType.text,
  bool numbersOnly = false,
  void Function()? onSubmit,
  context,
}) {
  return TextField(
    controller: controller,
    focusNode: focusNode,
    keyboardType: keyboardType,
    inputFormatters: numbersOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
    textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
    onSubmitted: (_) {
      if (nextFocus != null) {
        FocusScope.of(context).requestFocus(nextFocus);
      } else if (onSubmit != null) {
        onSubmit();
      }
    },
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: MyColors.secondColor(context),
    ),
  );
}
