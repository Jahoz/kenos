import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/presentation/salon_claim_screen.dart';
import 'package:kenos/features/constellations/presentation/salon_share_sheet.dart';
import 'package:kenos/features/cosmic_map/data/artifact_memory.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';

/// LE SALON (V3.19) — the invitable constellation. Pinned here:
/// the demo ether honours the door exactly like the SQL one (key,
/// hiding while written, refusal that says nothing), the invite link
/// carries origin and key, the claim threshold tells every state
/// honestly — and a first-time guest crosses the Seuil BEFORE the
/// door, then lands back on the salon.
void main() {
  group('LocalConstellationRepository — la porte en démo', () {
    test('un anneau salon naît derrière sa clé', () async {
      final repo = LocalConstellationRepository();
      final seeded =
          await repo.seed(0.5, 0.5, invited: true);
      expect(seeded.isSalon, isTrue);
      expect(seeded.inviteToken, startsWith('salon-'));
      expect(seeded.meta.state, 'OPEN');
      expect(seeded.meta.lineCount, 0);
    });

    test('caché en écriture, artefact public refermé', () async {
      final repo = LocalConstellationRepository();
      final seeded = await repo.seed(0.5, 0.5, invited: true);
      final token = seeded.inviteToken!;

      // Hidden while it is written — no two-class ether in demo either.
      expect(await repo.fetchVisible(), isEmpty,
          reason: 'un salon ouvert n\'existe pas sur la carte');

      // The guests fill the ring through the door.
      for (var i = 0; i < seeded.meta.target; i++) {
        await repo.contribute(
          constellationId: seeded.meta.id,
          text: 'ligne $i',
          inviteToken: token,
        );
      }
      final visible = await repo.fetchVisible();
      expect(visible, hasLength(1),
          reason: 'refermé, le salon rejoint le ciel comme un artefact');
      expect(visible.single.isClosed, isTrue);
      expect((await repo.read(seeded.meta.id)), isNotNull);
    });

    test('sans clé ni mauvaise clé : la porte ne dit rien', () async {
      final repo = LocalConstellationRepository();
      final seeded = await repo.seed(0.5, 0.5, invited: true);

      expect(
        () => repo.contribute(
          constellationId: seeded.meta.id,
          text: 'intrusion',
        ),
        throwsA(isA<SalonKeyRefused>()),
        reason: 'sans clé, rien',
      );
      expect(
        () => repo.contribute(
          constellationId: seeded.meta.id,
          text: 'intrusion',
          inviteToken: 'salon-faux',
        ),
        throwsA(isA<SalonKeyRefused>()),
        reason: 'mauvaise clé : exactement comme pas de clé',
      );
      expect(
        () => repo.peekPrevious(seeded.meta.id),
        throwsA(isA<SalonKeyRefused>()),
        reason: 'même le peek demande la clé',
      );
    });

    test('fetchInvited : la clé résout, une clé fausse ne résout rien',
        () async {
      final repo = LocalConstellationRepository();
      final seeded = await repo.seed(0.5, 0.5, invited: true);

      final meta = await repo.fetchInvited(seeded.inviteToken!);
      expect(meta.id, seeded.meta.id);
      expect(meta.state, 'OPEN');
      expect(
        () => repo.fetchInvited('salon-inconnu'),
        throwsA(isA<SalonKeyRefused>()),
      );
    });

    test('le mapper traduit le refus de la porte', () {
      expect(
        contributeRefusalMessage(const SalonKeyRefused()),
        'LE SALON N\'A PAS RECONNU TA CLÉ.',
      );
    });
  });

  group('le lien d\'invitation', () {
    test('sans origine connue, la clé reste honnête', () {
      // The test VM is not the web: no origin, the link says so.
      final link = salonInviteLink('deadbeef01');
      expect(link, '/#/c/deadbeef01');
      expect(link.startsWith('http'), isFalse);
    });

    test('la forme du lien est le chemin du claim', () {
      // Whatever the origin, the path IS the claim route.
      expect(salonInviteLink('k').contains('/c/k'), isTrue);
    });
  });

  group('SalonClaimScreen — le seuil de l\'invité', () {
    late ArtifactMemory memory;

    setUp(() async {
      memory = ArtifactMemory(io: _MemIO());
      await memory.load();
    });

    Future<void> pumpClaim(
      WidgetTester tester, {
      required ConstellationRepository repo,
      _StatefulStore? store,
      bool onboarded = true,
      String token = 'good-key',
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final s = store ?? _StatefulStore(onboarded);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bootstrapProvider.overrideWithValue(
              Bootstrap(supabaseConfigured: false, hasOnboarded: onboarded),
            ),
            localEchoStoreProvider.overrideWithValue(s),
            constellationRepositoryProvider.overrideWithValue(repo),
            artifactMemoryProvider.overrideWithValue(memory),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/c/$token',
              routes: [
                GoRoute(
                  path: '/space',
                  builder: (_, _) =>
                      const Scaffold(body: Center(child: Text('SPACE'))),
                ),
                GoRoute(
                  path: '/c/:token',
                  builder: (c, s) => SalonClaimScreen(
                    token: s.pathParameters['token'] ?? '',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    ConstellationMeta meta({
      String state = 'OPEN',
      int lineCount = 1,
      int target = 5,
      ConstellationKind kind = ConstellationKind.poem,
    }) =>
        ConstellationMeta(
          id: 'salon-1',
          seedX: 0.5,
          seedY: 0.5,
          state: state,
          lineCount: lineCount,
          target: target,
          kind: kind,
        );

    testWidgets('une clé morte parle honnêtement', (tester) async {
      await pumpClaim(tester, repo: _SalonFakeRepo.dead());
      expect(find.text('Le salon s’est tu'), findsOneWidget);
      expect(find.text('RETOURNER AU VIDE'), findsOneWidget);
    });

    testWidgets('l’éther loin : on peut réessayer', (tester) async {
      await pumpClaim(tester, repo: _SalonFakeRepo.unreachable());
      expect(find.text('L’éther est injoignable'), findsOneWidget);
      expect(find.text('RÉESSAYER'), findsOneWidget);
    });

    testWidgets('l’invitation s’ouvre : la figure, la progression, la ligne',
        (tester) async {
      await pumpClaim(tester, repo: _SalonFakeRepo.open(meta()));
      expect(find.text('Un poème à l’aveugle\nt’attend en salon'),
          findsOneWidget);
      expect(find.text('POSER MA LIGNE'), findsOneWidget);
      expect(find.text('1 / 5 LIGNES — LE POÈME ATTEND'), findsOneWidget);
      expect(find.byKey(const ValueKey('salon_progress')), findsOneWidget);
    });

    testWidgets('une chanson en salon demande une phrase', (tester) async {
      await pumpClaim(
        tester,
        repo: _SalonFakeRepo.open(
          meta(kind: ConstellationKind.melody, lineCount: 0),
        ),
      );
      expect(find.text('POSER MA PHRASE'), findsOneWidget);
      expect(find.text('0 / 5 PHRASES — LA CHANSON ATTEND'), findsOneWidget);
    });

    testWidgets('refermé : le poème attend dans l’éther', (tester) async {
      await pumpClaim(
        tester,
        repo: _SalonFakeRepo.open(meta(state: 'CLOSED', lineCount: 5)),
      );
      expect(find.text('Le poème s’est refermé'), findsOneWidget);
      expect(find.text('LIRE LE POÈME'), findsOneWidget);
    });

    testWidgets('déjà contribué : l’offre meurt', (tester) async {
      await memory.markContributed('salon-1');
      await pumpClaim(tester, repo: _SalonFakeRepo.open(meta()));
      expect(find.text('Ta ligne est déjà dans ce corps'), findsOneWidget);
    });

    testWidgets('l’invité neuf croise le Seuil d’abord, puis le salon',
        (tester) async {
      final store = _StatefulStore(false);
      await pumpClaim(
        tester,
        repo: _SalonFakeRepo.open(meta()),
        store: store,
        onboarded: false,
      );

      // The three rules first — the salon is not even spoken of.
      expect(find.text('KENOS'), findsOneWidget);
      expect(find.text('ENTRER'), findsOneWidget);
      expect(find.text('POSER MA LIGNE'), findsNothing);

      // The threshold crossed, the same route lands past the gate:
      // the journey link → Seuil → salon is whole.
      await tester.tap(find.text('ENTRER'));
      await tester.pumpAndSettle();
      expect(store.onboarded, isTrue);
      expect(find.text('POSER MA LIGNE'), findsOneWidget);
    });
  });

  group('SalonShareSheet — le lien montré une fois', () {
    testWidgets('la clé vit sur l’écran, la porte se ferme à la main',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSalonShareSheet(
                  context,
                  meta: ConstellationMeta(
                    id: 'salon-1',
                    seedX: 0.5,
                    seedY: 0.5,
                    state: 'OPEN',
                    lineCount: 0,
                    target: 5,
                  ),
                  inviteToken: 'abc123',
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('L’anneau attend ses invités'), findsOneWidget);
      expect(find.text('PARTAGER LE LIEN'), findsOneWidget);
      expect(find.text('COPIER'), findsOneWidget);
      expect(find.byKey(const ValueKey('salon_link')), findsOneWidget);
      expect(find.textContaining('/#/c/abc123'), findsOneWidget);
      // The test VM has no origin: the panel says the truth.
      expect(
        find.textContaining('NE CONNAÎT PAS L’ORIGINE'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('salon_shared')));
      await tester.pumpAndSettle();
      expect(find.text('L’anneau attend ses invités'), findsNothing,
          reason: 'seul J’AI PARTAGÉ ferme la porte');
    });
  });
}

/// Stateful onboarding: the Seuil's return trip is testable.
class _StatefulStore extends LocalEchoStore {
  _StatefulStore(this.onboarded);

  bool onboarded;

  @override
  Future<bool> hasOnboarded() async => onboarded;

  @override
  Future<void> setOnboarded() async => onboarded = true;
}

class _MemIO implements ArtifactMemoryIO {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

/// Claim-screen fake: the door resolves what the test chooses.
class _SalonFakeRepo implements ConstellationRepository {
  _SalonFakeRepo(this._resolve);

  final Future<ConstellationMeta> Function(String token) _resolve;

  static _SalonFakeRepo open(ConstellationMeta meta) =>
      _SalonFakeRepo((token) async => meta);

  static _SalonFakeRepo dead() =>
      _SalonFakeRepo((token) async => throw const SalonKeyRefused());

  static _SalonFakeRepo unreachable() =>
      _SalonFakeRepo((token) async => throw Exception('sky too far'));

  @override
  Future<ConstellationMeta> fetchInvited(String token) => _resolve(token);

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
  Future<SeededConstellation> seed(
    double x,
    double y, {
    ConstellationKind kind = ConstellationKind.poem,
    bool invited = false,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<ConstellationMeta>> fetchVisible() async => const [];

  @override
  Future<List<AssembledLine>?> read(String id) async => null;
}
