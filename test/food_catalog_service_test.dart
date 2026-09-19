import 'package:flutter_test/flutter_test.dart';
import 'package:health/models/food_item.dart';
import 'package:health/services/food_catalog_service.dart';

void main() {
  group('FoodCatalogService', () {
    final service = FoodCatalogService();

    test('ships with a large India-first catalog', () {
      expect(service.totalFoods, greaterThanOrEqualTo(80));
      expect(service.indianFoodCount, greaterThanOrEqualTo(65));
      expect(service.indianFoodRatio, greaterThan(0.75));
    });

    test('finds foods by text and regional aliases', () {
      final biryaniResults = service.search(query: 'biryani', limit: 200);
      expect(
        biryaniResults.map((food) => food.id),
        containsAll(<String>[
          'veg_biryani',
          'paneer_biryani',
          'hyderabadi_chicken_biryani',
        ]),
      );

      final golgappaResults = service.search(query: 'golgappa');
      expect(
        golgappaResults.any((food) => food.id == 'pani_puri'),
        isTrue,
      );
    });

    test('supports vegetarian and category filters', () {
      final vegetarianProteins = service.search(
        category: FoodCategory.protein,
        vegetarianOnly: true,
        indianOnly: true,
        limit: 20,
      );

      expect(vegetarianProteins, isNotEmpty);
      expect(
        vegetarianProteins.every((food) => food.isVegetarian),
        isTrue,
      );
      expect(
        vegetarianProteins.any((food) => food.id == 'paneer_tikka'),
        isTrue,
      );
      expect(
        vegetarianProteins.any((food) => food.id == 'butter_chicken'),
        isFalse,
      );
    });

    test('serializes and hydrates food entries', () {
      const original = FoodItem(
        id: 'test_food',
        name: 'Test Food',
        category: FoodCategory.snack,
        serving: '1 plate',
        calories: 123,
        proteinGrams: 4.5,
        carbsGrams: 11.0,
        fatGrams: 6.0,
        cuisine: 'Indian',
        region: 'Test Region',
        fiberGrams: 2.0,
        sugarGrams: 3.0,
        sodiumMilligrams: 99,
        isIndian: true,
        isVegetarian: true,
        isVegan: false,
        tags: ['demo'],
        aliases: ['sample'],
      );

      final roundTrip = FoodItem.fromMap(original.toMap());

      expect(roundTrip.id, original.id);
      expect(roundTrip.name, original.name);
      expect(roundTrip.category, original.category);
      expect(roundTrip.serving, original.serving);
      expect(roundTrip.calories, original.calories);
      expect(roundTrip.tags, original.tags);
      expect(roundTrip.aliases, original.aliases);
    });
  });
}
