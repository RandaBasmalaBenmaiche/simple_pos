import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/styles/my_colors.dart';

class SuggestionInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool expands;
  final bool isAlphanumeric;
  final String? defaultValue;
  final FocusNode? focusNode;
  final List<String> suggestions;
  final void Function(String)? onSelected;

  const SuggestionInputField({
    Key? key,
    required this.controller,
    required this.label,
    this.expands = true,
    this.isAlphanumeric = false,
    this.defaultValue,
    this.focusNode,
    this.suggestions = const [],
    this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Set default value if provided
    if (defaultValue != null && controller.text.isEmpty) {
      controller.text = defaultValue!;
    }

    Widget field = Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
        return suggestions.where((s) => s.toLowerCase().contains(
              textEditingValue.text.toLowerCase(),
            ));
      },
      onSelected: (selection) {
        controller.text = selection; // keep external controller in sync
        if (onSelected != null) onSelected!(selection);
        focusNode?.requestFocus();
      },
      fieldViewBuilder: (context, textController, fNode, onFieldSubmitted) {
        // Keep external controller updated
        textController.addListener(() {
          if (controller.text != textController.text) {
            controller.text = textController.text;
            controller.selection = textController.selection;
          }
        });

        return TextField(
          controller: textController, // crucial for Autocomplete to work
          focusNode: focusNode ?? fNode,
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
            fillColor: MyColors.secondColor,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          keyboardType:
              isAlphanumeric ? TextInputType.text : TextInputType.number,
        );
      },
    );

    return expands ? Expanded(child: field) : field;
  }
}
