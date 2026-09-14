import 'package:flutter/material.dart';
import 'package:simple_pos/services/local_database/model/tabledebt.dart';
import 'package:simple_pos/services/formatters/display_formatters.dart';
import 'package:simple_pos/styles/my_colors.dart';

Future<void> showPaymentHistoryDialog(
  BuildContext context,
  Map<String, dynamic> customer,
) async {
  final customerId = customer['id'] as int;
  final customerName = customer['name']?.toString() ?? 'Client';

  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("تاريخ تسديدات $customerName", textAlign: TextAlign.center),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: DDebtPaymentsTable().getPaymentsByCustomer(customerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("حدث خطأ في تحميل البيانات"));
              }
              final payments = snapshot.data ?? [];
              if (payments.isEmpty) {
                return const Center(
                  child: Text("لا توجد سجلات تسديد"),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payments.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  return ListTile(
                    leading: const Icon(Icons.payment, color: Colors.green),
                    title: Text(
                      "المبلغ: ${DisplayFormatters.price(payment['amount_paid'])} دج",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("التاريخ: ${payment['payment_date']}"),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إغلاق"),
          ),
        ],
      );
    },
  );
}
