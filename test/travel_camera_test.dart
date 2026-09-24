import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/application/celestial_bodies.dart';
import 'package:kenos/features/cosmic_map/application/kenos_system.dart';
import 'package:kenos/features/cosmic_map/application/travel_camera.dart';

void main() {
  group('TravelCamera — le voyage', () {
    test('vue initiale centrée : rect visible et conversion écran', () {
      final camera = TravelCamera(zoom: 1.75);
      final rect = camera.visibleRect;
      expect(rect.minX, closeTo(0.5 - 0.5 / 1.75, 1e-9));
      expect(rect.maxX, closeTo(0.5 + 0.5 / 1.75, 1e-9));

      const viewport = Size(400, 800);
      // Le centre du monde reste au centre de l'écran.
      final center = camera.worldToScreen(const Offset(0.5, 0.5), viewport);
      expect(center.dx, closeTo(200, 1e-6));
      expect(center.dy, closeTo(400, 1e-6));
    });

    test('le ciel suit le doigt : pan écran → déplacement inverse', () {
      final camera = TravelCamera();
      const viewport = Size(400, 800);
      // Glisser vers la gauche (dx négatif) → l'œil va vers la droite.
      camera.panByScreen(const Offset(-100, 0), viewport);
      expect(camera.center.dx, greaterThan(0.5));
      // La dérive s'accumule en A.L.
      expect(camera.drift, greaterThan(0));
      expect(camera.driftLabel, endsWith('A.L.'));
    });

    test('clamp : on ne quitte jamais tout à fait l\'éther connu', () {
      final camera = TravelCamera(zoom: 1.75, margin: 0.1);
      const viewport = Size(400, 800);
      // Pan démesuré vers l'extérieur : la caméra s'arrête à la marge.
      camera.panByScreen(const Offset(-100000, -100000), viewport);
      final c = camera.center;
      expect(c.dx, lessThanOrEqualTo(1.1 - 0.5 / 1.75 + 1e-9));
      expect(c.dy, lessThanOrEqualTo(1.1 - 0.5 / 1.75 + 1e-9));
    });

    test('pincement : le zoom s\'ancre sous les doigts', () {
      final camera = TravelCamera();
      const viewport = Size(400, 800);
      const focalWorld = Offset(0.44, 0.5); // the point under the fingers
      final before =
          camera.worldToScreen(focalWorld, viewport);

      camera.zoomBy(1.8, focalWorld);

      expect(camera.zoom, closeTo(1.0 * 1.8, 1e-6));
      final after = camera.worldToScreen(focalWorld, viewport);
      // The anchored point barely moved on screen (clamping may shift
      // it a little — it must NOT fly away).
      expect((after - before).distance, lessThan(24));
    });

    test('bornes du pincement : jamais carte, jamais microscope', () {
      final camera = TravelCamera();
      const focal = Offset(0.5, 0.5);
      camera.zoomBy(100, focal);
      expect(camera.zoom, TravelCamera.maxZoom);
      camera.zoomBy(0.001, focal);
      expect(camera.zoom, TravelCamera.minZoom);
    });

    test('zoomer sépare : l\'écart écran entre deux points proches grandit', () {
      final camera = TravelCamera();
      const viewport = Size(400, 800);
      final a = const Offset(0.50, 0.50);
      final b = const Offset(0.505, 0.50); // ~2 px apart at rest
      final before =
          (camera.worldToScreen(b, viewport) - camera.worldToScreen(a, viewport)).distance;
      camera.zoomBy(3.0, a);
      final after =
          (camera.worldToScreen(b, viewport) - camera.worldToScreen(a, viewport)).distance;
      expect(after, greaterThan(before * 1.9),
          reason: 'les étoiles trop proches deviennent tenables');
    });

    test('RECALIBRER : retour au cœur, dérive conservée', () {
      final camera = TravelCamera();
      const viewport = Size(400, 800);
      camera.panByScreen(const Offset(-60, 40), viewport);
      final drift = camera.drift;
      camera.recenter();
      expect(camera.center, const Offset(0.5, 0.5));
      expect(camera.drift, drift, reason: 'le voyage vécu reste compté');
    });
  });

  group('V3.40 — le vide traversable : tout corps nommé s\'atteint', () {
    test('chaque monde, chaque errant : l\'œil au repos PEUT le centrer',
        () {
      // The rings are CIRCLES in a SQUARE ether: the wanderers (r up
      // to 0.65) step past the rim along the axes, and at the old
      // +0.1 margin they were sometimes UNREACHABLE (the eye saw at
      // most to 1.1; Europe rides to 1.15). The traversable void now
      // extends to ±0.5: a fresh eye at its resting zoom can centre
      // on every named body, at any moment of their arcs — sampled
      // across a day and a half to catch the axis crossings.
      final t0 = DateTime(2026, 9, 14);
      for (var s = 0; s < 32; s++) {
        final at = t0.add(Duration(hours: s));
        final bodies = <String, Offset>{
          for (var i = 0; i < KenosSystem.planets.length; i++)
            celestialBodies[i].name: KenosSystem.planetPosition(i, at),
          for (var i = 0; i < celestialWanderers.length; i++)
            celestialWanderers[i].name:
                CelestialMath.wandererPosition(i, at),
        };
        for (final entry in bodies.entries) {
          final camera = TravelCamera(); // the resting eye, default void
          camera.panByWorld(entry.value - camera.center);
          expect(
            (camera.center - entry.value).distance,
            lessThan(1e-9),
            reason:
                '${entry.key} doit être centrable à $at (position ${entry.value})',
          );
        }
      }
    });

    test('au-delà de l\'éther, le vide reste borné — le monde n\'est pas infini',
        () {
      final camera = TravelCamera();
      camera.panByWorld(const Offset(100, 100));
      expect(camera.center.dx, lessThanOrEqualTo(1.7));
      expect(camera.center.dy, lessThanOrEqualTo(1.7));
      camera.panByWorld(const Offset(-200, -200));
      expect(camera.center.dx, greaterThanOrEqualTo(-0.7));
      expect(camera.center.dy, greaterThanOrEqualTo(-0.7));
    });
  });

  group('V3.65 — l\'éther n\'est jamais étiré : large écran, monde plus large', () {
    const wide = Size(1600, 1000); // the 16:10 tablet

    test('un delta monde égal reste un delta écran égal (les cercles restent ronds)', () {
      final camera = TravelCamera()..attach(wide);
      final a = camera.worldToScreen(const Offset(0.5, 0.5), wide);
      final dx = camera.worldToScreen(const Offset(0.6, 0.5), wide);
      final dy = camera.worldToScreen(const Offset(0.5, 0.6), wide);
      expect((dx - a).distance, closeTo((dy - a).distance, 1e-6),
          reason: 'avant V3.65 le même Δ valait 1,6× plus en largeur');
      // The short side carries viewExtent: 0.1 world = 0.1 × zoom ×
      // shortestSide px at the survey gaze (zoom 1.0).
      expect((dx - a).distance, closeTo(0.1 * 1.0 * 1000, 1e-6));
    });

    test('le rect visible est un rectangle honnête : 1,6× plus large que haut', () {
      final camera = TravelCamera()..attach(wide);
      final r = camera.visibleRect;
      final w = r.maxX - r.minX;
      final h = r.maxY - r.minY;
      // The SHORT side (height, 1000px) carries viewExtent exactly.
      expect(h, closeTo(1.0, 1e-9),
          reason: 'le petit côté porte viewExtent');
      expect(w, closeTo(1.6, 1e-9),
          reason: 'le grand côté montre PLUS de monde, pas un étirement');
    });

    test('screenToWorld inverse worldToScreen sur écran large', () {
      final camera = TravelCamera()..attach(wide);
      camera.panByWorld(const Offset(0.12, -0.07));
      const p = Offset(0.61, 0.44);
      final screen = camera.worldToScreen(p, wide);
      final back = camera.screenToWorld(screen, wide);
      expect(back.dx, closeTo(p.dx, 1e-9));
      expect(back.dy, closeTo(p.dy, 1e-9));
    });

    test('les murs suivent l\'aspect : le clamp horizontal est plus strict en survey', () {
      final camera = TravelCamera(zoom: 1.0)..attach(wide);
      camera.panByWorld(const Offset(50, 50));
      final c = camera.center;
      // halfW = 0.8 → the wall sits at 1.7 - 0.8 = 0.9.
      expect(c.dx, lessThanOrEqualTo(0.9 + 1e-9));
      // halfH = 0.5 → the vertical wall sits at 1.7 - 0.5 = 1.2.
      expect(c.dy, lessThanOrEqualTo(1.2 + 1e-9));
    });

    test('sans attach (téléphone, premiers tests) : le regard carré d\'avant', () {
      final camera = TravelCamera(zoom: 1.75);
      final r = camera.visibleRect;
      expect(r.maxX - r.minX, closeTo(1 / 1.75, 1e-9));
      expect(r.maxY - r.minY, closeTo(1 / 1.75, 1e-9));
    });
  });

  group('DriftGlide — l\'inertie', () {
    test('la vitesse décroît et s\'arrête', () {
      final glide = DriftGlide(decay: 0.9);
      final path = glide.path(const Offset(0.5, 0)).toList();
      expect(path.length, greaterThan(2));
      // Chaque pas est plus petit que le précédent.
      for (var i = 1; i < path.length; i++) {
        expect(path[i].dx, lessThan(path[i - 1].dx));
      }
      // L'inertie meurt, elle ne s\'éternise pas.
      expect(glide.totalDistance(const Offset(0.5, 0)), lessThan(5.2));
    });

    test('vitesse nulle : pas de glissement', () {
      expect(DriftGlide().path(Offset.zero).toList(), isEmpty);
    });
  });
}
