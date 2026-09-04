import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/presentation/constellation_sheets.dart';
import 'package:kenos/features/create_echo/presentation/mirror_screen.dart';

/// The guard at the threshold of creation (the Trace Shield's
/// contract, extended where the ether is structurally blind): a
/// thought that carries a phone number gets the anonymity warning
/// BEFORE it seals — device-side, zero network. WARN, never block.
void main() {
  group('Miroir : le seuil avant le scellement', () {
    testWidgets(
      'un numéro → l\'avertissement ; REPRENDRE garde la pensée, et le seuil revient',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: MirrorScreen())),
        );
        await tester.pump();

        await tester.enterText(
          find.byType(TextField),
          'je laisse mon numero 0683077484',
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(OutlinedButton, 'SCELLER & LANCER'));
        await tester.pump();

        // The threshold opens, the thought is NOT sealed yet.
        expect(find.text('TON ANONYMAT EST LE CONTRAT'), findsOneWidget);
        expect(find.text('LAISSER QUAND MÊME'), findsOneWidget);

        await tester.tap(find.text('REPRENDRE MA PENSÉE'));
        await tester.pump();
        expect(find.text('TON ANONYMAT EST LE CONTRAT'), findsNothing);
        // The thought stayed, whole, editable.
        expect(find.text('je laisse mon numero 0683077484'), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'SCELLER & LANCER'),
              )
              .onPressed,
          isNotNull,
          reason: 'reprendre n\'est pas renoncer : le sceau reste possible',
        );

        // Only LEAVING acknowledges: a retry warns again.
        await tester.tap(find.widgetWithText(OutlinedButton, 'SCELLER & LANCER'));
        await tester.pump();
        expect(find.text('TON ANONYMAT EST LE CONTRAT'), findsOneWidget);
        await tester.tap(find.text('REPRENDRE MA PENSÉE'));
        await tester.pump();
      },
    );
  });

  group('Cadavre poème : avertir, jamais bloquer', () {
    testWidgets('numéro → seuil, puis LAISSER QUAND MÊME scelle la ligne', (
      tester,
    ) async {
      final repo = FakeConstellationRepository();
      await tester.pumpSheet(repo, ConstellationKind.poem);
      await tester.pump(const Duration(milliseconds: 600));

      await tester.enterText(
        find.byType(TextField),
        'rappelle-moi au 06 83 07 74 84',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'DONNER LA LIGNE'));
      await tester.pump();

      expect(find.text('TON ANONYMAT EST LE CONTRAT'), findsOneWidget);
      await tester.tap(find.text('LAISSER QUAND MÊME'));
      await tester.pump();
      // The ack SnackBar must fully expire before the test ends.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));

      // Non-blocking, proven: the line sealed and drifted.
      expect(repo.lines, hasLength(1));
      expect(repo.lines.single, contains('06 83 07 74 84'));
    });

    testWidgets('ligne innocente → aucun seuil, envoi direct', (tester) async {
      final repo = FakeConstellationRepository();
      await tester.pumpSheet(repo, ConstellationKind.poem);
      await tester.pump(const Duration(milliseconds: 600));

      await tester.enterText(find.byType(TextField), 'le vent dans l\'absinthe');
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'DONNER LA LIGNE'));
      await tester.pump();
      expect(find.text('TON ANONYMAT EST LE CONTRAT'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(repo.lines, hasLength(1));
    });
  });
}

extension PumpSheet on WidgetTester {
  /// Host (a ConsumerWidget gives the sheet a real WidgetRef) + open
  /// via the gate button; the dialog future stays pending while the
  /// sheet is up.
  Future<void> pumpSheet(
    ConstellationRepository repo,
    ConstellationKind kind,
  ) async {
    await pumpWidget(
      ProviderScope(
        overrides: [constellationRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: _SheetHost(kind: kind)),
      ),
    );
    await tap(find.text('OPEN'));
    await pump();
  }
}

class _SheetHost extends ConsumerWidget {
  const _SheetHost({required this.kind});

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

class FakeConstellationRepository implements ConstellationRepository {
  final List<String> lines = [];

  @override
  Future<ContributeResult> contribute({
    required String constellationId,
    required String text,
  }) async {
    lines.add(text);
    return ContributeResult(count: lines.length);
  }

  @override
  Future<bool?> hasContributed(String id) async => null;

  @override
  Future<AssembledLine?> peekPrevious(String constellationId) async => null;

  @override
  Future<ConstellationMeta> seed(
    double x,
    double y, {
    ConstellationKind kind = ConstellationKind.poem,
  }) async => throw UnimplementedError();

  @override
  Future<List<ConstellationMeta>> fetchVisible() async => const [];

  @override
  Future<List<AssembledLine>?> read(String id) async => null;
}
