import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/audio_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/haptics/kenos_haptics.dart';
import '../../../core/utils/motion_preferences.dart';
import '../../../core/utils/parallax_math.dart';
import '../../echo/data/echo_providers.dart';
import '../../echo/domain/echo.dart';
import '../application/map_controller.dart';
import '../application/motion_service.dart';
import '../application/reception_controller.dart';
import 'widgets/background_painters.dart';
import 'widgets/mindful_hold_star.dart';

/// The stellar map: KENOS public space.
/// No lists, no scrolling — a three-dimensional Stack where the void dominates.
///
/// Performance contract: only the leaf layers ([_AmbientBackground],
/// [_ParallaxStarLayer]) watch the tilt stream — the HUD and the screen
/// itself never rebuild at sensor rate.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioControllerProvider).ensureStarted();
    });
  }

  @override
  Widget build(BuildContext context) {
    final echoes = ref.watch(mapControllerProvider);
    final reduced = context.wantsReducedMotion;
    final boot = ref.watch(bootstrapProvider);
    final count = echoes.valueOrNull?.length ?? 0;
    final signals =
        ref.watch(receptionControllerProvider).valueOrNull?.length ?? 0;

    // A new signal lands: the device feels it (single informative
    // pulse, kept even under reduce-motion).
    ref.listen<int>(
      receptionControllerProvider.select(
        (receptions) => receptions.valueOrNull?.length ?? 0,
      ),
      (previous, next) {
        if ((previous ?? 0) < next) {
          KenosHaptics.pulse(KenosPulse.signal, reduceMotion: reduced);
        }
      },
    );

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      // First gesture anywhere = audio unlock (iOS autoplay policy).
      body: Listener(
        onPointerDown: (_) => unawaited(
          ref.read(audioControllerProvider).ensureStarted(),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Spatial void + diffuse nebulae + dead star field (scenery).
            const _AmbientBackground(),
            // The matter: the echoes.
            echoes.when(
              data: (list) =>
                  list.isEmpty ? const _CalmEther() : _ParallaxStarLayer(echoes: list),
              loading: () => const _Centered(
                'CALIBRATION DE L\'ÉTHER…',
                color: AppColors.teal,
              ),
              error: (e, _) => _UnreachableEther(
                onRetry: () {
                  ref.invalidate(sessionReadyProvider);
                  ref.invalidate(mapControllerProvider);
                },
              ),
            ),
            // Top HUD — machine typography.
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KENOS // ${boot.supabaseConfigured ? 'LIAISON ÉTABIE' : 'MODE DÉMO LOCAL'}',
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 9,
                          letterSpacing: 3,
                          color: AppColors.fade(AppColors.cyan, 0.55),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$count ÉCHOS EN ORBITE',
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 9,
                          letterSpacing: 3,
                          color: AppColors.fade(AppColors.pureLight, 0.4),
                        ),
                      ),
                      if (signals > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          signals == 1
                              ? '1 SIGNAL REÇU — TOUCHE TON ÉTOILE'
                              : '$signals SIGNAUX REÇUS — TOUCHE TES ÉTOILES',
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 9,
                            letterSpacing: 3,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Top-right controls.
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 16, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _SoundToggle(),
                      TextButton(
                        onPressed: () => context.push('/impact'),
                        child: const Text('TON IMPACT'),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(mapControllerProvider),
                        child: const Text('RECALIBRER'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Mirror gate.
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 30),
                child: _AnimatedEchoButton(
                  onPressed: () => context.push('/mirror'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scenery layer: nebulae + dead star field.
///
/// The twinkle ticks at ~8 fps through a plain timer — scenery must
/// breathe without repainting at display rate (a sanctuary app owes
/// the battery some silence). Frozen entirely under reduce-motion.
class _AmbientBackground extends ConsumerStatefulWidget {
  const _AmbientBackground();

  @override
  ConsumerState<_AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends ConsumerState<_AmbientBackground> {
  static const _tick = Duration(milliseconds: 125);

  double _time = 0;
  Timer? _twinkle;

  @override
  void initState() {
    super.initState();
    if (!platformDisablesAnimations()) {
      _twinkle = Timer.periodic(_tick, (_) {
        if (mounted) setState(() => _time += _tick.inMilliseconds / 1000);
      });
    }
  }

  @override
  void dispose() {
    _twinkle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ambient parallax calms down (×0.15) but stays alive: the ether is
    // not a screenshot.
    final motionScale = context.wantsReducedMotion ? 0.15 : 1.0;
    final tilt = ref.watch(tiltProvider).valueOrNull ?? Tilt.zero;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: NebulaPainter(
              tiltX: tilt.x * 0.5 * motionScale,
              tiltY: tilt.y * 0.5 * motionScale,
              time: _time,
            ),
          ),
          CustomPaint(
            painter: BackgroundStarFieldPainter(
              time: _time,
              tiltX: tilt.x * motionScale,
              tiltY: tilt.y * motionScale,
            ),
          ),
        ],
      ),
    );
  }
}

/// Positions echoes in space: normalized coordinates, parallax
/// proportional to depth, close buckets painted last.
///
/// Stars are grouped in depth buckets; the whole bucket translates with
/// the tilt (one Transform per bucket) instead of rewriting every star's
/// position at sensor rate. Distant buckets share one blur layer instead
/// of one saveLayer per star.
class _ParallaxStarLayer extends ConsumerStatefulWidget {
  const _ParallaxStarLayer({required this.echoes});

  final List<Echo> echoes;

  @override
  ConsumerState<_ParallaxStarLayer> createState() =>
      _ParallaxStarLayerState();
}

class _ParallaxStarLayerState extends ConsumerState<_ParallaxStarLayer> {
  /// Far → near. The last edge breathes past 1.0 so z = 1 lands inside.
  static const _bucketEdges = [0.05, 0.30, 0.55, 0.80, 1.001];

  @override
  Widget build(BuildContext context) {
    // Ambient parallax calms down (×0.15) under reduce-motion.
    final motionScale = context.wantsReducedMotion ? 0.15 : 1.0;
    final tilt = ref.watch(tiltProvider).valueOrNull ?? Tilt.zero;
    final now = DateTime.now();

    final sorted = widget.echoes.toList()
      ..sort((a, b) => a.resolveZ(now).compareTo(b.resolveZ(now)));

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final layers = <Widget>[];

        for (var b = 0; b < _bucketEdges.length - 1; b++) {
          final children = <Widget>[];
          for (final echo in sorted) {
            final z = echo.resolveZ(now);
            if (z < _bucketEdges[b] || z >= _bucketEdges[b + 1]) continue;
            final diameter = ParallaxMath.starDiameter(z);
            final hit = diameter + 26; // comfortable touch target
            final baseX =
                ParallaxMath.clamp(echo.coordX * w, hit / 2, w - hit / 2);
            final baseY =
                ParallaxMath.clamp(echo.coordY * h, hit / 2, h - hit / 2);
            children.add(
              Positioned(
                left: baseX - hit / 2,
                top: baseY - hit / 2,
                width: hit,
                height: hit,
                child: MindfulHoldStar(echo: echo, z: z),
              ),
            );
          }
          if (children.isEmpty) continue;

          final bucketZ =
              (_bucketEdges[b] + _bucketEdges[b + 1].clamp(0.0, 1.0)) / 2;
          Widget layer = Stack(children: children);
          final sigma = ParallaxMath.blurSigma(bucketZ);
          if (sigma > 0.05) {
            layer = ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
              child: layer,
            );
          }
          layers.add(
            Transform.translate(
              offset: Offset(
                ParallaxMath.offsetPixels(
                  tilt: tilt.x * motionScale,
                  z: bucketZ,
                  amplitude: 46,
                ),
                ParallaxMath.offsetPixels(
                  tilt: tilt.y * motionScale,
                  z: bucketZ,
                  amplitude: 32,
                ),
              ),
              child: layer,
            ),
          );
        }

        return Stack(fit: StackFit.expand, children: layers);
      },
    );
  }
}

class _CalmEther extends StatefulWidget {
  const _CalmEther();

  @override
  State<_CalmEther> createState() => _CalmEtherState();
}

class _CalmEtherState extends State<_CalmEther> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (!platformDisablesAnimations()) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated breathing glow
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final opacity = 0.3 + (_controller.value * 0.3);
              final scale = 0.95 + (_controller.value * 0.1);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.fade(AppColors.cyan, opacity * 0.5),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final opacity = 0.5 + (_controller.value * 0.2);
              return Opacity(
                opacity: opacity,
                child: Text(
                  'L\'ÉTHER EST CALME.',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    letterSpacing: 4,
                    color: AppColors.fade(AppColors.pureLight, 1.0),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'RESPIRE.',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 9,
              letterSpacing: 3,
              color: AppColors.fade(AppColors.teal, 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreachableEther extends StatelessWidget {
  const _UnreachableEther({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Centered('L\'ÉTHER EST INJOIGNABLE.', color: AppColors.rose),
          const SizedBox(height: 18),
          TextButton(onPressed: onRetry, child: const Text('RECALIBRER')),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered(this.message, {required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10,
          letterSpacing: 4,
          color: AppColors.fade(color, 0.6),
        ),
      ),
    );
  }
}

class _AnimatedEchoButton extends StatefulWidget {
  const _AnimatedEchoButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_AnimatedEchoButton> createState() => _AnimatedEchoButtonState();
}

class _AnimatedEchoButtonState extends State<_AnimatedEchoButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    if (!platformDisablesAnimations()) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final pulse = 0.95 + (_controller.value * 0.1);
            final glow = _controller.value * 0.4;
            return Transform.scale(
              scale: pulse,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.fade(AppColors.pureLight, 0.5 + (glow * 0.3)),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.fade(AppColors.cyan, glow * 0.3),
                      blurRadius: 12 + (glow * 8),
                      spreadRadius: glow * 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    'FORMULER UN ÉCHO',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 9,
                      letterSpacing: 2,
                      color: AppColors.fade(AppColors.pureLight, 0.7 + (glow * 0.3)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SoundToggle extends ConsumerStatefulWidget {
  const _SoundToggle();

  @override
  ConsumerState<_SoundToggle> createState() => _SoundToggleState();
}

class _SoundToggleState extends ConsumerState<_SoundToggle> {
  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioControllerProvider);
    return TextButton(
      onPressed: () async {
        await audio.toggleMute();
        if (mounted) setState(() {});
      },
      child: Text(audio.isMuted ? 'SON ─ OFF' : 'SON ─ ON'),
    );
  }
}
