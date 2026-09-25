import 'dart:math' as math;
import 'dart:ui';

import '../../../core/heavens/heavens.dart';
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
  static const Offset blackHole = Heavens.blackHole;

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
    // The beacon: Polaris keeps a clear sky. V3.76 — she holds the
    // far corner: the outward push has nowhere to go (the square's
    // wall), so the degenerate on-beacon case dodges TOWARD the
    // heart instead of into the clamp.
    final toBeacon = q - CelestialMath.polaris;
    if (toBeacon.distance < clearance + 0.02 && toBeacon.distance >= 0) {
      final away = toBeacon.distance < 1e-9
          ? ((blackHole - CelestialMath.polaris) / (blackHole - CelestialMath.polaris).distance)
          : toBeacon / toBeacon.distance;
      q = CelestialMath.polaris + away * (clearance + 0.02);
    }
    // The others: a deterministic GOLDEN SCATTER. Repulsion alone
    // squeezes clusters; instead, a stacked body takes the next
    // golden-angle station on a ring around its first collision —
    // clusters bloom apart, never through each other.
    // V3.76 — the bloom's PHASE is the body's own: with one shared
    // phase every collision in the sky hopped the SAME way, and the
    // library smeared east ("toujours concentrés à droite"). Each
    // body now blooms from its own bearing — collisions scatter in
    // every direction.
    final base = q;
    const golden = 2.399963229728653; // radians, the golden angle
    final basePhase = (base.dx * 917.0 + base.dy * 613.0) % (2 * math.pi);
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
      final angle = n * golden + basePhase;
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
  /// heart grew to flagship scale; its retinue now rings it INSIDE the
  /// first gaze, yet stays clear of the reception field (0.16):
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
  ///
  /// The radii live in [Heavens] now (the world's own astronomy,
  /// shared with the ether's data layer) — delegated, one law.
  static double orbitRadiusOf(int index) => Heavens.orbitRadiusOf(index);

  /// One full revolution of the innermost lane (legacy reference).
  static const Duration planetPeriod = Duration(minutes: 40);

  /// The outermost planetary lane — beyond it only comets and
  /// wanderers travel.
  static double get outerOrbit => orbitRadiusOf(1);

  /// The three celestial anchors, in fixed order.
  static const List<EchoColorTheme> planets = [
    EchoColorTheme.teal, // APAISER
    EchoColorTheme.indigo, // CONFIER
    EchoColorTheme.lumen, // ÉCLAIRER
  ];

  /// World position of a planet at a given moment (the heavens'
  /// own law — delegated to [Heavens], the shared deterministic
  /// astronomy).
  static Offset planetPosition(int index, DateTime at) =>
      Heavens.planetPosition(index, at);

  // ── Echo orbits ────────────────────────────────────────────────────────

  /// V3.75/76 — THE FAR BAND: where an aged thought rides at its
  /// moon's end (0.38 from its world — the system opened with the
  /// lanes), drawn as the one whisper ring around each planet. The
  /// three-shell diagram is retired with the void-ring errants: the
  /// swarm is a CROWD of own ellipses, aged by distance (see
  /// [orbitAphelion]).
  static const double echoFarBand = 0.38;

  /// Per-echo orbital eccentricity range. Aphelion is bounded, so the
  /// radius always stays within [aphelion × (1 - e), aphelion].
  static const double liaisonEccentricityMin = 0.08;
  static const double liaisonEccentricityMax = 0.31;

  /// V3.75 — THE CONSTITUTION (the flag derives from `created_at`;
  /// the law lives in [Heavens], shared with the ether's data layer).
  /// Moon-companions: ~1 in 6, a tight court around one of the lunes.
  static bool ridesAMoon(DateTime createdAt) =>
      Heavens.ridesAMoon(createdAt);

  // ── V3.75 — THE AGING LAW ────────────────────────────────────────────
  // A thought's distance from its body IS its age: born tight (0.03)
  // against its world (or 0.025 against its moon), the orbit widens
  // over the memory moon to the far band — older thoughts ride higher
  // and slower, dimming as they recede (the star's age factor). What
  // is never read drifts away: the memory recedes as it ages. La
  // chute des jours is retired — thoughts no longer fall home; they
  // recede instead, and the 30-day purge meets them at the rim.

  /// The memory moon: days a thought takes to ride from its body's
  /// face to the far band (the purge horizon stands).
  static const Duration memoryMoon = Duration(days: 30);

  /// Age as a 0..1 fraction of the memory moon.
  static double ageFraction(Echo echo, DateTime at) =>
      (at.difference(echo.createdAt).inMilliseconds /
              memoryMoon.inMilliseconds)
          .clamp(0.0, 1.0);

  /// The orbit's far point (aphelion) at a moment: near when young,
  /// the far band when old. Moon-companions stay tight to their lune
  /// (courtiers, not migrants).
  static double orbitAphelion(Echo echo, DateTime at) {
    final t = ageFraction(echo, at);
    final h = echo.id.hashCode & 0x7fffffff;
    final jitter = ((h >> 3) % 100) / 100 * 0.04; // identity's own span
    final moonCourt = Heavens.ridesAMoon(echo.createdAt);
    final near = moonCourt ? 0.025 : 0.030;
    final far = moonCourt ? 0.10 : echoFarBand;
    return near + (far - near) * t + jitter;
  }

  /// The orbit's period at a moment: quick when young and near,
  /// slower as the thought rides higher (Kepler's courtesy) — still
  /// minutes per orbit, never a carousel (V3.22's law holds).
  static Duration orbitPeriod(Echo echo, DateTime at) {
    final t = ageFraction(echo, at);
    final h = echo.id.hashCode & 0x7fffffff;
    final jitter = 0.82 + 0.36 * ((h >> 5) % 100) / 100;
    final seconds = (150 + 390 * t) * jitter;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Planet index for an intent: the theme decides the gravity. The
  /// rebound keeps the parent's hue — comets inherit their orbit.
  /// (The binding is the theme's own law: [EchoColorTheme.skyPlanetIndex].)
  static int themeIndexOf(EchoColorTheme theme) => theme.skyPlanetIndex;

  /// Planet index for an echo: its intent decides its gravity.
  static int planetIndexOf(Echo echo) => themeIndexOf(echo.theme);

  /// V3.75 — where a new echo is BORN in the server's sky: BESIDE ITS
  /// BODY (its intent planet, or its moon for a companion — see
  /// [Heavens.launchCoordsForPlanet], one law shared with the demo
  /// ether's seeding). The client computes this BEFORE the RPC — no
  /// server law moves — and the render derives the same verdict from
  /// the same `created_at`.
  static Offset launchCoordsFor(
    EchoColorTheme theme,
    DateTime at, [
    math.Random? rng,
  ]) =>
      Heavens.launchCoordsForPlanet(theme.skyPlanetIndex, at, rng);

  /// V3.75 — THE CONSTITUTION: every echo orbits a BODY by its type.
  /// Comet (momentum > 0): unchanged, it crosses everything.
  /// Moon-companion ([Heavens.ridesAMoon], ~1 in 6): a tight court
  /// around one of the lunes, carried across the sky — found by
  /// travelling. Every other thought: its OWN eccentric ellipse
  /// around its intent planet, the span and tempo set by its AGE
  /// (near is young, far is old, slow is old). The void-ring
  /// "errant" law is retired: nothing orbits the emptiness.
  static Offset echoPosition(Echo echo, DateTime at) {
    // A rebounded echo (momentum > 0) leaves its planet's gravity:
    // a COMET on an eccentric ellipse around the void, crossing the
    // three orbits — the trace of the humans who carried it. Comets
    // do not age: they already cross everything, dying their own way.
    if (echo.momentum > 0) {
      return _cometPosition(echo, at);
    }
    final h = echo.id.hashCode & 0x7fffffff;
    final body = Heavens.ridesAMoon(echo.createdAt)
        ? Heavens.wandererPosition((h >> 7) % Heavens.wandererCount, at)
        : planetPosition(planetIndexOf(echo), at);
    final aphelion = orbitAphelion(echo, at);
    final e = liaisonEccentricity(echo);
    final omega = 2 * math.pi * ((h >> 17) % 360) / 360;
    final a = aphelion / (1 + e); // aphelion-bounded semi-major axis
    final period = orbitPeriod(echo, at);
    final phase =
        (at.millisecondsSinceEpoch + h % 9973) / period.inMilliseconds;
    final theta = 2 * math.pi * phase;
    final rr = a * (1 - e * e) / (1 + e * math.cos(theta));
    final x = rr * math.cos(theta + omega);
    final y = rr * math.sin(theta + omega);
    return Offset(body.dx + x, body.dy + y);
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
    // V3.70 — the aphelion reaches into the median's deep half
    // (0.63-1.08, was 0.48-0.73): every rebound now crosses the WHOLE
    // middle country — each passage asserts the extent the survey
    // implies.
    return outerOrbit + 0.25 + 0.15 * (h % 4);
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
