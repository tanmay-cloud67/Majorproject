import 'package:flutter/material.dart';

import '../widgets/nutrition_graph_card.dart';
import '../widgets/water_tracker_card.dart';
import 'home_screen.dart';

class WellnessScreen extends StatelessWidget {
  const WellnessScreen({
    super.key,
    this.showBottomNav = true,
  });

  final bool showBottomNav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9F8),
        elevation: 0,
        title: const Text(
          'Wellness & Hydration',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            WaterTrackerCard(
              onTapMore: () => HomeScreen.showHydrationSheet(context),
            ),
            const SizedBox(height: 20),
            const NutritionGraphCard(),
          ],
        ),
      ),
    );
  }
}
