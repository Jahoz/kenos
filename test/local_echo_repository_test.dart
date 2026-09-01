import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/echo/data/echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';
import 'package:kenos/features/echo/domain/echo_excerpt.dart';
import 'package:kenos/features/echo/domain/echo_media.dart';

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

  group('V3.10 — les Extraits (parité démo)', () {
    test('la carte porte le genre de porte, jamais la porte elle-même',
        () async {
      final repo = newRepo();
      final map = await repo.fetchStarMap();
      final doors = map.where((e) =>
          e.mediaKind == EchoMediaKind.song ||
          e.mediaKind == EchoMediaKind.video);
      expect(doors, isNotEmpty, reason: "l'éther semé porte des portes");
      for (final door in doors) {
        expect(door.excerpt, isNull, reason: 'la porte vit scellée');
        expect(door.text, isNull);
      }
    });

    test('la porte ne s\'ouvre que pour le lecteur unique, puis meurt',
        () async {
      final repo = newRepo();
      final target = (await repo.fetchStarMap())
          .firstWhere((e) => e.mediaKind == EchoMediaKind.song);
      final consumed = await repo.consumeEcho(target.id);
      expect(consumed, isNotNull);
      expect(consumed!.excerpt, isNotNull);
      expect(consumed.excerpt!.kind, EchoExcerptKind.song);
      // The winner got the real door: the wire form round-trips.
      expect(EchoExcerpt.fromRef(consumed.excerpt!.ref), consumed.excerpt);
      // Single read: the door died with the echo.
      expect(await repo.consumeEcho(target.id), isNull);
    });

    test('l\'écho à extrait part avec le genre de porte, scellé', () async {
      final repo = newRepo();
      const door = EchoExcerpt(
        kind: EchoExcerptKind.video,
        id: 'jfKfPfyJRdk',
        startSeconds: 30,
      );
      final echo = await repo.sendEcho(
        text: 'regarde ça',
        coordX: 0.4,
        coordY: 0.6,
        coordZ: 1.0,
        theme: EchoColorTheme.teal,
        excerpt: door,
      );
      expect(echo.mediaKind, EchoMediaKind.video);
      expect(echo.excerpt, isNull, reason: "même l'auteur ne garde la porte");
    });

    test('fragment OU porte : les deux attachements sont refusés', () async {
      final repo = newRepo();
      await expectLater(
        repo.sendEcho(
          text: 'trop lourd d\'attachements',
          coordX: 0.4,
          coordY: 0.6,
          coordZ: 1.0,
          theme: EchoColorTheme.teal,
          media: EchoMediaDraft(
            kind: EchoMediaKind.image,
            bytes: Uint8List.fromList(List.filled(16, 1)),
            name: 'a.jpg',
          ),
          excerpt: const EchoExcerpt(
            kind: EchoExcerptKind.song,
            id: '4cOdK2wGLETKBW3PvgPWqT',
          ),
        ),
        throwsA(isA<KenosException>()),
      );
    });

    test("V3.10b' — démo : la voix dans le vide décline toujours", () async {
      final repo = newRepo();
      expect(
        await repo.excerptPreviewUrl('4cOdK2wGLETKBW3PvgPWqT'),
        isNull,
        reason: 'hors-ligne, seule la porte demeure',
      );
    });
  });
}
