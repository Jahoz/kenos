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
  static const double blackHoleExclusion = 0.15;

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

  /// Each anchor rides its OWN lane (V3.12): the Moon closer and
  /// livelier, Venus wider and slower — the tracks never smear into
  /// one another, conjunctions stay rare. Polaris rides none.
  static double orbitRadiusOf(int index) =>
      switch (index) { 0 => 0.26, _ => 0.37 };

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

  /// An echo's orbit: its planet's gravity, at a radius derived from
  /// its identity (stable per echo, spread across a band).
  static double _echoOrbitRadius(Echo echo) {
    final h = (echo.id.hashCode & 0x7fffffff) % 1000;
    return 0.045 + 0.075 * (h / 999);
  }

  /// Orbital period from the radius: inner thoughts whirl faster —
  /// and the whole clock runs at a contemplative-but-alive pace
  /// (15–60 s per orbit: you SEE the drift if you linger).
  static Duration _echoPeriod(Echo echo) {
    final r = _echoOrbitRadius(echo);
    return Duration(seconds: (90 * r / 0.08).round().clamp(25, 75));
  }

  /// Planet index for an echo: its intent decides its gravity. The
  /// rebound keeps the parent's hue — comets inherit their orbit.
  static int planetIndexOf(Echo echo) =>
      switch (echo.theme) {
        EchoColorTheme.teal => 0,
        EchoColorTheme.indigo => 1,
        _ => 2,
      };

  /// World position of an echo at a given moment — the orbit everyone
  /// agrees on, derived only from the server timestamp and identity.
  static Offset echoPosition(Echo echo, DateTime at) {
    // A rebounded echo (momentum > 0) leaves its planet's gravity:
    // a COMET on an eccentric ellipse around the void, crossing the
    // three orbits — the trace of the humans who carried it.
    if (echo.momentum > 0) {
      return _cometPosition(echo, at);
    }
    final planet = planetPosition(planetIndexOf(echo), at);
    final radius = _echoOrbitRadius(echo);
    final period = _echoPeriod(echo);
    final phase = (at.millisecondsSinceEpoch + echo.id.hashCode % 9973) /
        period.inMilliseconds;
    final angle = 2 * math.pi * phase;
    return Offset(
      planet.dx + radius * math.cos(angle),
      planet.dy + radius * math.sin(angle),
    );
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
