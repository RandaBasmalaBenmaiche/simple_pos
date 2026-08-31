import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._();
  GeminiService._();

  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  Future<List<Map<String, String>>> extractProductsFromImage(List<int> imageBytes) async {
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API Key not configured. Please provide it via --dart-define=GEMINI_API_KEY=...');
    }

    final model = GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: _apiKey,
    );

    final prompt = '''
You are a specialized OCR and product extraction agent for a POS system. Your task is to read an image of a product list or invoice and extract all products and their quantities.

Follow these rules strictly:
1. Extract every visible product and its associated quantity.
2. Preserve the product name exactly as written in the image.
3. Handle Arabic, French, English, and mixed-language text.
4. Distinguish clearly between the product name and the quantity.
5. Return the data ONLY as a valid JSON array of objects.
6. Do not include any markdown formatting (like \`\`\`json), no preamble, and no post-amble.
7. If a quantity is not visible, use '1'.
8. If the image is low quality, extract the most likely text.
9. Never invent products or quantities that are not in the image.

Expected JSON format:
[
  {
    "name": "Coca Cola 33cl",
    "quantity": "10"
  },
  {
    "name": "Eau Minérale 1.5L",
    "quantity": "5"
  }
]
''';

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', Uint8List.fromList(imageBytes)),
      ])
    ];

    try {
      final response = await model.generateContent(content);
      final text = response.text;
      if (text == null) return [];

      // Remove markdown code blocks if present, despite the prompt
      String cleanedText = text;
      if (cleanedText.contains('```json')) {
        cleanedText = cleanedText.split('```json')[1].split('```')[0];
      } else if (cleanedText.contains('```')) {
        cleanedText = cleanedText.split('```')[1].split('```')[0];
      }
      cleanedText = cleanedText.trim();

      final List<dynamic> decoded = jsonDecode(cleanedText);
      return decoded.map((item) {
        final map = item as Map<String, dynamic>;
        return {
          'name': map['name']?.toString() ?? '',
          'quantity': map['quantity']?.toString() ?? '1',
        };
      }).toList();
    } catch (e) {
      print('Gemini extraction error: $e');
      rethrow;
    }
  }
}

// Helper to avoid casting errors in the map
extension MapExt on Map<String, dynamic> {
  String getSafeString(String key) => this[key]?.toString() ?? '';
}
