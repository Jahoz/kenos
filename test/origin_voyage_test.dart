import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/reveal_sheet.dart';
import 'package:kenos/features/echo/domain/echo.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';

/// V3.26 — l'origine et le voyage: the interception tells the story.
/// The shore's name (opt-in, author's choice), the drift, and how far
/// from the reader's own eye the light was launched.
Echo _echo({String origin = '', DateTime? createdAt}) => Echo(
      id: 'voyage-test',
      coordX: 0.2,
      coordY: 0.2,
      coordZ: 0.9,
      theme: EchoColorTheme.teal,
      createdAt: createdAt ?? DateTime.now(),
      text: 'une confidence nomade',
      origin: origin,
    );

Future<void> _open(WidgetTester tester, Echo echo, {double? eye}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: RevealPanel(echo: echo, eyeDistanceAL: eye)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

/// The panel arms its burn window with delayed futures: drain the
/// timeline so no timer outlives the test.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 20));
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  group('V3.26 — le voyage conté à l\'interception', () {
    testWidgets('un écho nommé dit son rivage, sa dérive, sa distance',
        (tester) async {
      await _open(
        tester,
        _echo(
          origin: 'FRANCE · AUVERGNE-RHÔNE-ALPES · LYON',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        eye: 0.42,
      );

      expect(
        find.textContaining('PARTI DE FRANCE'),
        findsOneWidget,
        reason: 'le rivage choisi par l\'auteur est révélé au gagnant',
      );
      expect(
        find.textContaining('DÉRIVÉ PENDANT 3 H'),
        findsOneWidget,
        reason: 'la dérive compte pour le lecteur aussi',
      );
      expect(
        find.textContaining('LANCÉ À 0.42 A.L. DE TON ŒIL'),
        findsOneWidget,
        reason: 'la distance de lancement à l\'œil, devise de la carte',
      );
      await _drain(tester);
    });

    testWidgets('un écho anonyme reste anonyme — pas de rivage inventé',
        (tester) async {
      await _open(tester, _echo(createdAt: DateTime.now()));
      expect(find.textContaining('PARTI DE'), findsNothing);
      expect(find.textContaining('DÉRIVÉ PENDANT'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('une interception à portée de main tait la distance',
        (tester) async {
      await _open(
        tester,
        _echo(origin: 'SENEGAL · DAKAR'),
        eye: 0.005,
      );
      expect(find.textContaining('LANCÉ À'), findsNothing,
          reason: 'pris sur place : le voyage se tait');
      expect(find.textContaining('PARTI DE SENEGAL'), findsOneWidget);
      await _drain(tester);
    });
  });
}
