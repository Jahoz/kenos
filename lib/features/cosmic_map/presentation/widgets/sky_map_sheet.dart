import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/utils/parallax_math.dart';
import '../../application/celestial_bodies.dart';
import '../../application/kenos_system.dart';

/// V3.28 — LA CARTE DU CIEL: the organization, told at a glance.
///
/// The sky is a place with laws — echoes orbit the intent they were
/// confided to, culture rests where it washed ashore, comets cross
/// everything — but none of it was legible while travelling. This
/// schematic overlay draws the whole system to scale in the [0,1]
/// world: the void's heart and its exclusion, the two anchor lanes
/// with their live positions, the three echo shells, the beacon, the
/// wanderers' far ring, the resting field, and the traveller's own
/// eye with its reception radius. Every named body is touchable:
/// the sheet closes and the camera glides to its live position.
Future<void> showSkyMapSheet(
  BuildContext context, {
  required Offset eye,
  required void Function(Offset worldTarget) onTravel,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'KENOS_CARTE_DU_CIEL',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 450),
    useRootNavigator: true,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _SkyMapPanel(eye: eye, onTravel: onTravel),
      );
    },
  );
}

class _SkyMapPanel extends StatelessWidget {
  const _SkyMapPanel({required this.eye, required this.onTravel});

  final Offset eye;
  final void Function(Offset worldTarget) onTravel;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Dialog(
      backgroundColor: AppColors.voidBlack,
      // V3.28b — the live phone report: the default 40 px insets
      // starved a narrow portrait; the sky map takes the room it
      // needs, and scrolls when even that is not enough.
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.fade(AppColors.pureLight, 0.18)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20),
          // Scrollable: the diagram + seven departures + the legend
          // exceed a small portrait viewport — nothing may overflow.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'LA CARTE DU CIEL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    letterSpacing: 4,
                    color: AppColors.fade(AppColors.cyan, 0.85),
                  ),
                ),
                const SizedBox(height: 16),
                _SkyMapDiagram(
                  eye: eye,
                  now: now,
                  onTravel: (t) => _travel(context, t),
                ),
                const SizedBox(height: 12),
                Text(
                  'TOUCHE UN CORPS — LA CAMÉRA VOYAGERA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 7.5,
                    letterSpacing: 2,
                    color: AppColors.fade(AppColors.pureLight, 0.35),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (final (i, body) in celestialBodies.indexed)
                      TextButton(
                        onPressed: () => _travel(
                          context,
                          KenosSystem.planetPosition(i, DateTime.now()),
                        ),
                        child: Text(
                          body.name.toUpperCase(),
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 8,
                            letterSpacing: 2,
                            color: AppColors.fade(
                              body.theme?.halo ?? AppColors.teal,
                              0.8,
                            ),
                          ),
                        ),
                      ),
                    for (final (i, body) in celestialWanderers.indexed)
                      TextButton(
                        onPressed: () => _travel(
                          context,
                          CelestialMath.wandererPosition(i, DateTime.now()),
                        ),
                        child: Text(
                          body.name.toUpperCase(),
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 8,
                            letterSpacing: 2,
                            color: AppColors.fade(AppColors.pureLight, 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'les échos orbitent l\'intention qu\'on leur confie\n'
                  'les vestiges reposent — la culture ne tourne pas\n'
                  'les comètes traversent tout : des pensées portées',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 11.5,
                    height: 1.8,
                    color: AppColors.fade(AppColors.pureLight, 0.5),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  child: const Text('REFERMER'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _travel(BuildContext context, Offset worldTarget) {
    Navigator.of(context, rootNavigator: true).pop();
    onTravel(worldTarget);
  }
}

/// The schematic itself: the whole [0,1] sky at true scale, painted
/// quietly. Named bodies carry generous hit zones (0.07 world).
class _SkyMapDiagram extends StatelessWidget {
  const _SkyMapDiagram({
    required this.eye,
    required this.now,
    required this.onTravel,
  });

  final Offset eye;
  final DateTime now;
  final void Function(Offset worldTarget) onTravel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return GestureDetector(
          onTapUp: (details) {
            final p = Offset(
              details.localPosition.dx / size,
              details.localPosition.dy / size,
            );
            // Anchors and the beacon first (they own the lanes), then
            // the wanderers — generous zones, fat fingers at dusk.
            for (var i = 0; i < KenosSystem.planets.length; i++) {
              final target = KenosSystem.planetPosition(i, now);
              if ((p - target).distance < 0.07) return _hit(target);
            }
            for (var i = 0; i < celestialWanderers.length; i++) {
              final target = CelestialMath.wandererPosition(i, now);
              if ((p - target).distance < 0.07) return _hit(target);
            }
          },
          child: CustomPaint(
            size: Size.square(size),
            painter: _SkyMapPainter(eye: eye, now: now),
          ),
        );
      },
    );
  }

  void _hit(Offset worldTarget) => onTravel(worldTarget);
}

class _SkyMapPainter extends CustomPainter {
  _SkyMapPainter({required this.eye, required this.now});

  final Offset eye;
  final DateTime now;

  static const _label = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 7,
    letterSpacing: 1.5,
    color: Color(0x66F4F4F6),
  );

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint) {
    const segments = 56;
    for (var i = 0; i < segments; i += 2) {
      final a0 = 2 * math.pi * i / segments;
      final a1 = 2 * math.pi * (i + 1) / segments;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a0,
        a1 - a0,
        false,
        paint,
      );
    }
  }

  void _labelAt(Canvas canvas, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: _label),
    )..layout();
    tp.paint(canvas, at + const Offset(5, -3));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset w(Offset p) => Offset(p.dx * s, p.dy * s);
    final hole = w(KenosSystem.blackHole);

    // The resting field: culture washed ashore, deterministic scatter
    // that never touches the heart (a schematic of the vestige sea).
    final rng = _StableHash(104729);
    final field = Paint()..color = AppColors.fade(AppColors.pureLight, 0.10);
    for (var i = 0; i < 34; i++) {
      final p = Offset(0.06 + rng.next() * 0.88, 0.06 + rng.next() * 0.88);
      if ((p - KenosSystem.blackHole).distance <
          KenosSystem.blackHoleExclusion + 0.03) {
        continue;
      }
      canvas.drawCircle(w(p), 1.2, field);
    }

    // The two anchor lanes + their live positions and echo shells.
    for (var i = 0; i < 2; i++) {
      final theme = KenosSystem.planets[i];
      final lane = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = AppColors.fade(theme.halo, 0.22);
      _dashedCircle(canvas, hole, KenosSystem.orbitRadiusOf(i) * s, lane);

      final p = w(KenosSystem.planetPosition(i, now));
      final shells = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = AppColors.fade(theme.halo, 0.13);
      for (final shell in KenosSystem.echoShells) {
        canvas.drawCircle(p, shell * s, shells);
      }
      canvas.drawCircle(p, 3.2, Paint()..color = theme.core);
      _labelAt(canvas, celestialBodies[i].name.toUpperCase(), p);
    }

    // The beacon: fixed, north corner.
    final polaris = w(CelestialMath.polaris);
    canvas.drawCircle(
      polaris,
      2.6,
      Paint()..color = KenosSystem.planets[2].core,
    );
    _labelAt(canvas, 'POLARIS', polaris);

    // The wanderers' far country: three slow rings, four named dots.
    final wander = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.fade(AppColors.pureLight, 0.10);
    for (var i = 0; i < celestialWanderers.length; i++) {
      _dashedCircle(canvas, hole, (0.55 + 0.05 * (i % 3)) * s, wander);
      final p = w(CelestialMath.wandererPosition(i, now));
      canvas.drawCircle(
        p,
        2.0,
        Paint()..color = AppColors.fade(AppColors.pureLight, 0.55),
      );
    }

    // The heart: darker than the void, its exclusion told.
    canvas.drawCircle(
      hole,
      KenosSystem.blackHoleExclusion * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = AppColors.fade(AppColors.rose, 0.30),
    );
    canvas.drawCircle(hole, 4.5, Paint()..color = AppColors.voidBlackDeep);
    canvas.drawCircle(
      hole,
      4.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.fade(AppColors.rose, 0.55),
    );

    // The traveller's eye and its reception field.
    final e = w(eye);
    canvas.drawCircle(
      e,
      ParallaxMath.receptionRadius * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.fade(AppColors.cyan, 0.45),
    );
    canvas.drawCircle(e, 2.4, Paint()..color = AppColors.cyan);
  }

  @override
  bool shouldRepaint(_SkyMapPainter old) =>
      old.eye != eye || now.difference(old.now).inMinutes != 0;
}

/// Deterministic pseudo-random for the schematic's resting field.
class _StableHash {
  _StableHash(int seed) : _state = seed % 2147483647;
  int _state;

  double next() {
    _state = (_state * 48271) % 2147483647;
    return _state / 2147483647;
  }
}
