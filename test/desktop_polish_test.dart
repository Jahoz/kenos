import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/app/kenos_app.dart';
import 'package:kenos/features/cosmic_map/application/motion_service.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/sky_map_sheet.dart';
import 'package:kenos/features/create_echo/presentation/mirror_screen.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';

/// V3.44 — desktop and every support, civilised: ESC renounces the
/// Mirror and closes the sky map sheet, the doors LIVE under the
/// cursor, the phone's silent line folds its counts away, and the
/// CARTE breathes on tablets.
void main() {
  group('V3.44 — ÉCHAP, le réflexe universel', () {
    testWidgets('Échap renonce au Miroir', (tester) async {
      // The Mirror reads the interface voice (V3.52): scope above.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Center(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MirrorScreen(),
                    ),
                  ),
                  child: const Text('OUVRIR'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OUVRIR'));
      await tester.pumpAndSettle();
      expect(find.text('La formulation du vide'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('OUVRIR'), findsOneWidget,
          reason: 'Échap ramène au seuil précédent');
    });

    testWidgets('Échap referme la CARTE DU CIEL', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: OutlinedButton(
              onPressed: () => showSkyMapSheet(
                context,
                eye: const Offset(0.5, 0.5),
                onTravel: (_) {},
              ),
              child: const Text('OUVRIR'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('OUVRIR'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('LA CARTE DU CIEL'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('LA CARTE DU CIEL'), findsNothing,
          reason: 'Échap referme le schéma du ciel');
    });
  });

  group('V3.44 — la porte vit sous le curseur', () {
    Future<void> bootMap(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
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
      // V3.70 — raise the folded doors through the pebble.
      final pebble = find.byKey(const ValueKey('gate-pebble'));
      if (pebble.evaluate().isNotEmpty) {
        await tester.tap(pebble);
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    testWidgets('le survol vivifie la première porte', (tester) async {
      await bootMap(tester, const Size(1280, 800));

      BoxDecoration decoration() {
        final container = find
            .descendant(
              of: find.byKey(const ValueKey('gate-echo')),
              matching: find.byType(Container),
            )
            .first;
        return tester.widget<Container>(container).decoration!
            as BoxDecoration;
      }

      final before = decoration().border!.top.color;
      final center = tester.getCenter(find.byKey(const ValueKey('gate-echo')));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: center);
      await tester.pump();
      await mouse.moveTo(center);
      await tester.pump(const Duration(milliseconds: 200));
      final after = decoration().border!.top.color;

      expect(after.a, greaterThan(before.a),
          reason: 'la bordure s\'éclaire sous le curseur');
      expect(after.a, greaterThan(0.9), reason: 'pleine lumière au survol');
      expect(before.a, lessThan(0.95), reason: '…et seulement au survol');
    });

    testWidgets('en 390 px, la ligne silencieuse plie l\'inventaire',
        (tester) async {
      // The feature is the FOLD: on a narrow phone the counts leave
      // (drift, place and souffle stay). The wide line keeping its
      // counts is the status quo the compact mode carves from.
      await bootMap(tester, const Size(390, 844));
      for (var i = 0; i < 20; i++) {
        if (find.textContaining('DÉRIVE').evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 300));
      }
      final line = tester
          .widgetList<Text>(find.textContaining('DÉRIVE'))
          .first
          .data!;
      expect(line, contains('LE GOUFFRE'));
      expect(line, isNot(contains('VESTIGES')),
          reason: 'en 390 px, l\'inventaire se plie');
      expect(line, isNot(contains('SCELLÉES')));
      expect(line, isNot(contains('CONSTELLATIONS')));
    });

    testWidgets('la CARTE respire sur tablette (460), reste compacte en 390',
        (tester) async {
      Future<void> openAt(Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: OutlinedButton(
                onPressed: () => showSkyMapSheet(
                  context,
                  eye: const Offset(0.5, 0.5),
                  onTravel: (_) {},
                ),
                child: const Text('OUVRIR'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('OUVRIR'));
        await tester.pump(const Duration(milliseconds: 600));
      }

      await openAt(const Size(1200, 900));
      var width = tester.getRect(find.byType(Dialog)).width;
      expect(width, greaterThan(440), reason: 'la carte gagne sa stature');

      await tester.pumpWidget(const SizedBox.shrink());
      await openAt(const Size(360, 740));
      width = tester.getRect(find.byType(Dialog)).width;
      expect(width, lessThan(390), reason: 'le téléphone garde le compact');
    });
  });
}
