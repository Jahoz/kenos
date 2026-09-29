import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/presentation/constellation_sheets.dart';
import 'package:kenos/features/create_echo/presentation/mirror_screen.dart';

import 'pii_warning_test.dart' show FakeConstellationRepository;

/// The care moment at the threshold of creation (V3.88): a thought
/// that carries a real weight is offered the quiet hand BEFORE it
/// seals — device-side, zero network, WARN never block. The dialog
/// never quotes the words; it names the doors that exist.
void main() {
  group('Miroir : le moment de soin avant le scellement', () {
    testWidgets(
      'une vraie douleur → la main tendue ; REPRENDRE garde la pensée, et la main revient',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: MirrorScreen())),
        );
        await tester.pump();

        await tester.enterText(
          find.byType(TextField),
          'je ne vais pas bien, je veux mourir',
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(OutlinedButton, 'SCELLER & LANCER'));
        await tester.pump();

        // The hand opens; the thought is NOT sealed yet.
        expect(find.text('AVANT QUE ÇA DÉRIVE'), findsOneWidget);
        // The law: the dialog never quotes the author's words — the
        // only place they exist is the author's own draft.
        expect(find.textContaining('je veux mourir'), findsOneWidget);
        // The door is named — 3114, with its purpose.
        expect(
          find.textContaining('3114'),
          findsWidgets,
          reason: 'la porte détresse est nommée, avec son usage',
        );

        await tester.tap(find.text('REPRENDRE MA PENSÉE'));
        await tester.pump();
        expect(find.text('AVANT QUE ÇA DÉRIVE'), findsNothing);
        // The thought stayed, whole, editable.
        expect(find.text('je ne vais pas bien, je veux mourir'), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'SCELLER & LANCER'),
              )
              .onPressed,
          isNotNull,
          reason: 'reprendre n\'est pas renoncer : le sceau reste possible',
        );

        // Only PROCEEDING acknowledges: a retry offers the hand again.
        await tester.tap(find.widgetWithText(OutlinedButton, 'SCELLER & LANCER'));
        await tester.pump();
        expect(find.text('AVANT QUE ÇA DÉRIVE'), findsOneWidget);
        await tester.tap(find.text('REPRENDRE MA PENSÉE'));
        await tester.pump();
      },
    );

    testWidgets('une pensée légère → aucune main, envoi direct du seuil', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: MirrorScreen())),
      );
      await tester.pump();

      await tester.enterText(
        find.byType(TextField),
        'le concert de violon de samedi',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'SCELLER & LANCER'));
      // The sealing ceremony takes its time (scramble, launch): let
      // the timers run out so the test ends clean.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));

      // The violon stays music: no care moment was offered.
      expect(find.text('AVANT QUE ÇA DÉRIVE'), findsNothing);
    });
  });

  group('Cadavre poème : la main tendue aussi', () {
    testWidgets('douleur → la main, puis DONNER QUAND MÊME scelle la ligne', (
      tester,
    ) async {
      final repo = FakeConstellationRepository();
      await tester.pumpSheet(repo, ConstellationKind.poem);
      await tester.pump(const Duration(milliseconds: 600));

      await tester.enterText(
        find.byType(TextField),
        'je me coupe depuis l\'hiver',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'DONNER LA LIGNE'));
      await tester.pump();

      expect(find.text('AVANT QUE ÇA DÉRIVE'), findsOneWidget);
      await tester.tap(find.text('DONNER QUAND MÊME'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));

      // Non-blocking, proven: the line sealed and drifted.
      expect(repo.lines, hasLength(1));
    });
  });
}

extension PumpCareSheet on WidgetTester {
  Future<void> pumpSheet(
    ConstellationRepository repo,
    ConstellationKind kind,
  ) async {
    await pumpWidget(
      ProviderScope(
        overrides: [constellationRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: _CareSheetHost(kind: kind)),
      ),
    );
    await tap(find.text('OPEN'));
    await pump();
  }
}

class _CareSheetHost extends ConsumerWidget {
  const _CareSheetHost({required this.kind});

  final ConstellationKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => unawaited(
        showContributeSheet(
          context,
          ref: ref,
          constellation: ConstellationMeta(
            id: 'c1',
            seedX: 0.5,
            seedY: 0.5,
            state: 'OPEN',
            lineCount: 1,
            target: 4,
            kind: kind,
          ),
        ),
      ),
      child: const Text('OPEN'),
    );
  }
}
