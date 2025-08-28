import 'package:flutter/material.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/services/local_database/model/tablecustomers.dart';
import 'package:simple_pos/services/local_database/model/tableinvoice.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';


Future<pw.Document> generateInvoicePdf(
  Map<String, dynamic> invoice,
  List<Map<String, dynamic>> items,
) async {
  final pdf = pw.Document();

  // Load Arabic font from assets
  final fontData = await rootBundle.load("assets/fonts/NotoNaskhArabic-VariableFont_wght.ttf");
  final ttf = pw.Font.ttf(fontData);

  // Format date
  final DateTime parsedDate = DateTime.parse(invoice['date']);
  final String formattedDate = DateFormat('yyyy-MM-dd – kk:mm').format(parsedDate);

  pdf.addPage(
    pw.MultiPage(
      textDirection: pw.TextDirection.rtl, // ✅ RTL for Arabic
      build: (pw.Context context) => [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Invoice header
            pw.Text(
              "فاتورة #${invoice['id']}",
              style: pw.TextStyle(font: ttf, fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text("التاريخ: $formattedDate", style: pw.TextStyle(font: ttf)),
            pw.Text("الزبون: ${invoice['customer_name'] ?? 'زائر'}", style: pw.TextStyle(font: ttf)),
            pw.SizedBox(height: 20),

            // Items table
            pw.Table.fromTextArray(
              headers: ["المنتج", "الكمية", "السعر", "المجموع"],
              data: items.map((item) {
                return [
                  item['productName'],
                  item['quantity'],
                  (double.tryParse(item['price'].toString()) ?? 0.0).toStringAsFixed(2),
                  (double.tryParse(item['totalPrice'].toString()) ?? 0.0).toStringAsFixed(2),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
              cellStyle: pw.TextStyle(font: ttf),
              cellAlignment: pw.Alignment.center,
              border: pw.TableBorder.all(width: 0.5),
            ),
            pw.SizedBox(height: 20),

            // Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  "المجموع: ${(double.tryParse(invoice['total'].toString()) ?? 0.0).toStringAsFixed(2)} دج",
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

  int? selectedYear;
  int? selectedMonth;
  int? selectedDay;

  DateTime? startDate;
  DateTime? endDate;

  List<int> years = [];
  List<int> months = [];
  List<int> days = [];

  bool _obscureText = true;
  bool _isAuth = false;

  bool _obscureTextCust = true;
  bool _isAuthCusy = false;

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
        if (invoice['profit'] != null) {
          totalProfit += double.tryParse(invoice['profit'].toString()) ?? 0;
        }
      }
      for (var cust in All_customers) {
        if (cust['debt'] != null) {
          totalDebts += double.tryParse(cust['debt'].toString()) ?? 0;
        }
      }
    });
  }

  void _generateDateFilters() {
    final Set<int> yearSet = {};
    final Set<int> monthSet = {};
    final Set<int> daySet = {};

    for (var item in All_invoices) {
      final date = DateTime.tryParse(item['date']);
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
        final date = DateTime.tryParse(item['date']);
        if (date == null) return false;

        if (selectedYear != null && date.year != selectedYear) return false;
        if (selectedMonth != null && date.month != selectedMonth) return false;
        if (selectedDay != null && date.day != selectedDay) return false;

        if (startDate != null && date.isBefore(startDate!)) return false;
        if (endDate != null && date.isAfter(endDate!)) return false;

        return true;
      }).toList();

      totalProfit = 0;
      for (var invoice in invoices) {
        if (invoice['profit'] != null) {
          totalProfit += double.tryParse(invoice['profit'].toString()) ?? 0;
        }
      }
    });
  }

  void _onSearchChanged() {
    final query = searchController.text.toLowerCase();

    if (query.isEmpty) {
      totalProfit = 0;
      setState(() => invoices = List.from(All_invoices));
      for (var invoice in invoices) {
        if (invoice['profit'] != null) {
          totalProfit += double.tryParse(invoice['profit'].toString()) ?? 0;
        }
      }
      return;
    }

    final filtered = All_invoices.where((item) {
      final date = item['date'].toString().toLowerCase();
      final customer = item['customer_name']?.toString().toLowerCase() ?? '';
      return date.contains(query) || customer.contains(query);
    }).toList();

    totalProfit = 0;
    for (var invoice in filtered) {
      if (invoice['profit'] != null) {
        totalProfit += double.tryParse(invoice['profit'].toString()) ?? 0;
      }
    }

    invoices = filtered;
    setState(() {});
  }

  void _toggleVisibility() async {
    if (_isAuth) {
      _isAuth = !_isAuth;
      _obscureText = !_obscureText;
      setState(() {});
      return;
    }
    String? password = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController passController = TextEditingController();
        return AlertDialog(
          title: const Text("Enter password"),
          content: TextField(
            controller: passController,
            obscureText: true,
            decoration: const InputDecoration(hintText: "Password"),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            TextButton(
                onPressed: () => Navigator.pop(context, passController.text),
                child: const Text("OK")),
          ],
        );
      },
    );

    if (password == '1234') {
      setState(() {
        _obscureText = false;
        _isAuth = !_isAuth;
      });
    } else if (password != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wrong password")),
      );
    }
  }

  void _toggleVisibilityCust() async {
    if (_isAuthCusy) {
      _isAuthCusy = !_isAuthCusy;
      _obscureTextCust = !_obscureTextCust;
      setState(() {});
      return;
    }
    String? password = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController passController = TextEditingController();
        return AlertDialog(
          title: const Text("Enter password"),
          content: TextField(
            controller: passController,
            obscureText: true,
            decoration: const InputDecoration(hintText: "Password"),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            TextButton(
                onPressed: () => Navigator.pop(context, passController.text),
                child: const Text("OK")),
          ],
        );
      },
    );

    if (password == '1234') {
      setState(() {
        _obscureTextCust = false;
        _isAuthCusy = !_isAuthCusy;
      });
    } else if (password != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wrong password")),
      );
    }
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
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "ابحث",
                  filled: true,
                  fillColor: MyColors.secondColor(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.search, color: MyColors.mainColor(context)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            /// Profit & Filters Row
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                      Container(
                        decoration: BoxDecoration(
                          color: MyColors.secondColor(context),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: SizedBox(
                          height: 50,
                          width: 300,
                          child: Row(
                            children: [
                              const Text(" دج ", style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              )),
                              Expanded(
                                child: TextField(
                                    controller: TextEditingController(text: totalProfit.toStringAsFixed(2)),
                                    readOnly: true, 
                                    obscureText: _obscureText,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none, 
                                    ),
                                  ),

                              ),
                              const Text(" الربح الكلي: ", style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                
                              )),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: Icon(
                                  _obscureText ? Icons.visibility : Icons.visibility_off,
                                  size: 30,
                                ),
                                onPressed: _toggleVisibility,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 10,),
                          Container(
                            decoration: BoxDecoration(
                              color: MyColors.secondColor(context),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: SizedBox(
                              height: 50,
                              width: 300,
                              child: Row(
                                children: [
                                  const Text(" دج ", style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  )),
                                  Expanded(
                                    child: TextField(
                                        controller: TextEditingController(text: totalDebts.toStringAsFixed(2)),
                                        readOnly: true, 
                                        obscureText: _obscureTextCust,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none, 
                                        ),
                                      ),
                          
                                  ),
                                  const Text("  مجموع الديون: ", style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    
                                  )),
                                  const SizedBox(width: 10),
                                  IconButton(
                                    icon: Icon(
                                      _obscureTextCust ? Icons.visibility : Icons.visibility_off,
                                      size: 30,
                                    ),
                                    onPressed: _toggleVisibilityCust,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          DropdownButton<int>(
                            value: selectedYear,
                            hint: const Text("السنة"),
                            items: years.map((year) {
                              return DropdownMenuItem(value: year, child: Text(year.toString()));
                            }).toList(),
                            onChanged: (value) {
                              setState(() => selectedYear = value);
                              _filterByDate();
                            },
                          ),
                          DropdownButton<int>(
                            value: selectedMonth,
                            hint: const Text("الشهر"),
                            items: months.map((month) {
                              return DropdownMenuItem(value: month, child: Text(month.toString()));
                            }).toList(),
                            onChanged: (value) {
                              setState(() => selectedMonth = value);
                              _filterByDate();
                            },
                          ),
                          DropdownButton<int>(
                            value: selectedDay,
                            hint: const Text("اليوم"),
                            items: days.map((day) {
                              return DropdownMenuItem(value: day, child: Text(day.toString()));
                            }).toList(),
                            onChanged: (value) {
                              setState(() => selectedDay = value);
                              _filterByDate();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: _pickStartDate,
                        child: Text(startDate == null
                            ? "اختر تاريخ البداية"
                            : "من: ${dateFormatter.format(startDate!)}"),
                      ),
                      SizedBox(width: 10,),
                      ElevatedButton(
                        onPressed: _pickEndDate,
                        child: Text(endDate == null
                            ? "اختر تاريخ النهاية"
                            : "إلى: ${dateFormatter.format(endDate!)}"),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 10),

            /// Invoices List
            (invoices.isNotEmpty)
                ? Flexible(
                    child: ListView.builder(
                      itemCount: invoices.length,
                      itemBuilder: (context, index) {
                        final invoice = invoices[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ExpansionTile(
                            title: Text(
                              "فاتورة #${invoice['id']} - ${invoice['date']}"
                              "${invoice['customer_name'] != null ? ' -- ${invoice['customer_name']} الزبون--' : '--زائر--'}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("المجموع: ${(double.tryParse(invoice['total'].toString()) ?? 0.0).toStringAsFixed(2)} DA"),
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
                                            title: Text("${item['productName']}"),
                                            subtitle: Text("الكود: ${item['productCodeBar']} - الكمية: ${item['quantity']}"),
                                            trailing: Text("${(double.tryParse(item['totalPrice'].toString()) ?? 0.0).toStringAsFixed(2)} DA"),
                                            
                                          );
                                      
                                        }).toList(),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final pdf = await generateInvoicePdf(invoice, items);
                                          await Printing.layoutPdf(
                                            onLayout: (PdfPageFormat format) async => pdf.save(),
                                          );
                                        },
                                        icon: const Icon(Icons.picture_as_pdf),
                                        label: const Text("حفظ PDF"),
                                      ),
                                      SizedBox(height: 10,)
                                    ],
                                  );
                                  
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : const Center(child: Text("لا توجد فواتير حتى الآن")),
          ],
        ),
      ),
    );
  }
}
