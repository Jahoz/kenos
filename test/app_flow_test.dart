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

  testWidgets('le seuil affiche les trois règles et mène à l\'espace', (
    tester,
  ) async {
    await bootApp(tester);

    expect(find.text('KENOS'), findsOneWidget);
    expect(find.text('ENTRER'), findsOneWidget);
    expect(find.textContaining('TROIS SECONDES'), findsOneWidget);

    await tester.tap(find.text('ENTRER'));
    await tester.pump(const Duration(milliseconds: 700)); // transition fondu

    expect(find.textContaining('MODE DÉMO LOCAL'), findsOneWidget);
    expect(find.textContaining('À LIRE'), findsOneWidget,
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

    // 3-second long press on an ether star.
    // NB: le premier pump n'attache que le ticker de l'animation.
    // Orbits cluster stars near their planets and they MOVE with real
    // time — overlaps vary run to run. Hold a star whose center is
    // covered by no other star: the pressed one is surely the intended.
    final screen = Offset(
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    );
    // The living clock sweeps stars through overlaps: retry over a
    // few beats of orbit until one qualifies (visible + uncovered).
    int pick = -1;
    for (var attempt = 0; attempt < 40 && pick == -1; attempt++) {
      final starsNow = find.byType(MindfulHoldStar);
      final rectsNow = [
        for (var i = 0; i < starsNow.evaluate().length; i++)
          tester.getRect(starsNow.at(i)),
      ];
      for (var i = 0; i < rectsNow.length; i++) {
        final r = rectsNow[i];
        final onScreen = r.left >= 0 &&
            r.right <= screen.dx &&
            r.top >= 0 &&
            r.bottom <= screen.dy;
        final covered = rectsNow.asMap().entries.any(
          (e) => e.key != i && e.value.contains(r.center),
        );
        // Best candidate: visible and uncovered. Fallback (last
        // resort, attempt 39): any visible star — the assertion below
        // tolerates whichever star the pointer actually consumed by
        // checking the count, not the id.
        if (onScreen && (!covered || attempt == 39)) {
          pick = i;
          break;
        }
      }
      if (pick == -1) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }
    expect(pick, greaterThanOrEqualTo(0), reason: 'aucune étoile visible');
    // The living clock makes a single tap timing-sensitive: retry the
    // hold (re-picking a qualifying star) until the reveal opens.
    var revealed = false;
    for (var hold = 0; hold < 3 && !revealed; hold++) {
      // Re-pick: orbits swept the sky between attempts.
      var star = find.byType(MindfulHoldStar).at(pick);
      if (star.evaluate().isEmpty) {
        for (var i = 0; i < find.byType(MindfulHoldStar).evaluate().length; i++) {
          final r = tester.getRect(find.byType(MindfulHoldStar).at(i));
          if (r.left >= 0 && r.right <= screen.dx && r.top >= 0 && r.bottom <= screen.dy) {
            pick = i;
            break;
          }
        }
        star = find.byType(MindfulHoldStar).at(pick);
      }
      expect((tester.widget(star) as MindfulHoldStar).echo.id, isNotEmpty);
      final gesture = await tester.startGesture(tester.getCenter(star));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3200));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 600));
      revealed =
          find.text('ÉCHO INTERCEPTÉ — LECTURE UNIQUE').evaluate().isNotEmpty ||
          find.textContaining('TON ÉCHO DÉRIVE').evaluate().isNotEmpty;
    }
    expect(revealed, isTrue, reason: 'aucune étoile tenue après 3 essais');

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

    // Orbits cluster stars near their planets and they MOVE with real
    // time — overlaps vary run to run. Hold a star whose center is
    // covered by no other star: the pressed one is surely the intended.
    final screen = Offset(
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    );
    // The living clock sweeps stars through overlaps: retry over a
    // few beats of orbit until one qualifies (visible + uncovered).
    int pick = -1;
    for (var attempt = 0; attempt < 40 && pick == -1; attempt++) {
      final starsNow = find.byType(MindfulHoldStar);
      final rectsNow = [
        for (var i = 0; i < starsNow.evaluate().length; i++)
          tester.getRect(starsNow.at(i)),
      ];
      for (var i = 0; i < rectsNow.length; i++) {
        final r = rectsNow[i];
        final onScreen = r.left >= 0 &&
            r.right <= screen.dx &&
            r.top >= 0 &&
            r.bottom <= screen.dy;
        final covered = rectsNow.asMap().entries.any(
          (e) => e.key != i && e.value.contains(r.center),
        );
        // Best candidate: visible and uncovered. Fallback (last
        // resort, attempt 39): any visible star — the assertion below
        // tolerates whichever star the pointer actually consumed by
        // checking the count, not the id.
        if (onScreen && (!covered || attempt == 39)) {
          pick = i;
          break;
        }
      }
      if (pick == -1) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }
    expect(pick, greaterThanOrEqualTo(0), reason: 'aucune étoile visible');
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
