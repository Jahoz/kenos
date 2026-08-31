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
    this.starCount = 120,
  });

  final double time;
  final double tiltX;
  final double tiltY;
  final int starCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Draw stars in three depth layers for enhanced parallax
    for (var layer = 0; layer < 3; layer++) {
      final layerSeed = 1337 + layer * 17;
      final layerRandom = math.Random(layerSeed);
      final layerStarCount = (starCount / 3).toInt();
      final baseDepth = 0.15 + (layer * 0.25);
      final depthRange = 0.20;
      final layerParallaxScale = 4.0 + (layer * 2.5);
      
      for (var i = 0; i < layerStarCount; i++) {
        final depth = baseDepth + layerRandom.nextDouble() * depthRange;
        final baseX = layerRandom.nextDouble();
        final baseY = layerRandom.nextDouble();
        final twinklePhase = layerRandom.nextDouble() * 2 * math.pi;
        final twinkleSpeed = 0.2 + layerRandom.nextDouble() * 0.6;

        final x = baseX * size.width + tiltX * layerParallaxScale * depth;
        final y = baseY * size.height + tiltY * layerParallaxScale * depth;
        final radius = 0.3 + depth * 1.3;
        final baseAlpha = (0.08 + depth * 0.25);
        final twinkle = 0.6 + 0.4 * math.sin(time * twinkleSpeed + twinklePhase);
        final alpha = baseAlpha * twinkle;

        paint.color = AppColors.fade(Colors.white, alpha.clamp(0.0, 1.0));
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(BackgroundStarFieldPainter old) => true;
}

/// Diffuse nebulae: multiple color halos with layered effects,
/// subtly swaying with the tilt and pulsing over time.
class NebulaPainter extends CustomPainter {
  NebulaPainter({required this.tiltX, required this.tiltY, this.time = 0.0});

  final double tiltX;
  final double tiltY;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    void nebula(
      Offset relativeCenter,
      double relativeRadius,
      Color color,
      double baseAlpha,
      double pulseSpeed,
      double pulseAmount,
    ) {
      // Add subtle pulsing to nebulae
      final pulse = 1.0 + pulseAmount * math.sin(time * pulseSpeed);
      final alpha = baseAlpha * pulse.clamp(0.7, 1.3);
      
      final center = Offset(
        relativeCenter.dx * size.width + tiltX * 12,
        relativeCenter.dy * size.height + tiltY * 12,
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

    // Layered nebulae with different colors, positions, and pulse rates
    nebula(const Offset(0.22, 0.3), 0.60, AppColors.indigo, 0.12, 0.5, 0.2);
    nebula(const Offset(0.8, 0.72), 0.55, AppColors.teal, 0.08, 0.7, 0.15);
    nebula(const Offset(0.6, 0.15), 0.40, AppColors.purple, 0.06, 0.3, 0.1);
    // Additional subtle layers for depth
    nebula(const Offset(0.15, 0.75), 0.45, AppColors.cyan, 0.05, 0.6, 0.12);
    nebula(const Offset(0.9, 0.3), 0.35, AppColors.fade(AppColors.purple, 0.5), 0.04, 0.4, 0.08);
  }

  @override
  bool shouldRepaint(NebulaPainter old) =>
      old.tiltX != tiltX || old.tiltY != tiltY || (old.time - time).abs() > 0.1;
}
