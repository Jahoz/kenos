import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/vestige.dart';

void main() {
  group('Vestiges — la culture curatée', () {
    test('le JSON embarqué charge : vestiges quotidiens, textes sourcés, positions [0,1]',
        () async {
      final vestiges = await loadVestiges();
      expect(vestiges, isNotEmpty);
      // Daily rotation: ~2/3 of the 12 drift on any given day (8 ± a
      // few) — always shards left for tomorrow.
      expect(vestiges.length, greaterThanOrEqualTo(6),
          reason: 'la dérive quotidienne doit rester dense');
      expect(Vestige.knownCount, greaterThanOrEqualTo(12),
          reason: 'la bibliothèque complète est comptée');
      for (final v in vestiges) {
        expect(v.text, isNotEmpty, reason: 'vestige vide : ${v.id}');
        expect(v.source, isNotEmpty, reason: 'sans source : ${v.id}');
        expect(v.offsetX, inInclusiveRange(0, 1));
        expect(v.offsetY, inInclusiveRange(0, 1));
        expect(v.kindLabel, isNot(contains('VESTITVE')),
            reason: 'genre inconnu non fallback : ${v.id}');
      }
    });

    test('la rotation des éclats est déterministe (même ciel partout)', () {
      final at = DateTime(2026, 9, 1, 14, 30); // a moment mid-tumble
      final a = VestigeMath.rotationAt('v001', at);
      final b = VestigeMath.rotationAt('v001', at);
      expect(a, b);
      // Ids hash to different phases — verify at a few moments that
      // they differ at least somewhere in the tumble.
      var differSomewhere = false;
      for (final m in [0, 7, 13, 29, 41]) {
        final t = at.add(Duration(minutes: m));
        if (VestigeMath.rotationAt('v001', t) !=
            VestigeMath.rotationAt('v002', t)) {
          differSomewhere = true;
          break;
        }
      }
      expect(differSomewhere, isTrue,
          reason: 'les éclats ne tournent pas en chœur');
    });

    testWidgets('le panneau vestige rend le texte et la source, re-lisible',
        (tester) async {
      const vestige = Vestige(
        id: 'v-test',
        kind: 'quote',
        text: "On ne se libère pas de ce qu'on garde.",
        source: 'anonyme',
        offsetX: 0.5,
        offsetY: 0.5,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showVestigeSheet(context, vestige: vestige),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining("On ne se libère pas"), findsOneWidget);
      expect(find.text('— anonyme'), findsOneWidget);
      expect(find.textContaining('NE BRÛLE PAS'), findsOneWidget,
          reason: 'un vestige est re-lisible, jamais brûlé');
      // V3.56 — the panel's title says VESTIGE (a one-letter typo
      // called every shard "VESTITVE" since the first delivery).
      expect(find.text('VESTIGE — CITATION'), findsOneWidget);
      expect(find.textContaining('VESTITVE'), findsNothing);
    });
  });

  group('la lune de faveur (V3.58)', () {
    Vestige shard(String id, {DateTime? born}) => Vestige(
          id: id,
          kind: 'fact',
          text: 'un fait vérifiable, assez long pour exister',
          source: 'astronomie',
          offsetX: 0.5,
          offsetY: 0.5,
          createdAt: born,
        );

    test('un éclat de moins d\'une lune dérive TOUS les jours', () {
      final start = DateTime(2026, 9, 17);
      for (var d = 0; d < 40; d++) {
        final day = start.add(Duration(days: d));
        // Fresh AS OF THAT DAY: 29 days old, one before the moon.
        final fresh = shard('fresh', born: day.subtract(const Duration(days: 29)));
        final all = [
          for (var i = 0; i < 40; i++) shard('old$i'),
        ]..insert(3, fresh);
        expect(dailyRotation(all, day), contains(fresh),
            reason: 'jour +$d : publier doit se voir, partout, tout de suite');
      }
    });

    test('la vieille bibliothèque tourne toujours — ~deux tiers, déterministe',
        () {
      final now = DateTime(2026, 9, 17);
      // createdAt null = le canon embarqué, intemporel : la rotation
      // l'a toujours traité ainsi, rien ne change.
      final all = [for (var i = 0; i < 30; i++) shard('canon$i')];
      final a = dailyRotation(all, now);
      final b = dailyRotation(all, now);
      expect(a, b, reason: 'même ciel partout');
      expect(a.length, closeTo(20, 3), reason: '~2/3 de la vieille bibliothèque');
    });

    test('après une lune, l\'éclat rejoint la rotation commune', () {
      final now = DateTime(2026, 9, 17);
      final aged = shard('aged', born: now.subtract(const Duration(days: 31)));
      final all = [
        for (var i = 0; i < 40; i++) shard('old$i'),
      ]..insert(7, aged);
      var hiddenSomeDay = false;
      for (var d = 0; d < 40 && !hiddenSomeDay; d++) {
        hiddenSomeDay = !dailyRotation(all, now.add(Duration(days: d)))
            .contains(aged);
      }
      expect(hiddenSomeDay, isTrue,
          reason: 'la faveur prend fin : l\'éclat vieilli retrouve la rotation');
    });

    test('le fil de l\'ether porte la naissance (created_at)', () {
      final v = Vestige.fromJson({
        'id': 'x',
        'kind': 'fact',
        'text': 'La lumière du Soleil met 8 minutes.',
        'source': 'astronomie',
        'x': 0.5,
        'y': 0.5,
        'created_at': '2026-09-17T07:00:00+00:00',
      });
      expect(v.createdAt, isNotNull);
      expect(Vestige.fromJson({
        'id': 'x',
        'kind': 'fact',
        'text': 't',
        'source': 's',
        'x': 0.5,
        'y': 0.5,
      }).createdAt, isNull, reason: 'le canon embarqué reste intemporel');
    });
  });
}
