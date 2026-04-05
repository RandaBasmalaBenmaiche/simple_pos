import 'package:flutter/material.dart';

class ScrollArrowButtons extends StatelessWidget {
  const ScrollArrowButtons({
    super.key,
    required this.onScrollUp,
    required this.onScrollDown,
  });

  final VoidCallback onScrollUp;
  final VoidCallback onScrollDown;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: onScrollUp,
          icon: const Icon(Icons.keyboard_arrow_up),
          label: const Text('فوق'),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: onScrollDown,
          icon: const Icon(Icons.keyboard_arrow_down),
          label: const Text('تحت'),
        ),
      ],
    );
  }
}
