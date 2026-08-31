import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_controller.dart';
import '../../../../core/audio/audio_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/utils/parallax_math.dart';
import '../../../echo/data/echo_repository.dart';
import '../../../echo/domain/echo.dart';
import '../../application/map_controller.dart';
import 'ring_painters.dart';
import 'reception_sheet.dart';
import 'reveal_sheet.dart';

/// A star on the map.
///
/// Ether echo    → Mindful Hold: 3 s long press, charge ring,
///                 rising drone pitch, then atomic consumption.
/// Sealed echo (self) → rotating dashed shield, untouchable.
class MindfulHoldStar extends ConsumerStatefulWidget {
  const MindfulHoldStar({super.key, required this.echo, required this.z});

  final Echo echo;
  final double z;

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
    if (_echo.isMine) {
      _controller.repeat();
    } else {
      _controller.addListener(_onHoldTick);
      _controller.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    HapticFeedback.mediumImpact();
    try {
      final echo = await ref
          .read(mapControllerProvider.notifier)
          .consume(_echo.id);
      if (!mounted) return;
      if (echo == null) {
        ref.read(mapControllerProvider.notifier).forget(_echo.id);
        _intercepted();
      } else {
        ref.read(audioControllerProvider).playBell(KenosBell.reveal);
        await showRevealSheet(context, echo: echo);
        if (!mounted) return;
        ref.read(mapControllerProvider.notifier).forget(_echo.id);
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
        ref.read(audioControllerProvider).setDronePitch(1.0);
      }
    }
  }

  void _intercepted() {
    HapticFeedback.selectionClick();
    _toast('CET ÉCHO S\'EST DISSOUS AILLEURS.');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_busy) return;
    if (_echo.isMine) {
      // Sealed echo: consult the bottle-in-the-sea signal (never the text).
      HapticFeedback.lightImpact();
      ref.read(audioControllerProvider).playBell(KenosBell.seal);
      final reception = ref
          .read(mapControllerProvider.notifier)
          .receptionFor(_echo.id);
      showReceptionSheet(context, echo: _echo, reception: reception);
      return;
    }
    _downPosition = event.position;
    HapticFeedback.lightImpact();
    _controller.forward();
  }

  void _onPointerMove(PointerMoveEvent event) {
    // Mindful means steady: drifting off the star cancels the hold.
    if (_downPosition == null) return;
    if ((event.position - _downPosition!).distance > 28) {
      _downPosition = null;
      _onPointerUp();
    }
  }

  void _onPointerUp() {
    _downPosition = null;
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

    Widget visual = SizedBox(
      width: diameter,
      height: diameter,
      child: AnimatedBuilder(
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
            child: Container(
              width: coreRadius * 2,
              height: coreRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white, color, AppColors.fade(color, 0)],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Depth: distant echoes are dimmer, smaller, blurred.
    final sigma = ParallaxMath.blurSigma(z);
    if (sigma > 0.05) {
      visual = ImageFiltered(imageFilter: _blurFilter(sigma), child: visual);
    }
    var opacity = ParallaxMath.opacityFor(z);
    if (hasUnreadSignal) {
      // A signal waits: the sealed star breathes.
      final pulse = 0.5 + 0.5 * math.sin(_controller.value * 6.283 * 2);
      opacity = opacity + (1 - opacity) * 0.55 * pulse;
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
    final reception =
        ref.read(mapControllerProvider.notifier).receptionFor(_echo.id);
    return reception != null && !reception.seen;
  }
}

ImageFilter _blurFilter(double sigma) =>
    ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);
