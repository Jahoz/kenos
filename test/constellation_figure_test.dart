import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/domain/constellation_figure.dart';
import 'package:kenos/features/constellations/presentation/constellation_sheets.dart';

/// V3.11b — the emergent figure's arithmetic: golden-angle stations,
/// deterministic on every client, never two stars in one direction.
void main() {
  group('déterminisme', () {
    test('même index, même station — tous les clients voient la même figure',
        () {
      for (var k = 0; k < 7; k++) {
        expect(
          ConstellationFigure.starAt(k, target: 5),
          ConstellationFigure.starAt(k, target: 5),
        );
      }
    });

    test('sept stations, sept positions distinctes', () {
      final seen = <Offset>{
        for (var k = 0; k < 7; k++) ConstellationFigure.starAt(k, target: 7),
      };
      expect(seen.length, 7, reason: "deux lignes ne peuvent partager une étoile");
    });
  });

  group('la spirale de l\'angle d\'or', () {
    test('le rayon croît avec chaque ligne — la figure s\'étend', () {
      double radiusAt(int k) =>
          ConstellationFigure.starAt(k, target: 7).distance;
      for (var k = 1; k < 7; k++) {
        expect(radiusAt(k), greaterThan(radiusAt(k - 1)),
            reason: 'la ligne $k doit s\'éloigner de la graine');
      }
    });

    test('chaque station avance de l\'angle d\'or (~137,5°)', () {
      final a = ConstellationFigure.starAt(0, target: 5);
      final b = ConstellationFigure.starAt(1, target: 5);
      final angleA = a.direction;
      final angleB = b.direction;
      final delta = (angleB - angleA).abs();
      const golden = 2 * 3.141592653589793 * 0.38196601125010515;
      expect((delta - golden).abs(), lessThan(0.001));
    });

    test('toutes les stations restent dans le cercle unité', () {
      for (var k = 0; k < 7; k++) {
        expect(
          ConstellationFigure.starAt(k, target: 7).distance,
          lessThanOrEqualTo(1.0),
        );
      }
    });

    test('la graine oriente la première ligne vers le haut', () {
      final first = ConstellationFigure.starAt(0, target: 4);
      expect(first.dy, lessThan(0), reason: 'première étoile au nord de la graine');
    });
  });

  group('les étoiles dessinées', () {
    test('lineCount borne le dessin à la cible', () {
      expect(ConstellationFigure.drawnStars(9, target: 5).length, 5);
      expect(ConstellationFigure.drawnStars(3, target: 5).length, 3);
      expect(ConstellationFigure.drawnStars(0, target: 5), isEmpty);
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
