import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/widgets/ether_dissolve.dart';
import 'package:kenos/core/widgets/scramble_text.dart';

void main() {
  group('Accessibilité — « réduire les animations »', () {
    testWidgets('ScrambleText se résout instantanément quand le flag est actif', (
      tester,
    ) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScrambleText(text: 'message clair', resolve: true),
          ),
        ),
      );
      // First frame only: no animation frames pumped.
      final text = tester.widget<Text>(find.byType(Text)).data!;
      expect(text, 'message clair');
    });

    testWidgets('ScrambleText anime normalement sans le flag', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScrambleText(text: 'message', resolve: true),
          ),
        ),
      );
      // Mid-animation: the first characters are resolved, the rest is noise.
      await tester.pump(const Duration(milliseconds: 5));
      final text = tester.widget<Text>(find.byType(Text)).data!;
      expect(text, isNot('message'));
    });

    testWidgets('EtherDissolve (fallback CPU) ne lève jamais', (
      tester,
    ) async {
      // In the test environment the shader program cannot load: the CPU
      // painter path is the one exercised here.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EtherDissolve(
              progress: 0.5,
              color: Color(0xFF14B8A6),
              seed: 0.37,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(EtherDissolve), findsOneWidget);
    });

    testWidgets('EtherDissolve est invisible hors fenêtre', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EtherDissolve(progress: 0.0, color: Color(0xFF14B8A6)),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(EtherDissolve),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });
}
