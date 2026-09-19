import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/food_log_service.dart';

class NutritionGraphCard extends StatefulWidget {
  const NutritionGraphCard({super.key});

  @override
  State<NutritionGraphCard> createState() => _NutritionGraphCardState();
}

class _NutritionGraphCardState extends State<NutritionGraphCard> {
  int _selectedDayIndex = 6; // Sunday/Today default

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FoodLogEntry>>(
      stream: FoodLogService.instance.entriesStream,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const [];

        // Generate past 7 days data
        final now = DateTime.now();
        final days = List.generate(7, (i) {
          final date = now.subtract(Duration(days: 6 - i));
          return date;
        });

        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

        // Aggregate calories per day
        final dayCalories = List<double>.filled(7, 0.0);
        double totalProtein = 0;
        double totalCarbs = 0;
        double totalFat = 0;

        for (final entry in entries) {
          final diffDays = now.difference(entry.timestamp).inDays;
          if (diffDays >= 0 && diffDays < 7) {
            final dayIndex = 6 - diffDays;
            if (dayIndex >= 0 && dayIndex < 7) {
              dayCalories[dayIndex] += (entry.calories ?? 0);
            }
          }
          // Simple estimation fallback for demo macros if not detailed
          final cal = entry.calories ?? 0;
          totalProtein += cal * 0.25 / 4; // 25% protein
          totalCarbs += cal * 0.50 / 4;   // 50% carbs
          totalFat += cal * 0.25 / 9;     // 25% fat
        }

        final selectedCal = dayCalories[_selectedDayIndex].round();
        final maxCal = dayCalories.reduce(math.max);
        final targetCal = 2000.0;
        final highestValue = math.max(maxCal, targetCal * 1.1);

        return Container(
          padding: const EdgeInsets.all(20),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nutrition Analytics',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF111111),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Weekly Calorie & Macro Trends',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF6F6A64),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE9DB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            size: 16, color: Color(0xFFFF6A1B)),
                        const SizedBox(width: 4),
                        Text(
                          '$selectedCal kcal',
                          style: const TextStyle(
                            color: Color(0xFFFF6A1B),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Weekly Bar Chart
              SizedBox(
                height: 160,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final dayDate = days[index];
                    final dayLabel = dayNames[dayDate.weekday - 1];
                    final cal = dayCalories[index];
                    final heightFactor =
                        highestValue > 0 ? (cal / highestValue).clamp(0.05, 1.0) : 0.05;
                    final isSelected = index == _selectedDayIndex;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDayIndex = index;
                        });
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isSelected)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111111),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${cal.round()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: isSelected ? 22 : 16,
                            height: 110 * heightFactor,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: isSelected
                                    ? [const Color(0xFFFF6A1B), const Color(0xFFFFB37A)]
                                    : [const Color(0xFFE2DDD5), const Color(0xFFF4F1EC)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFF6A1B)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dayLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFFFF6A1B)
                                  : const Color(0xFF8C867E),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 20),

              // Macro Breakdown Section
              Text(
                'Macronutrient Breakdown',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111111),
                    ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  // Donut Ring Visualizer
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: _MacroDonutPainter(
                        proteinRatio: totalProtein > 0 ? 0.3 : 0.33,
                        carbsRatio: totalCarbs > 0 ? 0.45 : 0.33,
                        fatRatio: totalFat > 0 ? 0.25 : 0.34,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Macros',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Legend items
                  Expanded(
                    child: Column(
                      children: [
                        _MacroIndicatorRow(
                          label: 'Carbs',
                          value: '${totalCarbs > 0 ? totalCarbs.round() : 145}g',
                          color: const Color(0xFFFF8A4C),
                          percent: 0.50,
                        ),
                        const SizedBox(height: 8),
                        _MacroIndicatorRow(
                          label: 'Protein',
                          value: '${totalProtein > 0 ? totalProtein.round() : 68}g',
                          color: const Color(0xFF10B981),
                          percent: 0.30,
                        ),
                        const SizedBox(height: 8),
                        _MacroIndicatorRow(
                          label: 'Fat',
                          value: '${totalFat > 0 ? totalFat.round() : 42}g',
                          color: const Color(0xFFF59E0B),
                          percent: 0.20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MacroIndicatorRow extends StatelessWidget {
  const _MacroIndicatorRow({
    required this.label,
    required this.value,
    required this.color,
    required this.percent,
  });

  final String label;
  final String value;
  final Color color;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF444444),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MacroDonutPainter extends CustomPainter {
  _MacroDonutPainter({
    required this.proteinRatio,
    required this.carbsRatio,
    required this.fatRatio,
  });

  final double proteinRatio;
  final double carbsRatio;
  final double fatRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final strokeWidth = 12.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2;

    // Carbs Segment
    final carbsSweep = 2 * math.pi * carbsRatio;
    paint.color = const Color(0xFFFF8A4C);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        carbsSweep - 0.08,
        false,
        paint);
    startAngle += carbsSweep;

    // Protein Segment
    final proteinSweep = 2 * math.pi * proteinRatio;
    paint.color = const Color(0xFF10B981);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        proteinSweep - 0.08,
        false,
        paint);
    startAngle += proteinSweep;

    // Fat Segment
    final fatSweep = 2 * math.pi * fatRatio;
    paint.color = const Color(0xFFF59E0B);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        fatSweep - 0.08,
        false,
        paint);
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) => true;
}
