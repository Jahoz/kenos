import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../echo/domain/echo.dart';
import '../../application/celestial_bodies.dart';
import '../../application/kenos_system.dart';
import '../../application/travel_camera.dart';

/// V3.7b — the heavens: a black hole at the heart, three planets for
/// the three intentions, orbit rings barely whispered. Everything is
/// drawn from the deterministic system math — two devices see the
/// same sky. Reduce-motion freezes the epoch at "now" (a star chart,
/// not a clockwork).
class SystemPainter extends CustomPainter {
  SystemPainter({
    required this.camera,
    required this.viewport,
    required this.now,
    required this.reducedMotion,
    this.echoes = const [],
  })  : _center = camera.center,
        _zoom = camera.zoom;

  final TravelCamera camera;

  /// Camera VALUES captured at construction: the camera object is a
  /// single mutable instance — comparing it to itself never fires. The
  /// painter must repaint whenever the eye actually moved (V3.12c fix:
  /// the heavens' own clock made the stale-`now` comparison visible as
  /// judder between beats).
  final Offset _center;
  final double _zoom;
  final Size viewport;
  final DateTime now;
  final bool reducedMotion;

  /// The visible sky's echoes — only for the lineage constellations
  /// (faint links between a phoenix and where it was reborn).
  final List<dynamic> echoes;

  @override
  void paint(Canvas canvas, Size size) {
    final epoch = reducedMotion ? now : now;

    Offset world(Offset w) => camera.worldToScreen(w, viewport);

    // V3.69 — the heavens are WORLD-sized: the heart's radius is
    // 0.10 of the sky, the worlds 0.028, the wanderers 0.010, all
    // through [worldScale] (px-per-world). The viewport-anchored
    // bodies never receded — the wheel slid a texture and the heart
    // stayed 18% of the frame at ANY gaze ("c'est pas flagrant");
    // now zooming out is RECEDING, the system a jewel that dwindles
    // into its sky, and hierarchy is world law: hole > worlds >
    // wanderers > shards.
    final worldScale = viewport.shortestSide / camera.viewExtent;
    const holeRadius = 0.10;
    const planetRadius = 0.028;
    const wandererRadius = 0.010;

    // V3.63 — bodies RECEDE with distance (a screen-proportional heart
    // once stayed flagship-huge seen from the far country, floating in
    // the very void it was supposed to make feel vast). Each body
    // keeps its full presence only near the eye; leaving the system,
    // it all dwindles in the traveller's wake — the strongest cue
    // that a distance was CROSSED.
    double far(Offset worldAt) =>
        (1.0 - (worldAt - _center).distance * 0.5).clamp(0.3, 1.0);

    // Small screens pay blur in PHYSICAL pixels (a phone at DPR 3
    // rasterizes nine times the area): the halos soften by half
    // there — the mobile breath (V3.25).
    final softScreen = size.shortestSide < 600;
    final haloBlur = softScreen ? 11.0 : 22.0;
    final ringBlur = softScreen ? 4.0 : 8.0;
    final moonBlur = softScreen ? 5.0 : 9.0;
    final venusBlur = softScreen ? 4.0 : 7.0;

    // Viewport culling (V3.17c): a blurred body off-screen still pays
    // its full raster price on web — a circle plus its margin is
    // drawn only when it can touch the traveller's window.
    bool onScreen(Offset c, double r) =>
        c.dx + r >= -40 &&
        c.dx - r <= size.width + 40 &&
        c.dy + r >= -40 &&
        c.dy - r <= size.height + 40;

    // ── The black hole: darker than the void itself ────────────────────
    // V3.62 — the heart is the sky's flagship (it once read as a
    // pebble among shards). V3.69 — flagship IN THE SYSTEM, jewel in
    // the sky: 0.10 of the ether's width, receding with the gaze.
    final bh = world(KenosSystem.blackHole);
    final bhRadius = holeRadius * worldScale * far(KenosSystem.blackHole);
    final bhVisible = onScreen(bh, bhRadius * 1.6);
    if (bhVisible) {

    // Presence before detail: a wide, deep-blurred gravity halo —
    // the heart is FELT at the edge of the eye before it is seen.
    canvas.drawCircle(
      bh,
      bhRadius * 1.35,
      Paint()
        ..color = AppColors.fade(AppColors.rose, 0.05)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, haloBlur * 1.6),
    );

    // Gravitational lensing: a rose-tinted accretion ring — the
    // destruction color's only legitimate celestial object, whispering
    // the reading contract: what crosses never returns. V3.62: the
    // whisper became a voice — the heart promotes itself.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, ringBlur)
      ..shader = SweepGradient(
        colors: [
          AppColors.fade(AppColors.rose, 0.0),
          AppColors.fade(AppColors.roseText, 0.30),
          AppColors.fade(AppColors.rose, 0.10),
          AppColors.fade(AppColors.roseText, 0.22),
          AppColors.fade(AppColors.rose, 0.0),
        ],
      ).createShader(Rect.fromCircle(center: bh, radius: bhRadius));
    canvas.drawCircle(bh, bhRadius * 0.92, ringPaint);

    // The event horizon: pure absence, a disc blacker than the
    // background — painted opaque so even stars behind are swallowed.
    canvas.drawCircle(bh, bhRadius, Paint()..color = const Color(0xFF000000));
    // A hairline of nothing-but-edge so the disc reads on the void.
    canvas.drawCircle(
      bh,
      bhRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.fade(AppColors.roseText, 0.40),
    );
    } // black hole culled

    // ── The named anchors (V3.12) ─────────────────────────────────────
    // Each intention's world has its own glyph and its own lane: a
    // cratered crescent Moon on the inner track, a doubly ringed
    // Venus on the outer, the fixed beacon Polaris above. Worlds are
    // bodies with structure, stars are lights — never confused.
    for (var i = 0; i < KenosSystem.planets.length; i++) {
      final theme = KenosSystem.planets[i];
      final p = world(KenosSystem.planetPosition(i, epoch));
      // V3.62 — worlds with variants: each body its own weight (Vénus
      // reads wide through her rings, Polaris stays a pointed beacon).
      // Clearly beneath the heart, clearly above the moons and shards.
      final variant = switch (i) { 0 => 1.0, 1 => 1.12, _ => 0.8 };
      final bodyR = planetRadius * worldScale * variant *
          far(KenosSystem.planetPosition(i, epoch));
      final ringR = bodyR * 1.75;
      final bodyVisible = onScreen(p, bodyR * 2.5);
      if (!bodyVisible) continue;

      // The lane: each planet its own circle — never doubled, never
      // smeared. Polaris has none: it holds still.
      if (i != 2) {
        canvas.drawCircle(
          world(KenosSystem.blackHole),
          KenosSystem.orbitRadiusOf(i) * worldScale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7
            ..color = AppColors.fade(theme.halo, 0.07),
        );
      }

      // The echo lanes: where this world's thoughts whirl — the THREE
      // true shells travelling with the planet (V3.28: the guides now
      // draw exactly where the orbits run; the old 0.08/0.13 pair was
      // a lie the sky kept telling).
      if (i != 2) {
        for (final lane in KenosSystem.echoShells) {
          canvas.drawCircle(
            p,
            lane * worldScale,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5
              ..color = AppColors.fade(theme.halo, 0.05),
          );
        }
      } else {
        canvas.drawCircle(
          p,
          KenosSystem.echoShells.first * worldScale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..color = AppColors.fade(theme.halo, 0.06),
        );
      }

      // Soft breathing halo (very dim: it must not outshine stars).
      canvas.drawCircle(
        p,
        bodyR,
        Paint()
          ..color = AppColors.fade(theme.core, 0.08)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, haloBlur),
      );

      switch (i) {
        case 0: // La Lune — cratered, matte, a waning crescent.
          canvas.drawCircle(
            p,
            bodyR,
            Paint()..color = AppColors.fade(theme.core, 0.55),
          );
          // The shadow disc carving the crescent.
          canvas.drawCircle(
            p.translate(-bodyR * 0.42, -bodyR * 0.24),
            bodyR * 0.94,
            Paint()..color = AppColors.voidBlack.withValues(alpha: 0.78),
          );
          // Craters on the lit limb — three, quietly placed.
          final crater = Paint()
            ..color = AppColors.voidBlack.withValues(alpha: 0.35);
          canvas.drawCircle(
            p.translate(bodyR * 0.38, bodyR * 0.12),
            bodyR * 0.16,
            crater,
          );
          canvas.drawCircle(
            p.translate(bodyR * 0.22, bodyR * 0.42),
            bodyR * 0.11,
            crater,
          );
          canvas.drawCircle(
            p.translate(bodyR * 0.50, -bodyR * 0.22),
            bodyR * 0.09,
            crater,
          );
          canvas.drawCircle(
            p,
            bodyR,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1
              ..color = AppColors.fade(theme.halo, 0.8),
          );
        case 1: // Vénus — the doubly ringed world of confided love.
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(-0.42);
          canvas.drawOval(
            Rect.fromCircle(center: Offset.zero, radius: ringR * 1.18),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8
              ..color = AppColors.fade(theme.halo, 0.18),
          );
          canvas.rotate(0.18);
          canvas.drawOval(
            Rect.fromCircle(center: Offset.zero, radius: ringR),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = AppColors.fade(theme.halo, 0.45),
          );
          canvas.restore();
          canvas.drawCircle(
            p,
            bodyR,
            Paint()..color = AppColors.fade(theme.core, 0.6),
          );
          canvas.drawCircle(
            p,
            bodyR,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = AppColors.fade(theme.halo, 0.85),
          );
        case 2: // Polaris — the beacon: rays, a breathing core, no lane.
          // A ~4.8 s breath, derived from the shared clock.
          final pulse =
              0.5 +
              0.5 * math.sin(epoch.millisecondsSinceEpoch / 4800 * 2 * math.pi);
          final ray = Paint()
            ..strokeWidth = 1.1
            ..color = AppColors.fade(theme.halo, 0.35 + 0.3 * pulse);
          final rl = bodyR * (2.4 + 0.9 * pulse);
          canvas.drawLine(p.translate(-rl, 0), p.translate(rl, 0), ray);
          canvas.drawLine(p.translate(0, -rl), p.translate(0, rl), ray);
          final drl = bodyR * (1.3 + 0.5 * pulse);
          for (final diag in [
            math.pi / 4,
            -math.pi / 4,
            3 * math.pi / 4,
            -3 * math.pi / 4,
          ]) {
            canvas.drawLine(
              p.translate(drl * math.cos(diag), drl * math.sin(diag)),
              p.translate(
                -drl * math.cos(diag) * 0.35,
                -drl * math.sin(diag) * 0.35,
              ),
              ray,
            );
          }
          canvas.drawCircle(
            p,
            bodyR * 0.6,
            Paint()..color = AppColors.fade(theme.core, 0.85 + 0.1 * pulse),
          );
          canvas.drawCircle(
            p,
            bodyR * 0.6,
            Paint()
              ..color = AppColors.fade(theme.halo, 0.25 + 0.2 * pulse)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, moonBlur),
          );
      }
    }

    // ── The wanderers (V3.12): named far bodies, each its silhouette ──
    // V3.62 — the moons rise a step (their silhouettes must read),
    // still a clear rank below the worlds.
    for (var i = 0; i < celestialWanderers.length; i++) {
      final w = world(CelestialMath.wandererPosition(i, now));
      final wandererR = wandererRadius * worldScale *
          far(CelestialMath.wandererPosition(i, now));
      if (!onScreen(w, wandererR * 2.5)) continue;
      final body = Paint()..color = AppColors.fade(AppColors.pureLight, 0.4);
      final limb = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = AppColors.fade(AppColors.cyan, 0.55);
      switch (i) {
        case 0: // Pluton — the heart on its flank.
          canvas.drawCircle(w, wandererR, body);
          canvas.drawCircle(
            w.translate(wandererR * 0.28, wandererR * 0.30),
            wandererR * 0.34,
            Paint()..color = AppColors.fade(AppColors.cyan, 0.45),
          );
          canvas.drawCircle(w, wandererR, limb);
        case 1: // Triton — half-lit: the retrograde exile.
          canvas.drawCircle(w, wandererR, body);
          canvas.drawCircle(
            w.translate(-wandererR * 0.45, wandererR * 0.2),
            wandererR * 0.92,
            Paint()..color = AppColors.voidBlack.withValues(alpha: 0.7),
          );
          canvas.drawCircle(w, wandererR, limb);
        case 2: // Europe — the cracked ice over a warm sea.
          canvas.drawCircle(w, wandererR, body);
          final crack = Paint()
            ..strokeWidth = 0.6
            ..color = AppColors.fade(AppColors.cyan, 0.5);
          canvas.drawLine(
            w.translate(-wandererR * 0.7, -wandererR * 0.1),
            w.translate(wandererR * 0.7, wandererR * 0.3),
            crack,
          );
          canvas.drawLine(
            w.translate(-wandererR * 0.2, wandererR * 0.7),
            w.translate(wandererR * 0.3, -wandererR * 0.7),
            crack,
          );
          canvas.drawCircle(w, wandererR, limb);
        case 3: // Titan — the haze: a blurred wide shroud.
          canvas.drawCircle(
            w,
            wandererR * 1.7,
            Paint()
              ..color = AppColors.fade(AppColors.pureLight, 0.12)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, venusBlur),
          );
          canvas.drawCircle(w, wandererR, body);
          canvas.drawCircle(w, wandererR, limb);
      }
    }

    // ── Lineage constellations ──────────────────────────────────────
    // Faint links: the map of a thought's journey through humans.
    // Consumed parents leave phantom anchors — the line still points
    // at where the rebirth happened. Never bright: a trace, not a
    // thread to pull.
    for (final segment in KenosSystem.lineageSegments(
      echoes.cast<Echo>(),
      now,
    )) {
      final (from, to, theme) = segment;
      final a = world(from);
      final b = world(to);
      final paint = Paint()
        ..strokeWidth = 0.7
        ..style = PaintingStyle.stroke
        ..color = AppColors.fade(theme.halo, 0.10);
      canvas.drawLine(a, b, paint);
      // A mote at the rebirth point: someone carried this further.
      canvas.drawCircle(
        b,
        1.4,
        Paint()..color = AppColors.fade(theme.halo, 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(SystemPainter oldDelegate) =>
      oldDelegate.now != now ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate._center != _center ||
      oldDelegate._zoom != _zoom ||
      oldDelegate.viewport != viewport;
}

/// Screen rectangle of a planet's tap target (for « voyager vers »).
Rect planetTapRect({
  required int index,
  required TravelCamera camera,
  required Size viewport,
  required DateTime now,
}) {
  final p = camera.worldToScreen(
    KenosSystem.planetPosition(index, now),
    viewport,
  );
  // V3.69 — the target rides the world-sized body (the painted body
  // recedes with the gaze), with the finger's courtesy floor.
  final worldScale = viewport.shortestSide / camera.viewExtent;
  final r = math.max(0.028 * worldScale * 1.4, 44.0);
  return Rect.fromCircle(center: p, radius: r);
}

/// Screen rectangle of a wanderer's tap target.
Rect wandererTapRect({
  required int index,
  required TravelCamera camera,
  required Size viewport,
  required DateTime now,
}) {
  final p = camera.worldToScreen(
    CelestialMath.wandererPosition(index, now),
    viewport,
  );
  // V3.69 — world-sized wanderer, courtesy floor for the far dots.
  final worldScale = viewport.shortestSide / camera.viewExtent;
  return Rect.fromCircle(
    center: p,
    radius: math.max(0.010 * worldScale * 2.2, 40.0),
  );
}

/// Which wanderer (if any) sits under a screen tap. -1 = none.
int wandererHitTest({
  required Offset screenPoint,
  required TravelCamera camera,
  required Size viewport,
  required DateTime now,
}) {
  for (var i = 0; i < celestialWanderers.length; i++) {
    if (wandererTapRect(
      index: i,
      camera: camera,
      viewport: viewport,
      now: now,
    ).contains(screenPoint)) {
      return i;
    }
  }
  return -1;
}

/// Which planet (if any) sits under a screen tap. -1 = none.
int planetHitTest({
  required Offset screenPoint,
  required TravelCamera camera,
  required Size viewport,
  required DateTime now,
}) {
  for (var i = 0; i < KenosSystem.planets.length; i++) {
    if (planetTapRect(
      index: i,
      camera: camera,
      viewport: viewport,
      now: now,
    ).contains(screenPoint)) {
      return i;
    }
  }
  return -1;
}

// Kept for future comet tails: the golden-angle spread used by the
// lineage constellations (V3.8 seed).
double goldenAngle(int i) => i * 137.508 * math.pi / 180;
