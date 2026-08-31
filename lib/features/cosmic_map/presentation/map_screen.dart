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
import '../application/kenos_system.dart';
import '../application/map_controller.dart';
import '../application/motion_service.dart';
import '../application/reception_controller.dart';
import '../application/travel_camera.dart';
import 'widgets/awakening_sas.dart';
import 'widgets/background_painters.dart';
import 'widgets/mindful_hold_star.dart';
import 'widgets/origin_node.dart';
import 'widgets/system_painter.dart';

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
  /// The Awakening sas speaks once per session, after the first
  /// receptions sync — never again (silence is the default state).
  static bool _aubeSpokenThisSession = false;

  /// V3.7a — Le Voyage: the traveller's eye. Fixed zoom, the void
  /// follows the finger, drift accumulates in Années-Lumière.
  final TravelCamera _camera = TravelCamera();
  Timer? _glide;
  Size _viewport = Size.zero;

  /// Gesture bookkeeping: where it began, how far it carried. A
  /// release under the tap threshold is an intention, not a travel.
  Offset _lastPointerDown = Offset.zero;
  Offset _dragTotal = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(audioControllerProvider).ensureStarted());
    });
  }

  void _maybeSpeakAube() {
    if (_aubeSpokenThisSession || !mounted) return;
    final receptions =
        ref.read(receptionControllerProvider).valueOrNull;
    if (receptions == null) return; // still syncing: wait.
    _aubeSpokenThisSession = true;
    unawaited(maybeShowAwakening(context, ref));
  }

  @override
  void dispose() {
    _glide?.cancel();
    super.dispose();
  }

  /// The sky follows the finger: pan the void, travel the ether.
  void _onPanUpdate(DragUpdateDetails details) {
    _glide?.cancel();
    _dragTotal += details.delta;
    setState(() {
      _camera.panByScreen(details.delta, _viewport);
    });
  }

  /// Release: the void keeps a soft inertia (skipped under
  /// reduce-motion — the eye simply stops).
  void _onPanEnd(DragEndDetails details) {
    // A gesture that barely moved is an intention: tapping a planet
    // glides the eye toward its gravity. (A separate tap recognizer
    // would steal the pan arena — one detector, one grammar.)
    if (_dragTotal.distance < 8) {
      _dragTotal = Offset.zero;
      _onVoidTap();
      return;
    }
    _dragTotal = Offset.zero;
    if (context.wantsReducedMotion) {
      _refreshAfterTravel();
      return;
    }
    final velocity = Offset(
      details.velocity.pixelsPerSecond.dx,
      details.velocity.pixelsPerSecond.dy,
    );
    final worldPerSecond = Offset(
      velocity.dx / (_viewport.width) * _camera.viewExtent,
      velocity.dy / (_viewport.height) * _camera.viewExtent,
    );
    final path = DriftGlide().path(-worldPerSecond).toList();
    if (path.isEmpty) {
      _refreshAfterTravel();
      return;
    }
    var i = 0;
    _glide?.cancel();
    _glide = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (i >= path.length) {
        _glide?.cancel();
        _glide = null;
        _refreshAfterTravel();
        return;
      }
      setState(() => _camera.panByWorld(path[i++]));
    });
  }

  /// What the eye sees changed: ask the ether for this window.
  void _refreshAfterTravel() {
    final r = _camera.visibleRect;
    unawaited(
      ref.read(mapControllerProvider.notifier).refreshViewport(
            minX: r.minX,
            minY: r.minY,
            maxX: r.maxX,
            maxY: r.maxY,
          ),
    );
  }

  /// A tap on the void: a planet glides the eye toward its gravity —
  /// « voyager vers ». Tapping empty space travels nowhere (the drag
  /// is the road, the tap is the intention).
  void _onVoidTap() {
    final hit = planetHitTest(
      screenPoint: _lastPointerDown,
      camera: _camera,
      viewport: _viewport,
      now: DateTime.now(),
    );
    if (hit < 0) return;
    final target = KenosSystem.planetPosition(hit, DateTime.now());
    _glide?.cancel();
    setState(() {
      _camera.panByWorld(target - _camera.center);
    });
    _refreshAfterTravel();
  }

  /// RECALIBRER, travelled: return the eye to the heart of the ether.
  void _recenter() {
    _glide?.cancel();
    setState(() => _camera.recenter());
    _refreshAfterTravel();
  }

  @override
  Widget build(BuildContext context) {
    final echoes = ref.watch(mapControllerProvider);
    final reduced = context.wantsReducedMotion;
    final boot = ref.watch(bootstrapProvider);
    final count = echoes.valueOrNull?.length ?? 0;
    final signals =
        ref.watch(receptionControllerProvider).valueOrNull?.length ?? 0;

    // L'Aube: once the first sync settles, the sas may speak.
    ref.listen(receptionControllerProvider, (previous, next) {
      if (previous == null || !previous.hasValue) _maybeSpeakAube();
    });

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
            // The matter: the echoes — and the travelling eye.
            LayoutBuilder(
              builder: (context, constraints) {
                _viewport = Size(constraints.maxWidth, constraints.maxHeight);
                final epoch = DateTime.now();
                return GestureDetector(
                  // The sky follows the finger; holding a star keeps
                  // its own friction (a >28px drift cancels the hold
                  // and hands the gesture to the void). Tapping a
                  // planet glides the eye toward its gravity.
                  onPanDown: (d) => _lastPointerDown = d.globalPosition,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  behavior: HitTestBehavior.translucent,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // The heavens: black hole + planets, behind stars.
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: SystemPainter(
                            camera: _camera,
                            viewport: _viewport,
                            now: epoch,
                            reducedMotion: context.wantsReducedMotion,
                          ),
                        ),
                      ),
                      echoes.when(
                    data: (list) => list.isEmpty
                        ? const _CalmEther()
                        : _ParallaxStarLayer(
                            echoes: list,
                            camera: _camera,
                          ),
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
                  ],
                ),
                );
              },
            ),
            // Top HUD — machine typography. On narrow portraits the
            // controls wrap to their own row under the telemetry:
            // nothing ever overlaps, nothing ever overflows.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
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
                    const SizedBox(height: 6),
                    Text(
                      'DÉRIVE — ${_camera.driftLabel}',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 9,
                        letterSpacing: 3,
                        color: AppColors.fade(AppColors.cyan, 0.45),
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
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 2,
                      runSpacing: 0,
                      children: [
                        const _SoundToggle(),
                        TextButton(
                          onPressed: () => context.push('/frequencies'),
                          child: const Text('FRÉQUENCES'),
                        ),
                        TextButton(
                          onPressed: () => context.push('/impact'),
                          child: const Text('TON IMPACT'),
                        ),
                        TextButton(
                          onPressed: () {
                            _recenter();
                            ref.invalidate(mapControllerProvider);
                          },
                          child: const Text('RECALIBRER'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // The origin node: one's warm ember anchor, stardust
            // riding around it. Quiet impact, one tap away. On narrow
            // portraits it sits above the mirror gate — never under it.
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 22,
                  bottom: MediaQuery.sizeOf(context).width < 640 ? 118 : 44,
                ),
                child: const OriginNode(),
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
  const _ParallaxStarLayer({required this.echoes, required this.camera});

  final List<Echo> echoes;

  /// The traveller's eye: stars are placed in the WORLD, the camera
  /// decides which sky the screen holds.
  final TravelCamera camera;

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
            // V3.7b: an echo orbits the planet of its intent — the
            // server's raw launch point was only its birth place.
            final sp = widget.camera.worldToScreen(
              KenosSystem.echoPosition(echo, now),
              Size(w, h),
            );
            // Travel culling: only the visible sky carries widgets.
            if (sp.dx < -60 || sp.dx > w + 60 || sp.dy < -60 || sp.dy > h + 60) {
              continue;
            }
            final diameter = ParallaxMath.starDiameter(z);
            final hit = diameter + 26; // comfortable touch target
            final screenPos = sp;
            final baseX = screenPos.dx;
            final baseY = screenPos.dy;
            children.add(
              Positioned(
                key: ValueKey(echo.id),
                left: baseX - hit / 2,
                top: baseY - hit / 2,
                width: hit,
                height: hit,
                child: MindfulHoldStar(key: ValueKey('star-${echo.id}'), echo: echo, z: z),
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
