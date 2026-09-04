import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_fonts.dart';

/// The anonymity threshold — one shared grammar everywhere a thought
/// that seems to carry personal data is about to drift (the reader's
/// trace, the Mirror's seal, a corpse's line). WARN, never block:
/// anonymity is the contract, choosing belongs to the author.
///
/// Returns true to let it drift anyway, false to take it back.
Future<bool> warnAnonymityLoss(
  BuildContext context, {
  required String body,
  required String takeBackLabel,
}) async {
  final proceed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.voidBlack,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.fade(AppColors.pureLight, 0.18)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TON ANONYMAT EST LE CONTRAT',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10,
                  letterSpacing: 3,
                  color: AppColors.fade(AppColors.teal, 0.85),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.serifItalic,
                  fontSize: 14,
                  height: 1.75,
                  color: AppColors.fade(AppColors.pureLight, 0.75),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('LAISSER QUAND MÊME'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(takeBackLabel),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return proceed ?? false;
}
