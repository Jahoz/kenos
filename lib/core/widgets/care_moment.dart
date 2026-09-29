import 'package:flutter/material.dart';

import '../care/care_guard.dart';
import '../constants/app_colors.dart';
import '../constants/app_fonts.dart';
import '../voice/kenos_voice.dart';

/// The care moment — the quiet hand (V3.88).
///
/// WARN, never block, never judge: the cry belongs to the one who
/// wrote it, and choosing belongs to them. The dialog names the doors
/// that exist — never the words that summoned it: what the author
/// wrote is theirs alone, and the resources belong to everyone.
///
/// Returns true to let the words drift anyway, false to take them
/// back. [reader] dresses the variant for the one who RECEIVED heavy
/// words: there the dialog has no take-back (nothing of theirs is
/// about to drift) — a single quiet return.
Future<bool> offerCareMoment(
  BuildContext context, {
  required KenosVoice voice,
  required Set<CareTheme> themes,
  required String continueLabel,
  String? takeBackLabel,
  bool reader = false,
}) async {
  final doors = <String>[
    for (final theme in CareTheme.values)
      ..._doorsFor(theme, voice),
  ];
  final proceed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.voidBlack,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.fade(AppColors.pureLight, 0.18)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                voice.pick('AVANT QUE ÇA DÉRIVE', 'BEFORE IT DRIFTS'),
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10,
                  letterSpacing: 3,
                  color: AppColors.fade(AppColors.teal, 0.85),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                reader
                    ? voice.pick(
                        'Ce que tu viens de recevoir peut peser lourd.\n\n'
                        'Si ces mots résonnent, tu n\'es pas obligé·e de les '
                        'porter seul·e — ces lignes écoutent :',
                        'What you just received may weigh heavy.\n\nIf these '
                            'words resonate, you don\'t have to carry them '
                            'alone — these lines listen:',
                      )
                    : voice.pick(
                        'Ce que tu écris semble porter une vraie douleur.\n\n'
                        'Tu n\'es pas obligé·e de la porter seul·e — ces '
                        'lignes écoutent :',
                        'What you are writing seems to carry real pain.\n\n'
                            'You don\'t have to carry it alone — these lines '
                            'listen:',
                      ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.serifItalic,
                  fontSize: 14,
                  height: 1.75,
                  color: AppColors.fade(AppColors.pureLight, 0.75),
                ),
              ),
              const SizedBox(height: 14),
              // The doors, in the lexicon's own quiet order — each one
              // names its purpose and its hours, nothing more.
              for (final door in doors) ...[
                Text(
                  door,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9.5,
                    letterSpacing: 1,
                    height: 1.9,
                    color: AppColors.fade(AppColors.teal, 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(continueLabel),
              ),
              if (!reader && takeBackLabel != null)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(takeBackLabel),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  return proceed ?? false;
}

/// The doors a theme opens — one line each: the number, the purpose,
/// the hours. The doors are French national lines — the product's own
/// ground — said so in English rather than translated away.
List<String> _doorsFor(CareTheme theme, KenosVoice voice) {
  switch (theme) {
    case CareTheme.detresse:
      return [
        voice.pick(
          '3114 — prévention du suicide, 24h/24, gratuit',
          '3114 — suicide prevention (France), 24/7, free',
        ),
        voice.pick(
          '15 ou 112 — en urgence, tout de suite',
          '15 or 112 — emergency, right now',
        ),
      ];
    case CareTheme.violences:
      return [
        voice.pick(
          '3919 — violences conjugales et familiales, écoute nationale',
          '3919 — domestic & family violence (France), national line',
        ),
      ];
    case CareTheme.agression:
      return [
        voice.pick(
          '0 800 05 123 4 — SOS Viols, écoute et accompagnement',
          '0 800 05 123 4 — SOS Viols, support line (France)',
        ),
      ];
    case CareTheme.enfance:
      return [
        voice.pick(
          '119 — enfance en danger, 24h/24',
          '119 — childhood in danger (France), 24/7',
        ),
      ];
  }
}
