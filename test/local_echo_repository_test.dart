import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/echo/data/echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';

void main() {
  LocalEchoRepository newRepo() =>
      LocalEchoRepository.seeded(latency: const Duration(milliseconds: 5));

  group('LocalEchoRepository (sémantique du backend)', () {
    test('la carte ne contient que des métadonnées, jamais de texte', () async {
      final repo = newRepo();
      final map = await repo.fetchStarMap();
      expect(map, isNotEmpty);
      for (final echo in map) {
        expect(echo.text, isNull, reason: 'fuite de texte sur ${echo.id}');
        expect(echo.isMine, isFalse);
      }
    });

    test(
      'lecture unique : consommation concurrente, un seul vainqueur',
      () async {
        final repo = newRepo();
        final target = (await repo.fetchStarMap()).first;

        final results = await Future.wait(
          List.generate(8, (_) => repo.consumeEcho(target.id)),
        );

        final winners = results.where((t) => t != null).toList();
        expect(winners.length, 1, reason: 'deux lecteurs ont gagné la course');
        expect(winners.single, isNotNull);

        // The consumed echo disappears from the map.
        final mapAfter = await repo.fetchStarMap();
        expect(mapAfter.map((e) => e.id), isNot(contains(target.id)));
      },
    );

    test('une seconde consommation du même écho retourne null', () async {
      final repo = newRepo();
      final target = (await repo.fetchStarMap()).first;
      expect(await repo.consumeEcho(target.id), isNotNull);
      expect(await repo.consumeEcho(target.id), isNull);
    });

    test('signalement : une lecture autorise un seul motif', () async {
      final repo = newRepo();
      final target = (await repo.fetchStarMap()).first;
      await repo.consumeEcho(target.id);

      expect(
        await repo.reportEcho(target.id, EchoReportReason.inappropriate),
        isTrue,
      );
      expect(
        await repo.reportEcho(target.id, EchoReportReason.spam),
        isFalse,
      );
    });

    test('un id inconnu retourne null (jamais d\'exception)', () async {
      final repo = newRepo();
      expect(await repo.consumeEcho('id-inexistant'), isNull);
    });

    test('l\'écho envoyé revient scellé : isMine, sans texte, z = 1', () async {
      final repo = newRepo();
      final echo = await repo.sendEcho(
        text: 'un aveu',
        coordX: 0.4,
        coordY: 0.6,
        coordZ: 1.0,
        theme: EchoColorTheme.indigo,
      );
      expect(echo.isMine, isTrue);
      expect(echo.text, isNull, reason: 'même son auteur ne relit plus');
      expect(echo.coordZ, 1.0);
      // And it does not appear as readable in the public ether.
      final map = await repo.fetchStarMap();
      expect(map.map((e) => e.id), isNot(contains(echo.id)));
    });
  });
}
