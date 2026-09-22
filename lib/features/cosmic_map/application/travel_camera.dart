import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The traveller's eye over the ether (V3.7a — Le Voyage).
///
/// The world stays the server's normalized [0,1]² (its coordinates are
/// guarded by SQL bounds), but the eye no longer owns all of it: a
/// fixed zoom shows about two fifths of the sky at once, and one
/// glides the void to travel (V3.61: the resting eye held 57% and the
/// sky read as a crowded sheet — it now holds ~42%, the void leads).
///
/// V3.40 — the traversable void extends WELL past the known ether
/// (margin 0.5 → the eye rides [-0.5, 1.5]): the worlds and their
/// rings are CIRCLES in a SQUARE ether — the wanderers (r up to 0.65)
/// step past the square's rim along the axes, and Venus at her aphelion
/// hugged the old +0.1 wall, hard to reach and reading like the edge
/// of a box. Beyond the last light there is now REAL reachable
/// emptiness — the far country is genuinely vast, every named body is
/// centerable, and "the void is more vast" is a traversable truth.
///
/// A [ChangeNotifier]: gestures mutate the eye and ONLY the layers
/// that look through it rebuild — the screen, the HUD and the gates
/// never spend a frame on a pan.
class TravelCamera extends ChangeNotifier {
  TravelCamera({
    double zoom = 1.25,
    this.margin = 0.65,
    Offset center = const Offset(0.5, 0.5),
  })  : _zoom = zoom.clamp(minZoom, maxZoom),
        _center = center;

  /// How much of the world fills the screen at once (1.25 → ~80% of
  /// the short side). V3.68 — the gaze pulls back: the system (V3.67's
  /// lanes and halos) was WIDER than the old 1.7 window — the eye
  /// lived INSIDE the retinue, and no rearrangement of matter could
  /// read as immensity from within. At 1.25 the system is a JEWEL in
  /// the middle distance and the sky carries it.
  double _zoom;
  double get zoom => _zoom;

  /// Pinch bounds: deep enough to split the tightest clusters (8×
  /// separates stars born a few pixels apart), never a map of pixels.
  /// V3.64 — the survey floor opens (1.2 → 1.0): the whole known
  /// ether in one gaze, a majestic map — far lights, nothing at hand.
  static const double minZoom = 1.0;
  static const double maxZoom = 8.0;

  /// V3.40 — the traversable void extends WELL past the known ether
  /// (the eye rides [-0.65, 1.65]): the worlds and their rings are
  /// CIRCLES in a SQUARE ether — the wanderers (r up to 0.65) step
  /// past the square's rim along the axes, and Venus at her aphelion
  /// hugged the old +0.1 wall, hard to reach and reading like the
  /// edge of a box. Beyond the last light there is now REAL reachable
  /// emptiness — the far country is genuinely vast, every named body
  /// is centerable, and "the void is more vast" is a traversable
  /// truth. V3.68 — the margin widens with the pulled-back gaze
  /// (0.5 → 0.65): at the 1.25 window the old walls would have
  /// caged the named heavens again — immensity must be REACHABLE.
  final double margin;

  Offset _center;

  /// Camera center in world coordinates.
  Offset get center => _center;

  /// Cumulative travelled distance, in Années-Lumière poetics
  /// (1 world unit = 1 A.L. — the speed of the void).
  double _drift = 0;
  double get drift => _drift;

  /// Fraction of the world visible along the SHORT axis. V3.65 — the
  /// long axis used to stretch the SAME fraction: a 16:10 tablet drew
  /// the square ether 1.6× wide (elliptical orbits, a bunched
  /// diagonal, wasted edges). The scale is uniform now — the width is
  /// more world, never a stretch.
  double get viewExtent => 1 / zoom;

  /// Screen pixels per world unit — one scale for both axes. This is
  /// the whole V3.65 law: circles stay circles on every aspect.
  double pxPerWorld(Size viewport) => viewport.shortestSide / viewExtent;

  /// The projection's viewport, attached by the layout. Until the
  /// first layout the clamps assume the square gaze of a phone.
  Size? _attached;

  /// Tell the camera the aspect it looks through (rect walls depend
  /// on it). Silent on purpose — layouts fire often.
  void attach(Size viewport) {
    if (_attached == viewport) return;
    _attached = viewport;
    _center = _clamped(_center); // the walls moved with the aspect
  }

  /// Half of the visible world along each axis — the view is a RECT:
  /// [viewExtent] on the short side, scaled by the aspect on the long
  /// one (a 16:10 tablet sees 1.6× more width, unstretched).
  double get _halfW {
    final v = _attached;
    return v == null
        ? viewExtent / 2
        : viewExtent / 2 * (v.width / v.shortestSide);
  }

  double get _halfH {
    final v = _attached;
    return v == null
        ? viewExtent / 2
        : viewExtent / 2 * (v.height / v.shortestSide);
  }

  /// World-space rect currently visible (with [margin] slack).
  ({double minX, double minY, double maxX, double maxY}) get visibleRect {
    final c = _center;
    return (
      minX: c.dx - _halfW,
      minY: c.dy - _halfH,
      maxX: c.dx + _halfW,
      maxY: c.dy + _halfH,
    );
  }

  /// Pan by a screen-space delta, given the viewport size in logical
  /// pixels. Returns the applied world delta.
  Offset panByScreen(Offset screenDelta, Size viewport) =>
      panByWorld(-(screenDelta / viewport.shortestSide * viewExtent));

  /// Pan by a world-space delta (dragging the void moves the eye the
  /// opposite way — the sky follows the finger).
  Offset panByWorld(Offset worldDelta) {
    final next = _clamped(_center + worldDelta);
    final applied = next - _center;
    _center = next;
    _drift += applied.distance;
    if (applied != Offset.zero) notifyListeners();
    return applied;
  }

  /// Pinch: zoom by [factor], keeping the world point under the
  /// fingers where it is (the focal point anchors the zoom).
  void zoomBy(double factor, Offset focalWorldPoint) {
    final previousZoom = _zoom;
    _zoom = (_zoom * factor).clamp(minZoom, maxZoom);
    final applied = _zoom / previousZoom;
    if (applied == 1.0) return;
    // Keep the focal world point at the same screen position:
    // (f - c') / ve' = (f - c) / ve  and  ve' = ve / applied, so
    // center' = focal - (focal - center) / applied.
    final target = focalWorldPoint -
        (focalWorldPoint - _center) / applied;
    _center = _clamped(target);
    notifyListeners();
  }

  /// Recentre on the heart of the ether (RECALIBRER).
  void recenter() {
    if (_center == const Offset(0.5, 0.5)) return;
    _center = const Offset(0.5, 0.5);
    notifyListeners();
  }

  /// World point → screen point for a given viewport (uniform scale:
  /// the short side carries [viewExtent], the long side carries more
  /// world — V3.65).
  Offset worldToScreen(Offset world, Size viewport) {
    final scale = pxPerWorld(viewport);
    return Offset(
      (world.dx - _center.dx) * scale + viewport.width / 2,
      (world.dy - _center.dy) * scale + viewport.height / 2,
    );
  }

  /// Screen point → world point — the pinch anchor and the taps,
  /// inverse of [worldToScreen].
  Offset screenToWorld(Offset screen, Size viewport) {
    final scale = pxPerWorld(viewport);
    return Offset(
      (screen.dx - viewport.width / 2) / scale + _center.dx,
      (screen.dy - viewport.height / 2) / scale + _center.dy,
    );
  }

  Offset _clamped(Offset c) => Offset(
        c.dx.clamp(-margin + _halfW, 1.0 + margin - _halfW),
        c.dy.clamp(-margin + _halfH, 1 + margin - _halfH),
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


/// Where the traveller's eye rests in the world — the map writes it,
/// the Symphonie reads it: waves are heard around WHERE YOU ARE, not
/// around your last tap. The music of the spheres is local.
final travelPositionProvider =
    StateProvider<Offset>((ref) => const Offset(0.5, 0.5));
