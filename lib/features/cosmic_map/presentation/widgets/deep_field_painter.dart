import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../application/deep_field.dart';
import '../../application/travel_camera.dart';

/// V3.34 — paints the deep field: the far universe behind the ether,
/// riding slower layers than the world as the eye travels. Culled per
/// mote (an off-screen mote costs a comparison), static by design — no
/// ticker, no twinkle: the far field does not breathe, it only recedes.
///
/// V3.63 — the dust rides the ether's presence but never dies past a
/// floor: the far country is EMPTY of decoration, yet the last dust
/// keeps the void in depth — emptiness with relief, not a flat black.
class DeepFieldPainter extends CustomPainter {
  DeepFieldPainter({required this.camera, this.presence = 1.0})
      : _center = camera.center,
        _zoom = camera.zoom;

  final TravelCamera camera;

  /// V3.63 — 1.0 inside the known ether, 0.0 in the far country
  /// (see [ParallaxMath.etherPresence]); the dust floors at 30%.
  final double presence;

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
    final dustVeil = 0.3 + 0.7 * presence;
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
        paint.color = AppColors.fade(AppColors.pureLight, mote.alpha * dustVeil);
        canvas.drawCircle(sp, r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DeepFieldPainter oldDelegate) =>
      oldDelegate._center != _center ||
      oldDelegate._zoom != _zoom ||
      (oldDelegate.presence - presence).abs() > 0.01;
}
