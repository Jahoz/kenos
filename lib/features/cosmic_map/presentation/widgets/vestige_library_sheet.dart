import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/haptics/kenos_haptics.dart';
import '../../data/artifact_memory.dart';
import 'vestige.dart';

/// V3.30 — LA BIBLIOTHÈQUE DU VIDE: the reading mode. A long press on
/// CARTE opens the whole vestige field at once — every shard of
/// culture at its true place in the [0,1] sky, tappable, readable at
/// leisure. On the map a shard is a drifting fragment you discover;
/// here the library is a PLACE: the traveller who drifts alone may
/// also sit and read. Read shards rest dimmer; the unread still wait.
Future<void> showVestigeLibrary(
  BuildContext context, {
  required List<Vestige> vestiges,
  required ArtifactMemory artifacts,
  required Offset eye,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'KENOS_BIBLIOTHEQUE_DU_VIDE',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 450),
    useRootNavigator: true,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _LibraryPanel(vestiges: vestiges, artifacts: artifacts, eye: eye),
      );
    },
  );
}

class _LibraryPanel extends StatefulWidget {
  const _LibraryPanel({
    required this.vestiges,
    required this.artifacts,
    required this.eye,
  });

  final List<Vestige> vestiges;
  final ArtifactMemory artifacts;
  final Offset eye;

  @override
  State<_LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState extends State<_LibraryPanel> {
  Vestige? _selected;

  void _read(Vestige v) {
    KenosHaptics.pulse(KenosPulse.themePick);
    // Reading here is the same memory as reading adrift: the map's
    // « N VESTIGES À DÉCOUVRIR » counts what remains.
    widget.artifacts.markRead(v.id);
    setState(() => _selected = v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 26),
              child: Column(
                children: [
                  Text(
                    'LA BIBLIOTHÈQUE DU VIDE',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 10,
                      letterSpacing: 4,
                      color: AppColors.fade(AppColors.cyan, 0.85),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'TOUCHE UN ÉCLAT POUR LE LIRE — LE VIDE SE REFERME AU TOUCHER EXTÉRIEUR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 7.5,
                      letterSpacing: 2,
                      color: AppColors.fade(AppColors.pureLight, 0.32),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = math.min(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final local = details.localPosition;
                      // Letterboxed square: map back to world [0,1].
                      final origin = Offset(
                        (constraints.maxWidth - side) / 2,
                        (constraints.maxHeight - side) / 2,
                      );
                      final p = Offset(
                        (local.dx - origin.dx) / side,
                        (local.dy - origin.dy) / side,
                      );
                      Vestige? hit;
                      var best = 0.045;
                      for (final v in widget.vestiges) {
                        final d = (Offset(v.offsetX, v.offsetY) - p).distance;
                        if (d < best) {
                          best = d;
                          hit = v;
                        }
                      }
                      if (hit != null) _read(hit);
                    },
                    child: CustomPaint(
                      size: Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      ),
                      painter: _LibraryPainter(
                        vestiges: widget.vestiges,
                        artifacts: widget.artifacts,
                        eye: widget.eye,
                        selected: _selected,
                        side: side,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // The reading plaque: the shard sits still and speaks.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _selected == null
                ? const SizedBox(height: 34)
                : _ShardPlaque(
                    key: ValueKey(_selected!.id),
                    vestige: _selected!,
                    onClose: () => setState(() => _selected = null),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The reading plaque: the shard sits still and speaks.
class _ShardPlaque extends StatelessWidget {
  const _ShardPlaque({
    super.key,
    required this.vestige,
    required this.onClose,
  });

  final Vestige vestige;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(22, 0, 22, 14 + bottom),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.voidBlack,
        border: Border.all(color: AppColors.fade(AppColors.pureLight, 0.18)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            vestige.kindLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 9,
              letterSpacing: 3,
              color: AppColors.fade(AppColors.teal, 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            vestige.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.serifItalic,
              fontSize: 14.5,
              height: 1.75,
              color: AppColors.fade(AppColors.pureLight, 0.88),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '— ${vestige.source}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 8,
              letterSpacing: 2,
              color: AppColors.fade(AppColors.pureLight, 0.4),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onClose,
            child: const Text('REPRENDRE LA DÉRIVE'),
          ),
        ],
      ),
    );
  }
}

/// The field at rest: every shard a small tumbling diamond at its
/// true place, the read ones resting dimmer, the eye's last stance
/// drawn faint — a map of culture, not a feed.
class _LibraryPainter extends CustomPainter {
  _LibraryPainter({
    required this.vestiges,
    required this.artifacts,
    required this.eye,
    required this.selected,
    required this.side,
  });

  final List<Vestige> vestiges;
  final ArtifactMemory artifacts;
  final Offset eye;
  final Vestige? selected;
  final double side;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(
      (size.width - side) / 2,
      (size.height - side) / 2,
    );
    Offset w(double x, double y) => Offset(origin.dx + x * side, origin.dy + y * side);

    // The sky's own frame, hairline quiet.
    canvas.drawRect(
      Rect.fromLTWH(origin.dx, origin.dy, side, side),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = AppColors.fade(AppColors.pureLight, 0.08),
    );

    // The eye's last stance in the void.
    final e = w(eye.dx, eye.dy);
    canvas.drawCircle(
      e,
      2.4,
      Paint()..color = AppColors.fade(AppColors.cyan, 0.5),
    );

    for (final v in vestiges) {
      final p = w(v.offsetX, v.offsetY);
      final isRead = artifacts.isRead(v.id);
      final isSelected = selected?.id == v.id;
      final alpha = isSelected ? 0.95 : (isRead ? 0.22 : 0.62);
      final rot = (v.id.hashCode & 0x7fffffff) % 60 / 60 * math.pi;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(rot);
      final shard = Paint()
        ..color = isRead
            ? AppColors.fade(AppColors.pureLight, alpha)
            : AppColors.fade(AppColors.teal, alpha);
      final r = isSelected ? 5.2 : 3.6;
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2), shard);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LibraryPainter old) =>
      old.selected?.id != selected?.id ||
      old.vestiges.length != vestiges.length ||
      old.eye != eye;
}
