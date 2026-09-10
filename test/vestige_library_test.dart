import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/data/artifact_memory.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/vestige.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/vestige_library_sheet.dart';

/// V3.30 — LA BIBLIOTHÈQUE DU VIDE: the reading mode. The whole
/// vestige field at once, every shard readable at its true place.
void main() {
  final vestiges = [
    const Vestige(
      id: 'lib-1',
      kind: 'quote',
      text: 'Le silence est un ami qui ne trahit jamais.',
      source: 'Confucius',
      offsetX: 0.3,
      offsetY: 0.3,
    ),
    const Vestige(
      id: 'lib-2',
      kind: 'etymology',
      text: 'ÉTHER — du grec aithêin, « brûler ».',
      source: 'grec ancien',
      offsetX: 0.7,
      offsetY: 0.6,
    ),
  ];

  testWidgets('la bibliothèque s\'ouvre et un éclat se lit sur place',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: OutlinedButton(
            onPressed: () => showVestigeLibrary(
              context,
              vestiges: vestiges,
              artifacts: ArtifactMemory(io: _MemIO()),
              eye: const Offset(0.5, 0.5),
            ),
            child: const Text('OUVRIR'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('OUVRIR'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('LA BIBLIOTHÈQUE DU VIDE'), findsOneWidget);
    expect(
      find.textContaining('TOUCHE UN ÉCLAT'),
      findsOneWidget,
    );

    // Tap the first shard's place, computed from the painter's own
    // letterboxed square — the same math the hit test uses. (The
    // dialog route paints its own full-screen CustomPaint first; the
    // field painter is the LAST one in the tree.)
    final box = tester.renderObject<RenderBox>(
      find.byType(CustomPaint).last,
    );
    final topLeft = box.localToGlobal(Offset.zero);
    final side = math.min(box.size.width, box.size.height);
    final origin = topLeft +
        Offset(
          (box.size.width - side) / 2,
          (box.size.height - side) / 2,
        );
    await tester.tapAt(origin + Offset(0.3 * side, 0.3 * side));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('CITATION'), findsOneWidget);
    expect(find.textContaining('ne trahit jamais'), findsOneWidget);
    expect(find.text('— Confucius'), findsOneWidget);

    await tester.tap(find.text('REPRENDRE LA DÉRIVE'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('— Confucius'), findsNothing,
        reason: 'la plaque cède la place au champ');
  });
}

class _MemIO implements ArtifactMemoryIO {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}
