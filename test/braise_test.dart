import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kenos/features/braise/data/braise_repository.dart';
import 'package:kenos/features/braise/domain/braise_ballot.dart';
import 'package:kenos/features/braise/domain/braise_link.dart';
import 'package:kenos/features/braise/presentation/braise_claim_screen.dart';
import 'package:kenos/features/braise/presentation/braise_forge_sheet.dart';
import 'package:kenos/features/constellations/data/salon_anchor_store.dart';
import 'package:kenos/features/cosmic_map/presentation/impact_screen.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';
import 'package:kenos/features/echo/data/user_stats_store.dart';
import 'package:kenos/features/onboarding/presentation/onboarding_screen.dart';

/// LA BRAISE (V3.60) — the anonymous passage. Pinned here: the demo
/// ether honours the ember exactly like the SQL one (hex key, one
/// claim, refusal that says nothing), the ballot survives its journey
/// through the link and nothing else opens it, the claim threshold
/// tells every state honestly — and the local memories replant on the
/// new body while the old one goes quiet.
void main() {
  group('LocalBraiseRepository — la démo porte la même braise', () {
    test('la forge rend une clé de 16 octets hex', () async {
      final repo = LocalBraiseRepository();
      expect(await repo.forge(), matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('le claim consomme — un seul corps par braise', () async {
      final repo = LocalBraiseRepository();
      final key = await repo.forge();
      await repo.claim(key);
      expect(() => repo.claim(key), throwsA(isA<BraiseKeyRefused>()),
          reason: 'la braise meurt au claim, aucun replay');
    });

    test('mauvaise clé : exactement comme pas de clé', () async {
      final repo = LocalBraiseRepository();
      await repo.forge();
      expect(
        () => repo.claim('ffffffffffffffffffffffffffffffff'),
        throwsA(isA<BraiseKeyRefused>()),
      );
      expect(
        BraiseKeyRefused().toString(),
        'KENOS_PASSAGE_UNKNOWN',
        reason: 'parité de silence avec le serveur',
      );
    });

    test('reforger tue le lien précédent', () async {
      final repo = LocalBraiseRepository();
      final first = await repo.forge();
      await repo.forge();
      expect(() => repo.claim(first), throwsA(isA<BraiseKeyRefused>()),
          reason: 'une braise vive à la fois');
    });
  });

  group('le ballot scellé', () {
    final stats = UserStats(
      totalEchosSent: 3,
      totalReceptionsReceived: 1,
      totalTracesLeft: 2,
      readCount: 7,
      stardust: 9,
      seenReceptions: 1,
      constellationsTouched: 4,
    );

    SalonAnchor anchor(int n) => SalonAnchor(
          id: 'ring-$n',
          token: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d$n',
          seedX: 0.5,
          seedY: 0.4 + n * 0.01,
          kind: 'POEM',
          target: 5,
          heldSince: DateTime.now().millisecondsSinceEpoch,
        );

    test('le voyage complet : scellé, transporté, replanté', () async {
      final ballot = BraiseBallot(
        onboarded: true,
        stats: stats,
        freqGuideSeen: true,
        corpseGuideSeen: false,
        eyeGuideSeen: true,
        anchors: [anchor(1), anchor(2)],
      );
      final key = '00112233445566778899aabbccddeeff';
      final packed = await BraiseBallot.pack(ballot, key);
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(packed), isTrue,
          reason: 'le ballot vit dans un fragment d\'URL');

      final back = await BraiseBallot.tryUnpack(packed, key);
      expect(back, isNotNull);
      expect(back!.onboarded, isTrue);
      expect(back.stats.totalEchosSent, 3);
      expect(back.stats.stardust, 9);
      expect(back.freqGuideSeen, isTrue);
      expect(back.corpseGuideSeen, isFalse);
      expect(back.anchors, hasLength(2));
      expect(back.anchors.first.id, 'ring-1');
      expect(back.anchors.last.token, ballot.anchors.last.token);
    });

    test('une autre clé n\'ouvre rien — silence, pas d\'erreur', () async {
      final packed =
          await BraiseBallot.pack(BraiseBallot(onboarded: true, stats: stats),
              '00112233445566778899aabbccddeeff');
      expect(
        await BraiseBallot.tryUnpack(packed, 'ffffffffffffffffffffffffffffffff'),
        isNull,
      );
    });

    test('un ballot altéré est un souvenir oublié', () async {
      final key = '00112233445566778899aabbccddeeff';
      var packed = await BraiseBallot.pack(
          BraiseBallot(onboarded: true, stats: stats), key);
      final tampered =
          (packed.substring(0, packed.length - 2)) + (packed.endsWith('aa') ? 'bb' : 'aa');
      expect(await BraiseBallot.tryUnpack(tampered, key), isNull);
    });

    test('la fusion : les compteurs s\'ajoutent, les repères prennent le dernier',
        () {
      final older = DateTime(2026, 9, 1);
      final newer = DateTime(2026, 9, 15);
      final ballot = BraiseBallot(
        onboarded: true,
        stats: UserStats(
          totalEchosSent: 3,
          totalReceptionsReceived: 2,
          totalTracesLeft: 1,
          lastEchoSentAt: newer,
          readCount: 4,
          stardust: 6,
          seenReceptions: 2,
          constellationsTouched: 1,
          lastVisitAt: older,
        ),
      );
      final here = UserStats(
        totalEchosSent: 2,
        totalReceptionsReceived: 1,
        totalTracesLeft: 0,
        lastEchoSentAt: older,
        readCount: 1,
        stardust: 1,
        seenReceptions: 5,
        constellationsTouched: 0,
        lastVisitAt: newer,
      );
      final merged = ballot.mergedStats(here);
      expect(merged.totalEchosSent, 5);
      expect(merged.totalReceptionsReceived, 3);
      expect(merged.totalTracesLeft, 1);
      expect(merged.readCount, 5);
      expect(merged.stardust, 7);
      expect(merged.constellationsTouched, 1);
      expect(merged.lastEchoSentAt, newer);
      expect(merged.lastVisitAt, newer);
      expect(merged.seenReceptions, 5,
          reason: 'l\'Aube ne reparle pas de ce qui fut vu');
    });

    test('les ancres replantent sur un autre corps (IO seam)', () async {
      final ioA = _MemAnchorIO();
      final bodyA = SalonAnchorStore(io: ioA);
      await bodyA.load();
      await bodyA.remember(anchor(7));

      final key = '0123456789abcdef0123456789abcdef';
      final ballot = BraiseBallot(
        onboarded: true,
        stats: UserStats.empty(),
        anchors: bodyA.open(),
      );
      final packed = await BraiseBallot.pack(ballot, key);

      // The journey: link → parse → unpack → re-remember.
      final parsed = BraiseLink.parse('$key.$packed');
      final back = await BraiseBallot.tryUnpack(parsed!.ballot!, key);
      final bodyB = SalonAnchorStore(io: _MemAnchorIO());
      await bodyB.load();
      for (final a in back!.anchors) {
        await bodyB.remember(a);
      }
      expect(bodyB.open(), hasLength(1));
      expect(bodyB.open().single.id, 'ring-7');
      expect(bodyB.open().single.token, bodyA.open().single.token);
    });
  });

  group('le lien de passage', () {
    test('sans origine connue, la clé reste honnête', () {
      final link = BraiseLink.forge('deadbeef01' * 2 + 'ab', 'cGacked');
      expect(link, '/#/pass/${'deadbeef01' * 2}ab.cGacked');
      expect(link.startsWith('http'), isFalse);
    });

    test('la forme du lien est le chemin du claim', () {
      expect(BraiseLink.forge('ab' * 16, 'xyz').contains('/pass/'), isTrue);
    });

    test('le parse rend la clé et le ballot', () {
      final parsed = BraiseLink.parse('ab' * 16 + '.AQID');
      expect(parsed!.key, 'ab' * 16);
      expect(parsed.ballot, 'AQID');
    });

    test('un passage nu est toléré (claim sans souvenirs)', () {
      final parsed = BraiseLink.parse('ab' * 16);
      expect(parsed!.key, 'ab' * 16);
      expect(parsed.ballot, isNull);
    });

    test('ce qui ne porte pas la forme de la braise est mort', () {
      expect(BraiseLink.parse('not-hex-at-all'), isNull);
      expect(BraiseLink.parse('abc'), isNull);
      expect(BraiseLink.parse(''), isNull);
      expect(BraiseLink.parse('ab' * 16 + '.con/tenu!interdit'), isNull,
          reason: 'le fragment reste un seul segment sûr');
    });
  });

  group('BraiseClaimScreen — le seuil du corps', () {
    Future<void> pumpPass(
      WidgetTester tester, {
      required BraiseRepository repo,
      required String payload,
      LocalEchoStore? store,
      bool onboarded = true,
      SalonAnchorStore? doors,
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
            braiseRepositoryProvider.overrideWithValue(repo),
            salonAnchorStoreProvider.overrideWithValue(
              doors ?? SalonAnchorStore(io: _MemAnchorIO()),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/pass/$payload',
              routes: [
                GoRoute(
                  path: '/space',
                  builder: (_, _) =>
                      const Scaffold(body: Center(child: Text('SPACE'))),
                ),
                GoRoute(
                  path: '/pass/:payload',
                  builder: (c, s) => BraiseClaimScreen(
                    payload: s.pathParameters['payload'] ?? '',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('un payload hors forme parle honnêtement', (tester) async {
      await pumpPass(tester, repo: LocalBraiseRepository(), payload: 'nimporte');
      expect(find.text('La braise s’est éteinte'), findsOneWidget);
      expect(find.text('RETOURNER AU VIDE'), findsOneWidget);
    });

    testWidgets('une braise déjà claimée s’est éteinte', (tester) async {
      final repo = LocalBraiseRepository();
      final key = await repo.forge();
      await repo.claim(key);
      await pumpPass(tester, repo: repo, payload: key);
      expect(find.text('La braise s’est éteinte'), findsOneWidget);
    });

    testWidgets('l’éther loin : on peut réessayer', (tester) async {
      await pumpPass(
        tester,
        repo: _UnreachableBraise(),
        payload: 'ab' * 16,
      );
      expect(find.text('L’éther est injoignable'), findsOneWidget);
      expect(find.text('RÉESSAYER'), findsOneWidget);
    });

    testWidgets('le corps neuf croise le Seuil d\'abord, puis la braise',
        (tester) async {
      final repo = LocalBraiseRepository();
      final key = await repo.forge();
      // A naked link (no ballot to vouch for the rules).
      final store = _StatefulStore(false);
      await pumpPass(
        tester,
        repo: repo,
        payload: key,
        store: store,
        onboarded: false,
      );

      expect(find.text('KENOS'), findsOneWidget);
      expect(find.text('ENTRER'), findsOneWidget);
      expect(find.text('La braise a passé'), findsNothing);

      await tester.tap(find.text('ENTRER'));
      await tester.pumpAndSettle();
      expect(store.onboarded, isTrue);
      expect(find.text('La braise a passé'), findsOneWidget);
      expect(find.text('ENTRER DANS LE VIDE'), findsOneWidget);
    });

    testWidgets('le ballot qui vouche des règles épargne le Seuil — et replante',
        (tester) async {
      final repo = LocalBraiseRepository();
      final key = await repo.forge();
      final store = _StatefulStore(true)
        ..stats = UserStats(
          totalEchosSent: 2,
          totalReceptionsReceived: 1,
          totalTracesLeft: 0,
        );
      final doors = SalonAnchorStore(io: _MemAnchorIO());
      await doors.load();
      final ballot = BraiseBallot(
        onboarded: true,
        stats: UserStats(
          totalEchosSent: 3,
          totalReceptionsReceived: 0,
          totalTracesLeft: 1,
          stardust: 6,
          constellationsTouched: 2,
        ),
        freqGuideSeen: true,
        eyeGuideSeen: true,
        anchors: [
          SalonAnchor(
            id: 'ring-9',
            token: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d9',
            seedX: 0.5,
            seedY: 0.5,
            kind: 'MELODY',
            target: 6,
            heldSince: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );
      final payload = '$key.${await BraiseBallot.pack(ballot, key)}';

      await pumpPass(
        tester,
        repo: repo,
        payload: payload,
        store: store,
        doors: doors,
      );

      // No threshold: the sealed ballot vouched for the rules.
      expect(find.text('ENTRER'), findsNothing);
      expect(find.text('La braise a passé'), findsOneWidget);

      // The memories took root on this body.
      expect(store.stats.totalEchosSent, 5,
          reason: 'les compteurs s\'ajoutent');
      expect(store.stats.constellationsTouched, 2);
      expect(store.freqGuide, isTrue);
      expect(store.corpseGuide, isFalse);
      expect(doors.open(), hasLength(1));
      expect(doors.open().single.id, 'ring-9');

      await tester.tap(find.text('ENTRER DANS LE VIDE'));
      await tester.pumpAndSettle();
      expect(find.text('SPACE'), findsOneWidget);
    });

    testWidgets('un corps éteint ne reçoit plus de braise', (tester) async {
      await pumpPass(
        tester,
        repo: _ExtinctBraise(),
        payload: 'ab' * 16,
      );
      expect(find.text('Ce corps a déjà transmis'), findsOneWidget);
      expect(find.text('RETOURNER AU VIDE'), findsOneWidget);
    });
  });

  group('l\'extinction ROSE du vieux corps (V3.60a)', () {
    test('eraseAll éteint honnêtement la mémoire locale', () async {
      final store = LocalEchoStore();
      await store.setOnboarded();
      await store.writeStats(UserStats(
        totalEchosSent: 4,
        totalReceptionsReceived: 1,
        totalTracesLeft: 2,
      ));
      await store.markFrequenciesGuideSeen();
      await store.markEyeGuideSeen();
      expect(await store.hasOnboarded(), isTrue);

      await store.eraseAll();

      expect(await store.hasOnboarded(), isFalse);
      expect((await store.readStats()).totalEchosSent, 0);
      expect(await store.hasFrequenciesGuideSeen(), isFalse);
      expect(await store.hasEyeGuideSeen(), isFalse);
    });

    test('les portes s\'éteignent avec le corps — et ne ressuscitent pas',
        () async {
      final io = _MemAnchorIO();
      final doors = SalonAnchorStore(io: io);
      await doors.load();
      await doors.remember(SalonAnchor(
        id: 'ring-3',
        token: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d3',
        seedX: 0.5,
        seedY: 0.5,
        kind: 'POEM',
        target: 5,
        heldSince: DateTime.now().millisecondsSinceEpoch,
      ));
      expect(doors.open(), hasLength(1));

      await doors.eraseAll();

      expect(doors.open(), isEmpty);
      final reborn = SalonAnchorStore(io: io);
      await reborn.load();
      expect(reborn.open(), isEmpty,
          reason: 'un redémarrage ne rallume pas une porte éteinte');
    });

    Future<void> pumpImpact(
      WidgetTester tester, {
      required BraiseRepository repo,
      required _StatefulStore store,
      required SalonAnchorStore doors,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bootstrapProvider.overrideWithValue(
              const Bootstrap(supabaseConfigured: false, hasOnboarded: true),
            ),
            localEchoStoreProvider.overrideWithValue(store),
            braiseRepositoryProvider.overrideWithValue(repo),
            salonAnchorStoreProvider.overrideWithValue(doors),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/impact',
              routes: [
                GoRoute(
                  path: '/impact',
                  builder: (_, _) => const ImpactScreen(),
                ),
                GoRoute(
                  path: '/onboarding',
                  builder: (_, _) => const OnboardingScreen(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('forger sur un corps éteint propose la mort douce — ROSE',
        (tester) async {
      final store = _StatefulStore(true)
        ..stats = UserStats(
          totalEchosSent: 3,
          totalReceptionsReceived: 0,
          totalTracesLeft: 0,
        );
      final doors = SalonAnchorStore(io: _MemAnchorIO());
      await doors.load();
      await doors.remember(SalonAnchor(
        id: 'ring-4',
        token: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d4',
        seedX: 0.5,
        seedY: 0.5,
        kind: 'POEM',
        target: 5,
        heldSince: DateTime.now().millisecondsSinceEpoch,
      ));
      await pumpImpact(
        tester,
        repo: _ExtinctBraise(),
        store: store,
        doors: doors,
      );

      // The forge line sits at the ledger's bottom — under the fold
      // on a phone: bring it into the light first.
      await tester.ensureVisible(find.byKey(const ValueKey('braise_forge')));
      await tester.tap(find.byKey(const ValueKey('braise_forge')));
      await tester.pumpAndSettle();

      expect(find.text('Ce corps a déjà transmis'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('braise_extinguish')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('braise_stay')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('braise_extinguish')),
      );
      await tester.tap(find.byKey(const ValueKey('braise_extinguish')));
      await tester.pumpAndSettle();

      // The body went dark, and the Seuil waits for a stranger to be
      // born: renaissance, not resurrection.
      expect(find.text('KENOS'), findsOneWidget);
      expect(store.onboarded, isFalse);
      expect(store.stats.totalEchosSent, 0);
      expect(doors.open(), isEmpty);
    });

    testWidgets('rester encore ne touche à rien', (tester) async {
      final store = _StatefulStore(true)
        ..stats = UserStats(
          totalEchosSent: 3,
          totalReceptionsReceived: 0,
          totalTracesLeft: 0,
        );
      final doors = SalonAnchorStore(io: _MemAnchorIO());
      await doors.load();
      await pumpImpact(
        tester,
        repo: _ExtinctBraise(),
        store: store,
        doors: doors,
      );

      await tester.ensureVisible(find.byKey(const ValueKey('braise_forge')));
      await tester.tap(find.byKey(const ValueKey('braise_forge')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('braise_stay')));
      await tester.tap(find.byKey(const ValueKey('braise_stay')));
      await tester.pumpAndSettle();

      expect(store.onboarded, isTrue);
      expect(store.stats.totalEchosSent, 3);
      expect(find.text('TON IMPACT'), findsOneWidget,
          reason: 'le corps reste sur son bilan');
    });
  });

  group('BraiseForgeSheet — le lien montré une fois', () {
    testWidgets('la braise vit sur l’écran, la porte se ferme à la main',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showBraiseForgeSheet(context, link: '/#/pass/abc.def'),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('Ce lien est ton corps'), findsOneWidget);
      expect(find.text('PARTAGER LE LIEN'), findsOneWidget);
      expect(find.text('COPIER'), findsOneWidget);
      expect(find.byKey(const ValueKey('braise_qr')), findsOneWidget,
          reason: 'la pastille scannable vit avec le lien');
      expect(find.byKey(const ValueKey('braise_link')), findsOneWidget);
      expect(find.textContaining('/#/pass/abc.def'), findsOneWidget);
      expect(
        find.textContaining('NE CONNAÎT PAS L’ORIGINE'),
        findsOneWidget,
        reason: 'le test VM n\'a pas d\'origine — le panneau dit vrai',
      );

      // The chip grew the sheet: bring the closing word into the
      // light before it is spoken.
      await tester.ensureVisible(find.byKey(const ValueKey('braise_shared')));
      await tester.tap(find.byKey(const ValueKey('braise_shared')));
      await tester.pumpAndSettle();
      expect(find.text('Ce lien est ton corps'), findsNothing,
          reason: 'seul J’AI TRANSMIS ferme la porte');
    });
  });

  group('le mapper du refus', () {
    test('un corps éteint qui lance : le HUD le dit, honnêtement', () {
      final e = KenosException.from(const _RawError('Exception: KENOS_BRAISE_PASSED'));
      expect(e.code, KenosErrorCode.braisePassed);
      expect(e.hudMessage, contains('BRAISE'));
    });
  });
}

class _MemAnchorIO implements SalonAnchorIO {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

/// Stateful local store: the Seuil's return trip and the transplant are
/// both observable, with zero keychain I/O (no pending timers — the
/// real store's 2 s timeout guard is exactly what a widget test must
/// not inherit; the salon tests use the same seam).
class _StatefulStore extends LocalEchoStore {
  _StatefulStore(this.onboarded);

  bool onboarded;
  UserStats stats = UserStats.empty();
  bool freqGuide = false;
  bool corpseGuide = false;
  bool eyeGuide = false;

  @override
  Future<bool> hasOnboarded() async => onboarded;

  @override
  Future<void> setOnboarded() async => onboarded = true;

  @override
  Future<void> eraseAll() async {
    onboarded = false;
    stats = UserStats.empty();
    freqGuide = corpseGuide = eyeGuide = false;
  }

  @override
  Future<UserStats> readStats() async => stats;

  @override
  Future<void> writeStats(UserStats value) async => stats = value;

  @override
  Future<bool> hasFrequenciesGuideSeen() async => freqGuide;

  @override
  Future<void> markFrequenciesGuideSeen() async => freqGuide = true;

  @override
  Future<bool> hasCorpseGuideSeen() async => corpseGuide;

  @override
  Future<void> markCorpseGuideSeen() async => corpseGuide = true;

  @override
  Future<bool> hasEyeGuideSeen() async => eyeGuide;

  @override
  Future<void> markEyeGuideSeen() async => eyeGuide = true;
}

/// A repository whose ether is simply far.
class _UnreachableBraise implements BraiseRepository {
  @override
  Future<String> forge() async => 'ab' * 16;

  @override
  Future<void> claim(String key) async => throw Exception('boom');
}

/// A repository that answers for an already-transmitted body: both
/// the forge and the claim meet their extinction.
class _ExtinctBraise implements BraiseRepository {
  @override
  Future<String> forge() async =>
      throw const _RawError('Exception: KENOS_BRAISE_PASSED');

  @override
  Future<void> claim(String key) async =>
      throw const _RawError('Exception: KENOS_BRAISE_PASSED');
}

class _RawError implements Exception {
  const _RawError(this.message);

  final String message;

  @override
  String toString() => message;
}
