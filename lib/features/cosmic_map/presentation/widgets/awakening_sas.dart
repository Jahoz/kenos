import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/haptics/kenos_haptics.dart';
import '../../../../core/utils/motion_preferences.dart';
import '../../../../core/widgets/scramble_text.dart';
import '../../../echo/data/echo_providers.dart';
import '../../../echo/data/user_stats_store.dart';

/// L'Aube — the notification replacement (manifest V2 §2E).
///
/// At app open, IF anything happened during the absence, the user
/// crosses a short sas: poetic lines, a warm ember dot breathing,
/// then the map. Nothing is ever pushed afterwards — the ritual
/// happens once, at the threshold, and stays silent when there is
/// nothing to tell.
Future<void> maybeShowAwakening(BuildContext context, WidgetRef ref) async {
  final stats = await ref.read(userStatsProvider.future);
  if (!stats.hasAwakeningToTell) return;
  if (!context.mounted) return;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'KENOS_AUBE',
    barrierColor: AppColors.voidBlack,
    transitionDuration: const Duration(milliseconds: 700),
    useRootNavigator: true,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _AwakeningPanel(stats: stats),
      );
    },
  );

  // The visit is recorded only when the sas has actually spoken:
  // what was unseen becomes seen, next time it stays silent about it.
  unawaited(ref.read(localEchoStoreProvider).recordVisit());
}

class _AwakeningPanel extends ConsumerStatefulWidget {
  const _AwakeningPanel({required this.stats});

  final UserStats stats;

  @override
  ConsumerState<_AwakeningPanel> createState() => _AwakeningPanelState();
}

class _AwakeningPanelState extends ConsumerState<_AwakeningPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (!platformDisablesAnimations()) {
      _breath.repeat(reverse: true);
    } else {
      _breath.value = 0.5;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  void _enter() {
    KenosHaptics.pulse(KenosPulse.holdComplete,
        reduceMotion: platformDisablesAnimations());
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.stats.awakeningLines();
    final waiting = widget.stats.receptionsSinceLastVisit;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _enter,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            // Wide screens (tablets, desktop): the sas keeps its
            // readable measure, centered in the void — never a full
            // 1200 px column pinned to nothing.
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 560,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34),
                child: Column(
                  children: [
                const Spacer(flex: 5),
                // The warm ember: the origin node, breathing.
                AnimatedBuilder(
                  animation: _breath,
                  builder: (context, _) {
                    final t = _breath.value;
                    final glow = 0.35 + 0.45 * t;
                    return Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.pureLight,
                            AppColors.ember,
                            AppColors.fade(AppColors.emberSoft, 0),
                          ],
                          stops: const [0, 0.42, 1],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.fade(AppColors.ember, glow * 0.5),
                            blurRadius: 34 + 26 * t,
                            spreadRadius: 2 + 6 * t,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Spacer(flex: 2),
                Text(
                  'L\'AUBE',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    letterSpacing: 6,
                    color: AppColors.fade(AppColors.ember, 0.75),
                  ),
                ),
                const SizedBox(height: 30),
                // The lines emerge one after the other, like decryption.
                for (final (i, line) in lines.indexed) ...[
                  ScrambleText(
                    text: line,
                    resolve: true,
                    duration: Duration(milliseconds: 900 + i * 350),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.serifItalic,
                      fontSize: 19,
                      height: 1.75,
                      color: AppColors.fade(AppColors.pureLight, 0.92),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (waiting > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    waiting == 1
                        ? 'UN SIGNAL ATTEND — TOUCHE TON ÉTOILE QUI PULSE'
                        : '$waiting SIGNAUX ATTENDENT — TOUCHE TES ÉTOILES QUI PULSENT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 9,
                      letterSpacing: 3,
                      color: AppColors.fade(AppColors.teal, 0.85),
                    ),
                  ),
                ],
                const Spacer(flex: 3),
                Text(
                  'TOUCHE LE VIDE POUR ENTRER',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    letterSpacing: 4,
                    color: AppColors.fade(AppColors.pureLight, 0.35),
                  ),
                ),
                const SizedBox(height: 26),
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
