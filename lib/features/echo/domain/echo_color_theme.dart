import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Chromatic themes of an echo.
///
/// ROSE is reserved for destruction (burn after reading):
/// never selectable at creation time.
enum EchoColorTheme {
  teal('TEAL', 'APAISER', 'Ce qui cherche un peu d\'air.'),
  indigo('INDIGO', 'CONFIER', 'Ce qui pèse et demande à être déposé.'),
  lumen('LUMEN', 'ÉCLAIRER', 'Ce qui veut simplement exister un instant.');

  const EchoColorTheme(this.wire, this.emotionLabel, this.emotionHint);
  final String wire;
  final String emotionLabel;
  final String emotionHint;

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
