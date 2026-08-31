import 'package:flutter/services.dart';

/// KENOS haptic vocabulary — one pulse per meaning, never noise.
///
/// Fire-and-forget by design (same rule as the audio layer): a haptic
/// must never block or delay the UI.
enum KenosPulse {
  /// Fingertip lands on a star of the ether.
  holdStart,

  /// Slow heartbeat while the Mindful Hold charges (decorative).
  holdBeat,

  /// The 3 s hold completes — the interception begins.
  holdComplete,

  /// An echo just got decrypted in front of one's eyes.
  reveal,

  /// The reading window closes: the echo is burning.
  burn,

  /// Someone else read it first — it dissolved elsewhere.
  intercepted,

  /// A bottle-in-the-sea signal just landed for one of our echoes.
  signal,

  /// The Mirror seals the text.
  seal,

  /// The sealed echo leaves the device for the ether.
  launch,

  /// A color theme is picked in the Mirror.
  themePick,
}

/// Enriched haptics with a single accessibility rule: when the platform
/// asks to reduce motion, ESSENTIAL single pulses survive (the product's
/// friction and feedback), REPETITIVE or purely decorative patterns stop.
class KenosHaptics {
  KenosHaptics._();

  static void pulse(KenosPulse pulse, {bool reduceMotion = false}) {
    switch (pulse) {
      case KenosPulse.holdStart:
        HapticFeedback.lightImpact();
      case KenosPulse.holdBeat:
        if (!reduceMotion) HapticFeedback.selectionClick();
      case KenosPulse.holdComplete:
        HapticFeedback.mediumImpact();
      case KenosPulse.reveal:
        HapticFeedback.selectionClick();
      case KenosPulse.burn:
        // Mourning: one heavy strike, then the void.
        HapticFeedback.heavyImpact();
        if (!reduceMotion) {
          Future<void>.delayed(
            const Duration(milliseconds: 200),
            HapticFeedback.lightImpact,
          );
        }
      case KenosPulse.intercepted:
        HapticFeedback.selectionClick();
      case KenosPulse.signal:
        HapticFeedback.lightImpact();
      case KenosPulse.seal:
        HapticFeedback.selectionClick();
      case KenosPulse.launch:
        HapticFeedback.lightImpact();
        if (!reduceMotion) {
          Future<void>.delayed(
            const Duration(milliseconds: 140),
            HapticFeedback.mediumImpact,
          );
        }
      case KenosPulse.themePick:
        if (!reduceMotion) HapticFeedback.selectionClick();
    }
  }
}
