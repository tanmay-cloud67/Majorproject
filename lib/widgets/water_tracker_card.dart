import 'package:flutter/material.dart';
import '../services/hydration_service.dart';

class WaterTrackerCard extends StatelessWidget {
  const WaterTrackerCard({
    super.key,
    this.onTapMore,
  });

  final VoidCallback? onTapMore;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HydrationSnapshot>(
      stream: HydrationService.instance.hydrationStream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final todayLiters = data?.todayLiters ?? 0.0;
        final rawGoal = data?.goalLiters ?? 2.5;
        final goalLiters = rawGoal <= 0 ? 2.5 : rawGoal;
        final progress = (todayLiters / goalLiters).clamp(0.0, 1.0);
        final percent = (progress * 100).round();

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
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Water & Hydration Tracker 💧',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF111111),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stay hydrated throughout the day',
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
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F7FA),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.water_drop_rounded,
                            size: 16, color: Color(0xFF00ACC1)),
                        const SizedBox(width: 4),
                        Text(
                          '${todayLiters.toStringAsFixed(1)} / ${goalLiters.toStringAsFixed(1)} L',
                          style: const TextStyle(
                            color: Color(0xFF00ACC1),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Water Level Visual Progress Bar
              Stack(
                children: [
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F7FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.02, 1.0),
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00ACC1), Color(0xFF29B6F6)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00ACC1).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$percent% of daily goal',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00ACC1),
                    ),
                  ),
                  Text(
                    '${(goalLiters - todayLiters).clamp(0.0, 10.0).toStringAsFixed(1)} L remaining',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8C867E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Quick Add Buttons Row
              Row(
                children: [
                  Expanded(
                    child: _WaterAddButton(
                      label: '+200ml',
                      icon: Icons.local_drink_rounded,
                      onTap: () => HydrationService.instance.addWater(0.2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _WaterAddButton(
                      label: '+500ml',
                      icon: Icons.water_damage_rounded,
                      onTap: () => HydrationService.instance.addWater(0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _WaterAddButton(
                      label: '+1.0L',
                      icon: Icons.local_cafe_rounded,
                      onTap: () => HydrationService.instance.addWater(1.0),
                    ),
                  ),
                  if (onTapMore != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onTapMore,
                      icon: const Icon(Icons.settings_suggest_rounded, size: 22),
                      color: const Color(0xFF00ACC1),
                      tooltip: 'More settings',
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WaterAddButton extends StatelessWidget {
  const _WaterAddButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE0F7FA),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: const Color(0xFF00ACC1)),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF00ACC1),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
