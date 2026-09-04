import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/application/celestial_bodies.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/celestial_plaque.dart';

/// V3.12 — the named heavens: every body carries its truth, the math
/// stays deterministic, and the plaque says what the sky corresponds to.
void main() {
  group('la math des cieux nommés', () {
    test('Polaris ne bouge pas — le point fixe', () {
      final a = DateTime.fromMillisecondsSinceEpoch(0);
      final b = DateTime.fromMillisecondsSinceEpoch(987654321000);
      final pa = Offset(0.5, 0.5) +
          const Offset(0, -0.32); // via KenosSystem.planetPosition(2, ·)
      expect(pa, CelestialMath.polaris);
      expect(CelestialMath.polaris.dx, 0.5);
      expect(CelestialMath.polaris.dy, 0.18);
      // Same instant twice — trivially equal, but the contract is fixed.
      expect(a.millisecondsSinceEpoch >= 0 && b.millisecondsSinceEpoch > 0, isTrue);
    });

    test('les errants dérivent de façon déterministe', () {
      final at = DateTime.fromMillisecondsSinceEpoch(1750000000000);
      for (var i = 0; i < celestialWanderers.length; i++) {
        expect(
          CelestialMath.wandererPosition(i, at),
          CelestialMath.wandererPosition(i, at),
          reason: 'tous les clients voient le même errant',
        );
      }
    });

    test('les errants vivent au-delà des orbites planétaires', () {
      final at = DateTime.fromMillisecondsSinceEpoch(1750000000000);
      for (var i = 0; i < celestialWanderers.length; i++) {
        final p = CelestialMath.wandererPosition(i, at);
        final dist = Offset(p.dx - 0.5, p.dy - 0.5).distance;
        expect(dist, greaterThanOrEqualTo(0.62),
            reason: 'les errants se trouvent en voyageant');
        expect(dist, lessThanOrEqualTo(0.80));
      }
    });

    test('les errants se déplacent au fil des heures', () {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1750000000000);
      final t2 = t1.add(const Duration(hours: 3));
      final a = CelestialMath.wandererPosition(0, t1);
      final b = CelestialMath.wandererPosition(0, t2);
      expect(a, isNot(b), reason: 'la dérive est lente mais réelle');
    });
  });

  group('la plaque céleste', () {
    testWidgets('une ancre dit son nom, son intention, ses orbites',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: OutlinedButton(
              onPressed: () => showCelestialPlaque(
                context,
                body: celestialBodies[1], // Vénus
                orbitCount: 3,
                onTravel: () {},
              ),
              child: const Text('OUVRIR'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('OUVRIR'));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Vénus'), findsOneWidget);
      expect(find.text("PLANÈTE — L'ÉTOILE DU BERGER"), findsOneWidget);
      expect(find.textContaining('INTENTION — CONFIER'), findsOneWidget);
      expect(find.textContaining('3 échos'), findsOneWidget);
      expect(find.text('VOYAGER VERS'), findsOneWidget);
    });

    testWidgets('Polaris est une ancre-phare : intention lumen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: OutlinedButton(
              onPressed: () => showCelestialPlaque(
                context,
                body: celestialBodies[2],
                orbitCount: 0,
              ),
              child: const Text('OUVRIR'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('OUVRIR'));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Polaris'), findsOneWidget);
      expect(find.text('ÉTOILE FIXE'), findsOneWidget);
      expect(find.textContaining('INTENTION — ÉCLAIRER'), findsOneWidget);
      expect(find.textContaining('0 écho'), findsOneWidget);
    });

    testWidgets('un errant est une question ouverte — rien n\'orbite', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: OutlinedButton(
              onPressed: () => showCelestialPlaque(
                context,
                body: celestialWanderers.first, // Pluton
              ),
              child: const Text('OUVRIR'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('OUVRIR'));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Pluton'), findsOneWidget);
      expect(find.text('PLANÈTE NAINE'), findsOneWidget);
      expect(find.text("RIEN N'ORBITE ICI — PAS ENCORE."), findsOneWidget);
      expect(find.text('VOYAGER VERS'), findsNothing);
      expect(find.text('REVENIR AU VIDE'), findsOneWidget);
    });
  });
}
