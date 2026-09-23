import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/presentation/constellation_sheets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The prod reports, each pinned to its fix:
///  - long artifacts overflowed phones with no scroll;
///  - the ether's refusals were a shrug ('refused') when the reason
///    existed (ALREADY_CONTRIBUTED on a sheet the app itself had
///    re-offered);
///  - a reaped or closed ring still offered its keyboard — the truth
///    now lands at the peek, before a line is ever typed.
void main() {
  group('contributeRefusalMessage — le refus dit son nom', () {
    test('déjà contribué : ce sont les mêmes mains', () {
      expect(
        contributeRefusalMessage(
          const PostgrestException(message:'KENOS_ALREADY_CONTRIBUTED'),
        ),
        'TA PHRASE EST DÉJÀ DANS CE CORPS.',
      );
    });

    test('cadence : le ciel souffle deux minutes', () {
      expect(
        contributeRefusalMessage(
          const PostgrestException(message:'KENOS_RATE_LIMIT'),
        ),
        contains('DEUX MINUTES'),
      );
    });

    test('refermé ailleurs, trop long, anneau dissous, méconnaissance', () {
      expect(
        contributeRefusalMessage(const PostgrestException(message:'KENOS_CLOSED')),
        'LE POÈME S\'EST REFERMÉ AILLEURS.',
      );
      expect(
        contributeRefusalMessage(
          const PostgrestException(message:'KENOS_INVALID_LENGTH'),
        ),
        contains('TROP LONGUE'),
      );
      // The reaped ring (OPEN past its seven days): the map can show
      // it up to a breath late — the refusal must say what happened.
      expect(
        contributeRefusalMessage(
          const PostgrestException(message:'KENOS_NOT_FOUND'),
        ),
        'CET ANNEAU A RETOURNÉ AU VIDE.',
      );
      expect(
        contributeRefusalMessage(
          const PostgrestException(message:'KENOS_UNAUTHENTICATED'),
        ),
        'L\'ÉTHER NE TE RECONNAÎT PLUS.',
      );
    });

    test('le serveur a parlé sans code connu : un vrai refus', () {
      expect(
        contributeRefusalMessage(const PostgrestException(message: 'boom')),
        'L\'ÉTHER A REFUSÉ LA LIGNE.',
      );
    });

    test('rien n\'a été refusé quand l\'éther n\'a pas répondu', () {
      expect(
        contributeRefusalMessage(Exception('SocketException: the sky is far')),
        'L\'ÉTHER EST INJOIGNABLE — LA LIGNE RESTE À TOI.',
      );
    });
  });

  group('seedRefusalMessage — le garde dit son remède', () {
    test('cadence : deux minutes entre deux anneaux', () {
      expect(
        seedRefusalMessage(const PostgrestException(message:'KENOS_RATE_LIMIT')),
        'LE CIEL SOUFFLE — DEUX MINUTES ENTRE DEUX ANNEAUX.',
      );
    });

    test('plafond : cinq poèmes ouverts par main', () {
      expect(
        seedRefusalMessage(const PostgrestException(message:'KENOS_SEED_CAP')),
        'TA MAIN TIENT DÉJÀ CINQ POÈMES OUVERTS.',
      );
    });

    test('méconnaissance, injoignable, refus inconnu', () {
      expect(
        seedRefusalMessage(
          const PostgrestException(message:'KENOS_UNAUTHENTICATED'),
        ),
        'L\'ÉTHER NE TE RECONNAÎT PLUS.',
      );
      expect(
        seedRefusalMessage(Exception('SocketException: the sky is far')),
        'L\'ÉTHER EST INJOIGNABLE.',
      );
      expect(
        seedRefusalMessage(const PostgrestException(message: 'boom')),
        'L\'ÉTHER A REFUSÉ LA CONSTELLATION.',
      );
    });
  });

  group('refusalOf — the structural interpreter (audit 2026-09-23)', () {
    test('reads the code from typed fields, never from toString', () {
      expect(
        refusalOf(const PostgrestException(message: 'KENOS_CLOSED')),
        ConstellationRefusal.closed,
      );
      // Demo parity: the local repositories raise StateError('KENOS_*').
      expect(
        refusalOf(StateError('KENOS_NOT_FOUND')),
        ConstellationRefusal.notFound,
      );
      // The typed salon refusal.
      expect(
        refusalOf(const SalonKeyRefused()),
        ConstellationRefusal.inviteUnknown,
      );
    });

    test('no code, no refusal — but the ether still answered', () {
      // A PostgrestException with no known code (e.g. SQLSTATE 42501):
      // a true refusal, just not one the grammar names.
      expect(
        refusalOf(const PostgrestException(code: '42501', message: '')),
        isNull,
      );
      expect(
        etherAnswered(const PostgrestException(code: '42501', message: '')),
        isTrue,
      );
      // Anything else is the sky being far: nothing was refused.
      expect(refusalOf(Exception('SocketException')), isNull);
      expect(etherAnswered(Exception('SocketException')), isFalse);
      // String sniffing is gone: a bare exception whose TEXT carries
      // the token is NOT a refusal — only typed fields speak.
      expect(refusalOf(Exception('KENOS_CLOSED')), isNull);
    });

    test('a PostgrestException whose message hides the token still maps', () {
      expect(
        refusalOf(const PostgrestException(
          code: 'P0001',
          message: 'raise_exception: KENOS_SEED_CAP — five open rings',
        )),
        ConstellationRefusal.seedCap,
      );
    });
  });

  group('petits écrans : un long artefact défile, ne déborde pas', () {
    testWidgets('sept lignes longues sur un téléphone — aucun débordement',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The reading panel reads the interface voice (V3.52): scope above.
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
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

