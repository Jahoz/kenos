import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/application/kenos_system.dart';

/// V3.12c — serene real estate: everything that RESTS keeps its
/// distance — from the throat, the lanes, the beacon, and each other.
void main() {
  group('resolveResting — rien ne se chevauche au repos', () {
    test('le trou noir reste dégagé', () {
      final q = KenosSystem.resolveResting(const Offset(0.51, 0.5));
      expect((q - KenosSystem.blackHole).distance,
          greaterThanOrEqualTo(KenosSystem.blackHoleExclusion - 1e-9));
    });

    test('les couloirs planétaires sont esquivés', () {
      // Straight on the inner lane (0.26 from the heart).
      final onLane = KenosSystem.blackHole + const Offset(0.26, 0);
      final q = KenosSystem.resolveResting(onLane);
      final d = (q - KenosSystem.blackHole).distance;
      expect((d - KenosSystem.orbitRadiusOf(0)).abs(),
          greaterThanOrEqualTo(0.055 - 1e-9),
          reason: 'un monde chevauche sa file — repoussé hors du couloir');
      final onOuter = KenosSystem.blackHole + const Offset(0, 0.37);
      final q2 = KenosSystem.resolveResting(onOuter);
      final d2 = (q2 - KenosSystem.blackHole).distance;
      expect((d2 - KenosSystem.orbitRadiusOf(1)).abs(),
          greaterThanOrEqualTo(0.055 - 1e-9));
    });

    test('Polaris garde son ciel dégagé', () {
      final q = KenosSystem.resolveResting(
        Offset(0.5, 0.5 - 0.32), // exactly on the beacon
      );
      // Polaris's beacon rays reach ~0.05: the resting body is out.
      expect(q, isNot(const Offset(0.5, 0.18)),
          reason: 'rien ne repose sur le phare');
    });

    test('deux statiques à la même position se séparent', () {
      const spot = Offset(0.7, 0.3);
      final a = KenosSystem.resolveResting(spot);
      final b = KenosSystem.resolveResting(spot, occupied: [a]);
      expect((a - b).distance, greaterThanOrEqualTo(0.05),
          reason: 'aucun empilement permanent');
    });

    test('une grappe de statiques finit dégagée (passes bornées)', () {
      final placed = <Offset>[];
      for (var i = 0; i < 8; i++) {
        placed.add(KenosSystem.resolveResting(
          const Offset(0.75, 0.25),
          occupied: placed,
        ));
      }
      for (var i = 0; i < placed.length; i++) {
        for (var j = i + 1; j < placed.length; j++) {
          expect((placed[i] - placed[j]).distance, greaterThan(0.04),
              reason: 'les corps $i et $j se chevauchent encore');
        }
      }
    });

    test('déterministe : même entrée, même sortie', () {
      final a = KenosSystem.resolveResting(
        const Offset(0.62, 0.42),
        occupied: const [Offset(0.63, 0.41)],
      );
      final b = KenosSystem.resolveResting(
        const Offset(0.62, 0.42),
        occupied: const [Offset(0.63, 0.41)],
      );
      expect(a, b);
    });

    test('les positions restent dans l\'éther connu', () {
      final q = KenosSystem.resolveResting(const Offset(0.999, 0.999));
      expect(q.dx, lessThanOrEqualTo(0.98));
      expect(q.dy, lessThanOrEqualTo(0.98));
    });
  });
}
