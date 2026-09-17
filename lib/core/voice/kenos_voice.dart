import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The interface voice (V3.52).
///
/// FRENCH IS CANONICAL — the product's own tongue, everywhere, for
/// everyone. English serves only the FIRST JOURNEY (the threshold,
/// the two gates, the Mirror, the revelation, the artifact reading)
/// and only on the WEB build, when the traveller's platform speaks
/// English: a stranger who evaluates the sanctuary in thirty seconds
/// must see the ritual, not a wall of French.
///
/// The laws this voice obeys:
///  - USER CONTENT IS NEVER TRANSLATED (V3.16): sealed thoughts cross
///    borders in the tongue they were whispered in. The voice dresses
///    the doors, never the confidences.
///  - Everything beyond the first journey stays French — the sky, the
///    HUD, the territories, the salons. Deep travellers accept the
///    sanctuary as it speaks.
///  - Native builds keep the canonical voice for now (the wave is a
///    link; the stores are Roadmap+).
///  - Tests resolve FRENCH by construction: `kIsWeb` is false in the
///    VM, so the whole suite keeps asserting the canonical copy. The
///    English journey is pinned by overriding the provider.
enum KenosVoice {
  french,
  english;

  bool get isEnglish => this == english;

  /// The one-word choice: canonical first, the traveller's tongue
  /// second. Every translated line lives exactly here, at its call
  /// site — one source of truth per string.
  String pick(String fr, String en) => this == english ? en : fr;

  /// Pure resolution (testable without a binding): English serves the
  /// first journey on the WEB build only, for an English platform.
  static KenosVoice resolve({required bool web, Locale? platformLocale}) {
    if (!web) return french;
    final language = platformLocale?.languageCode;
    return (language != null && language.startsWith('en'))
        ? english
        : french;
  }
}

/// The live voice: the web build listens to the platform locale, the
/// canonical French answers everywhere else (native, VM tests).
final voiceProvider = Provider<KenosVoice>((ref) {
  return KenosVoice.resolve(
    web: kIsWeb,
    platformLocale: WidgetsBinding.instance.platformDispatcher.locale,
  );
});
