import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/domain/note_phrase.dart';
import 'package:kenos/features/constellations/presentation/constellation_sheets.dart';
import 'package:kenos/features/create_echo/presentation/mirror_screen.dart';

/// The void gives nothing to the void: an empty echo — written, sung,
/// or whitespace — never leaves the device. Every send path is pinned
/// here: the Mirror's seal, the poem's line, the song's phrase.
void main() {
  late FakeConstellationRepository repo;

  setUp(() {
    repo = FakeConstellationRepository();
  });

  OutlinedButton buttonOf(WidgetTester tester, String label) =>
      tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label));

  Finder buttonOfFinder(WidgetTester tester, String label) =>
      find.widgetWithText(OutlinedButton, label);

  testWidgets('Miroir : texte vide ou blanc → SCELLER & LANCER mort',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MirrorScreen())),
    );
    await tester.pump();

    // Autofocus gives the field text '' — the button is born dead.
    expect(buttonOf(tester, 'SCELLER & LANCER').onPressed, isNull,
        reason: 'rien à sceller');

    // Whitespace is still nothing.
    await tester.enterText(find.byType(TextField), '   \n\t  ');
    await tester.pump();
    expect(buttonOf(tester, 'SCELLER & LANCER').onPressed, isNull,
        reason: 'le blanc n\'est pas une confidence');

    // One true character revives it.
    await tester.enterText(find.byType(TextField), 'je');
    await tester.pump();
    expect(buttonOf(tester, 'SCELLER & LANCER').onPressed, isNotNull);
  });

  testWidgets('Cadavre poème : ligne vide ou blanche → DONNER LA LIGNE mort',
      (tester) async {
    await tester.pumpSheet(repo, ConstellationKind.poem);
    await tester.pump(const Duration(milliseconds: 600));

    expect(buttonOf(tester, 'DONNER LA LIGNE').onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(buttonOf(tester, 'DONNER LA LIGNE').onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'une vraie ligne');
    await tester.pump();
    expect(buttonOf(tester, 'DONNER LA LIGNE').onPressed, isNotNull);
  });

  testWidgets('Cadavre chanson : aucune note → DONNER LA PHRASE mort',
      (tester) async {
    await tester.pumpSheet(repo, ConstellationKind.melody);
    await tester.pump(const Duration(milliseconds: 600));

    // A song with no notes is silence, not a phrase.
    expect(buttonOf(tester, 'DONNER LA PHRASE').onPressed, isNull);

    // One note on the composer pad revives it.
    final pad = find.textContaining('LA HAUTEUR EST LA NOTE');
    await tester.tapAt(tester.getCenter(pad));
    await tester.pump();
    expect(buttonOf(tester, 'DONNER LA PHRASE').onPressed, isNotNull);
  });

  testWidgets(
      'Compositeur précis : haut = cristallin, bas = grave, à la position exacte',
      (tester) async {
    await tester.pumpSheet(repo, ConstellationKind.melody);
    await tester.pump(const Duration(milliseconds: 600));

    final padRect = tester.getRect(find.byKey(const Key('song_composer_pad')));
    // Top edge = the highest note of the scale; bottom = the lowest.
    // (The first version divided by the PANEL's height — every note
    // landed off-pitch. This pins the pad's own geometry.)
    await tester.tapAt(Offset(padRect.center.dx, padRect.top + 2));
    await tester.pump();
    await tester.tapAt(Offset(padRect.center.dx, padRect.bottom - 2));
    await tester.pump();

    expect(buttonOf(tester, 'DONNER LA PHRASE').onPressed, isNotNull);
    await tester.tap(buttonOfFinder(tester, 'DONNER LA PHRASE'));
    await tester.pump();
    // The ack SnackBar must fully expire before the test ends (its
    // dismissal timer starts once its entry animation settled).
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));

    // The phrase sealed to the ether carries the exact notes.
    expect(repo.lines, hasLength(1));
    final phrase = NotePhrase.tryParse(repo.lines.single);
    expect(phrase, isNotNull);
    expect(phrase!.notes.first, greaterThan(15),
        reason: 'le haut du pad est cristallin');
    expect(phrase.notes.last, lessThan(4), reason: 'le bas du pad est grave');
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
        child: MaterialApp(
          home: _SheetHost(kind: kind),
        ),
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
    String? inviteToken,
  }) async {
    lines.add(text);
    return ContributeResult(count: lines.length);
  }

  @override
  Future<bool?> hasContributed(String id) async => null;

  @override
  Future<AssembledLine?> peekPrevious(
    String constellationId, {
    String? inviteToken,
  }) async => null;

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
