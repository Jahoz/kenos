import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kenos/core/widgets/scramble_text.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/reception_sheet.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/echo_repository.dart';
import 'package:kenos/features/echo/domain/echo.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';
import 'package:kenos/features/echo/domain/reception.dart';

/// The reception sheet, author side (audit 2026-09-23 — the file sat
/// at 0% coverage): the signal's journey is told honestly, the trace
/// deciphers once, and BRÛLER LE SIGNAL burns it through the
/// controller — one look, then the void.
void main() {
  Echo ownEcho() => Echo(
        id: 'own-1',
        coordX: 0.5,
        coordY: 0.5,
        coordZ: 0.7,
        theme: EchoColorTheme.teal,
        createdAt: DateTime.now().subtract(const Duration(hours: 27)),
        isMine: true,
      );

  Reception signal({String? reply}) => Reception(
        echoId: 'own-1',
        readAt: DateTime.now(),
        driftSeconds: 94440, // 26 H 14 MIN — ~189 UA at the void's speed
        reply: reply,
      );

  Future<void> open(
    WidgetTester tester, {
    Reception? reception,
    EchoRepository? repo,
  }) async {
    // Portrait phone surface: the sheet's column is sized for one.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (repo != null)
            echoRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          // The sheet's burn path reads the reception CONTROLLER —
          // watching it here lets its build settle before any burn.
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: OutlinedButton(
                  onPressed: () => showReceptionSheet(
                    context,
                    echo: ownEcho(),
                    reception: reception,
                  ),
                  child: const Text('OUVRIR'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OUVRIR'));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('un signal lu : le voyage est dit, la trace déchiffre',
      (tester) async {
    await open(tester, reception: signal(reply: 'Lu. Porté. Merci.'));

    expect(find.text('TON ÉCHO A ÉTÉ LU'), findsOneWidget);
    expect(find.textContaining('DÉRIVÉ PENDANT 26 H 14 MIN'), findsOneWidget);
    expect(find.textContaining('DISTANCE PARCOURUE ≈ 189 UA'), findsOneWidget);
    expect(find.text('TRACE — LECTURE UNIQUE'), findsOneWidget);

    // The trace scrambles in, then resolves.
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Lu. Porté. Merci.'), findsOneWidget);

    // Burning is offered — the signal exists once.
    expect(find.text('BRÛLER LE SIGNAL'), findsOneWidget);
  });

  testWidgets('sans réponse du lecteur, le silence est aussi une réponse',
      (tester) async {
    await open(tester, reception: signal());

    expect(find.text('TON ÉCHO A ÉTÉ LU'), findsOneWidget);
    expect(find.textContaining('Aucune trace'), findsOneWidget);
    expect(find.byType(ScrambleText), findsNothing,
        reason: 'aucune trace à déchiffrer');
  });

  testWidgets('le signal brûle : le contrôleur le consomme, le rideau tombe',
      (tester) async {
    final repo = _FakeEchoRepository([signal(reply: 'merci')]);
    await open(tester, reception: signal(reply: 'merci'), repo: repo);

    await tester.tap(find.text('BRÛLER LE SIGNAL'));
    await tester.pump(); // the burn crosses the controller
    await tester.pump(const Duration(seconds: 1)); // the dissolve (900 ms)
    await tester.pump(); // the pop lands
    await tester.pump(const Duration(milliseconds: 700)); // the curtain

    expect(repo.burned, ['own-1'],
        reason: 'voir = brûler : la réception est consommée');
    expect(find.text('BRÛLER LE SIGNAL'), findsNothing,
        reason: 'le rideau est tombé, la feuille est fermée');
  });

  testWidgets('un écho encore à la dérive n\'offre que le retour au vide',
      (tester) async {
    await open(tester);

    expect(find.text('TON ÉCHO DÉRIVE ENCORE'), findsOneWidget);
    expect(find.textContaining('Personne ne l\'a lu'), findsOneWidget);
    expect(find.text('BRÛLER LE SIGNAL'), findsNothing);
    expect(find.text('REVENIR AU VIDE'), findsOneWidget);
  });
}

/// The ether, as far as the sheet needs it: unseen receptions in,
/// burns recorded out.
class _FakeEchoRepository implements EchoRepository {
  _FakeEchoRepository(this.unseen);

  final List<Reception> unseen;
  final List<String> burned = [];

  @override
  Future<void> burnReception(String echoId) async => burned.add(echoId);

  @override
  Future<List<Reception>> fetchReceptions() async =>
      unseen.where((r) => !r.seen).toList();

  @override
  Stream<void> receptionChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
