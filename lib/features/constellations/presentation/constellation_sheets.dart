import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/haptics/kenos_haptics.dart';
import '../../echo/data/echo_providers.dart';
import '../data/constellation_repository.dart';
import '../domain/constellation_figure.dart';
/// The Exquisite Corpse panels: contribute a blind line to an OPEN
/// constellation, or read a CLOSED one whole — once, never again.
/// The contributor NEVER sees the whole they helped write.

/// Contribute one blind line to an open constellation.
Future<void> showContributeSheet(
  BuildContext context, {
  required WidgetRef ref,
  required ConstellationMeta constellation,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'KENOS_UNE_LIGNE',
    barrierColor: AppColors.voidBlack,
    transitionDuration: const Duration(milliseconds: 500),
    useRootNavigator: true,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _ContributePanel(constellation: constellation),
      );
    },
  );
}

/// Read a closed constellation whole — the only reading it will ever get.
Future<void> showConstellationReading(
  BuildContext context, {
  required List<AssembledLine> lines,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'KENOS_CONSTELLATION',
    barrierColor: AppColors.voidBlack,
    transitionDuration: const Duration(milliseconds: 600),
    useRootNavigator: true,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _ReadingPanel(lines: lines),
      );
    },
  );
}

class _ContributePanel extends ConsumerStatefulWidget {
  const _ContributePanel({required this.constellation});

  final ConstellationMeta constellation;

  @override
  ConsumerState<_ContributePanel> createState() => _ContributePanelState();
}

class _ContributePanelState extends ConsumerState<_ContributePanel> {
  final _input = TextEditingController();
  bool _sending = false;

  static const _maxLength = 140;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _input.text.trim();
    if (text.isEmpty || text.length > _maxLength) return;
    setState(() => _sending = true);
    try {
      final count = await ref
          .read(constellationRepositoryProvider)
          .contribute(constellationId: widget.constellation.id, text: text);
      if (!mounted) return;
      unawaited(
        ref.read(localEchoStoreProvider).recordConstellationTouched(),
      );
      KenosHaptics.pulse(KenosPulse.seal);
      Navigator.of(context, rootNavigator: true).pop();
      _acknowledge(context, count);
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('L\'ÉTHER A REFUSÉ LA LIGNE.')),
        );
      }
    }
  }

  void _acknowledge(BuildContext context, int count) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count >= widget.constellation.target
              ? 'LIGNE DONNÉE — LA CONSTELLATION S\'EST REFERMÉE.'
              : 'LIGNE DONNÉE — TU NE LA RELIRAS JAMAIS.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.constellation;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'UNE LIGNE, À L\'AVEUGLE',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10,
                  letterSpacing: 4,
                  color: AppColors.fade(AppColors.teal, 0.85),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                '${c.lineCount} inconnus ont déjà écrit,\nsans jamais voir le tout.\nTa ligne sera la leur —\nelle ne te reviendra pas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.serifItalic,
                  fontSize: 16,
                  height: 1.8,
                  color: AppColors.fade(AppColors.pureLight, 0.75),
                ),
              ),
              const SizedBox(height: 26),
              TextField(
                controller: _input,
                autofocus: true,
                maxLength: _maxLength,
                maxLines: 1,
                cursorColor: AppColors.teal,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.serifItalic,
                  fontSize: 17,
                  color: const Color(0xFFF4F4F6),
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'une ligne, puis le vide',
                  hintStyle: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 16,
                    color: Color(0x33F4F4F6),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _sending ? null : _send,
                child: Text(_sending ? 'DON…' : 'DONNER LA LIGNE'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                child: const Text('GARDER SON SILENCE'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingPanel extends StatefulWidget {
  const _ReadingPanel({required this.lines});

  final List<AssembledLine> lines;

  @override
  State<_ReadingPanel> createState() => _ReadingPanelState();
}

class _ReadingPanelState extends State<_ReadingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    _fade.forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: AnimatedBuilder(
            animation: _fade,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CONSTELLATION REFERMÉE',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    letterSpacing: 4,
                    color: AppColors.fade(AppColors.teal, 0.75),
                  ),
                ),
                const SizedBox(height: 18),
                // The figure the strangers drew, complete for one breath:
                // every star a line, every segment a hand that passed.
                _CompletedFigure(starCount: widget.lines.length),
                const SizedBox(height: 24),
                for (final line in widget.lines) ...[
                  Opacity(
                    opacity:
                        (1 - (line.number / (widget.lines.length + 1))).clamp(
                      0.15,
                  1.0,
                    ) < _fade.value
                        ? 1.0
                        : 0.0,
                    child: Text(
                      line.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.serifItalic,
                        fontSize: 17,
                        height: 1.9,
                        color: AppColors.fade(
                          AppColors.pureLight,
                          0.55 + 0.4 * (1 - line.number / widget.lines.length),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 26),
                Text(
                  'TU ES LE SEUL À L\'AVOIR LUE ENTIÈRE — ELLE N\'EXISTE PLUS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 8,
                    letterSpacing: 2,
                    color: AppColors.fade(AppColors.pureLight, 0.35),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  child: const Text('RETOURNER AU VIDE'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// V3.11b — the completed figure, shown once above the poem it guards:
/// golden-angle stars (one per line) linked by the strangers' segments.
class _CompletedFigure extends StatelessWidget {
  const _CompletedFigure({required this.starCount});

  final int starCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: CustomPaint(
        painter: _CompletedFigurePainter(starCount: starCount),
      ),
    );
  }
}

class _CompletedFigurePainter extends CustomPainter {
  _CompletedFigurePainter({required this.starCount});

  final int starCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;
    final color = AppColors.indigo;
    final stars = [
      for (var k = 0; k < starCount; k++)
        ConstellationFigure.starAt(k, target: starCount),
    ];

    Offset at(Offset unit) => Offset(
          center.dx + radius * unit.dx,
          center.dy + radius * unit.dy,
        );

    // The strangers' path, complete.
    if (stars.length >= 2) {
      final link = Paint()
        ..color = AppColors.fade(color, 0.45)
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;
      for (var k = 1; k < stars.length; k++) {
        canvas.drawLine(at(stars[k - 1]), at(stars[k]), link);
      }
    }
    canvas.drawCircle(
      center,
      1.2,
      Paint()..color = AppColors.fade(color, 0.8),
    );
    for (final unit in stars) {
      canvas.drawCircle(
        at(unit),
        1.9,
        Paint()..color = AppColors.fade(color, 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_CompletedFigurePainter old) =>
      old.starCount != starCount;
}
