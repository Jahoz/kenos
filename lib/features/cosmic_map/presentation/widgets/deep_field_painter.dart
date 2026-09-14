import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../application/deep_field.dart';
import '../../application/travel_camera.dart';

/// V3.34 — paints the deep field: the far universe behind the ether,
/// riding slower layers than the world as the eye travels. Culled per
/// mote (an off-screen mote costs a comparison), static by design — no
/// ticker, no twinkle: the far field does not breathe, it only recedes.
class DeepFieldPainter extends CustomPainter {
  DeepFieldPainter({required this.camera})
      : _center = camera.center,
        _zoom = camera.zoom;

  final TravelCamera camera;

  /// Camera VALUES captured at construction (the camera is a single
  /// mutable instance — comparing it to itself never fires).
  final Offset _center;
  final double _zoom;

  /// The dust, resolved once for the process: same sky, every device.
  static final List<List<DeepFieldDust>> _dust = [
    for (var i = 0; i < deepFieldLayers.length; i++) deepFieldDust(i),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var li = 0; li < deepFieldLayers.length; li++) {
      final layer = deepFieldLayers[li];
      final scale = DeepFieldMath.sizeScale(_zoom, layer.factor);
      for (final mote in _dust[li]) {
        final sp = DeepFieldMath.worldToScreen(
          mote.at,
          center: _center,
          zoom: _zoom,
          factor: layer.factor,
          viewport: size,
        );
        final r = mote.radius * scale;
        if (sp.dx < -r - 1 ||
            sp.dx > size.width + r + 1 ||
            sp.dy < -r - 1 ||
            sp.dy > size.height + r + 1) {
          continue;
        }
        paint.color = AppColors.fade(AppColors.pureLight, mote.alpha);
        canvas.drawCircle(sp, r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DeepFieldPainter oldDelegate) =>
      oldDelegate._center != _center || oldDelegate._zoom != _zoom;
}
