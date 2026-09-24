import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../data/artifact_memory.dart';
import '../../domain/vestige.dart';

// The Vestige model, its daily rotation and its math live in the
// DOMAIN now (the repository that loads them is
// `data/vestige_repository.dart`) — re-exported here so the sheet's
// existing importers keep resolving.
export '../../domain/vestige.dart';

/// The Vestige visual: a carved geometric shard, dim, unmistakably NOT
/// a star (no radial glow, no round core) — an artefact of culture.
class VestigePainter extends CustomPainter {
  VestigePainter({
    required this.rotation,
    required this.color,
    required this.pulse,
    this.read = false,
    this.kept = false,
    this.fresh = false,
    this.scale = 1.0,
    this.recede = 1.0,
  });

  final double rotation;
  final Color color;

  /// 0..1 gentle highlight (a reader's attention passing nearby).
  final double pulse;

  /// Read on this device within the week: a VISIBLE ghost (still
  /// there, still re-readable — a memory, not a burn; the marker
  /// fades after seven days and the shard is a discovery again).
  final bool read;

  /// Kept in this traveller's sky: full light, ember-tinted — the
  /// reliquaire's mark, local forever.
  final bool kept;

  /// V3.58b — born within the moon of favour: a soft halo, so a just-
  /// published shard reads NEW at a glance on the map (publishing
  /// must be seen, the live report).
  final bool fresh;

  /// V3.72 — the carving's scale relative to its box (world-sized by
  /// the caller: the finger's 32 px courtesy box may be larger than
  /// what the eye sees at the survey).
  final double scale;

  /// V3.72 — 1.0 near the eye, dying with distance (the V3.63 law
  /// every body obeys; kept shards ride 1.0 forever — earned
  /// importance is not borrowed).
  final double recede;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // V3.58f — the balance the owner asked for: SMALLER but
    // LUMINOUS. The carving shrinks to ~12 px (the 32 px box stays —
    // it is the finger's courtesy, not the eye's), the stroke
    // thickens and brightens, and a breath of fill carries the
    // light. A READ shard rests at 0.42 — a visible memory, never an
    // extinction ("il s'éteint après lecture", the live report).
    //
    // V3.62 — demoted another step: the shard flood had inverted the
    // sky's hierarchy (culture covered the heavens). The unread
    // whisper breathes at 0.30, its fill barely there — a trace to
    // drift near, never a body. Kept shards (the reliquaire) keep
    // their ember light: EARNED importance is not borrowed.
    //
    // V3.72 — world-sized × receding: at the survey the carving is a
    // wanderer-class mote, and it fades with distance like all
    // matter. The newborn's ring dies twice as fast — a birth is
    // told NEAR, it is not a lighthouse.
    final r = (size.shortestSide / 2 - 8) * 0.75 * scale;
    if (r < 0.8) return; // beyond the whisper: nothing to draw
    // The newborn's mark (V3.58e): a thin HOLLOW ring, the sky's own
    // grammar for "something surrounds this" — angular like its
    // shard, quiet like the lanes, gone with the moon of favour.
    if (fresh && !read && !kept) {
      canvas.drawCircle(
        center,
        r * 1.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = AppColors.fade(color, 0.34 * recede * recede),
      );
    }
    final baseAlpha =
        (kept ? 0.58 : (read ? 0.22 : 0.30)) * recede;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = AppColors.fade(kept ? AppColors.ember : color, baseAlpha);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // The shard: an elongated hexagon — carved, angular, now carrying
    // a breath of light inside (a fill below the stroke: luminous
    // without becoming a star — culture leans toward the light, it is
    // never a confidence).
    final path = Path()
      ..moveTo(-r * 0.35, -r)
      ..lineTo(r * 0.45, -r * 0.8)
      ..lineTo(r, 0)
      ..lineTo(r * 0.3, r * 0.9)
      ..lineTo(-r * 0.5, r * 0.7)
      ..lineTo(-r, -r * 0.1)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.fade(
          kept ? AppColors.ember : color,
          (read ? 0.02 : 0.05) * recede,
        ),
    );
    canvas.drawPath(path, paint);

    // A carved line across — a fragment of inscription.
    canvas.drawLine(
      Offset(-r * 0.4, -r * 0.2),
      Offset(r * 0.5, r * 0.15),
      paint..strokeWidth = 0.55,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(VestigePainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.pulse != pulse ||
      oldDelegate.read != read ||
      oldDelegate.kept != kept ||
      oldDelegate.fresh != fresh ||
      oldDelegate.scale != scale ||
      oldDelegate.recede != recede;
}

/// The Vestige reveal: serif text, sourced, RE-READABLE (a quote does
/// not burn — that would be waste). A short hold (~1 s) decipheres.
/// With [memory], the read outlives the session (seven days) and the
/// traveller may KEEP the shard in their sky (the reliquaire).
Future<void> showVestigeSheet(
  BuildContext context, {
  required Vestige vestige,
  ArtifactMemory? memory,
}) {
  memory?.markRead(vestige.id);
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'KENOS_VESTIGE',
    barrierColor: AppColors.voidBlack,
    transitionDuration: const Duration(milliseconds: 500),
    useRootNavigator: true,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _VestigePanel(vestige: vestige, memory: memory),
      );
    },
  );
}

class _VestigePanel extends StatefulWidget {
  const _VestigePanel({required this.vestige, this.memory});

  final Vestige vestige;
  final ArtifactMemory? memory;

  @override
  State<_VestigePanel> createState() => _VestigePanelState();
}

class _VestigePanelState extends State<_VestigePanel> {
  String? _keepAck;

  Future<void> _keep() async {
    final memory = widget.memory;
    if (memory == null) return;
    final released = await memory.keep(
      KeptArtifact(
        id: widget.vestige.id,
        kind: 'vestige',
        x: widget.vestige.offsetX,
        y: widget.vestige.offsetY,
        texts: [widget.vestige.text],
        target: 0,
        keptAt: DateTime.now().millisecondsSinceEpoch,
        source: widget.vestige.source,
        vestigeKind: widget.vestige.kind,
      ),
    );
    if (!mounted) return;
    setState(() {
      _keepAck = released == null
          ? 'GARDÉ DANS TON CIEL'
          : 'GARDÉ — LE PLUS ANCIEN EST RETOURNÉ AU CIEL';
    });
  }

  @override
  Widget build(BuildContext context) {
    final vestige = widget.vestige;
    final memory = widget.memory;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context, rootNavigator: true).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 38),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // V3.58 — the reliquaire's mark rides the header:
                  // a kept shard says so, right where it is read.
                  // V3.58b — the newborn too: TOUT NOUVEAU, one moon.
                  'VESTIGE — ${vestige.kindLabel}'
                  '${vestige.isFresh ? ' · TOUT NOUVEAU' : ''}'
                  '${memory?.isKept(vestige.id) == true ? ' · GARDÉ' : ''}',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    letterSpacing: 4,
                    color: AppColors.fade(AppColors.pureLight, 0.45),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  vestige.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 19,
                    height: 1.8,
                    color: AppColors.fade(AppColors.pureLight, 0.92),
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  '— ${vestige.source}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    letterSpacing: 2,
                    color: AppColors.fade(AppColors.teal, 0.55),
                  ),
                ),
                const SizedBox(height: 36),
                if (memory != null && _keepAck == null && !memory.isKept(vestige.id))
                  TextButton(
                    onPressed: _keep,
                    child: const Text(
                      'LE GARDER DANS MON CIEL',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 9,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                if (_keepAck != null) ...[
                  Text(
                    _keepAck!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 8.5,
                      letterSpacing: 1.5,
                      color: AppColors.fade(AppColors.ember, 0.75),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'CECI NE BRÛLE PAS — IL REVIENDRA',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 8,
                    letterSpacing: 3,
                    color: AppColors.fade(AppColors.pureLight, 0.25),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
