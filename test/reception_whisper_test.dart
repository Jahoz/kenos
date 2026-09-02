import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/mindful_hold_star.dart';
import 'package:kenos/features/echo/domain/echo.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';

/// The reception field teaches itself ONCE: the first press on a star
/// beyond the field whispers "TROP LOIN. RAPPROCHE-TOI." — the second
/// stays silent (friction explained once is guidance, twice is noise).
void main() {
  setUp(() {
    MindfulHoldStar.farWhisperSpoken = false;
  });

  Widget harness({required double reception}) {
    final echo = Echo(
      id: 'far-star',
      coordX: 0.5,
      coordY: 0.5,
      coordZ: 0.8,
      theme: EchoColorTheme.teal,
      createdAt: DateTime.now(),
    );
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: MindfulHoldStar(echo: echo, z: 0.8, reception: reception),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> press(WidgetTester tester) async {
    final gesture = await tester.startGesture(tester.getCenter(find.byType(MindfulHoldStar)));
    await gesture.up();
    // Let the snackbar's ENTRY animation complete — its 4 s dismissal
    // timer only starts once the entry has settled.
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  testWidgets('au loin : un whisper, puis le silence', (tester) async {
    await tester.pumpWidget(harness(reception: 0));
    await tester.pump();

    await press(tester);
    expect(find.text('TROP LOIN. RAPPROCHE-TOI.'), findsOneWidget);
    expect(MindfulHoldStar.farWhisperSpoken, isTrue);

    // The snackbar expires (4 s after its entry settled) and leaves.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('TROP LOIN. RAPPROCHE-TOI.'), findsNothing);
    await press(tester);
    await tester.pump();
    expect(find.text('TROP LOIN. RAPPROCHE-TOI.'), findsNothing);
  });

  testWidgets("à portée : pas de whisper, le hold s'arme", (tester) async {
    await tester.pumpWidget(harness(reception: 1));
    await tester.pump();

    await press(tester);
    expect(find.text('TROP LOIN. RAPPROCHE-TOI.'), findsNothing);
    expect(MindfulHoldStar.farWhisperSpoken, isFalse);
  });
}
