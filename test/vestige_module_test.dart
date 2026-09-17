import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kenos/features/observatory/data/admin_providers.dart';
import 'package:kenos/features/observatory/data/admin_repository.dart';
import 'package:kenos/features/observatory/data/local_admin_repository.dart';
import 'package:kenos/features/observatory/domain/admin_metrics.dart';
import 'package:kenos/features/observatory/presentation/vestige_module_screen.dart';

void main() {
  group('Le Semeur d\'éclats — the Observatory module (V3.57)', () {
    testWidgets('the review loop: read, publish, discard, sow, retire', (
      tester,
    ) async {
      final repo = _SowerRepo();
      await _pump(tester, repo);

      // The two proposals await their taste.
      expect(find.text('À RELIRE — 2'), findsOneWidget);
      expect(find.textContaining('huit minutes'), findsOneWidget);
      expect(find.textContaining('κόσμος'), findsOneWidget);
      expect(find.text('TOUT PUBLIER'), findsOneWidget);

      // Publish the Sun: it leaves the queue, enters the library.
      // (Every gesture advances the fake clock past the demo's
      // delays before settling — pumpAndSettle alone goes quiet
      // while the sky's timers still hold.)
      await tester.tap(find.text('PUBLIER DANS LE CIEL').first);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(repo.decided, hasLength(1));
      expect(repo.decided.first.approve, isTrue);
      expect(find.text('À RELIRE — 1'), findsOneWidget);

      // Discard the cosmos: gone, nowhere.
      await tester.tap(find.text('ÉCARTER'));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(repo.decided, hasLength(2));
      expect(repo.decided.last.approve, isFalse);
      expect(find.textContaining('Aucun éclat en attente'), findsOneWidget);

      // The library: the published shard drifts, the lever retires.
      expect(find.textContaining('LA BIBLIOTHÈQUE'), findsOneWidget);
      expect(find.textContaining('huit minutes'), findsOneWidget);
      await tester.ensureVisible(find.text('RETIRER DU CIEL').first);
      await tester.tap(find.text('RETIRER DU CIEL').first);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(repo.retired, isTrue);

      // Ask for a harvest: the sower's word, a fresh proposal. (The
      // field's focus scrolls the view — the button is re-aimed
      // after typing.)
      await tester.ensureVisible(find.text('SEMER 6 ÉCLATS'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'étymologies grecques',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('SEMER 6 ÉCLATS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SEMER 6 ÉCLATS'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(repo.sown, [(count: 6, theme: 'étymologies grecques')]);
      // The demo sower grows a canned shard — its word says DEMO, and
      // the queue really grew.
      expect(find.textContaining('DÉMO : UN ÉCLAT EN CONSERVE'),
          findsOneWidget);
      expect(find.text('À RELIRE — 1'), findsOneWidget);
    });

    testWidgets('an unconfigured key says so, honestly', (tester) async {
      final repo = _SowerRepo(sowResult: const SowResult(
        sown: 0,
        reason: 'unconfigured',
      ));
      await _pump(tester, repo);

      // The sower's panel lives under the fold — bring it up first.
      await tester.ensureVisible(find.text('SEMER 6 ÉCLATS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SEMER 6 ÉCLATS'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('VESTIGE_AI_KEY'),
        findsOneWidget,
        reason: 'la clé absente a son mot, jamais un silence',
      );
    });

    test('the demo sower grows a canned proposal — the loop, offline', () async {
      final repo = await _signedInDemo();
      final before = await repo.fetchVestigeProposals();
      final result = await repo.sowVestiges(count: 4, theme: 'astronomie');
      expect(result.sown, 1);
      expect(result.reason, 'demo');
      final after = await repo.fetchVestigeProposals();
      expect(after.length, before.length + 1);

      // And the demo decision really moves the shard.
      final published = await repo.decideVestigeProposal(after.first.id, true);
      expect(published, isTrue);
      final library = await repo.fetchVestigeLibrary();
      expect(library.where((v) => v.id == after.first.id), isNotEmpty);
    });
  });
}

Future<void> _pump(WidgetTester tester, AdminRepository repo) async {
  // The demo repository demands its threshold, like the real sky. Its
  // real-time delay only fires inside runAsync — the fake clock of a
  // testWidgets body never advances by itself (the hang this comment
  // replaced).
  if (!repo.isSignedIn) {
    await tester.runAsync(() => repo.signIn('gardien@kenos.local', 'demo'));
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: VestigeModuleScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<LocalAdminRepository> _signedInDemo() async {
  final repo = LocalAdminRepository();
  await repo.signIn('gardien@kenos.local', 'demo');
  return repo;
}

/// The harness repo: the demo repository itself (it IS the parity),
/// subclassed to observe the gestures.
class _SowerRepo extends LocalAdminRepository {
  _SowerRepo({this.sowResult});

  SowResult? sowResult;
  final decided = <({String id, bool approve})>[];
  final sown = <({int count, String theme})>[];
  bool retired = false;

  @override
  Future<bool> decideVestigeProposal(String proposalId, bool approve) async {
    decided.add((id: proposalId, approve: approve));
    return super.decideVestigeProposal(proposalId, approve);
  }

  @override
  Future<void> setVestigeLive(String id, bool live) async {
    retired = !live;
    await super.setVestigeLive(id, live);
  }

  @override
  Future<SowResult> sowVestiges({int count = 6, required String theme}) async {
    sown.add((count: count, theme: theme));
    return sowResult ?? await super.sowVestiges(count: count, theme: theme);
  }
}
