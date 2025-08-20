import 'package:flutter/material.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/services/local_database/model/tableinvoice.dart';
import 'package:simple_pos/styles/my_colors.dart';

class POSPageHistorique extends StatefulWidget {
  const POSPageHistorique({Key? key}) : super(key: key);

  @override
  _POSPageHistoriqueState createState() => _POSPageHistoriqueState();
}

class _POSPageHistoriqueState extends State<POSPageHistorique> {
  List<Map<String, dynamic>> All_invoices = [];
  List<Map<String, dynamic>> invoices = [];
  TextEditingController searchController = TextEditingController();

    Future<void> _loadInvoices() async {
    final invoiceTable = DInvoiceTable();
    final data = await invoiceTable.getInvoices();
    setState(() {
      All_invoices = data;
      invoices = data;
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
    _loadInvoices();
    searchController.addListener(_onSearchChanged);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomPOSAppBar(showReturnButton: true),
      body:
          Column(
            children: [
              const SizedBox(height: 20,),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "ابحث بالتاريخ",
                        filled: true,
                        fillColor: MyColors.secondColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.search, color: MyColors.mainColor),
                      ),
                    ),
              ),
              const SizedBox(height: 20,),
              (invoices.isNotEmpty)?Flexible(
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
                              future: DInvoiceItemsTable()
                                  .getItemsByInvoiceId(invoice['id']),
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
              ):const Center(child: Text("لا توجد فواتير حتى الآن"))

            ],
          ),
    );
  }
}
