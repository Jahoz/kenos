import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/echo/data/sector_grid.dart';
import 'package:kenos/features/echo/domain/echo.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';

Echo _echo(String id, double x, double y, DateTime createdAt) => Echo(
      id: id,
      coordX: x,
      coordY: y,
      coordZ: 0.5,
      theme: EchoColorTheme.teal,
      createdAt: createdAt,
    );

void main() {
  final base = DateTime(2026, 8, 31, 12);

  group('SectorGrid (culling par secteur)', () {
    test('un secteur dense est plafonné aux plus récents', () {
      final echoes = List.generate(
        100,
        (i) => _echo('e$i', 0.01, 0.01, base.subtract(Duration(minutes: i))),
      );
      final kept = SectorGrid.cull(echoes);
      expect(kept.length, SectorGrid.maxPerSector);
      // Newest first: the most recent echo is kept.
      expect(kept.first.id, 'e0');
      expect(kept.map((e) => e.id), isNot(contains('e99')));
    });

    test('des secteurs calmes ne sont pas affamés par un secteur dense', () {
      final echoes = [
        ...List.generate(
          50,
          (i) => _echo('dense$i', 0.01, 0.01, base.subtract(Duration(minutes: i))),
        ),
        _echo('lointain', 0.9, 0.9, base.subtract(const Duration(hours: 5))),
      ];
      final kept = SectorGrid.cull(echoes);
      expect(kept.map((e) => e.id), contains('lointain'));
    });

    test('le total est plafonné à maxTotal', () {
      final echoes = [
        for (var sx = 0; sx < SectorGrid.sectorsPerAxis; sx++)
          for (var sy = 0; sy < SectorGrid.sectorsPerAxis; sy++)
            ...List.generate(
              SectorGrid.maxPerSector,
              (i) => _echo(
                's${sx}_$sy _$i',
                (sx + 0.5) / SectorGrid.sectorsPerAxis,
                (sy + 0.5) / SectorGrid.sectorsPerAxis,
                base.subtract(Duration(minutes: i)),
              ),
            ),
      ];
      // 64 sectors × 24 = 1536 candidates → capped at 400, newest first.
      final kept = SectorGrid.cull(echoes);
      expect(kept.length, SectorGrid.maxTotal);
    });

    test('coord 1.0 reste dans la grille (dernier secteur)', () {
      expect(SectorGrid.sectorIndexOf(1.0), SectorGrid.sectorsPerAxis - 1);
      expect(SectorGrid.sectorIndexOf(0.0), 0);
      expect(SectorGrid.sectorIndexOf(0.5), 4);
    });

    // Mirrors rpc.sql 'sector columns floor': the same boundaries must
    // bin identically in SQL and Dart — demo parity depends on it.
    test('frontières de demi-cellule identiques au SQL (floor, pas arrondi)', () {
      // (0.0626 * 8) = 0.5008 → floor 0 (a float→int cast would give 1).
      expect(SectorGrid.sectorIndexOf(0.0626), 0);
      // (0.9376 * 8) = 7.5008 → floor 7 (a naive cast would give 8).
      expect(SectorGrid.sectorIndexOf(0.9376), 7);
      // Exact cell edges change sector exactly at k / 8.
      expect(SectorGrid.sectorIndexOf(0.1249999), 0);
      expect(SectorGrid.sectorIndexOf(0.125), 1);
    });

    test('une liste petite n\'est pas modifiée en ordre', () {
      final echoes = [
        _echo('a', 0.3, 0.3, base),
        _echo('b', 0.7, 0.7, base.subtract(const Duration(minutes: 1))),
      ];
      final kept = SectorGrid.cull(echoes);
      expect(kept.length, 2);
      expect(kept.first.id, 'a'); // newest first
    });
  });
}
