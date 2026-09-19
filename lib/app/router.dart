import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_durations.dart';
import '../core/utils/motion_preferences.dart';
import '../features/braise/presentation/braise_claim_screen.dart';
import '../features/constellations/presentation/corpse_screen.dart';
import '../features/constellations/presentation/salon_claim_screen.dart';
import '../features/cosmic_map/application/sky_link.dart';
import '../features/cosmic_map/presentation/impact_screen.dart';
import '../features/cosmic_map/presentation/map_screen.dart';
import '../features/create_echo/presentation/mirror_screen.dart';
import '../features/echo/data/echo_providers.dart';
import '../features/frequencies/presentation/frequencies_screen.dart';
import '../features/observatory/presentation/observatory_screen.dart';
import '../features/observatory/presentation/vestige_module_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

/// KENOS routing: fades only, no abrupt screen changes.
final goRouterProvider = Provider<GoRouter>((ref) {
  final boot = ref.watch(bootstrapProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // V3.50 — the LIVE threshold, READ per navigation (never
      // watched: rebuilding the router mid-session would reset the
      // whole navigation to the initial location — the threshold
      // flip happened exactly once, and the sky fell back to the
      // heart). The immutable boot snapshot cannot learn that the
      // Seuil was crossed; this state can.
      final onboarded = ref.read(onboardedProvider);
      final loc = state.matchedLocation;
      final atThreshold = loc == '/onboarding';
      // LE SALON carries its OWN threshold (the rules inside the
      // claim): the global redirect never touches it. LA BRAISE
      // carries its own too (V3.60) — or none at all, when the sealed
      // ballot vouches that this traveller already crossed the rules
      // on another body.
      final atSalon = loc.startsWith('/c/');
      final atPassage = loc.startsWith('/pass/');
      if (!onboarded && !atThreshold && !atSalon && !atPassage) {
        // A fresh visitor on ANY door — a sky link, the Mirror, a
        // raw '/space' — meets the rules first, and the door opens
        // back after ENTRER ('vers': where they were going).
        return loc == '/'
            ? '/onboarding'
            : '/onboarding?vers=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (onboarded && atThreshold) return '/space';
      // The root gate decides: threshold (first run) or space.
      if (state.matchedLocation == '/') {
        return boot.hasOnboarded ? '/space' : '/onboarding';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _fade(context, child: const SizedBox.shrink()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _fade(
          context,
          child: OnboardingScreen(
            // V3.50 — where the door opens after the rules (a deep
            // link's destination); the default is the space.
            returnTo:
                state.uri.queryParameters['vers'] ?? '/space',
          ),
        ),
      ),
      GoRoute(
        path: '/space',
        pageBuilder: (context, state) =>
            _fade(context, child: const MapScreen()),
      ),
      GoRoute(
        path: '/mirror',
        pageBuilder: (context, state) =>
            _fade(context, child: const MirrorScreen()),
      ),
      GoRoute(
        path: '/cadavre',
        pageBuilder: (context, state) =>
            _fade(context, child: const CorpseScreen()),
      ),
      // LE SALON (V3.19): the invitation link's landing — a key, not a
      // page. The threshold decides what the guest meets (rules first
      // if they are new, then the claim).
      GoRoute(
        path: '/c/:token',
        pageBuilder: (context, state) => _fade(
          context,
          child: SalonClaimScreen(token: state.pathParameters['token'] ?? ''),
        ),
      ),
      // LA BRAISE (V3.60): the passage link's landing — a body, not a
      // page. The key (and the sealed ballot behind the dot) hands an
      // anonymous identity over; the threshold decides whether the
      // rules are told first.
      GoRoute(
        path: '/pass/:payload',
        pageBuilder: (context, state) => _fade(
          context,
          child: BraiseClaimScreen(
            payload: state.pathParameters['payload'] ?? '',
          ),
        ),
      ),
      // V3.49 — a PLACE in the void: `/#/ciel/<x>/<y>` lands the eye
      // where a stranger stood. Coordinates only — the same public
      // metadata the sky renders; a malformed link opens the heart.
      GoRoute(
        path: '/ciel/:x/:y',
        pageBuilder: (context, state) => _fade(
          context,
          child: MapScreen(
            eye: SkyLink.parse(
              state.pathParameters['x'],
              state.pathParameters['y'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/impact',
        pageBuilder: (context, state) =>
            _fade(context, child: const ImpactScreen()),
      ),
      // The guardian's hidden door: no link, no label — the threshold
      // itself decides who crosses (long-press L'Aube on the map).
      GoRoute(
        path: '/observatoire',
        pageBuilder: (context, state) =>
            _fade(context, child: const ObservatoryScreen()),
      ),
      // V3.57 — the Shard Sower: the vestige module behind the
      // Observatory's own threshold (same guardian session).
      GoRoute(
        path: '/observatoire/eclats',
        pageBuilder: (context, state) =>
            _fade(context, child: const VestigeModuleScreen()),
      ),
      GoRoute(
        path: '/frequencies',
        pageBuilder: (context, state) =>
            _fade(context, child: const FrequenciesScreen()),
      ),
    ],
  );
});

CustomTransitionPage<void> _fade(
  BuildContext context, {
  required Widget child,
}) {
  final reduced = context.wantsReducedMotion;
  return CustomTransitionPage<void>(
    child: child,
    // « Reduce animations »: screens appear at once, no fade theater.
    transitionDuration: reduced ? Duration.zero : AppDurations.routeFade,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Composite transition: fade + subtle upward drift + scale
      final curveAnim = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final scaleAnim = Tween<double>(begin: 0.97, end: 1.0).animate(curveAnim);
      final offsetAnim = Tween<Offset>(
        begin: const Offset(0, 0.02),
        end: Offset.zero,
      ).animate(curveAnim);

      return FadeTransition(
        opacity: curveAnim,
        child: SlideTransition(
          position: offsetAnim,
          child: ScaleTransition(scale: scaleAnim, child: child),
        ),
      );
    },
  );
}
