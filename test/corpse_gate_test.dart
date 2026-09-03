import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/presentation/corpse_screen.dart';
import 'package:kenos/features/cosmic_map/application/travel_camera.dart';

/// The corpse has its own door (OUVRIR UN CADAVRE on the map) and its
/// own screen — an echo empties oneself, a corpse opens a space for
/// strangers. Pinned: poem or song chosen at the drop, the ring born
/// near the resting eye, the id pops back to the map for the FIRST
/// blind line.
void main() {
  late FakeConstellationRepository repo;

  setUp(() {
    repo = FakeConstellationRepository();
  });

  Future<void> pumpCorpse(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          constellationRepositoryProvider.overrideWithValue(repo),
          travelPositionProvider
              .overrideWith((ref) => const Offset(0.5, 0.5)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              // Push like the map's gate, capturing the pop result.
              onPressed: () async {
                repo.poppedWith = await Navigator.of(context).push<String?>(
                  MaterialPageRoute(builder: (_) => const CorpseScreen()),
                );
              },
              child: const Text('GATE'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('GATE'));
    await tester.pumpAndSettle();
  }

  testWidgets('le cadavre a son propre seuil : poème ou chanson',
      (tester) async {
    await pumpCorpse(tester);
    expect(find.text("Un poème à l'aveugle"), findsOneWidget);
    expect(find.text('SEMER UN POÈME'), findsOneWidget);
    expect(find.text('SEMER UNE CHANSON'), findsOneWidget);
    expect(find.text('RENONCER'), findsOneWidget);
  });

  testWidgets('larguer un poème : anneau près de l\'œil, id au pop',
      (tester) async {
    await pumpCorpse(tester);

    await tester.tap(find.text('SEMER UN POÈME'));
    await tester.pumpAndSettle();

    expect(repo.seeds, hasLength(1));
    expect(repo.seeds.single.dx, inExclusiveRange(0.44, 0.56));
    expect(repo.seeds.single.dy, inExclusiveRange(0.44, 0.56));
    expect(repo.lastKind, ConstellationKind.poem);
    expect(repo.poppedWith, 'corpse-fresh');
    expect(find.byType(CorpseScreen), findsNothing);
  });

  testWidgets('larguer une chanson : le genre voyage', (tester) async {
    await pumpCorpse(tester);

    await tester.tap(find.text('SEMER UNE CHANSON'));
    await tester.pumpAndSettle();

    expect(repo.lastKind, ConstellationKind.melody);
    expect(repo.poppedWith, 'corpse-fresh');
  });
}

class FakeConstellationRepository implements ConstellationRepository {
  final List<Offset> seeds = [];
  String? poppedWith;
  ConstellationKind? lastKind;

  @override
  Future<ConstellationMeta> seed(
    double x,
    double y, {
    ConstellationKind kind = ConstellationKind.poem,
  }) async {
    seeds.add(Offset(x, y));
    lastKind = kind;
    return ConstellationMeta(
      id: 'corpse-fresh',
      seedX: x,
      seedY: y,
      state: 'OPEN',
      lineCount: 0,
      target: 5,
      kind: kind,
    );
  }

  @override
  Future<ContributeResult> contribute({
    required String constellationId,
    required String text,
  }) async =>
      const ContributeResult(count: 1);

  @override
  Future<AssembledLine?> peekPrevious(String constellationId) async => null;

  @override
  Future<List<ConstellationMeta>> fetchVisible() async => const [];

  @override
  Future<List<AssembledLine>?> read(String id) async => null;
}
