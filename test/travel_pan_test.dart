import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/app/kenos_app.dart';
import 'package:kenos/features/cosmic_map/application/motion_service.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';

void main() {
  testWidgets('le pan fait dériver l\'œil (HUD)', (tester) async {
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
            (ref) => LocalEchoRepository.seeded(latency: const Duration(milliseconds: 1)),
          ),
          localEchoStoreProvider.overrideWithValue(store),
          tiltProvider.overrideWith((ref) => Stream.value(Tilt.zero)),
        ],
        child: const KenosApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    expect(find.textContaining('DÉRIVE'), findsOneWidget);

    final gesture = await tester.startGesture(const Offset(300, 200));
    await gesture.moveBy(const Offset(-2, 1));
    await tester.pump(const Duration(milliseconds: 1200));
    await gesture.moveBy(const Offset(-20, 15));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    final hud = tester.widgetList<Text>(find.textContaining('DÉRIVE')).first.data;
    // ignore: avoid_print
    print('DEBUG hud after pan: $hud');
    expect(hud, isNot(contains('0.00')));
  });
}
