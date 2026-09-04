import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../application/accretion.dart';
import '../../application/kenos_system.dart';
import '../../application/travel_camera.dart';

/// V3.12b — the falls: motes of what died, spiralling from their last
/// sky position into the black hole's rose horizon. Drawn above the
/// stars, beneath the HUD — the void eats quietly.
class AccretionPainter extends CustomPainter {
  AccretionPainter({
    required this.motes,
    required this.camera,
    required this.viewport,
    required this.now,
    required this.reducedMotion,
  });

  final List<AccretionMote> motes;
  final TravelCamera camera;
  final Size viewport;
  final DateTime now;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    if (reducedMotion) return;
    final hole = camera.worldToScreen(KenosSystem.blackHole, viewport);
    final worldScale = viewport.shortestSide / camera.viewExtent;

    for (final mote in motes) {
      final t =
          now.difference(mote.at).inMicroseconds / accretionFall.inMicroseconds;
      if (t < 0 || t >= 1) continue;
      final (radius, angle) = AccretionController.spiralAt(mote, t);
      final pos = hole +
          Offset(
            radius * math.cos(angle) * worldScale,
            radius * math.sin(angle) * worldScale,
          );
      final color = AccretionController.colorAt(mote, t);
      final dotR = (2.6 * (1 - t) + 0.5) * (viewport.shortestSide / 700);

      // A short trailing arc: the memory of the path just travelled.
      final tail = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round
        ..color = AppColors.fade(color, 0.35 * (1 - t));
      canvas.drawArc(
        Rect.fromCircle(center: hole, radius: radius * worldScale),
        angle - 0.55 * (1 - t * 0.5),
        0.55 * (1 - t * 0.5),
        false,
        tail,
      );

      // The mote itself, warming.
      canvas.drawCircle(
        pos,
        dotR,
        Paint()
          ..color = AppColors.fade(color, 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(
        pos,
        dotR * 0.6,
        Paint()..color = AppColors.fade(color, 1),
      );
    }
  }

  @override
  bool shouldRepaint(AccretionPainter oldDelegate) =>
      oldDelegate.now != now || oldDelegate.motes.length != motes.length;
}

/// Convenience: does anything still fall? (Cheap ticker gate.)
bool accretionActive(List<AccretionMote> motes, DateTime now) => motes.any(
      (m) => now.difference(m.at) < accretionFall,
    );
