import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/background_painters.dart';

/// Les étoiles filantes : la géométrie d'un vœu — déterministe,
/// descendante, née et morte dans le noir (jamais de pop).
void main() {
  group('ShootingStar géométrie', () {
    test('même graine, même étoile', () {
      final a = ShootingStar.fromSeed(42);
      final b = ShootingStar.fromSeed(42);
      expect(a.start, b.start);
      expect(a.angle, b.angle);
      expect(a.duration, b.duration);
      expect(a.travel, b.travel);
      expect(a.tailLength, b.tailLength);
    });

    test('la filante descend toujours, jamais verticale', () {
      for (var seed = 0; seed < 200; seed++) {
        final star = ShootingStar.fromSeed(seed);
        final dy = math.sin(star.angle);
        final dx = math.cos(star.angle).abs();
        expect(dy, greaterThan(0), reason: 'seed $seed doit descendre');
        // Une diagonale, pas une chute : 22°–65° sous l'horizon.
        expect(dy, lessThan(0.95), reason: 'seed $seed trop vertical');
        expect(dx, greaterThan(0.35), reason: 'seed $seed trop plat');
      }
    });

    test('la tête part du point d\'entrée et suit la direction', () {
      const sky = Size(400, 800);
      final star = ShootingStar.fromSeed(7);
      final origin = star.head(sky, 0);
      expect(origin.dx, closeToFit(star.start.dx * sky.width));
      expect(origin.dy, closeToFit(star.start.dy * sky.height));

      final mid = star.head(sky, 0.5);
      final travelled = mid - origin;
      final dir = star.direction();
      // Le trajet est colinéaire à la direction, de longueur attendue.
      expect(travelled.dx / travelled.dy, closeTo(dir.dx / dir.dy, 0.001));
      expect(
        travelled.distance,
        closeTo(star.travel * sky.longestSide * 0.5, 0.001),
      );
    });

    test('née sombre, morte sombre — jamais de pop', () {
      for (var seed = 0; seed < 50; seed++) {
        final star = ShootingStar.fromSeed(seed);
        expect(star.opacity(0), 0);
        expect(star.opacity(1), 0);
        expect(star.opacity(0.5), greaterThan(0));
        for (var p = 0.0; p <= 1.0; p += 0.05) {
          expect(star.opacity(p), lessThanOrEqualTo(0.7));
        }
      }
    });
  });

  group('ShootingStarPainter', () {
    testWidgets('peint une passe entière sans lever', (tester) async {
      final star = ShootingStar.fromSeed(1234);
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(400, 800),
            painter: ShootingStarPainter(star: star, progress: 0),
          ),
        ),
      );
      for (var p = 0.0; p <= 1.0; p += 0.1) {
        await tester.pumpWidget(
          MaterialApp(
            home: CustomPaint(
              size: const Size(400, 800),
              painter: ShootingStarPainter(star: star, progress: p),
            ),
          ),
        );
      }
      expect(tester.takeException(), isNull);
    });
  });
}

/// Un closeTo tolérant aux arrondis flottants (± 0.5 px).
Matcher closeToFit(num value) => closeTo(value, 0.5);
