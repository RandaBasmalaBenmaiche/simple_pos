import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';




class PriceDialog {
  static void show({
    required BuildContext context,
    required String title,
    required Function(dynamic value) onSubmit,
  }) {


    final TextEditingController codeController = TextEditingController();
    final FocusNode codeFocusNode = FocusNode();
    final store = BlocProvider.of<StoreCubit>(context, listen: false).state;
    String? productName;
    String? productPrice;
    bool isSubmitted = false;



    showDialog(
      context: context,
      builder: (context) {

        //if we still didn't submit focus for the code input
        Future.delayed(const Duration(milliseconds: 300), () {
          if (context.mounted && !isSubmitted) {
            FocusScope.of(context).requestFocus(codeFocusNode);
          }
        });

        return StatefulBuilder(
          builder: (context, setState) {
            
            //MAL PLACE MBE3D
            Future<void> confirm() async {
              await _handleConfirm(
                context,
                codeController,
                setState,
                (name, price) {
                  productName = name;
                  productPrice = price;
                  isSubmitted = true;
                },
                onSubmit,
                store,
              );
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: RawKeyboardListener(
                focusNode: FocusNode(), // needed to listen to keyboard
                autofocus: true,
                onKey: (RawKeyEvent event) async {
                  if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
                    await confirm(); // triggers your _handleConfirm function
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

                      // if not submitted we will have the input field
                      if (!isSubmitted) ...[
                        _buildTextField(
                          label: "الكود",
                          controller: codeController,
                          numbersOnly: true,
                          focusNode: codeFocusNode,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) async {
                            await confirm(); // trigger confirm on Enter in the text field
                          },
                          context: context
                        ),
                      ],

                      // if submitted we show product info
                      if (isSubmitted) ...[
                        _buildTextField(
                          label: "اسم المنتج",
                          controller: TextEditingController(text: productName ?? ''),
                          readOnly: true,
                          fillColor: MyColors.secondColor(context),
                          context: context,
                          
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          label: "ثمن المنتج",
                          controller: TextEditingController(text: productPrice ?? ''),
                          readOnly: true,
                          fillColor: MyColors.secondColor(context),
                          context: context
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
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            if(!isSubmitted)ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MyColors.mainColor(context),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: confirm,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
  TextEditingController controller,
  void Function(void Function()) setState,
  void Function(String?, String?) onProductLoaded,
  Function(dynamic) onSubmit,
  store,
) async {
  if (controller.text.isEmpty) return;

  final product = await DStockTable().getProductByCode(controller.text,store);

  if (product == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الكود غير موجود")),
      );
    }
    return;
  }

  final productName = product['productName'];
  final productPrice = product['productPrice'];

  
  setState(() => onProductLoaded(productName, productPrice));
  onSubmit({
    'code': controller.text,
    'name': productName,
    'price': productPrice,
  });
}


  //reusable component for the text fields of the dialog 
  static Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool numbersOnly = false,
    bool readOnly = false,
    FocusNode? focusNode,
    Function(String)? onSubmitted,
    Color? fillColor,
    TextInputAction? textInputAction,
    context
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
