import 'package:flutter/material.dart';
import 'package:simple_pos/styles/my_colors.dart';

class CartItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(int newQuantity) onQuantityChanged;
  final VoidCallback onDelete;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['productName']?.toString() ?? 'Unknown';
    final price = double.tryParse(item['productPrice']?.toString() ?? '0') ?? 0.0;
    final quantity = int.tryParse(item['productQuantity']?.toString() ?? '0') ?? 0;
    final total = double.tryParse(item['total']?.toString() ?? '0') ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Unit Price: ${price.toStringAsFixed(2)} دج",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _buildQuantityButton(
                  icon: Icons.remove,
                  onPressed: quantity > 1
                      ? () => onQuantityChanged(quantity - 1)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    "$quantity",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildQuantityButton(
                  icon: Icons.add,
                  onPressed: () => onQuantityChanged(quantity + 1),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${total.toStringAsFixed(2)} دج",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: MyColors.mainColor(context),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: onDelete,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton({required IconData icon, required VoidCallback? onPressed}) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      constraints: const BoxConstraints(
        minWidth: 32,
        minHeight: 32,
      ),
      padding: EdgeInsets.zero,
    );
  }
}
