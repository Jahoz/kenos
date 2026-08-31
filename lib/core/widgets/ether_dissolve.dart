import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Real-particle dissolution field — the roadmap's custom-shader widget.
///
/// One particle per grid cell, GPU-driven (fragment shader
/// `shaders/ether_dissolve.frag`): staggered liftoff, radial dispersion
/// with a curl, embers brighter than dust. When the shader program is
/// unavailable (exotic platform, test environment), a CPU painter draws
/// the same particle field — the dissolution never falls back to a mere
/// fade.
///
/// Accessibility: callers skip this widget entirely when the user asked
/// to reduce animations.
class EtherDissolve extends StatefulWidget {
  const EtherDissolve({
    super.key,
    required this.progress,
    required this.color,
    this.seed = 0.0,
    this.cellPx = 16,
  });

  /// 0 → 1 dissolution.
  final double progress;

  /// Star hue of the dissolving echo (its theme halo).
  final Color color;

  /// Per-echo randomness (derive from the echo id).
  final double seed;

  /// Grid cell size in logical pixels — the dust density.
  final double cellPx;

  @override
  State<EtherDissolve> createState() => _EtherDissolveState();
}

class _EtherDissolveState extends State<EtherDissolve> {
  static ui.FragmentProgram? _program;
  static Future<void>? _loading;

  static Future<void> _ensureProgram() {
    return _loading ??= () async {
      try {
        _program = await ui.FragmentProgram.fromAsset(
          'shaders/ether_dissolve.frag',
        );
      } catch (e) {
        // Not fatal: the CPU painter takes over, the ether still dissolves.
        debugPrint('[kenos.shader] ether_dissolve unavailable: $e');
      }
    }();
  }

  @override
  void initState() {
    super.initState();
    _ensureProgram().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.progress;
    if (v <= 0.0 || v >= 1.0) return const SizedBox.shrink();
    final program = _program;
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: program == null
            ? _CpuDissolvePainter(widget)
            : _ShaderDissolvePainter(program.fragmentShader(), widget),
      ),
    );
  }
}

/// GPU path.
class _ShaderDissolvePainter extends CustomPainter {
  _ShaderDissolvePainter(this.shader, this.widget);

  final ui.FragmentShader shader;
  final EtherDissolve widget;

  @override
  bool shouldRepaint(_ShaderDissolvePainter old) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final c = widget.color;
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, widget.progress.clamp(0.0, 1.0));
    shader.setFloat(3, widget.seed);
    shader.setFloat(4, c.r);
    shader.setFloat(5, c.g);
    shader.setFloat(6, c.b);
    shader.setFloat(7, c.a);
    shader.setFloat(8, widget.cellPx);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.srcOver,
    );
  }
}

/// CPU fallback — same particle math, one drawCircle per mote.
class _CpuDissolvePainter extends CustomPainter {
  _CpuDissolvePainter(this.widget);

  final EtherDissolve widget;

  @override
  bool shouldRepaint(_CpuDissolvePainter old) => true;

  static double _hash(int ix, int iy, double seed) {
    var h = (ix * 374761393 + iy * 668265263 + (seed * 1e6).round() * 69069) &
        0x3fffffff;
    h = ((h >> 13) ^ h) * 1274126177 & 0x3fffffff;
    return ((h >> 16) & 0x3fffffff) / 1073741823.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final v = widget.progress.clamp(0.0, 1.0);
    final materialize = (v / 0.12).clamp(0.0, 1.0);
    if (materialize <= 0) return;

    final cell = widget.cellPx;
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    final c = widget.color;
    final ember = Colors.white.withValues(alpha: c.a);

    final paint = Paint()..isAntiAlias = true;
    for (var ix = 0; ix < cols; ix++) {
      for (var iy = 0; iy < rows; iy++) {
        final r1 = _hash(ix, iy, widget.seed);
        final r2 = _hash(ix + 1717, iy + 931, widget.seed);
        final r3 = _hash(ix + 377, iy + 4113, widget.seed);

        final t = ((v - r3 * 0.45) / 0.55).clamp(0.0, 1.0);
        if (t >= 1.0) continue;

        final cx = (ix + 0.5) * cell;
        final cy = (iy + 0.5) * cell;
        var dx = cx / size.width - 0.5;
        var dy = cy / size.height - 0.5;
        final len = math.max(1e-4, math.sqrt(dx * dx + dy * dy));
        dx /= len;
        dy /= len;
        final drift = t * t * (0.3 + r2) * size.shortestSide * 0.35;

        final px = cx + (dx - dy * (r1 - 0.5) * 0.7) * drift;
        final py = cy + (dy + dx * (r1 - 0.5) * 0.7 - 0.4 * drift) * 1.0;

        final radius = (0.5 + r2 * 1.2) * (1 - 0.55 * t);
        final alpha =
            math.pow(1 - t, 1.6).toDouble() * materialize * c.a;
        if (alpha < 0.02) continue;

        paint.color = (r1 > 0.94 ? ember : c).withValues(alpha: alpha);
        canvas.drawCircle(Offset(px, py), radius, paint);
      }
    }
  }
}
