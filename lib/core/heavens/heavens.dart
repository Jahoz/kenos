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

  /// Polaris does not orbit: the fixed point, beacon of the far
  /// corner (V3.21 — the corner clears every lane; V3.76 — pushed to
  /// the corner itself, r ≈ 0.64: the widened lanes (0.32/0.45) would
  /// graze the old north-corner post — the beacon watches the system
  /// from farther out, clear of all traffic).
  /// V3.79 — the beacon holds the DEEPER far corner: the system
  /// breathes with the widened sky (lanes 0.42/0.72) and Polaris
  /// moves with it, staying clear of every orbiting lane by more
  /// than the 0.08 the determinism test pins (r ≈ 0.8485).
  static const Offset polaris = Offset(-0.10, -0.10);

  /// The three intentions' anchors: the worlds thoughts gravitate
  /// around. Anchor order is law (teal/La Lune 0, indigo/Vénus 1,
  /// lumen/Polaris 2) — `EchoColorTheme.skyPlanetIndex` speaks it.
  static const int anchorCount = 3;

  /// Base angles (radians) spread the three intents apart at epoch.
  /// (A literal: Duration members are not const-evaluable here.)
  static const double _epoch = 72 * 3600000.0;

  /// V3.62/V3.66/V3.68/V3.76 — the lanes' radii. V3.76 — THE SYSTEM
  /// OPENS: the retinue hugged the hole (0.24/0.38 — everything
  /// alive inside a disc of radius 0.64, one third of the sky's
  /// surface, "on reste toujours aussi proche du trou noir"). The
  /// V3.79 — THE SYSTEM BREATHES WITH THE SKY: V3.77 widened the
  /// storable field to [-0.6, 1.6] and the system stayed compact in
  /// the middle — "les astres principaux sont trop proches les uns
  /// des autres et du trou noir" (the live report). Lanes 0.42/0.72:
  /// +35% of sky to the hole, the planets' conjunction distance rises
  /// 0.13 → 0.30, and Polaris (r 0.6364) breathes BETWEEN the lanes
  /// — every crossing keeps the 0.08 floor the determinism test
  /// pins (her radius chose the outer lane: 0.72 clears it).
  static double orbitRadiusOf(int index) =>
      switch (index) { 0 => 0.42, _ => 0.72 };

  /// Each lane has its own tempo. V3.74 — THE SKY MUST BE SEEN TO
  /// TURN; V3.79 — the widened lanes lengthen their laps to hold the
  /// linear serenity the determinism test pins (~0.23 world-units a
  /// minute, never a carousel): 11.5/20 min, Kepler's courtesy — the
  /// outer world rides slower than the inner one.
  static Duration _periodOf(int index) => switch (index) {
        0 => const Duration(milliseconds: 690000),
        _ => const Duration(minutes: 20),
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

  /// V3.75 — THE CONSTITUTION: every echo orbits a BODY (its type's
  /// planet, or a moon). Roughly one in six — deterministic on
  /// `created_at`, the same verdict at launch and at render — is born
  /// a MOON-COMPANION: a tight little court around one of the four
  /// lunes, found by travelling. The void-ring "errant" concept is
  /// retired: nothing orbits the emptiness, the hole is the only
  /// center and matter gravitates around matter.
  static bool ridesAMoon(DateTime createdAt) {
    final h = (createdAt.millisecondsSinceEpoch * 2654435761) &
        0x7fffffff;
    return h % 6 == 0;
  }

  /// Where a new echo is BORN in the sky (V3.28 → V3.75): beside its
  /// BODY — its intent planet's live position (a tight newborn orbit,
  /// see KenosSystem's aging law), or, for a moon-companion
  /// ([ridesAMoon]), beside its moon. The client computes this BEFORE
  /// the RPC; the sector fetch, the A.L. telemetry and the rendered
  /// orbit then agree: the author drops the thought where it will
  /// actually drift.
  static Offset launchCoordsForPlanet(
    int planetIndex,
    DateTime at, [
    math.Random? rng,
  ]) {
    final random = rng ?? math.Random();
    final body = ridesAMoon(at)
        ? wandererPosition(
            (at.millisecondsSinceEpoch >> 3) % wandererCount, at)
        : planetPosition(planetIndex, at);
    // The newborn's band: tight against its body (the aging law will
    // lift the orbit as the thought ages — near is young).
    final radius = 0.015 + random.nextDouble() * 0.035;
    final angle = random.nextDouble() * 2 * math.pi;
    // V3.77 — beyond the square: the storable sky widens to
    // [-0.55, 1.55] (a hair inside the server's new bound).
    return Offset(
      (body.dx + radius * math.cos(angle)).clamp(-0.55, 1.55),
      (body.dy + radius * math.sin(angle)).clamp(-0.55, 1.55),
    );
  }

  // ── The lunes (V3.12/V3.70/V3.74) ────────────────────────────────────
  // Far slow arcs beyond every planetary lane, each at its own pace;
  // every device agrees on where they are. Pure world astronomy —
  // they live HERE (Heavens' charter) so the birth law and the map
  // read ONE law.

  /// How many lunes ride the sky.
  static const int wandererCount = 4;

  /// A lune's world position: arcs the sky in ~50–110 min (V3.74 —
  /// the sky must be SEEN to turn). V3.79 — pushed to 0.98–1.08: the
  /// outer lane's retinue (0.72 + the echo band's 0.24) reaches
  /// 0.96, and the lunes owe it a clear court; the far limit (1.08)
  /// keeps every lune INSIDE the storable sky (0.5 − 1.08 = −0.58 ≥
  /// −0.6) and centerable at the eye's reach.
  static Offset wandererPosition(int index, DateTime at) {
    final i = index % wandererCount;
    final radius = 0.98 + 0.05 * (i % 3);
    final periodMs = (50 + 20 * i) * 60000.0;
    final base = i * math.pi / 2;
    final angle =
        base + 2 * math.pi * at.millisecondsSinceEpoch / periodMs;
    return Offset(
      0.5 + radius * math.cos(angle),
      0.5 + radius * math.sin(angle),
    );
  }
}
