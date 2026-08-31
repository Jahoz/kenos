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
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  @override
  void initState() {
    super.initState();
    // « Reduce animations »: the star field stays still — scenery only.
    if (!platformDisablesAnimations()) {
      _twinkle.repeat();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioControllerProvider).ensureStarted();
    });
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final echoes = ref.watch(mapControllerProvider);
    final reduced = context.wantsReducedMotion;
    // Ambient parallax calms down (×0.15) but stays alive: the ether is
    // not a screenshot.
    final motionScale = reduced ? 0.15 : 1.0;
    final tilt = ref.watch(tiltProvider).valueOrNull ?? Tilt.zero;
    final boot = ref.watch(bootstrapProvider);
    final count = echoes.valueOrNull?.length ?? 0;
    final signals = ref.watch(receptionControllerProvider).valueOrNull?.length ?? 0;

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
        onPointerDown: (_) => ref.read(audioControllerProvider).ensureStarted(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Spatial void + diffuse nebulae.
            CustomPaint(
              painter: NebulaPainter(
                tiltX: tilt.x * 0.5 * motionScale,
                tiltY: tilt.y * 0.5 * motionScale,
              ),
            ),
            // Dead star field (scenery, slow twinkle).
            AnimatedBuilder(
              animation: _twinkle,
              builder: (context, _) => CustomPaint(
                painter: BackgroundStarFieldPainter(
                  time: _twinkle.value * 60,
                  tiltX: tilt.x * motionScale,
                  tiltY: tilt.y * motionScale,
                ),
              ),
            ),
            // The matter: the echoes.
            echoes.when(
              data: (list) => list.isEmpty
                  ? const _CalmEther()
                  : _StarLayer(
                      echoes: list,
                      tilt: Tilt(tilt.x * motionScale, tilt.y * motionScale),
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
                child: OutlinedButton(
                  onPressed: () => context.push('/mirror'),
                  child: const Text('FORMULER UN ÉCHO'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Positions echoes in space: normalized coordinates + parallax
/// proportional to depth. Close objects paint last.
class _StarLayer extends StatelessWidget {
  const _StarLayer({required this.echoes, required this.tilt});

  final List<Echo> echoes;
  final Tilt tilt;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sorted = echoes.toList()
      ..sort((a, b) => a.resolveZ(now).compareTo(b.resolveZ(now)));

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final children = <Widget>[];

        for (final echo in sorted) {
          final z = echo.resolveZ(now);
          final diameter = ParallaxMath.starDiameter(z);
          final hit = diameter + 26; // comfortable touch target

          final baseX =
              ParallaxMath.clamp(echo.coordX * w, hit / 2, w - hit / 2) +
              ParallaxMath.offsetPixels(tilt: tilt.x, z: z, amplitude: 46);
          final baseY =
              ParallaxMath.clamp(echo.coordY * h, hit / 2, h - hit / 2) +
              ParallaxMath.offsetPixels(tilt: tilt.y, z: z, amplitude: 32);

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

        return Stack(children: children);
      },
    );
  }
}

class _CalmEther extends StatelessWidget {
  const _CalmEther();

  @override
  Widget build(BuildContext context) {
    return const _Centered(
      'L\'ÉTHER EST CALME. RESPIRE.',
      color: AppColors.pureLight,
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
