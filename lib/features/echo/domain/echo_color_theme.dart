import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Chromatic themes of an echo.
///
/// ROSE is reserved for destruction (burn after reading):
/// never selectable at creation time.
enum EchoColorTheme {
  teal(
    'TEAL',
    'APAISER',
    'Ce qui cherche un peu d\'air.',
    'SOOTHE',
    'What is looking for a little air.',
  ),
  indigo(
    'INDIGO',
    'CONFIER',
    'Ce qui pèse et demande à être déposé.',
    'CONFIDE',
    'What weighs and asks to be set down.',
  ),
  lumen(
    'LUMEN',
    'ÉCLAIRER',
    'Ce qui veut simplement exister un instant.',
    'ILLUMINATE',
    'What simply wants to exist for a moment.',
  );

  const EchoColorTheme(
    this.wire,
    this.emotionLabel,
    this.emotionHint,
    this.emotionLabelEn,
    this.emotionHintEn,
  );
  final String wire;
  final String emotionLabel;
  final String emotionHint;

  /// V3.52 — the first journey's English (the Mirror's intentions).
  final String emotionLabelEn;
  final String emotionHintEn;

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

  /// The world this intention's thoughts gravitate around — sky law
  /// (anchor order: teal/La Lune 0, indigo/Vénus 1, lumen/Polaris 2,
  /// see `Heavens.planetPosition`). The ether's own data layer reads
  /// it to seed the demo sky where real launches are born.
  int get skyPlanetIndex => switch (this) {
    EchoColorTheme.teal => 0,
    EchoColorTheme.indigo => 1,
    EchoColorTheme.lumen => 2,
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
