import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/components/AutoComplete.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/styles/my_colors.dart';

Future<void> showEditProductDialog(
    BuildContext context, Future<void> Function() onUpdate) async {
  await showDialog(
    context: context,
    builder: (context) => EditProductDialog(onUpdate: onUpdate),
  );
}

class EditProductDialog extends StatefulWidget {
  final Future<void> Function() onUpdate;

  const EditProductDialog({super.key, required this.onUpdate});

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  late final TextEditingController codeController;
  late final TextEditingController oldNameController;
  late final TextEditingController newCodeController;
  late final TextEditingController nameController;
  late final TextEditingController priceController;
  late final TextEditingController quantityController;

  late final FocusNode newCodeFocus;
  late final FocusNode nameFocus;
  late final FocusNode priceFocus;
  late final FocusNode quantityFocus;

  late final DStockTable stockTable;
  late final int storeId;
  late final List<String> productNames;

  bool isLoaded = false;
  bool isEditable = true;
  int? loadedProductId;

  @override
  void initState() {
    super.initState();
    codeController = TextEditingController();
    oldNameController = TextEditingController();
    newCodeController = TextEditingController();
    nameController = TextEditingController();
    priceController = TextEditingController();
    quantityController = TextEditingController();

    newCodeFocus = FocusNode();
    nameFocus = FocusNode();
    priceFocus = FocusNode();
    quantityFocus = FocusNode();

    stockTable = DStockTable();
    storeId = BlocProvider.of<StoreCubit>(context, listen: false).state;

    // Load product names asynchronously
    _initProductNames();
  }

  Future<void> _initProductNames() async {
    final names = await stockTable.getAllProductNames(storeId);
    if (mounted) {
      setState(() {
        _suggestions = names;
      });
    }
  }

  // Using a separate list for suggestions to avoid initState async gaps
  List<String> _suggestions = [];
  Future<void> _loadSuggestions() async {
    final names = await stockTable.getAllProductNames(storeId);
    if (mounted) {
      setState(() => _suggestions = names);
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    oldNameController.dispose();
    newCodeController.dispose();
    nameController.dispose();
    priceController.dispose();
    quantityController.dispose();

    newCodeFocus.dispose();
    nameFocus.dispose();
    priceFocus.dispose();
    quantityFocus.dispose();

    super.dispose();
  }

  Future<void> loadProduct() async {
    Map<String, dynamic>? product;

    if (codeController.text.isNotEmpty) {
      product = await stockTable.getProductByCode(codeController.text, storeId);
    } else if (oldNameController.text.isNotEmpty) {
      product = await stockTable.getProductByName(oldNameController.text, storeId);
    }

    if (product != null && product.isNotEmpty) {
      final productData = product;
      if (!mounted) return;
      setState(() {
        loadedProductId = productData['id'] as int?;
        newCodeController.text = productData['productCodeBar']?.toString() ?? '';
        nameController.text = productData['productName']?.toString() ?? '';
        priceController.text = productData['productPrice']?.toString() ?? '';
        quantityController.text = productData['productQuantity']?.toString() ?? '';
        isLoaded = true;
        isEditable = false;
      });
      FocusScope.of(context).requestFocus(newCodeFocus);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("المنتج غير موجود")));
    }
  }

  Future<void> submitUpdate() async {
    bool success = false;

    final String? newCode = newCodeController.text.isEmpty ? null : newCodeController.text;
    final String? newName = nameController.text.isEmpty ? null : nameController.text;
    final String? newPrice = priceController.text.isEmpty ? null : priceController.text;
    final String? newQuantity = quantityController.text.isEmpty ? null : quantityController.text;

    if (codeController.text.isNotEmpty) {
      success = await stockTable.updateProduct(
        codeBar: codeController.text,
        newCodeBar: newCode,
        newName: newName,
        newPrice: newPrice,
        newQuantity: newQuantity,
        storeId: storeId,
      );
    } else if (oldNameController.text.isNotEmpty) {
      success = await stockTable.updateProductByName(
        name: oldNameController.text,
        newCodeBar: newCode,
        newName: newName,
        newPrice: newPrice,
        newQuantity: newQuantity,
        storeId: storeId,
      );
    }

    if (!success && loadedProductId != null) {
      success = await stockTable.updateProductById(
        id: loadedProductId!,
        newCodeBar: newCode,
        newName: newName,
        newPrice: newPrice,
        newQuantity: newQuantity,
      );
    }

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("تم التحديث بنجاح")));
      Navigator.pop(context);
      await widget.onUpdate();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("حدث خطأ أثناء التحديث")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Load suggestions on first build if empty
    if (_suggestions.isEmpty) {
      _loadSuggestions();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(
                label: "كود المنتج الحالي",
                controller: codeController,
                enabled: isEditable,
                numbersOnly: true,
                onSubmitted: (_) => loadProduct()),
            const SizedBox(height: 10),
            AutoCompleteInputField(
              controller: oldNameController,
              label: "اسم المنتج الحالي",
              suggestions: _suggestions,
              isAlphanumeric: true,
              expands: false,
              enabled: isEditable,
            ),
            const SizedBox(height: 10),
            if (isLoaded) ...[
              _buildTextField(
                  label: "كود المنتج الجديد",
                  controller: newCodeController,
                  focusNode: newCodeFocus,
                  numbersOnly: true,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(nameFocus)),
              const SizedBox(height: 10),
              _buildTextField(
                  label: "اسم المنتج",
                  controller: nameController,
                  focusNode: nameFocus,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(priceFocus)),
              const SizedBox(height: 10),
              _buildTextField(
                  label: "ثمن البيع",
                  controller: priceController,
                  numbersOnly: true,
                  focusNode: priceFocus,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(quantityFocus)),
              const SizedBox(height: 10),
              _buildTextField(
                  label: "الكمية",
                  controller: quantityController,
                  numbersOnly: true,
                  focusNode: quantityFocus,
                  onSubmitted: (_) => submitUpdate()),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text("إلغاء",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white)),
                  ),
                ),
                if (!isLoaded)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.mainColor(context),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: loadProduct,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text("التالي",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white)),
                    ),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.mainColor(context),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: submitUpdate,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text("حفظ",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    bool numbersOnly = false,
    FocusNode? focusNode,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      focusNode: focusNode,
      inputFormatters:
          numbersOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      onSubmitted: onSubmitted,
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
}
