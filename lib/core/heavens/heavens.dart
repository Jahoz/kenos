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
  static const Offset polaris = Offset(0.05, 0.05);

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
  /// lanes widen to 0.32/0.45 with the far band at 0.38: the crowd's
  /// envelope reaches 0.83 and the survey frame cuts it on every
  /// screen — distance between the worlds at last.
  static double orbitRadiusOf(int index) =>
      switch (index) { 0 => 0.32, _ => 0.45 };

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
    return Offset(
      (body.dx + radius * math.cos(angle)).clamp(0.02, 0.98),
      (body.dy + radius * math.sin(angle)).clamp(0.02, 0.98),
    );
  }

  // ── The lunes (V3.12/V3.70/V3.74) ────────────────────────────────────
  // Far slow arcs beyond every planetary lane, each at its own pace;
  // every device agrees on where they are. Pure world astronomy —
  // they live HERE (Heavens' charter) so the birth law and the map
  // read ONE law.

  /// How many lunes ride the sky.
  static const int wandererCount = 4;

  /// A lune's world position: arcs 0.72–1.12 of the sky, pacing
  /// their circles in ~50–110 min (V3.74 — the sky must be SEEN to
  /// turn). V3.76 — pushed out with the widened system; the far
  /// limit keeps every lune centerable (the eye at max zoom).
  static Offset wandererPosition(int index, DateTime at) {
    final i = index % wandererCount;
    final radius = 0.72 + 0.20 * (i % 3);
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
