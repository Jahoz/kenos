import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/app/kenos_app.dart';
import 'package:kenos/features/cosmic_map/application/motion_service.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';

/// V3.78f — THE CONTENT NEVER PARALLAXES. An echo lives around its
/// astre, astres around the trou noir: no tilt, no zoom, no sway may
/// displace a light from its anchor. The test drives the tilt stream
/// itself — a step far past the epsilon gate — and asserts the star
/// layer's translations stay EXACTLY zero: the sway is the scenery's
/// business (the deep field parallaxes), never the content's.
void main() {
  testWidgets('un pas de tilt ne déplace AUCUN contenu — ancre stable',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tiltStream = StreamController<Tilt>.broadcast();
    addTearDown(tiltStream.close);

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
          tiltProvider.overrideWith((ref) => tiltStream.stream),
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

    // Every Transform translation in the sky must be ZERO, before and
    // after a violent tilt step: content holds its anchor.
    List<Offset> translations() => tester
        .widgetList<Transform>(find.byType(Transform))
        .map((t) => Offset(t.transform.entry(0, 3), t.transform.entry(1, 3)))
        .where((o) => o != Offset.zero)
        .toList();

    tiltStream.add(Tilt.zero);
    await tester.pump(const Duration(milliseconds: 120));
    expect(translations(), isEmpty, reason: 'au repos, aucune translation');

    tiltStream.add(const Tilt(0.9, -0.9));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      translations(),
      isEmpty,
      reason: 'le contenu ne parallaxe pas — un écho vit autour de son astre, '
          'un astre autour du trou noir, quoi que fasse la main',
    );
  });
}
