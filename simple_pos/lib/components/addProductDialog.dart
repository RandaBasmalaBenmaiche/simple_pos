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
              _buildTextField(label: "اسم المنتج", controller: nameController),
              const SizedBox(height: 10),
              _buildTextField(
                label: "ثمن البيع",
                controller: priceController,
                keyboardType: TextInputType.number,
                numbersOnly: true,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                label: "سعر الشراء",
                controller: buyingPriceController,
                keyboardType: TextInputType.number,
                numbersOnly: true,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                label: "الكمية",
                controller: quantityController,
                keyboardType: TextInputType.number,
                numbersOnly: true,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                label: "الكود",
                controller: codeController,
                keyboardType: TextInputType.number,
                numbersOnly: true,
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
                      backgroundColor: MyColors.mainColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      // Prevent adding if any field is empty
                      if (nameController.text.isEmpty ||
                          priceController.text.isEmpty ||
                          buyingPriceController.text.isEmpty ||
                          quantityController.text.isEmpty ||
                          codeController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("الرجاء تعبئة جميع الحقول"),
                          ),
                        );
                        return;
                      }

                      // Check if code already exists in the database
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

                      // Add product
                      onAdd(
                        nameController.text,
                        priceController.text,
                        buyingPriceController.text,
                        quantityController.text,
                        codeController.text,
                      );
                      Navigator.pop(context);
                    },
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
}

Widget _buildTextField({
  required String label,
  required TextEditingController controller,
  TextInputType keyboardType = TextInputType.text,
  bool numbersOnly = false,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    inputFormatters:
        numbersOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: MyColors.secondColor,
    ),
  );
}
