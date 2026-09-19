import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../models/food_detection_result.dart';
import 'food_detector.dart';

class GeminiFoodDetector implements FoodDetector {
  GeminiFoodDetector({
    String? apiKey,
    String? model,
    http.Client? client,
  })  : _apiKey = apiKey ?? _defaultApiKey,
        _model = model ?? _defaultModel,
        _client = client ?? http.Client();

  static const String _defaultApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyBSR3dGWWvSJWo488vVX565d0_1jPHFc1k',
  );
  static const String _defaultModel = 'gemini-2.5-flash';

  final String _apiKey;
  final String _model;
  final http.Client _client;

  @override
  bool get isAvailable => _apiKey.trim().isNotEmpty;

  @override
  Future<FoodDetectionResult> detectFood(File imageFile) async {
    if (!isAvailable) {
      throw Exception('Gemini API key is not configured.');
    }

    if (!await imageFile.exists()) {
      throw Exception('Captured image file does not exist.');
    }

    final imageBytes = await imageFile.readAsBytes();
    final mimeType = _guessMimeType(imageFile.path);
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
    );

    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text': '''
Identify the food item shown in this image for a nutrition tracking application.
Respond STRICTLY with a valid JSON object adhering to this schema:
{
  "foodName": "Name of the dish or food item",
  "confidence": 0.92,
  "estimatedCalories": 350,
  "proteinGrams": 18.5,
  "carbsGrams": 42.0,
  "fatGrams": 12.0,
  "servingSize": "1 bowl (approx 250g)",
  "summary": "Brief 1-sentence description of the meal.",
  "candidates": [
    {
      "name": "Alternative dish name",
      "confidence": 0.45,
      "estimatedCalories": 310
    }
  ]
}

Rules:
1. Prefer specific, common food or dish names (especially Indian / Asian / global cuisines).
2. Calories and macros should reflect the visible portion size.
3. Keep confidence between 0.0 and 1.0.
4. Provide up to 3 candidate alternatives.
5. Return ONLY the raw JSON object without markdown formatting or code blocks.
''',
              },
              {
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Encode(imageBytes),
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini API failed with status ${response.statusCode}');
    }

    final responseBody =
        jsonDecode(response.body) as Map<String, dynamic>? ?? const {};
    final generatedText = _extractGeminiText(responseBody);
    if (generatedText == null || generatedText.trim().isEmpty) {
      throw Exception('Gemini did not return text content.');
    }

    final payload = _parseJsonPayload(generatedText);
    return _buildResultFromPayload(payload);
  }

  FoodDetectionResult _buildResultFromPayload(Map<String, dynamic> payload) {
    final foodName = (payload['foodName'] as String?)?.trim() ?? 'Unknown Food';
    final confidence = _parseDouble(payload['confidence'], fallback: 0.80);
    final calories = _parseDouble(payload['estimatedCalories'], fallback: 200.0);
    final protein = _parseDouble(payload['proteinGrams']);
    final carbs = _parseDouble(payload['carbsGrams']);
    final fat = _parseDouble(payload['fatGrams']);
    final serving = (payload['servingSize'] as String?)?.trim() ?? '1 serving';
    final summary = (payload['summary'] as String?)?.trim() ?? '';

    final rawCandidates = payload['candidates'];
    final alternatives = <FoodDetectionResult>[];
    if (rawCandidates is List) {
      for (final item in rawCandidates.whereType<Map>()) {
        final altName = (item['name'] as String?)?.trim();
        if (altName != null && altName.isNotEmpty && altName != foodName) {
          alternatives.add(
            FoodDetectionResult(
              foodName: altName,
              calories: _parseDouble(item['estimatedCalories'], fallback: calories),
              confidence: _parseDouble(item['confidence'], fallback: 0.50),
              source: FoodDetectionSource.gemini,
            ),
          );
        }
      }
    }

    return FoodDetectionResult(
      foodName: foodName,
      calories: calories,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
      servingSize: serving,
      confidence: confidence,
      summary: summary,
      source: FoodDetectionSource.gemini,
      alternatives: alternatives,
    );
  }

  static String? _extractGeminiText(Map<String, dynamic> responseBody) {
    final candidates = responseBody['candidates'];
    if (candidates is! List) return null;
    for (final candidate in candidates.whereType<Map>()) {
      final content = candidate['content'];
      if (content is! Map) continue;
      final parts = content['parts'];
      if (parts is! List) continue;
      for (final part in parts.whereType<Map>()) {
        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  static Map<String, dynamic> _parseJsonPayload(String text) {
    final trimmed = text.trim();
    try {
      return Map<String, dynamic>.from(jsonDecode(trimmed) as Map);
    } catch (_) {
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start != -1 && end > start) {
        return Map<String, dynamic>.from(
          jsonDecode(trimmed.substring(start, end + 1)) as Map,
        );
      }
      throw Exception('Could not parse Gemini JSON payload.');
    }
  }

  static double _parseDouble(Object? val, {double fallback = 0.0}) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  static String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
