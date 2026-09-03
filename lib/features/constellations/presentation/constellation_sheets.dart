import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/audio_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/haptics/kenos_haptics.dart';
import '../../echo/data/echo_providers.dart';
import '../../frequencies/application/spatial_wave_audio.dart';
import '../../frequencies/domain/kenos_wave.dart';
import '../data/constellation_repository.dart';
import '../domain/constellation_figure.dart';
import '../domain/note_phrase.dart';
/// The Exquisite Corpse panels: contribute a line by continuing the
/// preceding one (the classic rule — nobody sees the whole while it
/// writes itself), or read a CLOSED poem — an artifact, open to
/// everyone, re-readable like the vestiges.

/// Contribute one line to an open constellation, continuing the poem.
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

/// Read a finished constellation — an artifact: it stays, refermé.
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
  AssembledLine? _previous;
  bool _peeked = false;

  /// SONG mode: the composer's draft (note indices into the waves'
  /// pentatonic scale).
  final List<int> _draft = [];

  static const _maxLength = 140;

  bool get _isSong => widget.constellation.kind == ConstellationKind.melody;

  @override
  void initState() {
    super.initState();
    _peekPrevious();
  }

  /// The classic rule, sonorous or written: one CONTINUES. The tail
  /// of the poem/song shows itself before the line is given — never
  /// the whole.
  Future<void> _peekPrevious() async {
    final previous = await ref
        .read(constellationRepositoryProvider)
        .peekPrevious(widget.constellation.id);
    if (mounted) setState(() { _previous = previous; _peeked = true; });
  }

  /// One note, best-effort: the spatial engine when it lives, the
  /// baked wave asset otherwise. The song never blocks, never throws.
  Future<void> _playNote(int noteIndex, {double pan = 0}) async {
    final spatial = await SpatialWaveAudio.instance.playNote(
      noteIndex,
      pan: pan,
      gain: 0.6,
    );
    if (!spatial) {
      try {
        await ref
            .read(audioControllerProvider)
            .playAsset(WaveMath.assetForNote(noteIndex));
      } catch (_) {
        // The silence of a dead engine is also an answer.
      }
    }
  }

  Future<void> _playPhrase(Iterable<int> notes) async {
    final list = notes.toList();
    for (var i = 0; i < list.length; i++) {
      // Pan sweeps the stereo field with the phrase's progression.
      unawaited(_playNote(list[i], pan: -0.6 + 1.2 * (i / 7)));
      await Future<void>.delayed(
        const Duration(milliseconds: NotePhrase.phraseNoteSpacingMs),
      );
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final payload = _isSong
        ? (_draft.isEmpty ? null : NotePhrase(_draft).encode())
        : _input.text.trim().isEmpty ? null : _input.text.trim();
    if (payload == null) return;
    if (!_isSong && payload.length > _maxLength) return;
    setState(() => _sending = true);
    try {
      final result = await ref
          .read(constellationRepositoryProvider)
          .contribute(constellationId: widget.constellation.id, text: payload);
      if (!mounted) return;
      unawaited(
        ref.read(localEchoStoreProvider).recordConstellationTouched(),
      );
      KenosHaptics.pulse(KenosPulse.seal);
      Navigator.of(context, rootNavigator: true).pop();
      _acknowledge(context, result.count);
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
              ? _isSong
                  ? 'PHRASE DONNÉE — LA CHANSON S\'EST REFERMÉE.'
                  : 'LIGNE DONNÉE — LA CONSTELLATION S\'EST REFERMÉE.'
              : _isSong
                  ? 'PHRASE DONNÉE — LA CHANSON GRANDIT.'
                  : 'LIGNE DONNÉE — LE POÈME GRANDIT.',
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
                _isSong
                    ? '${c.lineCount} inconnus ont déjà joué,\nsans jamais entendre le tout.\nTa phrase continuera la leur.'
                    : '${c.lineCount} inconnus ont déjà écrit,\nsans jamais voir le tout.\nTa ligne sera la leur —\nelle ne te reviendra pas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.serifItalic,
                  fontSize: 16,
                  height: 1.8,
                  color: AppColors.fade(AppColors.pureLight, 0.75),
                ),
              ),
              const SizedBox(height: 24),
              if (_peeked)
                if (_previous != null) ...[
                  Text(
                    _isSong
                        ? 'LA PHRASE QUI PRÉCÈDE'
                        : 'LA LIGNE QUI PRÉCÈDE',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 9,
                      letterSpacing: 3,
                      color: AppColors.fade(AppColors.teal, 0.6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_isSong)
                    TextButton(
                      onPressed: () {
                        final phrase = NotePhrase.tryParse(_previous!.text);
                        if (phrase != null) unawaited(_playPhrase(phrase.notes));
                      },
                      child: const Text('ÉCOUTER'),
                    )
                  else
                    Text(
                      '«${_previous!.text}»',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.serifItalic,
                        fontSize: 17,
                        height: 1.6,
                        color: AppColors.fade(AppColors.pureLight, 0.88),
                      ),
                    ),
                ] else
                  Text(
                    _isSong
                        ? 'TU OUVRES LA CHANSON — LA PREMIÈRE PHRASE EST À TOI.'
                        : 'TU OUVRES LE POÈME — LA PREMIÈRE LIGNE EST À TOI.',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 8.5,
                      letterSpacing: 2,
                      color: AppColors.fade(AppColors.teal, 0.6),
                    ),
                  ),
              const SizedBox(height: 22),
              if (_isSong) ...[
                // The composer: tap the void, the note lands where the
                // finger fell (bottom = low, top = crystalline — the
                // waves' own mapping). ≤ 8 notes.
                SizedBox(
                  width: 260,
                  height: 170,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      if (_draft.length >= NotePhrase.maxNotes) return;
                      final box =
                          context.findRenderObject() as RenderBox?;
                      final size = box?.size ?? const Size(260, 170);
                      final local = details.localPosition;
                      final note = WaveMath.noteForY(
                        (local.dy / size.height).clamp(0.0, 1.0),
                      );
                      setState(() => _draft.add(note));
                      unawaited(_playNote(note));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.hairlineStrong),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          for (final (i, n) in _draft.indexed)
                            Align(
                              alignment: Alignment(
                                -1 + 2 * (i / (NotePhrase.maxNotes - 1)),
                                1 - 2 * (n / (WaveMath.noteCount - 1)),
                              ),
                              child: Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.fade(
                                    AppColors.cyan,
                                    0.4 + 0.5 * (i / NotePhrase.maxNotes),
                                  ),
                                ),
                              ),
                            ),
                          if (_draft.isEmpty)
                            const Center(
                              child: Text(
                                'TOUCHE LE VIDE — CHAQUE TOUCHE EST UNE NOTE',
                                style: TextStyle(
                                  fontFamily: AppFonts.mono,
                                  fontSize: 7.5,
                                  letterSpacing: 2,
                                  color: Color(0x40F4F4F6),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed:
                          _draft.isEmpty ? null : () => unawaited(_playPhrase(_draft)),
                      child: const Text('ÉCOUTER MA PHRASE'),
                    ),
                    TextButton(
                      onPressed: _draft.isEmpty
                          ? null
                          : () => setState(() => _draft.clear()),
                      child: const Text('EFFACER'),
                    ),
                  ],
                ),
              ] else
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
                onPressed: _sending ||
                        (_isSong && _draft.isEmpty)
                    ? null
                    : _send,
                child: Text(
                  _sending
                      ? 'DON…'
                      : _isSong
                          ? 'DONNER LA PHRASE'
                          : 'DONNER LA LIGNE',
                ),
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

class _ReadingPanel extends ConsumerStatefulWidget {
  const _ReadingPanel({required this.lines});

  final List<AssembledLine> lines;

  @override
  ConsumerState<_ReadingPanel> createState() => _ReadingPanelState();
}

class _ReadingPanelState extends ConsumerState<_ReadingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// SONG mode: the melody phrases, the playing cursor, the guard
  /// that dies with the panel (sequential playback — one phrase at a
  /// time, the overload answer).
  List<NotePhrase>? _phrases;
  int _playingPhrase = -1;
  bool _songAlive = false;

  @override
  void initState() {
    super.initState();
    _fade.forward();
    // A song is known by its first line: a sealed note phrase, not
    // text. If every line parses, the corpse sings.
    final parsed = [
      for (final line in widget.lines) NotePhrase.tryParse(line.text),
    ];
    if (parsed.isNotEmpty && parsed.every((p) => p != null)) {
      _phrases = [for (final p in parsed) p!];
      Future<void>.delayed(const Duration(milliseconds: 700), _playSong);
    }
  }

  /// The figure sings: phrase after phrase, each at its golden-angle
  /// station — panned across the stereo field by the station's place
  /// in the void. Sequential by design: the app carries one phrase
  /// at a time, never the whole at once.
  Future<void> _playSong() async {
    if (!mounted || _phrases == null) return;
    setState(() { _songAlive = true; });
    for (var p = 0; p < _phrases!.length; p++) {
      if (!mounted || !_songAlive) return;
      setState(() => _playingPhrase = p);
      final station = ConstellationFigure.starAt(
        p,
        target: _phrases!.length,
      );
      final pan = station.dx.clamp(-1.0, 1.0);
      final gain = 0.85 - 0.3 * ((station.dy + 1) / 2);
      for (final note in _phrases![p].notes) {
        if (!mounted || !_songAlive) return;
        unawaited(_playNote(note, pan: pan, gain: gain));
        await Future<void>.delayed(
          const Duration(milliseconds: NotePhrase.phraseNoteSpacingMs),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    if (mounted) setState(() => _playingPhrase = -1);
  }

  Future<void> _playNote(int noteIndex, {double pan = 0, double gain = 0.6}) async {
    final spatial = await SpatialWaveAudio.instance.playNote(
      noteIndex,
      pan: pan,
      gain: gain,
    );
    if (!spatial) {
      try {
        await ref
            .read(audioControllerProvider)
            .playAsset(WaveMath.assetForNote(noteIndex));
      } catch (_) {
        // A dead engine sings in silence.
      }
    }
  }

  @override
  void dispose() {
    _songAlive = false;
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = _phrases;
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
                  song != null ? 'CHANSON REFERMÉE' : 'CONSTELLATION REFERMÉE',
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
                _CompletedFigure(
                  starCount: widget.lines.length,
                  singingPhrase: _playingPhrase,
                ),
                const SizedBox(height: 24),
                if (song != null) ...[
                  // The song traverses: phrase by phrase, the singing
                  // station breathing with the sound.
                  Text(
                    _playingPhrase >= 0
                        ? 'PHRASE ${_playingPhrase + 1} / ${song.length}'
                        : 'LA FIGURE CHANTE — CHAQUE PHRASE À SA STATION',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 8.5,
                      letterSpacing: 3,
                      color: _playingPhrase >= 0
                          ? AppColors.fade(AppColors.cyan, 0.85)
                          : AppColors.fade(AppColors.pureLight, 0.4),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () {
                      _songAlive = false;
                      Future<void>.delayed(
                        const Duration(milliseconds: 200),
                        _playSong,
                      );
                    },
                    child: const Text('REJOUER LA CHANSON'),
                  ),
                ] else
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
                  song != null
                      ? 'UNE CHANSON D\'ÉTRANGERS — ELLE RESTE, REFERMÉE'
                      : 'UN POÈME D\'ÉTRANGERS — IL RESTE, REFERMÉ',
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
/// V3.14 — in a SONG, the singing phrase's station breathes cyan.
class _CompletedFigure extends StatelessWidget {
  const _CompletedFigure({required this.starCount, this.singingPhrase = -1});

  final int starCount;
  final int singingPhrase;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: CustomPaint(
        painter: _CompletedFigurePainter(
          starCount: starCount,
          singingPhrase: singingPhrase,
        ),
      ),
    );
  }
}

class _CompletedFigurePainter extends CustomPainter {
  _CompletedFigurePainter({required this.starCount, this.singingPhrase = -1});

  final int starCount;
  final int singingPhrase;

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
    for (final (k, unit) in stars.indexed) {
      // The singing phrase's station breathes cyan, larger.
      final singing = k == singingPhrase;
      canvas.drawCircle(
        at(unit),
        singing ? 3.4 : 1.9,
        Paint()
          ..color = singing
              ? AppColors.cyan
              : AppColors.fade(color, 0.85),
      );
      if (singing) {
        canvas.drawCircle(
          at(unit),
          6.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = AppColors.fade(AppColors.cyan, 0.45),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CompletedFigurePainter old) =>
      old.starCount != starCount || old.singingPhrase != singingPhrase;
}
