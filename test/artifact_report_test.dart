import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/presentation/constellation_sheets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('LocalConstellationRepository — the report parity (V3.51)', () {
    test('a closed artifact is flagged once per hand', () async {
      final repo = LocalConstellationRepository();
      final seeded = await repo.seed(0.5, 0.5);
      final id = seeded.meta.id;
      // Close the ring: four strangers, four lines.
      for (var i = 0; i < seeded.meta.target; i++) {
        await repo.contribute(constellationId: id, text: 'ligne $i');
      }
      expect(seeded.meta.target, greaterThanOrEqualTo(4));
      expect(await repo.read(id), isNotEmpty); // CLOSED and readable.

      expect(await repo.report(id, 'INAPPROPRIATE'), isTrue);
      expect(await repo.report(id, 'SPAM'), isFalse); // one hand, one report
    });

    test('an open ring carries nothing readable — nothing to flag', () async {
      final repo = LocalConstellationRepository();
      final seeded = await repo.seed(0.5, 0.5);
      expect(
        () => repo.report(seeded.meta.id, 'INAPPROPRIATE'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('The reading panel — SIGNALER CE POÈME (V3.51)', () {
    testWidgets('a live-ether reading offers the report, a kept relic '
        'does not', (tester) async {
      await _pumpReading(tester, reportable: true);
      await tester.ensureVisible(find.text('SIGNALER CE POÈME'));
      expect(find.text('SIGNALER CE POÈME'), findsOneWidget);
      // Close the reading before the next phase (the dialog is a
      // Scaffold too — an open one outlives a same-shape pumpWidget).
      await tester.tap(find.text('RETOURNER AU VIDE'));
      await tester.pumpAndSettle();

      await _pumpReading(tester, reportable: false);
      expect(find.text('SIGNALER CE POÈME'), findsNothing);
    });

    testWidgets('a reason crosses, the ether answers, one hand never '
        'flags twice', (tester) async {
      final repo = _RecordingRepo();
      await _pumpReading(tester, reportable: true, repo: repo);

      await tester.ensureVisible(find.text('SIGNALER CE POÈME'));
      await tester.tap(find.text('SIGNALER CE POÈME'));
      await tester.pumpAndSettle();
      // The dialog asks (its title wears the button's words — two
      // texts now) and offers every honest reason.
      expect(find.text('ANNULER'), findsOneWidget);
      expect(find.text('DANGER IMMÉDIAT'), findsOneWidget);

      await tester.tap(find.text('DANGER IMMÉDIAT'));
      await tester.pumpAndSettle();
      expect(repo.reports, [
        (id: 'figure-x', reason: 'DANGER'),
      ]);
      // A toast's law is its presence (a replacing HUD can double
      // the text during the swap — the count is not the contract).
      expect(find.text('SIGNALEMENT TRANSMIS AU GARDIEN.'), findsWidgets);

      // Let the toast die (it overlays the panel's foot — the second
      // attempt must tap the button, not the toast).
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // The second attempt is honest about the past.
      await tester.ensureVisible(find.text('SIGNALER CE POÈME'));
      await tester.tap(find.text('SIGNALER CE POÈME'));
      await tester.pumpAndSettle();
      expect(find.text('AUTRE MOTIF'), findsOneWidget);
      await tester.tap(find.text('AUTRE MOTIF'));
      await tester.pumpAndSettle();
      expect(find.text('TU AS DÉJÀ SIGNALÉ CE POÈME.'), findsWidgets);
    });

    test('the refusal grammar speaks the guard reasons', () {
      expect(
        reportRefusalMessage(
          const PostgrestException(message: 'KENOS_INVALID_STATE'),
        ),
        'RIEN N\'EST LISIBLE DANS CET ANNEAU.',
      );
      expect(
        reportRefusalMessage(
          const PostgrestException(message: 'KENOS_NOT_FOUND'),
        ),
        'CET ARTEFACT A RETOURNÉ AU VIDE.',
      );
      expect(
        reportRefusalMessage(
          const PostgrestException(message: 'KENOS_RATE_LIMIT'),
        ),
        'LE CIEL SOUFFLE — REVIENS DEMAIN.',
      );
      expect(
        reportRefusalMessage(const _NetworkGone()),
        'L\'ÉTHER EST INJOIGNABLE — LE CIEL GARDERA.',
      );
    });
  });
}

Future<void> _pumpReading(
  WidgetTester tester, {
  required bool reportable,
  ConstellationRepository? repo,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        constellationRepositoryProvider.overrideWithValue(
          repo ?? _RecordingRepo(),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    ),
  );
  await tester.pump();
  // The reading is a root-navigator dialog born from the screen above.
  // Its future ends only when the dialog closes — never awaited here.
  unawaited(showConstellationReading(
    tester.state(find.byType(Scaffold)).context,
    lines: const [
      AssembledLine(number: 1, text: 'une ligne d\'étranger'),
      AssembledLine(number: 2, text: 'une autre, scellée'),
    ],
    figureId: 'figure-x',
    reportable: reportable,
  ));
  await tester.pump(const Duration(milliseconds: 700));
}

/// Records what crossed; the law is ONE report per HAND per ARTIFACT
/// (the SQL PK is (constellation_id, reporter_id)) — a second reason
/// on an already-flagged poem changes nothing.
class _RecordingRepo implements ConstellationRepository {
  final _reportedIds = <String>{};
  final reports = <({String id, String reason})>[];

  @override
  Future<bool> report(String constellationId, String reasonCode) async {
    if (!_reportedIds.add(constellationId)) return false;
    reports.add((id: constellationId, reason: reasonCode));
    return true;
  }

  @override
  Future<bool?> hasContributed(String constellationId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A PostgREST-shaped refusal for the grammar test (the mapper reads
/// `toString()` like the other kenos mappers).
class _NetworkGone implements Exception {
  const _NetworkGone();
}
