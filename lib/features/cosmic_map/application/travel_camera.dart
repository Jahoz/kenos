import 'dart:ui';

/// The traveller's eye over the ether (V3.7a — Le Voyage).
///
/// The world stays the server's normalized [0,1]² (its coordinates are
/// guarded by SQL bounds), but the eye no longer owns all of it: a
/// fixed zoom shows about half the sky at once, and one glides the
/// void to travel. The camera may drift slightly BEYOND the known
/// ether ([-margin, 1+margin]) — travelling to the edge means reaching
/// into emptiness, and emptiness is the point.
class TravelCamera {
  TravelCamera({
    this.zoom = 1.75,
    this.margin = 0.1,
    Offset center = const Offset(0.5, 0.5),
  }) : _center = center;

  /// How much of the world fills the screen at once (1.75 → ~57%).
  final double zoom;

  /// How far past the known ether the void still carries the eye.
  final double margin;

  Offset _center;

  /// Camera center in world coordinates.
  Offset get center => _center;

  /// Cumulative travelled distance, in Années-Lumière poetics
  /// (1 world unit = 1 A.L. — the speed of the void).
  double _drift = 0;
  double get drift => _drift;

  /// Fraction of the world visible on one axis.
  double get viewExtent => 1 / zoom;

  /// World-space rect currently visible (with [margin] slack).
  ({double minX, double minY, double maxX, double maxY}) get visibleRect {
    final half = viewExtent / 2;
    final c = _center;
    return (
      minX: c.dx - half,
      minY: c.dy - half,
      maxX: c.dx + half,
      maxY: c.dy + half,
    );
  }

  /// Pan by a screen-space delta, given the viewport size in logical
  /// pixels. Returns the applied world delta.
  Offset panByScreen(Offset screenDelta, Size viewport) {
    final worldDelta = Offset(
      screenDelta.dx / viewport.width * viewExtent,
      screenDelta.dy / viewport.height * viewExtent,
    );
    return panByWorld(-worldDelta);
  }

  /// Pan by a world-space delta (dragging the void moves the eye the
  /// opposite way — the sky follows the finger).
  Offset panByWorld(Offset worldDelta) {
    final next = _clamped(_center + worldDelta);
    final applied = next - _center;
    _center = next;
    _drift += applied.distance;
    return applied;
  }

  /// Recentre on the heart of the ether (RECALIBRER).
  void recenter() {
    _center = const Offset(0.5, 0.5);
  }

  /// World point → screen point for a given viewport.
  Offset worldToScreen(Offset world, Size viewport) => Offset(
        (world.dx - _center.dx) / viewExtent * viewport.width +
            viewport.width / 2,
        (world.dy - _center.dy) / viewExtent * viewport.height +
            viewport.height / 2,
      );

  Offset _clamped(Offset c) => Offset(
        c.dx.clamp(-margin + viewExtent / 2, 1.0 + margin - viewExtent / 2),
        c.dy.clamp(-margin + viewExtent / 2, 1 + margin - viewExtent / 2),
      );

  /// Poetic drift label: "0.42 A.L." (two decimals, French dot kept
  /// machine-voiced as HUD).
  String get driftLabel {
    final ly = _drift;
    if (ly < 0.01) return '0.00 A.L.';
    if (ly >= 100) return '${ly.toStringAsFixed(0)} A.L.';
    return '${ly.toStringAsFixed(2)} A.L.';
  }
}

/// Inertia: a velocity decays along a FrictionPhase — plain math so
/// tests can pin the glide without a ticker.
class DriftGlide {
  DriftGlide({this.decay = 0.94});

  /// Multiplicative decay per 16 ms step.
  final double decay;

  static const _step = Duration(milliseconds: 16);

  /// Positions of the glide over time, until the speed dies. World
  /// deltas per step, for the camera to consume.
  Iterable<Offset> path(Offset velocityPerSecond) sync* {
    var v = velocityPerSecond * (_step.inMicroseconds / 1e6);
    while (v.distance > 0.0005) {
      yield v;
      v *= decay;
    }
  }

  /// Total distance the glide would cover (for tests).
  double totalDistance(Offset velocityPerSecond) => path(velocityPerSecond)
      .map((d) => d.distance)
      .fold(0.0, (a, b) => a + b);
}
