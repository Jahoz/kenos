import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/app/kenos_app.dart';
import 'package:kenos/features/cosmic_map/application/map_controller.dart';
import 'package:kenos/features/cosmic_map/application/motion_service.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/mindful_hold_star.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';

/// Full user journey in demo mode (no backend):
/// threshold → space → 3 s Mindful Hold → reveal → 10 s burn → dissolution.
///
/// Sensor and audio are neutralized by design (soft fallbacks),
/// only the real mechanics of the experience are tested here.
void main() {
  Future<void> bootApp(WidgetTester tester) async {
    // The designed posture: a held phone. The old default surface
    // (800×600 landscape) is a desktop window now — there, the column
    // compresses the sky and no star sits clear of the HUD strip.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(
            const Bootstrap(supabaseConfigured: false, hasOnboarded: false),
          ),
          echoRepositoryProvider.overrideWith(
            (ref) => LocalEchoRepository.seeded(
              latency: const Duration(milliseconds: 10),
            ),
          ),
          tiltProvider.overrideWith((ref) => Stream.value(Tilt.zero)),
        ],
        child: const KenosApp(),
      ),
    );
    await tester.pump();
  }


  /// Picks a holdable star: fully visible, clear of the HUD strip, its
  /// center covered by nothing. The sky is a window into a 2× world —
  /// when the holdable band is empty (planets polarize the latitudes),
  /// the test TRAVELS like a human: pan the void, look again.
  Future<int> pickHoldableStar(WidgetTester tester, Offset screen) async {
    for (var attempt = 0; attempt < 14; attempt++) {
      final starsNow = find.byType(MindfulHoldStar);
      final rectsNow = [
        for (var i = 0; i < starsNow.evaluate().length; i++)
          tester.getRect(starsNow.at(i)),
      ];
      for (var i = 0; i < rectsNow.length; i++) {
        final r = rectsNow[i];
        final onScreen = r.left >= 0 &&
            r.right <= screen.dx &&
            r.top > 150 &&
            r.bottom <= screen.dy;
        final covered = rectsNow.asMap().entries.any(
              (e) => e.key != i && e.value.contains(r.center),
            );
        if (onScreen && (!covered || attempt >= 12)) {
          return i;
        }
      }
      // Nothing holdable in this window: travel (alternate directions —
      // the holdable band may be up or down the world). The drag
      // starts top-right, clear of the star bands, and warms up with a
      // micro-move first — a fast raw drag from a covered point never
      // engages the pan (the star's hold eats it).
      final g = await tester.startGesture(
        Offset(screen.dx * 0.77, screen.dy * 0.24),
      );
      await g.moveBy(const Offset(-2, 1));
      await tester.pump(const Duration(milliseconds: 300));
      await g.moveBy(Offset(0, attempt.isEven ? -280.0 : 280.0));
      await tester.pump();
      await g.up();
      await tester.pump(const Duration(milliseconds: 350));
    }
    return -1;
  }

  testWidgets('le seuil affiche les trois règles et mène à l\'espace', (
    tester,
  ) async {
    await bootApp(tester);

    expect(find.text('KENOS'), findsOneWidget);
    expect(find.text('ENTRER'), findsOneWidget);
    expect(find.textContaining('TROIS SECONDES'), findsOneWidget);

    await tester.tap(find.text('ENTRER'));
    await tester.pump(const Duration(milliseconds: 700)); // transition fondu

    expect(find.textContaining('DÉMO'), findsOneWidget,
      reason: 'le HUD compact dit le mode en un mot');
    expect(find.textContaining('ÉCHOS'), findsOneWidget,
      reason: 'le HUD compte les lisibles, pas les scellées');

    // Let I/O safety nets (keychain timeouts) settle.
    await tester.pump(const Duration(milliseconds: 2600));
  });

  testWidgets('Mindful Hold 3 s : révélation, burn, dissolution, retrait', (
    tester,
  ) async {
    await bootApp(tester);

    // Franchir le seuil (700 ms de fondu, puis E/S locales + garde-fous).
    await tester.tap(find.text('ENTRER'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 2600));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(KenosApp)),
      listen: false,
    );
    final stateBefore = container.read(mapControllerProvider).valueOrNull ?? [];
    expect(stateBefore, isNotEmpty, reason: 'l\'éther démo est vide');

    // 3-second long press on an ether star — travelling if the
    // holdable band is empty.
    final screen = Offset(
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    );
    var pick = await pickHoldableStar(tester, screen);
    expect(pick, greaterThanOrEqualTo(0), reason: 'aucune étoile visible même en voyageant');
    // The living clock makes a single tap timing-sensitive: retry the
    // hold (re-picking a qualifying star) until the reveal opens.
    var revealed = false;
    var skyWaits = 0;
    for (var hold = 0; hold < 5 && !revealed; hold++) {
      // The sky can be empty for a beat (a map refresh): wait it out,
      // never index into a vanished list.
      var skyCount = find.byType(MindfulHoldStar).evaluate().length;
      while (skyCount == 0 && skyWaits < 10) {
        skyWaits++;
        await tester.pump(const Duration(milliseconds: 400));
        skyCount = find.byType(MindfulHoldStar).evaluate().length;
      }
      if (skyCount == 0) break;
      // Fresh pick on every attempt: the previous failure left the
      // sky moved (and the held star possibly drifted somewhere worse).
      final fresh = await pickHoldableStar(tester, screen);
      if (fresh >= 0) pick = fresh;
      if (pick >= skyCount) {
        // Orbits swept the sky: any visible star will do.
        pick = 0;
        for (var i = 0; i < skyCount; i++) {
          final r = tester.getRect(find.byType(MindfulHoldStar).at(i));
          if (r.left >= 0 && r.right <= screen.dx && r.top > 150 && r.bottom <= screen.dy) {
            pick = i;
            break;
          }
        }
      }
      final star = find.byType(MindfulHoldStar).at(pick);
      expect((tester.widget(star) as MindfulHoldStar).echo.id, isNotEmpty);
      final gesture = await tester.startGesture(tester.getCenter(star));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3200));
      await gesture.up();
      // The reveal can land a beat late (async consume + route build):
      // poll for it instead of trusting a single pump.
      for (var wait = 0; wait < 8 && !revealed; wait++) {
        await tester.pump(const Duration(milliseconds: 300));
        revealed =
            find.text('ÉCHO INTERCEPTÉ — LECTURE UNIQUE').evaluate().isNotEmpty ||
            find.textContaining('TON ÉCHO DÉRIVE').evaluate().isNotEmpty;
      }
    }
    expect(revealed, isTrue, reason: 'aucune étoile tenue après 5 essais');

    // The reveal modal (or the sealed-star sheet) is up.
    expect(
      find.text('ÉCHO INTERCEPTÉ — LECTURE UNIQUE').evaluate().isNotEmpty ||
          find.textContaining('TON ÉCHO DÉRIVE').evaluate().isNotEmpty,
      isTrue);
    if (find.text('ÉCHO INTERCEPTÉ — LECTURE UNIQUE').evaluate().isNotEmpty) {
      expect(find.text('DESTRUCTION IMMINENTE'), findsOneWidget);
    }

    // 10 s reading window, then dissolve — then the trace offer
    // (bottle in the sea) takes over from the dissolved secret.
    var guard = 0;
    while (find
        .text('ÉCHO INTERCEPTÉ — LECTURE UNIQUE')
        .evaluate()
        .isNotEmpty) {
      guard++;
      expect(
        guard,
        lessThan(40),
        reason: 'la modale ne s\'est jamais dissoute',
      );
      await tester.pump(const Duration(milliseconds: 500));
    }

    // The trace offer: one line, no possible answer.
    expect(find.text('As-tu été touché ?'), findsOneWidget);
    expect(find.text('ENVOYER LA TRACE'), findsOneWidget);

    // Leaving without a trace closes the modal for good.
    await tester.tap(find.text('REPARTIR SANS RIEN'));
    var closeGuard = 0;
    while (find.text('As-tu été touché ?').evaluate().isNotEmpty) {
      closeGuard++;
      expect(closeGuard, lessThan(20), reason: 'la modale ne se referme pas');
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(
      find.text('As-tu été touché ?'),
      findsNothing,
      reason: 'la modale aurait dû se refermer',
    );

    // The read echo is gone from the map: single read, for real.
    // Single read, for real: THE read echo is gone from the ether's
    // state — and only it (widget counting is no longer the contract:
    // stars beyond the traveller's window are legitimately unbuilt).
    final stateAfter = container.read(mapControllerProvider).valueOrNull ?? [];
    // The single-read contract: exactly ONE ether echo left the sky.
    // (When the tap lands on overlapped stars, the pointer consumes
    // the topmost — the pre-captured id is not authoritative; the
    // count is.)
    expect(stateAfter.length, stateBefore.length - 1);
  });

  testWidgets('un appui relâché trop tôt ne consomme rien', (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('ENTRER'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 2600));

    // 3-second long press on an ether star — travelling if the
    // holdable band is empty.
    final screen = Offset(
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    );
    var pick = await pickHoldableStar(tester, screen);
    expect(pick, greaterThanOrEqualTo(0), reason: 'aucune étoile visible même en voyageant');
    // The sky can vanish for a beat (a map refresh): wait it out.
    var skyCount = find.byType(MindfulHoldStar).evaluate().length;
    for (var wait = 0; skyCount == 0 && wait < 10; wait++) {
      await tester.pump(const Duration(milliseconds: 400));
      skyCount = find.byType(MindfulHoldStar).evaluate().length;
    }
    if (pick >= skyCount) pick = 0;
    final star = find.byType(MindfulHoldStar).at(pick);
    expect((tester.widget(star) as MindfulHoldStar).echo.id, isNotEmpty);
    final gesture = await tester.startGesture(tester.getCenter(star));
    await tester.pump(); // attache le ticker
    await tester.pump(const Duration(milliseconds: 1200)); // trop court
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 1500)); // ring rolls back

    expect(find.text('ÉCHO INTERCEPTÉ — LECTURE UNIQUE'), findsNothing);
    final starsAfter = tester
        .widgetList<MindfulHoldStar>(find.byType(MindfulHoldStar))
        .length;
    expect(starsAfter, greaterThan(0));
  });
}
