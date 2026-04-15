import 'dart:ui';

/// Sort mode for product lists
enum SortMode { arabic, latin }

/// Sort order (ascending or descending)
enum SortOrder { ascending, descending }

/// Sort products by name using Arabic alphabetical order
/// Handles Arabic Unicode correctly, ignores diacritics, stable ordering for mixed Arabic/Latin names
/// Items without Arabic characters go to the BOTTOM of the list
List<Map<String, dynamic>> sortProductsArabic(
  List<Map<String, dynamic>> products, {
  SortOrder order = SortOrder.ascending,
}) {
  // Separate items with and without Arabic
  final withArabic = <Map<String, dynamic>>[];
  final withoutArabic = <Map<String, dynamic>>[];

  for (var product in products) {
    final name = product['productName']?.toString() ?? '';
    if (_hasArabicCharacters(name)) {
      withArabic.add(product);
    } else {
      withoutArabic.add(product);
    }
  }

  // Sort items with Arabic
  withArabic.sort((a, b) {
    final nameA = a['productName']?.toString() ?? '';
    final nameB = b['productName']?.toString() ?? '';
    final result = _compareArabicNames(nameA, nameB);
    return order == SortOrder.ascending ? result : -result;
  });

  // Sort items without Arabic (they go to bottom)
  withoutArabic.sort((a, b) {
    final nameA = a['productName']?.toString() ?? '';
    final nameB = b['productName']?.toString() ?? '';
    final result = _compareLatinNames(nameA, nameB);
    return order == SortOrder.ascending ? result : -result;
  });

  // Combine: items with Arabic first, then items without Arabic at bottom
  return [...withArabic, ...withoutArabic];
}

/// Check if text contains Arabic characters
bool _hasArabicCharacters(String text) {
  return RegExp(r'[\u0621-\u064A\u0660-\u0669]').hasMatch(text);
}

/// Arabic alphabet order for proper sorting (standard alphabetical order - 28 letters)
const String _arabicAlphabet = 'ابتثجحدخذرزسشصضطظعغفقكلمنهوي';

/// Get the position of an Arabic character in the alphabet
int _getArabicCharPosition(String char) {
  final index = _arabicAlphabet.indexOf(char);
  return index != -1 ? index : char.codeUnitAt(0);
}

/// Normalize Arabic characters for sorting (treat أ, إ, آ as ا)
String _normalizeArabicForSort(String text) {
  return text
      .replaceAll('أ', 'ا')  // Alif with hamza above
      .replaceAll('إ', 'ا')  // Alif with hamza below
      .replaceAll('آ', 'ا')  // Alif with madda
      .replaceAll('ؤ', 'و')  // Waw with hamza
      .replaceAll('ئ', 'ي')  // Ya with hamza
      .replaceAll('ة', 'ه'); // Ta marbuta as ha
}

/// Compare two Arabic names (internal comparison, assumes both have Arabic)
int _compareArabicNames(String a, String b) {
  final normalizedA = _removeArabicDiacritics(a);
  final normalizedB = _removeArabicDiacritics(b);

  // Extract Arabic characters for comparison
  String arabicA = _extractArabicChars(normalizedA);
  String arabicB = _extractArabicChars(normalizedB);

  // Normalize hamza variations (أ, إ, آ all treated as ا)
  arabicA = _normalizeArabicForSort(arabicA);
  arabicB = _normalizeArabicForSort(arabicB);

  // If both have Arabic, compare Arabic parts character by character
  if (arabicA.isNotEmpty && arabicB.isNotEmpty) {
    // Compare character by character using Arabic alphabetical order
    final minLength = arabicA.length < arabicB.length ? arabicA.length : arabicB.length;
    for (int i = 0; i < minLength; i++) {
      final charA = arabicA[i];
      final charB = arabicB[i];
      if (charA != charB) {
        final posA = _getArabicCharPosition(charA);
        final posB = _getArabicCharPosition(charB);
        return posA - posB;
      }
    }
    // If all compared characters are equal, shorter string comes first
    return arabicA.length - arabicB.length;
  }

  // Fallback to full string comparison
  return normalizedA.compareTo(normalizedB);
}

/// Extract Arabic characters from text
String _extractArabicChars(String text) {
  return text.replaceAll(RegExp(r'[^\u0621-\u064A\u0660-\u0669]'), '');
}

/// Sort products by name using Latin/French alphabetical order
/// Handles accents correctly (é, è, à, ç, etc.), case-insensitive
/// Items without Latin/French characters go to the BOTTOM of the list
List<Map<String, dynamic>> sortProductsLatin(
  List<Map<String, dynamic>> products, {
  SortOrder order = SortOrder.ascending,
}) {
  // Separate items with and without Latin/French characters
  final withLatin = <Map<String, dynamic>>[];
  final withoutLatin = <Map<String, dynamic>>[];

  for (var product in products) {
    final name = product['productName']?.toString() ?? '';
    if (_hasLatinCharacters(name)) {
      withLatin.add(product);
    } else {
      withoutLatin.add(product);
    }
  }

  // Sort items with Latin/French
  withLatin.sort((a, b) {
    final nameA = a['productName']?.toString() ?? '';
    final nameB = b['productName']?.toString() ?? '';
    final result = _compareLatinNames(nameA, nameB);
    return order == SortOrder.ascending ? result : -result;
  });

  // Sort items without Latin/French (they go to bottom)
  withoutLatin.sort((a, b) {
    final nameA = a['productName']?.toString() ?? '';
    final nameB = b['productName']?.toString() ?? '';
    final result = _compareArabicNames(nameA, nameB);
    return order == SortOrder.ascending ? result : -result;
  });

  // Combine: items with Latin first, then items without Latin at bottom
  return [...withLatin, ...withoutLatin];
}

/// Check if text contains Latin characters
bool _hasLatinCharacters(String text) {
  return RegExp(r'[a-zA-Z\u00C0-\u00FF]').hasMatch(text);
}

/// Compare two Latin names (internal comparison, assumes both have Latin)
int _compareLatinNames(String a, String b) {
  final normalizedA = _normalizeLatin(a);
  final normalizedB = _normalizeLatin(b);
  final keyA = _createSortKey(normalizedA, isArabic: false);
  final keyB = _createSortKey(normalizedB, isArabic: false);
  return keyA.compareTo(keyB);
}

/// Check if text is purely Arabic (no Latin characters)
bool _isPurelyArabic(String text) {
  final hasLatin = RegExp(r'[a-zA-Z\u00C0-\u00FF]').hasMatch(text);
  final hasArabic = RegExp(r'[\u0621-\u064A\u0660-\u0669]').hasMatch(text);
  return hasArabic && !hasLatin;
}

/// Sort products by name using the specified sort mode and order
List<Map<String, dynamic>> sortProducts(
  List<Map<String, dynamic>> products,
  SortMode mode, {
  SortOrder order = SortOrder.ascending,
}) {
  return mode == SortMode.arabic
      ? sortProductsArabic(products, order: order)
      : sortProductsLatin(products, order: order);
}


/// Remove Arabic diacritics (tashkeel) from text
String _removeArabicDiacritics(String text) {
  // Arabic diacritics range: U+064B to U+065F, plus U+0670
  return text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
}

/// Normalize Latin text by removing accents and converting to lowercase
String _normalizeLatin(String text) {
  String normalized = text.toLowerCase();

  // Replace common accented characters with their base forms
  const replacements = {
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'à': 'a', 'â': 'a', 'ä': 'a',
    'ù': 'u', 'û': 'u', 'ü': 'u',
    'î': 'i', 'ï': 'i',
    'ô': 'o', 'ö': 'o', 'œ': 'oe',
    'ç': 'c', 'ñ': 'n',
    'É': 'e', 'È': 'e', 'Ê': 'e', 'Ë': 'e',
    'À': 'a', 'Â': 'a', 'Ä': 'a',
    'Ù': 'u', 'Û': 'u', 'Ü': 'u',
    'Î': 'i', 'Ï': 'i',
    'Ô': 'o', 'Ö': 'o', 'Œ': 'oe',
    'Ç': 'c', 'Ñ': 'n',
  };

  for (final entry in replacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }

  return normalized;
}

/// Create a sort key that handles edge cases consistently
/// Rules:
/// 1. Empty/null names come first
/// 2. Names starting with numbers come before letters
/// 3. Special characters are stripped for sorting but original is preserved
String _createSortKey(String text, {required bool isArabic}) {
  if (text.isEmpty) {
    return '';
  }

  // Trim whitespace
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  // Check if starts with number
  final firstChar = trimmed[0];
  if (RegExp(r'[0-9]').hasMatch(firstChar)) {
    // Extract leading numbers and pad for proper numeric sorting
    final numberMatch = RegExp(r'^(\d+)').firstMatch(trimmed);
    if (numberMatch != null) {
      final numStr = numberMatch.group(1)!;
      // Pad number to 10 digits for proper numeric sorting
      final paddedNum = numStr.padLeft(10, '0');
      final rest = trimmed.substring(numStr.length);
      return '###$paddedNum${_normalizeForSort(rest, isArabic: isArabic)}';
    }
  }

  // Check if starts with special character
  if (RegExp(r'[^a-zA-Z\u0621-\u064A\u0660-\u06690-9]').hasMatch(firstChar)) {
    // Strip leading special characters for sorting
    final stripped = trimmed.replaceFirst(RegExp(r'^[^a-zA-Z\u0621-\u064A0-9]+'), '');
    if (stripped.isNotEmpty) {
      return '!!!${_normalizeForSort(stripped, isArabic: isArabic)}';
    }
    return '!!!';
  }

  return _normalizeForSort(trimmed, isArabic: isArabic);
}

/// Normalize text for sorting purposes
String _normalizeForSort(String text, {required bool isArabic}) {
  if (isArabic) {
    // For Arabic mode: keep Arabic characters only
    return text;
  } else {
    // For Latin mode: normalize accents, keep case-insensitive
    String result = _normalizeLatin(text);
    // Remove common special characters for sorting
    result = _removeSpecialChars(result);
    return result;
  }
}

/// Remove special characters from text for sorting
String _removeSpecialChars(String text) {
  // Remove common special characters one by one to avoid regex issues
  String result = text;
  const specialChars = ['%', '_', '/', '-', '@', '#', '\$', '^', '&', '*', '(', ')', '+', '=', '[', ']', '{', '}', '|', ';', ':', "'", '"', '<', '>', ',', '.', '?', '!', '\\\\'];
  for (final char in specialChars) {
    result = result.replaceAll(char, '');
  }
  return result;
}
