import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_durations.dart';
import '../core/utils/motion_preferences.dart';
import '../features/cosmic_map/presentation/impact_screen.dart';
import '../features/cosmic_map/presentation/map_screen.dart';
import '../features/create_echo/presentation/mirror_screen.dart';
import '../features/echo/data/echo_providers.dart';
import '../features/frequencies/presentation/frequencies_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

/// KENOS routing: fades only, no abrupt screen changes.
final goRouterProvider = Provider<GoRouter>((ref) {
  final boot = ref.watch(bootstrapProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // The root gate decides: threshold (first run) or space.
      if (state.matchedLocation == '/') {
        return boot.hasOnboarded ? '/space' : '/onboarding';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _fade(context, child: const SizedBox.shrink()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _fade(context, child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/space',
        pageBuilder: (context, state) => _fade(context, child: const MapScreen()),
      ),
      GoRoute(
        path: '/mirror',
        pageBuilder: (context, state) => _fade(context, child: const MirrorScreen()),
      ),
      GoRoute(
        path: '/impact',
        pageBuilder: (context, state) => _fade(context, child: const ImpactScreen()),
      ),
      GoRoute(
        path: '/frequencies',
        pageBuilder: (context, state) => _fade(context, child: const FrequenciesScreen()),
      ),
    ],
  );
});

CustomTransitionPage<void> _fade(BuildContext context, {required Widget child}) {
  final reduced = context.wantsReducedMotion;
  return CustomTransitionPage<void>(
    child: child,
    // « Reduce animations »: screens appear at once, no fade theater.
    transitionDuration: reduced ? Duration.zero : AppDurations.routeFade,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Composite transition: fade + subtle upward drift + scale
      final curveAnim = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final scaleAnim = Tween<double>(begin: 0.97, end: 1.0).animate(curveAnim);
      final offsetAnim = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
          .animate(curveAnim);
      
      return FadeTransition(
        opacity: curveAnim,
        child: SlideTransition(
          position: offsetAnim,
          child: ScaleTransition(
            scale: scaleAnim,
            child: child,
          ),
        ),
      );
    },
  );
}
