import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../domain/admin_metrics.dart';

/// The Spectre — thirty days of the sky, as paired bars.
///
/// Teal rises when a thought is sown; indigo when one is read and
/// burns. Machine voice: Space Mono labels, hairline baseline, no
/// grid, no scale numbers — the shape tells the story.
class SpectrumBars extends StatelessWidget {
  const SpectrumBars({super.key, required this.series, this.height = 130});

  final List<DailyPoint> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    final launched = series.fold<int>(0, (a, d) => math.max(a, d.launched));
    final consumed = series.fold<int>(0, (a, d) => math.max(a, d.consumed));
    return Semantics(
      container: true,
      label:
          'Spectre sur ${series.length} jours : '
          'jusqu\'à $launched échos semés et $consumed lus par jour.',
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _SpectrumPainter(series: series),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({required this.series});

  final List<DailyPoint> series;

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
      max = math.max(max, math.max(d.launched, d.consumed));
    }

    final slot = w / n;
    final barW = math.max(1.0, slot * 0.26);
    final teal = Paint()..color = AppColors.fade(AppColors.teal, 0.85);
    final indigo = Paint()..color = AppColors.fade(AppColors.indigo, 0.85);

    for (var i = 0; i < n; i++) {
      final cx = slot * (i + 0.5);
      final day = series[i];
      if (day.launched > 0) {
        final barH = day.launched / max * h;
        canvas.drawRect(
          Rect.fromLTWH(cx - barW - 1.0, h - barH, barW, barH),
          teal,
        );
      }
      if (day.consumed > 0) {
        final barH = day.consumed / max * h;
        canvas.drawRect(Rect.fromLTWH(cx + 1.0, h - barH, barW, barH), indigo);
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
      !identical(old.series, series);
}
