import 'dart:math' as math;
import 'dart:ui';

/// V3.11b — the emergent figure of an Exquisite Corpse.
///
/// Every contributed line becomes a star at the next golden-angle
/// station around the seed: the constellation DRAWS ITSELF as strangers
/// write, without anyone seeing the whole.
///
/// The corpse's identity signs the figure: its id is hashed (FNV-1a,
/// stable across platforms and runs — Dart's own hashCode is
/// process-seeded and must never shape the sky) into a rotation, a
/// spin direction and an inner radius. Deterministic, so every client
/// in the ether sees the exact same figure for the same corpse — but
/// two corpses never share a sky: before the signature, target ranges
/// 4..7 meant the whole ether drew four shapes, over and over.
class ConstellationFigure {
  ConstellationFigure._();

  /// The golden angle, in radians (~137.507°): the irrational step that
  /// spreads seeds without ever repeating a direction.
  static const double goldenAngle = 2 * math.pi * 0.38196601125010515;

  /// FNV-1a over the id's code units — small, fast, and stable
  /// everywhere. Web-safe by construction: the full FNV product would
  /// exceed 2^53 (Dart web ints are doubles), so the multiply is
  /// split into 16-bit halves and every intermediate stays exactly
  /// representable on every platform. The same corpse always hashes
  /// to the same sky.
  static int _signature(String id) {
    var h = 186522613; // FNV offset basis, 31-bit domain
    for (final cu in id.codeUnits) {
      h ^= cu;
      final xl = h & 0xffff;
      final xh = h >> 16;
      h = (((xh * 0x01000193) & 0x7fffffff) * 65536 + xl * 0x01000193) &
          0x7fffffff;
    }
    return h;
  }

  /// Star k's direction-and-radius, in unit-figure space (center 0,0;
  /// radius ≤ 1). k = 0 is the innermost station; the figure grows
  /// outward as it fills. The corpse's [id] rotates the spiral, spins
  /// it clockwise or counter-clockwise, and sets how tight the first
  /// ring hugs the seed.
  static Offset starAt(int k, {required int target, required String id}) {
    final t = math.max(target, 2);
    final kk = k.clamp(0, t - 1);
    final h = _signature(id);
    final rotation = 2 * math.pi * (h % 10007) / 10007;
    final spin = h.isEven ? 1.0 : -1.0;
    final inner = 0.36 + 0.16 * ((h >> 8) % 1000) / 999;
    final radius = inner + (1 - inner) * kk / (t - 1);
    final angle = rotation + spin * kk * goldenAngle;
    return Offset(radius * math.cos(angle), radius * math.sin(angle));
  }

  /// The figure's stations for a corpse of [lineCount] lines drawn so
  /// far out of [target]: filled stars, hollow stations, and the faint
  /// segments linking consecutive drawn stars (what the strangers drew).
  static List<Offset> drawnStars(
    int lineCount, {
    required int target,
    required String id,
  }) => [
        for (var k = 0; k < math.min(lineCount, target); k++)
          starAt(k, target: target, id: id),
      ];
}
