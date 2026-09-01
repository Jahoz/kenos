import 'dart:math' as math;
import 'dart:ui';

/// V3.11b — the emergent figure of an Exquisite Corpse.
///
/// Every contributed line becomes a star at the next golden-angle
/// station around the seed: the constellation DRAWS ITSELF as strangers
/// write, without anyone seeing the whole. The placement is pure
/// arithmetic on the line index — deterministic, so every client in
/// the ether sees the exact same figure for the same count.
class ConstellationFigure {
  ConstellationFigure._();

  /// The golden angle, in radians (~137.507°): the irrational step that
  /// spreads seeds without ever repeating a direction.
  static const double goldenAngle = 2 * math.pi * 0.38196601125010515;

  /// Star k's direction-and-radius, in unit-figure space (center 0,0;
  /// radius ≤ 1). k = 0 is the innermost station; the figure grows
  /// outward as it fills.
  static Offset starAt(int k, {required int target}) {
    final t = math.max(target, 2);
    final kk = k.clamp(0, t - 1);
    final radius = 0.42 + 0.58 * kk / (t - 1);
    final angle = kk * goldenAngle - math.pi / 2;
    return Offset(radius * math.cos(angle), radius * math.sin(angle));
  }

  /// The figure's stations for a corpse of [lineCount] lines drawn so
  /// far out of [target]: filled stars, hollow stations, and the faint
  /// segments linking consecutive drawn stars (what the strangers drew).
  static List<Offset> drawnStars(int lineCount, {required int target}) => [
        for (var k = 0; k < math.min(lineCount, target); k++)
          starAt(k, target: target),
      ];
}
