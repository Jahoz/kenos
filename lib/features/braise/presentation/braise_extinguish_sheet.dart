import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/constants/app_layout.dart';

/// LA BRAISE — the extinguishing (V3.60a). ROSE is the law: this is
/// destruction, the only destructive local gesture in the product.
///
/// Offered when a body that already transmitted its ember tries to
/// forge again: what it still holds here — souvenirs, doors, scars —
/// serves no one anymore. It may go dark, gently; the traveller can
/// then cross the Seuil again and be born a stranger.
Future<bool?> showBraiseExtinguishSheet(BuildContext context) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'KENOS_BRAISE_EXTINGUISH',
    barrierColor: AppColors.voidBlack,
    transitionDuration: const Duration(milliseconds: 500),
    useRootNavigator: true,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: const _BraiseExtinguishPanel(),
      );
    },
  );
}

class _BraiseExtinguishPanel extends StatelessWidget {
  const _BraiseExtinguishPanel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
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
                          'LA BRAISE',
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 9,
                            letterSpacing: 4,
                            // ROSE is reserved for destruction — this
                            // panel is the one place a traveller meets
                            // it on their own body.
                            color: AppColors.fade(AppColors.rose, 0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'Ce corps a déjà transmis',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.serifItalic,
                        fontSize: 26,
                        height: 1.5,
                        color: AppColors.fade(AppColors.pureLight, 0.92),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Sa braise vit sur un autre appareil.\n'
                      'Ce qu’il garde encore ici — souvenirs,\n'
                      'portes, cicatrices — ne sert plus personne.\n'
                      'Il peut s’éteindre, doucement.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.serifItalic,
                        fontSize: 16,
                        height: 1.9,
                        color: AppColors.fade(AppColors.pureLight, 0.62),
                      ),
                    ),
                    const SizedBox(height: 40),
                    OutlinedButton(
                      key: const ValueKey('braise_extinguish'),
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rose,
                        side: BorderSide(
                          color: AppColors.fade(AppColors.rose, 0.4),
                        ),
                      ),
                      child: const Text('ÉTEINDRE CE CORPS'),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        key: const ValueKey('braise_stay'),
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        child: const Text('RESTER ENCORE'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
