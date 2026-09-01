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
import '../../cosmic_map/application/travel_camera.dart';
import '../../echo/data/echo_providers.dart';
import '../application/spatial_wave_audio.dart';
import '../application/wave_controller.dart';
import '../domain/kenos_wave.dart';
import '../domain/spatial_wave_math.dart';
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
  StreamSubscription<KenosWave>? _heard;

  /// First visit: a veil explains the symphony (one time, stored).
  bool _showingGuide = true;
  DateTime? _lastIncomingAt;

  // Captured in initState: `ref` is already dead when dispose runs.
  late final WaveController _controller =
      ref.read(waveControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Music of the spheres (V3.7c): open the field WHERE YOU ARE —
    // the camera's resting point is the listening center.
    final position = ref.read(travelPositionProvider);
    _controller.setListenCenter(position.dx, position.dy);
    _readGuideSeen();
    // Start hearing the ether (V3.2): a 2 s poll feeds incoming waves.
    _controller.activate();
    _heard = _controller.incomingWaves.listen(_soundIncoming);
  }

  @override
  void dispose() {
    _heard?.cancel();
    _controller.deactivate();
    _ticker?.cancel();
    super.dispose();
  }

  /// A stranger's wave just landed: sound it, softer the further it
  /// was born from our listening point. The wave keeps aging from its
  /// server birth, so late arrivals may already be fading.
  Future<void> _readGuideSeen() async {
    final store = ref.read(localEchoStoreProvider);
    final seen = await store.hasFrequenciesGuideSeen();
    if (mounted) setState(() => _showingGuide = !seen);
  }

  void _soundIncoming(KenosWave wave) {
    // Softer the further it was born, and to the side it was born on.
    final controller = ref.read(waveControllerProvider.notifier);
    final d = controller.listenDistanceTo(wave.offsetX, wave.offsetY);
    KenosHaptics.pulse(KenosPulse.waveEmit, reduceMotion: platformDisablesAnimations());
    unawaited(
      _soundWave(
        wave,
        pan: SpatialWaveMath.panFor(wave.offsetX, controller.listenCenter.$1),
        gain: SpatialWaveMath.gainFor(
          d,
          radius: WaveController.hearingRadius,
        ),
      ),
    );
    setState(() => _lastIncomingAt = DateTime.now());
    _startTickerIfNeeded();
  }

  void _emit(Offset local, Size size) {
    final reduced = platformDisablesAnimations();
    final wave = ref.read(waveControllerProvider.notifier).emit(
          local.dx / size.width,
          local.dy / size.height,
        );
    KenosHaptics.pulse(KenosPulse.waveEmit, reduceMotion: reduced);
    // One's own wave is born under the finger: centered, present.
    unawaited(_soundWave(wave));
    _startTickerIfNeeded();
  }

  /// V3.6 — sounds a wave: a real oscillator placed in the stereo field
  /// when the engine lives, the baked asset otherwise. The symphony
  /// never goes silent over an engine, and never blocks the UI.
  Future<void> _soundWave(KenosWave wave, {double pan = 0, double gain = 0.45}) async {
    final spatial = await SpatialWaveAudio.instance
        .playNote(wave.noteIndex, pan: pan, gain: gain);
    if (!spatial) {
      unawaited(
        ref
            .read(audioControllerProvider)
            .playAsset(WaveMath.assetForNote(wave.noteIndex), volume: gain),
      );
    }
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
        child: Stack(
          children: [
            Positioned.fill(
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
                    lastIncomingAt: _lastIncomingAt,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'TOUCHE = ÉMETTRE · HAUT = CLAIR · BAS = GRAVE · LES ONDES DES INCONNUS ARRIVENT SEULES',
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
            if (_showingGuide)
              Positioned.fill(
                child: _FrequenciesGuide(onUnderstood: _dismissGuide),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _dismissGuide() async {
    setState(() => _showingGuide = false);
    await ref.read(localEchoStoreProvider).markFrequenciesGuideSeen();
  }
}

/// The tappable resonance field: grid telemetry, hint, nebulae.
class _ResonanceField extends StatelessWidget {
  const _ResonanceField({
    required this.waves,
    required this.now,
    required this.reducedMotion,
    required this.onEmit,
    this.lastIncomingAt,
  });

  final List<KenosWave> waves;
  final DateTime now;
  final bool reducedMotion;
  final void Function(Offset local, Size size) onEmit;

  /// When the last foreign wave landed — draws a brief arrival ring
  /// so 'joining a symphony' is something you SEE, not guess.
  final DateTime? lastIncomingAt;

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
              foregroundPainter: _ArrivalRingPainter(
                waves: waves,
                lastIncomingAt: lastIncomingAt,
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


/// First-visit veil: three lines that make the symphony legible.
class _FrequenciesGuide extends StatelessWidget {
  const _FrequenciesGuide({required this.onUnderstood});

  final VoidCallback onUnderstood;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onUnderstood,
      child: Container(
        color: AppColors.fade(AppColors.voidBlack, 0.88),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 38),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LA SYMPHONIE COLLECTIVE',
                  style: hudLabel(
                    fontSize: 10,
                    letterSpacing: 5,
                    color: AppColors.fade(AppColors.teal, 0.85),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Touche le vide : ton onde naît.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 18,
                    height: 1.7,
                    color: AppColors.fade(AppColors.pureLight, 0.92),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Le haut de l\'écran chante clair, le bas chante grave.\n'
                  'La couleur suit la gauche ou la droite du vide.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 15,
                    height: 1.8,
                    color: AppColors.fade(AppColors.pureLight, 0.6),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Les inconnus qui touchent le vide près de toi\n'
                  'y laissent des ondes — elles arrivent seules,\n'
                  'tu les entendras et les verras naître.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 15,
                    height: 1.8,
                    color: AppColors.fade(AppColors.teal, 0.75),
                  ),
                ),
                const SizedBox(height: 34),
                Text(
                  'TOUCHE POUR COMMENCER',
                  style: hudLabel(
                    fontSize: 9,
                    letterSpacing: 4,
                    color: AppColors.fade(AppColors.pureLight, 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// A brief expanding ring on the freshest foreign wave — the visible
/// sign that the symphony reached you.
class _ArrivalRingPainter extends CustomPainter {
  _ArrivalRingPainter({
    required this.waves,
    required this.lastIncomingAt,
    required this.now,
    required this.reducedMotion,
  });

  final List<KenosWave> waves;
  final DateTime? lastIncomingAt;
  final DateTime now;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final at = lastIncomingAt;
    if (at == null || reducedMotion) return;
    final ageMs = now.difference(at).inMilliseconds;
    if (ageMs < 0 || ageMs > 1200) return;
    final t = ageMs / 1200;

    // The freshest wave that is not ours (foreign waves have server
    // ids, ours carry the 'w' prefix).
    final foreign = waves.where((w) => !w.id.startsWith('w')).toList();
    if (foreign.isEmpty) return;
    foreign.sort((a, b) => b.bornAt.compareTo(a.bornAt));
    final wave = foreign.first;

    final center = Offset(
      wave.offsetX * size.width,
      wave.offsetY * size.height,
    );
    final radius = 20 + 120 * t;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * (1 - t)
      ..color = AppColors.fade(AppColors.teal, 0.55 * (1 - t));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_ArrivalRingPainter oldDelegate) => true;
}
