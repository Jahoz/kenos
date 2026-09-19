import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../braise/data/braise_repository.dart';
import '../../braise/domain/braise_ballot.dart';
import '../../braise/domain/braise_link.dart';
import '../../braise/presentation/braise_forge_sheet.dart';
import '../../constellations/data/salon_anchor_store.dart';
import '../../echo/data/echo_providers.dart';
import '../../echo/data/echo_repository.dart';

/// Anonymous, local observations of what has resonated in the ether.
class ImpactScreen extends ConsumerWidget {
  const ImpactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      appBar: AppBar(
        backgroundColor: AppColors.voidBlack,
        foregroundColor: AppColors.pureLight,
        title: Text(
          'TON IMPACT',
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 11,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: stats.when(
        data: (userStats) => SingleChildScrollView(
          // Wide screens: the ledger keeps its readable measure,
          // centered — same grammar as the Aube and the Mirror.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 560,
              ),
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.fade(AppColors.cyan, 0.3),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'CE QUI A RÉSONNÉ',
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 9,
                          letterSpacing: 2,
                          color: AppColors.fade(AppColors.pureLight, 0.5),
                        ),
                      ),
                      Text(
                        userStats.resonanceMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.serifItalic,
                          fontSize: 20,
                          height: 1.5,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aucun rang. Rien à collectionner.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.serifItalic,
                          fontSize: 13,
                          height: 1.6,
                          color: AppColors.fade(AppColors.pureLight, 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Stats grid
                _StatCard(
                  label: 'Échos créés',
                  value: userStats.totalEchosSent.toString(),
                  color: AppColors.teal,
                  icon: Icons.auto_awesome_outlined,
                ),
                const SizedBox(height: 16),
                _StatCard(
                  label: 'Réceptions reçues',
                  value: userStats.totalReceptionsReceived.toString(),
                  color: AppColors.indigo,
                  icon: Icons.mark_email_unread_outlined,
                ),
                const SizedBox(height: 16),
                _StatCard(
                  label: 'Traces laissées',
                  value: userStats.totalTracesLeft.toString(),
                  color: AppColors.cyan,
                  icon: Icons.edit_outlined,
                ),
                const SizedBox(height: 16),
                _StatCard(
                  label: 'Échos lus',
                  value: userStats.readCount.toString(),
                  color: AppColors.purple,
                  icon: Icons.visibility_outlined,
                ),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'Ces traces ne quittent pas cet appareil.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.serifItalic,
                      fontSize: 14,
                      height: 1.8,
                      color: AppColors.fade(AppColors.pureLight, 0.5),
                    ),
                  ),
                ),
                // LA BRAISE (V3.60): the only door out of a body — one
                // discreet line at the bottom of the ledger, nowhere
                // else. The threshold and the sky never speak of it.
                const SizedBox(height: 24),
                const _BraiseForgeLine(),
                  ],
                ),
              ),
            ),
          ),
        ),
        loading: () => Center(
          child: Text(
            'CHARGEMENT…',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 9,
              letterSpacing: 3,
              color: AppColors.fade(AppColors.pureLight, 0.4),
            ),
          ),
        ),
        error: (_, _) => Center(
          child: Text(
            'ERREUR',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 9,
              letterSpacing: 3,
              color: AppColors.fade(AppColors.rose, 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

/// LA BRAISE — the discreet forge line (V3.60). One tap: the body's
/// memories are sealed into the passage link and the ember is minted
/// server-side (fingerprint only, ten minutes). The link is shown
/// once, by the forge sheet — the ledger never speaks of it again.
class _BraiseForgeLine extends ConsumerStatefulWidget {
  const _BraiseForgeLine();

  @override
  ConsumerState<_BraiseForgeLine> createState() => _BraiseForgeLineState();
}

class _BraiseForgeLineState extends ConsumerState<_BraiseForgeLine> {
  Future<void> _forge() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final store = ref.read(localEchoStoreProvider);
      final stats = await store.readStats();
      final doors = ref.read(salonAnchorStoreProvider);
      await doors.load();
      final ballot = BraiseBallot(
        onboarded: true,
        stats: stats,
        freqGuideSeen: await store.hasFrequenciesGuideSeen(),
        corpseGuideSeen: await store.hasCorpseGuideSeen(),
        eyeGuideSeen: await store.hasEyeGuideSeen(),
        anchors: doors.open().take(BraiseBallot.maxAnchors).toList(),
      );
      final key = await ref.read(braiseRepositoryProvider).forge();
      final link = BraiseLink.forge(key, await BraiseBallot.pack(ballot, key));
      // The sheet holds the screen the link exists on: it waits for a
      // living one, like every share panel.
      if (!mounted) return;
      await showBraiseForgeSheet(context, link: link);
    } catch (e) {
      // An extinguished body forges no new ember; the sky may also be
      // far — either way the ledger says it, honestly.
      messenger.showSnackBar(
        SnackBar(content: Text(KenosException.from(e).hudMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        key: const ValueKey('braise_forge'),
        onPressed: _forge,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.fade(AppColors.ember, 0.55),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: const Text(
          'TRANSMETTRE LA BRAISE',
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 8,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.fade(color, 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 9,
                  letterSpacing: 1,
                  color: AppColors.fade(color, 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 28,
                  color: color,
                ),
              ),
            ],
          ),
          Icon(
            icon,
            size: 28,
            color: AppColors.fade(color, 0.72),
          ),
        ],
      ),
    );
  }
}
