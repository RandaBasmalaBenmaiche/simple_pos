import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/components/scrollArrowButtons.dart';
import 'package:simple_pos/services/formatters/display_formatters.dart';
import 'package:simple_pos/services/local_database/model/tableinvoice.dart';
import 'package:simple_pos/styles/my_colors.dart';

import 'package:simple_pos/pages/history.dart' show generateInvoicePdf;

class InvoicePreviewPage extends StatefulWidget {
  const InvoicePreviewPage({
    super.key,
    required this.invoiceId,
  });

  final int invoiceId;

  @override
  State<InvoicePreviewPage> createState() => _InvoicePreviewPageState();
}

class _InvoicePreviewPageState extends State<InvoicePreviewPage> {
  Map<String, dynamic>? invoice;
  List<Map<String, dynamic>> items = [];
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    final invoiceTable = DInvoiceTable();
    final invoiceItemsTable = DInvoiceItemsTable();
    final loadedInvoice = await invoiceTable.getInvoiceById(widget.invoiceId);
    final loadedItems = await invoiceItemsTable.getItemsByInvoiceId(widget.invoiceId);

    if (!mounted) return;
    setState(() {
      invoice = loadedInvoice;
      items = loadedItems;
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollBy(double delta) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target =
        (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomPOSAppBar(showReturnButton: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : invoice == null
              ? const Center(child: Text('تعذر تحميل الفاتورة'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 16),
                      Expanded(child: _buildItemsList(context)),
                      const SizedBox(height: 16),
                      _buildFooter(context),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final parsedDate = DateTime.tryParse(invoice?['date']?.toString() ?? '');
    final formattedDate = parsedDate == null
        ? (invoice?['date']?.toString() ?? '')
        : DateFormat('yyyy-MM-dd HH:mm').format(parsedDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.secondColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'فاتورة رقم ${DisplayFormatters.quantity(invoice?['id'])}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('التاريخ: $formattedDate'),
          Text('الزبون: ${invoice?['customer_name'] ?? 'زائر'}'),
          Text('المجموع: ${DisplayFormatters.price(invoice?['total'])} دج'),
          Text(
            'الدين الحالي: ${DisplayFormatters.price(invoice?['total_debt_customer'])} دج',
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(BuildContext context) {
    return Column(
      children: [
        ScrollArrowButtons(
          onScrollUp: () => _scrollBy(-220),
          onScrollDown: () => _scrollBy(220),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  title: Text(item['productName']?.toString() ?? 'غير محدد'),
                  subtitle: Text(
                    'الكود: ${item['productCodeBar'] ?? '-'}  |  الكمية: ${DisplayFormatters.quantity(item['quantity'])}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('السعر: ${DisplayFormatters.price(item['price'])}'),
                      Text('الإجمالي: ${DisplayFormatters.price(item['totalPrice'])}'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            final currentInvoice = invoice;
            if (currentInvoice == null) return;
            final pdf = await generateInvoicePdf(currentInvoice, items);
            await Printing.layoutPdf(
              onLayout: (PdfPageFormat format) async => pdf.save(),
            );
          },
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('حفظ PDF'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('رجوع إلى البيع'),
        ),
      ],
    );
  }
}
