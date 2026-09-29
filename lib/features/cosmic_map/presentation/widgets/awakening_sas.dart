import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_meta.dart';
import '../../../../core/haptics/kenos_haptics.dart';
import '../../../../core/utils/motion_preferences.dart';
import '../../../../core/voice/kenos_voice.dart';
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
///
/// V3.89 — THE ACCORD: the first door also carries the pact. A
/// traveller who has never accepted the terms of the ether meets
/// them here, before entering — readably, once, in their own tongue
/// (the voice dresses doors). The pact is a deliberate gesture: no
/// tap-the-void shortcut while it waits, one button, and the barrier
/// holds. Acceptance is remembered per version; the Braise's honest
/// death carries it away, and a re-born body signs again.
Future<void> maybeShowAwakening(BuildContext context, WidgetRef ref) async {
  final stats = await ref.read(userStatsProvider.future);
  final store = ref.read(localEchoStoreProvider);
  final news = stats.hasAwakeningToTell;
  final pactPending = !(await store.hasPact(kAubePactVersion));
  if (!news && !pactPending) return;
  if (!context.mounted) return;

  await showGeneralDialog(
    context: context,
    // News may be dismissed at a touch; the accord may not — nothing
    // enters without accepting the terms of the place.
    barrierDismissible: !pactPending,
    barrierLabel: 'KENOS_AUBE',
    barrierColor: AppColors.voidBlack,
    transitionDuration: const Duration(milliseconds: 700),
    useRootNavigator: true,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _AwakeningPanel(stats: stats, news: news, pactPending: pactPending),
      );
    },
  );

  // The visit is recorded only when the sas has actually spoken:
  // what was unseen becomes seen, next time it stays silent about it.
  if (news) {
    unawaited(ref.read(localEchoStoreProvider).recordVisit());
  }
  // The accord closes only one way: the button. Reaching here with a
  // pending pact means it was pressed.
  if (pactPending) {
    unawaited(ref.read(localEchoStoreProvider).recordPact(kAubePactVersion));
  }
}

class _AwakeningPanel extends ConsumerStatefulWidget {
  const _AwakeningPanel({
    required this.stats,
    required this.news,
    required this.pactPending,
  });

  final UserStats stats;

  /// Whether the sas carries news from the absence (V3.89: it may
  /// open for the accord alone, with nothing to tell).
  final bool news;

  /// Whether the ether's pact still waits — the accord replaces the
  /// tap-the-void exit with one deliberate button.
  final bool pactPending;

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
    final voice = ref.read(voiceProvider);
    final lines = widget.news ? widget.stats.awakeningLines() : const <String>[];
    final waiting =
        widget.news ? widget.stats.receptionsSinceLastVisit : 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // The void answers a touch only once the pact is signed: the
      // accord is a gesture, never a stray tap.
      onTap: widget.pactPending ? null : _enter,
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
                if (widget.pactPending) ...[
                  const SizedBox(height: 30),
                  // The terms may be longer than a small screen is tall:
                  // they scroll, they never truncate — an accord must be
                  // readable in full before it is signed.
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            voice.pick(
                              'LE PACTE DE L\'ÉTHER',
                              'THE PACT OF THE ETHER',
                            ),
                            style: TextStyle(
                              fontFamily: AppFonts.mono,
                              fontSize: 10,
                              letterSpacing: 4,
                              color: AppColors.fade(AppColors.teal, 0.9),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            voice.pick(
                              'Ici, personne n\'a de nom. Ce que tu scelles part '
                              'illisible — même pour nous.\n\n'
                              'Une pensée, un seul inconnu, une seule lecture. '
                              'Puis le vide.\n\n'
                              'La seule ligne en clair est gardée : l\'illicite '
                              'brûle, la douleur reste libre.\n\n'
                              'Si un soir ça pèse, des lignes écoutent : 3114, '
                              '3919, 0 800 05 123 4, 119 — et le 15 en urgence.\n\n'
                              'Sois doux avec les inconnus. L\'anonymat est le '
                              'contrat.',
                              'Here, no one has a name. What you seal leaves '
                              'unreadable — even to us.\n\n'
                              'One thought, one stranger, one single read. Then '
                              'the void.\n\n'
                              'The only clear line is guarded: the illicit burns, '
                              'pain stays free.\n\n'
                              'If a night weighs too much, lines listen: 3114, '
                              '3919, 0 800 05 123 4, 119 (France) — and 15 in an '
                              'emergency.\n\n'
                              'Be gentle with strangers. Anonymity is the '
                              'contract.',
                            ),
                            textAlign: TextAlign.center,
                            // V3.90 — a pact must be READABLE: an accord in
                            // 14.5 px italic at 80% was punishment on a narrow
                            // phone (live report, S25). The terms now speak at
                            // the confidences' own size, near-full light.
                            style: TextStyle(
                              fontFamily: AppFonts.serifItalic,
                              fontSize: 16.5,
                              height: 1.75,
                              color: AppColors.fade(AppColors.pureLight, 0.92),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(flex: 3),
                if (widget.pactPending)
                  OutlinedButton(
                    onPressed: _enter,
                    child: Text(
                      voice.pick('J\'ACCEPTE — JE RENTRE', 'I ACCEPT — I ENTER'),
                    ),
                  )
                else
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
