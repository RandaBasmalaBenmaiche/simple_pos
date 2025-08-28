import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/styles/my_colors.dart';

Future<void> showAddCustomerDialog(
  BuildContext context,
  void Function(String name, String phone, String debt) onAdd,
) {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController debtController = TextEditingController(text: "0");

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
              _buildTextField(label: "اسم العميل", controller: nameController, context: context),
              const SizedBox(height: 10),
              _buildTextField(
                label: "الهاتف",
                controller: phoneController,
                keyboardType: TextInputType.phone,
                context: context,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                label: "الديْن",
                controller: debtController,
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

                      onAdd(
                        nameController.text,
                        phoneController.text,
                        debtController.text,
                      );
                      Navigator.pop(context);
                    },
                    child: const Text("إضافة", style: TextStyle(fontSize: 20, color: Colors.white)),
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
  context,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    inputFormatters: numbersOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
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
