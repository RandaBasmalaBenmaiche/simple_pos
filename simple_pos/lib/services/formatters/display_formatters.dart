class DisplayFormatters {
  static String price(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    return parsed.toStringAsFixed(2);
  }

  static String quantity(dynamic value) {
    final parsed = int.tryParse(value?.toString() ?? '') ?? 0;
    return parsed.toString().padLeft(3, '0');
  }

  static String calculateEan13Checksum(String code) {
    if (code.length != 12) return '';
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.tryParse(code[i]) ?? 0;
      sum += (i % 2 == 0) ? digit * 1 : digit * 3;
    }
    int checksum = (10 - (sum % 10)) % 10;
    return checksum.toString();
  }

  static String customerId(dynamic value) {
    final parsed = int.tryParse(value?.toString() ?? '') ?? 0;
    return parsed.toString().padLeft(3, '0');
  }
}
