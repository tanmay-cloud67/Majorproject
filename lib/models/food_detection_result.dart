import '../models/food_item.dart';

enum FoodDetectionSource {
  cloudVision,
  gemini,
  localTflite,
  hybridEnsemble,
  manualSearch,
}

extension FoodDetectionSourceX on FoodDetectionSource {
  String get label => switch (this) {
    FoodDetectionSource.cloudVision => 'Cloud Vision AI',
    FoodDetectionSource.gemini => 'Gemini AI',
    FoodDetectionSource.localTflite => 'On-Device TFLite',
    FoodDetectionSource.hybridEnsemble => 'Hybrid Vision AI',
    FoodDetectionSource.manualSearch => 'Manual Selection',
  };
}

class FoodDetectionResult {
  const FoodDetectionResult({
    required this.foodName,
    required this.calories,
    required this.source,
    this.proteinGrams = 0.0,
    this.carbsGrams = 0.0,
    this.fatGrams = 0.0,
    this.servingSize = '1 serving',
    this.confidence = 0.85,
    this.summary = '',
    this.catalogMatch,
    this.alternatives = const [],
    this.isOffline = false,
  });

  final String foodName;
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final String servingSize;
  final double confidence;
  final String summary;
  final FoodDetectionSource source;
  final FoodItem? catalogMatch;
  final List<FoodDetectionResult> alternatives;
  final bool isOffline;

  bool get hasCatalogMatch => catalogMatch != null;

  String get displayName => catalogMatch?.name ?? foodName;

  double get displayCalories =>
      catalogMatch?.calories.toDouble() ?? calories;

  FoodDetectionResult copyWith({
    String? foodName,
    double? calories,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    String? servingSize,
    double? confidence,
    String? summary,
    FoodDetectionSource? source,
    FoodItem? catalogMatch,
    List<FoodDetectionResult>? alternatives,
    bool? isOffline,
  }) {
    return FoodDetectionResult(
      foodName: foodName ?? this.foodName,
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      servingSize: servingSize ?? this.servingSize,
      confidence: confidence ?? this.confidence,
      summary: summary ?? this.summary,
      source: source ?? this.source,
      catalogMatch: catalogMatch ?? this.catalogMatch,
      alternatives: alternatives ?? this.alternatives,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}
