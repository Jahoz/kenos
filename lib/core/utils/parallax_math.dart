import 'dart:math' as math;
import 'dart:ui' show Offset;

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

  /// Visual radius of a star core, in pixels — generous: a star must
  /// read as LIGHT (pointed, alive), never as a planet's disc.
  static double coreRadius(double z) => 3.5 + 5.5 * z;

  /// Total diameter taken by the star + its charge ring — the hold
  /// target grows with it (tight clusters stay tappable).
  static double starDiameter(double z) => 26.0 + 54.0 * z;

  /// Opacity: distant objects fade into the void.
  static double opacityFor(double z) => 0.22 + 0.78 * z;

  /// Depth haze: retired with the bucket ImageFiltered (it had to
  /// re-filter the whole viewport every frame once the orbits came
  /// alive). The haze now lives in each star's glow — see
  /// MindfulHoldStar: far = softer, wider halo.

  /// The traveller's reception field: the eye receives what drifts
  /// CLOSE. Within [receptionRadius] (world units) of the eye a star
  /// is fully alive — readable, holdable; beyond it fades to a glimmer
  /// that must be approached. Distance is the price of the bottle in
  /// the sea. Zooming in deep shrinks viewExtent and brings the whole
  /// screen inside the field: approaching IS zooming, too.
  static const double receptionRadius = 0.16;
  static const double receptionFade = 0.18;

  /// 1 inside the field, 0 beyond it, a linear breath between.
  static double receptionIntensity({
    required Offset eye,
    required Offset star,
  }) {
    final d = (star - eye).distance;
    if (d <= receptionRadius) return 1;
    if (d >= receptionRadius + receptionFade) return 0;
    return 1 - (d - receptionRadius) / receptionFade;
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
