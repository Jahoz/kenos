import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/widgets/portrait_guard.dart';

void main() {
  group('PortraitGuard — l\'éther est portrait', () {
    testWidgets('paysage forcé : le voile demande de se tenir debout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390); // landscape
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: PortraitGuard(
            enforce: true,
            child: Scaffold(body: Text('LE CONTENU')),
          ),
        ),
      );

      expect(find.textContaining('se vit debout'), findsOneWidget);
      expect(find.textContaining('TOURNE TON APPAREIL'), findsOneWidget);
      expect(find.text('LE CONTENU'), findsNothing);
    });

    testWidgets('portrait : le contenu règne, pas de voile', (tester) async {
      tester.view.physicalSize = const Size(390, 844); // portrait
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: PortraitGuard(
            enforce: true,
            child: Scaffold(body: Text('LE CONTENU')),
          ),
        ),
      );

      expect(find.text('LE CONTENU'), findsOneWidget);
      expect(find.textContaining('TOURNE'), findsNothing);
    });

    testWidgets('sans enforcement (natif verrouillé) : jamais de voile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390); // landscape
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: PortraitGuard(
            enforce: false,
            child: Scaffold(body: Text('LE CONTENU')),
          ),
        ),
      );

      expect(find.text('LE CONTENU'), findsOneWidget);
    });
  });
}
