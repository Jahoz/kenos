import 'dart:math' as math;
import 'dart:ui';

import '../../echo/domain/echo.dart';
import '../../echo/domain/echo_color_theme.dart';

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

  /// Orbital radius of each planet around the void (world units).
  static const double planetOrbit = 0.32;

  /// One full planetary revolution — slow enough to feel eternal,
  /// fast enough to notice between two visits (~6 h).
  static const Duration planetPeriod = Duration(hours: 6);

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
    final phase =
        (at.millisecondsSinceEpoch + _epoch) / planetPeriod.inMilliseconds;
    final angle = 2 * math.pi * (phase + index / planets.length);
    return Offset(
      blackHole.dx + planetOrbit * math.cos(angle),
      blackHole.dy + planetOrbit * math.sin(angle),
    );
  }

  // ── Echo orbits ────────────────────────────────────────────────────────

  /// An echo's orbit: its planet's gravity, at a radius derived from
  /// its identity (stable per echo, spread across a band).
  static double _echoOrbitRadius(Echo echo) {
    final h = (echo.id.hashCode & 0x7fffffff) % 1000;
    return 0.045 + 0.075 * (h / 999);
  }

  /// Orbital period from the radius: inner thoughts whirl faster
  /// (Kepler-flavored, deliberately poetic rather than physical).
  static Duration _echoPeriod(Echo echo) {
    final r = _echoOrbitRadius(echo);
    return Duration(seconds: (240 * r / 0.08).round().clamp(90, 300));
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
}
