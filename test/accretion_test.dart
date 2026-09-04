import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/constants/app_colors.dart';
import 'package:kenos/features/cosmic_map/application/accretion.dart';
import 'package:kenos/features/cosmic_map/application/kenos_system.dart';

/// V3.12b — nothing rests upon the black hole, and what dies falls in.
void main() {
  group('outsideTheHole — rien ne repose sur le trou noir', () {
    test('une position extérieure reste où elle est', () {
      const far = Offset(0.9, 0.1);
      expect(KenosSystem.outsideTheHole(far), far);
    });

    test('une position dans l\'exclusion est repoussée au bord', () {
      final nudged = KenosSystem.outsideTheHole(const Offset(0.55, 0.5));
      final dist = (nudged - KenosSystem.blackHole).distance;
      expect(dist, closeTo(KenosSystem.blackHoleExclusion, 1e-9));
      expect(nudged.dx, greaterThan(0.55),
          reason: 'la poussée suit le rayon propre de l\'objet');
    });

    test('le centre exact est repoussé vers le haut, de façon stable', () {
      final nudged = KenosSystem.outsideTheHole(KenosSystem.blackHole);
      expect(nudged.dy, KenosSystem.blackHole.dy - KenosSystem.blackHoleExclusion);
      expect(KenosSystem.outsideTheHole(nudged), nudged,
          reason: 'idempotent : déjà au bord, on n\'insiste pas');
    });

    test('la garde est idempotente — pas de dérive au re-render', () {
      var p = const Offset(0.52, 0.51);
      final once = KenosSystem.outsideTheHole(p);
      final twice = KenosSystem.outsideTheHole(once);
      expect(twice, once);
      p = once;
      expect(p, once);
    });

    test('les vestiges et cadavres ne recouvrent jamais le disque', () {
      // Sweep the whole ether: after the guard, nothing sits inside.
      for (var x = 0.30; x <= 0.70; x += 0.02) {
        for (var y = 0.30; y <= 0.70; y += 0.02) {
          final p = KenosSystem.outsideTheHole(Offset(x, y));
          expect((p - KenosSystem.blackHole).distance,
              greaterThanOrEqualTo(KenosSystem.blackHoleExclusion - 1e-9));
        }
      }
    });
  });

  group('AccretionController — ce qui meurt tombe', () {
    test('feed ajoute une chute et le vidage est honnête', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller =
          container.read(accretionProvider.notifier);

      expect(container.read(accretionProvider), isEmpty);
      controller.feed(const Offset(0.3, 0.2), tint: AppColors.teal);
      controller.feed(const Offset(0.8, 0.7));

      final motes = container.read(accretionProvider);
      expect(motes.length, 2);
      expect(motes.first.origin, const Offset(0.3, 0.2));
      expect(motes.first.tint, AppColors.teal);
    });

    test('la spirale se referme et accélère — le rayon décroît', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(accretionProvider.notifier);
      controller.feed(const Offset(0.5, 0.1)); // r0 = 0.4

      final mote = container.read(accretionProvider).single;
      var lastRadius = 0.4;
      for (var t = 0.1; t < 1.0; t += 0.1) {
        final (radius, _) = AccretionController.spiralAt(mote, t);
        expect(radius, lessThan(lastRadius),
            reason: 'la chute ne fait que se rapprocher du vide');
        lastRadius = radius;
      }
      expect(AccretionController.spiralAt(mote, 1.0).$1, closeTo(0.0, 1e-9),
          reason: 't=1 : l\'horizon est atteint');
    });

    test('la couleur rougit en tombant — vers l\'anneau d\'accrétion', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(accretionProvider.notifier);
      controller.feed(const Offset(0.2, 0.5), tint: AppColors.teal);
      final mote = container.read(accretionProvider).single;

      final start = AccretionController.colorAt(mote, 0);
      final end = AccretionController.colorAt(mote, 1);
      expect(start, AppColors.teal);
      expect(end, AppColors.roseText);
    });
  });
}
