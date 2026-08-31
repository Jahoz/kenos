import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/kenos_wave.dart';

/// Paints the breathing nebulae of the Symphonie Collective.
///
/// One Paint per wave with a radial gradient and a soft blur — no
/// widgets, no saveLayer storms (V3.1 ceiling: 24 waves). The life
/// curve: swell (grow + fade in), presence, exhale (fade out).
class WaveNebulaPainter extends CustomPainter {
  WaveNebulaPainter({
    required this.waves,
    required this.now,
    required this.reducedMotion,
  });

  final List<KenosWave> waves;
  final DateTime now;
  final bool reducedMotion;

  static const double _maxRadius = 110;
  static const double _peakOpacity = 0.38;

  @override
  void paint(Canvas canvas, Size size) {
    for (final wave in waves) {
      final p = wave.progressAt(now);
      if (p <= 0 || p >= 1) continue;

      final center = Offset(
        wave.offsetX * size.width,
        wave.offsetY * size.height,
      );

      // Swell: the first fifth of the life grows the nebula to full
      // radius. Reduce-motion skips the growth — the wave simply IS.
      final grow = reducedMotion ? 1.0 : _easeOut((p / 0.22).clamp(0.0, 1.0));
      final radius = _maxRadius * grow;

      final opacity = reducedMotion
          ? (p > 0.75 ? _peakOpacity * (1 - (p - 0.75) / 0.25) : _peakOpacity)
          : _envelope(p);

      final hue = WavePalette.hueFor(wave.hueIndex);
      final paint = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26)
        ..shader = RadialGradient(
          colors: [
            AppColors.fade(hue, opacity),
            AppColors.fade(hue, opacity * 0.55),
            AppColors.fade(hue, 0),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);

      // The white core, present until the very end of the exhale.
      final corePaint = Paint()
        ..color = AppColors.fade(AppColors.pureLight, opacity * 1.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center, 6 * grow, corePaint);
    }
  }

  /// Sound-like envelope: quick swell, plateau, long exhale.
  static double _envelope(double p) {
    if (p < 0.18) return _peakOpacity * (p / 0.18);
    if (p < 0.72) return _peakOpacity;
    return _peakOpacity * (1 - (p - 0.72) / 0.28);
  }

  static double _easeOut(double t) => 1 - math.pow(1 - t, 3).toDouble();

  @override
  bool shouldRepaint(WaveNebulaPainter oldDelegate) =>
      oldDelegate.now != now ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.waves.length != waves.length;
}
