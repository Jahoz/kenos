import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/domain/note_phrase.dart';

/// The constellation-song's soul: a phrase is a few integers, sealed
/// as the line's payload — poems stay text, songs parse, silence
/// never errors. And a closed song is an artifact: readable twice.
void main() {
  group('NotePhrase', () {
    test('round-trip: la phrase scellée revient entière', () {
      const phrase = NotePhrase([0, 4, 7, 12, 19]);
      final parsed = NotePhrase.tryParse(phrase.encode());
      expect(parsed, isNotNull);
      expect(parsed!.notes, [0, 4, 7, 12, 19]);
    });

    test('une ligne de poème ne se parse pas en phrase', () {
      expect(NotePhrase.tryParse('je navigue dans le vide pour toi'), isNull);
    });

    test('bornes : 1..8 notes, indices dans la gamme', () {
      expect(const NotePhrase([]).isValid, isFalse);
      expect(
        const NotePhrase([0, 1, 2, 3, 4, 5, 6, 7, 8]).isValid,
        isFalse,
        reason: '9 notes = pas une phrase',
      );
      expect(const NotePhrase([20]).isValid, isFalse, reason: 'hors gamme');
      expect(NotePhrase.tryParse('{"n":[99]}'), isNull);
    });

    test('un payload cassé lit en silence, jamais en erreur', () {
      expect(NotePhrase.tryParse('{"n":'), isNull);
      expect(NotePhrase.tryParse('{"x":1}'), isNull);
    });
  });

  group('LocalConstellationRepository — la chanson', () {
    test('semer en MELODY, phrases séquentielles, artefact re-lisible',
        () async {
      final repo = LocalConstellationRepository();
      final song = await repo.seed(0.5, 0.5, kind: ConstellationKind.melody);
      expect(song.kind, ConstellationKind.melody);

      // The first stranger hears NOTHING before them — they open it.
      final first = await repo.peekPrevious(song.id);
      expect(first, isNull);

      // Each phrase continues the previous one (the classic rule).
      final r1 = await repo.contribute(
        constellationId: song.id,
        text: const NotePhrase([0, 4, 7]).encode(),
      );
      expect(r1.previous, isNull);

      final peeked = await repo.peekPrevious(song.id);
      expect(peeked, isNotNull);
      final phrase = NotePhrase.tryParse(peeked!.text);
      expect(phrase?.notes, [0, 4, 7]);

      final r2 = await repo.contribute(
        constellationId: song.id,
        text: const NotePhrase([12, 9]).encode(),
      );
      expect(r2.previous, isNotNull);
      expect(NotePhrase.tryParse(r2.previous!.text)?.notes, [0, 4, 7]);

      // Close it, read it TWICE: the artifact stays.
      while (true) {
        final meta = (await repo.fetchVisible()).first;
        if (meta.isClosed) break;
        await repo.contribute(
          constellationId: song.id,
          text: const NotePhrase([2]).encode(),
        );
      }
      final reading1 = await repo.read(song.id);
      final reading2 = await repo.read(song.id);
      expect(reading1, isNotNull);
      expect(reading2, isNotNull,
          reason: 'V3.14 : la chanson refermée se réécoute');
      expect(
        reading2!.every((l) => NotePhrase.tryParse(l.text) != null),
        isTrue,
        reason: 'chaque ligne est une phrase de notes',
      );
    });
  });
}
