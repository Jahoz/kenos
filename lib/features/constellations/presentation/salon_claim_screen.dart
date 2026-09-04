import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/constants/app_layout.dart';
import '../../cosmic_map/data/artifact_memory.dart';
import '../../echo/data/echo_providers.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../data/constellation_repository.dart';
import '../domain/constellation_figure.dart';
import 'constellation_sheets.dart';

/// LE SALON — the invited guest's threshold (V3.19).
///
/// A link is a key: `/#/c/<token>` opens onto this screen. The rules
/// of the game are the corpse's own — one line per stranger, the
/// preceding line only, blind to the whole. What differs is the door:
/// the ring lives hidden while it is written, and the key is checked
/// inside the contribution itself.
///
/// States, each told honestly: resolving · the threshold (a first-time
/// guest learns the three rules before the door) · dead key (wrong or
/// expired — alike, by design) · the poem already closed (it waits in
/// the ether as a public artifact) · these hands already gave · the
/// invitation itself · the ether unreachable.
class SalonClaimScreen extends ConsumerStatefulWidget {
  const SalonClaimScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<SalonClaimScreen> createState() => _SalonClaimScreenState();
}

enum _SalonPhase { resolving, threshold, dead, closed, already, invited, unreachable }

class _SalonClaimScreenState extends ConsumerState<SalonClaimScreen> {
  _SalonPhase _phase = _SalonPhase.resolving;
  ConstellationMeta? _meta;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    if (!mounted) return;
    setState(() => _phase = _SalonPhase.resolving);
    try {
      // A first-time guest crosses the threshold first — the three
      // rules are read live (the boot snapshot never refreshes), so
      // the return trip through this same route lands past the gate.
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
      if (!onboarded) {
        setState(() => _phase = _SalonPhase.threshold);
        return;
      }
      // The anonymous session must exist before the door is knocked.
      await ref.read(sessionReadyProvider.future);
      final meta =
          await ref.read(constellationRepositoryProvider).fetchInvited(widget.token);
      if (!mounted) return;
      _meta = meta;
      if (meta.isClosed) {
        setState(() => _phase = _SalonPhase.closed);
        return;
      }
      final mine = ref.read(artifactMemoryProvider).contributedTo(meta.id) ||
          (await ref.read(constellationRepositoryProvider).hasContributed(meta.id) ??
              false);
      if (!mounted) return;
      if (mine) {
        unawaited(ref.read(artifactMemoryProvider).markContributed(meta.id));
        setState(() => _phase = _SalonPhase.already);
        return;
      }
      setState(() => _phase = _SalonPhase.invited);
    } catch (e) {
      if (!mounted) return;
      // Wrong and expired look alike — the door says nothing about
      // what is behind it. Everything else is the sky being far.
      setState(() {
        _phase = e.toString().contains('KENOS_INVITE_UNKNOWN')
            ? _SalonPhase.dead
            : _SalonPhase.unreachable;
      });
    }
  }

  Future<void> _poseLine() async {
    final meta = _meta;
    if (meta == null) return;
    await showContributeSheet(
      context,
      ref: ref,
      constellation: meta,
      inviteToken: widget.token,
    );
    if (mounted) context.go('/space');
  }

  Future<void> _readArtifact() async {
    final meta = _meta;
    if (meta == null) return;
    final lines =
        await ref.read(constellationRepositoryProvider).read(meta.id);
    if (!mounted) return;
    context.go('/space');
    if (lines != null) {
      await showConstellationReading(
        context,
        lines: lines,
        figureId: meta.id,
        memory: ref.read(artifactMemoryProvider),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _SalonPhase.threshold) {
      // The rules before the door: same threshold, and the door opens
      // back onto the salon once they are accepted. The navigation to
      // this same location would be a router no-op — the screen reacts
      // itself, the route is already the right one.
      return OnboardingScreen(
        returnTo: '/c/${widget.token}',
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
                          'LE SALON',
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
                      _SalonPhase.resolving => _resolving(),
                      _SalonPhase.dead => _dead(),
                      _SalonPhase.closed => _closed(),
                      _SalonPhase.already => _already(),
                      _SalonPhase.unreachable => _unreachable(),
                      _SalonPhase.invited => _invited(),
                      _SalonPhase.threshold => _resolving(),
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
        key: const ValueKey('salon_resolving'),
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
        key: const ValueKey('salon_dead'),
        title: 'Le salon s’est tu',
        body: 'Cet anneau s’est dissous dans l’éther,\n'
            'ou la clé n’ouvre plus rien.\n'
            'Demande un nouveau lien à qui t’invite.',
        action: 'RETOURNER AU VIDE',
        onPressed: () => context.go('/space'),
      );

  Widget _closed() => _word(
        key: const ValueKey('salon_closed'),
        title: 'Le poème s’est refermé',
        body: 'Il vit désormais dans l’éther,\n'
            'un artefact lisible par tous —\n'
            'toi inclus, pour toujours.',
        action: 'LIRE LE POÈME',
        onPressed: _readArtifact,
      );

  Widget _already() => _word(
        key: const ValueKey('salon_already'),
        title: 'Ta ligne est déjà dans ce corps',
        body: 'Un salon ne se relit jamais\n'
            'en train de se faire.\n'
            'Reviens le lire refermé, dans l’éther.',
        action: 'RETOURNER AU VIDE',
        onPressed: () => context.go('/space'),
      );

  Widget _unreachable() => _word(
        key: const ValueKey('salon_unreachable'),
        title: 'L’éther est injoignable',
        body: 'La porte n’a pas répondu.\n'
            'Le vide, parfois, est loin de tout.',
        action: 'RÉESSAYER',
        onPressed: _resolve,
      );

  Widget _invited() {
    final meta = _meta!;
    final isSong = meta.kind == ConstellationKind.melody;
    final unit = isSong ? 'PHRASES' : 'LIGNES';
    return Column(
      key: const ValueKey('salon_invited'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Center(
          child: CustomPaint(
            size: const Size(150, 150),
            painter: _SalonFigurePainter(
              lineCount: meta.lineCount,
              target: meta.target,
              id: meta.id,
              song: isSong,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          isSong ? 'Une chanson à l’aveugle\nt’attend en salon' : 'Un poème à l’aveugle\nt’attend en salon',
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
          'Quelqu’un t’a choisi. Chaque invité offre\n'
          '${isSong ? 'une phrase de notes' : 'une ligne'}, en voyant seulement\n'
          '${isSong ? 'celle qui la précède' : 'celle qui la précède'} — personne\n'
          'ne voit le tout. Refermé, ${isSong ? 'la chanson' : 'le poème'}\n'
          'rejoindra l’éther : lisible par tous.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.serifItalic,
            fontSize: 16,
            height: 1.9,
            color: AppColors.fade(AppColors.pureLight, 0.62),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          '${meta.lineCount} / ${meta.target} $unit'
          ' — ${isSong ? 'LA CHANSON' : 'LE POÈME'} ATTEND',
          key: const ValueKey('salon_progress'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 8.5,
            letterSpacing: 2,
            color: AppColors.fade(AppColors.ember, 0.75),
          ),
        ),
        const SizedBox(height: 22),
        OutlinedButton(
          key: const ValueKey('salon_pose_line'),
          onPressed: _poseLine,
          child: Text(isSong ? 'POSER MA PHRASE' : 'POSER MA LIGNE'),
        ),
        const SizedBox(height: 14),
        Text(
          'TU NE VERRAS JAMAIS LE TOUT QUE TU AIDES À FAIRE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 8,
            letterSpacing: 2,
            color: AppColors.fade(AppColors.pureLight, 0.3),
          ),
        ),
      ],
    );
  }

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

/// The salon's figure, waiting: filled stars for the lines already
/// given, hollow stations for those the poem still awaits — the same
/// golden-angle arithmetic the map will draw once the artifact joins
/// the sky.
class _SalonFigurePainter extends CustomPainter {
  _SalonFigurePainter({
    required this.lineCount,
    required this.target,
    required this.id,
    required this.song,
  });

  final int lineCount;
  final int target;
  final String id;
  final bool song;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;
    final t = target.clamp(2, 7);
    final stroke = song ? AppColors.cyan : AppColors.indigo;

    Offset station(int k) {
      final unit = ConstellationFigure.starAt(k, target: t, id: id);
      return Offset(center.dx + radius * unit.dx, center.dy + radius * unit.dy);
    }

    // The seed: the hand that invited, warm at the heart.
    canvas.drawCircle(
      center,
      1.4,
      Paint()..color = AppColors.fade(AppColors.ember, 0.8),
    );

    final drawn = lineCount.clamp(0, t);
    final link = Paint()
      ..color = AppColors.fade(stroke, 0.35)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    for (var k = 1; k < drawn; k++) {
      canvas.drawLine(station(k - 1), station(k), link);
    }
    for (var k = 0; k < t; k++) {
      final p = station(k);
      if (k < drawn) {
        canvas.drawCircle(
          p,
          2.2,
          Paint()..color = AppColors.fade(stroke, 0.9),
        );
      } else {
        canvas.drawCircle(
          p,
          2.2,
          Paint()
            ..color = AppColors.fade(AppColors.pureLight, 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SalonFigurePainter old) =>
      old.lineCount != lineCount ||
      old.target != target ||
      old.id != id ||
      old.song != song;
}
