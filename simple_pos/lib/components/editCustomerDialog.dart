import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:simple_pos/services/local_database/model/tablecustomers.dart';

Future<void> showEditCustomerDialog(
  BuildContext context,
  Map<String, dynamic> customer,
  void Function(String name, String phone) onEdit,
) {
  final TextEditingController nameController = TextEditingController(text: customer['name']);
  final TextEditingController phoneController = TextEditingController(text: customer['phone'] ?? '');

  final customerId = customer['id'] as int;
  final formattedId = DCustomersTable.formatCustomerId(customerId);

  final FocusNode nameFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();

  void cleanup() {
    nameController.dispose();
    phoneController.dispose();
    nameFocus.dispose();
    phoneFocus.dispose();
  }

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
              Text(
                "تعديل بيانات العميل",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: MyColors.mainColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MyColors.secondColor(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "ID: $formattedId",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: "اسم العميل",
                controller: nameController,
                context: context,
                focusNode: nameFocus,
                autofocus: true,
                onSubmitted: (_) => FocusScope.of(context).requestFocus(phoneFocus),
              ),
              const SizedBox(height: 10),
              _buildTextField(
                label: "الهاتف",
                controller: phoneController,
                keyboardType: TextInputType.phone,
                context: context,
                focusNode: phoneFocus,
                onSubmitted: (_) {
                  if (nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("الرجاء إدخال اسم العميل")),
                    );
                    return;
                  }
                  onEdit(nameController.text, phoneController.text);
                  Navigator.pop(context);
                  cleanup();
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
                    onPressed: () {
                      Navigator.pop(context);
                      cleanup();
                    },
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
                      if (nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("الرجاء إدخال اسم العميل")),
                        );
                        return;
                      }

                      onEdit(nameController.text, phoneController.text);
                      Navigator.pop(context);
                      cleanup();
                    },
                    child: const Text("حفظ", style: TextStyle(fontSize: 20, color: Colors.white)),
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

Widget _buildTextField({
  required String label,
  required TextEditingController controller,
  TextInputType keyboardType = TextInputType.text,
  bool numbersOnly = false,
  BuildContext? context,
  FocusNode? focusNode,
  bool autofocus = false,
  void Function(String)? onSubmitted,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    inputFormatters: numbersOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
    focusNode: focusNode,
    autofocus: autofocus,
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
