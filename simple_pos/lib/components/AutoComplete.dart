import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/styles/my_colors.dart';

class AutoCompleteInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool expands;
  final bool isAlphanumeric;
  final String? defaultValue;
  final FocusNode? focusNode;
  final List<String> suggestions;

  const AutoCompleteInputField({
    super.key,
    required this.controller,
    required this.label,
    this.expands = true,
    this.isAlphanumeric = false,
    this.defaultValue,
    this.focusNode,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    // set default value if provided
    if (defaultValue != null && controller.text.isEmpty) {
      controller.text = defaultValue!;
    }

    Widget field = Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return const Iterable<String>.empty();
        }
        return suggestions.where((String option) {
          return option
              .toLowerCase()
              .contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (BuildContext context,
          TextEditingController textEditingController,
          FocusNode fieldFocusNode,
          VoidCallback onFieldSubmitted) {
        // 🔹 Always sync external controller with internal one
        textEditingController.text = controller.text;
        textEditingController.addListener(() {
          controller.text = textEditingController.text;
        });

        return TextField(
          controller: textEditingController,
          focusNode: focusNode ?? fieldFocusNode,
          inputFormatters: [
            isAlphanumeric
                ? FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))
                : FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            labelText: label,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Colors.transparent),
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
          onEditingComplete: () {
            // 🔹 Sync again on Enter
            controller.text = textEditingController.text;
            onFieldSubmitted();
          },
        );
      },
    );

    return expands ? Expanded(child: field) : field;
  }
}
