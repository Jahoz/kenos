import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_controller.dart';
import '../../../core/audio/audio_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/haptics/kenos_haptics.dart';
import '../../../core/widgets/scramble_text.dart';
import '../../cosmic_map/application/map_controller.dart';
import '../../echo/data/echo_repository.dart';
import '../../echo/domain/echo_color_theme.dart';

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

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_sealing &&
      _input.text.trim().isNotEmpty &&
      _input.text.length <= _maxLength;

  Future<void> _sealAndLaunch() async {
    if (!_canSend) return;
    setState(() => _sealing = true);
    _focus.unfocus();

    final audio = ref.read(audioControllerProvider);
    final text = _input.text.trim();

    // Security theater: clear text freezes, scrambles, vanishes.
    // The bell rings DURING the sealing, without delaying it.
    KenosHaptics.pulse(KenosPulse.seal);
    audio.playBell(KenosBell.seal);
    await Future<void>.delayed(AppDurations.scramble);

    try {
      await ref
          .read(mapControllerProvider.notifier)
          .sendEcho(text: text, theme: _theme);
      audio.playBell(KenosBell.send);
      KenosHaptics.pulse(KenosPulse.launch);
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sealing = false);
      final message = e is KenosException
          ? e.hudMessage
          : 'L\'ÉTHER A REFUSÉ L\'ÉCHO.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sealing,
      child: Scaffold(
        backgroundColor: AppColors.voidBlack,
        body: SafeArea(
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
                      : TextField(
                          controller: _input,
                          focusNode: _focus,
                          maxLines: null,
                          expands: true,
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
                const SizedBox(height: 18),
                _ThemePicker(
                  selected: _theme,
                  enabled: !_sealing,
                  onChanged: (t) => setState(() => _theme = t),
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
          GestureDetector(
            onTap: enabled
                ? () {
                    KenosHaptics.pulse(KenosPulse.themePick);
                    onChanged(theme);
                  }
                : null,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == theme
                      ? AppColors.pureLight
                      : AppColors.hairlineStrong,
                  width: 1,
                ),
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.core,
                  ),
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
