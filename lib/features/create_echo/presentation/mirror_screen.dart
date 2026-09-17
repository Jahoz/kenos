import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/voice/kenos_voice.dart';
import '../../../core/widgets/anonymity_warning.dart';
import '../../../core/widgets/hud.dart';
import '../../../core/widgets/scramble_text.dart';
import '../../cosmic_map/application/map_controller.dart';
import '../../echo/data/echo_repository.dart';
import '../../echo/domain/echo_color_theme.dart';
import '../../echo/domain/echo_excerpt.dart';
import '../../echo/domain/echo_media.dart';
import '../../echo/domain/pii_guard.dart';
import '../data/origin_whisper.dart';
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

  /// V3.52 — the first journey's voice, resolved once (a session never
  /// changes its tongue mid-thought).
  KenosVoice get _voice => ref.read(voiceProvider);

  EchoColorTheme _theme = EchoColorTheme.teal;
  bool _sealing = false;
  bool _piiAcknowledged = false;
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  EchoMediaDraft? _media;
  EchoExcerpt? _excerpt;
  bool _recording = false;
  Timer? _recordingLimit;

  /// V3.26 — the shore's name (opt-in): resolved in the browser when
  /// the author asks, sent only if they keep it.
  String? _origin;
  bool _originResolving = false;
  bool _originUnreachable = false;

  /// V3.26d — open resolves (ipwho.is, then geojs.io), close unnamed.
  /// One flight at a time; a failure is told on the line itself,
  /// never blocking the launch.
  Future<void> _toggleOrigin() async {
    if (_originResolving) return;
    if (_origin != null) {
      setState(() => _origin = null);
      return;
    }
    setState(() {
      _originResolving = true;
      _originUnreachable = false;
    });
    final label = await OriginWhisper.resolve();
    if (!mounted) return;
    setState(() {
      _originResolving = false;
      _origin = label;
      _originUnreachable = label == null;
    });
  }

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
        showHud(
          context,
          _voice.pick(
            'CE FRAGMENT VISUEL EST TROP LOURD.',
            'THIS VISUAL FRAGMENT IS TOO HEAVY.',
          ),
        );
        return;
      }
      // One attachment per echo: a fragment replaces the door.
      setState(() {
        _media = draft;
        _excerpt = null;
      });
    } catch (e) {
      debugPrint('[kenos.mirror] image pick failed: $e');
      if (mounted) {
        showHud(
          context,
          _voice.pick(
            'LE FRAGMENT VISUEL REFUSE DE VENIR.',
            'THE VISUAL FRAGMENT REFUSES TO COME.',
          ),
        );
      }
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
        showHud(
          context,
          _voice.pick(
            'CE FRAGMENT SONORE EST TROP LOURD.',
            'THIS SOUND FRAGMENT IS TOO HEAVY.',
          ),
        );
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
      showHud(
        context,
        _voice.pick('LE MICROPHONE RESTE FERMÉ.', 'THE MICROPHONE STAYS SHUT.'),
      );
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
                  _voice.pick('UNE PORTE CULTURELLE', 'A CULTURAL DOOR'),
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
                  _voice.pick(
                    'Colle un lien Spotify ou YouTube.\n'
                    'Il voyagera scellé avec ton écho — seul le lecteur '
                    'unique pourra l\'ouvrir.',
                    'Paste a Spotify or YouTube link.\n'
                    'It will travel sealed with your echo — only the single '
                    'reader will open it.',
                  ),
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
                  child: Text(_voice.pick('SCELLER LA PORTE', 'SEAL THE DOOR')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(_voice.pick('ANNULER', 'CANCEL')),
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
        showHud(
          context,
          _voice.pick(
            'CE LIEN N\'EST NI SPOTIFY NI YOUTUBE.',
            'THIS LINK IS NEITHER SPOTIFY NOR YOUTUBE.',
          ),
        );
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

    // The PII guard: the author's last quiet look, BEFORE the sealing
    // ceremony. Once sealed, the ether is structurally blind to the
    // thought — this device-side look (phone/email, zero network) is
    // the only warning there will ever be. Warn, never block.
    if (!_piiAcknowledged && PiiGuard.carriesIdentity(_input.text)) {
      final proceed = await warnAnonymityLoss(
        context,
        voice: _voice,
        body: _voice.pick(
          'Ce que tu t\'apprêtes à sceller semble porter des données '
          'personnelles.\n\nUn seul inconnu les lira — mais il suffit : '
          'l\'anonymat, lui, ne revient pas.',
          'What you are about to seal seems to carry personal data.\n\nOne '
          'single stranger will read it — but that is enough: anonymity '
          'never comes back.',
        ),
        takeBackLabel: _voice.pick(
          'REPRENDRE MA PENSÉE',
          'TAKE MY THOUGHT BACK',
        ),
      );
      if (!mounted || !proceed) return;
      _piiAcknowledged = true;
    }

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
            origin: _origin ?? '',
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
            ? _voice.pick(
                'REVIENS DANS 20 SECONDES.\nFRICTION COMME VERTU.',
                'COME BACK IN 20 SECONDS.\nFRICTION AS A VIRTUE.',
              )
            : e.hudMessage;
      } else {
        message = _voice.pick(
          'L\'ÉTHER A REFUSÉ L\'ÉCHO.',
          'THE ETHER REFUSED THE ECHO.',
        );
      }
      showHud(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    // V3.44 — ESC renounces (the desktop's universal reflex); never
    // while the seal is in flight — a thought being sealed is beyond
    // retreat by then, the gesture should be too.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_sealing) Navigator.of(context).pop();
        },
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: !_sealing,
          child: Scaffold(
            backgroundColor: AppColors.voidBlack,
            // Portrait webapp: the keyboard folds the layout so the field
            // stays in view — one never types blind.
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // V3.43b — the measure follows the disposition: the
                  // wide composer escapes the phone's 560 cap (inside it,
                  // two columns were two cramped ones in a centered band
                  // — the very thing the wide layout came to fix).
                  final wide =
                      constraints.maxWidth >= AppLayout.mirrorTwoColumns;
                  // Centered like the constellation screen's own panel:
                  // without the Center, the readable column PINS to the
                  // left edge on any wider window (the Aube's old bug,
                  // resurrected by the V3.42 refactor — V3.43d).
                  return Center(
                    child: SingleChildScrollView(
                      // Fill-or-scroll (V3.42): when the column is smaller
                      // than the window it stretches and centers; when it is
                      // taller (keyboard open, small windows) it simply
                      // scrolls.
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: wide
                                ? AppLayout.mirrorWideMaxWidth
                                : AppLayout.contentMaxWidth,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(26, 18, 26, 26),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _voice.pick('MIROIR', 'MIRROR'),
                                      style: TextStyle(
                                        fontFamily: AppFonts.mono,
                                        fontSize: 9,
                                        letterSpacing: 4,
                                        color: AppColors.fade(
                                          AppColors.cyan,
                                          0.6,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: _sealing
                                          ? null
                                          : () => Navigator.of(context).pop(),
                                      child: Text(
                                        _voice.pick('RENONCER', 'RENOUNCE'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _voice.pick(
                                    'La formulation du vide',
                                    'The shaping of the void',
                                  ),
                                  style: TextStyle(
                                    fontFamily: AppFonts.serifItalic,
                                    fontSize: 26,
                                    color: AppColors.fade(
                                      AppColors.pureLight,
                                      0.92,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                // V3.42 — THE SENSE OF THE MIRROR: the
                                // intention comes FIRST (it is the echo's
                                // gravity), the editor is BOUNDED, and the
                                // attachments are real chips with a visible
                                // ＋. V3.43 — wide windows get a DISPOSITION,
                                // not a stretched phone: past
                                // [AppLayout.mirrorTwoColumns] the Mirror
                                // composes in two columns — the secret to
                                // the left, every choice and the seal to the
                                // right, nothing to scroll.
                                if (wide) ...[
                                  _wideComposer(),
                                ] else ...[
                                  _intentionCaption(),
                                  const SizedBox(height: 8),
                                  _ThemePicker(
                                    voice: _voice,
                                    selected: _theme,
                                    enabled: !_sealing,
                                    onChanged: (t) =>
                                        setState(() => _theme = t),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _voice.isEnglish
                                        ? _theme.emotionHintEn
                                        : _theme.emotionHint,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppFonts.serifItalic,
                                      fontSize: 13,
                                      color: AppColors.fade(
                                        AppColors.pureLight,
                                        0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _editorField(
                                    minHeight: 110,
                                    maxHeight: 260,
                                    minLines: 4,
                                    maxLines: 9,
                                  ),
                                  const SizedBox(height: 16),
                                  _attachSection(),
                                  _previewsSection(),
                                  const SizedBox(height: 8),
                                  _originSection(),
                                  const SizedBox(height: 14),
                                  _sealButton(),
                                  const SizedBox(height: 14),
                                  _sealWhisper(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
  // ── The Mirror's pieces (V3.43) ──────────────────────────────────
  // One set of parts, two dispositions: the phone column (V3.42's
  // pinned order) and the wide composer below. Same widgets, same
  // laws — only the geometry changes.

  /// The intention's quiet caption.
  Widget _intentionCaption() => Text(
    _voice.pick("L'INTENTION", 'THE INTENTION'),
    style: TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: 8,
      letterSpacing: 3,
      color: AppColors.fade(AppColors.cyan, 0.55),
    ),
  );

  /// The secret's field, bounded. Tall on wide windows (the desktop
  /// owes the confidence room), compact on phones.
  Widget _editorField({
    required double minHeight,
    required double maxHeight,
    required int minLines,
    required int maxLines,
  }) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
    child: _sealing
        ? SingleChildScrollView(
            child: ScrambleText(
              text: _input.text,
              resolve: false,
              style: secretStyle(fontSize: 18),
            ),
          )
        : TextField(
            controller: _input,
            focusNode: _focus,
            maxLines: maxLines,
            minLines: minLines,
            autofocus: true,
            maxLength: _maxLength,
            cursorColor: AppColors.teal,
            style: secretStyle(fontSize: 18),
            decoration: InputDecoration(
              counterStyle: const TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 9,
                letterSpacing: 2,
                color: Color(0x66F4F4F6),
              ),
              border: InputBorder.none,
              hintText: _voice.pick(
                'Écris ce que tu ne dis nulle part.\n'
                'Personne ne saura. Même pas toi, après.',
                'Write what you say nowhere else.\n'
                'No one will know. Not even you, after.',
              ),
              hintStyle: TextStyle(
                fontFamily: AppFonts.serifItalic,
                fontSize: 18,
                height: 1.75,
                color: Color(0x40F4F4F6),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
  );

  /// The attachments, SEEN before they are chosen: one line of prose
  /// says what may travel, the chips say it in the hand.
  Widget _attachSection() {
    if (_sealing) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _voice.pick(
            'Une seule chose peut voyager avec elle, '
            'scellée sous la même clé :',
            'One single thing may travel with it, '
            'sealed under the same key:',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.serifItalic,
            fontSize: 12.5,
            height: 1.5,
            color: AppColors.fade(AppColors.pureLight, 0.5),
          ),
        ),
        const SizedBox(height: 8),
        _AttachRow(
          voice: _voice,
          recording: _recording,
          hasFragment: _media != null,
          hasDoor: _excerpt != null,
          onImage: _recording ? null : _pickImage,
          onSound: _toggleRecording,
          onDoor: _recording ? null : _pasteExcerptLink,
        ),
      ],
    );
  }

  /// The attached fragment and the sealed door, made visible.
  Widget _previewsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_media != null) ...[
        MediaDraftPreview(
          media: _media!,
          onRemoved: () => setState(() => _media = null),
        ),
        const SizedBox(height: 10),
      ],
      if (_excerpt != null) ...[
        _ExcerptDraftChip(
          voice: _voice,
          excerpt: _excerpt!,
          onRemoved: () => setState(() => _excerpt = null),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );

  /// V3.26d — the origin is INFO about the echo, never a fourth
  /// fragment type. Touch names the shore, touch again unnamed.
  Widget _originSection() {
    if (_sealing) return const SizedBox.shrink();
    return _OriginLine(
      voice: _voice,
      label: _origin,
      resolving: _originResolving,
      unreachable: _originUnreachable,
      onToggle: _toggleOrigin,
    );
  }

  /// The seal, in the first door's family (V3.41): opaque
  /// teal-washed surface, teal border, near-full light. Kept an
  /// OutlinedButton: the send-path tests pin it.
  Widget _sealButton() => OutlinedButton(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
      minimumSize: const Size(0, 46),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: _canSend || _sealing
          ? Color.alphaBlend(
              AppColors.fade(AppColors.teal, 0.10),
              AppColors.voidBlack,
            )
          : AppColors.voidBlack,
      side: BorderSide(
        color: AppColors.fade(
          AppColors.teal,
          (_canSend || _sealing) ? 0.85 : 0.35,
        ),
        width: 1.2,
      ),
    ),
    onPressed: _canSend ? _sealAndLaunch : null,
    child: Text(
      _sealing
          ? _voice.pick('SCELLEMENT…', 'SEALING…')
          : _voice.pick('SCELLER & LANCER', 'SEAL & RELEASE'),
      style: TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: 10.5,
        letterSpacing: 4,
        color: AppColors.fade(
          AppColors.pureLight,
          (_canSend || _sealing) ? 0.95 : 0.5,
        ),
      ),
    ),
  );

  Widget _sealWhisper() => Text(
    _voice.pick(
      'UNE SEULE LECTURE POSSIBLE — AUCUN RETOUR — AUCUNE TRACE',
      'ONE SINGLE READING — NO RETURN — NO TRACE',
    ),
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: 8,
      letterSpacing: 2,
      color: AppColors.fade(AppColors.pureLight, 0.3),
    ),
  );

  /// V3.43 — THE WIDE COMPOSER: the secret owns the left column
  /// (tall, unbounded by a thumb's screen), every choice and the seal
  /// stand to its right — the width carries the sense, nothing
  /// scrolls on a window that has room.
  Widget _wideComposer() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 11,
        child: _editorField(
          minHeight: 340,
          maxHeight: 640,
          minLines: 12,
          maxLines: 26,
        ),
      ),
      const SizedBox(width: 46),
      Expanded(
        flex: 9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _intentionCaption(),
            const SizedBox(height: 10),
            _ThemePicker(
              voice: _voice,
              selected: _theme,
              enabled: !_sealing,
              onChanged: (t) => setState(() => _theme = t),
            ),
            const SizedBox(height: 8),
            Text(
              _voice.isEnglish ? _theme.emotionHintEn : _theme.emotionHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.serifItalic,
                fontSize: 13,
                color: AppColors.fade(AppColors.pureLight, 0.5),
              ),
            ),
            const SizedBox(height: 26),
            _attachSection(),
            _previewsSection(),
            const SizedBox(height: 12),
            _originSection(),
            const SizedBox(height: 18),
            _sealButton(),
            const SizedBox(height: 12),
            _sealWhisper(),
          ],
        ),
      ),
    ],
  );
}

/// The Mirror's attachments, SEEN: named chips with a visible ＋
/// (V3.42 — the old dotted whisper 'IMAGE · SON · PORTE' at 9 px was
/// a footnote nobody read; the capabilities were secrets). Each chip
/// is a real target: bordered, 38 px tall, teal when something rides.
/// The labels stay EXACT ('IMAGE'/'SON'/'PORTE') — the ＋ lives beside
/// the name, never inside it.
class _AttachRow extends StatelessWidget {
  const _AttachRow({
    required this.voice,
    required this.recording,
    required this.hasFragment,
    required this.hasDoor,
    required this.onImage,
    required this.onSound,
    required this.onDoor,
  });

  final KenosVoice voice;
  final bool recording;
  final bool hasFragment;
  final bool hasDoor;
  final VoidCallback? onImage;
  final VoidCallback? onSound;
  final VoidCallback? onDoor;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, VoidCallback? onPressed, bool riding) {
      final alive = onPressed != null || riding;
      final ink = riding ? AppColors.teal : AppColors.pureLight;
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          // V3.44 — the thumb's law: 44 px, like the doors.
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: AppColors.fade(ink, riding ? 0.75 : 0.28),
              width: 1,
            ),
          ),
          backgroundColor: riding
              ? Color.alphaBlend(
                  AppColors.fade(AppColors.teal, 0.10),
                  AppColors.voidBlack,
                )
              : AppColors.voidBlack,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              riding ? '·' : '＋',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 11,
                color: AppColors.fade(ink, riding ? 0.9 : 0.65),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 9.5,
                letterSpacing: 2,
                color: AppColors.fade(ink, riding ? 0.95 : (alive ? 0.7 : 0.4)),
              ),
            ),
          ],
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          chip(voice.pick('IMAGE', 'IMAGE'), onImage, hasFragment),
          const SizedBox(width: 8),
          chip(
            voice.pick(recording ? 'ARRÊTER' : 'SON', recording ? 'STOP' : 'SOUND'),
            onSound,
            recording || hasFragment,
          ),
          const SizedBox(width: 8),
          chip(voice.pick('PORTE', 'DOOR'), onDoor, hasDoor),
        ],
      ),
    );
  }
}

/// V3.26d — the origin is complementary INFO, never a fourth type:
/// a quiet, borderless, WRAPPING meta line. It reads as an attribute
/// of the echo (« parti de … »), not as one of the fragment modes,
/// and no label length can ever overflow it.
class _OriginLine extends StatelessWidget {
  const _OriginLine({
    required this.voice,
    required this.label,
    required this.resolving,
    required this.unreachable,
    required this.onToggle,
  });

  final KenosVoice voice;
  final String? label;
  final bool resolving;
  final bool unreachable;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final named = label != null;
    final text = resolving
        ? voice.pick('NOMMER L\'ORIGINE…', 'NAMING THE ORIGIN…')
        : named
        ? voice.pick(
            'PARTI DE ${label!.toUpperCase()} — TOUCHER POUR RETIRER',
            'SET OUT FROM ${label!.toUpperCase()} — TOUCH TO REMOVE',
          )
        : unreachable
        ? voice.pick(
            'ORIGINE INJOIGNABLE — TOUCHER POUR RÉESSAYER',
            'ORIGIN UNREACHABLE — TOUCH TO TRY AGAIN',
          )
        : voice.pick('NOMMER L\'ORIGINE', 'NAME THE ORIGIN');
    return GestureDetector(
      onTap: resolving ? null : onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 8.5,
            letterSpacing: 2,
            height: 1.6,
            color: named
                ? AppColors.fade(AppColors.teal, 0.8)
                : AppColors.fade(AppColors.pureLight, 0.4),
          ),
        ),
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.voice = KenosVoice.french,
  });

  final EchoColorTheme selected;
  final ValueChanged<EchoColorTheme> onChanged;
  final KenosVoice voice;

  String _labelOf(EchoColorTheme theme) =>
      voice.isEnglish ? theme.emotionLabelEn : theme.emotionLabel;
  final bool enabled;

  /// V3.42 — the intentions as PILLS: the choice is the echo's
  /// gravity, it comes FIRST and it must look choosable — the old
  /// plain-text row at the screen's bottom read as a caption. The
  /// selected pill carries its theme's own light (fill, border,
  /// text); the others keep a quiet hairline.
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
              label: _labelOf(theme),
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: selected == theme
                          ? AppColors.fade(theme.core, 0.85)
                          : AppColors.fade(AppColors.pureLight, 0.24),
                      width: selected == theme ? 1.2 : 1,
                    ),
                  ),
                  backgroundColor: selected == theme
                      ? Color.alphaBlend(
                          AppColors.fade(theme.core, 0.14),
                          AppColors.voidBlack,
                        )
                      : AppColors.voidBlack,
                ),
                onPressed: enabled
                    ? () {
                        KenosHaptics.pulse(KenosPulse.themePick);
                        onChanged(theme);
                      }
                    : null,
                child: Text(
                  _labelOf(theme),
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    letterSpacing: 2,
                    color: selected == theme
                        ? AppColors.fade(theme.core, 0.95)
                        : AppColors.fade(AppColors.pureLight, 0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
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
  const _ExcerptDraftChip({
    required this.excerpt,
    required this.onRemoved,
    this.voice = KenosVoice.french,
  });

  final EchoExcerpt excerpt;
  final VoidCallback onRemoved;
  final KenosVoice voice;

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
                  voice.pick(
                    'SCELLÉE AVEC L\'ÉCHO — LE LECTEUR SEUL L\'OUVRIRA',
                    'SEALED WITH THE ECHO — ONLY THE READER OPENS IT',
                  ),
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
            tooltip: voice.pick('Retirer la porte', 'Remove the door'),
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
