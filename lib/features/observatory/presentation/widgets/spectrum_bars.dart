import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../domain/admin_metrics.dart';

/// The Spectre — the chosen window of the sky, as paired bars.
///
/// Teal rises when a thought is sown; indigo when one is read and
/// burns. Machine voice: Space Mono labels, hairline baseline, no
/// grid, no scale numbers — the shape tells the story.

/// The four breaths of the Spectre: which pair of daily counters the
/// bars carry. The layer's name rides the selector; its colors ride
/// the legend. Data colors only (teal/cyan/indigo/purple/ember) —
/// ROSE stays reserved for destruction, as everywhere.
enum SpectrumLayer {
  echoes('ÉCHOS', 'semés', AppColors.teal, 'lus', AppColors.indigo),
  breaths('SOUFFLES', 'renaissances', AppColors.cyan, 'traces', AppColors.ember),
  corpses('CADAVRES', 'semés', AppColors.purple, 'fermés', AppColors.indigo),
  travelers('VOYAGEURS', 'naissances', AppColors.ember, 'lecteurs', AppColors.teal);

  const SpectrumLayer(
    this.label,
    this.firstLabel,
    this.firstColor,
    this.secondLabel,
    this.secondColor,
  );

  final String label;
  final String firstLabel;
  final Color firstColor;
  final String secondLabel;
  final Color secondColor;

  /// The left bar of a day — what the first color counts.
  int first(DailyPoint day) => switch (this) {
    echoes => day.launched,
    breaths => day.rebound,
    corpses => day.corpsesSeeded,
    travelers => day.newUsers,
  };

  /// The right bar of a day — what the second color counts.
  int second(DailyPoint day) => switch (this) {
    echoes => day.consumed,
    breaths => day.traces,
    corpses => day.corpsesClosed,
    travelers => day.activeReaders,
  };
}

class SpectrumBars extends StatelessWidget {
  const SpectrumBars({
    super.key,
    required this.series,
    this.layer = SpectrumLayer.echoes,
    this.height = 130,
  });

  final List<DailyPoint> series;
  final SpectrumLayer layer;
  final double height;

  @override
  Widget build(BuildContext context) {
    final first = series.fold<int>(0, (a, d) => math.max(a, layer.first(d)));
    final second = series.fold<int>(0, (a, d) => math.max(a, layer.second(d)));
    return Semantics(
      container: true,
      label:
          'Spectre ${layer.label.toLowerCase()} sur ${series.length} jours : '
          'jusqu\'à $first ${layer.firstLabel} et $second ${layer.secondLabel} '
          'par jour.',
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _SpectrumPainter(series: series, layer: layer),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({required this.series, required this.layer});

  final List<DailyPoint> series;
  final SpectrumLayer layer;

  static const double _labelSpace = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // Label row + a breath of headroom so tall bars never kiss the
    // section above.
    final h = size.height - _labelSpace - 6;
    final n = series.length;
    if (n == 0 || w <= 0 || h <= 0) return;

    final baseline = Offset(0, h);
    canvas.drawLine(
      baseline,
      Offset(w, h),
      Paint()
        ..color = AppColors.hairlineStrong
        ..strokeWidth = 1,
    );

    var max = 1;
    for (final d in series) {
      max = math.max(max, math.max(layer.first(d), layer.second(d)));
    }

    final slot = w / n;
    final barW = math.max(1.0, slot * 0.26);
    final firstPaint = Paint()..color = AppColors.fade(layer.firstColor, 0.85);
    final secondPaint = Paint()
      ..color = AppColors.fade(layer.secondColor, 0.85);

    for (var i = 0; i < n; i++) {
      final cx = slot * (i + 0.5);
      final day = series[i];
      final firstN = layer.first(day);
      final secondN = layer.second(day);
      if (firstN > 0) {
        final barH = firstN / max * h;
        canvas.drawRect(
          Rect.fromLTWH(cx - barW - 1.0, h - barH, barW, barH),
          firstPaint,
        );
      }
      if (secondN > 0) {
        final barH = secondN / max * h;
        canvas.drawRect(Rect.fromLTWH(cx + 1.0, h - barH, barW, barH), secondPaint);
      }
    }

    // Date anchors: inset from the edges — never flush, never clipped.
    _label(
      canvas,
      _shortDay(series.first.day),
      Offset(4, h + 5),
      width: w / 3 - 4,
      align: TextAlign.left,
    );
    _label(
      canvas,
      _shortDay(series.last.day),
      Offset(w * 2 / 3, h + 5),
      width: w / 3 - 4,
      align: TextAlign.right,
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at, {
    required double width,
    required TextAlign align,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 8,
          letterSpacing: 1,
          color: AppColors.fade(AppColors.pureLight, 0.4),
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    tp.paint(canvas, at);
  }

  String _shortDay(String iso) {
    if (iso.length != 10) return iso;
    return iso.substring(5); // MM-DD
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      // The series list is rebuilt only when the ledger reloads; every
      // rebuild of the same metrics reuses the identical instance.
      !identical(old.series, series) || old.layer != layer;
}
