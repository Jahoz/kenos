import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/audio_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/haptics/kenos_haptics.dart';
import '../../../../core/widgets/anonymity_warning.dart';
import '../../cosmic_map/data/artifact_memory.dart';
import '../../echo/data/echo_providers.dart';
import '../../echo/domain/pii_guard.dart';
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
  required String figureId,
  String? curatedBy,
  ArtifactMemory? memory,
  Offset? keepPosition,
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
        child: _ReadingPanel(
          lines: lines,
          figureId: figureId,
          curatedBy: curatedBy,
          memory: memory,
          keepPosition: keepPosition,
        ),
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
  bool _piiAcknowledged = false;
  AssembledLine? _previous;
  bool _peeked = false;

  /// SONG mode: the composer's draft — notes AND the rhythm the
  /// fingers actually played.
  NotePhrase? _draft;

  /// The composer pad, addressable for EFFACER.
  final GlobalKey<_ComposerPadState> _padKey = GlobalKey<_ComposerPadState>();

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
    if (mounted) {
      setState(() {
        _previous = previous;
        _peeked = true;
      });
    }
  }

  /// One note, best-effort: the spatial engine when it lives, the
  /// baked wave asset otherwise. The song never blocks, never throws.
  Future<void> _playNote(
    int noteIndex, {
    double pan = 0,
    double gain = 0.6,
  }) async {
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
        // The silence of a dead engine is also an answer.
      }
    }
  }

  /// Plays a phrase at ITS OWN RHYTHM — each note held exactly as
  /// long as the stranger held it, the pan sweeping the stereo field
  /// with the progression. Fire-and-forget from every caller.
  Future<void> _playPhrase(NotePhrase phrase) async {
    final holds = phrase.holds;
    final n = phrase.notes.length;
    for (var i = 0; i < n; i++) {
      unawaited(
        _playNote(phrase.notes[i], pan: -0.6 + 1.2 * (i / (n - 1).clamp(1, 7))),
      );
      await Future<void>.delayed(Duration(milliseconds: holds[i]));
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
        ? (_draft == null || _draft!.notes.isEmpty ? null : _draft!.encode())
        : _input.text.trim().isEmpty
        ? null
        : _input.text.trim();
    if (payload == null) return;
    if (!_isSong && payload.length > _maxLength) return;

    // The PII guard (poem only — a song is notes, anonymous by
    // construction): the line seals on this device, and the sealed
    // line is structurally invisible to the ether. This quiet look is
    // the only warning there will ever be. Warn, never block.
    if (!_isSong && !_piiAcknowledged && PiiGuard.carriesIdentity(payload)) {
      final proceed = await warnAnonymityLoss(
        context,
        body:
            'Cette ligne semble porter des données personnelles.\n\n'
            'Elle dérivera scellée avec le poème — lisible, un jour, par '
            'ses auteurs. L\'anonymat, lui, ne revient pas.',
        takeBackLabel: 'REPRENDRE MA LIGNE',
      );
      if (!mounted || !proceed) return;
      _piiAcknowledged = true;
    }

    setState(() => _sending = true);
    try {
      final result = await ref
          .read(constellationRepositoryProvider)
          .contribute(constellationId: widget.constellation.id, text: payload);
      if (!mounted) return;
      // One line per stranger per corpse, remembered: the sky will
      // never again OFFER composition to hands that already gave.
      unawaited(
        ref.read(artifactMemoryProvider).markContributed(
              widget.constellation.id,
            ),
      );
      unawaited(ref.read(localEchoStoreProvider).recordConstellationTouched());
      KenosHaptics.pulse(KenosPulse.seal);
      // The messenger is captured BEFORE the pop: the ack used to
      // look up ScaffoldMessenger through this panel's context AFTER
      // the dialog died — 'deactivated widget's ancestor' threw, the
      // catch buried a SUCCESS under 'L'ÉTHER A REFUSÉ LA LIGNE'
      // while the line sat safely in the ether (caught live in prod).
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context, rootNavigator: true).pop();
      _acknowledge(messenger, result.count);
    } catch (e) {
      debugPrint('[kenos.constellations] contribute refused: $e');
      if (mounted) {
        setState(() => _sending = false);
        // The writer deserves the ether's actual reason, never a
        // shrug (the live catch: ALREADY_CONTRIBUTED answered
        // 'refused' to hands the app itself had re-offered).
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(contributeRefusalMessage(e))),
        );
      }
    }
  }

  void _acknowledge(ScaffoldMessengerState messenger, int count) {
    messenger.showSnackBar(
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
                    _isSong ? 'LA PHRASE QUI PRÉCÈDE' : 'LA LIGNE QUI PRÉCÈDE',
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
                        if (phrase != null) unawaited(_playPhrase(phrase));
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
                // The composer: tap the void — the HEIGHT is the note
                // (bottom = low, top = crystalline, the waves' own
                // mapping), the TIME is the finger's own rhythm
                // (every interval between touches is recorded and
                // travels sealed with the phrase). The score writes
                // itself left → right; the hue follows the phrase's
                // progression (the symphonies' palette).
                _ComposerPad(
                  key: _padKey,
                  onChanged: (phrase) => setState(() => _draft = phrase),
                  onPlayNote: (note) => unawaited(_playNote(note)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _draft == null || _draft!.notes.isEmpty
                          ? null
                          : () => unawaited(_playPhrase(_draft!)),
                      child: const Text('ÉCOUTER MA PHRASE'),
                    ),
                    TextButton(
                      onPressed: _draft == null || _draft!.notes.isEmpty
                          ? null
                          : () {
                              _padKey.currentState?.clear();
                              setState(() => _draft = null);
                            },
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
                  // Without this the send button never wakes: typing
                  // alone rebuilds nothing (caught by the empty-send
                  // tests — the void gives nothing, but a line must
                  // revive the gesture).
                  onChanged: (_) => setState(() {}),
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
                // The void gives nothing to the void: an empty line —
                // written or sung — never leaves the device.
                onPressed:
                    _sending ||
                        (_isSong
                            ? _draft == null || _draft!.notes.isEmpty
                            : _input.text.trim().isEmpty)
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
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
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

/// The song composer pad: tap the void, the note lands EXACTLY where
/// the finger fell. The note comes from the tap's height (bottom =
/// low, top = crystalline — the waves' own mapping), the dot's HUE
/// from its horizontal band (the symphonies' palette: purple left →
/// cyan right), so a phrase reads like a little wave-field.
///
/// Size comes from a LayoutBuilder — the first version divided by the
/// PANEL's render box instead of the pad's, and every note landed
/// off-pitch (the décalage). Never again: the pad is its own widget,
/// its geometry its own truth.
/// The gesture's thread: a hairline joining the touches in played
/// order — the rhythm stays readable while every dot keeps its own
/// place under the finger that made it.
class _GestureThreadPainter extends CustomPainter {
  _GestureThreadPainter({required this.taps});

  final List<({int note, int atMs, double x, double y})> taps;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.fade(AppColors.pureLight, 0.18)
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < taps.length; i++) {
      canvas.drawLine(
        Offset(taps[i - 1].x * size.width, taps[i - 1].y * size.height),
        Offset(taps[i].x * size.width, taps[i].y * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GestureThreadPainter oldDelegate) =>
      oldDelegate.taps.length != taps.length;
}

class _ComposerPad extends StatefulWidget {
  const _ComposerPad({
    super.key,
    required this.onChanged,
    required this.onPlayNote,
  });

  /// The whole living draft — notes AND the rhythm the fingers
  /// played. Null when the pad is empty.
  final ValueChanged<NotePhrase?> onChanged;
  final void Function(int note) onPlayNote;

  @override
  State<_ComposerPad> createState() => _ComposerPadState();
}

class _ComposerPadState extends State<_ComposerPad> {
  static const padWidth = 260.0;
  static const padHeight = 170.0;

  /// Every touch: the note (from the tap's height) and the instant
  /// it landed (a clock started at the FIRST touch). The intervals
  /// between touches ARE the rhythm — recorded live, sealed with the
  /// phrase, never flattened again.
  final List<({int note, int atMs, double x, double y})> _taps = [];
  final Stopwatch _clock = Stopwatch();

  NotePhrase? get _phrase {
    if (_taps.isEmpty) return null;
    final holds = <int>[
      for (var i = 0; i < _taps.length; i++)
        // The last note's hold ends the phrase; the others last
        // exactly as long as the stranger waited before the next.
        i == _taps.length - 1
            ? NotePhrase.defaultHoldMs
            : _taps[i + 1].atMs - _taps[i].atMs,
    ];
    return NotePhrase([for (final t in _taps) t.note], holds);
  }

  void clear() => setState(() {
    _taps.clear();
    _clock.stop();
    _clock.reset();
    widget.onChanged(null);
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: padWidth,
      height: padHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.maxWidth == double.infinity
                ? padWidth
                : constraints.maxWidth,
            constraints.maxHeight == double.infinity
                ? padHeight
                : constraints.maxHeight,
          );
          // The score writes itself left → right: each dot's X is
          // its TIME in the phrase (normalized to the pad). With one
          // note only, the span is the default hold — the dot starts
          // at the left edge, writing begins.
          final spanMs = _taps.isEmpty
              ? 1
              : (_taps.last.atMs).clamp(NotePhrase.defaultHoldMs, 1 << 30);
          double timeX(int i) =>
              0.05 + 0.9 * (_taps[i].atMs / spanMs).clamp(0.0, 1.0);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              if (_taps.length >= NotePhrase.maxNotes) return;
              if (!_clock.isRunning && _taps.isEmpty) _clock.start();
              // The dot lands EXACTLY where the finger touched: the
              // height is the note (quantized by the scale — a note
              // IS discrete), the width is the touch's own place. The
              // RHYTHM stays in the intervals between touches, never
              // in a displaced score.
              final y = (details.localPosition.dy / size.height).clamp(
                0.0,
                1.0,
              );
              final x = (details.localPosition.dx / size.width).clamp(0.0, 1.0);
              final note = WaveMath.noteForY(y);
              setState(
                () => _taps.add((
                  note: note,
                  atMs: _clock.elapsedMilliseconds,
                  x: x,
                  y: y,
                )),
              );
              widget.onPlayNote(note);
              widget.onChanged(_phrase);
            },
            child: Container(
              key: const Key('song_composer_pad'),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.hairlineStrong),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The gesture's own thread: touches joined in the
                  // order they were played — the rhythm, made visible
                  // without displacing a single dot.
                  if (_taps.length >= 2)
                    CustomPaint(
                      size: size,
                      painter: _GestureThreadPainter(taps: _taps),
                    ),
                  for (final (i, t) in _taps.indexed)
                    Positioned(
                      left: t.x * size.width - 5,
                      top: t.y * size.height - 5,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // The symphonies' hue grammar, riding the
                          // phrase's TIME: the band it was born in.
                          // Later notes breathe brighter.
                          color: AppColors.fade(
                            WavePalette.hueFor(WaveMath.hueForX(timeX(i))),
                            0.45 + 0.55 * (i + 1) / NotePhrase.maxNotes,
                          ),
                        ),
                      ),
                    ),
                  if (_taps.isEmpty)
                    const Center(
                      child: Text(
                        'TOUCHE — LA HAUTEUR EST LA NOTE,\nLE RYTHME EST TON GESTE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 7.5,
                          letterSpacing: 2,
                          height: 1.9,
                          color: Color(0x40F4F4F6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReadingPanel extends ConsumerStatefulWidget {
  const _ReadingPanel({
    required this.lines,
    required this.figureId,
    this.curatedBy,
    this.memory,
    this.keepPosition,
  });

  final List<AssembledLine> lines;

  /// The corpse's identity: it signs the figure (rotation, spin,
  /// first ring) so no two artifacts share a sky.
  final String figureId;

  /// The traveller's artifact memory: the read outlives the session,
  /// and the artifact may be KEPT in one's own sky (the reliquaire).
  final ArtifactMemory? memory;

  /// The seed position (logical [0,1]) — where a kept artifact pins.
  final Offset? keepPosition;

  /// The Curator's attribution: a curated reading NAMES the poet —
  /// it never pretends strangers wrote public-domain poetry.
  final String? curatedBy;

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

  /// The reliquaire's quiet answer after LE GARDER.
  String? _keepAck;

  Future<void> _keep() async {
    final memory = widget.memory;
    final position = widget.keepPosition;
    if (memory == null || position == null) return;
    final released = await memory.keep(
      KeptArtifact(
        id: widget.figureId,
        kind: 'constellation',
        x: position.dx,
        y: position.dy,
        texts: [for (final l in widget.lines) l.text],
        target: widget.lines.length,
        keptAt: DateTime.now().millisecondsSinceEpoch,
        curatedBy: widget.curatedBy,
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
    setState(() {
      _songAlive = true;
    });
    for (var p = 0; p < _phrases!.length; p++) {
      if (!mounted || !_songAlive) return;
      setState(() => _playingPhrase = p);
      final station = ConstellationFigure.starAt(
        p,
        target: _phrases!.length,
        id: widget.figureId,
      );
      final pan = station.dx.clamp(-1.0, 1.0);
      final gain = 0.85 - 0.3 * ((station.dy + 1) / 2);
      final phrase = _phrases![p];
      final holds = phrase.holds;
      for (var i = 0; i < phrase.notes.length; i++) {
        if (!mounted || !_songAlive) return;
        unawaited(_playNote(phrase.notes[i], pan: pan, gain: gain));
        // Each note held exactly as long as the stranger held it:
        // the rhythm crosses the ether with the melody.
        await Future<void>.delayed(Duration(milliseconds: holds[i]));
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    if (mounted) setState(() => _playingPhrase = -1);
  }

  Future<void> _playNote(
    int noteIndex, {
    double pan = 0,
    double gain = 0.6,
  }) async {
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
            builder: (context, _) => SingleChildScrollView(
              // A closed artifact can carry seven long lines and a
              // singing figure: on a phone, the poem must SCROLL —
              // never overflow the sky it lives in.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song != null
                        ? 'CHANSON REFERMÉE'
                        : 'CONSTELLATION REFERMÉE',
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
                    figureId: widget.figureId,
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
                            (1 - (line.number / (widget.lines.length + 1)))
                                    .clamp(0.15, 1.0) <
                                _fade.value
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
                              0.55 +
                                  0.4 * (1 - line.number / widget.lines.length),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 26),
                  Text(
                    widget.curatedBy != null
                        ? '— ${widget.curatedBy} —'
                        : song != null
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
                  if (widget.memory != null && widget.keepPosition != null) ...[
                    if (_keepAck == null &&
                        !widget.memory!.isKept(widget.figureId))
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
                      )
                    else if (_keepAck != null)
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
                    const SizedBox(height: 12),
                  ],
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
      ),
    );
  }
}

/// V3.11b — the completed figure, shown once above the poem it guards:
/// golden-angle stars (one per line) linked by the strangers' segments.
/// V3.14 — in a SONG, the singing phrase's station breathes cyan.
class _CompletedFigure extends StatelessWidget {
  const _CompletedFigure({
    required this.figureId,
    required this.starCount,
    this.singingPhrase = -1,
  });

  final String figureId;
  final int starCount;
  final int singingPhrase;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: CustomPaint(
        painter: _CompletedFigurePainter(
          figureId: figureId,
          starCount: starCount,
          singingPhrase: singingPhrase,
        ),
      ),
    );
  }
}

class _CompletedFigurePainter extends CustomPainter {
  _CompletedFigurePainter({
    required this.figureId,
    required this.starCount,
    this.singingPhrase = -1,
  });

  final String figureId;
  final int starCount;
  final int singingPhrase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;
    final color = AppColors.indigo;
    final stars = [
      for (var k = 0; k < starCount; k++)
        ConstellationFigure.starAt(k, target: starCount, id: figureId),
    ];

    Offset at(Offset unit) =>
        Offset(center.dx + radius * unit.dx, center.dy + radius * unit.dy);

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
    canvas.drawCircle(center, 1.2, Paint()..color = AppColors.fade(color, 0.8));
    for (final (k, unit) in stars.indexed) {
      // The singing phrase's station breathes cyan, larger.
      final singing = k == singingPhrase;
      canvas.drawCircle(
        at(unit),
        singing ? 3.4 : 1.9,
        Paint()..color = singing ? AppColors.cyan : AppColors.fade(color, 0.85),
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
