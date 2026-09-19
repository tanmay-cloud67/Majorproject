import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../widgets/auth_background.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AuthBackground(),
          SafeArea(
            child: Stack(
              children: [
                const Positioned(
                  top: 40,
                  right: 18,
                  child: _FloatingIcon(
                    icon: Icons.fitness_center,
                    color: Color(0xFFFFD166),
                    size: 72,
                  ),
                ),
                const Positioned(
                  top: 160,
                  left: 22,
                  child: _FloatingIcon(
                    icon: Icons.dinner_dining,
                    color: Color(0xFF9AE66E),
                    size: 64,
                  ),
                ),
                const Positioned(
                  bottom: 140,
                  right: 24,
                  child: _FloatingIcon(
                    icon: Icons.rice_bowl,
                    color: Color(0xFFFF9A8B),
                    size: 68,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(flex: 3),
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enter personal details to keep your health journey on track.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const Spacer(flex: 4),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed(AppRoutes.login);
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFF3D5BDB),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Continue'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}
