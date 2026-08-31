import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../echo/data/echo_providers.dart';

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
              ],
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

class _StatCard extends StatelessWidget {
  const _StatCard({
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
