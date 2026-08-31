import 'dart:math' as math;

/// KENOS space math.
///
/// Depth convention: `z ∈ [0.05, 1]`, where 1 = against the camera
/// and 0.05 = lost at the bottom of the void.
///
/// NOTE (spec fix): the original design doc formula
/// `final_X = coord_x + tilt * (1/z)` was inverted — it moved distant
/// objects MORE than close ones, contradicting real parallax.
/// Displacement must be proportional to proximity: `offset = tilt * amplitude * z`.
class ParallaxMath {
  ParallaxMath._();

  /// Pixel offset induced by the device tilt.
  /// Close objects (z → 1) follow the motion, the background stays put.
  /// One home for THE parallax formula — layers must use this, not
  /// hand-rolled copies of it.
  static double offsetPixels({
    required double tilt,
    required double z,
    required double amplitude,
  }) => tilt * amplitude * z;

  /// Visual radius of a star core, in pixels.
  static double coreRadius(double z) => 2.0 + 3.5 * z;

  /// Total diameter taken by the star + its charge ring.
  static double starDiameter(double z) => 20.0 + 46.0 * z;

  /// Opacity: distant objects fade into the void.
  static double opacityFor(double z) => 0.22 + 0.78 * z;

  /// Depth blur (sigma) — 0 for close objects.
  static double blurSigma(double z) {
    if (z > 0.55) return 0;
    return (0.55 - z) * 5.0;
  }

  /// Slow drift of one's own echoes: launched at z = 1 (against the camera),
  /// they sink into the depth then stabilize far away.
  /// The full drift takes ~11 hours.
  static double driftZ({
    required DateTime sentAt,
    required DateTime now,
    double minZ = 0.12,
  }) {
    const driftHours = 11.0;
    final hours = now.difference(sentAt).inMilliseconds / 3.6e6;
    return math.max(minZ, math.min(1, 1 - hours / driftHours));
  }

  /// Double clamp utility.
  static double clamp(double v, double min, double max) =>
      math.max(min, math.min(max, v));
}
