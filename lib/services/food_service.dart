import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../data/scan_food_focus_bank.dart';
import '../data/scan_food_item_seed.dart';
import '../data/theseus_food_seed.dart';
import '../models/food_detection_result.dart';
import '../models/food_item.dart';
import 'detection/food_detector.dart';
import 'detection/gemini_food_detector.dart';
import 'food_catalog_service.dart';

enum FoodServiceErrorType {
  invalidResponse,
  localInferenceError,
  remoteApiError,
}

class FoodServiceException implements Exception {
  const FoodServiceException(this.type, this.message);

  final FoodServiceErrorType type;
  final String message;

  @override
  String toString() => 'FoodServiceException($type, $message)';
}

enum FoodExpertType { basicFood, dish, hybrid }

extension FoodExpertTypeX on FoodExpertType {
  String get label => switch (this) {
    FoodExpertType.basicFood => 'Basic Food AI',
    FoodExpertType.dish => 'Dish AI',
    FoodExpertType.hybrid => 'Vision AI',
  };
}

class FoodPrediction {
  const FoodPrediction({
    required this.label,
    required this.formattedName,
    required this.confidence,
    required this.expert,
    this.catalogMatch,
    this.fallbackCatalogMatch = false,
    this.fallbackCalories,
    this.mergeScore,
    this.supportingExperts = const [],
  });

  final String label;
  final String formattedName;
  final double confidence;
  final FoodExpertType expert;
  final FoodItem? catalogMatch;
  final bool fallbackCatalogMatch;
  final double? fallbackCalories;
  final double? mergeScore;
  final List<FoodExpertType> supportingExperts;

  String get displayName => catalogMatch?.name ?? formattedName;

  double get displayCalories =>
      catalogMatch?.calories.toDouble() ?? fallbackCalories ?? 250.0;

  bool get hasCatalogMatch => catalogMatch != null;

  bool get isTrustedCatalogMatch => hasCatalogMatch && !fallbackCatalogMatch;

  List<FoodExpertType> get resolvedSupportingExperts {
    if (supportingExperts.isNotEmpty) {
      return supportingExperts;
    }
    return <FoodExpertType>[expert];
  }

  bool get isHybridAgreement {
    final experts = resolvedSupportingExperts;
    return experts.contains(FoodExpertType.basicFood) &&
        experts.contains(FoodExpertType.dish);
  }

  FoodPrediction copyWith({
    String? label,
    String? formattedName,
    double? confidence,
    FoodExpertType? expert,
    FoodItem? catalogMatch,
    bool? fallbackCatalogMatch,
    double? fallbackCalories,
    double? mergeScore,
    List<FoodExpertType>? supportingExperts,
  }) {
    return FoodPrediction(
      label: label ?? this.label,
      formattedName: formattedName ?? this.formattedName,
      confidence: confidence ?? this.confidence,
      expert: expert ?? this.expert,
      catalogMatch: catalogMatch ?? this.catalogMatch,
      fallbackCatalogMatch:
          fallbackCatalogMatch ?? this.fallbackCatalogMatch,
      fallbackCalories: fallbackCalories ?? this.fallbackCalories,
      mergeScore: mergeScore ?? this.mergeScore,
      supportingExperts: supportingExperts ?? this.supportingExperts,
    );
  }
}

class FoodAnalysisResult {
  const FoodAnalysisResult({
    required this.foodName,
    required this.calories,
    required this.rawCategory,
    required this.catalogMatched,
    required this.primaryExpert,
    required this.mergeReason,
    this.fallbackCatalogMatch = false,
    this.confidence,
    this.alternatives = const [],
    this.basicExpertPredictions = const [],
    this.dishExpertPredictions = const [],
  });

  final String foodName;
  final double calories;
  final String rawCategory;
  final bool catalogMatched;
  final FoodExpertType primaryExpert;
  final String mergeReason;
  final bool fallbackCatalogMatch;
  final double? confidence;
  final List<FoodPrediction> alternatives;
  final List<FoodPrediction> basicExpertPredictions;
  final List<FoodPrediction> dishExpertPredictions;

  static const double lowConfidenceThreshold = 0.50;
  static const double rejectionConfidenceThreshold = 0.08;

  bool get isTrustedCatalogMatch => catalogMatched && !fallbackCatalogMatch;

  bool get isLowConfidence =>
      !catalogMatched ||
      confidence == null ||
      confidence! < lowConfidenceThreshold ||
      (fallbackCatalogMatch && confidence! < 0.60);

  bool get shouldReject =>
      confidence != null &&
      confidence! < 0.22 &&
      !catalogMatched &&
      !_strongBasicFoodNames.contains(FoodItem.normalizeSearchText(rawCategory));
}

class FoodService {
  FoodService({
    FoodCatalogService? dishCatalogService,
    FoodCatalogService? foodItemCatalogService,
    FoodCatalogService? broadCatalogService,
    http.Client? client,
    String? foodVisionApiBaseUrl,
    String? geminiApiKey,
    String? geminiModel,
    FoodDetector? cloudDetector,
  })  : _dishCatalogService = dishCatalogService ?? FoodCatalogService(),
        _foodItemCatalogService =
            foodItemCatalogService ??
            FoodCatalogService(catalog: scanFoodItemSeed),
        _broadCatalogService =
            broadCatalogService ?? FoodCatalogService(catalog: theseusFoodSeed),
        _client = client ?? http.Client(),
        _foodVisionApiBaseUrl =
            foodVisionApiBaseUrl ?? _defaultFoodVisionApiBaseUrl,
        _geminiApiKey = geminiApiKey ?? _defaultGeminiApiKey,
        _geminiModel = geminiModel ?? _defaultGeminiModel,
        _cloudDetector = cloudDetector ??
            GeminiFoodDetector(
              apiKey: geminiApiKey,
              model: geminiModel,
              client: client,
            );

  static final FoodService instance = FoodService();
  static const String _defaultFoodVisionApiBaseUrl = String.fromEnvironment(
    'FOOD_VISION_API_BASE_URL',
    defaultValue: '',
  );
  static const bool _useLocalModelFallback = bool.fromEnvironment(
    'ENABLE_LOCAL_FOOD_MODELS',
    defaultValue: true,
  );
  static const String _defaultGeminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyBSR3dGWWvSJWo488vVX565d0_1jPHFc1k',
  );
  static const String _defaultGeminiModel = 'gemini-2.5-flash';

  final FoodCatalogService _dishCatalogService;
  final FoodCatalogService _foodItemCatalogService;
  final FoodCatalogService _broadCatalogService;
  final http.Client _client;
  final String _foodVisionApiBaseUrl;
  final String _geminiApiKey;
  final String _geminiModel;
  final FoodDetector _cloudDetector;



  List<FoodItem> searchCatalog(String query) {
    final expandedQueries = expandScanFoodQueries(query);
    if (expandedQueries.isEmpty) {
      return const [];
    }

    final rankedById = <String, FoodItem>{};
    for (final searchQuery in expandedQueries.take(6)) {
      for (final item in <FoodItem>[
        ..._foodItemCatalogService.search(query: searchQuery, limit: 12),
        ..._dishCatalogService.search(query: searchQuery, limit: 20),
        ..._broadCatalogService.search(query: searchQuery, limit: 16),
      ]) {
        final current = rankedById[item.id];
        if (current == null ||
            _searchResultScore(item, expandedQueries) >
                _searchResultScore(current, expandedQueries)) {
          rankedById[item.id] = item;
        }
      }
    }

    final ranked = rankedById.values.toList(growable: false)
      ..sort(
        (left, right) => _searchResultScore(
          right,
          expandedQueries,
        ).compareTo(_searchResultScore(left, expandedQueries)),
      );
    return ranked.take(24).toList(growable: false);
  }

  static double _searchResultScore(
    FoodItem item,
    List<String> candidateQueries,
  ) {
    var maxScore = 0.0;
    for (final query in candidateQueries) {
      final normalizedQuery = FoodItem.normalizeSearchText(query);
      if (normalizedQuery.isEmpty) continue;
      final normalizedName = FoodItem.normalizeSearchText(item.name);
      if (normalizedName == normalizedQuery) {
        maxScore = math.max(maxScore, 1.0);
      } else if (normalizedName.startsWith(normalizedQuery)) {
        maxScore = math.max(maxScore, 0.85);
      } else if (normalizedName.contains(normalizedQuery)) {
        maxScore = math.max(maxScore, 0.70);
      } else {
        maxScore = math.max(maxScore, 0.50);
      }
    }
    return maxScore;
  }

  bool get _hasFoodVisionBackend =>
      _foodVisionApiBaseUrl.trim().isNotEmpty;

  bool get _hasGeminiApi => _geminiApiKey.trim().isNotEmpty;

  /// High-level detection entrypoint returning modular [FoodDetectionResult].
  Future<FoodDetectionResult> detectFood(String imagePath) async {
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw const FoodServiceException(
        FoodServiceErrorType.invalidResponse,
        'Image file does not exist.',
      );
    }

    // Primary: Cloud AI (Gemini)
    if (_cloudDetector.isAvailable) {
      try {
        final cloudResult = await _cloudDetector.detectFood(imageFile);
        final catalogMatch = _resolveCatalogCandidate(cloudResult.foodName);
        return cloudResult.copyWith(
          catalogMatch: catalogMatch,
          foodName: catalogMatch?.name ?? cloudResult.foodName,
        );
      } catch (_) {}
    }

    throw const FoodServiceException(
      FoodServiceErrorType.remoteApiError,
      'Food recognition is unavailable.',
    );
  }

  Future<FoodAnalysisResult> _analyzeWithFoodVisionBackend(
    String imagePath,
  ) async {
    if (!_hasFoodVisionBackend) {
      throw const FoodServiceException(
        FoodServiceErrorType.remoteApiError,
        'Food Vision AI backend URL is missing.',
      );
    }

    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw const FoodServiceException(
        FoodServiceErrorType.invalidResponse,
        'Could not read the captured food image.',
      );
    }

    final uri = _buildFoodVisionPredictUri();
    final request = http.MultipartRequest('POST', uri)
      ..fields['top_k'] = '3'
      ..files.add(await http.MultipartFile.fromPath('file', imagePath));

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FoodServiceException(
        FoodServiceErrorType.remoteApiError,
        'Food Vision AI backend failed (${response.statusCode}).',
      );
    }

    final payload = Map<String, dynamic>.from(
      jsonDecode(response.body) as Map<String, dynamic>? ?? const {},
    );
    return buildFoodVisionResultFromPayload(payload);
  }

  Future<FoodAnalysisResult> _analyzeWithGemini(String imagePath) async {
    if (_geminiApiKey.trim().isEmpty) {
      throw const FoodServiceException(
        FoodServiceErrorType.remoteApiError,
        'Gemini API key is missing.',
      );
    }

    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw const FoodServiceException(
        FoodServiceErrorType.invalidResponse,
        'Could not read the captured food image.',
      );
    }

    final imageBytes = await imageFile.readAsBytes();
    final mimeType = _guessMimeType(imagePath);
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_geminiModel:generateContent?key=$_geminiApiKey',
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
Identify the food in this image for a health-tracking app.
Return strict JSON only with this shape:
{
  "foodName": "string",
  "confidence": 0.0,
  "estimatedCalories": 0,
  "summary": "short string",
  "candidates": [
    {"name": "string", "confidence": 0.0, "estimatedCalories": 0}
  ]
}

Rules:
- Prefer a specific visible food or dish name.
- If uncertain, still provide the best 3 candidates.
- Confidence must be between 0 and 1.
- Calories should be for the visible serving in the image.
- Do not include markdown or code fences.
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
      throw FoodServiceException(
        FoodServiceErrorType.remoteApiError,
        'Gemini food recognition failed (${response.statusCode}).',
      );
    }

    final responseBody =
        jsonDecode(response.body) as Map<String, dynamic>? ?? const {};
    final generatedText = _extractGeminiText(responseBody);
    if (generatedText == null || generatedText.trim().isEmpty) {
      throw const FoodServiceException(
        FoodServiceErrorType.invalidResponse,
        'Gemini did not return a usable food result.',
      );
    }

    final payload = _decodeGeminiJson(generatedText);
    return buildGeminiResultFromPayload(payload);
  }

  FoodAnalysisResult buildFoodVisionResultFromPayload(
    Map<String, dynamic> payload,
  ) {
    final candidates = _buildFoodVisionPredictions(payload);
    if (candidates.isEmpty) {
      throw const FoodServiceException(
        FoodServiceErrorType.invalidResponse,
        'Could not detect food from the Food Vision AI response.',
      );
    }

    final primary = candidates.first;
    return FoodAnalysisResult(
      foodName: primary.displayName,
      calories: primary.displayCalories,
      rawCategory: primary.label,
      catalogMatched: primary.hasCatalogMatch,
      primaryExpert: FoodExpertType.hybrid,
      mergeReason: _buildFoodVisionReason(
        primary: primary,
        alternatives: candidates.skip(1),
      ),
      fallbackCatalogMatch: primary.fallbackCatalogMatch,
      confidence: primary.mergeScore ?? primary.confidence,
      alternatives: candidates.skip(1).take(4).toList(growable: false),
      basicExpertPredictions: const [],
      dishExpertPredictions: const [],
    );
  }

  FoodAnalysisResult buildGeminiResultFromPayload(
    Map<String, dynamic> payload,
  ) {
    final candidates = _buildGeminiPredictions(payload);
    if (candidates.isEmpty) {
      throw const FoodServiceException(
        FoodServiceErrorType.invalidResponse,
        'Could not detect food from the Gemini response.',
      );
    }

    final primary = candidates.first;
    final summary =
        (payload['summary'] as String?)?.trim() ??
        _buildGeminiReason(primary: primary, alternatives: candidates.skip(1));

    return FoodAnalysisResult(
      foodName: primary.displayName,
      calories: primary.displayCalories,
      rawCategory: primary.label,
      catalogMatched: primary.hasCatalogMatch,
      primaryExpert: FoodExpertType.hybrid,
      mergeReason: summary,
      fallbackCatalogMatch: primary.fallbackCatalogMatch,
      confidence: primary.mergeScore ?? primary.confidence,
      alternatives: candidates.skip(1).take(4).toList(growable: false),
      basicExpertPredictions: const [],
      dishExpertPredictions: const [],
    );
  }

  List<FoodPrediction> _buildFoodVisionPredictions(
    Map<String, dynamic> payload,
  ) {
    final predictions = payload['predictions'];
    if (predictions is! List) {
      return const [];
    }

    final byKey = <String, FoodPrediction>{};
    for (final candidate in predictions.whereType<Map>()) {
      final rawName = (candidate['label'] as String?)?.trim();
      if (rawName == null || rawName.isEmpty) {
        continue;
      }

      final confidence = _parseGeminiConfidence(candidate['confidence']);
      final nutrition =
          candidate['nutrition'] is Map
              ? Map<String, dynamic>.from(candidate['nutrition'] as Map)
              : const <String, dynamic>{};
      final estimatedCalories = _parseBackendCalories(nutrition);
      final catalogMatch = _resolveCatalogCandidate(rawName);
      final fallbackCatalogMatch = _isFallbackCatalogItem(catalogMatch);

      final prediction = FoodPrediction(
        label: rawName,
        formattedName: catalogMatch?.name ?? rawName,
        confidence: confidence,
        expert: FoodExpertType.hybrid,
        catalogMatch: catalogMatch,
        fallbackCatalogMatch: fallbackCatalogMatch,
        fallbackCalories: estimatedCalories > 0 ? estimatedCalories : null,
        mergeScore: _geminiCandidateScore(
          confidence: confidence,
          hasCatalogMatch: catalogMatch != null,
          fallbackCatalogMatch: fallbackCatalogMatch,
          estimatedCalories: estimatedCalories,
        ),
        supportingExperts: const [FoodExpertType.hybrid],
      );

      final key = _predictionKey(prediction);
      final current = byKey[key];
      if (current == null ||
          (prediction.mergeScore ?? prediction.confidence) >
              (current.mergeScore ?? current.confidence)) {
        byKey[key] = prediction;
      }
    }

    final ranked = byKey.values.toList(growable: false)
      ..sort(
        (left, right) => (right.mergeScore ?? right.confidence).compareTo(
          left.mergeScore ?? left.confidence,
        ),
      );
    return ranked;
  }

  List<FoodPrediction> _buildGeminiPredictions(Map<String, dynamic> payload) {
    final primaryName = (payload['foodName'] as String?)?.trim();
    final primaryConfidence = _parseGeminiConfidence(payload['confidence']);
    final primaryCalories = _parseGeminiCalories(payload['estimatedCalories']);

    final rawCandidates = <Map<String, dynamic>>[];
    if (primaryName != null && primaryName.isNotEmpty) {
      rawCandidates.add({
        'name': primaryName,
        'confidence': primaryConfidence,
        'estimatedCalories': primaryCalories,
      });
    }

    final candidateList = payload['candidates'];
    if (candidateList is List) {
      for (final candidate in candidateList.whereType<Map>()) {
        rawCandidates.add(Map<String, dynamic>.from(candidate));
      }
    }

    final byKey = <String, FoodPrediction>{};
    for (final candidate in rawCandidates) {
      final rawName = (candidate['name'] as String?)?.trim();
      if (rawName == null || rawName.isEmpty) {
        continue;
      }

      final confidence = _parseGeminiConfidence(candidate['confidence']);
      final estimatedCalories = _parseGeminiCalories(
        candidate['estimatedCalories'],
      );
      final catalogMatch = _resolveCatalogCandidate(rawName);
      final fallbackCatalogMatch = _isFallbackCatalogItem(catalogMatch);
      final prediction = FoodPrediction(
        label: rawName,
        formattedName: catalogMatch?.name ?? rawName,
        confidence: confidence,
        expert: FoodExpertType.hybrid,
        catalogMatch: catalogMatch,
        fallbackCatalogMatch: fallbackCatalogMatch,
        fallbackCalories: estimatedCalories > 0 ? estimatedCalories : null,
        mergeScore: _geminiCandidateScore(
          confidence: confidence,
          hasCatalogMatch: catalogMatch != null,
          fallbackCatalogMatch: fallbackCatalogMatch,
          estimatedCalories: estimatedCalories,
        ),
        supportingExperts: const [FoodExpertType.hybrid],
      );

      final key = _predictionKey(prediction);
      final current = byKey[key];
      if (current == null ||
          (prediction.mergeScore ?? prediction.confidence) >
              (current.mergeScore ?? current.confidence)) {
        byKey[key] = prediction;
      }
    }

    final ranked = byKey.values.toList(growable: false)
      ..sort(
        (left, right) => (right.mergeScore ?? right.confidence).compareTo(
          left.mergeScore ?? left.confidence,
        ),
      );
    return ranked;
  }

  Future<FoodAnalysisResult> analyzeImage(String imagePath) async {
    FoodAnalysisResult? apiResult;
    if (_hasFoodVisionBackend) {
      try {
        apiResult = await _analyzeWithFoodVisionBackend(imagePath);
      } catch (_) {}
    }

    if (apiResult == null && _hasGeminiApi) {
      try {
        apiResult = await _analyzeWithGemini(imagePath);
      } catch (_) {}
    }

    FoodAnalysisResult? localResult;
    if (_useLocalModelFallback) {
      try {
        localResult = await _analyzeWithLocalModels(imagePath);
      } catch (_) {}
    }

    if (apiResult != null && localResult != null) {
      return FoodService.selectBestAnalysisResult(
        apiResult: apiResult,
        localResult: localResult,
      );
    }

    if (localResult != null) {
      return localResult;
    }

    if (apiResult != null) {
      return apiResult;
    }

    throw const FoodServiceException(
      FoodServiceErrorType.invalidResponse,
      'Could not detect food. Please try again or search manually.',
    );
  }

  Future<FoodAnalysisResult> _analyzeWithLocalModels(String imagePath) async {
    throw const FoodServiceException(
      FoodServiceErrorType.localInferenceError,
      'Old local scanner has been removed.',
    );
  }





  static String _predictionKey(FoodPrediction prediction) {
    return FoodItem.normalizeSearchText(
      prediction.catalogMatch?.id ?? prediction.displayName,
    );
  }

  static bool _matchesCatalogVariant(
    FoodItem food,
    String normalizedCandidate,
  ) {
    final variants = <String>{
      food.name,
      food.id.replaceAll('_', ' '),
      ...food.aliases,
    };
    return variants.any((variant) {
      final normalizedVariant = FoodItem.normalizeSearchText(variant);
      return normalizedVariant == normalizedCandidate ||
          normalizedVariant.contains(normalizedCandidate) ||
          normalizedCandidate.contains(normalizedVariant);
    });
  }

  static int _compareTrustedMatches(FoodItem left, FoodItem right) {
    final calorieScore =
        (right.calories > 0 ? 1 : 0) - (left.calories > 0 ? 1 : 0);
    if (calorieScore != 0) {
      return calorieScore;
    }

    final nameLengthScore = left.name.length.compareTo(right.name.length);
    if (nameLengthScore != 0) {
      return nameLengthScore;
    }

    return left.name.compareTo(right.name);
  }

  FoodItem? _findTrustedCatalogMatch({
    required FoodCatalogService service,
    required List<String> candidateQueries,
  }) {
    final normalizedCandidates = candidateQueries
        .map(FoodItem.normalizeSearchText)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedCandidates.isEmpty) {
      return null;
    }

    final matchesById = <String, FoodItem>{};
    for (final query in normalizedCandidates.take(6)) {
      for (final food in service.search(query: query, limit: 12)) {
        matchesById.putIfAbsent(food.id, () => food);
      }
    }

    final trustedMatches =
        matchesById.values
            .where(
              (food) => normalizedCandidates.any(
                (candidate) => _matchesCatalogVariant(food, candidate),
              ),
            )
            .toList(growable: false)
          ..sort(_compareTrustedMatches);

    if (trustedMatches.isEmpty) {
      return null;
    }
    return trustedMatches.first;
  }

  FoodItem? _resolveCatalogCandidate(String candidateName) {
    final expandedQueries = expandScanFoodQueries(candidateName);
    if (expandedQueries.isEmpty) {
      return null;
    }

    final rankedMatches = searchCatalog(candidateName);
    final prefersFoodItems = expandedQueries
        .map(FoodItem.normalizeSearchText)
        .any(_strongBasicFoodNames.contains);

    final foodItemMatch = _findTrustedCatalogMatch(
      service: _foodItemCatalogService,
      candidateQueries: expandedQueries,
    );
    final dishMatch = _findTrustedCatalogMatch(
      service: _dishCatalogService,
      candidateQueries: expandedQueries,
    );
    final broadMatch = _findTrustedCatalogMatch(
      service: _broadCatalogService,
      candidateQueries: expandedQueries,
    );

    if (prefersFoodItems) {
      return foodItemMatch ??
          dishMatch ??
          broadMatch ??
          (rankedMatches.isNotEmpty ? rankedMatches.first : null);
    }

    return dishMatch ??
        foodItemMatch ??
        broadMatch ??
        (rankedMatches.isNotEmpty ? rankedMatches.first : null);
  }

  Uri _buildFoodVisionPredictUri() {
    final base = Uri.parse(_foodVisionApiBaseUrl.trim());
    final normalizedPath = base.path.endsWith('/')
        ? '${base.path}predict'
        : '${base.path}/predict';
    return base.replace(
      path: normalizedPath,
      queryParameters: <String, String>{'top_k': '3'},
    );
  }

  static String _guessMimeType(String imagePath) {
    final lower = imagePath.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  static String? _extractGeminiText(Map<String, dynamic> responseBody) {
    final candidates = responseBody['candidates'];
    if (candidates is! List) {
      return null;
    }

    for (final candidate in candidates.whereType<Map>()) {
      final content = candidate['content'];
      if (content is! Map) {
        continue;
      }
      final parts = content['parts'];
      if (parts is! List) {
        continue;
      }
      for (final part in parts.whereType<Map>()) {
        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  static Map<String, dynamic> _decodeGeminiJson(String text) {
    final trimmed = text.trim();
    try {
      return Map<String, dynamic>.from(
        jsonDecode(trimmed) as Map<String, dynamic>,
      );
    } catch (_) {
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) {
        throw const FoodServiceException(
          FoodServiceErrorType.invalidResponse,
          'Gemini returned malformed food JSON.',
        );
      }
      final candidateJson = trimmed.substring(start, end + 1);
      return Map<String, dynamic>.from(
        jsonDecode(candidateJson) as Map<String, dynamic>,
      );
    }
  }

  static double _parseGeminiConfidence(Object? value) {
    final raw = switch (value) {
      num() => value.toDouble(),
      String() => double.tryParse(value.trim()) ?? 0.0,
      _ => 0.0,
    };

    if (raw > 1.0) {
      return (raw / 100.0).clamp(0.0, 1.0);
    }
    return raw.clamp(0.0, 1.0);
  }

  static double _parseGeminiCalories(Object? value) {
    final raw = switch (value) {
      num() => value.toDouble(),
      String() => double.tryParse(value.trim()) ?? 0.0,
      _ => 0.0,
    };
    return raw.clamp(0.0, 5000.0);
  }

  static double _parseBackendCalories(Map<String, dynamic> nutrition) {
    return _parseGeminiCalories(
      nutrition['cal'] ?? nutrition['calories'] ?? nutrition['kcal'],
    );
  }

  static double _geminiCandidateScore({
    required double confidence,
    required bool hasCatalogMatch,
    required bool fallbackCatalogMatch,
    required double estimatedCalories,
  }) {
    var score = confidence;
    if (hasCatalogMatch && !fallbackCatalogMatch) {
      score += 0.18;
    } else if (hasCatalogMatch) {
      score += 0.08;
    }
    if (estimatedCalories > 0) {
      score += 0.04;
    }
    return score.clamp(0.0, 1.0);
  }

  static String _buildGeminiReason({
    required FoodPrediction primary,
    required Iterable<FoodPrediction> alternatives,
  }) {
    if (primary.isTrustedCatalogMatch) {
      return 'Gemini matched this photo to a trusted food in your app catalog.';
    }
    if (primary.fallbackCatalogMatch) {
      return 'Gemini matched this photo to the imported broad-food fallback catalog.';
    }
    final nextBest = alternatives.isEmpty
        ? null
        : alternatives.first.displayName;
    if (nextBest != null) {
      return 'Gemini thinks this is most likely ${primary.displayName}, with $nextBest as another possibility.';
    }
    return 'Gemini analyzed the photo and returned the strongest visible food match.';
  }

  static String _buildFoodVisionReason({
    required FoodPrediction primary,
    required Iterable<FoodPrediction> alternatives,
  }) {
    if (primary.isTrustedCatalogMatch) {
      return 'Food Vision AI matched this photo to a trusted food in your app catalog.';
    }
    if (primary.fallbackCatalogMatch) {
      return 'Food Vision AI matched this photo to the imported broad-food fallback catalog.';
    }
    final nextBest = alternatives.isEmpty
        ? null
        : alternatives.first.displayName;
    if (nextBest != null) {
      return 'Food Vision AI thinks this is most likely ${primary.displayName}, with $nextBest as another possibility.';
    }
    return 'Food Vision AI analyzed the photo and returned the strongest visible food match.';
  }

  static FoodAnalysisResult selectBestAnalysisResult({
    required FoodAnalysisResult apiResult,
    required FoodAnalysisResult localResult,
  }) {
    if (_shouldPreferLocalResult(
      apiResult: apiResult,
      localResult: localResult,
    )) {
      return localResult;
    }
    return apiResult;
  }

  static bool _shouldPreferLocalResult({
    required FoodAnalysisResult apiResult,
    required FoodAnalysisResult localResult,
  }) {
    final apiConfidence = apiResult.confidence ?? 0.0;
    final localConfidence = localResult.confidence ?? 0.0;

    if (apiResult.shouldReject && !localResult.shouldReject) {
      return true;
    }

    if (localResult.catalogMatched && !apiResult.catalogMatched) {
      if (localConfidence >= 0.45) {
        return true;
      }
      if (_isStrongBasicFoodResult(localResult) && localConfidence >= 0.35) {
        return true;
      }
    }

    if (localResult.catalogMatched &&
        !localResult.fallbackCatalogMatch &&
        apiResult.fallbackCatalogMatch &&
        !_sameResolvedFood(apiResult.foodName, localResult.foodName) &&
        localConfidence >= 0.35) {
      return true;
    }

    if (_isStrongBasicFoodResult(localResult) &&
        !_sameResolvedFood(apiResult.foodName, localResult.foodName) &&
        localConfidence >= apiConfidence + 0.08) {
      return true;
    }

    if (localResult.catalogMatched &&
        apiResult.catalogMatched &&
        !_sameResolvedFood(apiResult.foodName, localResult.foodName) &&
        localConfidence >= 0.75 &&
        apiConfidence < 0.7) {
      return true;
    }

    return false;
  }

  static bool _isFallbackCatalogItem(FoodItem? item) {
    return item?.tags.contains('theseus_fallback') ?? false;
  }

  static bool _sameResolvedFood(String left, String right) {
    return FoodItem.normalizeSearchText(left) ==
        FoodItem.normalizeSearchText(right);
  }

  static bool _isStrongBasicFoodResult(FoodAnalysisResult result) {
    return result.primaryExpert == FoodExpertType.basicFood &&
        _highSignalBasicLabels.contains(
          FoodItem.normalizeSearchText(result.rawCategory),
        );
  }
}

const Set<String> _highSignalBasicLabels = {'banana', 'apple', 'coffee'};

const Set<String> _strongBasicFoodNames = {
  'banana',
  'apple',
  'coffee',
  'orange',
  'egg',
  'milk',
};
