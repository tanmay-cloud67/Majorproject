class IndianMealItem {
  const IndianMealItem({
    required this.name,
    required this.caloriesKcal,
    required this.portionGrams,
    required this.category,
    required this.notes,
    this.confidence,
    this.proteinG,
    this.carbG,
    this.fatG,
    this.box,
  });

  final String name;
  final double caloriesKcal;
  final double portionGrams;
  final String category;
  final String notes;
  final double? confidence;
  final double? proteinG;
  final double? carbG;
  final double? fatG;
  final List<double>? box;

  factory IndianMealItem.fromMap(Map<String, dynamic> data) {
    List<double>? parsedBox;
    if (data['box'] is List) {
      parsedBox = (data['box'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    final double kcal = (data['kcal'] ?? data['calories_kcal'] ?? data['calories'] ?? 0).toDouble();

    return IndianMealItem(
      name: (data['name'] ?? data['item_name'] ?? 'Food Item').toString(),
      caloriesKcal: kcal,
      portionGrams: (data['estimated_weight_g'] ?? data['portion'] ?? 100).toDouble(),
      category: (data['category'] ?? 'Indian Food').toString(),
      notes: (data['notes'] ?? '').toString(),
      confidence: (data['confidence'] as num?)?.toDouble(),
      proteinG: (data['protein_g'] ?? data['protein'] as num?)?.toDouble(),
      carbG: (data['carb_g'] ?? data['carbs_g'] ?? data['carbs'] as num?)?.toDouble(),
      fatG: (data['fat_g'] ?? data['fat'] as num?)?.toDouble(),
      box: parsedBox,
    );
  }
}

class IndianMealTotals {
  const IndianMealTotals({
    required this.totalCaloriesKcal,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
  });

  final double totalCaloriesKcal;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;

  factory IndianMealTotals.fromMap(Map<String, dynamic> data) {
    return IndianMealTotals(
      totalCaloriesKcal: (data['kcal'] ?? data['total_calories_kcal'] ?? data['calories'] ?? 0).toDouble(),
      totalProteinG: (data['protein_g'] ?? data['total_protein_g'] ?? data['protein'] ?? 0).toDouble(),
      totalCarbsG: (data['carb_g'] ?? data['total_carbs_g'] ?? data['carbs_g'] ?? 0).toDouble(),
      totalFatG: (data['fat_g'] ?? data['total_fat_g'] ?? data['fat'] ?? 0).toDouble(),
    );
  }
}

class IndianMealResult {
  const IndianMealResult({
    required this.success,
    required this.totals,
    required this.items,
    this.scaleReference,
    this.referenceObject,
    this.disclaimer,
    this.error,
  });

  final bool success;
  final IndianMealTotals totals;
  final List<IndianMealItem> items;
  final String? scaleReference;
  final String? referenceObject;
  final String? disclaimer;
  final String? error;

  factory IndianMealResult.fromMap(Map<String, dynamic> data) {
    final rawItems = data['items'] as List? ?? [];
    final itemsList = rawItems
        .whereType<Map>()
        .map((item) => IndianMealItem.fromMap(item.cast<String, dynamic>()))
        .toList();

    final Map<String, dynamic> totalsData = (data['totals'] ?? data['meal_totals']) as Map<String, dynamic>? ?? {};

    double calcKcal = (totalsData['kcal'] ?? totalsData['total_calories_kcal'] ?? totalsData['calories'] ?? 0).toDouble();
    double calcProtein = (totalsData['protein_g'] ?? totalsData['total_protein_g'] ?? totalsData['protein'] ?? 0).toDouble();
    double calcCarbs = (totalsData['carb_g'] ?? totalsData['total_carbs_g'] ?? totalsData['carbs_g'] ?? 0).toDouble();
    double calcFat = (totalsData['fat_g'] ?? totalsData['total_fat_g'] ?? totalsData['fat'] ?? 0).toDouble();

    if (calcKcal == 0 && itemsList.isNotEmpty) {
      for (final item in itemsList) {
        calcKcal += item.caloriesKcal;
        calcProtein += item.proteinG ?? 0;
        calcCarbs += item.carbG ?? 0;
        calcFat += item.fatG ?? 0;
      }
    }

    return IndianMealResult(
      success: data['success'] == true || itemsList.isNotEmpty,
      totals: IndianMealTotals(
        totalCaloriesKcal: calcKcal,
        totalProteinG: calcProtein,
        totalCarbsG: calcCarbs,
        totalFatG: calcFat,
      ),
      items: itemsList,
      scaleReference: data['scale_reference']?.toString(),
      referenceObject: data['reference_object']?.toString(),
      disclaimer: data['disclaimer']?.toString(),
      error: data['error']?.toString(),
    );
  }
}
