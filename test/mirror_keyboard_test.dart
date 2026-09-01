import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/create_echo/presentation/mirror_screen.dart';

void main() {
  testWidgets('Miroir portrait : le champ reste visible clavier ouvert', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: MirrorScreen()));
    await tester.pump();

    final field = find.byType(TextField);
    expect(field, findsOneWidget);

    // The keyboard opens (viewInsets bottom = half the screen).
    tester.view.viewInsets = const FakeViewPadding(bottom: 420);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The field must STILL be on screen and hit-testable.
    final rect = tester.getRect(field);
    final size = tester.view.physicalSize;
    expect(rect.top, greaterThanOrEqualTo(0), reason: 'le champ déborde en haut');
    expect(rect.bottom, lessThanOrEqualTo(size.height), reason: 'le champ sous le clavier');
    expect(rect.height, greaterThan(80), reason: 'fenêtre de frappe illisible');
  });
}
