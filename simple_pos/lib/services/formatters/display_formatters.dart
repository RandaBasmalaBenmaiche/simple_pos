class DisplayFormatters {
  static String price(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    return parsed.toStringAsFixed(2);
  }

  static String quantity(dynamic value) {
    final parsed = int.tryParse(value?.toString() ?? '') ?? 0;
    return parsed.toString().padLeft(3, '0');
  }

  static String customerId(dynamic value) {
    final parsed = int.tryParse(value?.toString() ?? '') ?? 0;
    return parsed.toString().padLeft(3, '0');
  }
}
