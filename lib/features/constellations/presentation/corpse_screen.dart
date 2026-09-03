import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_controller.dart';
import '../../../core/audio/audio_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/constants/app_layout.dart';
import '../../../core/haptics/kenos_haptics.dart';
import '../../../core/widgets/hud.dart';
import '../../cosmic_map/application/travel_camera.dart';
import '../data/constellation_repository.dart';

/// LA CONSTELLATION — its own threshold, its own gesture.
///
/// An echo is emptying ONESELF; a corpse is opening a space for
/// STRANGERS. Two acts of different natures — the corpse does not
/// live in the Mirror anymore, it has its own door on the map. The
/// seeder chooses poem or song, the ring is dropped near where the
/// eye rests, and the screen pops with the fresh id so the map can
/// offer the seeder the FIRST blind line (to their own poem they are
/// just another stranger).
class CorpseScreen extends ConsumerStatefulWidget {
  const CorpseScreen({super.key});

  @override
  ConsumerState<CorpseScreen> createState() => _CorpseScreenState();
}

class _CorpseScreenState extends ConsumerState<CorpseScreen> {
  bool _dropping = false;

  Future<void> _drop(ConstellationKind kind) async {
    if (_dropping) return;
    setState(() => _dropping = true);
    KenosHaptics.pulse(KenosPulse.seal);
    try {
      final eye = ref.read(travelPositionProvider);
      final rng = Random();
      final meta = await ref.read(constellationRepositoryProvider).seed(
            (eye.dx + (rng.nextDouble() - 0.5) * 0.12).clamp(0.05, 0.95),
            (eye.dy + (rng.nextDouble() - 0.5) * 0.12).clamp(0.05, 0.95),
            kind: kind,
          );
      unawaited(
        ref.read(audioControllerProvider).playBell(KenosBell.send),
      );
      KenosHaptics.pulse(KenosPulse.launch);
      if (!mounted) return;
      Navigator.of(context).pop(meta.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _dropping = false);
      showHud(context, 'L\'ÉTHER A REFUSÉ LA CONSTELLATION.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dropping,
      child: Scaffold(
        backgroundColor: AppColors.voidBlack,
        body: SafeArea(
          // A dialog-like panel, centered with the app's shared
          // readable measure (wide screens included).
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.contentMaxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 18, 26, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Row(
                      children: [
                        Text(
                          'CONSTELLATION',
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 9,
                            letterSpacing: 4,
                            color: AppColors.fade(AppColors.indigo, 0.6),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed:
                              _dropping ? null : () => Navigator.of(context).pop(),
                          child: const Text('RENONCER'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Un poème à l\'aveugle',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.serifItalic,
                        fontSize: 26,
                        color: AppColors.fade(AppColors.pureLight, 0.92),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Des inconnus y écriront une ligne chacun,\n'
                      'chacun voyant seulement la ligne qui le\n'
                      'précède — ou une phrase de notes, au rythme\n'
                      'des doigts qui la jouent. Refermé, le poème\n'
                      'devient un artefact : lisible par tous.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.serifItalic,
                        fontSize: 16,
                        height: 1.9,
                        color: AppColors.fade(AppColors.pureLight, 0.62),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'L\'ANNEAU NAÎTRA PRÈS DE LÀ OÙ REPOSE TON REGARD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 8.5,
                        letterSpacing: 2,
                        color: AppColors.fade(AppColors.pureLight, 0.4),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 10,
                      children: [
                        OutlinedButton(
                          onPressed: _dropping
                              ? null
                              : () => _drop(ConstellationKind.poem),
                          child: Text(
                            _dropping ? 'SEMER…' : 'SEMER UN POÈME',
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _dropping
                              ? null
                              : () => _drop(ConstellationKind.melody),
                          child: Text(
                            _dropping ? 'SEMER…' : 'SEMER UNE CHANSON',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'TU LE LIRAS REFERMÉ — JAMAIS EN TRAIN DE SE FAIRE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 8,
                        letterSpacing: 2,
                        color: AppColors.fade(AppColors.pureLight, 0.3),
                      ),
                    ),
                  ],
                ),
),
),
),
),
),
),
  );
  }
}
