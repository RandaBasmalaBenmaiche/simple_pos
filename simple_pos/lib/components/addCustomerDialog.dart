import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:simple_pos/services/local_database/model/tablecustomers.dart';

Future<void> showAddCustomerDialog(
  BuildContext context,
  void Function(String name, String phone, String debt) onAdd,
  {bool showIdAfterCreate = false}) {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController debtController = TextEditingController(text: "0");

  // Focus nodes to handle Enter key navigation
  final FocusNode nameFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode debtFocus = FocusNode();

  void cleanup() {
    nameController.dispose();
    phoneController.dispose();
    debtController.dispose();
    nameFocus.dispose();
    phoneFocus.dispose();
    debtFocus.dispose();
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
                onSubmitted: (_) => FocusScope.of(context).requestFocus(debtFocus),
              ),
              const SizedBox(height: 10),
              _buildTextField(
                label: "الديْن",
                controller: debtController,
                keyboardType: TextInputType.number,
                numbersOnly: true,
                context: context,
                focusNode: debtFocus,
                onSubmitted: (_) async {
                  // Trigger submit when pressing Enter on last field
                  if (nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("الرجاء إدخال اسم العميل")),
                    );
                    return;
                  }

                  if (showIdAfterCreate) {
                    // Get next ID before inserting
                    final nextId = await DCustomersTable().getNextCustomerId();
                    final formattedId = DCustomersTable.formatCustomerId(nextId);

                    onAdd(
                      nameController.text,
                      phoneController.text,
                      debtController.text,
                    );

                    // Close the add dialog first
                    if (context.mounted) {
                      Navigator.pop(context);
                      // Show ID dialog after creation
                      await showDialog(
                        context: context,
                        builder: (dialogContext) => Dialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "تم إنشاء الزبون بنجاح",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: MyColors.mainColor(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: MyColors.secondColor(context),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "New client created — ID: $formattedId",
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    cleanup();
                                  },
                                  child: const Text("حسناً"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    } else {
                      cleanup();
                    }
                  } else {
                    onAdd(
                      nameController.text,
                      phoneController.text,
                      debtController.text,
                    );
                    Navigator.pop(context);
                    cleanup();
                  }
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
                    onPressed: () async {
                      if (nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("الرجاء إدخال اسم العميل")),
                        );
                        return;
                      }

                      if (showIdAfterCreate) {
                        // Get next ID before inserting
                        final nextId = await DCustomersTable().getNextCustomerId();
                        final formattedId = DCustomersTable.formatCustomerId(nextId);

                        onAdd(
                          nameController.text,
                          phoneController.text,
                          debtController.text,
                        );

                        // Close the add dialog first
                        if (context.mounted) {
                          Navigator.pop(context);
                          // Show ID dialog after creation
                          await showDialog(
                            context: context,
                            builder: (dialogContext) => Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "تم إنشاء الزبون بنجاح",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: MyColors.mainColor(context),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: MyColors.secondColor(context),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "New client created — ID: $formattedId",
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(dialogContext);
                                        cleanup();
                                      },
                                      child: const Text("حسناً"),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        } else {
                          cleanup();
                        }
                      } else {
                        onAdd(
                          nameController.text,
                          phoneController.text,
                          debtController.text,
                        );
                        Navigator.pop(context);
                        cleanup();
                      }
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
