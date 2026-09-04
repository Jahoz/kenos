import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/parallax_math.dart';
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

    // Bodies grow with the eye (V3.17): a zoom nothing grows through
    // is a zoom the eye cannot see — the lanes already scaled, the
    // bodies did not, and the wheel felt dead.
    final bodyScale = ParallaxMath.zoomScale(_zoom);

    // Viewport culling (V3.17c): a blurred body off-screen still pays
    // its full raster price on web — a circle plus its margin is
    // drawn only when it can touch the traveller's window.
    bool onScreen(Offset c, double r) =>
        c.dx + r >= -40 &&
        c.dx - r <= size.width + 40 &&
        c.dy + r >= -40 &&
        c.dy - r <= size.height + 40;

    // ── The black hole: darker than the void itself ────────────────────
    final bh = world(KenosSystem.blackHole);
    final bhRadius = viewport.shortestSide / 12 * bodyScale;
    final bhVisible = onScreen(bh, bhRadius * 1.6);
    if (bhVisible) {

    // Gravitational lensing: a faint rose-tinted accretion ring — the
    // destruction color's only legitimate celestial object, whispering
    // the reading contract: what crosses never returns.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..shader = SweepGradient(
        colors: [
          AppColors.fade(AppColors.rose, 0.0),
          AppColors.fade(AppColors.roseText, 0.16),
          AppColors.fade(AppColors.rose, 0.05),
          AppColors.fade(AppColors.roseText, 0.12),
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
        ..strokeWidth = 0.8
        ..color = AppColors.fade(AppColors.roseText, 0.22),
    );
    } // black hole culled

    // ── The named anchors (V3.12) ─────────────────────────────────────
    // Each intention's world has its own glyph and its own lane: a
    // cratered crescent Moon on the inner track, a doubly ringed
    // Venus on the outer, the fixed beacon Polaris above. Worlds are
    // bodies with structure, stars are lights — never confused.
    final worldScale = viewport.shortestSide / camera.viewExtent;
    for (var i = 0; i < KenosSystem.planets.length; i++) {
      final theme = KenosSystem.planets[i];
      final p = world(KenosSystem.planetPosition(i, epoch));
      final bodyR = viewport.shortestSide / 34 * bodyScale;
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

      // The echo lanes: where this world's thoughts whirl — two
      // breaths of circles travelling with the planet.
      if (i != 2) {
        for (final lane in [0.08, 0.13]) {
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
          0.08 * worldScale,
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
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
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
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
          );
      }
    }

    // ── The wanderers (V3.12): named far bodies, each its silhouette ──
    final wandererR = viewport.shortestSide / 72 * bodyScale;
    for (var i = 0; i < celestialWanderers.length; i++) {
      final w = world(CelestialMath.wandererPosition(i, now));
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
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
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
  final r =
      viewport.shortestSide / 34 * ParallaxMath.zoomScale(camera.zoom);
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
  return Rect.fromCircle(
    center: p,
    radius: viewport.shortestSide / 28 * ParallaxMath.zoomScale(camera.zoom),
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
