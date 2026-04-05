import 'dart:async';
import 'package:flutter/material.dart';
import 'package:simple_pos/components/scrollArrowButtons.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/services/formatters/display_formatters.dart';
import 'package:simple_pos/services/local_database/model/tablecustomers.dart';
import 'package:simple_pos/services/local_database/model/tableinvoice.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/supabase/web_realtime_service.dart';
import 'package:simple_pos/services/supabase/web_runtime.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

// ✅ Generate Invoice PDF safely with mirrored columns
Future<pw.Document> generateInvoicePdf(
  Map<String, dynamic> invoice,
  List<Map<String, dynamic>> items,
) async {
  final pdf = pw.Document();

  // Load Arabic font
  final fontData = await rootBundle.load("assets/fonts/NotoNaskhArabic-VariableFont_wght.ttf");
  final ttf = pw.Font.ttf(fontData);

  // ✅ Safely parse date
  final String dateString = invoice['date']?.toString() ?? '';
  final DateTime parsedDate = DateTime.tryParse(dateString) ?? DateTime.now();
  final String formattedDate = DateFormat('yyyy-MM-dd – kk:mm').format(parsedDate);

  pdf.addPage(
    pw.MultiPage(
      textDirection: pw.TextDirection.rtl,
      build: (pw.Context context) => [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "وصل رقم ${invoice['id'].toString().padLeft(2, '0') }",
              style: pw.TextStyle(font: ttf, fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text("التاريخ: $formattedDate", style: pw.TextStyle(font: ttf)),
            pw.Text("الزبون: ${invoice['customer_name'] ?? 'زائر'}", style: pw.TextStyle(font: ttf)),
            // ✅ Display total debt
            pw.Text(
              "إجمالي الدين: ${(double.tryParse(invoice['total_debt_customer']?.toString() ?? '') ?? 0.0).toStringAsFixed(2)} دج",
              style: pw.TextStyle(font: ttf),
            ),
            pw.SizedBox(height: 20),

            // ✅ Table with mirrored headers and rows
            pw.Table.fromTextArray(
              headers: ["المجموع", "السعر", "الكمية", "المنتج", "رقم"], // ✅ Reverse order
              data: List.generate(items.length, (i) {
                final item = items[i];
                final productName = item['productName'] ?? 'غير محدد';
                final quantity = DisplayFormatters.quantity(item['quantity']);
                final price = DisplayFormatters.price(item['price']);
                final total = DisplayFormatters.price(item['totalPrice']);

                return [
                  total,
                  price,
                  quantity,
                  productName,
                  (i + 1).toString().padLeft(2, '0') // ✅ Serial number
                ];
              }),
              headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
              cellStyle: pw.TextStyle(font: ttf),
              cellAlignment: pw.Alignment.center,
              border: pw.TableBorder.all(width: 0.5),
            ),

            pw.SizedBox(height: 20),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  "المجموع: ${(double.tryParse(invoice['total']?.toString() ?? '') ?? 0.0).toStringAsFixed(2)} دج",
                  style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  return pdf;
}




class POSPageHistorique extends StatefulWidget {
  const POSPageHistorique({Key? key}) : super(key: key);

  @override
  _POSPageHistoriqueState createState() => _POSPageHistoriqueState();
}

class _POSPageHistoriqueState extends State<POSPageHistorique> {
  List<Map<String, dynamic>> All_invoices = [];
  List<Map<String, dynamic>> All_customers = [];
  List<Map<String, dynamic>> invoices = [];
  TextEditingController searchController = TextEditingController();
  StreamSubscription<Set<String>>? _realtimeSub;
  final ScrollController _scrollController = ScrollController();

  int? selectedYear;
  int? selectedMonth;
  int? selectedDay;

  DateTime? startDate;
  DateTime? endDate;

  List<int> years = [];
  List<int> months = [];
  List<int> days = [];

  double totalProfit = 0;
  double totalDebts = 0;

  Future<void> _loadInvoices(int store) async {
    final invoiceTable = DInvoiceTable();
    final customersTable = DCustomersTable();
    final data = await invoiceTable.getInvoices(store);
    final dataCust = await customersTable.getCustomers(store);
    setState(() {
      totalProfit = 0;
      totalDebts = 0;
      All_invoices = data;
      All_customers = dataCust;
      invoices = data;
      _generateDateFilters();
      for (var invoice in invoices) {
        totalProfit += double.tryParse(invoice['profit']?.toString() ?? '') ?? 0;
      }
      for (var cust in All_customers) {
        totalDebts += double.tryParse(cust['debt']?.toString() ?? '') ?? 0;
      }
    });
  }

  void _generateDateFilters() {
    final Set<int> yearSet = {};
    final Set<int> monthSet = {};
    final Set<int> daySet = {};

    for (var item in All_invoices) {
      final date = DateTime.tryParse(item['date']?.toString() ?? '');
      if (date != null) {
        yearSet.add(date.year);
        monthSet.add(date.month);
        daySet.add(date.day);
      }
    }

    years = yearSet.toList()..sort();
    months = monthSet.toList()..sort();
    days = daySet.toList()..sort();
  }

  void _filterByDate() {
    setState(() {
      invoices = All_invoices.where((item) {
        final date = DateTime.tryParse(item['date']?.toString() ?? '');
        if (date == null) return false;

        // Normalize dates to compare only date portions (ignore time)
        final invoiceDate = DateTime(date.year, date.month, date.day);

        if (selectedYear != null && date.year != selectedYear) return false;
        if (selectedMonth != null && date.month != selectedMonth) return false;
        if (selectedDay != null && date.day != selectedDay) return false;

        // Compare date ranges using normalized dates (start of day for startDate, end of day for endDate)
        if (startDate != null) {
          final startOfDay = DateTime(startDate!.year, startDate!.month, startDate!.day);
          if (invoiceDate.isBefore(startOfDay)) return false;
        }
        if (endDate != null) {
          final endOfDay = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
          if (invoiceDate.isAfter(endOfDay)) return false;
        }

        return true;
      }).toList();

      totalProfit = 0;
      for (var invoice in invoices) {
        totalProfit += double.tryParse(invoice['profit']?.toString() ?? '') ?? 0;
      }
    });
  }

  void _onSearchChanged() {
    final query = searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() {
        invoices = List.from(All_invoices);
        totalProfit = invoices.fold(0, (sum, inv) => sum + (double.tryParse(inv['profit']?.toString() ?? '') ?? 0));
      });
      return;
    }

    final filtered = All_invoices.where((item) {
      final date = item['date']?.toString().toLowerCase() ?? '';
      final customer = item['customer_name']?.toString().toLowerCase() ?? '';
      return date.contains(query) || customer.contains(query);
    }).toList();

    totalProfit = filtered.fold(0, (sum, inv) => sum + (double.tryParse(inv['profit']?.toString() ?? '') ?? 0));
    invoices = filtered;
    setState(() {});
  }

  Future<void> _pickStartDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => startDate = picked);
      _filterByDate();
    }
  }

  Future<void> _pickEndDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => endDate = picked);
      _filterByDate();
    }
  }

  @override
  void initState() {
    super.initState();
    final currentStoreId = BlocProvider.of<StoreCubit>(context, listen: false).state;
    _loadInvoices(currentStoreId);
    searchController.addListener(_onSearchChanged);
    if (useSupabaseWeb) {
      _realtimeSub = WebRealtimeService.instance.changes.listen((tables) {
        if ((tables.contains('invoices') ||
                tables.contains('invoice_items') ||
                tables.contains('customers')) &&
            mounted) {
          final store = BlocProvider.of<StoreCubit>(context, listen: false).state;
          _loadInvoices(store);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _realtimeSub?.cancel();
    searchController.dispose();
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
    final dateFormatter = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: const CustomPOSAppBar(showReturnButton: true),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildSearchBar(),
            const SizedBox(height: 10),
            _buildProfitAndFilters(dateFormatter),
            const SizedBox(height: 10),
            _buildInvoicesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: "ابحث",
          filled: true,
          fillColor: MyColors.secondColor(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          prefixIcon: Icon(Icons.search, color: MyColors.mainColor(context)),
        ),
      ),
    );
  }

  Widget _buildProfitAndFilters(DateFormat dateFormatter) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTotals(),
              _buildDropdownFilters(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _pickStartDate,
                child: Text(startDate == null ? "اختر تاريخ البداية" : "من: ${dateFormatter.format(startDate!)}"),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _pickEndDate,
                child: Text(endDate == null ? "اختر تاريخ النهاية" : "إلى: ${dateFormatter.format(endDate!)}"),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTotals() {
    return const Column(children: []);
  }

  Widget _buildTotalField(String label, double value) {
    return Container(
      decoration: BoxDecoration(color: MyColors.secondColor(context), borderRadius: BorderRadius.circular(15)),
      child: SizedBox(
        height: 50,
        width: 300,
        child: Row(
          children: [
            const Text(" دج ", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: value.toStringAsFixed(2)),
                readOnly: true,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
            Text(" $label: ", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilters() {
    return Row(
      children: [
        DropdownButton<int>(
          value: selectedYear,
          hint: const Text("السنة"),
          items: years.map((year) => DropdownMenuItem(value: year, child: Text(year.toString()))).toList(),
          onChanged: (value) {
            setState(() => selectedYear = value);
            _filterByDate();
          },
        ),
        DropdownButton<int>(
          value: selectedMonth,
          hint: const Text("الشهر"),
          items: months.map((month) => DropdownMenuItem(value: month, child: Text(month.toString()))).toList(),
          onChanged: (value) {
            setState(() => selectedMonth = value);
            _filterByDate();
          },
        ),
        DropdownButton<int>(
          value: selectedDay,
          hint: const Text("اليوم"),
          items: days.map((day) => DropdownMenuItem(value: day, child: Text(day.toString()))).toList(),
          onChanged: (value) {
            setState(() => selectedDay = value);
            _filterByDate();
          },
        ),
      ],
    );
  }

  Widget _buildInvoicesList() {
    return invoices.isNotEmpty
        ? Flexible(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ScrollArrowButtons(
                    onScrollUp: () => _scrollBy(-260),
                    onScrollDown: () => _scrollBy(260),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: invoices.length,
                    itemBuilder: (context, index) {
                      final invoice = invoices[index];
                      final date = invoice['date']?.toString() ?? 'غير محدد';
                      final customer = invoice['customer_name']?.toString().isNotEmpty == true
                          ? invoice['customer_name']
                          : 'زائر';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ExpansionTile(
                          title: Text(
                            "فاتورة رقم${invoice['id'] ?? '-'} - $date -- $customer",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "المجموع: ${(double.tryParse(invoice['total']?.toString() ?? '') ?? 0.0).toStringAsFixed(2)} DA",
                          ),
                          children: [
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: DInvoiceItemsTable().getItemsByInvoiceId(invoice['id']),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                final items = snapshot.data!;
                                if (items.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text("لا توجد منتجات في هذه الفاتورة"),
                                  );
                                }
                                return Column(
                                  children: [
                                    Column(
                                      children: items.map((item) {
                                        return ListTile(
                                          title: Text(item['productName']?.toString() ?? "غير محدد"),
                                          subtitle: Text(
                                              "الكود: ${item['productCodeBar'] ?? '-'} - الكمية: ${DisplayFormatters.quantity(item['quantity'])}"),
                                          trailing: Text(
                                            "${DisplayFormatters.price(item['totalPrice'])} DA",
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final pdf = await generateInvoicePdf(invoice, items);
                                        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
                                      },
                                      icon: const Icon(Icons.picture_as_pdf),
                                      label: const Text("حفظ PDF"),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        : const Center(child: Text("لا توجد فواتير حتى الآن"));
  }
}
