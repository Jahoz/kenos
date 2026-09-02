import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../echo/domain/read_scar.dart';

/// The reader's trail: each consumed echo leaves a faint HOLLOW point
/// where it dissolved — contentless, local, fading with the ether's
/// 30-day horizon. Hollow like the sealed anchors: what was read is
/// empty now. The journey paints the sky.
///
/// Takes camera VALUES (center, zoom), not the mutable camera: a
/// mutated object would compare identical to itself and the scars
/// would never follow the eye.
class ScarFieldPainter extends CustomPainter {
  ScarFieldPainter({
    required this.center,
    required this.zoom,
    required this.scars,
  });

  final Offset center;
  final double zoom;
  final List<ReadScar> scars;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final scar in scars) {
      final o = scar.opacity;
      if (o <= 0.01) continue;
      final sp = Offset(
        (scar.worldX - center.dx) * zoom * size.width + size.width / 2,
        (scar.worldY - center.dy) * zoom * size.height + size.height / 2,
      );
      if (sp.dx < -8 || sp.dx > size.width + 8 ||
          sp.dy < -8 || sp.dy > size.height + 8) {
        continue;
      }
      paint.color = AppColors.fade(AppColors.pureLight, o);
      canvas.drawCircle(sp, 1.6, paint);
      // A hairline tick, id-stable, keeps each scar from reading as
      // a "star to hold": scars are marks, not lights.
      final angle = (scar.echoId.hashCode % 360) * math.pi / 180;
      canvas.drawLine(
        sp + Offset(math.cos(angle) * 3, math.sin(angle) * 3),
        sp + Offset(math.cos(angle) * 5.5, math.sin(angle) * 5.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ScarFieldPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.zoom != zoom ||
        !identical(oldDelegate.scars, scars);
  }
}
