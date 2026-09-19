import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/indian_meal_result.dart';
import '../services/food_log_service.dart';
import '../services/roboflow_nutrition_service.dart';

class RoboflowMealAnalyzerWidget extends StatefulWidget {
  const RoboflowMealAnalyzerWidget({
    super.key,
    this.onMealLogged,
  });

  final VoidCallback? onMealLogged;

  @override
  State<RoboflowMealAnalyzerWidget> createState() => _RoboflowMealAnalyzerWidgetState();
}

class _RoboflowMealAnalyzerWidgetState extends State<RoboflowMealAnalyzerWidget> {
  XFile? _selectedXFile;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _isSaving = false;
  IndianMealResult? _nutritionResult;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedXFile = pickedFile;
          _imageBytes = bytes;
          _nutritionResult = null;
          _errorMessage = null;
        });
        await _analyzeMeal();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to select image: $e';
      });
    }
  }

  Future<void> _analyzeMeal() async {
    if (_selectedXFile == null || _imageBytes == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final filename = _selectedXFile!.name.isNotEmpty ? _selectedXFile!.name : 'meal.jpg';
    final result = await RoboflowNutritionService.instance.analyzeMealBytes(
      _imageBytes!,
      filename: filename,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) {
        _nutritionResult = result;
      } else {
        _errorMessage = result.error ?? 'Failed to parse meal nutrition data.';
      }
    });
  }

  Future<void> _logMealToFoodLog() async {
    if (_nutritionResult == null || !_nutritionResult!.success) return;

    setState(() {
      _isSaving = true;
    });

    final totals = _nutritionResult!.totals;
    final itemNames = _nutritionResult!.items.map((i) => i.name).join(', ');
    final title = itemNames.isNotEmpty ? itemNames : 'Indian Meal';

    await FoodLogService.instance.addEntry(
      name: title,
      calories: totals.totalCaloriesKcal > 0 ? totals.totalCaloriesKcal : null,
      photoPath: _selectedXFile?.path,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved "$title" (${totals.totalCaloriesKcal.toInt()} kcal) to Daily Food Log!'),
        backgroundColor: const Color(0xFFFF7A59),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    widget.onMealLogged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo Preview Box
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: _imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0E6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lunch_dining_rounded,
                          size: 44,
                          color: Color(0xFFFF7A59),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Scan Meal Image',
                        style: TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          'Snap or upload a photo of your meal to calculate calories & macros',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF6F6A64),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Camera & Gallery
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFFF7A59),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 20),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111111),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFE5DFD7), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Loading State
          if (_isLoading) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: const [
                  CircularProgressIndicator(
                    color: Color(0xFFFF7A59),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Analyzing meal with AI...',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Detecting food items, portions, and nutrition values',
                    style: TextStyle(color: Color(0xFF6F6A64), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],

          // Error Display
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Nutrition Results Display
          if (_nutritionResult != null) ...[
            _buildNutritionSummaryCard(_nutritionResult!.totals),
            const SizedBox(height: 16),
            _buildItemsTable(_nutritionResult!.items),
            const SizedBox(height: 16),
            if (_nutritionResult!.disclaimer != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  'Note: ${_nutritionResult!.disclaimer}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8D8881),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _logMealToFoodLog,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 22),
              label: Text(_isSaving ? 'Saving...' : 'Log Meal to Daily Food Log'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A59),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: 4,
                shadowColor: const Color(0x40FF7A59),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNutritionSummaryCard(IndianMealTotals totals) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.analytics_rounded, color: Color(0xFFFF7A59), size: 22),
              SizedBox(width: 10),
              Text(
                'Meal Nutrition Summary',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMacroStatBox(
                  'Calories',
                  '${totals.totalCaloriesKcal.toInt()}',
                  'kcal',
                  const Color(0xFFE65100),
                  const Color(0xFFFFF4EC),
                  const Color(0xFFFFE0CC),
                  Icons.local_fire_department_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroStatBox(
                  'Protein',
                  totals.totalProteinG.toStringAsFixed(1),
                  'g',
                  const Color(0xFF1565C0),
                  const Color(0xFFF0F7FF),
                  const Color(0xFFD0E4FF),
                  Icons.fitness_center_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroStatBox(
                  'Carbs',
                  totals.totalCarbsG.toStringAsFixed(1),
                  'g',
                  const Color(0xFF2E7D32),
                  const Color(0xFFF2F9F2),
                  const Color(0xFFC8E6C9),
                  Icons.grain_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroStatBox(
                  'Fat',
                  totals.totalFatG.toStringAsFixed(1),
                  'g',
                  const Color(0xFFC2185B),
                  const Color(0xFFFFF0F3),
                  const Color(0xFFFFCDD2),
                  Icons.water_drop_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroStatBox(
    String label,
    String value,
    String unit,
    Color color,
    Color bg,
    Color borderColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6F6A64),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(List<IndianMealItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.restaurant_rounded, color: Color(0xFFFF7A59), size: 22),
              SizedBox(width: 10),
              Text(
                'Identified Foods',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(
              color: Color(0xFFEEEAE4),
              height: 16,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.fastfood_rounded,
                        size: 20,
                        color: Color(0xFFFF7A59),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Portion: ${item.portionGrams.toInt()}g • ${item.category}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6F6A64),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${item.caloriesKcal.toInt()} kcal',
                        style: const TextStyle(
                          color: Color(0xFFE65100),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
