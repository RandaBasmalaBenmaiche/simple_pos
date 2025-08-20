import 'package:flutter/material.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/services/local_database/model/tableinvoice.dart';

class POSPageHistorique extends StatefulWidget {
  const POSPageHistorique({Key? key}) : super(key: key);

  @override
  _POSPageHistoriqueState createState() => _POSPageHistoriqueState();
}

class _POSPageHistoriqueState extends State<POSPageHistorique> {
  List<Map<String, dynamic>> invoices = [];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    final invoiceTable = DInvoiceTable();
    final data = await invoiceTable.getInvoices();
    setState(() {
      invoices = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomPOSAppBar(showReturnButton: true),
      body: invoices.isEmpty
          ? const Center(child: Text("لا توجد فواتير حتى الآن"))
          : ListView.builder(
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
    );
  }
}
