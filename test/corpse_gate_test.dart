import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/presentation/corpse_screen.dart';
import 'package:kenos/features/cosmic_map/application/kenos_system.dart';
import 'package:kenos/features/cosmic_map/application/travel_camera.dart';

/// The corpse has its own door (SEMER UNE CONSTELLATION on the map)
/// and its own screen — an echo empties oneself, a corpse opens a
/// space for strangers. Pinned: poem or song chosen at the drop, the
/// ring born near the resting eye, the seed pops back to the map for
/// the FIRST blind line — and, since V3.19, WHO the ring waits for:
/// the void, or a salon behind a shareable key.
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
                repo.popped = await Navigator.of(context)
                    .push<SeededConstellation?>(
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

  testWidgets('le choix du public : le vide par défaut, le salon au doigt',
      (tester) async {
    await pumpCorpse(tester);

    // The void is the default — the historic corpse.
    expect(find.text('CONSTELLATION'), findsOneWidget);
    await tester.ensureVisible(find.text('SEMER UN POÈME'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SEMER UN POÈME'));
    await tester.pumpAndSettle();

    expect(repo.invitedFlags, [false]);
    expect(repo.popped, isNotNull);
    expect(repo.popped!.isSalon, isFalse,
        reason: 'dans le vide : pas de porte, pas de clé');
    expect(repo.popped!.inviteToken, isNull);
  });

  testWidgets('EN SALON : la clé naît avec l\'anneau et voyage au pop',
      (tester) async {
    await pumpCorpse(tester);

    await tester.tap(find.byKey(const ValueKey('audience_salon')));
    await tester.pumpAndSettle();
    // The screen speaks the salon: title, hidden ring, the link to
    // come.
    expect(find.text('LE SALON'), findsOneWidget);
    expect(find.text("Un poème à l'aveugle,\nentre invités"), findsOneWidget);

    await tester.ensureVisible(find.text('SEMER UN POÈME'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SEMER UN POÈME'));
    await tester.pumpAndSettle();

    expect(repo.invitedFlags, [true]);
    expect(repo.popped, isNotNull);
    expect(repo.popped!.isSalon, isTrue);
    expect(repo.popped!.inviteToken, 'salon-key-test',
        reason: 'la clé croise le fil exactement une fois, vers le semeur');
    expect(find.byType(CorpseScreen), findsNothing);
  });

  testWidgets('semer un poème : anneau près de l\'œil, graine au pop',
      (tester) async {
    await pumpCorpse(tester);

    await tester.ensureVisible(find.text('SEMER UN POÈME'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SEMER UN POÈME'));
    await tester.pumpAndSettle();

    expect(repo.seeds, hasLength(1));
    // V3.12b: seeding while looking at the black hole still never
    // rests upon it — the corpse is held just outside the horizon,
    // in the eye's neighbourhood.
    final seedDist = (Offset(repo.seeds.single.dx, repo.seeds.single.dy) -
            KenosSystem.blackHole)
        .distance;
    expect(seedDist, greaterThan(KenosSystem.blackHoleExclusion - 1e-9),
        reason: 'jamais sur le trou noir');
    expect(seedDist,
        lessThan(KenosSystem.blackHoleExclusion + 0.2),
        reason: 'mais dans le quartier de l\'œil');
    expect(repo.lastKind, ConstellationKind.poem);
    expect(repo.popped!.meta.id, 'corpse-fresh');
    expect(find.byType(CorpseScreen), findsNothing);
  });

  testWidgets('semer une chanson : le genre voyage', (tester) async {
    await pumpCorpse(tester);

    await tester.ensureVisible(find.text('SEMER UNE CHANSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SEMER UNE CHANSON'));
    await tester.pumpAndSettle();

    expect(repo.lastKind, ConstellationKind.melody);
    expect(repo.popped!.meta.id, 'corpse-fresh');
  });
}

class FakeConstellationRepository implements ConstellationRepository {
  final List<Offset> seeds = [];
  final List<bool> invitedFlags = [];
  SeededConstellation? popped;
  ConstellationKind? lastKind;

  @override
  Future<SeededConstellation> seed(
    double x,
    double y, {
    ConstellationKind kind = ConstellationKind.poem,
    bool invited = false,
  }) async {
    seeds.add(Offset(x, y));
    invitedFlags.add(invited);
    lastKind = kind;
    return SeededConstellation(
      meta: ConstellationMeta(
        id: 'corpse-fresh',
        seedX: x,
        seedY: y,
        state: 'OPEN',
        lineCount: 0,
        target: 5,
        kind: kind,
      ),
      inviteToken: invited ? 'salon-key-test' : null,
    );
  }

  @override
  Future<ContributeResult> contribute({
    required String constellationId,
    required String text,
    String? inviteToken,
  }) async =>
      const ContributeResult(count: 1);

  @override
  Future<bool?> hasContributed(String id) async => null;

  @override
  Future<AssembledLine?> peekPrevious(
    String constellationId, {
    String? inviteToken,
  }) async =>
      null;

  @override
  Future<List<ConstellationMeta>> fetchVisible() async => const [];

  @override
  Future<ConstellationMeta> fetchInvited(String token) async =>
      throw const SalonKeyRefused();

  @override
  Future<List<AssembledLine>?> read(String id) async => null;
}
