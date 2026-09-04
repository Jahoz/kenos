import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/constants/app_layout.dart';
import '../data/constellation_repository.dart';

/// LE SALON — the link shown once (V3.19).
///
/// The seeder receives the ring's only key at the drop. This panel is
/// the ONE moment it exists on a screen: after 'J'AI PARTAGÉ' it is
/// never shown again — the void does not keep it, exactly like a
/// reception. Sharing is the system sheet when it lives, the honest
/// clipboard otherwise.

/// Where invite links point. A build-time origin wins (the deployed
/// PWA); on the web the current origin speaks; a native build without
/// a known origin returns empty — the panel then says the truth
/// instead of sharing a broken link.
String salonLinkOrigin() {
  const fromBuild = String.fromEnvironment('SALON_LINK_ORIGIN');
  if (fromBuild.isNotEmpty) return fromBuild;
  if (kIsWeb) {
    final base = Uri.base;
    if (base.scheme.startsWith('http')) return base.origin;
  }
  return '';
}

/// The full invite URL: `https://<origin>/#/c/<token>` (hash routing,
/// zero server config — ready for universal links the day of stores).
String salonInviteLink(String token) {
  final origin = salonLinkOrigin();
  return origin.isEmpty ? '/#/c/$token' : '$origin/#/c/$token';
}

Future<void> showSalonShareSheet(
  BuildContext context, {
  required ConstellationMeta meta,
  required String inviteToken,
}) {
  return showGeneralDialog(
    context: context,
    // The key is precious: no accidental dismissal — only the honest
    // 'J'AI PARTAGÉ' closes this door.
    barrierDismissible: false,
    barrierLabel: 'KENOS_SALON',
    barrierColor: AppColors.voidBlack,
    transitionDuration: const Duration(milliseconds: 500),
    useRootNavigator: true,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _SalonSharePanel(meta: meta, inviteToken: inviteToken),
      );
    },
  );
}

class _SalonSharePanel extends StatefulWidget {
  const _SalonSharePanel({required this.meta, required this.inviteToken});

  final ConstellationMeta meta;
  final String inviteToken;

  @override
  State<_SalonSharePanel> createState() => _SalonSharePanelState();
}

class _SalonSharePanelState extends State<_SalonSharePanel> {
  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: salonInviteLink(widget.inviteToken),
          title: 'On t’invite en salon — KENOS',
        ),
      );
    } catch (_) {
      // No system sheet on this platform (or the test VM): the
      // clipboard carries the key, honestly.
      await _copy(quiet: true);
    }
  }

  Future<void> _copy({bool quiet = false}) async {
    try {
      await Clipboard.setData(
        ClipboardData(text: salonInviteLink(widget.inviteToken)),
      );
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
    final link = salonInviteLink(widget.inviteToken);
    final linkless = !link.startsWith('http');
    final isSong = widget.meta.kind == ConstellationKind.melody;
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
                          'LE SALON',
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
                      'L’anneau attend ses invités',
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
                      'Ce lien est la seule clé de l’anneau.\n'
                      'Chaque porteur posera ${isSong ? 'une phrase' : 'une ligne'} — '
                      'jusqu’à ${widget.meta.target}.\n'
                      'Refermé, ${isSong ? 'la chanson' : 'le poème'} rejoindra l’éther :\n'
                      'lisible par tous.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.serifItalic,
                        fontSize: 16,
                        height: 1.9,
                        color: AppColors.fade(AppColors.pureLight, 0.62),
                      ),
                    ),
                    const SizedBox(height: 30),
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
                        key: const ValueKey('salon_link'),
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
                              'DONNE-LE À QUI TU CHOISIS — OU GARDE-LE.',
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
                          key: const ValueKey('salon_share'),
                          onPressed: _share,
                          child: const Text('PARTAGER LE LIEN'),
                        ),
                        OutlinedButton(
                          key: const ValueKey('salon_copy'),
                          onPressed: () => _copy(),
                          child: const Text('COPIER'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: TextButton(
                        key: const ValueKey('salon_shared'),
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        child: const Text('J’AI PARTAGÉ'),
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
