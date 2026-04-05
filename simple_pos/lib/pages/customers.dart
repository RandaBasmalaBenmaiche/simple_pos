import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:simple_pos/components/addCustomerDialog.dart';
import 'package:simple_pos/components/editCustomerDialog.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/components/customersTable.dart';
import 'package:simple_pos/components/payDebtDialog.dart';
import 'package:simple_pos/components/sellButton.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/local_database/model/tablecustomers.dart';
import 'package:simple_pos/services/platform/file_text.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class POSPageCustomers extends StatefulWidget {
  const POSPageCustomers({Key? key}) : super(key: key);

  @override
  _POSPageCustomersState createState() => _POSPageCustomersState();
}

class _POSPageCustomersState extends State<POSPageCustomers> {
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> allCustomers = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentStoreId = BlocProvider.of<StoreCubit>(context, listen: false).state;
    _loadCustomers(currentStoreId);
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers(int store) async {
    final rawCustomers = await DCustomersTable().getCustomers(store);
    setState(() {
      customers = List.from(rawCustomers);
      allCustomers = List.from(rawCustomers);
    });
  }

  void _onSearchChanged() {
    final query = searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() => customers = List.from(allCustomers));
      return;
    }

    final filtered = allCustomers.where((customer) {
      final name = customer['name'].toString().toLowerCase();
      final phone = customer['phone']?.toString().toLowerCase() ?? '';
      return name.contains(query) || phone.contains(query);
    }).toList();

    setState(() => customers = filtered);
  }

  // ================= Export Customers CSV =================
  Future<void> exportCustomersToCSV() async {
    List<List<dynamic>> rows = [
      ['Name', 'Phone', 'Debt']
    ];

    for (var customer in allCustomers) {
      rows.add([
        customer['name'],
        customer['phone'],
        customer['debt'],
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('التصدير المباشر غير متاح حالياً على الويب')),
      );
      return;
    }

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'اختر مكان حفظ الملف',
      fileName: 'customers_export.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputFile != null) {
      await writeTextFile(outputFile, csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تصدير العملاء إلى $outputFile')),
      );
    }
  }

  // ================= Import Customers CSV =================
Future<void> importCustomersFromCSV(int storeId) async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv'],
    withData: true,
  );

  if (result != null) {
    final picked = result.files.single;
    String? csvString;

    if (picked.bytes != null) {
      csvString = utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      csvString = await readTextFile(picked.path!);
    }

    if (csvString == null) return;

    List<List<dynamic>> rows =
        const CsvToListConverter().convert(csvString, eol: '\n');

    if (rows.isNotEmpty) {
      // أول صف فيه عناوين الأعمدة (Name, Phone, Debt)
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length >= 3) {
          final name = row[0]?.toString() ?? '';
          final phone = row[1]?.toString() ?? '';
          final debt = double.tryParse(row[2].toString()) ?? 0.0;

          if (name.isNotEmpty) {
            await DCustomersTable().insertCustomer(
              storeId: storeId,
              name: name,
              phone: phone,
              debt: debt,
            );
          }
        }
      }

      await _loadCustomers(storeId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم استيراد العملاء بنجاح')),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreCubit>().state;

    return Scaffold(
      appBar: const CustomPOSAppBar(showReturnButton: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "ابحث بالاسم أو الهاتف",
                      filled: true,
                      fillColor: MyColors.secondColor(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.search, color: MyColors.secondColor(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  CustomActionButton(
                    text: "إضافة عميل",
                    onPressed: () {
                      showAddCustomerDialog(context, (name, phone , debt) async {
                        await DCustomersTable().insertCustomer(
                          storeId: store,
                          name: name,
                          phone: phone,
                          debt: double.parse(debt),
                        );
                        await _loadCustomers(store);
                      }, showIdAfterCreate: true);
                    },
                  ),
                  const SizedBox(width: 10),
                  CustomActionButton(
                    text: "تصدير العملاء",
                    onPressed: () async {
                      await exportCustomersToCSV();
                    },
                  ),
                  const SizedBox(width: 10),
                  CustomActionButton(
                    text: "استراد العملاء",
                    onPressed: () async {
                      await importCustomersFromCSV(store);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Customers Table
            Flexible(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: POSCustomersTable(
                  customers: customers,
                  onEdit: (int index) async{
                    final customer = customers[index];
                    await showEditCustomerDialog(context, customer, (name, phone) async {
                      await DCustomersTable().updateCustomer(
                        id: customer['id'],
                        name: name,
                        phone: phone,
                      );
                      await _loadCustomers(store);
                    });
                  },
                  onPayDebt: (index) async {
                    final customer = customers[index];
                    await showPayDebtDialog(context, customer,  "تسديد دين للعميل" , (amount) async {
                      final newDebt = (customer['debt'] ?? 0) - amount;
                      await DCustomersTable().updateCustomer(
                        id: customer['id'],
                        debt: newDebt,
                      );
                      await _loadCustomers(store);
                    });
                  },
                  onDelete: (index) async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("هل أنت متأكد؟", textAlign: TextAlign.center),
                          content: const Text("سيتم حذف هذا العميل نهائيًا!", textAlign: TextAlign.center),
                          actionsAlignment: MainAxisAlignment.center,
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("حذف", style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirm == true) {
                      final customer = customers[index];
                      await DCustomersTable().deleteCustomer(customer['id']);

                      setState(() {
                        allCustomers.removeAt(index);
                      });
                      await _loadCustomers(store);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
