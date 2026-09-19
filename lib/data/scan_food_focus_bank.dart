import '../models/food_item.dart';

/// Curated focus names and aliases distilled from Indian_Food_List_500.pdf.
///
/// We only keep entries that safely map onto foods already supported by the
/// current scanner catalog so the hybrid ranking can get smarter without
/// inventing duplicate meal types.
const Map<String, List<String>> scanFoodSearchAliases = {
  'veg biryani': <String>['biryani'],
  'vegetable biryani': <String>['biryani'],
  'chicken biryani': <String>['biryani'],
  'mutton biryani': <String>['biryani'],
  'egg biryani': <String>['biryani'],
  'dosa': <String>['plain dosa', 'masala dosa'],
  'set dosa': <String>['plain dosa'],
  'neer dosa': <String>['plain dosa'],
  'chapathi': <String>['chapati'],
  'chapatti': <String>['chapati'],
  'phulka': <String>['roti', 'chapati'],
  'plain rice': <String>['rice'],
  'steamed rice': <String>['rice'],
  'white rice': <String>['rice'],
  'bread slice': <String>['bread'],
  'brown bread': <String>['bread'],
  'toast': <String>['bread'],
  'plantain': <String>['banana'],
  'ripe banana': <String>['banana'],
  'banana fruit': <String>['banana'],
  'boiled egg': <String>['egg'],
  'boiled eggs': <String>['egg'],
  'fried egg': <String>['egg'],
  'fried eggs': <String>['egg'],
  'poached egg': <String>['egg'],
  'poached eggs': <String>['egg'],
  'scrambled egg': <String>['egg'],
  'scrambled eggs': <String>['egg'],
  'omelet': <String>['omelette'],
  'milk tea': <String>['chai'],
  'masala chai': <String>['chai'],
  'masala tea': <String>['chai'],
  'black tea': <String>['tea'],
  'green tea': <String>['tea'],
  'ginger tea': <String>['tea'],
  'cardamom tea': <String>['tea'],
  'filter coffee': <String>['coffee'],
  'black coffee': <String>['coffee'],
  'full cream milk': <String>['milk'],
  'toned milk': <String>['milk'],
  'skimmed milk': <String>['milk'],
  // These help bridge recognizable MobileNet labels back to food items.
  'coffee mug': <String>['coffee'],
  'coffeepot': <String>['coffee'],
  'teapot': <String>['tea'],
  'milk can': <String>['milk'],
  'eggnog': <String>['milk', 'egg'],
};

const Set<String> scanFoodFocusNames = {
  'banana',
  'orange',
  'lemon',
  'pineapple',
  'strawberry',
  'pomegranate',
  'custard apple',
  'apple',
  'mango',
  'papaya',
  'watermelon',
  'egg',
  'omelette',
  'rice',
  'bread',
  'milk',
  'tea',
  'chai',
  'coffee',
  'idli',
  'plain dosa',
  'masala dosa',
  'uttapam',
  'upma',
  'ven pongal',
  'poha',
  'jeera rice',
  'lemon rice',
  'curd rice',
  'roti',
  'chapati',
  'naan',
  'paratha',
  'khichdi',
  'biryani',
  'dal tadka',
  'dal makhani',
  'palak paneer',
  'paneer butter masala',
  'kadai paneer',
  'aloo matar',
  'aloo gobi',
  'aloo methi',
  'bhindi masala',
  'butter chicken',
  'chicken tikka masala',
  'samosa',
  'kachori',
  'aloo tikki',
  'pani puri',
  'pav bhaji',
  'jalebi',
  'gulab jamun',
  'rasgulla',
  'rabri',
  'basundi',
  'shrikhand',
  'mysore pak',
  'modak',
  'boondi',
  'chikki',
};

List<String> expandScanFoodQueries(String query) {
  final normalizedQuery = FoodItem.normalizeSearchText(query);
  if (normalizedQuery.isEmpty) {
    return const [];
  }

  final expanded = <String>[normalizedQuery];
  for (final entry in scanFoodSearchAliases.entries) {
    if (normalizedQuery == entry.key ||
        normalizedQuery.contains(entry.key) ||
        entry.key.contains(normalizedQuery)) {
      for (final alias in entry.value) {
        if (!expanded.contains(alias)) {
          expanded.add(alias);
        }
      }
    }
  }

  return List<String>.unmodifiable(expanded);
}

bool isScanFocusFoodName(String value) {
  return scanFoodFocusNames.contains(FoodItem.normalizeSearchText(value));
}
