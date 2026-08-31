import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/frequencies/application/wave_controller.dart';
import 'package:kenos/features/frequencies/presentation/frequencies_screen.dart';

void main() {
  testWidgets('un tap émet une onde : compteur à 1, indice envolé', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FrequenciesScreen())),
    );
    await tester.pump();
    expect(find.textContaining('0 ONDE'), findsOneWidget);
    expect(find.textContaining('TOUCHE L\'ESPACE'), findsOneWidget);

    // Tap in the upper-right quadrant of the field: cyan hue, high register.
    final fieldRect = tester.getRect(find.byType(RepaintBoundary).first);
    await tester.tapAt(
      fieldRect.center + Offset(fieldRect.width * 0.35, -fieldRect.height * 0.3),
    );
    await tester.pump();

    expect(find.textContaining('1 ONDE ACTIVE'), findsOneWidget);
    expect(find.textContaining('TOUCHE L\'ESPACE'), findsNothing);

    // The controller holds exactly one living wave, mapped from the tap.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FrequenciesScreen)),
    );
    final waves = container.read(waveControllerProvider);
    expect(waves.length, 1);
    expect(waves.first.hueIndex, 3, reason: 'X ≈ 0.85 → bande cyan');
    expect(waves.first.noteIndex, greaterThan(10), reason: 'Y ≈ 0.2 → registre haut');
  });
}
