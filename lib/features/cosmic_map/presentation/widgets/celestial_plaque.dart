import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/haptics/kenos_haptics.dart';
import '../../application/celestial_bodies.dart';

/// V3.12 — the celestial plaque: tap (or hover-travel) a named body and
/// the sky explains itself — what this world holds, which intention's
/// echoes orbit it, and for the wanderers, the open question they are.
Future<void> showCelestialPlaque(
  BuildContext context, {
  required CelestialBody body,
  int orbitCount = 0,
  VoidCallback? onTravel,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'KENOS_PLAQUE',
    barrierColor: AppColors.voidBlack,
    transitionDuration: const Duration(milliseconds: 500),
    useRootNavigator: true,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _PlaquePanel(body: body, orbitCount: orbitCount, onTravel: onTravel),
      );
    },
  );
}

class _PlaquePanel extends StatelessWidget {
  const _PlaquePanel({
    required this.body,
    required this.orbitCount,
    this.onTravel,
  });

  final CelestialBody body;
  final int orbitCount;
  final VoidCallback? onTravel;

  @override
  Widget build(BuildContext context) {
    final anchorColor = body.theme?.core ?? AppColors.pureLight;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          color: AppColors.fade(AppColors.voidBlack, 0.72),
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    body.kindLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 8.5,
                      letterSpacing: 3,
                      color: AppColors.fade(AppColors.cyan, 0.6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    body.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 34,
                      letterSpacing: 2,
                      color: AppColors.fade(AppColors.pureLight, 0.95),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    body.poem,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.serifItalic,
                      fontSize: 16.5,
                      height: 1.75,
                      color: AppColors.fade(AppColors.pureLight, 0.6),
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (body.isAnchor || body.kind == CelestialKind.beacon) ...[
                    Text(
                      'INTENTION — ${body.intention}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 9,
                        letterSpacing: 3,
                        color: AppColors.fade(anchorColor, 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Les échos lancés pour ${body.intention!.toLowerCase()} '
                      'orbitent ici.\n$orbitCount écho${orbitCount > 1 ? 's' : ''} '
                      '${orbitCount > 1 ? 'dérivent' : 'dérive'} autour d\'elle en ce moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 9.5,
                        letterSpacing: 1,
                        height: 1.9,
                        color: AppColors.fade(AppColors.pureLight, 0.5),
                      ),
                    ),
                    const SizedBox(height: 34),
                    if (onTravel != null)
                      OutlinedButton(
                        onPressed: () {
                          KenosHaptics.pulse(KenosPulse.themePick);
                          Navigator.of(context, rootNavigator: true).pop();
                          onTravel!();
                        },
                        child: const Text('VOYAGER VERS'),
                      ),
                  ] else ...[
                    Text(
                      'RIEN N\'ORBITE ICI — PAS ENCORE.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 9,
                        letterSpacing: 3,
                        color: AppColors.fade(AppColors.pureLight, 0.4),
                      ),
                    ),
                    const SizedBox(height: 34),
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      child: const Text('REVENIR AU VIDE'),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
