import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/application/celestial_bodies.dart';
import 'package:kenos/features/cosmic_map/application/void_territories.dart';

/// V3.35 — the landscapes of the void: three territories told by
/// radius from the heart, their boundaries honest against the sky's
/// own laws (the exclusion, Venus's swarm rim, Polaris's corner, the
/// wanderers' ring), and the drone's depth curve — fullest among the
/// gardens, drunk by the throat, thin in the far country.
void main() {
  group('boundaries', () {
    test('the eye is born in the throat', () {
      expect(
        VoidTerritories.territoryAt(const Offset(0.5, 0.5)),
        VoidTerritory.throat,
      );
    });

    test('the throat reaches past the resting exclusion, no further', () {
      // (Margins, not equality — binary floats make exact-edge tests
      // lie: 0.68999… − 0.5 lands a hair under 0.19.)
      expect(
        VoidTerritories.territoryAt(const Offset(0.5 + 0.15, 0.5)),
        VoidTerritory.throat,
      );
      expect(
        VoidTerritories.territoryAt(const Offset(0.5 + 0.1899, 0.5)),
        VoidTerritory.throat,
      );
      expect(
        VoidTerritories.territoryAt(const Offset(0.5 + 0.191, 0.5)),
        VoidTerritory.gardens,
      );
    });

    test('Polaris watches the system — she is not of the far country', () {
      // Her corner sits at r ≈ 0.523, inside the gardens edge (0.54).
      expect(
        VoidTerritories.territoryAt(CelestialMath.polaris),
        VoidTerritory.gardens,
      );
    });

    test('the far country begins beyond the gardens edge', () {
      expect(
        VoidTerritories.territoryAt(const Offset(0.5 + 0.539, 0.5)),
        VoidTerritory.gardens,
      );
      expect(
        VoidTerritories.territoryAt(const Offset(0.5 + 0.541, 0.5)),
        VoidTerritory.farCountry,
      );
      // The world's far corner belongs to it too.
      expect(
        VoidTerritories.territoryAt(const Offset(1.0, 1.0)),
        VoidTerritory.farCountry,
      );
    });

    test('the wanderers live in the far country', () {
      final now = DateTime.utc(2026, 9, 14);
      for (var i = 0; i < celestialWanderers.length; i++) {
        expect(
          VoidTerritories.territoryAt(
            CelestialMath.wandererPosition(i, now),
          ),
          VoidTerritory.farCountry,
          reason: celestialWanderers[i].name,
        );
      }
    });
  });

  group('names', () {
    test('HUD labels are distinct and set', () {
      final labels = VoidTerritory.values.map(VoidTerritories.hudLabel).toSet();
      expect(labels.length, VoidTerritory.values.length);
      for (final t in VoidTerritory.values) {
        expect(VoidTerritories.hudLabel(t), isNotEmpty);
        expect(VoidTerritories.whisperTitle(t), isNotEmpty);
        expect(VoidTerritories.whisperLine(t), isNotEmpty);
      }
    });
  });

  group('the drone drinks the radius', () {
    test('the curve\'s knots, exactly', () {
      expect(VoidTerritories.droneFactor(0.0), closeTo(0.50, 1e-12));
      expect(VoidTerritories.droneFactor(0.19), closeTo(0.85, 1e-12));
      expect(VoidTerritories.droneFactor(0.36), closeTo(1.00, 1e-12));
      expect(VoidTerritories.droneFactor(0.54), closeTo(1.00, 1e-12));
      expect(VoidTerritories.droneFactor(0.70), closeTo(0.60, 1e-12));
    });

    test('clamps outside the curve', () {
      expect(VoidTerritories.droneFactor(-1.0), closeTo(0.50, 1e-12));
      expect(VoidTerritories.droneFactor(5.0), closeTo(0.60, 1e-12));
    });

    test('full among the gardens, thin at the edges — monotone legs', () {
      bool neverFalls(double a, double b) {
        var mono = true;
        var prev = VoidTerritories.droneFactor(a);
        for (var r = a; r <= b; r += (b - a) / 24) {
          final v = VoidTerritories.droneFactor(r);
          if (v < prev - 1e-9) mono = false;
          prev = v;
        }
        return mono;
      }

      expect(neverFalls(0.0, 0.36), isTrue, reason: 'the climb to the gardens');
      expect(neverFalls(0.54, 0.70), isFalse, reason: 'the far thinning');
      // Continuous at every knot.
      for (final r in [0.19, 0.36, 0.54, 0.70]) {
        expect(
          VoidTerritories.droneFactor(r - 1e-9),
          closeTo(VoidTerritories.droneFactor(r), 1e-6),
        );
      }
    });
  });
}
