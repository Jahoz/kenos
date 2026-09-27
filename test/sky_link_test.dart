import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/app/kenos_app.dart';
import 'package:kenos/app/router.dart';
import 'package:kenos/features/cosmic_map/application/motion_service.dart';
import 'package:kenos/features/cosmic_map/application/sky_link.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';

/// V3.49 — deep links to places in the void: build and parse the
/// `/#/ciel/x/y` format, and honour it — the sky opens standing where
/// the stranger stood (fail-open: a malformed link opens the heart).
void main() {
  group('SkyLink — le format', () {
    test('build & parse font le tour complet', () {
      final world = const Offset(0.62, 0.31);
      final path = SkyLink.pathOf(world);
      expect(path, '0.62/0.31');
      final parts = path.split('/');
      expect(SkyLink.parse(parts[0], parts[1]), world);
    });

    test('hors de l\'éther, forgé ou cassé : null (fail-open au cœur)', () {
      expect(SkyLink.parse('1.4', '0.5'), isNull);
      expect(SkyLink.parse('-0.1', '0.5'), isNull);
      expect(SkyLink.parse('abc', '0.5'), isNull);
      expect(SkyLink.parse(null, null), isNull);
      // The bounds themselves are the ether's own.
      expect(SkyLink.parse('1', '0'), const Offset(1, 0));
    });

    test('l\'URL partagée porte le hash du ciel', () {
      final url = SkyLink.shareUrl(const Offset(0.8, 0.2));
      expect(url, contains('/#/ciel/0.80/0.20'));
    });
  });

  group('V3.49 — la route honore le lien', () {
    testWidgets('un lien du pays lointain y pose l\'œil', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
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
      // Sanity: born at the heart.
      expect(find.textContaining('LE GOUFFRE'), findsWidgets);

      // Travel by link: the far country.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(KenosApp)),
        listen: false,
      );
      container.read(goRouterProvider).go('/ciel/0.95/0.95');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.textContaining('LE PAYS LOINTAIN'),
        findsWidgets,
        reason: 'l\'œil s\'ouvre là où l\'inconnu se tenait',
      );
      expect(find.textContaining('UN ŒIL T\'A CONDUIT ICI'), findsOneWidget);
    });
  });
}
