import 'dart:async';
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
import '../../../core/haptics/kenos_haptics.dart';
import '../../../core/widgets/hud.dart';
import '../../../core/widgets/scramble_text.dart';
import '../../cosmic_map/application/map_controller.dart';
import '../../echo/data/echo_repository.dart';
import '../../echo/domain/echo_color_theme.dart';
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
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  EchoMediaDraft? _media;
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
      (_input.text.trim().isNotEmpty || _media != null) &&
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
      setState(() => _media = draft);
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
          .sendEcho(text: text, theme: _theme, media: _media);
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
                  'La formulation du vide',
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 26,
                    color: AppColors.fade(AppColors.pureLight, 0.92),
                  ),
                ),
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
                          constraints: const BoxConstraints(minHeight: 100),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Choisir une image',
                        onPressed: _recording ? null : _pickImage,
                        icon: const Icon(Icons.photo_outlined),
                      ),
                      IconButton(
                        tooltip: _recording
                            ? 'Terminer l\'enregistrement'
                            : 'Enregistrer un son',
                        onPressed: _toggleRecording,
                        icon: Icon(_recording ? Icons.stop : Icons.mic_none),
                        color: _recording ? AppColors.rose : AppColors.teal,
                      ),
                    ],
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
                  child: Text(_sealing ? 'SCELLEMENT…' : 'SCELLER & LANCER'),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final theme in EchoColorTheme.selectable) ...[
          Semantics(
            button: true,
            label: theme.emotionLabel,
            child: TextButton(
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
                  fontSize: 8,
                  letterSpacing: 1.5,
                  color: selected == theme
                      ? theme.core
                      : AppColors.fade(AppColors.pureLight, 0.38),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
        ],
      ],
    );
  }
}
