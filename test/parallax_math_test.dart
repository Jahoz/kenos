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
    test('opacité et flou restent dans des plages sûres', () {
      for (final z in [0.05, 0.2, 0.5, 0.8, 1.0]) {
        expect(ParallaxMath.opacityFor(z), inExclusiveRange(0, 1.01));
        expect(ParallaxMath.blurSigma(z), greaterThanOrEqualTo(0));
        expect(ParallaxMath.coreRadius(z), greaterThan(0));
      }
    });

    test('les objets proches ne sont pas flous, les lointains le sont', () {
      expect(ParallaxMath.blurSigma(1.0), 0);
      expect(ParallaxMath.blurSigma(0.1), greaterThan(0));
    });
  });
}
