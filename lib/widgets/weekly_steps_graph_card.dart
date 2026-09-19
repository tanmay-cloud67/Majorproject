import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/steps_service.dart';

class WeeklyStepsGraphCard extends StatefulWidget {
  const WeeklyStepsGraphCard({super.key});

  @override
  State<WeeklyStepsGraphCard> createState() => _WeeklyStepsGraphCardState();
}

class _WeeklyStepsGraphCardState extends State<WeeklyStepsGraphCard> {
  late int _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = (DateTime.now().weekday - 1) % 7;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StepsSnapshot>(
      stream: StepsService.instance.stepsStream,
      builder: (context, stepsSnapshot) {
        final stepsToday = stepsSnapshot.data?.stepsToday ?? 0;

        return StreamBuilder<WeeklyStepsSnapshot>(
          stream: StepsService.instance.weeklyStepsStream,
          builder: (context, snapshot) {
            final weeklyData = snapshot.data;
            final currentWeekList = weeklyData?.currentWeekSteps;
            const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

            final List<int> daySteps = (currentWeekList != null && currentWeekList.length == 7)
                ? List<int>.from(currentWeekList)
                : <int>[0, 0, 0, 0, 0, 0, stepsToday];
            if (daySteps.isNotEmpty) {
              daySteps[daySteps.length - 1] = stepsToday;
            }
        const int stepGoal = 8000;

        int maxStep = 0;
        for (final step in daySteps) {
          if (step > maxStep) maxStep = step;
        }
        final double highestValue = math.max(maxStep.toDouble(), stepGoal * 1.15);

        final selectedSteps = daySteps[_selectedDayIndex];

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
                          'Activity & Steps Graph',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF111111),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Daily Movement Progress',
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
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_walk_rounded,
                            size: 16, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 4),
                        Text(
                          '$selectedSteps steps',
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
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

              // Activity Bar Chart
              SizedBox(
                height: 160,
                child: Stack(
                  children: [
                    // Goal line indicator
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 110 * (stepGoal / highestValue),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Goal ${stepGoal ~/ 1000}k',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (index) {
                        final steps = daySteps[index];
                        final heightFactor = (steps / highestValue).clamp(0.05, 1.0);
                        final isSelected = index == _selectedDayIndex;
                        final meetsGoal = steps >= stepGoal;

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
                                    color: meetsGoal
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFF111111),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$steps',
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
                                    colors: meetsGoal
                                        ? [
                                            const Color(0xFF2E7D32),
                                            const Color(0xFF81C784)
                                          ]
                                        : isSelected
                                            ? [
                                                const Color(0xFF1565C0),
                                                const Color(0xFF64B5F6)
                                              ]
                                            : [
                                                const Color(0xFFE2DDD5),
                                                const Color(0xFFF4F1EC)
                                              ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: (meetsGoal
                                                    ? const Color(0xFF2E7D32)
                                                    : const Color(0xFF1565C0))
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : [],
                                ),
                              ),
                               const SizedBox(height: 8),
                              const SizedBox(height: 8),
                              Text(
                                dayNames[index],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? const Color(0xFF1565C0)
                                      : const Color(0xFF8C867E),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Summary Stats Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F7F4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ActivityStatTile(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: const Color(0xFFFF6A1B),
                      title: '${(selectedSteps * 0.04).round()} kcal',
                      subtitle: 'Active Burn',
                    ),
                    Container(height: 24, width: 1, color: Colors.grey.shade300),
                    _ActivityStatTile(
                      icon: Icons.place_rounded,
                      iconColor: const Color(0xFF1565C0),
                      title: '${(selectedSteps * 0.00075).toStringAsFixed(1)} km',
                      subtitle: 'Distance',
                    ),
                    Container(height: 24, width: 1, color: Colors.grey.shade300),
                    _ActivityStatTile(
                      icon: Icons.timer_rounded,
                      iconColor: const Color(0xFF2E7D32),
                      title: '${(selectedSteps * 0.008).round()} mins',
                      subtitle: 'Active Time',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
          },
        );
      },
    );
  }
}

class _ActivityStatTile extends StatelessWidget {
  const _ActivityStatTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111111),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8C867E),
          ),
        ),
      ],
    );
  }
}
