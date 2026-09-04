import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/admin_metrics.dart';

/// The Grille des secteurs — the 8×8 sky grid as an indigo heat map.
///
/// Where the map culls (24 per sector), the guardian sees the pressure:
/// each cell's warmth is its star count. A shape, never a star.
class SectorGrid extends StatelessWidget {
  const SectorGrid({super.key, required this.sectors});

  final List<SectorCell> sectors;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{
      for (final c in sectors)
        if (c.x >= 0 && c.x < 8 && c.y >= 0 && c.y < 8)
          '${c.x},${c.y}': c.count,
    };
    final max = counts.values.fold<int>(1, math.max);

    return Semantics(
      container: true,
      label:
          'Grille des secteurs : le secteur le plus dense porte '
          '${counts.values.fold(0, math.max)} échos.',
      child: AspectRatio(
        aspectRatio: 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var y = 0; y < 8; y++)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var x = 0; x < 8; x++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(0.75),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.fade(
                                AppColors.indigo,
                                _warmth(counts['$x,$y'] ?? 0, max),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 0 stars: near-invisible; a full sector: bright indigo. Above the
  /// 24-star culling cap the cell saturates — pressure reads instantly.
  double _warmth(int n, int max) {
    if (n == 0) return 0.04;
    final t = n / math.max(max, 1);
    return (0.14 + 0.66 * t).clamp(0.14, 0.85);
  }
}
