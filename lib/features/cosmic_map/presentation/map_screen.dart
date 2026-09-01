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
import '../../constellations/data/constellation_repository.dart';
import '../../constellations/presentation/constellation_sheets.dart';
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
import 'widgets/vestige.dart';

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

  /// The Vestiges: curated culture drifting in the void (V3.9).
  List<Vestige> _vestiges = const [];

  /// The one line that matters: signals first (they pulse), then the
  /// readable ether, then the mode.
  String _hudHeadline({required int readable, required int signals}) {
    if (signals > 0) {
      return signals == 1
          ? '1 SIGNAL — KENOS'
          : '$signals SIGNAUX — KENOS';
    }
    return '$readable ÉCHOS — $_bootLabel';
  }

  String get _bootLabel =>
      ref.read(bootstrapProvider).supabaseConfigured ? 'LIAISON' : 'DÉMO';

  /// The quiet second line: drift + sealed + vestiges, joined by
  /// breath marks — presence, never urgency.
  String get _readableSilent {
    final parts = <String>['DÉRIVE ${_camera.driftLabel}'];
    final sealedCount =
        (ref.read(mapControllerProvider).valueOrNull ?? const <Echo>[])
            .where((e) => e.isMine)
            .length;
    if (sealedCount > 0) parts.add('$sealedCount SCELLÉES');
    final unreadVestiges = _vestiges.where((v) => !v.isRead).length;
    if (unreadVestiges > 0) parts.add('$unreadVestiges VESTIGES');
    return parts.join(' · ');
  }

  /// The Constellations: exquisite corpses drifting in the void (V3.8).
  List<ConstellationMeta> _constellations = const [];

  /// V3.7a — Le Voyage: the traveller's eye. Fixed zoom, the void
  /// follows the finger, drift accumulates in Années-Lumière.
  final TravelCamera _camera = TravelCamera();
  Timer? _glide;
  Size _viewport = Size.zero;

  /// Gesture bookkeeping: where it began, how far it carried, how
  /// much it pinched. A release with neither travel nor zoom is an
  /// intention (a tap); a pinch that stays put still zooms.
  Offset _lastPointerDown = Offset.zero;
  Offset _dragTotal = Offset.zero;
  double _pinchFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _loadVestiges();
    _loadConstellations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(audioControllerProvider).ensureStarted());
    });
  }

  Future<void> _loadVestiges() async {
    final vestiges = await loadVestiges();
    if (mounted) setState(() => _vestiges = vestiges);
  }

  Future<void> _loadConstellations() async {
    try {
      final repo = ref.read(constellationRepositoryProvider);
      final visible = await repo.fetchVisible();
      if (mounted) setState(() => _constellations = visible);
    } catch (e) {
      debugPrint('[kenos.constellations] unreachable: $e');
    }
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

  /// The sky follows the fingers: one finger travels, two fingers
  /// also zoom (the point between them stays anchored under the
  /// pinch — clustered stars can be separated to be held).
  void _onScaleStart(ScaleStartDetails details) {
    _glide?.cancel();
    _lastPointerDown = details.focalPoint;
    _dragTotal = Offset.zero;
    _pinchFactor = 1.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (details.pointerCount >= 2 && details.scale != 1.0) {
        _camera.zoomBy(
          details.scale / _pinchFactor,
          _screenToWorld(details.focalPoint),
        );
        _pinchFactor = details.scale;
      }
      _dragTotal += details.focalPointDelta;
      _camera.panByScreen(details.focalPointDelta, _viewport);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Neither travelled nor zoomed: an intention — a planet glides the
    // eye toward its gravity. (One detector, one grammar.)
    if (_dragTotal.distance < 8 && ( _pinchFactor - 1.0 ).abs() < 0.03) {
      _onVoidTap();
      return;
    }
    if (context.wantsReducedMotion) {
      _refreshAfterTravel();
      return;
    }
    final velocity = details.velocity.pixelsPerSecond;
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

  /// Screen point → world point (for anchoring the pinch).
  Offset _screenToWorld(Offset screen) => Offset(
        (screen.dx - _viewport.width / 2) /
            _viewport.width *
            _camera.viewExtent +
            _camera.center.dx,
        (screen.dy - _viewport.height / 2) /
            _viewport.height *
            _camera.viewExtent +
            _camera.center.dy,
      );

  /// Publish where the eye rests (music of the spheres listens there).
  void _publishPosition() {
    ref.read(travelPositionProvider.notifier).state = _camera.center;
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
    _publishPosition();
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

  /// An OPEN corpse takes a blind line; a CLOSED one is read whole,
  /// once. The server enforces the soul: contributors never read.
  Future<void> _onConstellationTap(ConstellationMeta cst) async {
    KenosHaptics.pulse(KenosPulse.themePick);
    if (cst.isClosed) {
      final lines = await ref
          .read(constellationRepositoryProvider)
          .consume(cst.id);
      if (!mounted) return;
      if (lines == null || lines.isEmpty) {
        unawaited(_loadConstellations());
        return;
      }
      unawaited(showConstellationReading(context, lines: lines)
          .then((_) {
        if (mounted) _loadConstellations();
      }));
    } else {
      unawaited(showContributeSheet(context, ref: ref, constellation: cst)
          .then((_) {
        if (mounted) _loadConstellations();
      }));
    }
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
    final all = echoes.valueOrNull ?? const <Echo>[];
    final readable = all.where((e) => !e.isMine).length;
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
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
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
                            echoes: echoes.valueOrNull ?? const <Echo>[],
                          ),
                        ),
                      ),
                      // The Vestiges: carved shards of culture, static
                      // in the void, tappable for a re-readable reveal.
                      if (_vestiges.isNotEmpty)
                        LayoutBuilder(
                          builder: (context, c) => Stack(
                            children: [
                              for (final v in _vestiges)
                                Builder(
                                  builder: (context) {
                                    final sp = _camera.worldToScreen(
                                      Offset(v.offsetX, v.offsetY),
                                      Size(c.maxWidth, c.maxHeight),
                                    );
                                    if (sp.dx < -30 ||
                                        sp.dx > c.maxWidth + 30 ||
                                        sp.dy < -30 ||
                                        sp.dy > c.maxHeight + 30) {
                                      return const SizedBox.shrink();
                                    }
                                    return Positioned(
                                      left: sp.dx - 16,
                                      top: sp.dy - 16,
                                      width: 32,
                                      height: 32,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () async {
                                          await showVestigeSheet(
                                            context,
                                            vestige: v,
                                          );
                                          if (mounted) {
                                            setState(() {});
                                          }
                                        },
                                        child: CustomPaint(
                                          painter: VestigePainter(
                                            rotation:
                                                VestigeMath.rotationAt(
                                              v.id,
                                              context.wantsReducedMotion
                                                  ? epoch
                                                  : DateTime.now(),
                                            ),
                                            color: AppColors.pureLight,
                                            pulse: 0,
                                            read: v.isRead,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      // The Constellations: exquisite corpses. OPEN =
                      //    contribute a blind line; CLOSED = read it
                      //    whole, once. Never both for the same person.
                      if (_constellations.isNotEmpty)
                        LayoutBuilder(
                          builder: (context, c) => Stack(
                            children: [
                              for (final cst in _constellations)
                                Builder(
                                  builder: (context) {
                                    final sp = _camera.worldToScreen(
                                      Offset(cst.seedX, cst.seedY),
                                      Size(c.maxWidth, c.maxHeight),
                                    );
                                    if (sp.dx < -40 ||
                                        sp.dx > c.maxWidth + 40 ||
                                        sp.dy < -40 ||
                                        sp.dy > c.maxHeight + 40) {
                                      return const SizedBox.shrink();
                                    }
                                    return Positioned(
                                      left: sp.dx - 20,
                                      top: sp.dy - 20,
                                      width: 40,
                                      height: 40,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _onConstellationTap(cst),
                                        child: CustomPaint(
                                          painter: _ConstellationPainter(
                                            closed: cst.isClosed,
                                            lineCount: cst.lineCount,
                                            target: cst.target,
                                            color: cst.isClosed
                                                ? AppColors.indigo
                                                : AppColors.pureLight,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
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
            // Top HUD — one thin line of machine whisper, one row of
            // quiet controls. The void dominates; the numbers breathe.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ONE line: the state that matters now.
                    Text(
                      _hudHeadline(
                        readable: readable,
                        signals: signals,
                      ),
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 9,
                        letterSpacing: 3,
                        color: signals > 0
                            ? AppColors.teal
                            : AppColors.fade(AppColors.cyan, 0.55),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // The quiet second line — presence, not urgency.
                    Text(
                      _readableSilent,
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 8,
                        letterSpacing: 3,
                        color: AppColors.fade(AppColors.pureLight, 0.28),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 0,
                      runSpacing: 0,
                      children: [
                        const _SoundToggle(),
                        TextButton(
                          onPressed: () => context.push('/frequencies'),
                          child: const Text('ONDES'),
                        ),
                        TextButton(
                          onPressed: () => context.push('/impact'),
                          child: const Text('IMPACT'),
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

  /// Each star breathes on its own slow phase (the sky is alive —
  /// eternal is not motionless). ~4 fps is enough for a 6 s breath.
  DateTime _breathAt = DateTime.now();
  Timer? _breath;

  /// When a star is caught, its orbit time freezes HERE: the layer
  /// keeps computing its position from this instant until release.
  DateTime? _frozenAt;
  String? _frozenFor;

  @override
  void dispose() {
    _breath?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ambient parallax calms down (×0.15) under reduce-motion.
    final motionScale = context.wantsReducedMotion ? 0.15 : 1.0;
    final tilt = ref.watch(tiltProvider).valueOrNull ?? Tilt.zero;
    final now = DateTime.now();

    // The breathing: every star on its own phase (id-hash), a slow
    // 6-second swell. Frozen under reduce-motion (a star chart).
    if (!context.wantsReducedMotion && widget.echoes.isNotEmpty) {
      _breath ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() => _breathAt = DateTime.now());
      });
    }

    // A caught star holds still: snapshot the instant the hold began,
    // compute ITS position from that frozen clock until release.
    final heldId = ref.watch(heldEchoIdProvider);
    if (heldId != _frozenFor) {
      _frozenFor = heldId;
      _frozenAt = heldId != null ? DateTime.now() : null;
    }
    final frozenFor = _frozenFor;
    final frozenAt = _frozenAt;

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
            // A CAUGHT echo (under a finger) computes from its frozen
            // instant: catching a moving light is not a chase.
            final echoNow = (frozenFor == echo.id && frozenAt != null)
                ? frozenAt
                : now;
            final sp = widget.camera.worldToScreen(
              KenosSystem.echoPosition(echo, echoNow),
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
                child: MindfulHoldStar(
                  key: ValueKey('star-${echo.id}'),
                  echo: echo,
                  z: z,
                  breathAt: _breathAt,
                ),
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


/// V3.11b — the emergent figure: each contributed line is a star at the
/// next golden-angle station around the seed — the constellation draws
/// itself as strangers write. Drawn stars are bright and linked by
/// faint segments (what they wrote); the stations still hollow wait.
/// CLOSED = the figure complete, glowing indigo (readable whole, once).
class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter({
    required this.closed,
    required this.lineCount,
    required this.target,
    required this.color,
  });

  final bool closed;
  final int lineCount;
  final int target;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 3;
    final t = target.clamp(2, 7);

    Offset station(int k) => Offset(
          center.dx + radius * _fx(k, t).$1,
          center.dy + radius * _fx(k, t).$2,
        );

    // The seed: where the first stranger planted the corpse.
    canvas.drawCircle(
      center,
      1.1,
      Paint()..color = AppColors.fade(color, closed ? 0.9 : 0.55),
    );

    // The strangers' segments: what has been drawn so far.
    final drawn = lineCount.clamp(0, t);
    if (drawn >= 2) {
      final link = Paint()
        ..color = AppColors.fade(color, closed ? 0.5 : 0.28)
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round;
      for (var k = 1; k < drawn; k++) {
        canvas.drawLine(station(k - 1), station(k), link);
      }
    }

    // The stations: filled stars for written lines, hollow for the rest.
    for (var k = 0; k < t; k++) {
      final isFilled = k < drawn;
      final pos = station(k);
      final paint = Paint()
        ..color = AppColors.fade(color, isFilled ? (closed ? 0.9 : 0.6) : 0.18);
      if (isFilled) {
        canvas.drawCircle(pos, closed ? 2.0 : 1.8, paint);
      } else {
        canvas.drawCircle(
          pos,
          1.4,
          Paint()
            ..color = AppColors.fade(color, 0.16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7,
        );
      }
    }
  }

  // Golden-angle placement (unit space), mirrored from the figure
  // domain — the map avoids importing feature domains in painters.
  static (double, double) _fx(int k, int t) {
    const golden = 2 * 3.141592653589793 * 0.38196601125010515;
    final r = 0.42 + 0.58 * k / (t - 1);
    final a = k * golden - 3.141592653589793 / 2;
    return (r * _cos(a), r * _sin(a));
  }

  // Avoid importing dart:math for two trig calls.
  static double _cos(double rad) =>
      rad == 0 ? 1 : (rad == 3.141592653589793 ? -1 : _polyCos(rad));
  static double _polyCos(double x) {
    // Taylor 6 terms — precise enough for 7 stations.
    var term = 1.0;
    var sum = 1.0;
    for (var n = 1; n <= 6; n++) {
      term *= -x * x / ((2 * n - 1) * (2 * n));
      sum += term;
    }
    return sum;
  }

  static double _sin(double rad) => _polyCos(rad - 1.5707963267948966);

  @override
  bool shouldRepaint(_ConstellationPainter old) =>
      old.closed != closed ||
      old.lineCount != lineCount ||
      old.target != target;
}
