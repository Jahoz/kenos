import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/constants/app_layout.dart';
import '../../constellations/data/salon_anchor_store.dart';
import '../../echo/data/echo_providers.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../data/braise_repository.dart';
import '../domain/braise_ballot.dart';
import '../domain/braise_link.dart';

/// LA BRAISE — the passage's landing (V3.60).
///
/// A link is a body: `/#/pass/<key>.<ballot>` opens onto this screen.
/// The key knocks at `claim_passage` (once — the ember dies at the
/// claim), the sealed ballot replants the local memories on this
/// device. What the traveller meets first depends on what the link
/// itself vouches for: a ballot that says the rules were crossed
/// elsewhere spares a seasoned traveller the threshold; a naked link
/// on a fresh device tells the rules first, like every door.
///
/// States, each told honestly: resolving · the threshold · a dead
/// ember (wrong, expired or already claimed — alike, by design) · a
/// body that already gave its own · the arrival · the ether
/// unreachable.
class BraiseClaimScreen extends ConsumerStatefulWidget {
  const BraiseClaimScreen({super.key, required this.payload});

  final String payload;

  @override
  ConsumerState<BraiseClaimScreen> createState() => _BraiseClaimScreenState();
}

enum _BraisePhase {
  resolving,
  threshold,
  dead,
  extinct,
  arrived,
  unreachable,
}

class _BraiseClaimScreenState extends ConsumerState<BraiseClaimScreen> {
  _BraisePhase _phase = _BraisePhase.resolving;
  String? _key;
  BraiseBallot? _ballot;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    if (!mounted) return;
    setState(() => _phase = _BraisePhase.resolving);

    // The link's shape first: anything that does not wear the ember's
    // shape mourns exactly like an expired passage.
    final parsed = BraiseLink.parse(widget.payload);
    if (parsed == null) {
      setState(() => _phase = _BraisePhase.dead);
      return;
    }
    _key = parsed.key;
    _ballot = parsed.ballot == null
        ? null
        : await BraiseBallot.tryUnpack(parsed.ballot!, parsed.key);

    // The threshold: a fresh device learns the rules — unless the
    // sealed ballot vouches this traveller already crossed them on
    // another body (read live; the boot snapshot never refreshes).
    final store = ref.read(localEchoStoreProvider);
    var storedOnboarded = false;
    try {
      storedOnboarded = await store.hasOnboarded();
    } catch (_) {
      // Storage silence is not a refusal: the boot snapshot spoke.
    }
    final onboarded =
        ref.read(bootstrapProvider).hasOnboarded || storedOnboarded;
    if (!mounted) return;
    if (!onboarded && !(_ballot?.onboarded ?? false)) {
      setState(() => _phase = _BraisePhase.threshold);
      return;
    }

    // The anonymous session must exist before the ember is claimed.
    await ref.read(sessionReadyProvider.future);
    try {
      await ref.read(braiseRepositoryProvider).claim(_key!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final raw = e.toString();
        _phase = raw.contains('KENOS_PASSAGE_UNKNOWN')
            ? _BraisePhase.dead
            : raw.contains('KENOS_BRAISE_PASSED')
                ? _BraisePhase.extinct
                : _BraisePhase.unreachable;
      });
      return;
    }
    await _transplant();
    if (!mounted) return;
    setState(() => _phase = _BraisePhase.arrived);
  }

  /// Replants the sealed memories. A failed souvenir never breaks a
  /// successful claim — the identity lives server-side now.
  Future<void> _transplant() async {
    final ballot = _ballot;
    try {
      final store = ref.read(localEchoStoreProvider);
      if (ballot != null) {
        final here = await store.readStats();
        await store.writeStats(ballot.mergedStats(here));
        if (ballot.freqGuideSeen) {
          await store.markFrequenciesGuideSeen();
        }
        if (ballot.corpseGuideSeen) {
          await store.markCorpseGuideSeen();
        }
        if (ballot.eyeGuideSeen) {
          await store.markEyeGuideSeen();
        }
        if (ballot.onboarded) {
          await store.setOnboarded();
          ref.read(onboardedProvider.notifier).state = true;
        }
        final doors = ref.read(salonAnchorStoreProvider);
        await doors.load();
        for (final anchor in ballot.anchors) {
          await doors.remember(anchor);
        }
      }
    } catch (_) {
      // The claim holds; the souvenirs were only ever a courtesy.
    }
    ref.invalidate(userStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _BraisePhase.threshold) {
      // The rules before the ember: same threshold, and the claim
      // resumes once they are accepted. The navigation to this same
      // location would be a router no-op — the screen reacts itself,
      // the route is already the right one.
      return OnboardingScreen(
        returnTo: '/pass/${widget.payload}',
        onEntered: _resolve,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.voidBlack,
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
                          'LA BRAISE',
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 9,
                            letterSpacing: 4,
                            color: AppColors.fade(AppColors.ember, 0.6),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.go('/space'),
                          child: const Text('LE VIDE'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    switch (_phase) {
                      _BraisePhase.resolving => _resolving(),
                      _BraisePhase.dead => _dead(),
                      _BraisePhase.extinct => _extinct(),
                      _BraisePhase.arrived => _arrived(),
                      _BraisePhase.unreachable => _unreachable(),
                      _BraisePhase.threshold => _resolving(),
                    },
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resolving() => Column(
        key: const ValueKey('braise_resolving'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          SizedBox(height: 40),
          Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 1.2,
                color: AppColors.ember,
              ),
            ),
          ),
          SizedBox(height: 28),
        ],
      );

  Widget _dead() => _word(
        key: const ValueKey('braise_dead'),
        title: 'La braise s’est éteinte',
        body: 'Elle n’attend que dix minutes —\n'
            'déjà consumée, ou jamais forgée.\n'
            'L’ancien appareil peut en porter une neuve.',
        action: 'RETOURNER AU VIDE',
        onPressed: () => context.go('/space'),
      );

  Widget _extinct() => _word(
        key: const ValueKey('braise_extinct'),
        title: 'Ce corps a déjà transmis',
        body: 'Une braise ne se transmet pas deux fois.\n'
            'Celui-ci a donné la sienne —\n'
            'il ne peut plus en porter une autre.',
        action: 'RETOURNER AU VIDE',
        onPressed: () => context.go('/space'),
      );

  Widget _arrived() => Column(
        key: const ValueKey('braise_arrived'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Center(
            child: CustomPaint(
              size: const Size(120, 120),
              painter: _BraiseEmberPainter(),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'La braise a passé',
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
            'Ce que ce corps était t’appartient encore :\n'
            'les bouteilles en attente, les portes tenues,\n'
            'les mains données aux anneaux.\n'
            'L’ancien appareil s’est éteint à son tour.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.serifItalic,
              fontSize: 16,
              height: 1.9,
              color: AppColors.fade(AppColors.pureLight, 0.62),
            ),
          ),
          const SizedBox(height: 40),
          OutlinedButton(
            key: const ValueKey('braise_enter'),
            onPressed: () => context.go('/space'),
            child: const Text('ENTRER DANS LE VIDE'),
          ),
          const SizedBox(height: 14),
        ],
      );

  Widget _unreachable() => _word(
        key: const ValueKey('braise_unreachable'),
        title: 'L’éther est injoignable',
        body: 'La braise attend encore — dix minutes\n'
            'coulent, mais le vide, parfois, est loin de tout.',
        action: 'RÉESSAYER',
        onPressed: _resolve,
      );

  Widget _word({
    required Key key,
    required String title,
    required String body,
    required String action,
    required VoidCallback onPressed,
  }) =>
      Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),
          Text(
            title,
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
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.serifItalic,
              fontSize: 16,
              height: 1.9,
              color: AppColors.fade(AppColors.pureLight, 0.62),
            ),
          ),
          const SizedBox(height: 40),
          OutlinedButton(onPressed: onPressed, child: Text(action)),
          const SizedBox(height: 14),
        ],
      );
}

/// The ember, arrived: a warm seed breathing at the heart, the same
/// warmth the map draws on a held door — nothing more.
class _BraiseEmberPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      26,
      Paint()
        ..color = AppColors.fade(AppColors.ember, 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(
      center,
      7,
      Paint()..color = AppColors.fade(AppColors.ember, 0.55),
    );
    canvas.drawCircle(
      center,
      2.6,
      Paint()..color = AppColors.fade(AppColors.pureLight, 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _BraiseEmberPainter old) => false;
}
