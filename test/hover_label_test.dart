import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/app/kenos_app.dart';
import 'package:kenos/features/cosmic_map/application/kenos_system.dart';
import 'package:kenos/features/cosmic_map/application/motion_service.dart';
import 'package:kenos/features/cosmic_map/application/travel_camera.dart';
import 'package:kenos/features/cosmic_map/presentation/map_screen.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';

/// V3.38 — the hover label RIDES its body (desktop eye): it appears
/// beside the world — never printed on it — and it follows the sky
/// panning under a still pointer.
///
/// The tests are CLOCK-FREE: La Lune is first carried to a known
/// screen point by an exact drag (the finger held still before
/// release, so the glide carries nothing) — her low orbit would
/// otherwise ride behind the bottom gates at the wrong hour, and a
/// test must not depend on when it runs.
void main() {
  setUp(() {
    MapScreen.territoriesAnnounced.clear();
  });

  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
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

    for (final gate in ['TOUCHE POUR ENTRER', 'TOUCHE LE VIDE POUR ENTRER']) {
      if (find.text(gate).evaluate().isNotEmpty) {
        await tester.tap(find.text(gate));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 2100));
      }
    }
  }

  /// Where La Lune rides right now, for an eye born at the heart —
  /// the map's own camera is untouched at boot, so the math agrees.
  Offset moonOnScreen() {
    final camera = TravelCamera();
    return camera.worldToScreen(
      KenosSystem.planetPosition(0, DateTime.now()),
      const Size(1280, 800),
    );
  }

  /// Carries La Lune to [target] by an exact, glide-free drag: the
  /// finger holds still before release, so the inertia path is empty
  /// and the sky lands exactly where the finger said.
  Future<void> settleMoonAt(WidgetTester tester, Offset target) async {
    final delta = target - moonOnScreen();
    final gesture = await tester.startGesture(const Offset(640, 400));
    for (var i = 1; i <= 3; i++) {
      await gesture.moveBy(delta / 3);
      await tester.pump(const Duration(milliseconds: 120));
    }
    // Held still: the release velocity is nil, the glide is nothing.
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets("l'étiquette naît À CÔTÉ du monde, jamais dessus",
      (tester) async {
    await boot(tester);
    // A point the gates and the HUD never cover.
    const moon = Offset(640, 350);
    await settleMoonAt(tester, moon);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: moon);
    await tester.pump();
    await mouse.moveTo(moon);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('La Lune'), findsOneWidget);
    final label = tester.getTopLeft(find.text('La Lune'));
    // Anchored OUTSIDE the moon's tap zone (≈ 23 px at the resting
    // eye): the label sits to the RIGHT of the world, clear of its
    // disc and halo — the old code printed it centered on top.
    expect(label.dx, greaterThan(moon.dx + 20),
        reason: "le nom flotte à côté, pas sur le monde");
    expect(label.dy, lessThan(moon.dy),
        reason: 'le nom flotte au-dessus de la ligne du monde');
  });

  testWidgets("l'étiquette suit le monde quand le ciel glisse sous le pointeur",
      (tester) async {
    await boot(tester);
    const moon = Offset(640, 350);
    await settleMoonAt(tester, moon);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: moon);
    await tester.pump();
    await mouse.moveTo(moon);
    await tester.pump(const Duration(milliseconds: 300));
    final before = tester.getTopLeft(find.text('La Lune'));
    expect(before.dx, greaterThan(0));

    // The sky follows the finger: dragging LEFT carries every world
    // (and the label that rides it) LEFT by the same distance. The
    // finger stills before release — no glide, the distance is exact.
    final pan = await tester.startGesture(const Offset(300, 200));
    for (var i = 1; i <= 3; i++) {
      await pan.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pump(const Duration(milliseconds: 150));
    await pan.up();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('La Lune'), findsOneWidget);
    final after = tester.getTopLeft(find.text('La Lune'));
    expect(
      (after.dx - before.dx).abs(),
      inInclusiveRange(100, 140),
      reason: 'le nom a suivi le monde (−120 px, sans inertie)',
    );
  });

  testWidgets('quitter le monde éteint le nom', (tester) async {
    await boot(tester);
    const moon = Offset(640, 350);
    await settleMoonAt(tester, moon);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: moon);
    await tester.pump();
    await mouse.moveTo(moon);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('La Lune'), findsOneWidget);

    // Into the empty sky: no world under the pointer, no name.
    await mouse.moveTo(const Offset(640, 120));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('La Lune'), findsNothing);
  });
}
