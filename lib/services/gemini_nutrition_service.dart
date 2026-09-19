import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/indian_meal_result.dart';

class GeminiNutritionService {
  GeminiNutritionService._();

  static final GeminiNutritionService instance = GeminiNutritionService._();

  // Configurable Gemini API Key. Defaults to user's verified Gemini key.
  static String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyBbvVAQKJpnoYugg47a_mREM9LBiznxJTk',
  );

  static const String model = 'gemini-2.5-flash';

  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// Analyzes image bytes using Google Gemini 1.5 Flash Vision API (1,500 FREE requests/day)
  Future<IndianMealResult> analyzeMealBytes(
    Uint8List imageBytes, {
    String filename = 'meal.jpg',
    double confidenceThreshold = 0.5,
  }) async {
    if (!isConfigured) {
      return const IndianMealResult(
        success: false,
        totals: IndianMealTotals(
          totalCaloriesKcal: 0,
          totalProteinG: 0,
          totalCarbsG: 0,
          totalFatG: 0,
        ),
        items: [],
        error: 'Gemini API Key is not configured. Get a free key at aistudio.google.com',
      );
    }

    try {
      final base64Image = base64Encode(imageBytes);
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=${apiKey.trim()}',
      );

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'inline_data': {
                        'mime_type': 'image/jpeg',
                        'data': base64Image,
                      }
                    },
                    {
                      'text': '''
Analyze this meal image for a health and nutrition tracking application.
Identify all food items (especially Indian dishes like Omelette, Roti, Dal, Paneer, Dosa, Rice, Sabzi, Biryani, Curry, etc.), estimate portions, calories, and macronutrients.

STRICT REQUIREMENT: Respond ONLY with a valid JSON object adhering exactly to this structure:
{
  "success": true,
  "scale_reference": "plate",
  "disclaimer": "Nutritional estimates based on visual recognition",
  "meal_totals": {
    "total_calories_kcal": 350.0,
    "total_protein_g": 18.0,
    "total_carbs_g": 10.0,
    "total_fat_g": 25.0
  },
  "items": [
    {
      "name": "Masala Omelette",
      "calories_kcal": 350.0,
      "portion_grams": 150.0,
      "category": "Indian Breakfast",
      "protein_g": 18.0,
      "carb_g": 10.0,
      "fat_g": 25.0,
      "notes": "Spiced egg omelette cooked with onions and green chillies",
      "confidence": 0.95
    }
  ]
}
'''
                    }
                  ]
                }
              ],
              'generationConfig': {
                'responseMimeType': 'application/json',
                'temperature': 0.2,
              }
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final firstCandidate = candidates[0] as Map<String, dynamic>;
          final content = firstCandidate['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text']?.toString() ?? '';
            final jsonMatch = jsonDecode(text) as Map<String, dynamic>;
            jsonMatch['success'] = true;
            return IndianMealResult.fromMap(jsonMatch);
          }
        }
      } else {
        final errJson = jsonDecode(response.body);
        final msg = errJson['error']?['message'] ?? response.body;
        return IndianMealResult(
          success: false,
          totals: const IndianMealTotals(
            totalCaloriesKcal: 0,
            totalProteinG: 0,
            totalCarbsG: 0,
            totalFatG: 0,
          ),
          items: const [],
          error: 'Gemini API Error (${response.statusCode}): $msg',
        );
      }
    } catch (e) {
      return IndianMealResult(
        success: false,
        totals: const IndianMealTotals(
          totalCaloriesKcal: 0,
          totalProteinG: 0,
          totalCarbsG: 0,
          totalFatG: 0,
        ),
        items: const [],
        error: 'Gemini scan failed: $e',
      );
    }

    return const IndianMealResult(
      success: false,
      totals: IndianMealTotals(
        totalCaloriesKcal: 0,
        totalProteinG: 0,
        totalCarbsG: 0,
        totalFatG: 0,
      ),
      items: [],
      error: 'Could not parse Gemini nutrition response.',
    );
  }
}
