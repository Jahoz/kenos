import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/presentation/constellation_sheets.dart';

/// V3.46 — the poem's MEASURE, told before the hand writes: the
/// stations (full = lines given, hollow = owed) and the law — the
/// LAST line closes the poem by itself. Nobody seals a corpse.
void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    required int lineCount,
    required int target,
    bool song = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          constellationRepositoryProvider.overrideWithValue(
            _StubRepository(),
          ),
        ],
        child: MaterialApp(
          home: _SheetHost(
            lineCount: lineCount,
            target: target,
            song: song,
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pump();
  }

  testWidgets('la feuille dit la mesure : LIGNE 3 SUR 5, la dernière referme',
      (tester) async {
    await openSheet(tester, lineCount: 2, target: 5);
    expect(
      find.textContaining('LIGNE 3 SUR 5'),
      findsOneWidget,
      reason: 'où le poème en est, où il finit',
    );
    expect(
      find.textContaining('LA DERNIÈRE REFERME'),
      findsOneWidget,
      reason: 'la loi : personne ne scelle un cadavre',
    );
    // The stations: two full (given), three hollow (owed).
    expect(find.text('●'), findsNWidgets(2));
    expect(find.text('○'), findsNWidgets(3));
  });

  testWidgets('la chanson parle en phrases', (tester) async {
    await openSheet(tester, lineCount: 1, target: 4, song: true);
    expect(find.textContaining('PHRASE 2 SUR 4'), findsOneWidget);
    expect(find.textContaining('REFERME LA CHANSON'), findsOneWidget);
  });

  testWidgets("la main sait quand elle tient la dernière", (tester) async {
    await openSheet(tester, lineCount: 3, target: 4);
    expect(find.textContaining('LIGNE 4 SUR 4'), findsOneWidget);
    expect(find.text('●'), findsNWidgets(3));
    expect(find.text('○'), findsNWidgets(1));
  });

  testWidgets('V3.47 — un anneau vierge dit ce qu\'il est : planté, pas un leurre',
      (tester) async {
    await openSheet(tester, lineCount: 0, target: 5);
    expect(
      find.textContaining('planté vide dans l\'éther'),
      findsOneWidget,
      reason: 'l\'anneau vide s\'explique : le Jardinier sème des anneaux '
          'neufs pour qu\'une première main ait toujours où atterrir — '
          'jamais un faux bouton de création',
    );
    expect(find.textContaining('La première ligne est à toi'), findsOneWidget);
    // And the measure agrees: nothing full, everything owed.
    expect(find.text('●'), findsNothing);
    expect(find.text('○'), findsNWidgets(5));
  });
}

class _SheetHost extends ConsumerWidget {
  const _SheetHost({
    required this.lineCount,
    required this.target,
    required this.song,
  });

  final int lineCount;
  final int target;
  final bool song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => unawaited(
        showContributeSheet(
          context,
          ref: ref,
          constellation: ConstellationMeta(
            id: 'c1',
            seedX: 0.5,
            seedY: 0.5,
            state: 'OPEN',
            lineCount: lineCount,
            target: target,
            kind: song ? ConstellationKind.melody : ConstellationKind.poem,
          ),
        ),
      ),
      child: const Text('OPEN'),
    );
  }
}

class _StubRepository implements ConstellationRepository {
  @override
  Future<bool?> hasContributed(String id) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
