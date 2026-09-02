import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/widgets/portrait_guard.dart';

/// The posture: KENOS's composition is a portrait column. Wide
/// landscapes (tablets, desktops) are WELCOMED — only a held phone
/// lying flat meets the veil.
void main() {
  group('PortraitGuard — la colonne de posture', () {
    testWidgets('téléphone allongé (paysage bas) : le voile demande de se tenir debout',
        (tester) async {
      tester.view.physicalSize = const Size(844, 390); // landscape phone
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

    testWidgets('tablette en paysage : le contenu règne, jamais de voile',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768); // iPad landscape
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
      expect(find.textContaining('TOURNE'), findsNothing,
          reason: 'une tablette debout vit debout');
    });

    testWidgets('desktop en paysage : le contenu règne, jamais de voile',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
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
      expect(find.textContaining('TOURNE'), findsNothing,
          reason: "un desktop ne peut pas « tourner son appareil »");
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

    testWidgets('sans enforcement (natif verrouillé) : jamais de voile',
        (tester) async {
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
