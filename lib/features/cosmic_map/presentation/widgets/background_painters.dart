import 'dart:math' as math;
import 'dart:ui' as ui;

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

/// One passing wish: the pure geometry of a shooting star.
///
/// Deterministic from its seed, testable without a canvas — the layer
/// above decides WHEN it flies, this only says WHERE and HOW BRIGHT.
class ShootingStar {
  const ShootingStar({
    required this.start,
    required this.angle,
    required this.duration,
    required this.travel,
    required this.tailLength,
  });

  /// [seed] decides everything: same seed, same star.
  factory ShootingStar.fromSeed(int seed) {
    final rng = math.Random(seed);
    final deg = 22 + rng.nextDouble() * 42; // always below the horizon
    final mirrored = rng.nextBool();
    return ShootingStar(
      // Enters from the upper band of the sky, edges included.
      start: Offset(0.04 + rng.nextDouble() * 0.92, -0.06 + rng.nextDouble() * 0.34),
      angle: (mirrored ? 180 - deg : deg) * math.pi / 180,
      duration: 0.9 + rng.nextDouble() * 0.6,
      travel: 0.38 + rng.nextDouble() * 0.24,
      tailLength: 56 + rng.nextDouble() * 54,
    );
  }

  /// Normalized entry point (fractions of the sky).
  final Offset start;

  /// Travel direction in radians — descending by construction.
  final double angle;

  /// Seconds spent crossing the eye.
  final double duration;

  /// Path length, as a fraction of the sky's longest side.
  final double travel;

  /// Tail length in logical pixels.
  final double tailLength;

  Offset direction() => Offset(math.cos(angle), math.sin(angle));

  /// Where the burning head sits at [progress] (0..1).
  Offset head(Size sky, double progress) =>
      Offset(start.dx * sky.width, start.dy * sky.height) +
      direction() * (travel * sky.longestSide * progress);

  /// Visibility envelope: born dark, dies dark — never a pop.
  double opacity(double progress) {
    final fadeIn = (progress / 0.22).clamp(0.0, 1.0);
    final fadeOut = ((1.0 - progress) / 0.38).clamp(0.0, 1.0);
    return math.min(fadeIn, fadeOut) * 0.7;
  }
}

/// Paints one shooting star in flight: a white streak dissolving
/// into the void behind its head. Scenery, never matter.
class ShootingStarPainter extends CustomPainter {
  ShootingStarPainter({
    required this.star,
    required this.progress,
    this.tiltX = 0,
    this.tiltY = 0,
  });

  final ShootingStar star;
  final double progress;
  final double tiltX;
  final double tiltY;

  @override
  void paint(Canvas canvas, Size size) {
    final brightness = star.opacity(progress);
    if (brightness <= 0.01) return;

    // The visitor rides the tilt like the dead field does — a far,
    // light layer of parallax.
    final parallax = Offset(tiltX * 3, tiltY * 3);
    final head = star.head(size, progress) + parallax;
    final tail = head - star.direction() * star.tailLength;

    final streak = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3
      ..shader = ui.Gradient.linear(
        head,
        tail,
        [
          AppColors.fade(Colors.white, brightness),
          AppColors.fade(Colors.white, 0),
        ],
      );
    canvas.drawLine(head, tail, streak);

    canvas.drawCircle(
      head,
      1.6,
      Paint()..color = AppColors.fade(Colors.white, brightness * 0.9),
    );
  }

  @override
  bool shouldRepaint(ShootingStarPainter old) => true;
}
