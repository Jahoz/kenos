import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/app/kenos_app.dart';
import 'package:kenos/core/constants/app_colors.dart';
import 'package:kenos/features/cosmic_map/application/motion_service.dart';
import 'package:kenos/features/cosmic_map/presentation/map_screen.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';

/// V3.41 — LES DEUX PORTES: the map's two acts, readable and
/// reachable. The contract pinned here: both doors stand at least
/// 44 px tall (the thumb's law), both sit on OPAQUE fills (the sky
/// never prints through the words), the first door carries the teal
/// light and near-full text, and the corpse's indigo is gone from
/// the gate (it lives on the map, where it has contrast).
void main() {
  setUp(() {
    MapScreen.territoriesAnnounced.clear();
  });

  Future<void> boot(WidgetTester tester) async {
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
  }

  BoxDecoration doorDecoration(WidgetTester tester, Key key) {
    final container = find
        .descendant(
          of: find.byKey(key),
          matching: find.byType(Container),
        )
        .first;
    final widget = tester.widget<Container>(container);
    return widget.decoration! as BoxDecoration;
  }

  testWidgets('deux portes, la taille du pouce, des mots opaques',
      (tester) async {
    await boot(tester);

    expect(find.text('FORMULER UN ÉCHO'), findsOneWidget);
    expect(find.text('SEMER UNE CONSTELLATION'), findsOneWidget);

    for (final key in [
      const ValueKey('gate-echo'),
      const ValueKey('gate-constellation'),
    ]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.height, greaterThanOrEqualTo(44),
          reason: 'la porte se tient sous le pouce');
      expect(size.width, greaterThan(180));
      final decor = doorDecoration(tester, key);
      // Opaque: a door is a surface, never a window.
      expect(decor.color!.a, 1.0, reason: 'le ciel n\'imprime pas à travers');
      // And the corpse's muddy indigo is gone from the gates.
      final side = decor.border!.top.color;
      final isTeal =
          side.r == AppColors.teal.r && side.g == AppColors.teal.g;
      final isLight = side.r == AppColors.pureLight.r &&
          side.g == AppColors.pureLight.g;
      expect(isTeal || isLight, isTrue,
          reason: 'les portes parlent teal ou lumière — plus de violet');
    }
  });

  testWidgets('la première porte porte la lumière', (tester) async {
    await boot(tester);

    final first = doorDecoration(tester, const ValueKey('gate-echo'));
    final second =
        doorDecoration(tester, const ValueKey('gate-constellation'));

    // The hierarchy rides LIGHT: the first door glows, the second
    // does not.
    expect(first.boxShadow, isNotEmpty);
    expect(second.boxShadow, isEmpty);

    // And the first door's text is the fuller voice.
    final echoText = tester.widget<Text>(find.text('FORMULER UN ÉCHO'));
    expect(echoText.style!.fontSize, greaterThan(10));
    expect(echoText.style!.color!.a, greaterThan(0.9));
  });

  testWidgets('V3.43 — la disposition : empilées sur téléphone, côte à côte en large',
      (tester) async {
    await boot(tester); // 390×844 — the phone.

    final semer =
        tester.getRect(find.byKey(const ValueKey('gate-constellation')));
    final echo = tester.getRect(find.byKey(const ValueKey('gate-echo')));
    expect(echo.top, greaterThan(semer.bottom),
        reason: 'sur téléphone, la première porte est sous le pouce');

    // The wide window: two doors, side by side — the disposition of
    // a threshold, not a stack.
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      tester.widget<ProviderScope>(find.byType(ProviderScope)),
    );
    await tester.pump(const Duration(seconds: 2));
    for (final gate in ['TOUCHE POUR ENTRER', 'TOUCHE LE VIDE POUR ENTRER']) {
      if (find.text(gate).evaluate().isNotEmpty) {
        await tester.tap(find.text(gate));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 2100));
      }
    }
    final semerWide =
        tester.getRect(find.byKey(const ValueKey('gate-constellation')));
    final echoWide = tester.getRect(find.byKey(const ValueKey('gate-echo')));
    expect((semerWide.bottom - echoWide.bottom).abs(), lessThan(1),
        reason: 'côte à côte : posées sur le même sol');
    expect(semerWide.right, lessThan(echoWide.left),
        reason: 'la seconde porte à gauche de la première');
  });
}
