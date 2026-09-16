import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/haptics/kenos_haptics.dart';
import '../../application/celestial_bodies.dart';
import '../../application/sky_link.dart';

/// V3.12 — the celestial plaque: tap (or hover-travel) a named body and
/// the sky explains itself — what this world holds, which intention's
/// echoes orbit it, and for the wanderers, the open question they are.
/// V3.49 — the plaque can SHARE its place: a link that lands another
/// eye right where this body drifts (its live position).
Future<void> showCelestialPlaque(
  BuildContext context, {
  required CelestialBody body,
  int orbitCount = 0,
  VoidCallback? onTravel,
  Offset? sharePosition,
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
          child: _PlaquePanel(
            body: body,
            orbitCount: orbitCount,
            onTravel: onTravel,
            sharePosition: sharePosition,
          ),
        );
      },
  );
}

class _PlaquePanel extends StatelessWidget {
  const _PlaquePanel({
    required this.body,
    required this.orbitCount,
    this.onTravel,
    this.sharePosition,
  });

  final CelestialBody body;
  final int orbitCount;
  final VoidCallback? onTravel;

  /// V3.49 — the body's live position (the place a shared link
  /// lands on); null hides the sharing door.
  final Offset? sharePosition;

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
                    // V3.49 — the place, shareable: a link that lands
                    // another eye on this world's live position.
                    if (sharePosition != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () => unawaitedShare(
                            SkyLink.shareUrl(sharePosition!),
                          ),
                          child: const Text('PARTAGER CE LIEU'),
                        ),
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
                    if (sharePosition != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () => unawaitedShare(
                            SkyLink.shareUrl(sharePosition!),
                          ),
                          child: const Text('PARTAGER CE LIEU'),
                        ),
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

/// Share, fire-and-forget (the audio law's own grammar: never a
/// point of failure, never a block).
void unawaitedShare(String url) {
  SharePlus.instance.share(ShareParams(text: url, title: 'KENOS'));
}
