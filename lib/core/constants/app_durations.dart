/// KENOS experience durations and constants.
/// Friction is a feature: nothing should be instantaneous.
class AppDurations {
  AppDurations._();

  /// The "Mindful Hold": long press required to intercept an echo.
  static const Duration mindfulHold = Duration(milliseconds: 3000);

  /// Reading window before destruction.
  static const Duration burnWindow = Duration(seconds: 10);

  /// Dissolve transition of a read echo.
  static const Duration dissolve = Duration(milliseconds: 900);

  /// Standard route fade — no abrupt screen changes.
  static const Duration routeFade = Duration(milliseconds: 550);

  /// Scramble effect (visual sealing / decryption).
  static const Duration scramble = Duration(milliseconds: 1400);
}
