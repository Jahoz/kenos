import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/utils/parallax_math.dart';

void main() {
  group('ParallaxMath.offsetPixels', () {
    test('les objets proches bougent plus que les lointains', () {
      const tilt = 0.5;
      const amplitude = 60.0;
      final near = ParallaxMath.offsetPixels(
        tilt: tilt,
        z: 1.0,
        amplitude: amplitude,
      );
      final far = ParallaxMath.offsetPixels(
        tilt: tilt,
        z: 0.1,
        amplitude: amplitude,
      );
      expect(near, greaterThan(far));
      expect(near, 30.0);
      expect(far, closeTo(3.0, 1e-9));
    });

    test('tilt nul = aucun déplacement', () {
      expect(ParallaxMath.offsetPixels(tilt: 0, z: 0.8, amplitude: 100), 0);
    });
  });

  group('ParallaxMath.driftZ (dérive des échos scellés)', () {
    test('naît contre la caméra (z = 1)', () {
      final now = DateTime.now();
      final z = ParallaxMath.driftZ(sentAt: now, now: now);
      expect(z, 1.0);
    });

    test('dérive vers le fond puis se stabilise au minimum', () {
      final sent = DateTime(2026, 1, 1);
      final zEarly = ParallaxMath.driftZ(
        sentAt: sent,
        now: sent.add(const Duration(hours: 5)),
      );
      final zLate = ParallaxMath.driftZ(
        sentAt: sent,
        now: sent.add(const Duration(days: 30)),
      );
      expect(zEarly, lessThan(1.0));
      expect(zLate, 0.12); // never fully lost, never negative
    });
  });

  group('bornes visuelles', () {
    test('opacité et tailles restent dans des plages sûres', () {
      for (final z in [0.05, 0.2, 0.5, 0.8, 1.0]) {
        expect(ParallaxMath.opacityFor(z), inExclusiveRange(0, 1.01));
        expect(ParallaxMath.coreRadius(z), greaterThan(0));
      }
    });
  });

  group('ParallaxMath.displayScale (V3.25 — un ciel, tous les écrans)', () {
    test("l'écran large de référence ne change pas", () {
      expect(ParallaxMath.displayScale(900), 1.0);
      expect(ParallaxMath.displayScale(1035), greaterThan(1.0));
    });

    test('sur écran étroit, une étoile profonde ne dépasse pas la Lune', () {
      // S25 portrait: ~390 logical px shortest side.
      const phone = 390.0;
      final s = ParallaxMath.displayScale(phone);
      final deepStar = ParallaxMath.starDiameter(1.0) * s; // 92 × ~0.43
      final moonWithRings =
          phone / 34 * 2 * 1.75; // bodyR×2, ringR = bodyR×1.75
      expect(deepStar, lessThan(moonWithRings * 1.25),
          reason: 'la lumière reste une lumière, pas une planète');
      expect(deepStar, greaterThan(moonWithRings * 0.6),
          reason: 'mais elle reste visible du pouce');
    });

    test("jamais sous 0.4 ni au-dessus de 1.15 — la loi a des bords", () {
      expect(ParallaxMath.displayScale(200), 0.40);
      expect(ParallaxMath.displayScale(4000), 1.15);
    });
  });

  group('ParallaxMath.zoomScale (V3.17 — le zoom que l\'œil voit)', () {
    test("l'œil au repos ne change rien au ciel lancé", () {
      expect(ParallaxMath.zoomScale(ParallaxMath.eyeBaseZoom), 1.0);
    });

    test('zoomer approfondit, dézoomer recule — jamais de renversement', () {
      final s = ParallaxMath.zoomScale;
      expect(s(2.5), greaterThan(1.0));
      expect(s(1.2), lessThan(1.0));
      // Monotone sur toute la plage de l'œil.
      var previous = s(1.2);
      for (var z = 1.3; z <= 8.0; z += 0.1) {
        final v = s(double.parse(z.toStringAsFixed(1)));
        expect(v, greaterThan(previous));
        previous = v;
      }
    });

    test('subtil par construction : jamais des ballons', () {
      // Au zoom maximal (8), un corps ne grossit que ~2,5×.
      expect(ParallaxMath.zoomScale(8.0), closeTo(2.48, 0.05));
      // Au zoom minimal (1,2), il rétrécit à peine (~0,8×).
      expect(ParallaxMath.zoomScale(1.2), closeTo(0.79, 0.02));
    });
  });

  group('champ de réception', () {
    const eye = Offset(0.5, 0.5);

    test("à portée de l'œil : réception pleine", () {
      expect(
        ParallaxMath.receptionIntensity(eye: eye, star: const Offset(0.5, 0.5)),
        1.0,
      );
      expect(
        ParallaxMath.receptionIntensity(
          eye: eye,
          star: Offset(0.5 + ParallaxMath.receptionRadius / 2, 0.5),
        ),
        1.0,
      );
    });

    test('au-delà du champ : un scintillement muet (0)', () {
      final far = ParallaxMath.receptionRadius + ParallaxMath.receptionFade;
      expect(
        ParallaxMath.receptionIntensity(eye: eye, star: Offset(0.5 + far, 0.5)),
        0.0,
      );
    });

    test('fondu linéaire et monotone entre les deux', () {
      double at(double d) => ParallaxMath.receptionIntensity(
            eye: eye,
            star: Offset(0.5 + d, 0.5),
          );
      final d1 = ParallaxMath.receptionRadius + 0.02;
      final d2 = ParallaxMath.receptionRadius + 0.08;
      expect(at(d1), inExclusiveRange(0, 1));
      expect(at(d2), inExclusiveRange(0, 1));
      expect(at(d2), lessThan(at(d1)));
      // The fade is linear: midpoint lands at half intensity.
      final mid = ParallaxMath.receptionRadius + ParallaxMath.receptionFade / 2;
      expect(at(mid), closeTo(0.5, 0.001));
    });

    test("la distance est la même dans toutes les directions (cercle, pas carré)", () {
      final r = ParallaxMath.receptionRadius + ParallaxMath.receptionFade / 2;
      // A diagonal point at distance r sits at (r/√2, r/√2).
      final c = r / 2 * 1.4142135623730951; // r/√2
      expect(
        ParallaxMath.receptionIntensity(eye: eye, star: Offset(0.5 + r, 0.5)),
        closeTo(
          ParallaxMath.receptionIntensity(
            eye: eye,
            star: Offset(0.5 + c, 0.5 + c),
          ),
          0.001,
        ),
      );
    });
  });
}
