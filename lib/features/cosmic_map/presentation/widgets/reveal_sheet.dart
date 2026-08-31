import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_controller.dart';
import '../../../../core/audio/audio_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/haptics/kenos_haptics.dart';
import '../../../../core/utils/motion_preferences.dart';
import '../../../../core/widgets/ether_dissolve.dart';
import '../../../../core/widgets/scramble_text.dart';
import '../../../echo/domain/echo.dart';
import '../../application/map_controller.dart';

/// Reveal modal: glassmorphism, visual decryption, a 10-second reading
/// window, then dissolution — and the bottle-in-the-sea echo: the reader
/// may leave ONE trace for the stranger who launched the echo.
Future<void> showRevealSheet(BuildContext context, {required Echo echo}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'KENOS_REVELATION',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 600),
    useRootNavigator: true,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: RevealPanel(echo: echo),
      );
    },
  );
}

enum _Phase { reading, trace, sent }

class RevealPanel extends ConsumerStatefulWidget {
  const RevealPanel({super.key, required this.echo});

  final Echo echo;

  @override
  ConsumerState<RevealPanel> createState() => _RevealPanelState();
}

class _RevealPanelState extends ConsumerState<RevealPanel>
    with TickerProviderStateMixin {
  late final AnimationController _burn = AnimationController(
    vsync: this,
    duration: AppDurations.burnWindow,
  );
  late final AnimationController _dissolve = AnimationController(
    vsync: this,
    duration: AppDurations.dissolve,
  );

  final TextEditingController _traceInput = TextEditingController();

  _Phase _phase = _Phase.reading;
  bool _bellPlayed = false;
  bool _sending = false;

  static const _maxTrace = 140;

  @override
  void initState() {
    super.initState();
    _burn.addListener(() => setState(() {}));
    _burn.addStatusListener((status) {
      if (status == AnimationStatus.completed) _startDissolve();
    });
    // Let the decryption breathe before arming the countdown.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _burn.forward();
    });
  }

  @override
  void dispose() {
    _burn.dispose();
    _dissolve.dispose();
    _traceInput.dispose();
    super.dispose();
  }

  void _startDissolve() {
    if (!_bellPlayed) {
      _bellPlayed = true;
      // Low bell + mourning strike: the sound and feel of the burn.
      ref.read(audioControllerProvider).playBell(KenosBell.burn);
      KenosHaptics.pulse(
        KenosPulse.burn,
        reduceMotion: platformDisablesAnimations(),
      );
    }
    // Particle dissolution, then the trace offer — nothing else remains.
    _dissolve.forward(from: 0).whenComplete(() {
      if (mounted) {
        setState(() => _phase = _Phase.trace);
        _dissolve.value = 0;
      }
    });
  }

  Future<void> _sendTrace() async {
    if (_sending) return;
    final text = _traceInput.text.trim();
    if (text.isEmpty || text.length > _maxTrace) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(mapControllerProvider.notifier)
          .leaveTrace(widget.echo.id, text);
      ref.read(audioControllerProvider).playBell(KenosBell.send);
      KenosHaptics.pulse(KenosPulse.launch);
      if (!mounted) return;
      setState(() => _phase = _Phase.sent);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
    } catch (_) {
      // Silence is also an answer: close without guilt.
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void _leave() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    // « Reduce animations »: the dissolution becomes an instant swap;
    // the particle field never spawns.
    _dissolve.duration = context.wantsReducedMotion
        ? Duration.zero
        : AppDurations.dissolve;

    final Widget content;
    switch (_phase) {
      case _Phase.reading:
        content = _buildReading();
      case _Phase.trace:
        content = _buildTrace();
      case _Phase.sent:
        content = _buildSent();
    }

    return AnimatedBuilder(
      animation: _dissolve,
      builder: (context, child) {
        final v = _dissolve.value;
        final blurred = v > 0.01
            ? ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: v * 16,
                  sigmaY: v * 16,
                  tileMode: TileMode.decal,
                ),
                child: child,
              )
            : child!;
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 1 - v,
              child: Transform.scale(
                scale: 1 - v * 0.08,
                child: blurred,
              ),
            ),
            // The echo becomes dust: real particles scatter into the void
            // (skipped entirely when animations are reduced).
            if (v > 0.01 && !context.wantsReducedMotion)
              EtherDissolve(
                progress: v,
                color: widget.echo.theme.halo,
                seed: (widget.echo.id.hashCode % 997) / 997,
              ),
          ],
        );
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            color: AppColors.fade(AppColors.voidBlack, 0.72),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _panel({required List<Widget> children}) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );

  Widget _buildReading() {
    final secondsLeft = (10 * (1 - _burn.value)).toStringAsFixed(1);
    return _panel(
      children: [
        const SizedBox(height: 20),
        Text(
          'ÉCHO INTERCEPTÉ — LECTURE UNIQUE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 10,
            letterSpacing: 3,
            color: AppColors.fade(AppColors.teal, 0.9),
          ),
        ),
        const SizedBox(height: 34),
        ScrambleText(
          text: widget.echo.text ?? '',
          resolve: true,
          duration: const Duration(milliseconds: 1100),
          textAlign: TextAlign.center,
          style: secretStyle(),
        ),
        const SizedBox(height: 40),
        Text(
          'DESTRUCTION IMMINENTE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9,
            letterSpacing: 4,
            color: AppColors.roseText,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$secondsLeft S',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 16,
            letterSpacing: 2,
            color: AppColors.roseText,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 210,
            height: 1.5,
            color: AppColors.fade(AppColors.rose, 0.15),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _burn.value,
                child: Container(color: AppColors.rose),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTrace() {
    return _panel(
      children: [
        const SizedBox(height: 20),
        Text(
          'L\'ÉCHO S\'EST DISSOUS.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9,
            letterSpacing: 4,
            color: AppColors.fade(AppColors.pureLight, 0.4),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          'As-tu été touché ?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.serifItalic,
            fontSize: 22,
            color: AppColors.fade(AppColors.pureLight, 0.92),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Laisse une trace — une ligne, sans réponse possible.\n'
          'Celui qui a lancé cet écho ne saura jamais qui tu es.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9.5,
            letterSpacing: 1,
            height: 1.9,
            color: AppColors.fade(AppColors.pureLight, 0.45),
          ),
        ),
        const SizedBox(height: 26),
        TextField(
          controller: _traceInput,
          autofocus: true,
          maxLength: _maxTrace,
          maxLines: 1,
          cursorColor: AppColors.teal,
          textAlign: TextAlign.center,
          style: secretStyle(fontSize: 16),
          decoration: const InputDecoration(
            counterStyle: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 9,
              letterSpacing: 2,
              color: Color(0x55F4F4F6),
            ),
            border: InputBorder.none,
            hintText: 'une ligne, puis le vide',
            hintStyle: TextStyle(
              fontFamily: AppFonts.serifItalic,
              fontSize: 16,
              color: Color(0x33F4F4F6),
            ),
          ),
        ),
        const SizedBox(height: 22),
        OutlinedButton(
          onPressed: _sendTrace,
          child: const Text('ENVOYER LA TRACE'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _leave,
          child: const Text('REPARTIR SANS RIEN'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSent() {
    return _panel(
      children: [
        const SizedBox(height: 30),
        ScrambleText(
          text: 'trace larguée dans le vide',
          resolve: true,
          duration: const Duration(milliseconds: 900),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.serifItalic,
            fontSize: 20,
            color: AppColors.fade(AppColors.teal, 0.95),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
