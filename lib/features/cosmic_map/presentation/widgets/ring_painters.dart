import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Mindful Hold charge ring: a thin circular arc drawn around the star
/// during the 3-second long press.
class HoldRingPainter extends CustomPainter {
  HoldRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;

    // Discreet track.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.fade(Colors.white, 0.07);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    // Add glow effect under the charge ring
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = AppColors.fade(color, progress * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, radius, glowPaint);

    // Charged arc, gradient along the fill direction.
    final rect = Rect.fromCircle(center: center, radius: radius);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [AppColors.fade(color, 0.15), color, Colors.white],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(HoldRingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Shield of sealed echoes: slowly rotating dashed ring —
/// the user's echo is untouchable, even by themselves.
class ShieldRingPainter extends CustomPainter {
  ShieldRingPainter({required this.rotation, required this.color});

  final double rotation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    const dashCount = 12;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.fade(color, 0.55);

    for (var i = 0; i < dashCount; i++) {
      final start = rotation + (2 * math.pi * i / dashCount);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        2 * math.pi / dashCount * 0.45,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ShieldRingPainter old) => old.rotation != rotation;
}

/// The comet tail: momentum made visible. A rebounded echo carries the
/// count of humans who held it — each a fading mote trailing the star.
/// Public metadata only (a count, never a content).
class CometTailPainter extends CustomPainter {
  CometTailPainter({
    required this.momentum,
    required this.color,
    this.now,
  });

  final int momentum;
  final Color color;
  final DateTime? now;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final tailLength = (momentum).clamp(1, 6);
    final baseRadius = size.shortestSide / 2;

    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < tailLength; i++) {
      final t = (i + 1) / (tailLength + 1);
      // The tail drifts up-left, like a comet crossing the void.
      final angle = -2.45; // ~ -140°
      final distance = baseRadius * (0.9 + t * 1.8);
      final mote = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      final radius = 1.6 * (1 - t) + 0.6;
      paint.color = AppColors.fade(color, 0.5 * (1 - t) + 0.08);
      canvas.drawCircle(mote, radius, paint);
    }
  }

  @override
  bool shouldRepaint(CometTailPainter old) =>
      old.momentum != momentum || old.color != color;
}
