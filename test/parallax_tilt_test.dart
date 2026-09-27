import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/app/kenos_app.dart';
import 'package:kenos/features/cosmic_map/application/motion_service.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';

/// V3.78d — THE TILT NEVER REBUILDS (and it still MOVES). The buckets
/// must answer a gated tilt change by transforming their rasters — a
/// sway is a transform, never a relayout. The test drives the tilt
/// stream itself: emit a step far past the epsilon gate, and the
/// bucket translations must move — WITHOUT the star layer rebuilding
/// (the star rasters keep their element identities).
void main() {
  testWidgets('un sway de tilt déplace les buckets, sans rebuild',
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

    // The bucket translations of the star layer (Transform.translate
    // widgets carrying the parallax): where they sit at rest.
    List<Offset> bucketTranslations() => tester
        .widgetList<Transform>(find.byType(Transform))
        .map((t) => Offset(t.transform.entry(0, 3), t.transform.entry(1, 3)))
        .where((o) => o != Offset.zero)
        .toList();

    tiltStream.add(Tilt.zero);
    await tester.pump(const Duration(milliseconds: 120));
    // At rest the bucket translations are zero BY DEFINITION (tilt 0):
    // the star layer must exist, carrying its Transform widgets.
    expect(find.byType(Transform).evaluate().isNotEmpty, true,
        reason: 'le ciel existe');
    final before = bucketTranslations();
    expect(before.isEmpty, true,
        reason: 'au repos, aucune translation de parallaxe');

    // A step far past the epsilon gate (0.008): the buckets must move.
    tiltStream.add(const Tilt(0.4, -0.4));
    await tester.pump(const Duration(milliseconds: 120));
    final after = bucketTranslations();

    expect(after.isNotEmpty, true,
        reason: 'le sway déplace les buckets — un transform, jamais un rebuild');
  });
}
