import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Chromatic themes of an echo.
///
/// ROSE is reserved for destruction (burn after reading):
/// never selectable at creation time.
enum EchoColorTheme {
  teal('TEAL'),
  indigo('INDIGO'),
  lumen('LUMEN');

  const EchoColorTheme(this.wire);
  final String wire;

  static EchoColorTheme fromWire(
    String? wire, {
    EchoColorTheme fallback = EchoColorTheme.teal,
  }) {
    return EchoColorTheme.values.firstWhere(
      (t) => t.wire == wire,
      orElse: () => fallback,
    );
  }

  /// Stellar core color.
  Color get core => switch (this) {
    EchoColorTheme.teal => AppColors.teal,
    EchoColorTheme.indigo => AppColors.purple,
    EchoColorTheme.lumen => AppColors.pureLight,
  };

  /// Halo / charge ring.
  Color get halo => switch (this) {
    EchoColorTheme.teal => AppColors.cyan,
    EchoColorTheme.indigo => AppColors.indigo,
    EchoColorTheme.lumen => const Color(0xFFB9BBD0),
  };

  /// Themes offered in the Mirror.
  static List<EchoColorTheme> get selectable => const [teal, indigo, lumen];
}
