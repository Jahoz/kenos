import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Background dead star field: painted (no widgets), slow twinkle,
/// minimal parallax — this is scenery, not matter.
///
/// The void leads: magnitudes follow a power law (a skyful of barely
/// there dust, a handful of beacons) and the layers lean far-heavy,
/// so the black breathes between stars. A uniform speckle reads as
/// fabric; depth variance reads as distance (V3.60e — the sky was a
/// texture, it becomes a space).
class BackgroundStarFieldPainter extends CustomPainter {
  BackgroundStarFieldPainter({
    required this.time,
    required this.tiltX,
    required this.tiltY,
    this.starCount = 96,
  });

  final double time;
  final double tiltX;
  final double tiltY;
  final int starCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Three depth layers, far-heavy: the distant shell carries most
    // of the stars as near-invisible dust, the near one carries few.
    const layers = <({
      double share,
      double depthMin,
      double depthSpan,
      double parallax,
      double rMin,
      double rMax,
      double aMin,
      double aMax,
      double twinkle,
    })>[
      (
        share: 0.50, depthMin: 0.10, depthSpan: 0.20, parallax: 4.0,
        rMin: 0.3, rMax: 0.6, aMin: 0.02, aMax: 0.09, twinkle: 0.25,
      ),
      (
        share: 0.33, depthMin: 0.38, depthSpan: 0.20, parallax: 6.5,
        rMin: 0.4, rMax: 1.0, aMin: 0.05, aMax: 0.22, twinkle: 0.35,
      ),
      (
        share: 0.17, depthMin: 0.66, depthSpan: 0.20, parallax: 9.0,
        rMin: 0.5, rMax: 1.6, aMin: 0.08, aMax: 0.50, twinkle: 0.45,
      ),
    ];

    for (var layer = 0; layer < layers.length; layer++) {
      final l = layers[layer];
      final layerRandom = math.Random(1337 + layer * 17);
      final count = (starCount * l.share).round();

      for (var i = 0; i < count; i++) {
        final depth = l.depthMin + layerRandom.nextDouble() * l.depthSpan;
        final baseX = layerRandom.nextDouble();
        final baseY = layerRandom.nextDouble();
        final twinklePhase = layerRandom.nextDouble() * 2 * math.pi;
        final twinkleSpeed = 0.2 + layerRandom.nextDouble() * 0.6;

        // Power-law magnitude: most stars barely are, a few shine —
        // the sky's own distribution, and the surest cure for clutter.
        final magnitude = math.pow(layerRandom.nextDouble(), 2.6).toDouble();

        final x = baseX * size.width + tiltX * l.parallax * depth;
        final y = baseY * size.height + tiltY * l.parallax * depth;
        final radius = l.rMin + (l.rMax - l.rMin) * magnitude;
        final baseAlpha = l.aMin + (l.aMax - l.aMin) * magnitude;
        final twinkle =
            (1.0 - l.twinkle) + l.twinkle * math.sin(time * twinkleSpeed + twinklePhase);
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

    // Layered nebulae with different colors, positions, and pulse
    // rates — veils, not paint: each keeps well short of its edge
    // so true void survives between them (V3.60e).
    nebula(const Offset(0.22, 0.3), 0.50, AppColors.indigo, 0.09, 0.5, 0.2);
    nebula(const Offset(0.8, 0.72), 0.45, AppColors.teal, 0.06, 0.7, 0.15);
    nebula(const Offset(0.6, 0.15), 0.34, AppColors.purple, 0.042, 0.3, 0.1);
    // Additional subtle layers for depth
    nebula(const Offset(0.15, 0.75), 0.38, AppColors.cyan, 0.034, 0.6, 0.12);
    nebula(const Offset(0.9, 0.3), 0.28, AppColors.fade(AppColors.purple, 0.5), 0.024, 0.4, 0.08);
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
