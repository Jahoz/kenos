import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/application/motion_service.dart';
import 'package:kenos/features/cosmic_map/presentation/map_screen.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/system_painter.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';

/// V3.12c — the sky drifts on its OWN heartbeat: the heavens' painter
/// advances while the map idles, with no camera movement, no gesture.
void main() {
  testWidgets('les cieux avancent au repos, sans interaction', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
}
