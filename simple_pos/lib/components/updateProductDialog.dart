import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/components/AutoComplete.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/styles/my_colors.dart';

Future<void> showEditProductDialog(
    BuildContext context, VoidCallback onUpdate) async {
  final TextEditingController codeController = TextEditingController(); // old code
  final TextEditingController oldNameController = TextEditingController(); // old name
  final TextEditingController newCodeController = TextEditingController(); // new code
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController buyingPriceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  final int storeId = BlocProvider.of<StoreCubit>(context, listen: false).state;

  final List<String> productNames = await DStockTable().getAllProductNames(storeId);

  bool isLoaded = false;
  bool isEditable = true;

  final FocusNode newCodeFocus = FocusNode();
  final FocusNode nameFocus = FocusNode();
  final FocusNode priceFocus = FocusNode();
  final FocusNode buyingPriceFocus = FocusNode();
  final FocusNode quantityFocus = FocusNode();

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> loadProduct() async {
            final items = await DStockTable().getRecords();
            Map<String, dynamic> product = {};

            if (codeController.text.isNotEmpty) {
              product = items.firstWhere(
                  (e) => e['productCodeBar'] == codeController.text,
                  orElse: () => {});
            } else if (oldNameController.text.isNotEmpty) {
              product = items.firstWhere(
                  (e) => e['productName'] == oldNameController.text,
                  orElse: () => {});
            }

            if (product.isNotEmpty) {
              setState(() {
                newCodeController.text = product['productCodeBar'] ?? '';
                nameController.text = product['productName'] ?? '';
                priceController.text = product['productPrice'] ?? '';
                buyingPriceController.text = product['productBuyingPrice'] ?? '';
                quantityController.text = product['productQuantity'] ?? '';
                isLoaded = true;
                isEditable = false;
              });
              FocusScope.of(context).requestFocus(newCodeFocus);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("المنتج غير موجود")));
            }
          }

          Future<void> submitUpdate() async {
            if (nameController.text.isEmpty ||
                priceController.text.isEmpty ||
                buyingPriceController.text.isEmpty ||
                quantityController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("الرجاء تعبئة جميع الحقول")));
              return;
            }

            bool success = false;

            if (codeController.text.isNotEmpty) {
              success = await DStockTable().updateProduct(
                codeBar: codeController.text,
                newCodeBar: newCodeController.text,
                newName: nameController.text,
                newPrice: priceController.text,
                newBuyingPrice: buyingPriceController.text,
                newQuantity: quantityController.text,
                storeId: storeId,
              );
            } else if (oldNameController.text.isNotEmpty) {
              success = await DStockTable().updateProductByName(
                name: oldNameController.text,
                newCodeBar: newCodeController.text,
                newName: nameController.text,
                newPrice: priceController.text,
                newBuyingPrice: buyingPriceController.text,
                newQuantity: quantityController.text,
                storeId: storeId,
              );
            }

            if (success) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("تم التحديث بنجاح")));
              onUpdate();
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("حدث خطأ أثناء التحديث")));
            }
          }

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
                      enabled: isEditable,
                      numbersOnly: true,
                      context: context,
                      onSubmitted: (_) async => await loadProduct()),
                  const SizedBox(height: 10),
                  AutoCompleteInputField(
                    controller: oldNameController,
                    label: "اسم المنتج الحالي",
                    suggestions: productNames,
                    isAlphanumeric: true,
                    expands: false,
                  ),
                  const SizedBox(height: 10),

                  if (isLoaded) ...[
                    _buildTextField(
                        label: "كود المنتج الجديد",
                        controller: newCodeController,
                        context: context,
                        focusNode: newCodeFocus,
                        numbersOnly: true,
                        onSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(nameFocus)),
                    const SizedBox(height: 10),
                    _buildTextField(
                        label: "اسم المنتج",
                        controller: nameController,
                        context: context,
                        focusNode: nameFocus,
                        onSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(priceFocus)),
                    const SizedBox(height: 10),
                    _buildTextField(
                        label: "ثمن البيع",
                        controller: priceController,
                        numbersOnly: true,
                        context: context,
                        focusNode: priceFocus,
                        onSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(buyingPriceFocus)),
                    const SizedBox(height: 10),
                    _buildTextField(
                        label: "سعر الشراء",
                        controller: buyingPriceController,
                        numbersOnly: true,
                        context: context,
                        focusNode: buyingPriceFocus,
                        onSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(quantityFocus)),
                    const SizedBox(height: 10),
                    _buildTextField(
                        label: "الكمية",
                        controller: quantityController,
                        numbersOnly: true,
                        context: context,
                        focusNode: quantityFocus,
                        onSubmitted: (_) => submitUpdate()),
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
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            backgroundColor: MyColors.mainColor(context),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: loadProduct,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            backgroundColor: MyColors.mainColor(context),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: submitUpdate,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
  BuildContext? context,
  FocusNode? focusNode,
  void Function(String)? onSubmitted,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    enabled: enabled,
    focusNode: focusNode,
    inputFormatters:
        numbersOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
    onSubmitted: onSubmitted,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: context != null ? MyColors.secondColor(context) : Colors.grey[200],
    ),
  );
}
