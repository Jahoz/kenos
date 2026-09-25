import 'dart:math' as math;
import 'dart:ui';

/// The deterministic heavens — the WORLD's own astronomy, pure and
/// shared by every feature. No feature imports here, no Flutter
/// beyond `dart:ui`: the sky derives itself from server timestamps,
/// and every device agrees on where everything is (see KenosSystem's
/// V3.7b contract).
///
/// This module exists so the ether's data layer (demo seeding) and
/// the map's application layer (rendering, travel) read ONE law —
/// `echo/data` must never reach into another feature's application
/// to know where a thought is born.
class Heavens {
  Heavens._();

  /// The black hole sits at the heart of the known ether.
  static const Offset blackHole = Offset(0.5, 0.5);

  /// Polaris does not orbit: the fixed point, beacon of the north
  /// corner (V3.21 — the corner clears every lane; see
  /// CelestialMath for the full story).
  static const Offset polaris = Offset(0.13, 0.13);

  /// The three intentions' anchors: the worlds thoughts gravitate
  /// around. Anchor order is law (teal/La Lune 0, indigo/Vénus 1,
  /// lumen/Polaris 2) — `EchoColorTheme.skyPlanetIndex` speaks it.
  static const int anchorCount = 3;

  /// Base angles (radians) spread the three intents apart at epoch.
  /// (A literal: Duration members are not const-evaluable here.)
  static const double _epoch = 72 * 3600000.0;

  /// V3.62/V3.66/V3.68 — the lanes' radii (the JEWEL retinue: see
  /// KenosSystem.orbitRadiusOf for the history).
  static double orbitRadiusOf(int index) =>
      switch (index) { 0 => 0.24, _ => 0.38 };

  /// Each lane has its own tempo. V3.74 — THE SKY MUST BE SEEN TO
  /// TURN: the contemplative half-hours (30/55 min) read as frozen at
  /// the survey ("tout est figé, les astres doivent subir des
  /// rotations", the live report). The lanes now sweep in ~10/16 min
  /// — a drift the eye catches in ten seconds, still a contemplative
  /// sky, never a carousel (V3.22's law holds).
  static Duration _periodOf(int index) => switch (index) {
        0 => const Duration(minutes: 10),
        _ => const Duration(minutes: 16),
      };

  /// World position of a planet at a given moment. Polaris (index 2)
  /// holds still — the fixed point of the whole turning sky.
  static Offset planetPosition(int index, DateTime at) {
    if (index == 2) return polaris;
    final phase =
        (at.millisecondsSinceEpoch + _epoch) / _periodOf(index).inMilliseconds;
    final angle = 2 * math.pi * (phase + index / anchorCount);
    final radius = orbitRadiusOf(index);
    return Offset(
      blackHole.dx + radius * math.cos(angle),
      blackHole.dy + radius * math.sin(angle),
    );
  }

  // ── The birth law (echo launches) ────────────────────────────────────

  /// The gravity band's inner edge. V3.68 — the band tightens with
  /// the system (0.11 → 0.08): the bound swarm is the world's own
  /// retinue, a compact halo — the CROWD lives free (errant).
  static const double echoBandMin = 0.08;

  /// The gravity band's width.
  static const double echoBandSpan = 0.16;

  /// V3.67 — LA PENSÉE ERRANTE: not every thought falls into a
  /// gravity well. Roughly two in five are born FREE, anywhere in
  /// the ether, and ride wide slow rings around the VOID itself.
  /// V3.68 — the errant are the MAJORITY now (~65%) and their birth
  /// ring spans the whole sky. The flag derives from `created_at`
  /// (known at launch AND at render: the same input, the same
  /// verdict, forever).
  static bool isErrantThought(DateTime createdAt) {
    final h = (createdAt.millisecondsSinceEpoch * 2654435761) &
        0x7fffffff;
    return h % 100 < 65;
  }

  /// Where a new echo is BORN in the sky (V3.28): its intent planet's
  /// live position plus a point inside the gravity band, clamped to
  /// the known ether — OR, for a free thought
  /// ([isErrantThought]), anywhere on the wide ring (0.28–0.92 of
  /// the sky). The client computes this BEFORE the RPC; the sector
  /// fetch, the A.L. telemetry and the rendered orbit then agree.
  static Offset launchCoordsForPlanet(
    int planetIndex,
    DateTime at, [
    math.Random? rng,
  ]) {
    final random = rng ?? math.Random();
    if (isErrantThought(at)) {
      // V3.70 — THE CROWD LIVES IN THE MEDIAN: births crowd toward
      // the system's skirts (0.34) and thin into the deep field
      // (0.72), sqrt-biased so the swarm reads as a retinue thinning
      // into distance — never a uniform sheet. The radius is capped
      // by the square's TRUE edge along the angle: the ring breathes
      // to the corners, nothing piles on the walls.
      final a = random.nextDouble() * 2 * math.pi;
      final edge = math.min(
        0.48 / math.max(math.cos(a).abs(), 1e-9),
        0.48 / math.max(math.sin(a).abs(), 1e-9),
      );
      final r = math.min(
        0.34 + 0.38 * math.sqrt(random.nextDouble()),
        edge,
      );
      return Offset(
        (blackHole.dx + r * math.cos(a)).clamp(0.02, 0.98),
        (blackHole.dy + r * math.sin(a)).clamp(0.02, 0.98),
      );
    }
    final planet = planetPosition(planetIndex, at);
    final radius = echoBandMin + random.nextDouble() * echoBandSpan;
    final angle = random.nextDouble() * 2 * math.pi;
    return Offset(
      (planet.dx + radius * math.cos(angle)).clamp(0.02, 0.98),
      (planet.dy + radius * math.sin(angle)).clamp(0.02, 0.98),
    );
  }
}
