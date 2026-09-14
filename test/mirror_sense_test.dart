import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/create_echo/presentation/mirror_screen.dart';

/// V3.42 — THE SENSE OF THE MIRROR: the capabilities are seen in one
/// first look. The intention pills come BEFORE the editor, the editor
/// is BOUNDED (it used to be Expanded and ate the whole screen), the
/// attachments show as real ＋ chips, and everything — intention,
/// editor, attachments, seal — lives inside a phone's first screen.
void main() {
  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MirrorScreen())),
    );
    await tester.pump();
  }

  testWidgets('le bon ordre : intention → éditeur → attaches → sceau',
      (tester) async {
    await boot(tester);

    final intention = tester.getTopLeft(find.text('APAISER'));
    final editor = tester.getTopLeft(find.byType(TextField));
    final porte = tester.getTopLeft(find.text('PORTE'));
    final seal = tester.getTopLeft(
      find.widgetWithText(OutlinedButton, 'SCELLER & LANCER'),
    );

    expect(intention.dy, lessThan(editor.dy),
        reason: 'l\'intention se choisit AVANT d\'écrire');
    expect(editor.dy, lessThan(porte.dy),
        reason: 'les attaches se proposent après la confidence');
    expect(porte.dy, lessThan(seal.dy),
        reason: 'le sceau vient en dernier');
  });

  testWidgets('tout tient dans le premier écran — rien ne se découvre en scrollant',
      (tester) async {
    await boot(tester);

    for (final probe in [
      find.text('APAISER'),
      find.text('ÉCLAIRER'),
      find.text('PORTE'),
      find.text('＋'),
    ]) {
      expect(probe.evaluate(), isNotEmpty);
      expect(tester.getRect(probe.first).bottom, lessThan(844),
          reason: 'visible sans scroller');
    }
    final seal = tester.getRect(
      find.widgetWithText(OutlinedButton, 'SCELLER & LANCER'),
    );
    expect(seal.bottom, lessThan(844),
        reason: 'le sceau lui-même est du premier regard');
  });

  testWidgets('les attaches se proposent par trois ＋, l\'éditeur reste borné',
      (tester) async {
    await boot(tester);

    expect(find.text('＋'), findsNWidgets(3),
        reason: 'IMAGE, SON et PORTE portent chacune leur plus visible');
    final editor = tester.getRect(find.byType(TextField));
    expect(editor.height, lessThan(300),
        reason: "l'éditeur ne mange plus l'écran");
    expect(editor.height, greaterThan(100),
        reason: 'mais la confidence a de la place');
  });

  testWidgets('V3.43 — le compositeur large : le secret à gauche, les choix à droite',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MirrorScreen())),
    );
    await tester.pump();

    // The secret owns the LEFT column, tall; the choices and the seal
    // stand to its right.
    final editor = tester.getRect(find.byType(TextField));
    final intention = tester.getRect(find.text('APAISER'));
    final seal = tester.getRect(
      find.widgetWithText(OutlinedButton, 'SCELLER & LANCER'),
    );
    expect(editor.left, lessThan(intention.left),
        reason: 'la confidence est la colonne dominante');
    expect(seal.left, greaterThan(editor.right),
        reason: 'le sceau vit dans la colonne des choix');
    expect(editor.height, greaterThan(300),
        reason: 'en large, la confidence a de la chambre');
    expect(editor.width, greaterThan(400),
        reason: 'le compositeur ÉCHAPPE au cap téléphone de 560 — '
            'deux colonnes étriquées dans une bande centrée, c\'est '
            'ce que la disposition large venait corriger (V3.43b)');

    // Everything still holds in ONE first look — nothing scrolls.
    for (final probe in [
      find.text('PORTE'),
      find.text('＋'),
      find.text('APAISER'),
    ]) {
      expect(probe.evaluate(), isNotEmpty);
      expect(tester.getRect(probe.first).bottom, lessThan(800),
          reason: 'visible sans scroller, même en compositeur');
    }
  });

  testWidgets('V3.43c — une fenêtre Retina 955×480 garde la colonne honnête',
      (tester) async {
    // The composer is for GENUINELY wide windows: at this laptop-ish
    // Retina size it fired edge-to-edge and its tall editor pushed
    // the seal below the fold. The single column — the constellation
    // screen's own disposition — serves instead.
    tester.view.physicalSize = const Size(955, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MirrorScreen())),
    );
    await tester.pump();

    final editor = tester.getRect(find.byType(TextField));
    final intention = tester.getRect(find.text('APAISER'));
    // Stacked, not side by side.
    expect(intention.bottom, lessThan(editor.top),
        reason: 'la colonne honnête : l\'intention au-dessus de l\'éditeur');
    // And CENTERED — never pinned to the left edge (the Aube's old
    // bug, resurrected by the V3.42 refactor, caught by Hugo's eye).
    final title = tester.getRect(find.text('La formulation du vide'));
    expect((title.center.dx - 955 / 2).abs(), lessThan(40),
        reason: 'la colonne se tient au centre de la fenêtre');
    // The seal stays REACHABLE — one gesture brings it home (the
    // column scrolls, exactly like the constellation screen's own).
    final seal = find.widgetWithText(OutlinedButton, 'SCELLER & LANCER');
    await tester.ensureVisible(seal);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(seal).bottom, lessThan(480),
        reason: 'un geste amène le sceau — jamais noyé');
  });
}
