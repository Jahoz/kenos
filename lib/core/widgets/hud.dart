import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_fonts.dart';

/// Machine-voiced HUD: one toast style for the whole app (French copy,
/// Space Mono, the ether never shouts).
void showHud(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Canonical HUD label style — machine typography, tracked, faded.
TextStyle hudLabel({
  double fontSize = 9,
  double letterSpacing = 3,
  Color? color,
}) =>
    TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      color: color ?? AppColors.fade(AppColors.pureLight, 0.4),
    );
