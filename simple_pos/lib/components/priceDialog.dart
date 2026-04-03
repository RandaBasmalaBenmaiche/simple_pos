import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/components/AutoComplete.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PriceDialog {
  static void show({
    required BuildContext context,
    required String title,
    required Function(dynamic value) onSubmit,
  }) async {
    final TextEditingController codeController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final FocusNode codeFocusNode = FocusNode();
    final FocusNode nameFocusNode = FocusNode();

    // ✅ Get storeId as int
    final int storeId = BlocProvider.of<StoreCubit>(context, listen: false).state;

    // ✅ Fetch all product names for suggestions by storeId
    final List<String> productNames =
        await DStockTable().getAllProductNames(storeId);

    String? productName;
    String? productPrice;
    bool isSubmitted = false;

    showDialog(
      context: context,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (context.mounted && !isSubmitted) {
            FocusScope.of(context).requestFocus(codeFocusNode);
          }
        });

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> confirm() async {
              await _handleConfirm(
                context,
                codeController,
                nameController,
                setState,
                (name, price) {
                  productName = name;
                  productPrice = price;
                  isSubmitted = true;
                },
                onSubmit,
                storeId, // ✅ Pass storeId here
              );
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: RawKeyboardListener(
                focusNode: FocusNode(),
                autofocus: true,
                onKey: (RawKeyEvent event) async {
                  if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
                    await confirm();
                  }
                },
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
                          color: MyColors.mainColor(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      if (!isSubmitted) ...[
                        _buildTextField(
                          label: "الكود",
                          controller: codeController,
                          numbersOnly: true,
                          focusNode: codeFocusNode,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) async => await confirm(),
                          context: context,
                        ),
                        const SizedBox(height: 10),

                        AutoCompleteInputField(
                          controller: nameController,
                          label: "اسم المنتج",
                          suggestions: productNames,
                          focusNode: nameFocusNode,
                          isAlphanumeric: true,
                          expands: false,
                        ),
                      ],

                      if (isSubmitted) ...[
                        _buildTextField(
                          label: "اسم المنتج",
                          controller:
                              TextEditingController(text: productName ?? ''),
                          readOnly: true,
                          fillColor: MyColors.secondColor(context),
                          context: context,
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          label: "ثمن المنتج",
                          controller: TextEditingController(
                            text: productPrice != null
                                ? (double.tryParse(productPrice!) ?? 0.0)
                                    .toStringAsFixed(2)
                                : '',
                          ),
                          readOnly: true,
                          fillColor: MyColors.secondColor(context),
                          context: context,
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
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          if (!isSubmitted)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MyColors.mainColor(context),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: confirm,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Text(
                                  "تاكيد",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 25,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> _handleConfirm(
    BuildContext context,
    TextEditingController codeController,
    TextEditingController nameController,
    void Function(void Function()) setState,
    void Function(String?, String?) onProductLoaded,
    Function(dynamic) onSubmit,
    int storeId, // ✅ now int
  ) async {
    final code = codeController.text.trim();
    final name = nameController.text.trim();

    if (code.isEmpty && name.isEmpty) return;

    Map<String, dynamic>? product;

    if (code.isNotEmpty) {
      product = await DStockTable().getProductByCode(code, storeId);
    } else if (name.isNotEmpty) {
      product = await DStockTable().getProductByName(name, storeId);
    }

    if (product == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("المنتج غير موجود")),
        );
      }
      return;
    }

    final productName = product['productName'];
    final productPrice = product['productPrice'];

    setState(() => onProductLoaded(productName, productPrice));
    onSubmit({
      'code': product['productCodeBar'], // ✅ fixed key name
      'name': productName,
      'price': productPrice,
    });
  }

  static Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool numbersOnly = false,
    bool readOnly = false,
    FocusNode? focusNode,
    Function(String)? onSubmitted,
    Color? fillColor,
    TextInputAction? textInputAction,
    context,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
      onSubmitted: onSubmitted,
      keyboardType: numbersOnly ? TextInputType.number : TextInputType.text,
      textInputAction: textInputAction ?? TextInputAction.next,
      inputFormatters:
          numbersOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 30,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: fillColor ?? MyColors.secondColor(context),
      ),
    );
  }
}
