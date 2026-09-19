import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/background_painters.dart';

/// Les étoiles filantes : la géométrie d'un vœu — déterministe,
/// descendante, née et morte dans le noir (jamais de pop), et bornée
/// par le ciel qu'elle traverse (V3.60f : le portrait comptait).
void main() {
  group('ShootingStar géométrie', () {
    test('même graine, même étoile', () {
      const sky = Size(430, 932);
      final a = ShootingStar.fromSeed(42, sky: sky);
      final b = ShootingStar.fromSeed(42, sky: sky);
      expect(a.start, b.start);
      expect(a.angle, b.angle);
      expect(a.duration, b.duration);
      expect(a.travel, b.travel);
      expect(a.tailLength, b.tailLength);
    });

    test('la filante descend toujours, jamais verticale', () {
      const sky = Size(430, 932);
      for (var seed = 0; seed < 200; seed++) {
        final star = ShootingStar.fromSeed(seed, sky: sky);
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
      final star = ShootingStar.fromSeed(7, sky: sky);
      final origin = star.head(sky, 0);
      expect(origin.dx, closeToFit(star.start.dx * sky.width));
      expect(origin.dy, closeToFit(star.start.dy * sky.height));

      final mid = star.head(sky, 0.5);
      final travelled = mid - origin;
      final dir = star.direction();
      // Le trajet est colinéaire à la direction, de longueur attendue
      // (travel est déjà en pixels, borné par CE ciel).
      expect(travelled.dx / travelled.dy, closeTo(dir.dx / dir.dy, 0.001));
      expect(travelled.distance, closeTo(star.travel * 0.5, 0.001));
    });

    test('née sombre, morte sombre — jamais de pop', () {
      const sky = Size(430, 932);
      for (var seed = 0; seed < 50; seed++) {
        final star = ShootingStar.fromSeed(seed, sky: sky);
        expect(star.opacity(0), 0);
        expect(star.opacity(1), 0);
        expect(star.opacity(0.5), greaterThan(0));
        for (var p = 0.0; p <= 1.0; p += 0.05) {
          expect(star.opacity(p), lessThanOrEqualTo(0.7));
        }
      }
    });

    test('V3.60f — la tête reste dans le ciel, portrait ou paysage', () {
      // Régression : travel était borné par `longestSide` (la HAUTEUR
      // en portrait) alors que la course horizontale n'était que la
      // largeur — la filante volait, mais hors cadre.
      const skies = [Size(430, 932), Size(1280, 800), Size(360, 760)];
      for (final sky in skies) {
        for (var seed = 0; seed < 300; seed++) {
          final star = ShootingStar.fromSeed(seed, sky: sky);
          // L'entrée se fait dans la moitié de départ : chaque course
          // traverse au moins un demi-ciel.
          expect(star.travel, greaterThan(100),
              reason: 'seed $seed, $sky : le vœu doit traverser');
          // Née DANS le ciel : la tête reste dans le cadre du début
          // à la fin de la passe.
          for (final p in [0.0, 0.25, 0.5, 0.75, 1.0]) {
            final head = star.head(sky, p);
            expect(head.dx, inExclusiveRange(-2, sky.width + 2),
                reason: 'seed $seed p=$p, $sky : tête hors cadre en x');
            expect(head.dy, inExclusiveRange(-2, sky.height + 2),
                reason: 'seed $seed p=$p, $sky : tête hors cadre en y');
          }
        }
      }
    });
  });

  group('ShootingStarPainter', () {
    testWidgets('peint une passe entière sans lever', (tester) async {
      const sky = Size(400, 800);
      final star = ShootingStar.fromSeed(1234, sky: sky);
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: sky,
            painter: ShootingStarPainter(star: star, progress: 0),
          ),
        ),
      );
      for (var p = 0.0; p <= 1.0; p += 0.1) {
        await tester.pumpWidget(
          MaterialApp(
            home: CustomPaint(
              size: sky,
              painter: ShootingStarPainter(star: star, progress: p),
            ),
          ),
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('peint des pixels visibles au plus brillant', (tester) async {
      // V3.60f — le rendu doit exister : la tête doit briller DANS le
      // cadre (la graine 42 volait hors écran à mi-passe avant fix).
      const sky = Size(400, 800);
      final star = ShootingStar.fromSeed(42, sky: sky);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFF030508),
              child: CustomPaint(
                size: sky,
                painter: ShootingStarPainter(star: star, progress: 0.5),
              ),
            ),
          ),
        ),
      );
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // toImage needs the real engine codec — runAsync, or the test
      // binding hangs waiting for a frame that never comes.
      final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
      final data = await tester.runAsync(() => image!.toByteData());
      var bright = 0;
      final b = data!;
      for (var i = 0; i < b.lengthInBytes; i += 4) {
        final lum = (b.getUint8(i) * 299 + b.getUint8(i + 1) * 587 + b.getUint8(i + 2) * 114) ~/ 1000;
        if (lum > 100) bright++;
      }
      expect(bright, greaterThan(4),
          reason: 'à mi-passe, la tête et la queue doivent éclairer le ciel');
    });
  });
}

/// Un closeTo tolérant aux arrondis flottants (± 0.5 px).
Matcher closeToFit(num value) => closeTo(value, 0.5);
