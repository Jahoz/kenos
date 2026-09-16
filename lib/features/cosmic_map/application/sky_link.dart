import 'dart:ui';

import 'package:flutter/foundation.dart';

/// V3.49 — deep links to places in the void: `/#/ciel/<x>/<y>` (hash
/// routing, like the salons' `/#/c/<clé>`). A place link carries NO
/// content and NO identity — just a world coordinate, the same public
/// metadata the sky already renders for everyone.
class SkyLink {
  SkyLink._();

  /// The path part: '0.62/0.31' — two decimals carry the ether's own
  /// precision (a screen's worth at the resting eye).
  static String pathOf(Offset world) =>
      '${world.dx.toStringAsFixed(2)}/${world.dy.toStringAsFixed(2)}';

  /// Parses the two coordinates; null when malformed or outside the
  /// known ether's [0,1]² (a forged link opens the sky at its heart —
  /// fail-open, never an error page).
  static Offset? parse(String? x, String? y) {
    final dx = double.tryParse(x ?? '');
    final dy = double.tryParse(y ?? '');
    if (dx == null || dy == null) return null;
    if (dx < 0 || dx > 1 || dy < 0 || dy > 1) return null;
    return Offset(dx, dy);
  }

  /// Where place links point (the salons' own origin rule: a
  /// build-time origin wins, the web's current origin speaks, a
  /// native build without origin shares the bare hash path).
  static String shareUrl(Offset world) {
    const fromBuild = String.fromEnvironment('SALON_LINK_ORIGIN');
    var origin = fromBuild;
    if (origin.isEmpty && kIsWeb) {
      final base = Uri.base;
      if (base.scheme.startsWith('http')) origin = base.origin;
    }
    final path = '/#/ciel/${pathOf(world)}';
    return origin.isEmpty ? path : '$origin$path';
  }
}
