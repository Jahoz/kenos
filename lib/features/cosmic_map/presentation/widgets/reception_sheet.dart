import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_controller.dart';
import '../../../../core/audio/audio_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/haptics/kenos_haptics.dart';
import '../../../../core/widgets/scramble_text.dart';
import '../../../echo/domain/echo.dart';
import '../../../echo/domain/reception.dart';
import '../../application/reception_controller.dart';

/// Bottle-in-the-sea signal, author side: tap your sealed echo to learn
/// whether it was intercepted — how long it drifted, how far it traveled,
/// and the stranger's optional one-line trace.
///
/// The signal exists once: viewing it burns it.
Future<void> showReceptionSheet(
  BuildContext context, {
  required Echo echo,
  Reception? reception,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'KENOS_RECEPTION',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 600),
    useRootNavigator: true,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ReceptionPanel(echo: echo, reception: reception),
      );
    },
  );
}

class ReceptionPanel extends ConsumerStatefulWidget {
  const ReceptionPanel({super.key, required this.echo, this.reception});

  final Echo echo;
  final Reception? reception;

  @override
  ConsumerState<ReceptionPanel> createState() => _ReceptionPanelState();
}

class _ReceptionPanelState extends ConsumerState<ReceptionPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dissolve = AnimationController(
    vsync: this,
    duration: AppDurations.dissolve,
  );

  bool _closing = false;

  @override
  void initState() {
    super.initState();
    if (widget.reception != null) {
      ref.read(audioControllerProvider).playBell(KenosBell.reveal);
    }
  }

  @override
  void dispose() {
    _dissolve.dispose();
    super.dispose();
  }

  Future<void> _close({bool burn = false}) async {
    if (_closing) return;
    _closing = true;
    if (burn && widget.reception != null) {
      // The signal burns — one look, then the void.
      KenosHaptics.pulse(KenosPulse.burn);
      await ref
          .read(receptionControllerProvider.notifier)
          .burn(widget.echo.id);
    }
    await _dissolve.forward(from: 0);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final reception = widget.reception;
    final driftNow = DateTime.now().difference(widget.echo.createdAt);

    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              reception != null
                  ? 'TON ÉCHO A ÉTÉ LU'
                  : 'TON ÉCHO DÉRIVE ENCORE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 10,
                letterSpacing: 3,
                color: reception != null
                    ? AppColors.fade(AppColors.teal, 0.9)
                    : AppColors.fade(AppColors.pureLight, 0.4),
              ),
            ),
            const SizedBox(height: 26),
            // What this IS: the bottle came back — your sealed echo's
            // journey, never its text.
            Text(
              reception != null
                  ? 'Un inconnu l\'a intercepté quelque part dans le vide.\n'
                      'L\'écho n\'existe plus — ce signal est tout ce qui revient.'
                  : 'Personne ne l\'a lu. Il flotte,\nquelque part, intact.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.serifItalic,
                fontSize: 16.5,
                height: 1.75,
                color: AppColors.fade(AppColors.pureLight, 0.6),
              ),
            ),
            const SizedBox(height: 30),
            // Drift telemetry — machine voice.
            Text(
              'DÉRIVÉ PENDANT ${reception != null ? reception.driftLabel : _liveDrift(driftNow)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 11,
                letterSpacing: 3,
                color: AppColors.fade(AppColors.pureLight, 0.65),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'DISTANCE PARCOURUE ≈ ${_distanceLabel(reception?.driftSeconds ?? driftNow.inSeconds)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 11,
                letterSpacing: 3,
                color: AppColors.fade(AppColors.cyan, 0.7),
              ),
            ),
            const SizedBox(height: 34),
            if (reception?.reply != null) ...[
              ScrambleText(
                text: reception!.reply!,
                resolve: true,
                duration: const Duration(milliseconds: 1100),
                textAlign: TextAlign.center,
                style: secretStyle(),
              ),
              const SizedBox(height: 30),
              Text(
                'TRACE — LECTURE UNIQUE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 8,
                  letterSpacing: 4,
                  color: AppColors.roseText,
                ),
              ),
            ] else if (reception != null) ...[
              Text(
                'Aucune trace. Le silence est aussi une réponse.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.serifItalic,
                  fontSize: 17,
                  color: AppColors.fade(AppColors.pureLight, 0.5),
                ),
              ),
            ],
            const SizedBox(height: 36),
            if (reception != null) ...[
              OutlinedButton(
                onPressed: () => _close(burn: true),
                child: const Text('BRÛLER LE SIGNAL'),
              ),
              const SizedBox(height: 6),
              Text(
                'Le signal n\'existe qu\'une fois — le brûler, c\'est le laisser partir pour de bon.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 8,
                  letterSpacing: 1.5,
                  height: 1.8,
                  color: AppColors.fade(AppColors.pureLight, 0.35),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _close(),
                child: const Text('PLUS TARD — L\'ÉTOILE CONTINUERA DE PULSER'),
              ),
            ] else
              OutlinedButton(
                onPressed: () => _close(),
                child: const Text('REVENIR AU VIDE'),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _dissolve,
      builder: (context, child) => Opacity(
        opacity: 1 - _dissolve.value,
        child: child,
      ),
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

  String _liveDrift(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '$m MIN';
    return '$h H ${m.toString().padLeft(2, '0')} MIN';
  }

  String _distanceLabel(int driftSeconds) {
    // Same poetic scale as Reception.distanceLabel, for the still-drifting case.
    final km = driftSeconds * 299792.458;
    if (km >= 1.0e8) {
      final ua = km / 1.496e8;
      return '${ua >= 100 ? ua.round().toString() : ua.toStringAsFixed(1)} UA';
    }
    return '${km.round()} KM';
  }
}
