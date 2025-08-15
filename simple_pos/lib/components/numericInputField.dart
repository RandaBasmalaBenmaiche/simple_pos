import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/styles/my_colors.dart';

class NumericInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool expands;

  const NumericInputField({
    Key? key,
    required this.controller,
    required this.label,
    this.expands = true, // Optionally wrap in Expanded
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget field = TextField(
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      controller: controller,
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
        fillColor: MyColors.secondColor,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      keyboardType: TextInputType.number,
    );

    return expands ? Expanded(child: field) : field;
  }
}
