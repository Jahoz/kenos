import 'package:flutter/widgets.dart';

/// « Reducing animations » — accessibility, KENOS-side.
///
/// The platform flag (iOS "Reduce Motion", Android "Remove animations")
/// is respected everywhere: decorative motion freezes, ambient parallax
/// calms down, transitions become instant. What survives is functional:
/// the 10-second reading window (it IS the product), the countdown, and
/// essential haptic feedback.
extension MotionPreferences on BuildContext {
  /// True when the user asked the system to reduce animations.
  bool get wantsReducedMotion =>
      MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}

/// Same flag, readable from `initState` — reads the platform dispatcher
/// directly instead of depending on an inherited widget.
bool platformDisablesAnimations() =>
    WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
