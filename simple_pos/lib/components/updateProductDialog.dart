import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For FilteringTextInputFormatter
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/styles/my_colors.dart';

Future<void> showEditProductDialog(
    BuildContext context, VoidCallback onUpdate) async {
  final TextEditingController codeController = TextEditingController(); // old code
  final TextEditingController newCodeController = TextEditingController(); // new code
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController buyingPriceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  bool isLoaded = false;
  bool isCodeEditable = true; // old code editable at first

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
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
                    label: "كود المنتج الحالي",
                    controller: codeController,
                    enabled: isCodeEditable,
                    numbersOnly: true,
                  ),
                  const SizedBox(height: 10),

                  if (isLoaded) ...[
                    _buildTextField(
                        label: "كود المنتج الجديد",
                        controller: newCodeController,
                        numbersOnly: true),
                    const SizedBox(height: 10),
                    _buildTextField(
                        label: "اسم المنتج", controller: nameController),
                    const SizedBox(height: 10),
                    _buildTextField(
                        label: "ثمن البيع",
                        controller: priceController,
                        numbersOnly: true),
                    const SizedBox(height: 10),
                    _buildTextField(
                        label: "سعر الشراء",
                        controller: buyingPriceController,
                        numbersOnly: true),
                    const SizedBox(height: 10),
                    _buildTextField(
                        label: "الكمية",
                        controller: quantityController,
                        numbersOnly: true),
                  ],

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text("إلغاء",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white)),
                        ),
                      ),
                      if (!isLoaded)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MyColors.mainColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final items = await DStockTable().getRecords();
                            final product = items.firstWhere(
                                (e) =>
                                    e['productCodeBar'] ==
                                    codeController.text,
                                orElse: () => {});

                            if (product.isNotEmpty) {
                              setState(() {
                                newCodeController.text =
                                    product['productCodeBar'];
                                nameController.text =
                                    product['productName'];
                                priceController.text =
                                    product['productPrice'];
                                buyingPriceController.text =
                                    product['productBuyingPrice'] ?? '';
                                quantityController.text =
                                    product['productQuantity'];
                                isLoaded = true;
                                isCodeEditable = false; // freeze old code
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("الكود غير موجود")));
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text("التالي",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.white)),
                          ),
                        )
                      else
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MyColors.mainColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            // Check if any field is empty
                            if (newCodeController.text.isEmpty ||
                                nameController.text.isEmpty ||
                                priceController.text.isEmpty ||
                                buyingPriceController.text.isEmpty ||
                                quantityController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text("الرجاء تعبئة جميع الحقول")));
                              return;
                            }

                            bool success = await DStockTable().updateProduct(
                              codeBar: codeController.text,
                              newCodeBar: newCodeController.text,
                              newName: nameController.text,
                              newPrice: priceController.text,
                              newBuyingPrice: buyingPriceController.text,
                              newQuantity: quantityController.text,
                            );

                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("تم التحديث بنجاح")));
                              onUpdate();
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text("حدث خطأ أثناء التحديث")));
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text("حفظ",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.white)),
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
  TextInputType keyboardType = TextInputType.text,
  bool enabled = true,
  bool numbersOnly = false,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    enabled: enabled,
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
