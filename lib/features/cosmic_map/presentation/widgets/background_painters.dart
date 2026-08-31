import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Background dead star field: painted (no widgets), slow twinkle,
/// minimal parallax — this is scenery, not matter.
class BackgroundStarFieldPainter extends CustomPainter {
  BackgroundStarFieldPainter({
    required this.time,
    required this.tiltX,
    required this.tiltY,
    this.starCount = 90,
  });

  final double time;
  final double tiltX;
  final double tiltY;
  final int starCount;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(1337); // deterministic: the sky never shifts
    final paint = Paint();

    for (var i = 0; i < starCount; i++) {
      final depth = 0.15 + random.nextDouble() * 0.85;
      final baseX = random.nextDouble();
      final baseY = random.nextDouble();
      final twinklePhase = random.nextDouble() * 2 * math.pi;
      final twinkleSpeed = 0.3 + random.nextDouble() * 0.7;

      final x = baseX * size.width + tiltX * 6 * depth;
      final y = baseY * size.height + tiltY * 6 * depth;
      final radius = 0.4 + depth * 1.1;
      final alpha =
          (0.12 + depth * 0.30) *
          (0.7 + 0.3 * math.sin(time * twinkleSpeed + twinklePhase));

      paint.color = AppColors.fade(Colors.white, alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(BackgroundStarFieldPainter old) => true;
}

/// Diffuse nebulae: two color halos laid over the void,
/// barely swaying with the tilt.
class NebulaPainter extends CustomPainter {
  NebulaPainter({required this.tiltX, required this.tiltY});

  final double tiltX;
  final double tiltY;

  @override
  void paint(Canvas canvas, Size size) {
    void nebula(
      Offset relativeCenter,
      double relativeRadius,
      Color color,
      double alpha,
    ) {
      final center = Offset(
        relativeCenter.dx * size.width + tiltX * 10,
        relativeCenter.dy * size.height + tiltY * 10,
      );
      final radius = relativeRadius * size.longestSide;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [AppColors.fade(color, alpha), AppColors.fade(color, 0)],
        ).createShader(rect);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height).inflate(radius),
        paint..blendMode = BlendMode.plus,
      );
    }

    nebula(const Offset(0.22, 0.3), 0.55, AppColors.indigo, 0.10);
    nebula(const Offset(0.8, 0.72), 0.5, AppColors.teal, 0.07);
    nebula(const Offset(0.6, 0.15), 0.35, AppColors.purple, 0.05);
  }

  @override
  bool shouldRepaint(NebulaPainter old) =>
      old.tiltX != tiltX || old.tiltY != tiltY;
}
