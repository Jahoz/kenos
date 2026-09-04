import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import 'kenos_system.dart';

/// V3.12b — accretion: what dies here does not scatter, it FALLS.
///
/// When an echo burns (its reading window closes, or ashes were
/// chosen) — and when a star dissolves under one's fingers, claimed
/// elsewhere — its last sky position is fed to the black hole. The map
/// animates the mote spiralling into the rose accretion ring: the
/// destruction colour's only celestial object swallows its own.
class AccretionMote {
  const AccretionMote({required this.origin, required this.at, this.tint});

  /// World position where the object died.
  final Offset origin;

  /// When the fall began.
  final DateTime at;

  /// The dead echo's hue — the mote reddens as it falls.
  final Color? tint;
}

/// One fall lasts this long (world spirals are not rushed).
const Duration accretionFall = Duration(milliseconds: 1900);

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
}

final accretionProvider =
    NotifierProvider<AccretionController, List<AccretionMote>>(
  AccretionController.new,
);
