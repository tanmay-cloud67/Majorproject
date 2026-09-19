import 'package:flutter/material.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  static const Color _deepBlue = Color(0xFF2F3F8F);
  static const Color _midBlue = Color(0xFF5169D8);
  static const Color _lightBlue = Color(0xFF7F93F6);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_lightBlue, _midBlue, _deepBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -40,
          left: -20,
          child: _Blob(
            size: 140,
            colors: [Colors.white, _lightBlue.withValues(alpha: 0.6)],
          ),
        ),
        Positioned(
          top: 120,
          right: -30,
          child: _Blob(
            size: 120,
            colors: [Colors.white, _midBlue.withValues(alpha: 0.6)],
          ),
        ),
        Positioned(
          bottom: 120,
          left: -40,
          child: _Blob(
            size: 160,
            colors: [Colors.white, _deepBlue.withValues(alpha: 0.6)],
          ),
        ),
        Positioned(
          bottom: -20,
          right: -10,
          child: _Blob(
            size: 120,
            colors: [Colors.white, _midBlue.withValues(alpha: 0.7)],
          ),
        ),
        Positioned(
          top: 220,
          left: 40,
          child: _Blob(
            size: 70,
            colors: [Colors.white, _midBlue.withValues(alpha: 0.4)],
          ),
        ),
      ],
    );
  }
}

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed ?? () => Navigator.of(context).maybePop(),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1F2F73).withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
          radius: 0.9,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
    );
  }
}
