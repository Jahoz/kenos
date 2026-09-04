import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/presentation/constellation_sheets.dart';

/// The prod reports, each pinned to its fix:
///  - long artifacts overflowed phones with no scroll;
///  - the ether's refusals were a shrug ('refused') when the reason
///    existed (ALREADY_CONTRIBUTED on a sheet the app itself had
///    re-offered).
void main() {
  group('contributeRefusalMessage — le refus dit son nom', () {
    test('déjà contribué : ce sont les mêmes mains', () {
      expect(
        contributeRefusalMessage(
          const PostgrestExceptionLike('KENOS_ALREADY_CONTRIBUTED'),
        ),
        'TA PHRASE EST DÉJÀ DANS CE CORPS.',
      );
    });

    test('cadence : le ciel souffle deux minutes', () {
      expect(
        contributeRefusalMessage(
          const PostgrestExceptionLike('KENOS_RATE_LIMIT'),
        ),
        contains('DEUX MINUTES'),
      );
    });

    test('refermé ailleurs, trop long, inconnu', () {
      expect(
        contributeRefusalMessage(const PostgrestExceptionLike('KENOS_CLOSED')),
        'LE POÈME S\'EST REFERMÉ AILLEURS.',
      );
      expect(
        contributeRefusalMessage(
          const PostgrestExceptionLike('KENOS_INVALID_LENGTH'),
        ),
        contains('TROP LONGUE'),
      );
      expect(
        contributeRefusalMessage(const PostgrestExceptionLike('boom')),
        'L\'ÉTHER A REFUSÉ LA LIGNE.',
      );
    });
  });

  group('petits écrans : un long artefact défile, ne déborde pas', () {
    testWidgets('sept lignes longues sur un téléphone — aucun débordement',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: OutlinedButton(
              onPressed: () => showConstellationReading(
                context,
                figureId: 'long-poem',
                lines: [
                  for (var i = 1; i <= 7; i++)
                    AssembledLine(
                      number: i,
                      text:
                          'ligne $i — le poème des étrangers s\'étire longuement '
                          'à travers le ciel de personne, encore et encore.',
                    ),
                ],
              ),
              child: const Text('OUVRIR'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('OUVRIR'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // The overflow would surface as a RenderFlex exception — there
      // must be none, and the poem must be scrollable to its end.
      expect(tester.takeException(), isNull,
          reason: 'le poème défile au lieu de déborder');
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.textContaining('ligne 7'), findsOneWidget,
          reason: 'la dernière ligne est atteignable au doigt');
    });
  });
}

/// Minimal stand-in: only `toString()` matters to the mapper.
class PostgrestExceptionLike implements Exception {
  const PostgrestExceptionLike(this.message);
  final String message;

  @override
  String toString() => message;
}
