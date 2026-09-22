import 'dart:math' as math;
import 'dart:ui';

import '../../echo/domain/echo.dart';
import '../../echo/domain/echo_color_theme.dart';
import 'celestial_bodies.dart';

/// V3.7b — the System: a black hole at the heart of the world, three
/// planets for the three intentions, and every echo orbiting the
/// gravity of what it was launched for.
///
/// Everything is DETERMINISTIC from the server timestamp: two devices
/// opening the ether at the same moment see the same sky — no sync,
/// no migration, the heavens derive themselves from `created_at`.
class KenosSystem {
  KenosSystem._();

  /// The black hole sits at the heart of the known ether.
  static const Offset blackHole = Offset(0.5, 0.5);

  /// Nothing RESTS upon the black hole (V3.12b): vestiges and corpses
  /// are held outside this world radius, deterministically — the
  /// central object is the app's throat, not a parking spot. Orbiting
  /// echoes and grazing comets are exempt: they move, they don't rest.
  ///
  /// V3.62 — widened (0.15 → 0.22): the heart grew to flagship scale,
  /// and nothing may crowd its gravity. Resting bodies now ring the
  /// system instead of clustering at its rim.
  static const double blackHoleExclusion = 0.22;

  /// Gently nudges a resting position outside the hole's horizon,
  /// along its own radius. Idempotent, deterministic, poetic: what is
  /// too heavy to fall in simply rests at the edge.
  static Offset outsideTheHole(Offset p) {
    final d = p - blackHole;
    final dist = d.distance;
    if (dist >= blackHoleExclusion) return p;
    if (dist < 1e-9) {
      return Offset(blackHole.dx, blackHole.dy - blackHoleExclusion);
    }
    return blackHole + d / dist * blackHoleExclusion;
  }

  /// V3.12c — serene real estate for everything that RESTS (vestiges,
  /// corpses). One deterministic resolver, applied in a stable order:
  ///  - never upon the black hole;
  ///  - never ON the two planetary lanes (a world rides its circle);
  ///  - never on the fixed beacon Polaris;
  ///  - never stacked on another resting body ([occupied] carries the
  ///    ones already placed — call in a stable sequence).
  /// Echoes still sweep their swarm (they move; motion crossing a
  /// resting shard is the sky breathing, not a collision).
  ///
  /// V3.61 — the clearance widened (0.055 → 0.08): resting bodies
  /// breathe nearly half again as far apart; the sky was a crowded
  /// sheet, it becomes a field.
  static Offset resolveResting(
    Offset p, {
    List<Offset> occupied = const [],
    double clearance = 0.08,
  }) {
    var q = outsideTheHole(p);
    // The lanes: dodge both planetary circles radially. The dodge band
    // stays at 0.055 — the lanes sit 0.11 apart, a wider band would
    // leave nowhere to stand BETWEEN them (V3.61 learned it the hard
    // way); only the body-to-body clearance widened.
    for (final lane in [orbitRadiusOf(0), orbitRadiusOf(1)]) {
      final d = (q - blackHole).distance;
      if (d < 1e-9) break;
      if ((d - lane).abs() < 0.055) {
        var target = d < lane ? lane - 0.055 : lane + 0.055;
        if (target < blackHoleExclusion + 0.01) target = lane + 0.055;
        q = blackHole + (q - blackHole) / d * target;
      }
    }
    // The beacon: Polaris keeps a clear sky.
    final toBeacon = q - CelestialMath.polaris;
    if (toBeacon.distance < clearance + 0.02 && toBeacon.distance >= 0) {
      final away = toBeacon.distance < 1e-9
          ? const Offset(0, -1)
          : toBeacon / toBeacon.distance;
      q = CelestialMath.polaris + away * (clearance + 0.02);
    }
    // The others: a deterministic GOLDEN SCATTER. Repulsion alone
    // squeezes clusters; instead, a stacked body takes the next
    // golden-angle station on a ring around its first collision —
    // clusters bloom apart, never through each other.
    final base = q;
    const golden = 2.399963229728653; // radians, the golden angle
    for (var n = 0; n < 24; n++) {
      var clear = true;
      for (final o in occupied) {
        if ((q - o).distance < clearance) {
          clear = false;
          break;
        }
      }
      if (clear) break;
      // Phyllotaxis (sunflower packing): station n sits at golden angle
      // n·φ on a spiral of radius c·√(n+1) — the layout that keeps
      // every pair at least ~c apart, for any cluster size (c rides
      // the clearance, V3.61).
      final angle = n * golden;
      final r = 0.09 * math.sqrt(n + 1);
      q = Offset(
        base.dx + r * math.cos(angle),
        base.dy + r * math.sin(angle),
      );
    }
    q = outsideTheHole(q);
    // The known ether's bounds.
    return Offset(q.dx.clamp(0.02, 0.98), q.dy.clamp(0.02, 0.98));
  }

  /// V3.62 — the lanes tightened (0.26/0.37 → 0.19/0.28): at the
  /// resting eye (±0.21 of sky) the old tracks passed OUTSIDE the
  /// frame — the worlds existed, the traveller never saw them. The
  /// heart grew to flagship scale; its retinue now rings it INSIDE
  /// the first gaze, yet stays clear of the reception field (0.16):
  /// the worlds FRAME the holdable lights, they never sit among
  /// them. Moving bodies may orbit within the resting exclusion —
  /// only what RESTS is pushed out (see [blackHoleExclusion]).
  ///
  /// V3.66 — they open again (0.19/0.28 → 0.26/0.40): the uniform
  /// projection made wide screens honest, and honesty showed the
  /// whole retinue HIDDLING against the hole.
  ///
  /// V3.68 — the system becomes a JEWEL (0.30/0.44 → 0.24/0.38,
  /// halos tightened with it): spreading the lanes ever wider made
  /// the SYSTEM bigger than the sky it lives in — every frame was
  /// retinue, the eye lived inside it. The gaze pulled back (V3.68's
  /// 1.25) and the retinue compacted: the system sits in the middle
  /// distance, clear of the exclusion, lanes 0.14 apart (the resting
  /// dodge keeps its corridor), and the CROWD carries the sky
  /// (see [isErrantThought] — most thoughts are free now).
  static double orbitRadiusOf(int index) =>
      switch (index) { 0 => 0.24, _ => 0.38 };

  /// Each lane has its own tempo.
  static Duration _periodOf(int index) => switch (index) {
        0 => const Duration(minutes: 30),
        _ => const Duration(minutes: 55),
      };

  /// The outermost planetary lane — beyond it only comets and
  /// wanderers travel.
  static double get outerOrbit => orbitRadiusOf(1);

  /// One full revolution of the innermost lane (legacy reference).
  static const Duration planetPeriod = Duration(minutes: 40);

  /// Base angles (radians) spread the three intents apart at epoch.
  /// (A literal: Duration members are not const-evaluable here.)
  static const double _epoch = 72 * 3600000.0;

  /// The three celestial anchors, in fixed order.
  static const List<EchoColorTheme> planets = [
    EchoColorTheme.teal, // APAISER
    EchoColorTheme.indigo, // CONFIER
    EchoColorTheme.lumen, // ÉCLAIRER
  ];

  /// World position of a planet at a given moment.
  static Offset planetPosition(int index, DateTime at) {
    // Polaris holds still: the fixed point of the whole turning sky
    // (V3.12 — the named heavens).
    if (index == 2) return CelestialMath.polaris;
    final phase =
        (at.millisecondsSinceEpoch + _epoch) / _periodOf(index).inMilliseconds;
    final angle = 2 * math.pi * (phase + index / planets.length);
    final radius = orbitRadiusOf(index);
    return Offset(
      blackHole.dx + radius * math.cos(angle),
      blackHole.dy + radius * math.sin(angle),
    );
  }

  // ── Echo orbits ────────────────────────────────────────────────────────

  /// The gravity band's inner edge. V3.68 — the band tightens with
  /// the system (0.11 → 0.08): the bound swarm is the world's own
  /// retinue, a compact halo — the CROWD lives free (errant).
  static const double echoBandMin = 0.08;

  /// The gravity band's width.
  static const double echoBandSpan = 0.16;

  /// V3.28 — the band is no longer a hash-continuous smear but THREE
  /// discrete shells: each ring turns as a ring, at its own fixed
  /// tempo, and the swarm reads as structure instead of a churn.
  /// Still 100% deterministic from the echo's identity.
  ///
  /// V3.67 — the shells are only the BASE of each orbit now: every
  /// bound echo rides its OWN eccentric ellipse (aphelion jitter,
  /// eccentricity, orientation and tempo hashed from its id — see
  /// [launchCoordsFor] and [echoPosition]). Three perfect rings
  /// turning in unison read, on a wide screen, as geometry — Hugo's
  /// arbitrage: the sky must read as a CROWD, not a diagram.
  ///
  /// V3.68 — compact (0.13/0.18/0.23 → 0.09/0.14/0.19, rim 0.24):
  /// the system is a jewel, its swarms tight around their worlds;
  /// most thoughts drift FREE across the whole ether.
  static const List<double> echoShells = [0.09, 0.14, 0.19];

  /// Per-echo aphelion jitter on top of the shell (0 .. value).
  static const double liaisonJitter = 0.05;

  /// Per-echo orbital eccentricity range (bound thoughts). Aphelion
  /// is bounded (shell + jitter), so the radius always stays within
  /// [aphelion × (1 - e), aphelion].
  static const double liaisonEccentricityMin = 0.08;
  static const double liaisonEccentricityMax = 0.31;

  /// V3.67 — LA PENSÉE ERRANTE: not every thought falls into a
  /// gravity well. Roughly two in five are born FREE, anywhere in
  /// the ether, and ride wide slow rings around the VOID itself —
  /// the deep sky between the worlds carries matter of its own, and
  /// the map stops being a diagram with a crowded middle. The flag
  /// derives from `created_at` (known at launch AND at render: the
  /// same input, the same verdict, forever).
  ///
  /// V3.68 — the errant are the MAJORITY now (~65%) and their rings
  /// span the whole sky (birth 0.28–0.92): the bound swarms are the
  /// worlds' own retinues, compact; the CROWD is the sky. Immensity
  /// is a scale separation — a jewel of a system, and drifters
  /// between the stars.
  static bool isErrantThought(DateTime createdAt) {
    final h = (createdAt.millisecondsSinceEpoch * 2654435761) &
        0x7fffffff;
    return h % 100 < 65;
  }

  /// One full revolution per shell (V3.22's contemplative range kept:
  /// minutes per orbit, never a carousel).
  static const List<Duration> _shellPeriods = [
    Duration(seconds: 210),
    Duration(seconds: 300),
    Duration(seconds: 390),
  ];

  /// The shell an echo rides: decided by its identity, stable forever.
  static int _echoShell(Echo echo) =>
      (echo.id.hashCode & 0x7fffffff) % echoShells.length;

  /// V3.36 — LA CHUTE DES JOURS: an unread thought's orbit decays with
  /// age. It lingers in its lane for [fallGrace] (a fresh thought
  /// sags nowhere — the sky it was launched into is the sky it keeps),
  /// then falls LINEARLY over the rest of its moon, from its shell
  /// down to [landingRadius], just off the face of the world it was
  /// confided to. The 30-day purge is the landing: what is never read
  /// comes home to its intention. The age becomes a DISTANCE — around
  /// each world, the swarm reads radially sorted by time adrift.
  ///
  /// Deterministic from `created_at`: every device sees the same
  /// falling sky. And the culling stays honest BECAUSE the fall keeps
  /// every mote within its planet's band — the stored launch
  /// coordinates remain the truth the sector fetch believes (the
  /// hole-fall variant of this law was rejected for exactly that:
  /// decayed motes rendering far from any stored coordinate the fetch
  /// could know).
  static const Duration fallGrace = Duration(hours: 48);
  static const double landingRadius = 0.02;
  static const Duration echoMoon = Duration(days: 30);

  /// How far along its fall an echo is at [at]: 0 inside the grace,
  /// 1 at the moon's end.
  static double fallFraction(Echo echo, DateTime at) {
    final age = at.difference(echo.createdAt);
    if (age <= fallGrace) return 0;
    final span = echoMoon - fallGrace;
    return ((age - fallGrace).inMilliseconds / span.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  /// Orbital period: per-shell base, JITTERED PER ECHO (V3.67 — see
  /// [liaisonEccentricityMax]: the synchronized ring-read is gone).
  static Duration _echoPeriod(Echo echo) {
    final baseMs = _shellPeriods[_echoShell(echo)].inMilliseconds;
    final h = echo.id.hashCode & 0x7fffffff;
    final jitter = 0.82 + 0.36 * ((h >> 5) % 100) / 100;
    return Duration(milliseconds: (baseMs * jitter).round());
  }

  /// Planet index for an intent: the theme decides the gravity. The
  /// rebound keeps the parent's hue — comets inherit their orbit.
  static int themeIndexOf(EchoColorTheme theme) => switch (theme) {
        EchoColorTheme.teal => 0,
        EchoColorTheme.indigo => 1,
        _ => 2,
      };

  /// Planet index for an echo: its intent decides its gravity.
  static int planetIndexOf(Echo echo) => themeIndexOf(echo.theme);

  /// V3.28 — where a new echo is BORN in the server's sky: its intent
  /// planet's live position plus a point inside the gravity band,
  /// clamped to the known ether. The sector fetch, the A.L. telemetry
  /// and the lineage anchors then agree with the rendered orbit: the
  /// author drops the thought where it will actually drift.
  ///
  /// V3.67 — a free thought ([isErrantThought]) is born anywhere in
  /// the ether, on its own wide ring around the void: birth radius
  /// 0.28–0.92 of the sky (never inside the system's retinue, out to
  /// the known rim's corners), angle free. The client computes this
  /// BEFORE the RPC — no server law moves — and the render derives
  /// the same verdict from the same `created_at`.
  static Offset launchCoordsFor(
    EchoColorTheme theme,
    DateTime at, [
    math.Random? rng,
  ]) {
    final random = rng ?? math.Random();
    if (isErrantThought(at)) {
      // Birth on the wide ring: 0.28–0.92 of the sky — the deep
      // field between the worlds, out to the known rim's corners.
      final r = 0.28 + random.nextDouble() * 0.64;
      final a = random.nextDouble() * 2 * math.pi;
      return Offset(
        (blackHole.dx + r * math.cos(a)).clamp(0.02, 0.98),
        (blackHole.dy + r * math.sin(a)).clamp(0.02, 0.98),
      );
    }
    final planet = planetPosition(themeIndexOf(theme), at);
    final radius = echoBandMin + random.nextDouble() * echoBandSpan;
    final angle = random.nextDouble() * 2 * math.pi;
    return Offset(
      (planet.dx + radius * math.cos(angle)).clamp(0.02, 0.98),
      (planet.dy + radius * math.sin(angle)).clamp(0.02, 0.98),
    );
  }

  /// World position of an echo at a given moment — the orbit everyone
  /// agrees on, derived only from the server timestamp and identity.
  static Offset echoPosition(Echo echo, DateTime at) {
    // A rebounded echo (momentum > 0) leaves its planet's gravity:
    // a COMET on an eccentric ellipse around the void, crossing the
    // three orbits — the trace of the humans who carried it. Comets
    // do not fall: they already cross everything, dying their own way.
    if (echo.momentum > 0) {
      return _cometPosition(echo, at);
    }
    // A free thought rides its own wide slow ring around the VOID:
    // radius inherited from where it was born, tempo from its id —
    // a sky of drifting strangers, desynchronized by construction.
    if (isErrantThought(echo.createdAt)) {
      final birth = Offset(echo.coordX, echo.coordY);
      final r = (birth - blackHole).distance.clamp(0.25, 0.95);
      final h = echo.id.hashCode & 0x7fffffff;
      final period = Duration(
        hours: 3 + (h % 7),
      );
      final phase =
          (at.millisecondsSinceEpoch + h % 9973) / period.inMilliseconds;
      final angle = 2 * math.pi * phase;
      return Offset(
        blackHole.dx + r * math.cos(angle),
        blackHole.dy + r * math.sin(angle),
      );
    }
    // A bound thought: its OWN eccentric ellipse around its intent
    // planet — APHELION (shell + jitter), eccentricity, orientation
    // and tempo all hashed from the identity. The halo reads as a
    // crowd of crossing arcs, never as a drawn ring.
    final planet = planetPosition(planetIndexOf(echo), at);
    final h = echo.id.hashCode & 0x7fffffff;
    // LA CHUTE DES JOURS decays the APHELION toward the world it was
    // confided to (the fall keeps the shape — only the span shrinks).
    final fall = fallFraction(echo, at);
    final freshAphelion = liaisonAphelion(echo);
    final aphelion = fall <= 0
        ? freshAphelion
        : freshAphelion + (landingRadius - freshAphelion) * fall;
    final e = liaisonEccentricity(echo);
    final omega = 2 * math.pi * ((h >> 17) % 360) / 360;
    final a = aphelion / (1 + e); // aphelion-bounded semi-major axis
    final period = _echoPeriod(echo);
    final phase =
        (at.millisecondsSinceEpoch + h % 9973) / period.inMilliseconds;
    final theta = 2 * math.pi * phase;
    final rr = a * (1 - e * e) / (1 + e * math.cos(theta));
    final x = rr * math.cos(theta + omega);
    final y = rr * math.sin(theta + omega);
    return Offset(planet.dx + x, planet.dy + y);
  }

  /// The bound echo's APHELION (farthest point from its world):
  /// its shell plus an identity-hashed jitter. Public so the fall's
  /// tests can speak the same geometry (V3.67).
  static double liaisonAphelion(Echo echo) {
    final h = echo.id.hashCode & 0x7fffffff;
    final shell = echoShells[_echoShell(echo)];
    return shell + ((h >> 3) % 61) * (liaisonJitter / 60);
  }

  /// The bound echo's orbital eccentricity (identity-hashed).
  static double liaisonEccentricity(Echo echo) {
    final h = echo.id.hashCode & 0x7fffffff;
    return liaisonEccentricityMin +
        ((h >> 11) % 100) / 100 * (liaisonEccentricityMax -
            liaisonEccentricityMin);
  }

  // ── Comets (momentum > 0) ─────────────────────────────────────────────

  /// Comet geometry, stable per echo: an eccentric ellipse whose
  /// perihelion grazes the void's neighbourhood and whose aphelion
  /// reaches past the planets — every rebound crosses every orbit.
  static double _cometEccentricity(Echo echo) =>
      // A much-carried thought travels a wilder arc.
      (0.55 + 0.06 * echo.momentum).clamp(0.55, 0.82);

  static double _cometAphelion(Echo echo) {
    final h = echo.id.hashCode & 0x7fffffff;
    return outerOrbit + 0.10 + 0.05 * (h % 7);
  }

  static double _cometOrientation(Echo echo) {
    final h = (echo.id.hashCode & 0x7fffffff);
    return 2 * math.pi * (h % 360) / 360;
  }

  static Offset _cometPosition(Echo echo, DateTime at) {
    final e = _cometEccentricity(echo);
    final aphelion = _cometAphelion(echo);
    final orientation = _cometOrientation(echo);
    final a = aphelion / (1 + e); // aphelion = a(1+e)
    // Eccentrics sweep in minutes, not hours: a comet's passage is
    /// an event you can catch, not a rumor.
    final period = Duration(
      seconds: 180 + 40 * echo.momentum + (echo.id.hashCode % 120),
    );
    final phase = (at.millisecondsSinceEpoch + echo.id.hashCode % 9973) /
        period.inMilliseconds;
    final theta = 2 * math.pi * phase;
    // Parametric ellipse (poetic, not Kepler-precise — deterministic
    // is what matters: every device draws the same comet).
    final r = a * (1 - e * e) / (1 + e * math.cos(theta));
    final x = r * math.cos(theta + orientation);
    final y = r * math.sin(theta + orientation);
    return Offset(blackHole.dx + x, blackHole.dy + y);
  }

  // ── Lineage constellations (V3.7c) ────────────────────────────────────

  /// The faint lines of a phoenix chain: for each echo carrying a
  /// parent link, a segment from the parent's sky position to the
  /// child's. The parent is usually consumed (gone from the sky) —
  /// its phantom anchor is where the thought was reborn (the child's
  /// own launch point). Links are metadata, drawn in the lineage hue.
  static List<(Offset, Offset, EchoColorTheme)> lineageSegments(
    List<Echo> echoes,
    DateTime at,
  ) {
    final byId = {for (final e in echoes) e.id: e};
    final segments = <(Offset, Offset, EchoColorTheme)>[];
    for (final echo in echoes) {
      final parentId = echo.parentId;
      if (parentId == null) continue;
      final parent = byId[parentId];
      final childPos = echoPosition(echo, at);
      final parentPos = parent != null
          ? echoPosition(parent, at)
          : Offset(echo.coordX, echo.coordY);
      segments.add((parentPos, childPos, echo.theme));
    }
    return segments;
  }
}
