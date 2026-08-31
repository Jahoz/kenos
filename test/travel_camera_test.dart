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
