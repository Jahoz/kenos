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
  });

  final TravelCamera camera;
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

    // ── The black hole: darker than the void itself ────────────────────
    final bh = world(KenosSystem.blackHole);
    final bhRadius = viewport.shortestSide / 14;

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
    canvas.drawCircle(
      bh,
      bhRadius,
      Paint()..color = const Color(0xFF000000),
    );
    // A hairline of nothing-but-edge so the disc reads on the void.
    canvas.drawCircle(
      bh,
      bhRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.fade(AppColors.roseText, 0.22),
    );

    // ── The named anchors (V3.12) ─────────────────────────────────────
    // Each intention's world has its own glyph: a crescent Moon, a
    // ringed Venus, the fixed beacon Polaris. Worlds are bodies, stars
    // are lights — never confused.
    for (var i = 0; i < KenosSystem.planets.length; i++) {
      final theme = KenosSystem.planets[i];
      final p = world(KenosSystem.planetPosition(i, epoch));
      final bodyR = viewport.shortestSide / 46;
      final ringR = bodyR * 1.75;

      // Orbit path around the void — Polaris has none: it holds still.
      if (i != 2) {
        final orbitPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = AppColors.fade(theme.halo, 0.05);
        canvas.drawCircle(
          world(KenosSystem.blackHole),
          KenosSystem.planetOrbit / camera.viewExtent * viewport.shortestSide,
          orbitPaint,
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
        case 0: // La Lune — a crescent: what wanes, what returns.
          canvas.drawCircle(
            p,
            bodyR,
            Paint()..color = AppColors.fade(theme.core, 0.5),
          );
          canvas.drawCircle(
            p.translate(-bodyR * 0.38, -bodyR * 0.22),
            bodyR * 0.92,
            Paint()
              ..color = AppColors.voidBlack.withValues(alpha: 0.72),
          );
          canvas.drawCircle(
            p,
            bodyR,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1
              ..color = AppColors.fade(theme.halo, 0.7),
          );
        case 1: // Vénus — the ringed world of confided love.
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(-0.42 + 0.35);
          canvas.drawOval(
            Rect.fromCircle(center: Offset.zero, radius: ringR),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = AppColors.fade(theme.halo, 0.30),
          );
          canvas.restore();
          canvas.drawCircle(
            p,
            bodyR,
            Paint()..color = AppColors.fade(theme.core, 0.55),
          );
          canvas.drawCircle(
            p,
            bodyR,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = AppColors.fade(theme.halo, 0.75),
          );
        case 2: // Polaris — the beacon: a point, a cross of rays.
          final ray = Paint()
            ..strokeWidth = 1.0
            ..color = AppColors.fade(theme.halo, 0.55);
          final rl = bodyR * 2.6;
          canvas.drawLine(p.translate(-rl, 0), p.translate(rl, 0), ray);
          canvas.drawLine(p.translate(0, -rl), p.translate(0, rl), ray);
          canvas.drawCircle(
            p,
            bodyR * 0.55,
            Paint()..color = AppColors.fade(theme.core, 0.9),
          );
          canvas.drawCircle(
            p,
            bodyR * 0.55,
            Paint()
              ..color = AppColors.fade(theme.halo, 0.35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
      }
    }

    // ── The wanderers (V3.12): named far bodies on slow arcs ──────────
    for (var i = 0; i < celestialWanderers.length; i++) {
      final w = world(CelestialMath.wandererPosition(i, now));
      final r = viewport.shortestSide / 110;
      canvas.drawCircle(
        w,
        r,
        Paint()..color = AppColors.fade(AppColors.pureLight, 0.34),
      );
      canvas.drawCircle(
        w,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = AppColors.fade(AppColors.cyan, 0.5),
      );
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
      oldDelegate.camera.center != camera.center;
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
  final r = viewport.shortestSide / 40;
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
  return Rect.fromCircle(center: p, radius: viewport.shortestSide / 34);
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
