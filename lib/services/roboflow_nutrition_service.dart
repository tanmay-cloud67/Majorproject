import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/indian_meal_result.dart';

import 'gemini_nutrition_service.dart';

class RoboflowNutritionService {
  RoboflowNutritionService._();

  static final RoboflowNutritionService instance = RoboflowNutritionService._();

  // Configurable backend URL. Defaults to local Express proxy backend or Cloud Run FastAPI endpoint.
  static String backendUrl = 'http://127.0.0.1:3000/analyze-meal';

  // Direct Roboflow Cloud Workflow Configuration
  static String roboflowApiKey = 'KAJV9N9tGU8m19OifaQm';
  static const String workspaceName = 'vinays-workspace-qo2yi';
  static const String workflowId = 'indian-meal-nutrition-json-analyzer-1785338666664';

  /// Analyzes image bytes (supports Web, Android, iOS, Windows)
  Future<IndianMealResult> analyzeMealBytes(
    Uint8List imageBytes, {
    String filename = 'meal.jpg',
    double confidenceThreshold = 0.5,
  }) async {
    // 0. If Gemini is configured, use Gemini Flash (1,500 FREE scans/day)
    if (GeminiNutritionService.instance.isConfigured) {
      return await GeminiNutritionService.instance.analyzeMealBytes(
        imageBytes,
        filename: filename,
        confidenceThreshold: confidenceThreshold,
      );
    }

    // 1. Try Direct Roboflow Cloud API call
    try {
      final base64Image = base64Encode(imageBytes);
      final directUri = Uri.parse(
        'https://detect.roboflow.com/infer/workflows/$workspaceName/$workflowId',
      );

      final directResponse = await http
          .post(
            directUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'api_key': roboflowApiKey,
              'inputs': {
                'image': {
                  'type': 'base64',
                  'value': base64Image,
                }
              }
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (directResponse.statusCode == 200) {
        final decoded = jsonDecode(directResponse.body);
        Map<String, dynamic>? outputMap;

        if (decoded is Map<String, dynamic>) {
          if (decoded['outputs'] is List && (decoded['outputs'] as List).isNotEmpty) {
            outputMap = Map<String, dynamic>.from((decoded['outputs'] as List)[0] as Map);
          } else {
            outputMap = decoded;
          }
        } else if (decoded is List && decoded.isNotEmpty) {
          outputMap = Map<String, dynamic>.from(decoded[0] as Map);
        }

        if (outputMap != null && outputMap['json_parse_error'] != true) {
          outputMap['success'] = true;
          final result = IndianMealResult.fromMap(outputMap);

          if (result.items.isNotEmpty) {
            final filteredItems = result.items
                .where((item) => (item.confidence ?? 1.0) >= confidenceThreshold)
                .toList();

            if (filteredItems.length != result.items.length) {
              return IndianMealResult(
                success: result.success,
                totals: result.totals,
                items: filteredItems,
                scaleReference: result.scaleReference,
                referenceObject: result.referenceObject,
                disclaimer: result.disclaimer,
                error: result.error,
              );
            }
          }
          return result;
        }
      } else if (directResponse.statusCode == 402) {
        // If Roboflow credit cap reached, try Gemini if key exists
        if (GeminiNutritionService.instance.isConfigured) {
          return await GeminiNutritionService.instance.analyzeMealBytes(
            imageBytes,
            filename: filename,
            confidenceThreshold: confidenceThreshold,
          );
        }
        return const IndianMealResult(
          success: false,
          totals: IndianMealTotals(totalCaloriesKcal: 0, totalProteinG: 0, totalCarbsG: 0, totalFatG: 0),
          items: [],
          error: 'Roboflow Credit Cap Exceeded (402).\nGet a free Gemini API key (1,500 free scans/day) at aistudio.google.com or top up Roboflow credits.',
        );
      } else if (directResponse.statusCode == 401 || directResponse.statusCode == 403) {
        return const IndianMealResult(
          success: false,
          totals: IndianMealTotals(totalCaloriesKcal: 0, totalProteinG: 0, totalCarbsG: 0, totalFatG: 0),
          items: [],
          error: 'Roboflow API Authentication Failed.\nPlease verify your Roboflow API key.',
        );
      }
    } catch (e) {
      // Direct cloud call failed due to network exception or timeout — try local fallback if configured
    }

    // 2. Fallback to Local Node Backend Server if direct API call did not succeed
    final candidateUrls = [
      backendUrl,
      if (backendUrl.contains('127.0.0.1'))
        backendUrl.replaceFirst('127.0.0.1', '10.0.2.2'),
      if (backendUrl.contains('localhost'))
        backendUrl.replaceFirst('localhost', '10.0.2.2'),
    ].toSet().toList();

    Object? lastError;

    for (final targetUrl in candidateUrls) {
      try {
        final uri = Uri.parse(targetUrl);
        final request = http.MultipartRequest('POST', uri);

        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: filename,
          ),
        );

        final streamedResponse =
            await request.send().timeout(const Duration(seconds: 25));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final result = IndianMealResult.fromMap(data);

          if (result.items.isNotEmpty) {
            final filteredItems = result.items
                .where((item) => (item.confidence ?? 1.0) >= confidenceThreshold)
                .toList();

            if (filteredItems.length != result.items.length) {
              return IndianMealResult(
                success: result.success,
                totals: result.totals,
                items: filteredItems,
                scaleReference: result.scaleReference,
                referenceObject: result.referenceObject,
                disclaimer: result.disclaimer,
                error: result.error,
              );
            }
          }

          return result;
        } else {
          return IndianMealResult(
            success: false,
            totals: const IndianMealTotals(
              totalCaloriesKcal: 0,
              totalProteinG: 0,
              totalCarbsG: 0,
              totalFatG: 0,
            ),
            items: const [],
            error: 'Server Error (${response.statusCode}): ${response.body}',
          );
        }
      } catch (e) {
        lastError = e;
      }
    }

    return IndianMealResult(
      success: false,
      totals: const IndianMealTotals(
        totalCaloriesKcal: 0,
        totalProteinG: 0,
        totalCarbsG: 0,
        totalFatG: 0,
      ),
      items: const [],
      error:
          'Analysis failed. Please check internet connection.\nDetails: $lastError',
    );
  }
}
