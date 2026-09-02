import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/constants/app_layout.dart';
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

  group('La colonne de posture', () {
    testWidgets(
        'sur écran large, le contenu vit dans la colonne centrée — pas étiré',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.postureMaxWidth,
                ),
                child: KeyedSubtree(
                  key: const Key('posture-column'),
                  child: const ColoredBox(color: Color(0xFF010203), child: SizedBox.expand()),
                ),
              ),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(const Key('posture-column')));
      expect(rect.width, AppLayout.postureMaxWidth,
          reason: 'la composition ne s\'étire jamais au-delà de la posture');
      expect(rect.left, (1440 - AppLayout.postureMaxWidth) / 2,
          reason: 'la colonne est centrée dans le vide');
    });
  });
}
