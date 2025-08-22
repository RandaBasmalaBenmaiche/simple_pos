import 'package:flutter/material.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/services/local_database/model/tableinvoice.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


class POSPageHistorique extends StatefulWidget {
  const POSPageHistorique({Key? key}) : super(key: key);

  @override
  _POSPageHistoriqueState createState() => _POSPageHistoriqueState();
}

class _POSPageHistoriqueState extends State<POSPageHistorique> {

  List<Map<String, dynamic>> All_invoices = [];
  List<Map<String, dynamic>> invoices = [];
  TextEditingController searchController = TextEditingController();

  int? selectedYear;
  int? selectedMonth;
  int? selectedDay;

  List<int> years = [];
  List<int> months = [];
  List<int> days = [];

  Future<void> _loadInvoices(int store) async {
    final invoiceTable = DInvoiceTable();
    final data = await invoiceTable.getInvoices(store);
    setState(() {
      All_invoices = data;
      invoices = data;
      _generateDateFilters();
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

        return true;
      }).toList();
    });
  }

  void _onSearchChanged() {
    final query = searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() => invoices = List.from(All_invoices));
      return;
    }

    final filtered = All_invoices.where((item) {
      final date = item['date'].toString().toLowerCase();
      return date.contains(query);
    }).toList();

    setState(() => invoices = filtered);
  }

  @override
  void initState() {
    super.initState();
    final currentStoreId = BlocProvider.of<StoreCubit>(context, listen: false).state;
    _loadInvoices(currentStoreId);
    searchController.addListener(_onSearchChanged);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomPOSAppBar(showReturnButton: true),
      body: Column(
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

          /// Dropdown Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(height: 10, width: 10,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Year Dropdown
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
                    // Month Dropdown
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
                    // Day Dropdown
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
                            "فاتورة #${invoice['id']} - ${invoice['date']}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("المجموع: ${invoice['total']} DA"),
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
                                  children: items.map((item) {
                                    return ListTile(
                                      title: Text("${item['productName']}"),
                                      subtitle: Text(
                                          "الكود: ${item['productCodeBar']} - الكمية: ${item['quantity']}"),
                                      trailing: Text("${item['totalPrice']} DA"),
                                    );
                                  }).toList(),
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
    );
  }
}
