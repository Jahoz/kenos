import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_fonts.dart';

/// KENOS theme — strict dark mode, no Material frills.
class KenosTheme {
  KenosTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      surface: AppColors.voidBlack,
      onSurface: AppColors.pureLight,
      primary: AppColors.teal,
      onPrimary: AppColors.voidBlack,
      secondary: AppColors.indigo,
      onSecondary: AppColors.pureLight,
      error: AppColors.rose,
      onError: AppColors.voidBlack,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.voidBlack,
      fontFamily: AppFonts.mono,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.pureLight,
        displayColor: AppColors.pureLight,
        fontFamily: AppFonts.mono,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.pureLight,
          backgroundColor: AppColors.fade(Colors.black, 0.5),
          side: const BorderSide(color: AppColors.hairline, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 12,
            letterSpacing: 3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.fade(AppColors.pureLight, 0.55),
          textStyle: const TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 10,
            letterSpacing: 2.5,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.voidBlackDeep,
        contentTextStyle: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 11,
          letterSpacing: 2,
          color: AppColors.pureLight,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.hairline),
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: Colors.transparent),
    );
  }
}
