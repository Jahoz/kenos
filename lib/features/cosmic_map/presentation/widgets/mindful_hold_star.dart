import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_controller.dart';
import '../../../../core/audio/audio_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/haptics/kenos_haptics.dart';
import '../../../../core/utils/motion_preferences.dart';
import '../../../../core/utils/parallax_math.dart';
import '../../../../core/widgets/hud.dart';
import '../../../echo/data/echo_repository.dart';
import '../../../echo/domain/echo.dart';
import '../../../echo/domain/reception.dart';
import '../../application/map_controller.dart';
import '../../application/reception_controller.dart';
import 'reception_sheet.dart';
import 'reveal_sheet.dart';
import 'ring_painters.dart';

/// A star on the map.
///
/// Ether echo    → Mindful Hold: 3 s long press, charge ring,
///                 rising drone pitch, then atomic consumption.
/// Sealed echo (self) → rotating dashed shield, untouchable.
class MindfulHoldStar extends ConsumerStatefulWidget {
  const MindfulHoldStar({
    super.key,
    required this.echo,
    required this.z,
    this.breathAt,
  });

  final Echo echo;
  final double z;

  /// The sky's breath clock (V3.7 polish): each star swells and dims
  /// on its own 6-second phase. Null = frozen (reduce-motion).
  final DateTime? breathAt;

  @override
  ConsumerState<MindfulHoldStar> createState() => _MindfulHoldStarState();
}

class _MindfulHoldStarState extends ConsumerState<MindfulHoldStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.echo.isMine
        ? const Duration(seconds: 14)
        : AppDurations.mindfulHold,
  );

  bool _busy = false;
  Offset? _downPosition;

  Echo get _echo => widget.echo;

  @override
  void initState() {
    super.initState();
    final reduced = platformDisablesAnimations();
    if (_echo.isMine) {
      // The sealed shield rotates slowly — decorative, frozen when the
      // user asked to reduce animations.
      if (reduced) {
        _controller.value = 0.25;
      } else {
        _controller.repeat();
      }
    } else {
      _controller.addListener(_onHoldTick);
      _controller.addStatusListener(_onStatus);
    }
  }

  // The Riverpod container, captured at mount: `ref` is dead when
  // dispose runs, but a disposed star must not leave the sky frozen.
  late final ProviderContainer _container =
      ProviderScope.containerOf(context, listen: false);

  @override
  void dispose() {
    try {
      if (_container.read(heldEchoIdProvider) == _echo.id) {
        _container.read(heldEchoIdProvider.notifier).state = null;
      }
    } catch (_) {
      // Container already closed: nothing to thaw.
    }
    _beatTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Slow heartbeat while the hold charges — the friction has a pulse.
  Timer? _beatTimer;

  void _startBeats() {
    _beatTimer?.cancel();
    if (platformDisablesAnimations()) return;
    _beatTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      KenosHaptics.pulse(KenosPulse.holdBeat);
    });
  }

  void _stopBeats() {
    _beatTimer?.cancel();
    _beatTimer = null;
  }

  void _onHoldTick() {
    // The drone rises in pitch as the charge ring fills.
    ref
        .read(audioControllerProvider)
        .setDronePitch(1.0 + _controller.value * 0.5);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _consume();
    }
  }

  Future<void> _consume() async {
    if (_busy) return;
    _busy = true;
    _stopBeats();
    // Freeze the target NOW: the layer may rebuild and reassign this
    // element to another echo while the reveal is open (no keys on a
    // culled, re-sorted list) — forgetting must hit what was read.
    final targetId = _echo.id;
    KenosHaptics.pulse(
      KenosPulse.holdComplete,
      reduceMotion: platformDisablesAnimations(),
    );
    try {
      final echo = await ref
          .read(mapControllerProvider.notifier)
          .consume(targetId);
      if (!mounted) return;
      if (echo == null) {
        ref.read(mapControllerProvider.notifier).forget(targetId);
        _intercepted();
      } else {
        unawaited(ref.read(audioControllerProvider).playBell(KenosBell.reveal));
        KenosHaptics.pulse(KenosPulse.reveal);
        await showRevealSheet(context, echo: echo);
        if (!mounted) return;
        ref.read(mapControllerProvider.notifier).forget(targetId);
      }
    } catch (e) {
      if (mounted) {
        final message = e is KenosException
            ? e.hudMessage
            : 'L\'ÉTHER EST INJOIGNABLE.';
        _toast(message);
      }
    } finally {
      _busy = false;
      if (mounted) {
        _controller.value = 0;
        unawaited(ref.read(audioControllerProvider).setDronePitch(1.0));
      }
    }
  }

  void _intercepted() {
    KenosHaptics.pulse(KenosPulse.intercepted);
    _toast('CET ÉCHO S\'EST DISSOUS AILLEURS.');
  }

  void _toast(String message) {
    if (!mounted) return;
    showHud(context, message);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_busy) return;
    if (_echo.isMine) {
      // Sealed echo: consult the bottle-in-the-sea signal (never the text).
      KenosHaptics.pulse(KenosPulse.holdStart);
      ref.read(audioControllerProvider).playBell(KenosBell.seal);
      final reception = ref
          .read(receptionControllerProvider.notifier)
          .receptionFor(_echo.id);
      showReceptionSheet(context, echo: _echo, reception: reception);
      return;
    }
    _downPosition = event.position;
    // Caught: the star holds still under the finger — its orbit
    // freezes, the sky keeps breathing around it.
    ref.read(heldEchoIdProvider.notifier).state = _echo.id;
    KenosHaptics.pulse(KenosPulse.holdStart);
    _startBeats();
    _controller.forward();
  }

  void _onPointerMove(PointerMoveEvent event) {
    // Mindful means steady — but the SKY moves too: the measure is the
    // distance to the star's CURRENT center (it orbits while you hold),
    // not to where your finger first landed.
    if (_downPosition == null) return;
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final starCenter = renderObject.localToGlobal(
        renderObject.size.center(Offset.zero),
      );
      if ((event.position - starCenter).distance > 42) {
        _downPosition = null;
        _onPointerUp();
      }
      return;
    }
    if ((event.position - _downPosition!).distance > 28) {
      _downPosition = null;
      _onPointerUp();
    }
  }

  void _onPointerUp() {
    _downPosition = null;
    if (ref.read(heldEchoIdProvider) == _echo.id) {
      ref.read(heldEchoIdProvider.notifier).state = null;
    }
    _stopBeats();
    if (_echo.isMine) return;
    // Released before 100%: the ring rolls back, the drone returns to rest.
    if (_controller.status == AnimationStatus.forward) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final z = widget.z;
    final diameter = ParallaxMath.starDiameter(z);
    final coreRadius = ParallaxMath.coreRadius(z);
    final color = _echo.isMine ? AppColors.teal : _echo.theme.core;
    final hasUnreadSignal =
        _echo.isMine && _hasUnreadReception();

    // The breath: a slow individual swell (id-hash phase, 6 s period)
    // — the light LIVES, it is not a sticker.
    var coreScale = 1.0;
    var glowBoost = 0.0;
    final breathAt = widget.breathAt;
    if (breathAt != null && !context.wantsReducedMotion) {
      final phase =
          (breathAt.millisecondsSinceEpoch / 6000 + _echo.id.hashCode % 97) % 1.0;
      coreScale = 0.88 + 0.24 * math.sin(phase * 2 * math.pi);
      glowBoost = 0.5 + 0.5 * math.sin(phase * 2 * math.pi);
    }

    Widget visual = SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The comet tail: momentum made visible (a count of humans,
          // never a content). Decorative — hidden under reduce-motion.
          if (_echo.momentum > 0 && !context.wantsReducedMotion)
            Positioned.fill(
              child: CustomPaint(
                painter: CometTailPainter(
                  momentum: _echo.momentum,
                  color: color,
                ),
              ),
            ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _echo.isMine
                  ? ShieldRingPainter(
                      rotation: _controller.value * 6.283,
                      color: AppColors.teal,
                    )
                  : HoldRingPainter(
                      progress: _controller.value,
                      color: _echo.theme.halo,
                    ),
              child: Center(
                child: Transform.scale(
                  scale: coreScale,
                  child: Container(
                    width: coreRadius * 2,
                    height: coreRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white,
                          color,
                          AppColors.fade(color, 0),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                      boxShadow: glowBoost > 0.05
                          ? [
                              BoxShadow(
                                color: AppColors.fade(
                                  color,
                                  0.30 * glowBoost,
                                ),
                                blurRadius: 14 + 10 * glowBoost,
                                spreadRadius: 1 + 3 * glowBoost,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Depth: distant echoes are dimmer (the depth blur itself is
    // applied per bucket by the star layer — one saveLayer for the
    // whole depth range, not one per star).
    var opacity = ParallaxMath.opacityFor(z);
    if (hasUnreadSignal) {
      // A signal waits: the sealed star breathes — a steady glow,
      // not a pulse, when animations are reduced.
      if (context.wantsReducedMotion) {
        opacity = opacity + (1 - opacity) * 0.4;
      } else {
        final pulse = 0.5 + 0.5 * math.sin(_controller.value * 6.283 * 2);
        opacity = opacity + (1 - opacity) * 0.55 * pulse;
      }
    }
    visual = Opacity(opacity: opacity, child: visual);

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (_) => _onPointerUp(),
      // Cancel (scroll, system gesture) = release.
      onPointerCancel: (_) => _onPointerUp(),
      behavior: HitTestBehavior.opaque,
      child: Center(child: visual),
    );
  }

  bool _hasUnreadReception() {
    // Watch the receptions themselves (not just the notifier): a signal
    // landing must relight this star on the next frame.
    final receptions =
        ref.watch(receptionControllerProvider).valueOrNull ??
            const <Reception>[];
    return receptions.any((r) => r.echoId == _echo.id && !r.seen);
  }
}
