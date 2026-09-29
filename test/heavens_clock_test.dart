import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/constants/app_meta.dart';
import 'package:kenos/features/cosmic_map/application/motion_service.dart';
import 'package:kenos/features/cosmic_map/application/travel_camera.dart';
import 'package:kenos/features/cosmic_map/presentation/map_screen.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/system_painter.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';

import 'controllers_test.dart' show FakeLocalEchoStore;

/// V3.12c — the sky drifts on its OWN heartbeat: the heavens' painter
/// advances while the map idles, with no camera movement, no gesture.
void main() {
  testWidgets('les cieux avancent au repos, sans interaction', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // V3.89 — a signed pact (fake store: under the frozen test clock,
    // the real store's keychain-timeout write would never return).
    final store = FakeLocalEchoStore()..pactVersion = kAubePactVersion;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(
            const Bootstrap(supabaseConfigured: false, hasOnboarded: true),
          ),
          echoRepositoryProvider.overrideWith(
            (ref) => LocalEchoRepository.seeded(
              latency: const Duration(milliseconds: 10),
            ),
          ),
          localEchoStoreProvider.overrideWithValue(store),
          tiltProvider.overrideWith((ref) => Stream.value(Tilt.zero)),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    // Let the map settle (loads, veils fade or speak — irrelevant here).
    await tester.pump(const Duration(seconds: 2));

    SystemPainter? heavens() {
      for (final cp
          in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
        if (cp.painter is SystemPainter) return cp.painter as SystemPainter;
      }
      return null;
    }

    final before = heavens();
    expect(before, isNotNull, reason: 'les cieux sont peints');
    final t0 = before!.now;

    // Idle: no gesture, no camera change — only time.
    await tester.pump(const Duration(milliseconds: 600));

    final after = heavens();
    expect(after, isNotNull);
    expect(after!.now.isAfter(t0), isTrue,
        reason:
            "l'horloge des cieux bat seule — la fluidité n'attend pas le doigt");
  });
  testWidgets('contrat de repeint : l\'œil bougé repeint, même horloge',
      (tester) async {
    final camera = TravelCamera();
    final t = DateTime.now();
    final still = SystemPainter(
      camera: camera,
      viewport: const Size(390, 844),
      now: t,
      reducedMotion: false,
    );
    final sameStill = SystemPainter(
      camera: camera,
      viewport: const Size(390, 844),
      now: t,
      reducedMotion: false,
    );
    expect(still.shouldRepaint(sameStill), isFalse,
        reason: 'rien ne bouge, rien ne repeint');

    camera.panByWorld(const Offset(0.2, 0.1));
    final moved = SystemPainter(
      camera: camera,
      viewport: const Size(390, 844),
      now: t,
      reducedMotion: false,
    );
    expect(still.shouldRepaint(moved), isTrue,
        reason: 'l\'œil a bougé — les cieux repeignent, horloge identique ou non');
  });
}
