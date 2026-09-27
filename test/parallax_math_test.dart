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

  group('ParallaxMath.clockDirection (V3.30 — la boussole du souffle)', () {
    test('12 vers le haut, 3 vers l\'est, comme les heures du ciel', () {
      expect(ParallaxMath.clockDirection(const Offset(0, -1)), 12);
      expect(ParallaxMath.clockDirection(const Offset(1, 0)), 3);
      expect(ParallaxMath.clockDirection(const Offset(0, 1)), 6);
      expect(ParallaxMath.clockDirection(const Offset(-1, 0)), 9);
    });

    test('les diagonales tombent juste, jamais 0 h', () {
      expect(ParallaxMath.clockDirection(const Offset(1, -1)), 2);
      expect(ParallaxMath.clockDirection(const Offset(1, 1)), 5);
      expect(ParallaxMath.clockDirection(const Offset(-1, 1)), 7);
      expect(ParallaxMath.clockDirection(const Offset(-1, -1)), 10);
    });
  });

  group('ParallaxMath.zoomScale (V3.17 — le zoom que l\'œil voit)', () {
    test("l'œil au repos ne change rien au ciel lancé", () {
      expect(ParallaxMath.zoomScale(ParallaxMath.eyeBaseZoom), 1.0);
    });

    test('V3.58i — la dérive vivante s\'apaise à mesure qu\'on approche', () {
      // V3.70 — le repos EST le survey : il balance (voir le test
      // dédié). Le plein "neutre" vit au pli (1.2), dernier degré
      // avant l'amplification.
      expect(ParallaxMath.parallaxCalm(1.2), closeTo(1.0, 1e-9),
          reason: 'pleine vie neutre au pli');
      expect(ParallaxMath.parallaxCalm(8.0), closeTo(0.25, 1e-9),
          reason: 'un quart au zoom max — le feature survit, la distraction meurt');
      for (var z = 1.2; z <= 8.0; z += 0.3) {
        expect(ParallaxMath.parallaxCalm(z), inInclusiveRange(0.25, 1.0));
        expect(ParallaxMath.parallaxCalm(z + 0.3) <=
                ParallaxMath.parallaxCalm(z) + 1e-9, isTrue,
            reason: 'monotone : approcher ne réveille jamais');
      }
    });

    test('V3.70 — le survey balance : le ciel glisse dans son cadre', () {
      // Sous le pli (1.2), l\'amplification monte vers le plancher du
      // survey (0.9 → ×1.35) : incliner le téléphone fait glisser le
      // ciel — la fenêtre sur l\'infini, pas une carte sous verre.
      expect(ParallaxMath.parallaxCalm(1.2), closeTo(1.0, 1e-9),
          reason: 'continu au pli');
      expect(ParallaxMath.parallaxCalm(0.9), closeTo(1.35, 1e-9),
          reason: '×1.35 au plancher du survey');
      for (var z = 0.9; z <= 1.2; z += 0.05) {
        expect(ParallaxMath.parallaxCalm(z), inInclusiveRange(1.0, 1.35));
        expect(ParallaxMath.parallaxCalm(z + 0.05) <=
                ParallaxMath.parallaxCalm(z) + 1e-9, isTrue,
            reason: 'reculer amplifie, sans à-coup');
      }
    });

    test('zoomer approfondit, dézoomer recule — jamais de renversement', () {
      final s = ParallaxMath.zoomScale;
      expect(s(2.5), greaterThan(1.0));
      // L'ancre vit au survey (V3.69) : sous 1,0 l'étoile rétrécit.
      expect(s(0.9), lessThan(1.0));
      // Monotone sur toute la plage de l'œil.
      var previous = s(0.9);
      for (var z = 1.0; z <= 8.0; z += 0.1) {
        final v = s(double.parse(z.toStringAsFixed(1)));
        expect(v, greaterThan(previous));
        previous = v;
      }
    });

    test('subtil par construction : jamais des ballons', () {
      // Au zoom maximal (8), une ÉTOILE ne grossit que ~3,5× (les
      // corps du système sont world-sized depuis V3.69 — eux
      // reculent et grandissent avec le monde).
      expect(ParallaxMath.zoomScale(8.0), closeTo(3.48, 0.05));
      // Au plancher du survey (0,9), à peine plus petit (~0,94×) —
      // V3.69 : l'ancre vit au survey, 1,0.
      expect(ParallaxMath.zoomScale(0.9), closeTo(0.94, 0.02));
    });
  });

  group('ParallaxMath.glimmerFullRate (V3.37 — la cadence du scintillement)',
      () {
    test("l'œil au repos garde le demi-rythme (la batterie du sanctuaire)",
        () {
      expect(ParallaxMath.glimmerFullRate(1.75), isFalse);
      expect(ParallaxMath.glimmerFullRate(2.9), isFalse);
    });

    test('la veille profonde suit chaque battement — 30 fps y saccade', () {
      expect(ParallaxMath.glimmerFullRate(3.0), isTrue);
      expect(ParallaxMath.glimmerFullRate(8.0), isTrue);
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
