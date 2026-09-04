import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/domain/constellation_figure.dart';
import 'package:kenos/features/constellations/presentation/constellation_sheets.dart';

/// V3.11b — the emergent figure's arithmetic: golden-angle stations,
/// deterministic on every client, never two stars in one direction.
/// The corpse's id signs its sky: before the signature, target 4..7
/// meant the whole ether drew four shapes, over and over.
void main() {
  const corpse = '00000000-0000-4000-8000-0000000000c1';

  group('déterminisme', () {
    test('même cadavre, même station — tous les clients voient la même figure',
        () {
      for (var k = 0; k < 7; k++) {
        expect(
          ConstellationFigure.starAt(k, target: 5, id: corpse),
          ConstellationFigure.starAt(k, target: 5, id: corpse),
        );
      }
    });

    test('sept stations, sept positions distinctes', () {
      final seen = <Offset>{
        for (var k = 0; k < 7; k++)
          ConstellationFigure.starAt(k, target: 7, id: corpse),
      };
      expect(seen.length, 7, reason: "deux lignes ne peuvent partager une étoile");
    });
  });

  group('la signature du cadavre', () {
    test('deux cadavres ne partagent pas la même première station', () {
      final a = ConstellationFigure.starAt(0, target: 4, id: 'corpse-a');
      final b = ConstellationFigure.starAt(0, target: 4, id: 'corpse-b');
      expect(a, isNot(b),
          reason: "l'éther ne dessine plus quatre formes pour tous ses cadavres");
    });

    test('cinquante cadavres, cinquante ciels distincts (au moins 40)', () {
      final firsts = <Offset>{
        for (var i = 0; i < 50; i++)
          ConstellationFigure.starAt(0, target: 4, id: 'corpse-$i'),
      };
      expect(firsts.length, greaterThan(40),
          reason: 'la rotation signée doit disperser les figures');
    });

    test('la signature est stable — le hash ne dépend ni de la machine ni du run',
        () {
      // Fixed literal inputs: the FNV-1a output must be identical on
      // every platform (Dart's String.hashCode is process-seeded and
      // would fail this; the multiply is 16-bit-split so the PWA's
      // double-based ints agree with the VM's).
      final a = ConstellationFigure.starAt(3, target: 6, id: 'kenos');
      expect(a.dx, closeTo(0.320991, 0.001));
      expect(a.dy, closeTo(0.682963, 0.001));
    });
  });

  group('la spirale de l\'angle d\'or', () {
    test('le rayon croît avec chaque ligne — la figure s\'étend', () {
      double radiusAt(int k) =>
          ConstellationFigure.starAt(k, target: 7, id: corpse).distance;
      for (var k = 1; k < 7; k++) {
        expect(radiusAt(k), greaterThan(radiusAt(k - 1)),
            reason: 'la ligne $k doit s\'éloigner de la graine');
      }
    });

    test('chaque station avance de l\'angle d\'or (~137,5°), dans son sens', () {
      final a = ConstellationFigure.starAt(0, target: 5, id: corpse);
      final b = ConstellationFigure.starAt(1, target: 5, id: corpse);
      final delta = (b.direction - a.direction).abs();
      const golden = 2 * 3.141592653589793 * 0.38196601125010515;
      expect((delta - golden).abs(), lessThan(0.001));
    });

    test('toutes les stations restent dans le cercle unité', () {
      for (var k = 0; k < 7; k++) {
        expect(
          ConstellationFigure.starAt(k, target: 7, id: corpse).distance,
          lessThanOrEqualTo(1.0),
        );
      }
    });
  });

  group('les étoiles dessinées', () {
    test('lineCount borne le dessin à la cible', () {
      expect(
          ConstellationFigure.drawnStars(9, target: 5, id: corpse).length, 5);
      expect(
          ConstellationFigure.drawnStars(3, target: 5, id: corpse).length, 3);
      expect(ConstellationFigure.drawnStars(0, target: 5, id: corpse), isEmpty);
    });
  });

  testWidgets('le panneau de lecture porte la figure complète au-dessus du poème',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: OutlinedButton(
            onPressed: () => showConstellationReading(
              context,
              figureId: corpse,
              lines: const [
                AssembledLine(number: 1, text: 'première ligne'),
                AssembledLine(number: 2, text: 'deuxième ligne'),
                AssembledLine(number: 3, text: 'troisième ligne'),
                AssembledLine(number: 4, text: 'quatrième ligne'),
              ],
            ),
            child: const Text('OUVRIR'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('OUVRIR'));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('CONSTELLATION REFERMÉE'), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeast(1),
        reason: 'la figure est peinte au-dessus du poème');
    expect(find.text('première ligne'), findsOneWidget);
    expect(find.text('quatrième ligne'), findsOneWidget);
  });
}
