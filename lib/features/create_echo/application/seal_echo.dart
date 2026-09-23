import '../../../core/voice/kenos_voice.dart';
import '../../echo/data/echo_repository.dart';
import '../../echo/domain/pii_guard.dart';

/// The Mirror's use case — the « create an echo » decisions, pure and
/// testable (the screen stays dressing: fields, chips, ceremony).
///
/// Every rule here was inline in the Mirror's state before the
/// 2026-09-23 audit; it lives as an object now.
class SealEcho {
  const SealEcho._();

  /// The secret's hard ceiling (the server bounds the SEAL, the
  /// client bounds the thought — see ADR-002).
  static const int maxLength = 280;

  /// Whether the seal may be armed: a non-blank secret OR a real
  /// attachment (a fragment or a cultural door may carry the echo
  /// alone), always under the ceiling.
  static bool canSend({
    required String text,
    bool hasMedia = false,
    bool hasExcerpt = false,
  }) =>
      (text.trim().isNotEmpty || hasMedia || hasExcerpt) &&
      text.length <= maxLength;

  /// The PII gate: the author's last quiet look, BEFORE the sealing.
  /// Once sealed, the ether is structurally blind to the thought —
  /// the device-side look is the only warning there will ever be.
  /// Warn, never block.
  static bool needsPiiWarning(String text) => PiiGuard.carriesIdentity(text);

  /// What the HUD says when the launch fails. The rate limit keeps
  /// its own remedy (friction as a virtue); every other functional
  /// refusal speaks its [KenosException.hudMessage]; anything else is
  /// the ether refusing the echo, said plainly.
  static String launchFailureMessage(Object error, KenosVoice voice) {
    if (error is KenosException) {
      return error.code == KenosErrorCode.rateLimit
          ? voice.pick(
              'REVIENS DANS 20 SECONDES.\nFRICTION COMME VERTU.',
              'COME BACK IN 20 SECONDS.\nFRICTION AS A VIRTUE.',
            )
          : error.hudMessage;
    }
    return voice.pick(
      'L\'ÉTHER A REFUSÉ L\'ÉCHO.',
      'THE ETHER REFUSED THE ECHO.',
    );
  }

  /// The cultural door's verdict once the dialog closes: a parsed
  /// link is KEPT; a cancelled empty dialog is RENOUNCEMENT (not a
  /// failure — nothing was refused); pasted-and-unparseable is
  /// MALFORMED (the only case the sky scolds).
  static ExcerptDoorVerdict excerptVerdict({
    required String pasted,
    required Object? parsed,
  }) {
    if (parsed != null) return ExcerptDoorVerdict.keep;
    return pasted.trim().isEmpty
        ? ExcerptDoorVerdict.renounce
        : ExcerptDoorVerdict.malformed;
  }
}

/// What closing the cultural door's dialog meant.
enum ExcerptDoorVerdict { keep, renounce, malformed }

/// The PII acknowledgement, one draft's memory: the warning is asked
/// once per secret — an author who chose to proceed is not asked
/// again for the same thought.
class PiiGate {
  bool _acknowledged = false;

  /// Whether the sealing ceremony must open the anonymity warning
  /// for this text.
  bool shouldWarn(String text) =>
      !_acknowledged && SealEcho.needsPiiWarning(text);

  /// The author saw the warning and chose to proceed.
  void acknowledge() => _acknowledged = true;
}
