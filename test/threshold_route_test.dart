import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/app/kenos_app.dart';
import 'package:kenos/app/router.dart';
import 'package:kenos/features/cosmic_map/application/motion_service.dart';
import 'package:kenos/features/cosmic_map/presentation/map_screen.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';

/// V3.50 — the threshold guards EVERY door: a fresh visitor arriving
/// by a sky link (or the Mirror, or a raw /space) meets the three
/// rules first — and ENTRER opens the door back where they were
/// going. The salon's own threshold is never double-gated.
void main() {
  Future<void> bootFresh(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = LocalEchoStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(
            const Bootstrap(supabaseConfigured: false, hasOnboarded: false),
          ),
          echoRepositoryProvider.overrideWith(
            (ref) => LocalEchoRepository.seeded(
              latency: const Duration(milliseconds: 1),
            ),
          ),
          localEchoStoreProvider.overrideWithValue(store),
          tiltProvider.overrideWith((ref) => Stream.value(Tilt.zero)),
        ],
        child: const KenosApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('un lien ciel chez un visiteur neuf : les règles, puis le lieu',
      (tester) async {
    await bootFresh(tester);

    // Straight to a far-country place link — no rules seen yet.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(KenosApp)),
      listen: false,
    );
    container.read(goRouterProvider).go('/ciel/0.95/0.95');
    await tester.pump(const Duration(milliseconds: 800));

    // The threshold stands in the way (the three rules, not the map).
    expect(find.text('KENOS'), findsOneWidget);
    expect(find.textContaining('Aucun profil'), findsOneWidget);
    expect(find.byType(MapScreen), findsNothing);

    // ENTRER opens the door BACK to the place the link pointed at.
    await tester.tap(find.text('ENTRER'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(MapScreen), findsOneWidget);
    expect(
      find.textContaining('LE PAYS LOINTAIN'),
      findsWidgets,
      reason: 'la porte s\'ouvre là où le lien menait',
    );
    // Absorb the store's secure-I/O timeouts (the ENTRER write and
    // the map's first reads leave 2 s guards behind).
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('le miroir aussi garde son seuil', (tester) async {
    await bootFresh(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(KenosApp)),
      listen: false,
    );
    container.read(goRouterProvider).go('/mirror');
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('KENOS'), findsOneWidget,
        reason: 'les règles avant la formulation');
    expect(find.text('La formulation du vide'), findsNothing);
  });

  testWidgets('le salon garde son propre accueil (jamais double seuil)',
      (tester) async {
    await bootFresh(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(KenosApp)),
      listen: false,
    );
    final router = container.read(goRouterProvider);
    router.go('/c/deadbeef');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(seconds: 2));
    // The claim OWNS its welcome — its embedded rules may show (that
    // IS its threshold), but the ADDRESS never left the salon: the
    // global redirect did not fire.
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/c/deadbeef',
      reason: 'le redirect global ne détournait jamais la porte du salon',
    );
  });

  testWidgets('déjà entré : aucune boucle, le seuil ne revient pas',
      (tester) async {
    MapScreen.territoriesAnnounced.clear();
    await bootFresh(tester);
    // The store starts cold (fresh) — enter once.
    expect(find.text('KENOS'), findsOneWidget);
    await tester.tap(find.text('ENTRER'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(MapScreen), findsOneWidget);

    // Any deep link now lands directly — no second threshold.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(KenosApp)),
      listen: false,
    );
    container.read(goRouterProvider).go('/mirror');
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('La formulation du vide'), findsOneWidget);
    expect(find.text('KENOS'), findsNothing);
  });
}
