import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import 'kenos_system.dart';
import 'travel_camera.dart';

/// V3.12b — accretion: what dies here does not scatter, it FALLS.
///
/// When an echo burns (its reading window closes, or ashes were
/// chosen) — and when a star dissolves under one's fingers, claimed
/// elsewhere — its last sky position is fed to the black hole. The map
/// animates the mote spiralling into the rose accretion ring: the
/// destruction colour's only celestial object swallows its own.
class AccretionMote {
  const AccretionMote({
    required this.origin,
    required this.at,
    this.tint,
    this.rising = false,
  });

  /// World position where the object died (or, when [rising], where
  /// the phoenix was re-sealed).
  final Offset origin;

  /// When the fall (or the rise) began.
  final DateTime at;

  /// The echo's hue — a falling mote warms toward the rose horizon.
  final Color? tint;

  /// V3.12c — the phoenix's streak: instead of falling into the hole,
  /// the mote RISES from where the thought was read and fades into
  /// the ether for its next reader.
  final bool rising;
}

/// One fall lasts this long (world spirals are not rushed). V3.87 —
/// 3.8 s: at reading depth the gouffre sits off-frame and only the
/// DEPARTURE spiral is visible — at 1.9 s that was ~0.6 s of screen
/// time, "pas le temps de voir quoi que ce soit" (the live report).
/// Doubling the fall doubles the visible wound around the dead star;
/// the plunge itself stays the gouffre's secret (the whisper says it).
const Duration accretionFall = Duration(milliseconds: 3800);

class AccretionController extends Notifier<List<AccretionMote>> {
  @override
  List<AccretionMote> build() => const <AccretionMote>[];

  /// Feeds the hole. Prunes finished falls (older than twice their
  /// life — generous, the painter stops drawing at t=1 anyway).
  void feed(Offset worldOrigin, {Color? tint}) {
    final now = DateTime.now();
    final alive = state
        .where((m) => now.difference(m.at) < accretionFall * 2)
        .toList();
    state = [
      ...alive,
      AccretionMote(origin: worldOrigin, at: now, tint: tint),
    ];
  }

  /// The phoenix's launch: a streak rising from [worldOrigin].
  void feedRising(Offset worldOrigin, {Color? tint}) {
    final now = DateTime.now();
    final alive = state
        .where((m) => now.difference(m.at) < accretionFall * 2)
        .toList();
    state = [
      ...alive,
      AccretionMote(origin: worldOrigin, at: now, tint: tint, rising: true),
    ];
  }

  /// The fall's parameters at progress [t] (0..1): the spiral closes
  /// as it accelerates — gravity wins at the end.
  static (double radius, double angle) spiralAt(
    AccretionMote mote,
    double t,
  ) {
    final v = mote.origin - KenosSystem.blackHole;
    final r0 = v.distance;
    final theta0 = v.distance < 1e-9 ? -1.5707963267948966 : v.direction;
    final ease = Curves.easeIn.transform(t);
    final radius = r0 * (1 - ease);
    // ~1.6 turns, accelerating: the last quarter-turn is a plunge.
    final angle = theta0 + 2 * 3.141592653589793 * 1.6 * ease * (2.2 - 1.2 * ease);
    return (radius, angle);
  }

  /// The mote's colour: its own hue warming toward the accretion rose
  /// as the horizon nears.
  static Color colorAt(AccretionMote mote, double t) {
    final base = mote.tint ?? AppColors.pureLight;
    return Color.lerp(base, AppColors.roseText, Curves.easeIn.transform(t))!;
  }

  /// V3.82 — THE HOLE FED UNSEEN: is the gouffre outside the traveller's
  /// frame? A fall plays from the dead star into the hole's rose
  /// horizon — at deep reading zoom the gouffre sits several windows
  /// away and the whole spiral happens off-stage: the destruction is
  /// true but silent. The sky then says it once, in the HUD's machine
  /// voice — the death is never rumor.
  static bool holeOffStage(TravelCamera camera, Size viewport) {
    final sp = camera.worldToScreen(KenosSystem.blackHole, viewport);
    const m = 40.0; // the painter's own body-cull courtesy
    return sp.dx < -m ||
        sp.dx > viewport.width + m ||
        sp.dy < -m ||
        sp.dy > viewport.height + m;
  }
}

final accretionProvider =
    NotifierProvider<AccretionController, List<AccretionMote>>(
  AccretionController.new,
);
