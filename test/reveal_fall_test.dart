import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/application/accretion.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/reveal_sheet.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/domain/echo.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';

Echo _echo() => Echo(
      id: 'fall-test',
      coordX: 0.5,
      coordY: 0.5,
      coordZ: 0.9,
      theme: EchoColorTheme.teal,
      createdAt: DateTime.now(),
      text: 'texte de test',
    );

void main() {
  testWidgets('V3.86 — la chute sort avec le rideau, jamais dessous',
      (tester) async {
    // THE FALL PLAYS ON A CLEAR SKY: the celestial event rides OUT with
    // the pop verdict and the caller feeds the accretion once the
    // route's exit transition completes. The sheet itself never feeds —
    // fed from inside, the first 600 ms of the 1.9 s spiral died behind
    // the fading barrier and the fall read as never playing ("on ne
    // voit jamais l'animation vers le trou noir", the live report).
    late BuildContext sheetOpener;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                sheetOpener = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );

    final sheet = showRevealSheet(sheetOpener, echo: _echo());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700)); // entered

    // The reading window lapses, the panel dissolves, the fate moment
    // holds the sky — no mote may exist while the destiny is open.
    await tester.pump(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(accretionProvider), isEmpty,
        reason: 'rien ne tombe tant que le destin est ouvert');

    // V3.91 — the fate moment: the rail lives here now, never again
    // under the reading. Resting opens the trace offer.
    expect(find.text('RELANCER — UN AUTRE LA LIRA'), findsOneWidget);
    await tester.tap(find.text('REPOSER — LE LAISSER EN PAIX'));
    await tester.pump();
    expect(find.text('As-tu été touché ?'), findsOneWidget);
    expect(container.read(accretionProvider), isEmpty,
        reason: 'rien ne tombe tant que la demande de trace est ouverte');

    expect(find.text('REPARTIR SANS RIEN'), findsOneWidget);
    await tester.tap(find.text('REPARTIR SANS RIEN'));
    await tester.pump(); // the pop begins

    // MID-TRANSITION (300 of 600 ms): the curtain is still lifting —
    // the sheet must STILL not have fed the hole.
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(accretionProvider), isEmpty,
        reason: 'la chute attend le rideau entièrement levé');

    // The future resolves only when the exit transition completes, and
    // it carries the verdict the caller will feed.
    final verdict = await sheet;
    expect(verdict, RevealSkyEvent.fell,
        reason: 'la sortie porte la chute vers le gouffre');
  });

  testWidgets('V3.91 — le destin après la brûlure : la lecture ne porte plus le rail',
      (tester) async {
    late BuildContext sheetOpener;
    await tester.pumpWidget(
      ProviderScope(
        // The demo ether (bootstrap overridden): the rebound travels
        // the REAL repository path — demo parity is the law, and a
        // bare scope would only test the ether's refusal.
        overrides: [
          bootstrapProvider.overrideWithValue(
            const Bootstrap(supabaseConfigured: false, hasOnboarded: true),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                sheetOpener = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    final sheet = showRevealSheet(sheetOpener, echo: _echo());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700)); // entered

    // Reading is reading alone: the countdown speaks, the destiny
    // stays out of the panel.
    expect(find.text('DESTRUCTION IMMINENTE'), findsOneWidget);
    expect(find.text('RELANCER — UN AUTRE LA LIRA'), findsNothing,
        reason: 'le rail n\'a rien à faire sous la confidence');

    // The window lapses, the fate moment takes the sky.
    await tester.pump(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('son destin t\'appartient'), findsOneWidget);
    expect(find.text('RELANCER — UN AUTRE LA LIRA'), findsOneWidget);
    expect(find.text('REPOSER — LE LAISSER EN PAIX'), findsOneWidget);

    // RELANCER ends in the phoenix or the ether's refusal — either
    // way the sheet closes on its own, verdict honest.
    await tester.tap(find.text('RELANCER — UN AUTRE LA LIRA'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2)); // feedback window

    final verdict = await sheet;
    expect(
      verdict == RevealSkyEvent.rose || verdict == RevealSkyEvent.fell,
      isTrue,
      reason: 'phénix si l\'éther accepte, la chute honnête sinon — '
          'l\'echo a déjà brûlé, jamais le vide',
    );
  });
}
