import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/constants/app_layout.dart';

/// LA BRAISE — the link shown once (V3.60).
///
/// The old body receives its passage key at the forge. This panel is
/// the ONE moment it exists on a screen: after 'J'AI TRANSMIS' it is
/// never shown again — and the link itself dies within ten minutes
/// whether or not it was opened. Discreet by design: nothing here
/// ever touches the threshold or the sky.

Future<void> showBraiseForgeSheet(
  BuildContext context, {
  required String link,
}) {
  return showGeneralDialog(
    context: context,
    // The ember is precious: no accidental dismissal — only the
    // honest 'J'AI TRANSMIS' closes this door.
    barrierDismissible: false,
    barrierLabel: 'KENOS_BRAISE',
    barrierColor: AppColors.voidBlack,
    transitionDuration: const Duration(milliseconds: 500),
    useRootNavigator: true,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _BraiseForgePanel(link: link),
      );
    },
  );
}

class _BraiseForgePanel extends StatefulWidget {
  const _BraiseForgePanel({required this.link});

  final String link;

  @override
  State<_BraiseForgePanel> createState() => _BraiseForgePanelState();
}

class _BraiseForgePanelState extends State<_BraiseForgePanel> {
  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: widget.link, title: 'La braise — KENOS'),
      );
    } catch (_) {
      // No system sheet on this platform (or the test VM): the
      // clipboard carries the ember, honestly.
      await _copy(quiet: true);
    }
  }

  Future<void> _copy({bool quiet = false}) async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.link));
    } catch (_) {
      // The clipboard refused: silence — the link is still on screen,
      // selectable.
    }
    if (!mounted || quiet) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('LIEN COPIÉ.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final linkless = !link.startsWith('http');
    // The ember's own light: a standard-contrast chip the new device's
    // camera can read from across the table. Past the QR ceiling the
    // text link stays the honest road — the chip simply does not burn.
    final qrFits = link.length <= 2900;
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
                            color: AppColors.fade(AppColors.ember, 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'Ce lien est ton corps',
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
                      'Ouvre-le sur ton autre appareil.\n'
                      'Ce que ce corps était l’y attendra :\n'
                      'les bouteilles, les portes, les anneaux.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.serifItalic,
                        fontSize: 16,
                        height: 1.9,
                        color: AppColors.fade(AppColors.pureLight, 0.62),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (qrFits)
                      Center(
                        child: Container(
                          key: const ValueKey('braise_qr'),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.pureLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SizedBox(
                            width: 176,
                            height: 176,
                            child: QrImageView(
                              data: link,
                              version: QrVersions.auto,
                              backgroundColor: AppColors.pureLight,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: AppColors.voidBlack,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: AppColors.voidBlack,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    if (qrFits) const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.fade(AppColors.ember, 0.35),
                        ),
                      ),
                      child: SelectableText(
                        link,
                        key: const ValueKey('braise_link'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 10.5,
                          height: 1.7,
                          letterSpacing: 1,
                          color: AppColors.fade(AppColors.pureLight, 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      linkless
                          ? 'CET APPAREIL NE CONNAÎT PAS L’ORIGINE DU LIEN —\n'
                              'LA CLÉ EST LÀ, COPIABLE, MAIS LE LIEN COMPLET\n'
                              'VIT SUR LE WEB.'
                          : 'CE LIEN NE SERA PLUS MONTRE ICI.\n'
                              'IL MEURT DANS DIX MINUTES — OUVERT OU NON.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 8,
                        letterSpacing: 2,
                        height: 1.8,
                        color: AppColors.fade(AppColors.ember, 0.75),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 10,
                      children: [
                        OutlinedButton(
                          key: const ValueKey('braise_share'),
                          onPressed: _share,
                          child: const Text('PARTAGER LE LIEN'),
                        ),
                        OutlinedButton(
                          key: const ValueKey('braise_copy'),
                          onPressed: () => _copy(),
                          child: const Text('COPIER'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: TextButton(
                        key: const ValueKey('braise_shared'),
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        child: const Text('J’AI TRANSMIS'),
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
