import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../data/artifact_memory.dart';

/// A Vestige: real, curated culture drifting in the void — a quote, an
/// etymology, a haiku, a micro-history. NEVER a fake confession: the
/// sacred contract says a star is a real human thought; a Vestige is
/// an artefact, re-readable, carrying no author, no reception, no
/// stardust. Culture for the traveller who drifts alone.
class Vestige {
  const Vestige({
    required this.id,
    required this.kind,
    required this.text,
    required this.source,
    required this.offsetX,
    required this.offsetY,
  });

  final String id;
  final String kind;
  final String text;
  final String source;
  final double offsetX;
  final double offsetY;

  factory Vestige.fromJson(Map<String, dynamic> json) => Vestige(
        id: json['id'] as String,
        kind: json['kind'] as String,
        text: json['text'] as String,
        source: json['source'] as String,
        offsetX: (json['x'] as num).toDouble(),
        offsetY: (json['y'] as num).toDouble(),
      );

  /// How many curated shards exist in the current bundle.
  static int knownCount = 0;

  String get kindLabel => switch (kind) {
        'quote' => 'CITATION',
        'etymology' => 'ÉTYMOLOGIE',
        'haiku' => 'HAÏKU',
        'history' => 'HISTOIRE',
        _ => 'VESTITVE',
      };
}

/// Loads the curated vestiges: the ETHER's library first (the Curator
/// feeds it without a release), the bundled JSON as the honest offline
/// fallback — the app never blocks, the demo ether keeps its shards.
/// A subset shows at a time, rotating with the days: the library
/// renews itself as you return — always something left to discover.
Future<List<Vestige>> loadVestiges() async {
  final all = await _loadAllVestiges();
  Vestige.knownCount = all.length;

  // Daily rotation: ~2/3 of the shards are adrift on any given day,
  // deterministically — every device sees the same drifting set,
  // and tomorrow's sky holds shards today's doesn't.
  final day = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
  final visible = <Vestige>[];
  for (var i = 0; i < all.length; i++) {
    final slot = (i + day * 5) % all.length;
    if (slot < all.length * 2 / 3) {
      visible.add(all[i]);
    }
  }
  return visible;
}

/// The whole curated library: ether first, bundle fallback.
Future<List<Vestige>> _loadAllVestiges() async {
  // 1. The ether's library (when a backend is configured and alive).
  try {
    final client = Supabase.instance.client;
    final signedIn =
        client.auth.currentUser != null || client.auth.currentSession != null;
    if (signedIn) {
      final rows = await client.rpc('fetch_vestiges');
      if (rows is List && rows.isNotEmpty) {
        return [
          for (final row in rows)
            Vestige.fromJson((row as Map).cast<String, dynamic>()),
        ];
      }
    }
  } catch (e) {
    // The ether's library is a guest: if it is unreachable, the
    // bundle carries the culture — silently.
    debugPrint('[kenos.vestiges] ether library unreachable: $e');
  }

  // 2. The bundled library (demo mode, offline, always honest).
  try {
    final raw = await rootBundle.loadString('assets/vestiges.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return (data['vestiges'] as List)
        .map((v) => Vestige.fromJson(v as Map<String, dynamic>))
        .toList();
  } catch (e) {
    // The ether works without its library: the app never blocks.
    debugPrint('[kenos.vestiges] unavailable: $e');
    return const <Vestige>[];
  }
}

/// A Vestige's sky position: STATIC (culture doesn't orbit — it rests
/// where it drifted ashore), with the faintest breathing rotation.
class VestigeMath {
  VestigeMath._();

  /// The shard's rotation at a moment (very slow tumble, id-hashed).
  static double rotationAt(String id, DateTime at) {
    final h = (id.hashCode & 0x7fffffff);
    // Continuous spread (not bucketed): every shard tumbles on its own
    // precise phase — no two in choir.
    final phase = (at.millisecondsSinceEpoch / 47000 + (h % 9973) / 9973) % 1.0;
    return phase * 2 * math.pi;
  }
}

/// The Vestige visual: a carved geometric shard, dim, unmistakably NOT
/// a star (no radial glow, no round core) — an artefact of culture.
class VestigePainter extends CustomPainter {
  VestigePainter({
    required this.rotation,
    required this.color,
    required this.pulse,
    this.read = false,
    this.kept = false,
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

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // The shard stays STAR-CORE sized (~16 px): the 32 px box is the
    // finger's courtesy, the drawing never looms (V3.12c — the real
    // disproportion was here, not in the constellations).
    final r = size.shortestSide / 2 - 8;
    final baseAlpha = kept ? 0.5 : (read ? 0.22 : (0.26 + 0.20 * pulse));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kept || read ? 0.7 : 0.8
      ..color = AppColors.fade(kept ? AppColors.ember : color, baseAlpha);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // The shard: an elongated hexagon — carved, angular, not a light.
    final path = Path()
      ..moveTo(-r * 0.35, -r)
      ..lineTo(r * 0.45, -r * 0.8)
      ..lineTo(r, 0)
      ..lineTo(r * 0.3, r * 0.9)
      ..lineTo(-r * 0.5, r * 0.7)
      ..lineTo(-r, -r * 0.1)
      ..close();
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
      oldDelegate.kept != kept;
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
                  'VESTITVE — ${vestige.kindLabel}',
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
