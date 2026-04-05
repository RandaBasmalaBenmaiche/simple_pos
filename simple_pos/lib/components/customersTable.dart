import 'package:flutter/material.dart';
import 'package:simple_pos/components/scrollArrowButtons.dart';
import 'package:simple_pos/services/formatters/display_formatters.dart';
import 'package:simple_pos/styles/my_colors.dart';

class POSCustomersTable extends StatefulWidget {
  final List<Map<String, dynamic>> customers;
  final Function(int index) onDelete;
  final Function(int index) onEdit;
  final Function(int index) onPayDebt;

  const POSCustomersTable({
    super.key,
    required this.customers,
    required this.onDelete,
    required this.onEdit,
    required this.onPayDebt,
  });

  @override
  State<POSCustomersTable> createState() => _POSCustomersTableState();
}

class _POSCustomersTableState extends State<POSCustomersTable> {
  final ScrollController _scrollController = ScrollController();

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
    return Container(
      decoration: BoxDecoration(
        color: MyColors.secondColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MyColors.mainColor(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text("الدين", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                Expanded(flex: 3, child: Text("الهاتف", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                Expanded(flex: 4, child: Text("الإسم", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                Expanded(flex: 2, child: Text("ID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                SizedBox(width: 108),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: ScrollArrowButtons(
              onScrollUp: () => _scrollBy(-220),
              onScrollDown: () => _scrollBy(220),
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: widget.customers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final customer = widget.customers[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          DisplayFormatters.price(customer['debt']),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(customer['phone']?.toString() ?? ''),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          customer['name']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(DisplayFormatters.customerId(customer['id'])),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => widget.onEdit(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_money, color: Colors.green),
                        onPressed: () => widget.onPayDebt(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => widget.onDelete(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
