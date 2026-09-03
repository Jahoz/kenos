import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../core/audio/audio_controller.dart';
import '../../../core/audio/audio_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/constants/app_layout.dart';
import '../../../core/haptics/kenos_haptics.dart';
import '../../../core/widgets/hud.dart';
import '../../../core/widgets/scramble_text.dart';
import '../../constellations/data/constellation_repository.dart';
import '../../cosmic_map/application/map_controller.dart';
import '../../cosmic_map/application/travel_camera.dart';
import '../../echo/data/echo_repository.dart';
import '../../echo/domain/echo_color_theme.dart';
import '../../echo/domain/echo_excerpt.dart';
import '../../echo/domain/echo_media.dart';
import 'widgets/media_draft_preview.dart';

/// The Mirror: shaping the void, visual sealing, launch into the ether.
class MirrorScreen extends ConsumerStatefulWidget {
  const MirrorScreen({super.key});

  @override
  ConsumerState<MirrorScreen> createState() => _MirrorScreenState();
}

class _MirrorScreenState extends ConsumerState<MirrorScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();

  static const _maxLength = 280;

  EchoColorTheme _theme = EchoColorTheme.teal;
  bool _sealing = false;
  bool _corpseMode = false;
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  EchoMediaDraft? _media;
  EchoExcerpt? _excerpt;
  bool _recording = false;
  Timer? _recordingLimit;

  static const _audioLimit = Duration(seconds: 20);

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _recordingLimit?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_sealing &&
      (_input.text.trim().isNotEmpty || _media != null || _excerpt != null) &&
      _input.text.length <= _maxLength;

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 78,
        maxWidth: 1600,
      );
      if (image == null) return;
      final draft = EchoMediaDraft(
        kind: EchoMediaKind.image,
        bytes: await image.readAsBytes(),
        name: image.name,
      );
      if (!mounted) return;
      if (!draft.isWithinLimit) {
        showHud(context, 'CE FRAGMENT VISUEL EST TROP LOURD.');
        return;
      }
      // One attachment per echo: a fragment replaces the door.
      setState(() {
        _media = draft;
        _excerpt = null;
      });
    } catch (e) {
      debugPrint('[kenos.mirror] image pick failed: $e');
      if (mounted) showHud(context, 'LE FRAGMENT VISUEL REFUSE DE VENIR.');
    }
  }

  /// Recording bytes, cross-platform: native paths read via XFile,
  /// web blob: URLs via a same-origin fetch.
  Future<Uint8List> _readRecordingBytes(String path) async {
    if (kIsWeb && path.startsWith('blob:')) {
      final response = await http.get(Uri.parse(path));
      return response.bodyBytes;
    }
    return XFile(path).readAsBytes();
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _stopRecording();
      if (path == null || !mounted) return;
      final draft = EchoMediaDraft(
        kind: EchoMediaKind.audio,
        // On the web, stop() returns a blob: URL that XFile cannot
        // read — fetch it as bytes instead (same-origin).
        bytes: await _readRecordingBytes(path),
        name: path.split('/').last,
      );
      if (!mounted) return;
      if (!mounted) return;
      if (!draft.isWithinLimit) {
        showHud(context, 'CE FRAGMENT SONORE EST TROP LOURD.');
        return;
      }
      setState(() {
        _recording = false;
        _media = draft;
        _excerpt = null;
      });
      return;
    }
    final hasPermission = await _recorder.hasPermission();
    if (!mounted) return;
    if (!hasPermission) {
      showHud(context, 'LE MICROPHONE RESTE FERMÉ.');
      return;
    }
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 22050,
        numChannels: 1,
      ),
      path: 'kenos-${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
    if (mounted) {
      setState(() => _recording = true);
      _recordingLimit = Timer(_audioLimit, () async {
        if (!mounted || !_recording) return;
        await _toggleRecording();
      });
    }
  }

  Future<String?> _stopRecording() async {
    _recordingLimit?.cancel();
    _recordingLimit = null;
    return _recorder.stop();
  }

  /// V3.10 — the cultural door: paste a Spotify or YouTube link. The
  /// reference travels sealed under the echo's ephemeral key; only the
  /// single reader will be able to open it.
  ///
  /// v3.10b — the web platform has ONE editing host: leaving the
  /// Mirror's connection open while the dialog opens interleaves the
  /// two fields, and parsing before the composition is committed read
  /// stale state — doors were silently dropped on send. The fix: tear
  /// down the Mirror's connection first, and commit the dialog's
  /// editing state BEFORE parsing it.
  Future<void> _pasteExcerptLink() async {
    _focus.unfocus();
    final controller = TextEditingController();
    final dialogFocus = FocusNode();
    var sealing = false;
    Future<void> sealTheDoor(BuildContext dialogContext) async {
      if (sealing) return;
      sealing = true;
      // Closing the editing connection flushes any pending composition
      // into the controller — only a committed value may be parsed.
      dialogFocus.unfocus();
      await WidgetsBinding.instance.endOfFrame;
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop(EchoExcerpt.parseLink(controller.text));
    }

    final excerpt = await showDialog<EchoExcerpt?>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.voidBlack,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.fade(AppColors.pureLight, 0.18)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'UNE PORTE CULTURELLE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    letterSpacing: 3,
                    color: AppColors.pureLight,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Colle un lien Spotify ou YouTube.\n'
                  'Il voyagera scellé avec ton écho — seul le lecteur '
                  'unique pourra l\'ouvrir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 14,
                    height: 1.7,
                    color: AppColors.fade(AppColors.pureLight, 0.55),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  focusNode: dialogFocus,
                  autofocus: true,
                  cursorColor: AppColors.teal,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 12,
                    color: AppColors.pureLight,
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'https://…',
                    hintStyle: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 12,
                      color: Color(0x40F4F4F6),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => sealTheDoor(dialogContext),
                  child: const Text('SCELLER LA PORTE'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('ANNULER'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final pasted = controller.text.trim();
    controller.dispose();
    dialogFocus.dispose();
    if (!mounted) return;
    if (excerpt == null) {
      // Only scold when something was actually pasted: cancelling an
      // empty dialog is renouncing, not failing.
      if (pasted.isNotEmpty) {
        showHud(context, 'CE LIEN N\'EST NI SPOTIFY NI YOUTUBE.');
      }
      return;
    }
    setState(() {
      _excerpt = excerpt;
      _media = null; // one attachment per echo
    });
  }

  Future<void> _sealAndLaunch() async {
    if (!_canSend) return;
    setState(() => _sealing = true);
    _focus.unfocus();

    final audio = ref.read(audioControllerProvider);
    final text = _input.text.trim();

    // Security theater: clear text freezes, scrambles, vanishes.
    // The bell rings DURING the sealing, without delaying it.
    KenosHaptics.pulse(KenosPulse.seal);
    unawaited(audio.playBell(KenosBell.seal));
    await Future<void>.delayed(AppDurations.scramble);

    try {
      await ref
          .read(mapControllerProvider.notifier)
          .sendEcho(
            text: text,
            theme: _theme,
            media: _media,
            excerpt: _excerpt,
          );
      unawaited(audio.playBell(KenosBell.send));
      KenosHaptics.pulse(KenosPulse.launch);
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sealing = false);
      String message;
      if (e is KenosException) {
        message = e.code == KenosErrorCode.rateLimit
            ? 'REVIENS DANS 20 SECONDES.\nFRICTION COMME VERTU.'
            : e.hudMessage;
      } else {
        message = 'L\'ÉTHER A REFUSÉ L\'ÉCHO.';
      }
      showHud(context, message);
    }
  }

  /// The exquisite corpse: drop an open ring near where the eye
  /// rests. No text from the author — strangers will write it blind,
  /// and the ring pops with the result so the map can offer the
  /// seeder to give the FIRST line (they are just another stranger).
  Future<void> _dropCorpse() async {
    if (_sealing) return;
    setState(() => _sealing = true);
    _focus.unfocus();
    KenosHaptics.pulse(KenosPulse.seal);
    try {
      final eye = ref.read(travelPositionProvider);
      final rng = Random();
      final meta = await ref.read(constellationRepositoryProvider).seed(
            (eye.dx + (rng.nextDouble() - 0.5) * 0.12).clamp(0.05, 0.95),
            (eye.dy + (rng.nextDouble() - 0.5) * 0.12).clamp(0.05, 0.95),
          );
      unawaited(ref.read(audioControllerProvider).playBell(KenosBell.send));
      KenosHaptics.pulse(KenosPulse.launch);
      if (!mounted) return;
      Navigator.of(context).pop(meta.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sealing = false);
      showHud(context, 'L\'ÉTHER A REFUSÉ LE CADAVRE.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sealing,
      child: Scaffold(
        backgroundColor: AppColors.voidBlack,
        // Portrait webapp: the keyboard folds the layout so the field
        // stays in view — one never types blind.
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              // Normal case: the column fills the screen exactly
              // (Expanded works). Keyboard open: the fixed rows scroll
              // away and the editor keeps its readable window.
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  // Full-bleed sky, readable measure: the editor stands
                  // in a centered column on wide windows.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayout.contentMaxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 18, 26, 26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                'MIROIR',
                                style: TextStyle(
                                  fontFamily: AppFonts.mono,
                                  fontSize: 9,
                                  letterSpacing: 4,
                                  color: AppColors.fade(AppColors.cyan, 0.6),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _sealing
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('RENONCER'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _corpseMode
                                ? 'Un cadavre exquis'
                                : 'La formulation du vide',
                            style: TextStyle(
                              fontFamily: AppFonts.serifItalic,
                              fontSize: 26,
                              color: AppColors.fade(AppColors.pureLight, 0.92),
                            ),
                          ),
                          if (_corpseMode) ...[
                            const SizedBox(height: 28),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Des inconnus y écriront une ligne chacun,\n'
                                  'chacun voyant seulement la ligne qui le\n'
                                  'précède. Refermé, le poème devient un\n'
                                  'artefact : lisible par tous — toi aussi.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppFonts.serifItalic,
                                    fontSize: 16,
                                    height: 1.9,
                                    color: AppColors.fade(AppColors.pureLight, 0.62),
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              'L\'ANNEAU NAÎTRA PRÈS DE LÀ OÙ REPOSE TON REGARD',
                              style: TextStyle(
                                fontFamily: AppFonts.mono,
                                fontSize: 8.5,
                                letterSpacing: 2,
                                color: AppColors.fade(AppColors.pureLight, 0.4),
                              ),
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton(
                              onPressed: _sealing ? null : _dropCorpse,
                              child: Text(
                                _sealing ? 'LARGUAGE…' : 'LARGUER DANS L\'ÉTHER',
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'TU LE LIRAS REFERMÉ — JAMAIS EN TRAIN DE SE FAIRE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: AppFonts.mono,
                                fontSize: 8,
                                letterSpacing: 2,
                                color: AppColors.fade(AppColors.pureLight, 0.3),
                              ),
                            ),
                          ] else ...[
                          const SizedBox(height: 28),
                          Expanded(
                            child: _sealing
                                ? SingleChildScrollView(
                                    child: ScrambleText(
                                      text: _input.text,
                                      resolve: false,
                                      style: secretStyle(fontSize: 18),
                                    ),
                                  )
                                : ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 100,
                                    ),
                                    child: TextField(
                                      controller: _input,
                                      focusNode: _focus,
                                      maxLines: null,
                                      minLines: 3,
                                      autofocus: true,
                                      maxLength: _maxLength,
                                      cursorColor: AppColors.teal,
                                      style: secretStyle(fontSize: 18),
                                      decoration: const InputDecoration(
                                        counterStyle: TextStyle(
                                          fontFamily: AppFonts.mono,
                                          fontSize: 9,
                                          letterSpacing: 2,
                                          color: Color(0x66F4F4F6),
                                        ),
                                        border: InputBorder.none,
                                        hintText:
                                            'Écris ce que tu ne dis nulle part.\nPersonne ne saura. Même pas toi, après.',
                                        hintStyle: TextStyle(
                                          fontFamily: AppFonts.serifItalic,
                                          fontSize: 18,
                                          height: 1.75,
                                          color: Color(0x40F4F4F6),
                                        ),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 18),
                          if (!_sealing)
                            _ModeStrip(
                              recording: _recording,
                              hasFragment: _media != null,
                              hasDoor: _excerpt != null,
                              onImage: _recording ? null : _pickImage,
                              onSound: _toggleRecording,
                              onDoor: _recording ? null : _pasteExcerptLink,
                              onCorpse: () =>
                                  setState(() => _corpseMode = true),
                            ),
                          // The attached fragment, made visible: thumbnail or
                          // waveform, private listen, one-tap removal.
                          if (_media != null) ...[
                            MediaDraftPreview(
                              media: _media!,
                              onRemoved: () => setState(() => _media = null),
                            ),
                            const SizedBox(height: 10),
                          ],
                          // The sealed door, made visible: what the reader will
                          // be able to open, once, outside the void.
                          if (_excerpt != null) ...[
                            _ExcerptDraftChip(
                              excerpt: _excerpt!,
                              onRemoved: () => setState(() => _excerpt = null),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 8),
                          _ThemePicker(
                            selected: _theme,
                            enabled: !_sealing,
                            onChanged: (t) => setState(() => _theme = t),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _theme.emotionHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppFonts.serifItalic,
                              fontSize: 13,
                              color: AppColors.fade(AppColors.pureLight, 0.5),
                            ),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton(
                            onPressed: _canSend ? _sealAndLaunch : null,
                            child: Text(
                              _sealing ? 'SCELLEMENT…' : 'SCELLER & LANCER',
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'UNE SEULE LECTURE POSSIBLE — AUCUN RETOUR — AUCUNE TRACE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppFonts.mono,
                              fontSize: 8,
                              letterSpacing: 2,
                              color: AppColors.fade(AppColors.pureLight, 0.3),
                            ),
                          ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Mirror's modes, NAMED: icon-only buttons were invisible to the
/// finger (tooltips never show on touch) — people launched plain text
/// without ever knowing a fragment, a door or a corpse existed. Same
/// grammar as the HUD: quiet mono labels, teal when alive.
class _ModeStrip extends StatelessWidget {
  const _ModeStrip({
    required this.recording,
    required this.hasFragment,
    required this.hasDoor,
    required this.onImage,
    required this.onSound,
    required this.onDoor,
    required this.onCorpse,
  });

  final bool recording;
  final bool hasFragment;
  final bool hasDoor;
  final VoidCallback? onImage;
  final VoidCallback? onSound;
  final VoidCallback? onDoor;
  final VoidCallback? onCorpse;

  @override
  Widget build(BuildContext context) {
    Widget mode(
      String label,
      VoidCallback? onPressed,
      Color? active,
    ) =>
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 9,
              letterSpacing: 3,
              color: active ?? AppColors.fade(AppColors.pureLight, 0.55),
            ),
          ),
        );
    const dot = Text(
      '·',
      style: TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: 9,
        color: Color(0x33F4F4F6),
      ),
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          mode(
            'IMAGE',
            onImage,
            hasFragment ? AppColors.teal : null,
          ),
          dot,
          mode(
            recording ? 'ARRÊTER' : 'SON',
            onSound,
            recording ? AppColors.rose : (hasFragment ? AppColors.teal : null),
          ),
          dot,
          mode(
            'PORTE',
            onDoor,
            hasDoor ? AppColors.teal : null,
          ),
          dot,
          mode('CADAVRE', onCorpse, AppColors.fade(AppColors.indigo, 0.9)),
        ],
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final EchoColorTheme selected;
  final ValueChanged<EchoColorTheme> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final theme in EchoColorTheme.selectable) ...[
            Semantics(
              button: true,
              label: theme.emotionLabel,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: enabled
                    ? () {
                        KenosHaptics.pulse(KenosPulse.themePick);
                        onChanged(theme);
                      }
                    : null,
                child: Text(
                  theme.emotionLabel,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: selected == theme
                        ? theme.core
                        : AppColors.fade(AppColors.pureLight, 0.55),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

/// The sealed door, made visible before launch: what it is, where it
/// leads, one-tap removal. The author sees the door they give — the
/// reader will have to hold for it.
class _ExcerptDraftChip extends StatelessWidget {
  const _ExcerptDraftChip({required this.excerpt, required this.onRemoved});

  final EchoExcerpt excerpt;
  final VoidCallback onRemoved;

  String get _origin => switch (excerpt.kind) {
    EchoExcerptKind.song => 'open.spotify.com',
    EchoExcerptKind.video =>
      excerpt.startSeconds > 0
          ? 'youtube.com · ${_format(excerpt.startSeconds)}'
          : 'youtube.com',
  };

  static String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isSong = excerpt.kind == EchoExcerptKind.song;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairlineStrong),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.voidBlackDeep,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Icon(
                isSong
                    ? Icons.music_note_outlined
                    : Icons.smart_display_outlined,
                size: 26,
                color: AppColors.fade(AppColors.teal, 0.8),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  excerpt.kind.label,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    letterSpacing: 3,
                    color: AppColors.fade(AppColors.pureLight, 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _origin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 8,
                    letterSpacing: 1,
                    color: AppColors.fade(AppColors.pureLight, 0.45),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SCELLÉE AVEC L\'ÉCHO — LE LECTEUR SEUL L\'OUVRIRA',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 7.5,
                    letterSpacing: 1.5,
                    color: AppColors.fade(AppColors.pureLight, 0.3),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Retirer la porte',
            onPressed: onRemoved,
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.fade(AppColors.pureLight, 0.6),
          ),
        ],
      ),
    );
  }
}

/// The attached excerpt, made visible: which song or video travels
/// with the echo — a door for the single winner to open.
