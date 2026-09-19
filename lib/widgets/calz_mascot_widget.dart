import 'package:flutter/material.dart';

class CalzMascotWidget extends StatelessWidget {
  const CalzMascotWidget({super.key, this.starPoints = 0});

  final int starPoints;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Mascot Bird Drawing
        SizedBox(
          width: 220,
          height: 180,
          child: CustomPaint(
            painter: MascotPainter(),
          ),
        ),

        // Yellow Star Badge on top right
        Positioned(
          top: 10,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF111111), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(2, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$starPoints',
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: Color(0xFF111111),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MascotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final blackFill = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.fill;

    // Body
    final bodyPath = Path();
    bodyPath.moveTo(size.width * 0.5, size.height * 0.15);
    // Head top curve
    bodyPath.cubicTo(
      size.width * 0.25, size.height * 0.15,
      size.width * 0.20, size.height * 0.45,
      size.width * 0.18, size.height * 0.60,
    );
    // Left wing
    bodyPath.cubicTo(
      size.width * 0.05, size.height * 0.65,
      size.width * 0.05, size.height * 0.78,
      size.width * 0.22, size.height * 0.78,
    );
    // Bottom belly
    bodyPath.cubicTo(
      size.width * 0.35, size.height * 0.92,
      size.width * 0.65, size.height * 0.92,
      size.width * 0.78, size.height * 0.78,
    );
    // Right wing
    bodyPath.cubicTo(
      size.width * 0.95, size.height * 0.78,
      size.width * 0.95, size.height * 0.65,
      size.width * 0.82, size.height * 0.60,
    );
    // Head right curve
    bodyPath.cubicTo(
      size.width * 0.80, size.height * 0.45,
      size.width * 0.75, size.height * 0.15,
      size.width * 0.5, size.height * 0.15,
    );

    canvas.drawPath(bodyPath, fillPaint);
    canvas.drawPath(bodyPath, strokePaint);

    // Left Eye
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.38, size.height * 0.35, 10, 14),
      blackFill,
    );
    // Right Eye
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.56, size.height * 0.35, 10, 14),
      blackFill,
    );

    // Eyebrows
    final brow1 = Path()
      ..moveTo(size.width * 0.36, size.height * 0.30)
      ..quadraticBezierTo(
        size.width * 0.40, size.height * 0.25,
        size.width * 0.44, size.height * 0.31,
      );
    final brow2 = Path()
      ..moveTo(size.width * 0.54, size.height * 0.31)
      ..quadraticBezierTo(
        size.width * 0.58, size.height * 0.25,
        size.width * 0.62, size.height * 0.30,
      );
    canvas.drawPath(brow1, strokePaint..strokeWidth = 3);
    canvas.drawPath(brow2, strokePaint..strokeWidth = 3);

    // Beak
    final beak = Path()
      ..moveTo(size.width * 0.44, size.height * 0.42)
      ..lineTo(size.width * 0.54, size.height * 0.42)
      ..lineTo(size.width * 0.49, size.height * 0.52)
      ..close();
    canvas.drawPath(beak, blackFill);

    // Feet
    final foot1 = Path()
      ..addOval(Rect.fromLTWH(size.width * 0.34, size.height * 0.86, 22, 10));
    final foot2 = Path()
      ..addOval(Rect.fromLTWH(size.width * 0.54, size.height * 0.86, 22, 10));
    canvas.drawPath(foot1, blackFill);
    canvas.drawPath(foot2, blackFill);

    // Fork held by left wing
    final forkPath = Path();
    forkPath.moveTo(size.width * 0.12, size.height * 0.68);
    forkPath.lineTo(size.width * 0.32, size.height * 0.55);

    // Prongs
    forkPath.moveTo(size.width * 0.10, size.height * 0.64);
    forkPath.lineTo(size.width * 0.15, size.height * 0.72);
    forkPath.moveTo(size.width * 0.08, size.height * 0.67);
    forkPath.lineTo(size.width * 0.13, size.height * 0.75);

    canvas.drawPath(forkPath, strokePaint..strokeWidth = 3.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
