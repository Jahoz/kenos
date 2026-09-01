import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
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

      expect(camera.zoom, closeTo(1.75 * 1.8, 1e-6));
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
