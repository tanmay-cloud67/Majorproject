import '../data/food_catalog_seed.dart';
import '../models/food_item.dart';

class FoodCatalogService {
  FoodCatalogService({List<FoodItem>? catalog})
    : _catalog = List<FoodItem>.unmodifiable(catalog ?? foodCatalogSeed);

  final List<FoodItem> _catalog;

  List<FoodItem> get foods => _catalog;

  int get totalFoods => _catalog.length;

  int get indianFoodCount => _catalog.where((food) => food.isIndian).length;

  double get indianFoodRatio {
    if (_catalog.isEmpty) {
      return 0;
    }
    return indianFoodCount / _catalog.length;
  }

  Map<FoodCategory, int> categoryCounts() {
    final counts = <FoodCategory, int>{};
    for (final food in _catalog) {
      counts.update(food.category, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  List<FoodItem> search({
    String query = '',
    FoodCategory? category,
    bool indianOnly = false,
    bool vegetarianOnly = false,
    bool veganOnly = false,
    String? region,
    int limit = 30,
  }) {
    final normalizedQuery = FoodItem.normalizeSearchText(query);
    final normalizedRegion = FoodItem.normalizeSearchText(region ?? '');

    final matches = _catalog.where((food) {
      if (category != null && food.category != category) {
        return false;
      }
      if (indianOnly && !food.isIndian) {
        return false;
      }
      if (vegetarianOnly && !food.isVegetarian) {
        return false;
      }
      if (veganOnly && !food.isVegan) {
        return false;
      }
      if (normalizedRegion.isNotEmpty) {
        final itemRegion = FoodItem.normalizeSearchText(food.region ?? '');
        if (!itemRegion.contains(normalizedRegion)) {
          return false;
        }
      }
      return food.matchesQuery(normalizedQuery);
    }).toList(growable: false);

    matches.sort(
      (left, right) => _compareFoods(
        left: left,
        right: right,
        normalizedQuery: normalizedQuery,
      ),
    );

    if (limit <= 0 || matches.length <= limit) {
      return matches;
    }
    return matches.take(limit).toList(growable: false);
  }

  List<FoodItem> featuredIndianFoods({int limit = 20}) {
    return search(indianOnly: true, limit: limit);
  }

  int _compareFoods({
    required FoodItem left,
    required FoodItem right,
    required String normalizedQuery,
  }) {
    final scoreDifference =
        _scoreFood(right, normalizedQuery) - _scoreFood(left, normalizedQuery);
    if (scoreDifference != 0) {
      return scoreDifference;
    }

    final calorieDifference = left.calories.compareTo(right.calories);
    if (calorieDifference != 0) {
      return calorieDifference;
    }

    return left.name.compareTo(right.name);
  }

  int _scoreFood(FoodItem food, String normalizedQuery) {
    var score = food.isIndian ? 15 : 0;
    if (normalizedQuery.isEmpty) {
      return score;
    }

    final normalizedName = FoodItem.normalizeSearchText(food.name);
    if (normalizedName == normalizedQuery) {
      score += 100;
    } else if (normalizedName.startsWith(normalizedQuery)) {
      score += 70;
    } else if (food.matchesQuery(normalizedQuery)) {
      score += 40;
    }

    final aliasHit = food.aliases.any(
      (alias) => FoodItem.normalizeSearchText(alias).contains(normalizedQuery),
    );
    if (aliasHit) {
      score += 20;
    }

    return score;
  }
}
