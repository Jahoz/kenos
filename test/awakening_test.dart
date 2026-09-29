import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/constants/app_colors.dart';
import 'package:kenos/core/constants/app_meta.dart';
import 'package:kenos/core/voice/kenos_voice.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/awakening_sas.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/origin_node.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/user_stats_store.dart';

import 'controllers_test.dart' show FakeLocalEchoStore;

UserStats _stats({
  int sent = 0,
  int receptions = 0,
  int seen = 0,
  int stardust = 0,
  DateTime? lastVisit,
}) =>
    UserStats(
      totalEchosSent: sent,
      totalReceptionsReceived: receptions,
      totalTracesLeft: 0,
      seenReceptions: seen,
      stardust: stardust,
      lastVisitAt: lastVisit,
    );

void main() {
  group('L\'Aube — lignes du sas (pures, épinglées)', () {
    test('une réception pendant l\'absence : le sas parle d\'elle', () {
      final stats = _stats(sent: 3, receptions: 5, seen: 4, lastVisit: DateTime.now());
      final lines = stats.awakeningLines();
      expect(lines.first, contains('un de tes échos a touché un inconnu'));
      expect(lines.last, contains('plus loin que tu ne sais'));
    });

    test('plusieurs réceptions : le compte parle', () {
      final stats = _stats(receptions: 9, seen: 4);
      expect(stats.receptionsSinceLastVisit, 5);
      expect(stats.awakeningLines().first, contains('5 de tes échos'));
    });

    test('rien de nouveau mais des échos lancés : ils dérivent, intact', () {
      final stats = _stats(sent: 4, receptions: 2, seen: 2, lastVisit: DateTime.now());
      expect(stats.receptionsSinceLastVisit, 0);
      final lines = stats.awakeningLines();
      expect(lines.first, contains('4 échos dérivent encore'));
      expect(lines.last, contains('Respire'));
    });

    test('premier passage sans rien : invitation douce, pas de silence mort', () {
      final stats = _stats(sent: 0);
      expect(stats.hasAwakeningToTell, isFalse,
          reason: 'rien à dire → le sas reste fermé');
      expect(stats.awakeningLines().single, contains('Commence doucement'));
    });

    test('une constellation touchée fait parler l\'Aube (sans mentir)', () {
    final stats = _stats(sent: 2, receptions: 2, seen: 2).copyWith(
      constellationsTouched: 1,
      lastVisitAt: DateTime.now(),
    );
    expect(stats.hasAwakeningToTell, isTrue,
        reason: 'le murmure constellation est un signal d\'aube');
    final lines = stats.awakeningLines();
    // V3.45 — the Aube no longer claims a closure it cannot know
    // (the counter climbs at the LINE, not the closing): the truth is
    // the hand, the ember orbit, and the wait. The closure itself is
    // told on the map, once, by the closure whisper.
    expect(lines.first, contains('poèmes'));
    expect(lines.first, isNot(contains('refermée')),
        reason: 'touché n\'est pas refermé — l\'Aube ne prédit pas');
    expect(lines.last, contains('ember'),
        reason: 'l\'orbite ember est le repère sur la carte');
  });

  test('le sas ne se rouvre pas pour ce qui a déjà été vu', () {
      final fresh = _stats(sent: 2, receptions: 3, seen: 3, lastVisit: DateTime.now());
      expect(fresh.receptionsSinceLastVisit, 0);
      // Stardust accumulée + revisite : le seuil hasAwakeningToTell exige
      // du NOUVEAU (réceptions) ou une première visite.
      expect(fresh.hasAwakeningToTell, isFalse);
    });
  });

  group('Stardust — sérialisation et visites', () {
    test('roundtrip json conserve stardust, visites vues, dernier passage', () {
      final when = DateTime(2026, 8, 31, 21);
      final stats = _stats(sent: 7, receptions: 4, seen: 2, stardust: 11)
          .copyWith(lastVisitAt: when);
      final back = UserStats.fromJson(stats.toJson());
      expect(back.stardust, 11);
      expect(back.seenReceptions, 2);
      expect(back.lastVisitAt, when);
    });

    test('copyWith ne perd jamais les champs d\'aube', () {
      final stats = _stats(stardust: 5, seen: 3).copyWith(totalEchosSent: 9);
      expect(stats.stardust, 5);
      expect(stats.seenReceptions, 3);
    });
  });

  group('OriginNode (widget)', () {
    testWidgets('rend le cœur ambre sans planter, motes plafonnées', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: Scaffold(body: OriginNode()))),
      );
      await tester.pump();
      expect(find.byType(OriginNode), findsOneWidget);
      // Let the stats provider's storage-timeout timer (2 s) fire,
      // then unmount: nothing must outlive the widget tree.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('l\'ambre n\'est JAMAIS le rose (destruction only)', (
      tester,
    ) async {
      expect(AppColors.ember.toARGB32(), isNot(AppColors.rose.toARGB32()));
      expect(AppColors.emberSoft.toARGB32(), isNot(AppColors.roseText.toARGB32()));
    });
  });

  group('V3.89 — le pacte de l\'Aube : l\'accord avant de rentrer', () {
    Future<void> pumpAube(
      WidgetTester tester, {
      required FakeLocalEchoStore store,
      UserStats? stats,
      KenosVoice voice = KenosVoice.french,
    }) async {
      final s = stats ?? UserStats.empty();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localEchoStoreProvider.overrideWithValue(store),
            userStatsProvider.overrideWith((ref) async => s),
            voiceProvider.overrideWithValue(voice),
          ],
          child: MaterialApp(home: _AubeHost()),
        ),
      );
      await tester.tap(find.text('OUVRE'));
      await tester.pump(const Duration(milliseconds: 800));
    }

    testWidgets(
      'première entrée : le pacte parle, la barrière tient, l\'accord signe',
      (tester) async {
        tester.view.physicalSize = const Size(390, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final store = FakeLocalEchoStore();
        await pumpAube(tester, store: store);

        // The terms are on the table, the accord button with them —
        // and the old tap-the-void shortcut is gone.
        expect(find.text('LE PACTE DE L\'ÉTHER'), findsOneWidget);
        expect(find.text('J\'ACCEPTE — JE RENTRE'), findsOneWidget);
        expect(find.text('TOUCHE LE VIDE POUR ENTRER'), findsNothing);

        // The barrier holds: a touch outside closes nothing.
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        expect(find.text('LE PACTE DE L\'ÉTHER'), findsOneWidget);

        // One deliberate gesture signs and enters.
        await tester.tap(find.text('J\'ACCEPTE — JE RENTRE'));
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text('LE PACTE DE L\'ÉTHER'), findsNothing);
        expect(store.pactVersion, kAubePactVersion,
            reason: 'l\'accord est mémorisé, à cette version des termes');
      },
    );

    testWidgets('pacte signé, rien de nouveau : l\'Aube reste close', (
      tester,
    ) async {
      final store = FakeLocalEchoStore()..pactVersion = kAubePactVersion;
      await pumpAube(tester, store: store);
      expect(find.text('LE PACTE DE L\'ÉTHER'), findsNothing);
      expect(find.text('TOUCHE LE VIDE POUR ENTRER'), findsNothing,
          reason: 'aucune nouvelle, aucun pacte en attente : pas de sas');
    });

    testWidgets('pacte signé, une nouvelle : le sas d\'avant, sans pacte', (
      tester,
    ) async {
      final store = FakeLocalEchoStore()..pactVersion = kAubePactVersion;
      await pumpAube(
        tester,
        store: store,
        stats: _stats(sent: 3, receptions: 5, seen: 4, lastVisit: DateTime.now()),
      );
      expect(find.text('TOUCHE LE VIDE POUR ENTRER'), findsOneWidget);
      expect(find.text('LE PACTE DE L\'ÉTHER'), findsNothing,
          reason: 'l\'accord n\'agace jamais : une fois signé, il ne revient pas');
    });

    testWidgets('le premier parcours anglais signe dans sa langue', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = FakeLocalEchoStore();
      await pumpAube(tester, store: store, voice: KenosVoice.english);
      expect(find.text('THE PACT OF THE ETHER'), findsOneWidget);
      expect(find.text('I ACCEPT — I ENTER'), findsOneWidget);
      await tester.tap(find.text('I ACCEPT — I ENTER'));
      await tester.pump(const Duration(milliseconds: 800));
      expect(store.pactVersion, kAubePactVersion);
    });
  });
}

class _AubeHost extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => maybeShowAwakening(context, ref),
      child: const Text('OUVRE'),
    );
  }
}
