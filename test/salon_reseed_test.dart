import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/presentation/constellation_sheets.dart';

void main() {
  group('The second key — demo parity (V3.53)', () {
    test('an untouched door gives a fresh key, the old one dies', () async {
      final repo = LocalConstellationRepository();
      final seeded = await repo.seed(0.5, 0.5, invited: true);
      final id = seeded.meta.id;
      final oldToken = seeded.inviteToken!;

      final fresh = await repo.reseedKey(id);
      expect(fresh, isNot(oldToken));
      // Exactly one living key: the drop's token opens nothing.
      expect(() => repo.fetchInvited(oldToken), throwsSalonKeyRefused);
      final meta = await repo.fetchInvited(fresh);
      expect(meta.id, id);
      // And the living key still claims.
      final result = await repo.contribute(
        constellationId: id,
        text: 'première ligne, clé neuve',
        inviteToken: fresh,
      );
      expect(result.count, 1);
    });

    test('one line and the door is locked forever', () async {
      final repo = LocalConstellationRepository();
      final seeded = await repo.seed(0.5, 0.5, invited: true);
      await repo.contribute(
        constellationId: seeded.meta.id,
        text: 'la ligne qui verrouille',
        inviteToken: seeded.inviteToken,
      );
      expect(
        () => repo.reseedKey(seeded.meta.id),
        throwsStateError,
      );
    });

    test('a public ring is no salon', () async {
      final repo = LocalConstellationRepository();
      final seeded = await repo.seed(0.5, 0.5);
      expect(
        () => repo.reseedKey(seeded.meta.id),
        throwsStateError,
      );
    });
  });

  group('The refusal grammar speaks the door\'s reasons', () {
    test('every guard has its word', () {
      expect(
        reseedRefusalMessage(const _Refused('KENOS_LINES_EXIST')),
        'LA PORTE A DÉJÀ ÉTÉ TOUCHÉE.',
      );
      expect(
        reseedRefusalMessage(const _Refused('KENOS_CLOSED')),
        'LE POÈME S\'EST REFERMÉ.',
      );
      expect(
        reseedRefusalMessage(const _Refused('KENOS_NOT_FOUND')),
        'AUCUNE PORTE À RESEMER.',
      );
      expect(
        reseedRefusalMessage(const _Refused('KENOS_UNAUTHENTICATED')),
        'L\'ÉTHER NE TE RECONNAÎT PLUS.',
      );
      expect(
        reseedRefusalMessage(const _FarSky()),
        'L\'ÉTHER EST INJOIGNABLE.',
      );
    });
  });

  group('The untouched door\'s question', () {
    testWidgets('two honest choices, dismissal answers nothing', (
      tester,
    ) async {
      UntouchedDoorChoice? answer = UntouchedDoorChoice.contribute;
      var song = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: OutlinedButton(
                    onPressed: () async {
                      answer = await showUntouchedDoorChoice(
                        context,
                        song: song,
                      );
                    },
                    child: const Text('FRAPPER'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('FRAPPER'));
      await tester.pumpAndSettle();

      expect(find.text('LA PORTE N\'A PAS ENCORE ÉTÉ TOUCHÉE'),
          findsOneWidget);
      expect(find.textContaining('la précédente mourra'), findsOneWidget);
      expect(find.text('POSER MA LIGNE'), findsOneWidget);
      expect(find.text('TAILLER UNE NOUVELLE CLÉ'), findsOneWidget);

      await tester.tap(find.text('TAILLER UNE NOUVELLE CLÉ'));
      await tester.pumpAndSettle();
      expect(answer, UntouchedDoorChoice.reseed);

      // The song speaks in phrases; dismissal answers nothing.
      song = true;
      await tester.tap(find.text('FRAPPER'));
      await tester.pumpAndSettle();
      expect(find.text('POSER MA PHRASE'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(answer, isNull);
    });
  });
}

/// A PostgREST-shaped refusal (the mapper reads toString(), like the
/// other kenos mappers — the KENOS_* code crosses before the type).
class _Refused implements Exception {
  const _Refused(this.code);
  final String code;

  @override
  String toString() => 'PostgrestException: $code';
}

class _FarSky implements Exception {
  const _FarSky();
}

Matcher throwsSalonKeyRefused = throwsA(isA<SalonKeyRefused>());
