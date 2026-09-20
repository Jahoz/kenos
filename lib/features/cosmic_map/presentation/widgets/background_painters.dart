import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Background dead star field: painted (no widgets), slow twinkle,
/// minimal parallax — this is scenery, not matter.
///
/// The void leads: magnitudes follow a power law (a skyful of barely
/// there dust, a handful of beacons) and the layers lean far-heavy,
/// so the black breathes between stars. A uniform speckle reads as
/// fabric; depth variance reads as distance (V3.60e — the sky was a
/// texture, it becomes a space).
///
/// V3.63 — the field rides the ether's PRESENCE: leaving the known
/// ether thins the dead sky itself (the kept stars are a random
/// subset — sparser, then none), and the survivors dim. The far
/// country is EMPTY, not decorated.
class BackgroundStarFieldPainter extends CustomPainter {
  BackgroundStarFieldPainter({
    required this.time,
    required this.tiltX,
    required this.tiltY,
    this.starCount = 96,
    this.presence = 1.0,
  });

  final double time;
  final double tiltX;
  final double tiltY;
  final int starCount;

  /// V3.63 — 1.0 inside the known ether, 0.0 in the far country
  /// (see [ParallaxMath.etherPresence]).
  final double presence;

  /// V3.66 — the sky is dealt once, then only breathes: star
  /// parameters (position, magnitude, twinkle phase, presence
  /// ticket) are generated ONCE per star budget — the same seeded
  /// sequence as the live deal — and every frame only reads them.
  /// Regenerating 240 stars of RNG + pow per paint read as jank on
  /// tablets (the painter repaints with every twinkle tick).
  static List<List<({double x, double y, double depth, double r, double a,
      double ticket, double phase, double speed, double twinkle})>>? _cache;
  static int _cacheStarTotal = -1;

  static List<List<({double x, double y, double depth, double r, double a,
      double ticket, double phase, double speed, double twinkle})>> _deal(
      int starTotal) {
    // Three depth layers, far-heavy: the distant shell carries most
    // of the stars as near-invisible dust, the near one carries few.
    const layers = <({
      double share,
      double depthMin,
      double depthSpan,
      double parallax,
      double rMin,
      double rMax,
      double aMin,
      double aMax,
      double twinkle,
    })>[
      (
        share: 0.50, depthMin: 0.10, depthSpan: 0.20, parallax: 4.0,
        rMin: 0.3, rMax: 0.6, aMin: 0.02, aMax: 0.09, twinkle: 0.25,
      ),
      (
        share: 0.33, depthMin: 0.38, depthSpan: 0.20, parallax: 6.5,
        rMin: 0.4, rMax: 1.0, aMin: 0.05, aMax: 0.22, twinkle: 0.35,
      ),
      (
        share: 0.17, depthMin: 0.66, depthSpan: 0.20, parallax: 9.0,
        rMin: 0.5, rMax: 1.6, aMin: 0.08, aMax: 0.50, twinkle: 0.45,
      ),
    ];
    // Positions live in FRACTIONS of the sky: the same deal fits
    // every size, only the parallax offset is applied at paint.
    return [
      for (var layer = 0; layer < layers.length; layer++)
        () {
          final l = layers[layer];
          final layerRandom = math.Random(1337 + layer * 17);
          final count = (starTotal * l.share).round();
          return [
            for (var i = 0; i < count; i++)
              () {
                final depth =
                    l.depthMin + layerRandom.nextDouble() * l.depthSpan;
                final baseX = layerRandom.nextDouble();
                final baseY = layerRandom.nextDouble();
                final twinklePhase =
                    layerRandom.nextDouble() * 2 * math.pi;
                final twinkleSpeed = 0.2 + layerRandom.nextDouble() * 0.6;
                // Power-law magnitude: most stars barely are, a few
                // shine — the sky's own distribution, the surest cure
                // for clutter.
                final magnitude =
                    math.pow(layerRandom.nextDouble(), 2.6).toDouble();
                // V3.63 — presence is density: each star carries its
                // own leave-ticket in the deal; the fade test runs at
                // paint time against the live presence.
                final ticket = layerRandom.nextDouble();
                return (
                  x: baseX,
                  y: baseY,
                  depth: depth,
                  r: l.rMin + (l.rMax - l.rMin) * magnitude,
                  a: l.aMin + (l.aMax - l.aMin) * magnitude,
                  ticket: ticket,
                  phase: twinklePhase,
                  speed: twinkleSpeed,
                  twinkle: l.twinkle,
                );
              }(),
          ];
        }(),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // V3.65 — the field is screen-anchored, so its DENSITY must ride
    // the surface: 96 stars spread over a phone read as a sky, the
    // same 96 over a tablet read as a rumor (3× the area, a third the
    // presence). The count grows with the area, capped — a big screen
    // earns a fuller sky, never a fabric.
    final starTotal = (starCount * size.width * size.height / (430 * 932))
        .clamp(starCount.toDouble(), 240)
        .round();

    if (_cacheStarTotal != starTotal || _cache == null) {
      _cache = _deal(starTotal);
      _cacheStarTotal = starTotal;
    }

    // The near layer leans deepest under the tilt (parallax grows
    // with depth) — offsets applied per layer, from the painter's
    // tilt, not baked into the deal.
    const layerParallax = [4.0, 6.5, 9.0];
    for (var layer = 0; layer < _cache!.length; layer++) {
      final l = layerParallax[layer];
      for (final s in _cache![layer]) {
        // V3.63 — presence is density: the leave-ticket fades the
        // star out as the eye leaves the known ether (deterministic
        // subset — the same star keeps or loses its seat, whichever
        // frame asks).
        if (s.ticket > presence) continue;
        final x = s.x * size.width + tiltX * l * s.depth;
        final y = s.y * size.height + tiltY * l * s.depth;
        final twinkle = (1.0 - s.twinkle) +
            s.twinkle * math.sin(time * s.speed + s.phase);
        final alpha = s.a * twinkle * (0.35 + 0.65 * presence);
        paint.color = AppColors.fade(Colors.white, alpha.clamp(0.0, 1.0));
        canvas.drawCircle(Offset(x, y), s.r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(BackgroundStarFieldPainter old) => true;
}

/// Diffuse nebulae: multiple color halos with layered effects,
/// subtly swaying with the tilt and pulsing over time.
///
/// V3.63 — the veils die with distance: leaving the known ether, the
/// presence fades them to near-nothing (the far country is not
/// decorated). And the traveller gone far sees the HEARTH — the
/// ether's own glow at their back, teal and indigo, the light of
/// the populated world as one soft distant stain. Distance made
/// visible: you know how far you are by how small home glows.
class NebulaPainter extends CustomPainter {
  NebulaPainter({
    required this.tiltX,
    required this.tiltY,
    this.time = 0.0,
    this.presence = 1.0,
    this.hearthAt,
    this.hearthGlow = 0.0,
  });

  final double tiltX;
  final double tiltY;
  final double time;

  /// V3.63 — 1.0 inside the known ether, 0.0 in the far country.
  final double presence;

  /// The hearth's screen position as fractions of the sky (the
  /// ether's heart projected); null = never far enough to see it.
  final Offset? hearthAt;

  /// 0..1 — how far the traveller is (1 - presence, shaped).
  final double hearthGlow;

  @override
  void paint(Canvas canvas, Size size) {
    // The hearth first — behind every veil: home seen from the far
    // country, one soft warm-cold stain on the black. The eye's
    // window is narrow (viewExtent ~0.42): positionally, home leaves
    // the frame almost immediately — so the stain is COMPASS-shaped:
    // clamped to the rim, in home's true direction, fading with
    // presence. However far, the traveller can feel where it burns.
    final hearth = hearthAt;
    if (hearth != null && hearthGlow > 0.02) {
      const rim = 0.14;
      final c = Offset(
        (hearth.dx.clamp(rim, 1 - rim)) * size.width,
        (hearth.dy.clamp(rim, 1 - rim)) * size.height,
      );
      final radius = size.longestSide * 0.55;
      final rect = Rect.fromCircle(center: c, radius: radius);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height).inflate(radius),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              AppColors.fade(AppColors.teal, 0.16 * hearthGlow),
              AppColors.fade(AppColors.indigo, 0.09 * hearthGlow),
              AppColors.fade(AppColors.indigo, 0),
            ],
          ).createShader(rect),
      );
    }

    final veil = 0.2 + 0.8 * presence;
    void nebula(
      Offset relativeCenter,
      double relativeRadius,
      Color color,
      double baseAlpha,
      double pulseSpeed,
      double pulseAmount,
    ) {
      // Add subtle pulsing to nebulae
      final pulse = 1.0 + pulseAmount * math.sin(time * pulseSpeed);
      final alpha = baseAlpha * pulse.clamp(0.7, 1.3) * veil;
      
      final center = Offset(
        relativeCenter.dx * size.width + tiltX * 12,
        relativeCenter.dy * size.height + tiltY * 12,
      );
      final radius = relativeRadius * size.longestSide;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [AppColors.fade(color, alpha), AppColors.fade(color, 0)],
        ).createShader(rect);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height).inflate(radius),
        paint..blendMode = BlendMode.plus,
      );
    }

    // Layered nebulae with different colors, positions, and pulse
    // rates — veils, not paint: each keeps well short of its edge
    // so true void survives between them (V3.60e).
    nebula(const Offset(0.22, 0.3), 0.50, AppColors.indigo, 0.09, 0.5, 0.2);
    nebula(const Offset(0.8, 0.72), 0.45, AppColors.teal, 0.06, 0.7, 0.15);
    nebula(const Offset(0.6, 0.15), 0.34, AppColors.purple, 0.042, 0.3, 0.1);
    // Additional subtle layers for depth
    nebula(const Offset(0.15, 0.75), 0.38, AppColors.cyan, 0.034, 0.6, 0.12);
    nebula(const Offset(0.9, 0.3), 0.28, AppColors.fade(AppColors.purple, 0.5), 0.024, 0.4, 0.08);
  }

  @override
  bool shouldRepaint(NebulaPainter old) =>
      old.tiltX != tiltX ||
      old.tiltY != tiltY ||
      (old.time - time).abs() > 0.1 ||
      old.presence != presence ||
      old.hearthAt != hearthAt ||
      (old.hearthGlow - hearthGlow).abs() > 0.01;
}

/// One passing wish: the pure geometry of a shooting star.
///
/// Deterministic from its seed, testable without a canvas — the layer
/// above decides WHEN it flies, this only says WHERE and HOW BRIGHT.
class ShootingStar {
  const ShootingStar({
    required this.start,
    required this.angle,
    required this.duration,
    required this.travel,
    required this.tailLength,
  });

  /// [seed] decides everything: same seed, same star — for [sky].
  ///
  /// The travel is bounded by the sky's own edge along the flight
  /// direction: `longestSide` once scaled the path by the TALL side of
  /// a portrait screen while the run available sideways was only its
  /// width, sending nearly every pass off-screen almost immediately
  /// (the meteor flew — the eye never saw it).
  factory ShootingStar.fromSeed(int seed, {required Size sky}) {
    final rng = math.Random(seed);
    final deg = 22 + rng.nextDouble() * 42; // always below the horizon
    final mirrored = rng.nextBool();
    final angle = (mirrored ? 180 - deg : deg) * math.pi / 180;
    final direction = Offset(math.cos(angle), math.sin(angle));
    // Enters from the high band — born INSIDE the sky (the darkness
    // at birth is the opacity envelope's job, not the off-frame's),
    // on the half of the sky the flight LEAVES FROM: a leftward wish
    // enters on the right half — every run crosses at least half a
    // sky, whatever the aspect.
    final start = Offset(
      mirrored ? 0.55 + rng.nextDouble() * 0.41 : 0.04 + rng.nextDouble() * 0.41,
      0.02 + rng.nextDouble() * 0.28,
    );
    final startPx = Offset(start.dx * sky.width, start.dy * sky.height);

    // How far the head may run before leaving its sky, along its own
    // direction — an aspect-aware ceiling, not a fixed fraction of one
    // arbitrary side.
    final runX = direction.dx == 0
        ? double.infinity
        : (direction.dx > 0 ? sky.width - startPx.dx : startPx.dx) /
              direction.dx.abs();
    final runY = direction.dy == 0
        ? double.infinity
        : (sky.height - startPx.dy) / direction.dy;
    final toEdge = math.max(0.0, math.min(runX, runY));

    return ShootingStar(
      start: start,
      angle: angle,
      duration: 0.9 + rng.nextDouble() * 0.6,
      // Half to nine-tenths of the available run: the wish crosses
      // the eye's sky, whatever its aspect.
      travel: toEdge * (0.5 + rng.nextDouble() * 0.4),
      tailLength: 56 + rng.nextDouble() * 54,
    );
  }

  /// Normalized entry point (fractions of the sky).
  final Offset start;

  /// Travel direction in radians — descending by construction.
  final double angle;

  /// Seconds spent crossing the eye.
  final double duration;

  /// Path length in logical pixels, bounded by the sky given at
  /// construction (see [ShootingStar.fromSeed]).
  final double travel;

  /// Tail length in logical pixels.
  final double tailLength;

  Offset direction() => Offset(math.cos(angle), math.sin(angle));

  /// Where the burning head sits at [progress] (0..1). [sky] must be
  /// the same sky the star was seeded for — travel is already in px.
  Offset head(Size sky, double progress) =>
      Offset(start.dx * sky.width, start.dy * sky.height) +
      direction() * (travel * progress);

  /// Visibility envelope: born dark, dies dark — never a pop.
  double opacity(double progress) {
    final fadeIn = (progress / 0.22).clamp(0.0, 1.0);
    final fadeOut = ((1.0 - progress) / 0.38).clamp(0.0, 1.0);
    return math.min(fadeIn, fadeOut) * 0.7;
  }
}

/// Paints one shooting star in flight: a white streak dissolving
/// into the void behind its head. Scenery, never matter.
class ShootingStarPainter extends CustomPainter {
  ShootingStarPainter({
    required this.star,
    required this.progress,
    this.tiltX = 0,
    this.tiltY = 0,
  });

  final ShootingStar star;
  final double progress;
  final double tiltX;
  final double tiltY;

  @override
  void paint(Canvas canvas, Size size) {
    final brightness = star.opacity(progress);
    if (brightness <= 0.01) return;

    // The visitor rides the tilt like the dead field does — a far,
    // light layer of parallax.
    final parallax = Offset(tiltX * 3, tiltY * 3);
    final head = star.head(size, progress) + parallax;
    final tail = head - star.direction() * star.tailLength;

    final streak = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3
      ..shader = ui.Gradient.linear(
        head,
        tail,
        [
          AppColors.fade(Colors.white, brightness),
          AppColors.fade(Colors.white, 0),
        ],
      );
    canvas.drawLine(head, tail, streak);

    canvas.drawCircle(
      head,
      1.6,
      Paint()..color = AppColors.fade(Colors.white, brightness * 0.9),
    );
  }

  @override
  bool shouldRepaint(ShootingStarPainter old) => true;
}
