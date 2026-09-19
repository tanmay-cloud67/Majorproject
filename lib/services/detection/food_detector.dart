import 'dart:io';
import '../../models/food_detection_result.dart';

abstract class FoodDetector {
  Future<FoodDetectionResult> detectFood(File imageFile);
  bool get isAvailable;
}
