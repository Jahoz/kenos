import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/presentation/constellation_sheets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The prod wound, pinned: an OPEN ring the purge had already reaped
/// (or one closed elsewhere) still OFFERED its keyboard — the refusal
/// only fell at the send, as a shrug. The peek is now the door's
/// truth: a KENOS_* refusal kills the composer before a line is ever
/// typed; only an unreachable sky fails open.
void main() {
  testWidgets('anneau retourné au vide : la vérité avant le clavier',
      (tester) async {
    final repo = _RefusingRepo(
      peekError: const PostgrestException(message: 'KENOS_NOT_FOUND'),
    );
    await tester.pumpSheet(repo);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('CET ANNEAU A RETOURNÉ AU VIDE.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing,
        reason: 'jamais de clavier sur un anneau mort');
    expect(find.text('DONNER LA LIGNE'), findsNothing);
    expect(find.text('GARDER SON SILENCE'), findsNothing);

    await tester.tap(find.text('RETOURNER AU VIDE'));
    await tester.pumpAndSettle();
    expect(find.text('OPEN'), findsOneWidget,
        reason: 'la feuille se referme sur le vide');
    expect(repo.contributions, 0, reason: 'aucune ligne ne part vers un mort');
  });

  testWidgets('refermé entre-temps : la feuille le dit, sans clavier',
      (tester) async {
    final repo = _RefusingRepo(
      peekError: const PostgrestException(message: 'KENOS_CLOSED'),
    );
    await tester.pumpSheet(repo);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('LE POÈME S\'EST REFERMÉ AILLEURS.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(repo.contributions, 0);
  });

  testWidgets('clé morte de salon : la porte parle, pas le clavier',
      (tester) async {
    final repo = _RefusingRepo(peekError: const SalonKeyRefused());
    await tester.pumpSheet(repo);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('LE SALON N\'A PAS RECONNU TA CLÉ.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('éther injoignable au peek : l\'offre reste (fail-open)',
      (tester) async {
    final repo = _RefusingRepo(
      peekError: Exception('SocketException: the sky is far'),
    );
    await tester.pumpSheet(repo);
    await tester.pump(const Duration(milliseconds: 600));

    // Nothing was refused — the ether never answered. The composer
    // stays, exactly like hasContributed's own fail-open.
    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.text('TU OUVRES LE POÈME — LA PREMIÈRE LIGNE EST À TOI.'),
      findsOneWidget,
    );
  });
}

extension _PumpSheet on WidgetTester {
  /// Host (a ConsumerWidget gives the sheet a real WidgetRef) + open
  /// via the gate button; the dialog future stays pending while the
  /// sheet is up.
  Future<void> pumpSheet(ConstellationRepository repo) async {
    await pumpWidget(
      ProviderScope(
        overrides: [constellationRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: _SheetHost(),
        ),
      ),
    );
    await tap(find.text('OPEN'));
    await pump();
  }
}

class _SheetHost extends ConsumerWidget {
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
            kind: ConstellationKind.poem,
          ),
        ),
      ),
      child: const Text('OPEN'),
    );
  }
}

/// A repository whose door answers with one fixed truth at the peek.
class _RefusingRepo implements ConstellationRepository {
  _RefusingRepo({this.peekError});

  final Object? peekError;
  int contributions = 0;

  @override
  Future<bool> report(String constellationId, String reasonCode) async =>
      true;

  @override
  Future<String> reseedKey(String constellationId) async =>
      throw UnimplementedError();

  @override
  Future<ContributeResult> contribute({
    required String constellationId,
    required String text,
    String? inviteToken,
  }) async {
    contributions++;
    return ContributeResult(count: contributions);
  }

  @override
  Future<bool?> hasContributed(String id) async => null;

  @override
  Future<AssembledLine?> peekPrevious(
    String constellationId, {
    String? inviteToken,
  }) async {
    final e = peekError;
    if (e != null) throw e;
    return null;
  }

  @override
  Future<SeededConstellation> seed(
    double x,
    double y, {
    ConstellationKind kind = ConstellationKind.poem,
    bool invited = false,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<ConstellationMeta>> fetchVisible() async => const [];

  @override
  Future<List<AssembledLine>?> read(String id) async => null;

  @override
  Future<ConstellationMeta> fetchInvited(String token) async =>
      throw const SalonKeyRefused();
}
