import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/cosmic_map/application/travel_camera.dart';
import 'package:kenos/features/create_echo/presentation/mirror_screen.dart';

/// The Mirror's fourth mode: CADAVRE drops an open ring near the eye
/// and pops with the fresh id — the map then offers the seeder to
/// give the FIRST blind line. Before this existed, seeding a corpse
/// had NO UI at all.
void main() {
  late FakeConstellationRepository repo;

  setUp(() {
    repo = FakeConstellationRepository();
  });

  Future<void> pumpMirror(WidgetTester tester) async {
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
              // Push the Mirror like the map's gate does, capturing
              // the pop result (the fresh corpse id).
              onPressed: () async {
                repo.poppedWith = await Navigator.of(context)
                    .push<String?>(
                      MaterialPageRoute(builder: (_) => const MirrorScreen()),
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

  testWidgets('les modes portent des noms — le cadavre est visible',
      (tester) async {
    await pumpMirror(tester);
    expect(find.text('CADAVRE'), findsOneWidget,
        reason: 'la bande de modes remplace les icônes muettes');
    expect(find.text('PORTE'), findsOneWidget);
    expect(find.text('APAISER'), findsOneWidget,
        reason: 'le thème se lit');
  });

  testWidgets('larguer un cadavre : anneau près de l\'œil, id au pop',
      (tester) async {
    await pumpMirror(tester);

    await tester.tap(find.text('CADAVRE'));
    await tester.pumpAndSettle();
    expect(find.text('Un cadavre exquis'), findsOneWidget);

    await tester.tap(find.text('LARGUER UN POÈME'));
    await tester.pumpAndSettle();

    // Seeded ONCE, near the resting eye (±0.06 jitter).
    expect(repo.seeds, hasLength(1));
    expect(repo.seeds.single.dx, inExclusiveRange(0.44, 0.56));
    expect(repo.seeds.single.dy, inExclusiveRange(0.44, 0.56));

    // The Mirror popped with the fresh corpse id.
    expect(repo.poppedWith, 'corpse-fresh');
    expect(find.byType(MirrorScreen), findsNothing);
  });
}

class FakeConstellationRepository implements ConstellationRepository {
  final List<Offset> seeds = [];
  String? poppedWith;

  @override
  Future<ConstellationMeta> seed(
    double x,
    double y, {
    ConstellationKind kind = ConstellationKind.poem,
  }) async {
    seeds.add(Offset(x, y));
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
