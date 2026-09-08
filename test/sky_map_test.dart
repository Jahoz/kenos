import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/application/kenos_system.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/sky_map_sheet.dart';

/// V3.28 — LA CARTE DU CIEL: the organization told at a glance, and
/// every named body a departure.
void main() {
  testWidgets('la carte dit l\'organisation et ses trois lois', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: OutlinedButton(
            onPressed: () => showSkyMapSheet(
              context,
              eye: const Offset(0.5, 0.5),
              onTravel: (_) {},
            ),
            child: const Text('OUVRIR'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('OUVRIR'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('LA CARTE DU CIEL'), findsOneWidget);
    // The seven named bodies are departures.
    expect(find.text('LA LUNE'), findsOneWidget);
    expect(find.text('VÉNUS'), findsOneWidget);
    expect(find.text('POLARIS'), findsOneWidget);
    expect(find.text('PLUTON'), findsOneWidget);
    // The legend: the sky's three laws.
    expect(
      find.textContaining("l'intention qu'on leur confie"),
      findsOneWidget,
    );
    expect(
      find.textContaining('la culture ne tourne pas'),
      findsOneWidget,
    );
    expect(find.textContaining('des pensées portées'), findsOneWidget);
    expect(find.text('REFERMER'), findsOneWidget);
  });

  testWidgets('toucher Vénus referme la carte et fait voyager l\'œil',
      (tester) async {
    Offset? travelled;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: OutlinedButton(
            onPressed: () => showSkyMapSheet(
              context,
              eye: const Offset(0.2, 0.2),
              onTravel: (target) => travelled = target,
            ),
            child: const Text('OUVRIR'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('OUVRIR'));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('VÉNUS'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('LA CARTE DU CIEL'), findsNothing,
        reason: 'la carte se referme au départ');
    expect(travelled, isNotNull);
    // The departure is Vénus's LIVE position — her own lane (a hair
    // of clock drift: she rides ~0.002 world units per second).
    final venus = KenosSystem.planetPosition(1, DateTime.now());
    expect(travelled!.dx, closeTo(venus.dx, 0.002));
    expect(travelled!.dy, closeTo(venus.dy, 0.002));
  });
}
