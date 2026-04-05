import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/styles/my_colors.dart';

class NumericInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool expands;
  final bool isAlphanumeric;
  final String? defaultValue;
  final FocusNode? focusNode; 

  const NumericInputField({
    super.key,
    required this.controller,
    required this.label,
    this.expands = true,
    this.isAlphanumeric = false,
    this.defaultValue,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final textFormatter = FilteringTextInputFormatter.allow(
      isAlphanumeric ? RegExp(r"[a-zA-Z0-9\u0600-\u06FF ]") : RegExp(r"[0-9]"),
    );

    // set default value if provided
    if (defaultValue != null && controller.text.isEmpty) {
      controller.text = defaultValue!;
    }

    Widget field = TextField(
      controller: controller,
      focusNode: focusNode, 
      inputFormatters: [textFormatter],
      decoration: InputDecoration(
        labelText: label,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.transparent),
        ),
        filled: true,
        fillColor: MyColors.secondColor(context),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      keyboardType:
          isAlphanumeric ? TextInputType.text : TextInputType.number,
    );

    return expands ? Expanded(child: field) : field;
  }
}
