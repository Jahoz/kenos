import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/audio_controller.dart';
import '../../../core/audio/audio_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/constants/app_layout.dart';
import '../../../core/voice/kenos_voice.dart';
import '../../echo/data/echo_providers.dart';

/// The threshold: three rules, one gate. Passed once, never seen again.
/// An invited guest crosses it on their way somewhere (LE SALON's
/// claim) — `returnTo` says where the door opens after the rules, and
/// `onEntered` lets an embedding screen react without waiting for a
/// navigation that may be a same-location no-op.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key, this.returnTo = '/space', this.onEntered});

  final String returnTo;
  final VoidCallback? onEntered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // V3.52 — the first journey speaks the traveller's English when
    // the web build meets it; French stays canonical everywhere else.
    final voice = ref.watch(voiceProvider);
    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      body: SafeArea(
        child: Center(
          // Full-bleed sky, but the rules themselves keep their
          // measure: on a wide window they stand in a centered column
          // of readable width, the void all around.
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  Text(
                    'KENOS',
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 46,
                      letterSpacing: 14,
                      color: AppColors.pureLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    voice.pick(
                      'se vider de soi-même',
                      'emptying of oneself',
                    ),
                    style: TextStyle(
                      fontFamily: AppFonts.serifItalic,
                      fontSize: 15,
                      color: AppColors.fade(AppColors.pureLight, 0.55),
                    ),
                  ),
                  const Spacer(flex: 2),
                  _Rule(
                    index: '01',
                    text: voice.pick(
                      'Aucun profil, aucun nom, aucune trace. '
                      'Ce que tu lances ici n\'a pas de retour.',
                      'No profile, no name, no trail. What you release '
                      'here never comes back.',
                    ),
                  ),
                  _Rule(
                    index: '02',
                    text: voice.pick(
                      'Chaque écho ne peut être lu qu\'une seule fois, '
                      'par une seule personne — jamais toi.',
                      'Each echo can be read only once, by one single '
                      'stranger — never you.',
                    ),
                  ),
                  _Rule(
                    index: '03',
                    text: voice.pick(
                      'Rien à gagner. Pas de likes, pas de commentaires. '
                      'On donne pour se libérer.',
                      'Nothing to win. No likes, no comments. '
                      'We give to let go.',
                    ),
                  ),
                  const Spacer(flex: 2),
                  // The reception field taught in one line: the bottle
                  // in the sea is searched for, at distance.
                  Text(
                    voice.pick(
                      'POUR LIRE UN ÉCHO : MAINTIEN SON ÉTOILE TROIS SECONDES, '
                      'À PORTÉE DE TON ŒIL.',
                      'TO READ AN ECHO: HOLD ITS STAR FOR THREE SECONDS, '
                      'WITHIN YOUR EYE\'S REACH.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 9,
                      letterSpacing: 2,
                      height: 1.8,
                      color: AppColors.fade(AppColors.teal, 0.75),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () {
                      // Audio accompanies the entry, persistence never
                      // delays it: the threshold is crossed immediately.
                      final audio = ref.read(audioControllerProvider);
                      audio.ensureStarted();
                      audio.playBell(KenosBell.seal);
                      unawaited(
                        ref.read(localEchoStoreProvider).setOnboarded(),
                      );
                      // V3.50 — the LIVE threshold flips with the
                      // store write: the router trusts it, and the
                      // door opens back where the visitor was going.
                      ref.read(onboardedProvider.notifier).state = true;
                      onEntered?.call();
                      context.go(returnTo);
                    },
                    child: Text(voice.pick('ENTRER', 'ENTER')),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.index, required this.text});

  final String index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              index,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 10,
                letterSpacing: 2,
                color: AppColors.fade(AppColors.teal, 0.8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppFonts.serifItalic,
                fontSize: 15.5,
                height: 1.65,
                color: AppColors.fade(AppColors.pureLight, 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
