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
    });
  });
}
