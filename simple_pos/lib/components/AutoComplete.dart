import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/styles/my_colors.dart';

class AutoCompleteInputField extends StatefulWidget {
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
  State<AutoCompleteInputField> createState() => _AutoCompleteInputFieldState();
}

class _AutoCompleteInputFieldState extends State<AutoCompleteInputField> {
  TextEditingController? _autocompleteController;
  FocusNode? _autocompleteFocusNode;
  bool _syncingFromExternal = false;
  bool _syncingToExternal = false;

  @override
  void initState() {
    super.initState();
    if (widget.defaultValue != null && widget.controller.text.isEmpty) {
      widget.controller.text = widget.defaultValue!;
    }
    widget.controller.addListener(_syncFromExternalController);
    widget.focusNode?.addListener(_syncExternalFocusNode);
  }

  @override
  void didUpdateWidget(covariant AutoCompleteInputField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromExternalController);
      if (widget.defaultValue != null && widget.controller.text.isEmpty) {
        widget.controller.text = widget.defaultValue!;
      }
      widget.controller.addListener(_syncFromExternalController);
      _syncFromExternalController();
    }

    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_syncExternalFocusNode);
      widget.focusNode?.addListener(_syncExternalFocusNode);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromExternalController);
    widget.focusNode?.removeListener(_syncExternalFocusNode);
    _autocompleteController?.removeListener(_syncToExternalController);
    super.dispose();
  }

  void _syncFromExternalController() {
    if (_syncingToExternal) return;
    final textController = _autocompleteController;
    if (textController == null) return;
    if (textController.text == widget.controller.text) return;

    _syncingFromExternal = true;
    textController.value = widget.controller.value;
    _syncingFromExternal = false;
  }

  void _syncToExternalController() {
    if (_syncingFromExternal) return;
    final textController = _autocompleteController;
    if (textController == null) return;
    if (widget.controller.text == textController.text &&
        widget.controller.selection == textController.selection) {
      return;
    }

    _syncingToExternal = true;
    widget.controller.value = textController.value;
    _syncingToExternal = false;
  }

  void _syncExternalFocusNode() {
    final externalFocusNode = widget.focusNode;
    final autocompleteFocusNode = _autocompleteFocusNode;
    if (externalFocusNode == null || autocompleteFocusNode == null) return;
    if (externalFocusNode.hasFocus && !autocompleteFocusNode.hasFocus) {
      autocompleteFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textFormatter = FilteringTextInputFormatter.allow(
      widget.isAlphanumeric
          ? RegExp(r"[a-zA-Z0-9\u0600-\u06FF ]")
          : RegExp(r"[0-9]"),
    );

    final field = Autocomplete<String>(
      initialValue: widget.controller.value,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return const Iterable<String>.empty();
        }

        return widget.suggestions.where((option) {
          return option.toLowerCase().contains(query);
        });
      },
      onSelected: (String selection) {
        widget.controller.value = TextEditingValue(
          text: selection,
          selection: TextSelection.collapsed(offset: selection.length),
        );
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode fieldFocusNode,
        VoidCallback onFieldSubmitted,
      ) {
        if (!identical(_autocompleteController, textEditingController)) {
          _autocompleteController?.removeListener(_syncToExternalController);
          _autocompleteController = textEditingController;
          _autocompleteController!.addListener(_syncToExternalController);
          _syncFromExternalController();
        }

        _autocompleteFocusNode = fieldFocusNode;

        return TextField(
          controller: textEditingController,
          focusNode: fieldFocusNode,
          inputFormatters: [textFormatter],
          decoration: InputDecoration(
            labelText: widget.label,
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
              widget.isAlphanumeric ? TextInputType.text : TextInputType.number,
          onEditingComplete: onFieldSubmitted,
        );
      },
    );

    return widget.expands ? Expanded(child: field) : field;
  }
}
