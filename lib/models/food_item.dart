enum FoodCategory {
  breakfast,
  bread,
  curry,
  rice,
  snack,
  dessert,
  beverage,
  protein,
  side,
  salad,
}

extension FoodCategoryX on FoodCategory {
  String get storageValue => switch (this) {
    FoodCategory.breakfast => 'breakfast',
    FoodCategory.bread => 'bread',
    FoodCategory.curry => 'curry',
    FoodCategory.rice => 'rice',
    FoodCategory.snack => 'snack',
    FoodCategory.dessert => 'dessert',
    FoodCategory.beverage => 'beverage',
    FoodCategory.protein => 'protein',
    FoodCategory.side => 'side',
    FoodCategory.salad => 'salad',
  };

  String get label => switch (this) {
    FoodCategory.breakfast => 'Breakfast',
    FoodCategory.bread => 'Bread',
    FoodCategory.curry => 'Curry',
    FoodCategory.rice => 'Rice',
    FoodCategory.snack => 'Snack',
    FoodCategory.dessert => 'Dessert',
    FoodCategory.beverage => 'Beverage',
    FoodCategory.protein => 'Protein',
    FoodCategory.side => 'Side',
    FoodCategory.salad => 'Salad',
  };

  static FoodCategory fromStorage(String value) {
    return switch (value.trim().toLowerCase()) {
      'breakfast' => FoodCategory.breakfast,
      'bread' => FoodCategory.bread,
      'curry' => FoodCategory.curry,
      'rice' => FoodCategory.rice,
      'snack' => FoodCategory.snack,
      'dessert' => FoodCategory.dessert,
      'beverage' => FoodCategory.beverage,
      'protein' => FoodCategory.protein,
      'side' => FoodCategory.side,
      'salad' => FoodCategory.salad,
      _ => FoodCategory.snack,
    };
  }
}

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.serving,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    this.cuisine = 'Indian',
    this.region,
    this.fiberGrams = 0,
    this.sugarGrams = 0,
    this.sodiumMilligrams = 0,
    this.isIndian = true,
    this.isVegetarian = true,
    this.isVegan = false,
    this.tags = const [],
    this.aliases = const [],
  }) : assert(id != ''),
       assert(name != '');

  final String id;
  final String name;
  final String cuisine;
  final String? region;
  final FoodCategory category;
  final String serving;
  final int calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double fiberGrams;
  final double sugarGrams;
  final int sodiumMilligrams;
  final bool isIndian;
  final bool isVegetarian;
  final bool isVegan;
  final List<String> tags;
  final List<String> aliases;

  factory FoodItem.fromMap(Map<String, dynamic> data) {
    return FoodItem(
      id: (data['id'] as String?)?.trim() ?? '',
      name: (data['name'] as String?)?.trim() ?? '',
      cuisine: (data['cuisine'] as String?)?.trim() ?? 'Indian',
      region: (data['region'] as String?)?.trim(),
      category: FoodCategoryX.fromStorage(
        (data['category'] as String?) ?? 'snack',
      ),
      serving: (data['serving'] as String?)?.trim() ?? '1 serving',
      calories: _asInt(data['calories']),
      proteinGrams: _asDouble(data['proteinGrams']),
      carbsGrams: _asDouble(data['carbsGrams']),
      fatGrams: _asDouble(data['fatGrams']),
      fiberGrams: _asDouble(data['fiberGrams']),
      sugarGrams: _asDouble(data['sugarGrams']),
      sodiumMilligrams: _asInt(data['sodiumMilligrams']),
      isIndian: _asBool(data['isIndian'], fallback: true),
      isVegetarian: _asBool(data['isVegetarian'], fallback: true),
      isVegan: _asBool(data['isVegan']),
      tags: _asStringList(data['tags']),
      aliases: _asStringList(data['aliases']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cuisine': cuisine,
      if (region != null && region!.isNotEmpty) 'region': region,
      'category': category.storageValue,
      'serving': serving,
      'calories': calories,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
      'fiberGrams': fiberGrams,
      'sugarGrams': sugarGrams,
      'sodiumMilligrams': sodiumMilligrams,
      'isIndian': isIndian,
      'isVegetarian': isVegetarian,
      'isVegan': isVegan,
      'tags': tags,
      'aliases': aliases,
    };
  }

  bool matchesQuery(String query) {
    final normalizedQuery = normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final haystack = normalizeSearchText(
      [
        name,
        cuisine,
        region,
        category.label,
        serving,
        ...tags,
        ...aliases,
      ].whereType<String>().join(' '),
    );
    final terms = normalizedQuery.split(' ');
    return terms.every(haystack.contains);
  }

  static String normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _asInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  static bool _asBool(Object? value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    return fallback;
  }

  static List<String> _asStringList(Object? value) {
    if (value is Iterable) {
      return value
          .whereType<String>()
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}
