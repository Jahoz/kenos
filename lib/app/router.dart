import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_durations.dart';
import '../features/cosmic_map/presentation/map_screen.dart';
import '../features/create_echo/presentation/mirror_screen.dart';
import '../features/echo/data/echo_providers.dart';
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
        pageBuilder: (context, state) => _fade(child: const SizedBox.shrink()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _fade(child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/space',
        pageBuilder: (context, state) => _fade(child: const MapScreen()),
      ),
      GoRoute(
        path: '/mirror',
        pageBuilder: (context, state) => _fade(child: const MirrorScreen()),
      ),
    ],
  );
});

CustomTransitionPage<void> _fade({required Widget child}) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: AppDurations.routeFade,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
