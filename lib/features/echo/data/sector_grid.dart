import '../domain/echo.dart';

/// Map culling — the 8×8 sector grid shared by the backend RPC
/// (`fetch_map_sector`) and the demo repository, so both modes keep
/// identical semantics: a dense neighborhood must never starve a calm one.
class SectorGrid {
  SectorGrid._();

  static const int sectorsPerAxis = 8;
  static const int maxPerSector = 24;
  static const int maxTotal = 400;

  /// Client-side budget for a VIEWPORT fetch (the first gaze and every
  /// travel sync): the screen paints stars, not a catalogue — the rest
  /// of the ether is discovered by travelling. The backend hard cap
  /// ([maxTotal]) stays the safety ceiling, untouched.
  static const int viewBudget = 180;

  static int sectorIndexOf(double coord) {
    final raw = (coord * sectorsPerAxis).floor();
    // coord 1.0 is legal and belongs to the last sector.
    return raw < sectorsPerAxis ? raw : sectorsPerAxis - 1;
  }

  /// Keeps the newest [maxPerSector] echoes per sector, capped at
  /// [maxTotal] overall (newest first) — mirrors the SQL window function.
  static List<Echo> cull(List<Echo> echoes, {int? maxTotal}) {
    final ceiling = maxTotal ?? SectorGrid.maxTotal;
    final sorted = echoes.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final perSector = <int, int>{};
    final kept = <Echo>[];
    for (final echo in sorted) {
      if (kept.length >= ceiling) break;
      final sector =
          sectorIndexOf(echo.coordX) * sectorsPerAxis + sectorIndexOf(echo.coordY);
      final count = perSector[sector] ?? 0;
      if (count >= maxPerSector) continue;
      perSector[sector] = count + 1;
      kept.add(echo);
    }
    return kept;
  }
}
