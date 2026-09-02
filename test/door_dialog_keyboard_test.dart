import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/create_echo/presentation/mirror_screen.dart';

final Finder mirrorField = find.byType(TextField).first;
final Finder dialogField = find.descendant(
  of: find.byType(Dialog),
  matching: find.byType(TextField),
);

Future<void> openMirror(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: MirrorScreen())),
  );
  await tester.pump();
}

/// v3.10b — the web editing host is unique: the Mirror must tear down
/// its connection before the door dialog opens, and the door must be
/// parsed from COMMITTED editing state only. These tests pin the
/// contract that stopped doors from being silently dropped on send.
void main() {
  const spotifyLink =
      'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT?si=abc123';

  testWidgets('le Miroir cède l\'hôte d\'édition au dialogue de porte',
      (tester) async {
    await openMirror(tester);

    // Sanity: the Mirror's field holds the editing connection at rest.
    await tester.tap(mirrorField);
    await tester.pump();
    final mirrorNode = tester.widget<TextField>(mirrorField).focusNode;
    expect(FocusManager.instance.primaryFocus, same(mirrorNode),
        reason: 'le champ du Miroir tient le focus au repos');

    await tester.ensureVisible(find.byIcon(Icons.link));
    await tester.tap(find.byIcon(Icons.link));
    await tester.pumpAndSettle();

    // v3.10b: exactly ONE live editing connection — the dialog's.
    expect(dialogField, findsOneWidget);
    expect(mirrorNode?.hasFocus, isFalse,
        reason: "le Miroir ne doit plus tenir l'hôte d'édition");
    final dialogNode = tester.widget<TextField>(dialogField).focusNode;
    expect(dialogNode?.hasFocus, isTrue,
        reason: "le dialogue est l'unique hôte d'édition ouvert");
  });

  testWidgets('la porte se scelle depuis l\'état committé, le texte du Miroir intact',
      (tester) async {
    await openMirror(tester);

    await tester.enterText(mirrorField, 'une confidence intime');
    await tester.ensureVisible(find.byIcon(Icons.link));
    await tester.tap(find.byIcon(Icons.link));
    await tester.pumpAndSettle();

    await tester.enterText(dialogField, spotifyLink);
    // The button commits the editing state (one frame) BEFORE parsing.
    await tester.tap(find.text('SCELLER LA PORTE'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing, reason: 'le dialogue est refermé');
    expect(find.text('EXTRAIT MUSICAL'), findsOneWidget,
        reason: 'la porte est attachée');
    expect(
      tester.widget<TextField>(mirrorField).controller?.text,
      'une confidence intime',
      reason: "le texte du Miroir ne doit jamais être contaminé par le dialogue",
    );
  });

  testWidgets('un lien invalide ne scelle rien — le HUD le dit, pas de porte',
      (tester) async {
    await openMirror(tester);

    await tester.enterText(mirrorField, 'une confidence intime');
    await tester.ensureVisible(find.byIcon(Icons.link));
    await tester.tap(find.byIcon(Icons.link));
    await tester.pumpAndSettle();

    await tester.enterText(dialogField, 'https://example.com/track/abc');
    await tester.tap(find.text('SCELLER LA PORTE'));
    // Bounded pumps: a full pumpAndSettle can race the snackbar's own
    // dismissal timer and flake (seen once in CI-like conditions).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CE LIEN N\'EST NI SPOTIFY NI YOUTUBE.'), findsOneWidget);
    expect(find.text('EXTRAIT MUSICAL'), findsNothing);
    // And the Mirror's text survived the failed attempt.
    expect(
      tester.widget<TextField>(mirrorField).controller?.text,
      'une confidence intime',
    );
  });
}
