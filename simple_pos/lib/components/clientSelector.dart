import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pos/services/local_database/model/tablecustomers.dart';
import 'package:simple_pos/styles/my_colors.dart';

class ClientInputFormatter extends TextInputFormatter {
  final Function(String) onSpacePressed;

  ClientInputFormatter({required this.onSpacePressed});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;

    // Check if a space was just added at the end - this is the trigger for ID lookup
    if (newText.endsWith(' ') && newText.length > oldValue.text.length) {
      // Only trigger if the text before space is all digits (ID mode)
      final textBeforeSpace = newText.trim();
      if (RegExp(r'^[0-9]+$').hasMatch(textBeforeSpace)) {
        onSpacePressed(textBeforeSpace);
        return TextEditingValue(text: '');
      }
      // If not all digits, allow the space (name search mode)
      return newValue;
    }

    // Allow letters, numbers, and Arabic characters
    if (!RegExp(r'^[a-zA-Z0-9\u0600-\u06FF]*$').hasMatch(newText)) {
      return oldValue;
    }

    return newValue;
  }
}

class ClientSelector extends StatefulWidget {
  final Function(Map<String, dynamic>? client) onClientSelected;
  final Map<String, dynamic>? initialClient;
  final int storeId;

  const ClientSelector({
    Key? key,
    required this.onClientSelected,
    this.initialClient,
    required this.storeId,
  }) : super(key: key);

  @override
  State<ClientSelector> createState() => _ClientSelectorState();
}

class _ClientSelectorState extends State<ClientSelector> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  bool _isIdMode = false;
  Map<String, dynamic>? _selectedClient;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialClient != null) {
      _selectedClient = widget.initialClient;
      final id = widget.initialClient!['id'] as int;
      final formattedId = DCustomersTable.formatCustomerId(id);
      _controller.text = "${widget.initialClient!['name']} — #$formattedId";
    }
  }

  @override
  void didUpdateWidget(covariant ClientSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialClient != widget.initialClient) {
      if (widget.initialClient == null) {
        setState(() {
          _selectedClient = null;
          _controller.clear();
          _suggestions = [];
          _showSuggestions = false;
          _errorMessage = null;
          _isIdMode = false;
        });
      } else {
        _selectedClient = widget.initialClient;
        final id = widget.initialClient!['id'] as int;
        final formattedId = DCustomersTable.formatCustomerId(id);
        _controller.text = "${widget.initialClient!['name']} — #$formattedId";
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _searchByName(String query) async {
    if (query.length < 1) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final results = await DCustomersTable().getCustomerByName(query, widget.storeId);
    setState(() {
      _suggestions = results.take(5).toList();
      _showSuggestions = true;
      _isIdMode = false;
      _errorMessage = null;
    });
  }

  Future<void> _lookupById(String idString) async {
    final id = int.tryParse(idString);
    if (id == null) {
      setState(() {
        _errorMessage = "رقم الزبون غير صالح";
      });
      return;
    }

    final client = await DCustomersTable().getCustomerById(id);
    if (client != null) {
      _selectClient(client);
    } else {
      setState(() {
        _errorMessage = "لا يوجد زبون بالرقم $idString";
        _showSuggestions = false;
      });
    }
  }

  void _selectClient(Map<String, dynamic> client) {
    final id = client['id'] as int;
    final formattedId = DCustomersTable.formatCustomerId(id);
    setState(() {
      _selectedClient = client;
      _controller.text = "${client['name']} — #$formattedId";
      _showSuggestions = false;
      _suggestions = [];
      _errorMessage = null;
      _isIdMode = false;
    });
    widget.onClientSelected(_selectedClient);
  }

  void _clearSelection() {
    setState(() {
      _selectedClient = null;
      _controller.clear();
      _suggestions = [];
      _showSuggestions = false;
      _errorMessage = null;
    });
    widget.onClientSelected(null);
  }

  void _onTextChanged(String text) {
    if (_selectedClient != null) return;

    // Check if input is numeric (ID mode) or alphabetic (name mode)
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _errorMessage = null;
      });
      return;
    }

    // Detect mode: all digits = ID mode, otherwise name search
    final isNumeric = RegExp(r'^[0-9]+$').hasMatch(trimmedText);

    if (isNumeric) {
      setState(() {
        _isIdMode = true;
        _showSuggestions = false;
        _errorMessage = null;
      });
    } else {
      _searchByName(trimmedText);
    }
  }

  void _handleSpacePress(String value) {
    final trimmedValue = value.trim();
    // Directly check if it's a valid ID (all digits)
    if (RegExp(r'^[0-9]+$').hasMatch(trimmedValue) && trimmedValue.isNotEmpty) {
      _focusNode.unfocus();
      _lookupById(trimmedValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: "الزبون",
            hintText: _isIdMode ? "أدخل ID الزبون واضغط مسافة" : "اببحث باسم الزبون",
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
            suffixIcon: _selectedClient != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSelection,
                  )
                : null,
          ),
          keyboardType: _isIdMode ? TextInputType.number : TextInputType.text,
          inputFormatters: [
            ClientInputFormatter(onSpacePressed: _handleSpacePress),
          ],
          onChanged: _onTextChanged,
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final client = _suggestions[index];
                final id = client['id'] as int;
                final formattedId = DCustomersTable.formatCustomerId(id);

                return ListTile(
                  title: Text(
                    client['name']?.toString() ?? 'مجهول',
                    style: const TextStyle(fontSize: 16),
                  ),
                  subtitle: Text(
                    'ID: $formattedId${client['phone'] != null ? ' • ${client['phone']}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    _selectClient(client);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
