import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/haptics/kenos_haptics.dart';
import '../../../../core/utils/motion_preferences.dart';
import '../../../echo/data/echo_providers.dart';

/// The origin node (manifest V2 §2E): the user's warm anchor on the
/// map. Its ember aura breathes with accumulated stardust — one mote
/// per human touched, one per stranger's thought carried. Tapping it
/// opens the quiet impact observation (never a score, never a rank).
class OriginNode extends ConsumerWidget {
  const OriginNode({super.key, this.side = 64});

  final double side;

  static const int _maxVisibleMotes = 9;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userStatsProvider).valueOrNull;
    final stardust = stats?.stardust ?? 0;
    final reduced = context.wantsReducedMotion;
    final motes = math.min(stardust, _maxVisibleMotes);

    return Semantics(
      label:
          'Ton nœud d\'origine — $stardust poussière${stardust > 1 ? 's' : ''} d\'étoile',
      button: true,
      child: GestureDetector(
        onTap: () {
          KenosHaptics.pulse(KenosPulse.themePick, reduceMotion: reduced);
          context.push('/impact');
        },
        // The hidden door: a long press on L'Aube opens the guardian's
        // threshold. Unmarked by design — the sky keeps its secrets,
        // even its own observation.
        onLongPress: () {
          KenosHaptics.pulse(KenosPulse.themePick, reduceMotion: reduced);
          context.push('/observatoire');
        },
        child: SizedBox(
          width: side,
          height: side,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The breathing ember core.
              _EmberBreath(stardust: stardust, reduced: reduced),
              // Stardust motes: impact made visible, capped so the map
              // stays a void, not a trophy shelf.
              for (var i = 0; i < motes; i++)
                _StardustMote(index: i, total: motes, reduced: reduced),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmberBreath extends StatefulWidget {
  const _EmberBreath({required this.stardust, required this.reduced});

  final int stardust;
  final bool reduced;

  @override
  State<_EmberBreath> createState() => _EmberBreathState();
}

class _EmberBreathState extends State<_EmberBreath>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (widget.reduced) {
      _breath.value = 0.5;
    } else {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The more stardust, the warmer the glow — gently capped.
    final warmth = (0.35 + 0.05 * widget.stardust).clamp(0.35, 0.85);
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        final t = widget.reduced ? 0.5 : _breath.value;
        return Center(
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.pureLight,
                  AppColors.ember,
                  AppColors.fade(AppColors.emberSoft, 0),
                ],
                stops: const [0, 0.45, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.fade(
                    AppColors.ember,
                    warmth * (0.35 + 0.35 * t),
                  ),
                  blurRadius: 22 + 14 * t,
                  spreadRadius: 1 + 4 * t,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One mote of stardust, orbiting the node on its own slow angle.
class _StardustMote extends StatefulWidget {
  const _StardustMote({
    required this.index,
    required this.total,
    required this.reduced,
  });

  final int index;
  final int total;
  final bool reduced;

  @override
  State<_StardustMote> createState() => _StardustMoteState();
}

class _StardustMoteState extends State<_StardustMote>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: Duration(seconds: 9 + widget.index),
  );

  @override
  void initState() {
    super.initState();
    if (widget.reduced) {
      _orbit.value = widget.index / widget.total;
    } else {
      _orbit.repeat();
    }
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _orbit,
      builder: (context, _) {
        // Deterministic per-mote geometry: the constellation never
        // reshuffles between frames of the same life.
        final seed = (widget.index * 137.508) % 360; // golden angle
        final angle = (seed + _orbit.value * 360 - 90) * math.pi / 180;
        final radius = 16.0 + 8.0 * ((widget.index % 3) + 1) / 3 * 2;
        return Positioned(
          left: 32 + radius * math.cos(angle) - 1.5,
          top: 32 + radius * math.sin(angle) - 1.5,
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.fade(AppColors.ember, 0.75),
              boxShadow: [
                BoxShadow(
                  color: AppColors.fade(AppColors.ember, 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
