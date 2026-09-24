import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/app/kenos_app.dart';
import 'package:kenos/features/cosmic_map/application/motion_service.dart';
import 'package:kenos/features/cosmic_map/application/void_territories.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';

/// V3.35 — the landscapes of the void: crossing a territory whispers
/// its name ONCE per session (the born territory never greets — the
/// sky does not greet itself), the HUD always tells where the eye
/// rides, and a landscape already spoken stays silent forever. The
/// once-ness is session state (territoriesAnnouncedProvider): every
/// test owns its own scope, no reset needed.
void main() {
  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = LocalEchoStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(
            const Bootstrap(supabaseConfigured: false, hasOnboarded: true),
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
    await tester.pump(const Duration(seconds: 3));

    // First visit: whichever gate speaks (corpses guide or the dawn),
    // it is entered — the sky must be reachable to travel.
    for (final gate in ['TOUCHE POUR ENTRER', 'TOUCHE LE VIDE POUR ENTRER']) {
      if (find.text(gate).evaluate().isNotEmpty) {
        await tester.tap(find.text(gate));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 2100));
      }
    }
  }

  /// Drags the void: sky follows the finger, so a LEFT/UP drag sends
  /// the eye RIGHT/UP — away from the heart, into the gardens.
  Future<void> dragVoid(
    WidgetTester tester,
    Offset by,
  ) async {
    final gesture = await tester.startGesture(const Offset(195, 422));
    await gesture.moveBy(by / 3);
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.moveBy(by / 3);
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.moveBy(by - by / 3 * 2);
    await tester.pump();
    await gesture.up();
    // Absorb the glide: the whisper must survive the drift's tail.
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('le paysage se dit en le traversant, une fois', (tester) async {
    await boot(tester);

    // Born at the heart: the HUD names the throat, the sky says
    // nothing — one's birthplace is not news.
    expect(find.textContaining('LE GOUFFRE'), findsWidgets);
    expect(
      find.text(VoidTerritories.whisperTitle(VoidTerritory.gardens)),
      findsNothing,
    );

    // Out of the throat, into the gardens: the crossing speaks.
    // (Whispers are asserted on their serif line — the throat's title
    // shares its string with the HUD's own label for it. V3.69: the
    // survey gaze travels ~0.9 world per 390 px — the drag is halved
    // to LAND in the gardens, not overshoot into the far country.)
    await dragVoid(tester, const Offset(-140, -20));
    expect(
      find.text(VoidTerritories.whisperLine(VoidTerritory.gardens)),
      findsOneWidget,
    );

    // The breath leaves on its own — never a resident of the screen.
    await tester.pump(const Duration(seconds: 8));
    expect(
      find.text(VoidTerritories.whisperLine(VoidTerritory.gardens)),
      findsNothing,
    );

    // Home again: the throat, never greeted at birth, is told now.
    await dragVoid(tester, const Offset(140, 20));
    expect(
      find.text(VoidTerritories.whisperLine(VoidTerritory.throat)),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 8));

    // Back out: the gardens were already spoken — the sky stays quiet.
    await dragVoid(tester, const Offset(-140, -20));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(VoidTerritories.whisperLine(VoidTerritory.gardens)),
      findsNothing,
    );
    expect(
      find.text(VoidTerritories.whisperLine(VoidTerritory.throat)),
      findsNothing,
    );
  });

  testWidgets('le HUD dit toujours où dérive l\'œil', (tester) async {
    await boot(tester);

    // The born territory rides the silent line, next to the drift.
    final hud = tester.widgetList<Text>(find.textContaining('LE GOUFFRE'));
    expect(hud, isNotEmpty);

    await dragVoid(tester, const Offset(-140, -20));
    expect(find.textContaining('LES JARDINS'), findsWidgets);
  });
}
