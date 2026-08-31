import 'package:flutter/material.dart';

import '../constants/app_durations.dart';
import '../constants/app_fonts.dart';
import '../utils/motion_preferences.dart';

const _glyphs = '█▓▒░#%&@*<>~^/\\|=+';

/// "Scramble" text effect — KENOS security theater.
///
/// [resolve] = true  : emerges from undecipherable noise into clear text
///                     (decryption of an intercepted echo).
/// [resolve] = false : clear text decomposes into undecipherable
///                     characters (sealing before launch).
class ScrambleText extends StatefulWidget {
  const ScrambleText({
    super.key,
    required this.text,
    this.style,
    this.resolve = true,
    this.duration = AppDurations.scramble,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final bool resolve;
  final Duration duration;
  final TextAlign? textAlign;

  @override
  State<ScrambleText> createState() => _ScrambleTextState();
}

class _ScrambleTextState extends State<ScrambleText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  final _random = DateTime.now().microsecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    if (platformDisablesAnimations()) {
      // « Reduce animations »: jump straight to the final state —
      // resolved text (reveal) or full noise (sealing).
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _displayed {
    final chars = widget.text.characters.toList();
    final progress = _controller.value;
    final resolvedCount = widget.resolve
        ? (progress * chars.length).floor()
        : ((1 - progress) * chars.length).floor();
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      if (chars[i] == '\n') {
        buffer.write('\n');
        continue;
      }
      if (i < resolvedCount) {
        buffer.write(chars[i]);
      } else {
        final seed = (_random + i * 31 + _controller.value * 1000).round();
        buffer.write(_glyphs[seed.abs() % _glyphs.length]);
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) =>
          Text(_displayed, style: widget.style, textAlign: widget.textAlign),
    );
  }
}

/// Default style of a revealed secret: the Human, in italic serif.
TextStyle secretStyle({double fontSize = 19}) => TextStyle(
  fontFamily: AppFonts.serifItalic,
  fontSize: fontSize,
  height: 1.75,
  color: const Color(0xFFF4F4F6),
);
