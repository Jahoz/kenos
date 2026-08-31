import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/audio_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/haptics/kenos_haptics.dart';
import '../../../core/utils/motion_preferences.dart';
import '../../../core/widgets/hud.dart';
import '../application/wave_controller.dart';
import '../domain/kenos_wave.dart';
import 'widgets/wave_nebula_painter.dart';

/// The Symphonie Collective: touch the void, a pentatonic wave answers.
/// Y is the register (bottom = heavy/melancholy, top = crystalline/hope),
/// X is the hue band. Every combination is consonant by design.
///
/// V3.1: local only — waves are born and die on this device. The ether
/// crossing (shared waves within a hearing radius) is V3.2.
class FrequenciesScreen extends ConsumerStatefulWidget {
  const FrequenciesScreen({super.key});

  @override
  ConsumerState<FrequenciesScreen> createState() => _FrequenciesScreenState();
}

class _FrequenciesScreenState extends ConsumerState<FrequenciesScreen> {
  /// ~20 fps repaint while nebulae breathe — smooth enough for slow
  /// light, kind to the battery. Idle (no waves) costs nothing.
  static const _frame = Duration(milliseconds: 50);

  DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _emit(Offset local, Size size) {
    final reduced = platformDisablesAnimations();
    final wave = ref.read(waveControllerProvider.notifier).emit(
          local.dx / size.width,
          local.dy / size.height,
        );
    KenosHaptics.pulse(KenosPulse.waveEmit, reduceMotion: reduced);
    // Fire-and-forget by contract: the baked 6 s envelope plays itself.
    unawaited(
      ref
          .read(audioControllerProvider)
          .playAsset(WaveMath.assetForNote(wave.noteIndex), volume: 0.45),
    );
    _startTickerIfNeeded();
  }

  void _startTickerIfNeeded() {
    if (platformDisablesAnimations()) return;
    if (_ticker != null) return;
    _ticker = Timer.periodic(_frame, (_) {
      if (!mounted) return;
      final waves = ref.read(waveControllerProvider);
      if (waves.isEmpty) {
        _ticker?.cancel();
        _ticker = null;
        return;
      }
      setState(() => _now = DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final waves = ref.watch(waveControllerProvider);
    final reduced = context.wantsReducedMotion;

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back,
                        size: 14, color: AppColors.pureLight),
                    label: const Text('LA CARTE'),
                  ),
                  const Spacer(),
                  Text(
                    '${waves.length} ONDE${waves.length > 1 ? 'S' : ''} ACTIVE${waves.length > 1 ? 'S' : ''}',
                    style: hudLabel(color: AppColors.teal),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'KENOS // FRÉQUENCES',
                  style: hudLabel(
                    fontSize: 9,
                    letterSpacing: 3,
                    color: AppColors.fade(AppColors.cyan, 0.55),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _ResonanceField(
                    waves: waves,
                    now: _now,
                    reducedMotion: reduced,
                    onEmit: _emit,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                'UNE GAMME PENTATONIQUE — TOUTES LES ONDES SONT HARMONIEUSES',
                textAlign: TextAlign.center,
                style: hudLabel(
                  fontSize: 8,
                  letterSpacing: 2,
                  color: AppColors.fade(AppColors.pureLight, 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tappable resonance field: grid telemetry, hint, nebulae.
class _ResonanceField extends StatelessWidget {
  const _ResonanceField({
    required this.waves,
    required this.now,
    required this.reducedMotion,
    required this.onEmit,
  });

  final List<KenosWave> waves;
  final DateTime now;
  final bool reducedMotion;
  final void Function(Offset local, Size size) onEmit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapUp: (details) => onEmit(details.localPosition, size),
          child: RepaintBoundary(
            child: CustomPaint(
              size: size,
              painter: WaveNebulaPainter(
                waves: waves,
                now: now,
                reducedMotion: reducedMotion,
              ),
              child: waves.isEmpty ? const _Hint() : const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TOUCHE L\'ESPACE',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 11,
                letterSpacing: 5,
                color: AppColors.fade(AppColors.pureLight, 0.4),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'le haut respire l\'espérance — le bas, la mélancolie',
              style: TextStyle(
                fontFamily: AppFonts.serifItalic,
                fontSize: 13,
                color: AppColors.fade(AppColors.pureLight, 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
