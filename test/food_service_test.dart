import 'package:flutter_test/flutter_test.dart';
import 'package:health/services/food_service.dart';

void main() {
  group('FoodService.searchCatalog', () {
    final service = FoodService();

    test('maps chicken biryani queries back to the supported biryani item', () {
      final results = service.searchCatalog('Chicken Biryani');

      expect(results, isNotEmpty);
      expect(results.first.name, 'Biryani');
    });

    test('maps milk tea queries to chai before generic tea', () {
      final results = service.searchCatalog('milk tea');

      expect(results, isNotEmpty);
      expect(results.first.name, 'Chai');
    });

    test('maps coffee mug queries to the coffee item', () {
      final results = service.searchCatalog('coffee mug');

      expect(results, isNotEmpty);
      expect(results.first.name, 'Coffee');
    });

    test('maps plantain queries to banana', () {
      final results = service.searchCatalog('plantain');

      expect(results, isNotEmpty);
      expect(results.first.name, 'Banana');
    });

    test('surfaces imported Theseus fallback foods for broader queries', () {
      final results = service.searchCatalog('fish and chips');

      expect(results, isNotEmpty);
      expect(results.first.name, 'Fish And Chips');
      expect(results.first.tags, contains('theseus_fallback'));
    });
  });

  group('FoodService.buildGeminiResultFromPayload', () {
    final service = FoodService();

    test('maps Gemini dish names into the trusted food catalog', () {
      final result = service.buildGeminiResultFromPayload({
        'foodName': 'Chicken Biryani',
        'confidence': 0.88,
        'estimatedCalories': 640,
        'summary': 'Detected a rice-based chicken dish.',
        'candidates': [
          {
            'name': 'Chicken Biryani',
            'confidence': 0.88,
            'estimatedCalories': 640,
          },
          {'name': 'Pulao', 'confidence': 0.32, 'estimatedCalories': 420},
        ],
      });

      expect(result.foodName, 'Biryani');
      expect(result.catalogMatched, isTrue);
      expect(result.primaryExpert, FoodExpertType.hybrid);
      expect(
        result.mergeReason,
        contains('Detected a rice-based chicken dish'),
      );
    });

    test('keeps Gemini calories when no local catalog match exists', () {
      final result = service.buildGeminiResultFromPayload({
        'foodName': 'Dragon Fruit Bowl',
        'confidence': 0.71,
        'estimatedCalories': 210,
        'candidates': [
          {
            'name': 'Dragon Fruit Bowl',
            'confidence': 0.71,
            'estimatedCalories': 210,
          },
        ],
      });

      expect(result.foodName, 'Dragon Fruit Bowl');
      expect(result.catalogMatched, isFalse);
      expect(result.calories, 210);
      expect(result.isLowConfidence, isTrue);
    });

    test('maps Gemini plantain responses back to banana', () {
      final result = service.buildGeminiResultFromPayload({
        'foodName': 'Plantain',
        'confidence': 0.64,
        'estimatedCalories': 105,
        'candidates': [
          {'name': 'Plantain', 'confidence': 0.64, 'estimatedCalories': 105},
        ],
      });

      expect(result.foodName, 'Banana');
      expect(result.catalogMatched, isTrue);
    });

    test('marks imported broad-food matches as fallback catalog results', () {
      final result = service.buildGeminiResultFromPayload({
        'foodName': 'Artichoke Bottoms In Olive Oil',
        'confidence': 0.66,
        'estimatedCalories': 209,
        'candidates': [
          {
            'name': 'Artichoke Bottoms In Olive Oil',
            'confidence': 0.66,
            'estimatedCalories': 209,
          },
        ],
      });

      expect(result.foodName, 'Artichoke Bottoms In Olive Oil');
      expect(result.catalogMatched, isTrue);
      expect(result.fallbackCatalogMatch, isTrue);
    });
  });

  group('FoodService.buildFoodVisionResultFromPayload', () {
    final service = FoodService();

    test('maps backend labels into trusted app foods when possible', () {
      final result = service.buildFoodVisionResultFromPayload({
        'predictions': [
          {
            'label': 'Butter Chicken',
            'confidence': 97.2,
            'nutrition': {'cal': 230},
          },
          {
            'label': 'Chicken Curry',
            'confidence': 51.4,
            'nutrition': {'cal': 180},
          },
        ],
        'image_size': [224, 224],
      });

      expect(result.foodName, 'Butter Chicken');
      expect(result.catalogMatched, isTrue);
      expect(result.primaryExpert, FoodExpertType.hybrid);
      expect(result.mergeReason, contains('Food Vision AI'));
    });

    test('keeps backend nutrition calories for fallback foods', () {
      final result = service.buildFoodVisionResultFromPayload({
        'predictions': [
          {
            'label': 'Artichoke Bottoms In Olive Oil',
            'confidence': 88.4,
            'nutrition': {'cal': 209},
          },
        ],
      });

      expect(result.foodName, 'Artichoke Bottoms In Olive Oil');
      expect(result.catalogMatched, isTrue);
      expect(result.fallbackCatalogMatch, isTrue);
      expect(result.calories, 209);
    });
  });

  group('FoodService.selectBestAnalysisResult', () {
    test('prefers a strong local banana match over an unmatched API guess', () {
      const apiResult = FoodAnalysisResult(
        foodName: 'Yellow Fruit Dessert',
        calories: 180,
        rawCategory: 'Yellow Fruit Dessert',
        catalogMatched: false,
        primaryExpert: FoodExpertType.hybrid,
        mergeReason: 'Gemini guessed a dessert.',
        confidence: 0.51,
      );
      const localResult = FoodAnalysisResult(
        foodName: 'Banana',
        calories: 105,
        rawCategory: 'banana',
        catalogMatched: true,
        primaryExpert: FoodExpertType.basicFood,
        mergeReason: 'Local banana match.',
        confidence: 0.72,
      );

      final selected = FoodService.selectBestAnalysisResult(
        apiResult: apiResult,
        localResult: localResult,
      );

      expect(selected.foodName, 'Banana');
      expect(selected.primaryExpert, FoodExpertType.basicFood);
    });

    test('prefers a trusted local match over a broad fallback API match', () {
      const apiResult = FoodAnalysisResult(
        foodName: 'Macarons',
        calories: 460,
        rawCategory: 'Macarons',
        catalogMatched: true,
        fallbackCatalogMatch: true,
        primaryExpert: FoodExpertType.hybrid,
        mergeReason: 'Gemini matched the fallback catalog.',
        confidence: 0.62,
      );
      const localResult = FoodAnalysisResult(
        foodName: 'Banana',
        calories: 105,
        rawCategory: 'banana',
        catalogMatched: true,
        primaryExpert: FoodExpertType.basicFood,
        mergeReason: 'Local banana match.',
        confidence: 0.54,
      );

      final selected = FoodService.selectBestAnalysisResult(
        apiResult: apiResult,
        localResult: localResult,
      );

      expect(selected.foodName, 'Banana');
      expect(selected.primaryExpert, FoodExpertType.basicFood);
    });
  });
}
