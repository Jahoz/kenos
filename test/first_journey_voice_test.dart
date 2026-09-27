import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kenos/app/kenos_app.dart';
import 'package:kenos/core/voice/kenos_voice.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/presentation/constellation_sheets.dart';
import 'package:kenos/features/cosmic_map/application/motion_service.dart';
import 'package:kenos/features/create_echo/presentation/mirror_screen.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';

void main() {
  group('KenosVoice.resolve — the laws of the tongue', () {
    test('the web build serves English to an English platform', () {
      expect(
        KenosVoice.resolve(web: true, platformLocale: const Locale('en')),
        KenosVoice.english,
      );
      expect(
        KenosVoice.resolve(web: true, platformLocale: const Locale('en', 'GB')),
        KenosVoice.english,
      );
    });

    test('French stays canonical for every other tongue', () {
      expect(
        KenosVoice.resolve(web: true, platformLocale: const Locale('fr')),
        KenosVoice.french,
      );
      expect(
        KenosVoice.resolve(web: true, platformLocale: const Locale('de')),
        KenosVoice.french,
      );
      expect(
        KenosVoice.resolve(web: true, platformLocale: null),
        KenosVoice.french,
      );
    });

    test('native builds keep the canonical voice (V3.52)', () {
      expect(
        KenosVoice.resolve(
          web: false,
          platformLocale: const Locale('en', 'US'),
        ),
        KenosVoice.french,
      );
    });

    test('pick keeps the canonical string at the call site', () {
      const voice = KenosVoice.french;
      expect(voice.pick('ENTRER', 'ENTER'), 'ENTRER');
      expect(KenosVoice.english.pick('ENTRER', 'ENTER'), 'ENTER');
    });
  });

  group('The English first journey (V3.52)', () {
    testWidgets('the threshold speaks its three rules in English', (
      tester,
    ) async {
      await _bootApp(tester, onboarded: false);
      expect(find.text('ENTER'), findsOneWidget);
      expect(find.textContaining('No profile, no name, no trail'),
          findsOneWidget);
      expect(find.textContaining('Each echo can be read only once'),
          findsOneWidget);
      expect(
        find.textContaining('HOLD ITS STAR FOR THREE SECONDS'),
        findsOneWidget,
      );
      // The canonical copy stands down.
      expect(find.text('ENTRER'), findsNothing);
      expect(find.textContaining('Aucun profil'), findsNothing);
    });

    testWidgets('the two gates speak English on the map', (tester) async {
      await _bootApp(tester, onboarded: true);
      await _crossAube(tester);
      expect(find.text('FORMULATE AN ECHO'), findsOneWidget);
      expect(find.text('SOW A CONSTELLATION'), findsOneWidget);
      expect(find.text('FORMULER UN ÉCHO'), findsNothing);
    });

    testWidgets('the Mirror composes in English', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [voiceProvider.overrideWithValue(KenosVoice.english)],
          child: const MaterialApp(home: MirrorScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('MIRROR'), findsOneWidget);
      expect(find.text('THE INTENTION'), findsOneWidget);
      expect(find.text('SOOTHE'), findsOneWidget);
      expect(find.text('SOUND'), findsOneWidget);
      expect(find.text('DOOR'), findsOneWidget);
      expect(find.text('SEAL & RELEASE'), findsOneWidget);
      expect(find.text('RENOUNCE'), findsOneWidget);
      expect(find.textContaining('Write what you say nowhere else'),
          findsOneWidget);
      // The canon stands down.
      expect(find.text('MIROIR'), findsNothing);
      expect(find.text('APAISER'), findsNothing);
      expect(find.text('SCELLER & LANCER'), findsNothing);
    });

    testWidgets('the artifact reading reports in English', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [voiceProvider.overrideWithValue(KenosVoice.english)],
          child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        ),
      );
      await tester.pump();
      // The reading is a root-navigator dialog: its future ends only
      // when the dialog closes — never awaited here.
      unawaited(showConstellationReading(
        tester.state(find.byType(Scaffold)).context,
        lines: const [
          AssembledLine(number: 1, text: 'a stranger’s line'),
          AssembledLine(number: 2, text: 'another, sealed'),
        ],
        figureId: 'figure-en',
        reportable: true,
      ));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.text('REPORT THIS POEM'));
      expect(find.text('REPORT THIS POEM'), findsOneWidget);
      expect(find.text('RETURN TO THE VOID'), findsOneWidget);
      expect(find.text('SIGNALER CE POÈME'), findsNothing);

      await tester.tap(find.text('REPORT THIS POEM'));
      await tester.pumpAndSettle();
      expect(find.text('INAPPROPRIATE CONTENT'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });
  });
}

Future<void> _bootApp(WidgetTester tester, {required bool onboarded}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        voiceProvider.overrideWithValue(KenosVoice.english),
        bootstrapProvider.overrideWithValue(
          Bootstrap(supabaseConfigured: false, hasOnboarded: onboarded),
        ),
        echoRepositoryProvider.overrideWith(
          (ref) => LocalEchoRepository.seeded(
            latency: const Duration(milliseconds: 1),
          ),
        ),
        localEchoStoreProvider.overrideWithValue(LocalEchoStore()),
        tiltProvider.overrideWith((ref) => Stream.value(Tilt.zero)),
      ],
      child: const KenosApp(),
    ),
  );
  await tester.pump();
}

/// The Aube's own gates stay French (beyond the first journey) — the
/// harness crosses them the way the French one does. No pumpAndSettle
/// here: the sky breathes forever (4 Hz), it never settles.
Future<void> _crossAube(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  for (final gate in ['TOUCHE POUR ENTRER', 'TOUCHE LE VIDE POUR ENTRER']) {
    if (find.text(gate).evaluate().isNotEmpty) {
      await tester.tap(find.text(gate));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 2100));
    }
  }
  // V3.70 — the doors kneel into a pebble at the survey gaze: raise
  // them through the pebble.
  final pebble = find.byKey(const ValueKey('gate-pebble'));
  if (pebble.evaluate().isNotEmpty) {
    await tester.tap(pebble);
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pump(const Duration(seconds: 1));
}
