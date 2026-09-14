import 'dart:math' as math;
import 'dart:ui';

/// V3.34 — the deep field: scenery with DEPTH of travel.
///
/// The ambient background (nebulae, dead stars) moves with the tilt but
/// stays screen-fixed while the eye travels — a backdrop, not a world.
/// The deep field is the universe BEHIND the ether: dust anchored in
/// world space, riding slower layers (factor < 1) so every pan of the
/// void reads as a passage, not a scroll. Scenery, never matter:
/// nothing to read, nothing to catch, nothing counted — the reception
/// law, the HUD and the glimmers never see it.
///
/// Deterministic by seed (a stable LCG, not `Random`: its seeded
/// sequence is implementation-defined, and the far sky must be the same
/// on every device).
class DeepFieldLayer {
  const DeepFieldLayer({
    required this.factor,
    required this.dustCount,
    required this.radiusMin,
    required this.radiusMax,
    required this.alphaMin,
    required this.alphaMax,
    required this.seed,
  });

  /// Travel speed as a fraction of the world's: 0.30 = the far field,
  /// 0.55 = the nearer drift. Below 1 by law — deep scenery never
  /// outruns the ether it lies behind.
  final double factor;

  /// Motes of dust in the layer.
  final int dustCount;

  /// Core radius range, logical pixels at the resting eye.
  final double radiusMin;
  final double radiusMax;

  /// Opacity range. What keeps dust from reading as a light that
  /// could be approached is not alpha alone (a far-dim glimmer can be
  /// paler): dust is TINY (≤ 1.5 px against the glimmer cores' ≥ 3.6)
  /// and white where glimmers carry their theme's colour.
  final double alphaMin;
  final double alphaMax;

  /// The layer's deterministic seed.
  final int seed;
}

const List<DeepFieldLayer> deepFieldLayers = [
  DeepFieldLayer(
    factor: 0.30,
    dustCount: 90,
    radiusMin: 0.35,
    radiusMax: 0.9,
    alphaMin: 0.04,
    alphaMax: 0.10,
    seed: 20260914,
  ),
  DeepFieldLayer(
    factor: 0.55,
    dustCount: 48,
    radiusMin: 0.6,
    radiusMax: 1.5,
    alphaMin: 0.06,
    alphaMax: 0.16,
    seed: 104729,
  ),
];

/// One mote of far dust: a position in the decor plane, its size and
/// its alpha. Immutable — the field does not breathe, it only recedes.
class DeepFieldDust {
  const DeepFieldDust({
    required this.at,
    required this.radius,
    required this.alpha,
  });

  final Offset at;
  final double radius;
  final double alpha;
}

/// Pure math of the deep field — the transform every device agrees on.
class DeepFieldMath {
  DeepFieldMath._();

  /// The world's heart: the anchor the parallax factors pull toward
  /// (at rest, decor and world coordinates coincide).
  static const Offset base = Offset(0.5, 0.5);

  /// The decor plane: dust lives beyond the known ether so the
  /// traveller's margin never reaches past it (coverage is pinned by
  /// test across every legal camera state).
  static const double planeMin = -0.25;
  static const double planeMax = 1.25;

  /// The layer's eye: the camera's displacement from home, damped by
  /// the layer factor. A pan of δ moves the world by δ and the layer
  /// by δ·factor — the receding universe.
  static Offset effectiveCenter(Offset center, double factor) => Offset(
        base.dx + (center.dx - base.dx) * factor,
        base.dy + (center.dy - base.dy) * factor,
      );

  /// The layer's zoom: deep layers grow less under the pinch (a factor
  /// of 0.55 at zoom 8 sees only 4.85×, not 8×).
  static double effectiveZoom(double zoom, double factor) =>
      1.0 + (zoom - 1.0) * factor;

  /// How dust sizes breathe with the eye — damped like the zoom,
  /// gentler than the bodies' own `zoomScale` (dust stays dust, never
  /// a disc). Normalized by the LAYER's own resting zoom, so every
  /// layer's dust carries its designed size at the resting eye.
  static double sizeScale(double zoom, double factor) => math.pow(
        effectiveZoom(zoom, factor) / effectiveZoom(1.75, factor),
        0.35,
      ).toDouble();

  /// Decor-plane point → screen point, the deep field's own camera.
  static Offset worldToScreen(
    Offset dust, {
    required Offset center,
    required double zoom,
    required double factor,
    required Size viewport,
  }) {
    final ve = 1.0 / effectiveZoom(zoom, factor);
    final c = effectiveCenter(center, factor);
    return Offset(
      (dust.dx - c.dx) / ve * viewport.width + viewport.width / 2,
      (dust.dy - c.dy) / ve * viewport.height + viewport.height / 2,
    );
  }
}

/// Stable LCG (Lehmer, same constants as the sky map's schematic):
/// identical arithmetic on every platform.
class StableRandom {
  StableRandom(int seed) : _state = seed % 2147483647;

  int _state;

  double next() {
    _state = (_state * 48271) % 2147483647;
    return _state / 2147483647;
  }
}

/// The layer's dust, deterministic forever: same seed, same sky.
List<DeepFieldDust> deepFieldDust(int layerIndex) {
  final layer = deepFieldLayers[layerIndex];
  final rng = StableRandom(layer.seed);
  return List.generate(
    layer.dustCount,
    (_) => DeepFieldDust(
      at: Offset(
        DeepFieldMath.planeMin +
            rng.next() * (DeepFieldMath.planeMax - DeepFieldMath.planeMin),
        DeepFieldMath.planeMin +
            rng.next() * (DeepFieldMath.planeMax - DeepFieldMath.planeMin),
      ),
      radius: layer.radiusMin + rng.next() * (layer.radiusMax - layer.radiusMin),
      alpha: layer.alphaMin + rng.next() * (layer.alphaMax - layer.alphaMin),
    ),
  );
}
