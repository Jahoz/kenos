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
  static double coreRadius(double z) => 4.5 + 7.0 * z;

  /// Total diameter taken by the star + its charge ring — the hold
  /// target grows with it (tight clusters stay tappable).
  /// V3.29: was 30 + 62z — on a phone a deep sealed ring measured
  /// half the screen and swallowed the worlds whole (the live
  /// report). 22 + 42z keeps the light pointed and the sky's
  /// hierarchy readable; the catch zone keeps its own 44 px floor.
  static double starDiameter(double z) => 22.0 + 42.0 * z;

  /// One sky, every screen (V3.25): star sizes were raw pixels while
  /// planets scale with the viewport — on a phone's narrow window a
  /// deep glow swallowed the Moon whole. Stars now scale in the same
  /// currency: the desktop look (900 px shortest side) is the
  /// reference and proportions hold everywhere.
  static double displayScale(double shortestSide) =>
      (shortestSide / 900).clamp(0.40, 1.15);

  /// The eye's resting zoom — the anchor of [zoomScale]. The launched
  /// look (TravelCamera's default) must stay scale 1.0: the tuned sky
  /// and its tests are calibrated to it (V3.61 moved it 1.75 → 2.4 to
  /// de-clutter; V3.64 walked it back to 1.7; V3.68 pulled to 1.25;
  /// V3.69 opens at the SURVEY itself, 1.0 — the whole-ether map is
  /// the opening stance, the dive is the journey).
  static const double eyeBaseZoom = 1.0;

  /// How much celestial BODIES grow as the eye zooms. Zoom moves the
  /// window (viewExtent) — but a zoom nothing grows through is a zoom
  /// the eye cannot see: the wheel fired for days before anyone
  /// believed it (V3.17). Subtle on purpose, stars stay stars, never
  /// balloons: 1.0 at the resting eye, ≈0.73 zoomed out, ≈2.5 deep.
  static double zoomScale(double zoom) =>
      math.pow(zoom / eyeBaseZoom, 0.6).toDouble();

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
  ///
  /// V3.64 — the bubble shrank (0.16 → 0.085): the field once covered
  /// nearly the whole resting view — everything visible was readable,
  /// no distance was real, the ether read as a room ("tout est trop
  /// proche", the live report). Reading is now a PLACE one travels
  /// to; the sky between lights is crossed, not surveyed.
  static const double receptionRadius = 0.085;
  static const double receptionFade = 0.12;

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

  /// V3.63 — the known ether's PRESENCE at the traveller's eye. The
  /// traversable void extends far past the last light (V3.40), but it
  /// wore the same dust and veils as the heart: travel read as a
  /// texture sliding, not a distance crossed. Presence is geography
  /// now — full within the lit ether, dying into the far country.
  /// Leaving IS watching the sky empty itself; and the traveller
  /// gone far sees the ether glow at their back (the hearth).
  /// V3.68/69 — the lit band rides the survey gaze (0.8–1.25): the
  /// whole opening map stays dressed, only the true rim empties.
  ///
  /// V3.70 — THE FRAME MUST CUT A DRESSED SKY. On a tall phone the
  /// survey's long axis spans ~2.4 world units while the dressed disc
  /// was 2.5: the frame landed exactly where the ether DIED — a
  /// pendant on velvet, never a cosmos (the S25 report). The fade now
  /// dies far past the deepest frame (0.8 → 1.55) and the far country
  /// keeps a FLOOR forever: emptiness with relief, never flat black.
  static const double presenceFloor = 0.06;

  static double etherPresence(Offset eye) {
    final d = (eye - const Offset(0.5, 0.5)).distance;
    if (d <= 0.8) return 1.0;
    if (d >= 1.55) return presenceFloor;
    final t = (d - 0.8) / (1.55 - 0.8);
    final fade = t * t * (3 - 2 * t);
    return 1.0 - fade * (1.0 - presenceFloor);
  }

  /// V3.37 — the zoom where far lights move fast enough that a 30 fps
  /// glimmer canvas reads as judder (motion magnified by the eye): at
  /// and beyond it the glimmer field rides every tick. Below it the
  /// calm half-rate stands — battery is part of the sanctuary.
  static const double deepWatchZoom = 3.0;

  static bool glimmerFullRate(double zoom) => zoom >= deepWatchZoom;

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

  /// V3.30 — clock direction of a world-space delta: 12 = up (screen
  /// north), 3 = east, clockwise like the sky's own hours. The breath
  /// line's compass — a direction told, never a GPS.
  static int clockDirection(Offset delta) {
    final angle = math.atan2(delta.dx, -delta.dy);
    final hours = (angle / (2 * math.pi) * 12).round() % 12;
    return hours == 0 ? 12 : hours;
  }

  /// V3.58i — the living sway calms as the eye approaches. The tilt
  /// parallax (real gyro, or the sensor-less web's sinusoidal drift)
  /// keeps the space ALIVE at the overview — and fights the focused
  /// watch at deep zoom: a whole-field sway stepping at the gate's
  /// cadence reads as backward pops ("repart en arrière à intervalle
  /// régulier", the live report). Full amplitude at the resting eye,
  /// a quarter at max zoom — the feature survives, the distraction
  /// dies.
  ///
  /// V3.70 — THE SURVEY SWAYS: below the fold (1.2) the tilt is
  /// AMPLIFIED, up to ×1.35 at the survey floor — tilting the phone
  /// slides the whole sky inside its frame: the strongest mobile cue
  /// that the void has depth beyond the glass.
  static double parallaxCalm(double zoom) {
    if (zoom <= 1.2) {
      return 1.0 + 0.35 * ((1.2 - zoom) / (1.2 - 0.9)).clamp(0.0, 1.0);
    }
    return 1.0 - 0.75 * ((zoom - 1.2) / (8.0 - 1.2)).clamp(0.0, 1.0);
  }
}
