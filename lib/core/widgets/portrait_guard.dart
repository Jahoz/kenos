import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_fonts.dart';

/// Portrait is KENOS's posture: the ether is a held breath, not a
/// widescreen. Native platforms LOCK it in `main()`; the web cannot
/// lock a browser orientation — there, the guard replaces the app
/// with a quiet veil asking the device to stand up. UX stays mastered
/// everywhere, by lock or by ritual.
class PortraitGuard extends StatelessWidget {
  const PortraitGuard({super.key, required this.child, this.enforce});

  final Widget child;

  /// Force the veil in landscape regardless of platform (tests).
  /// Defaults to web-only, where no native lock exists.
  final bool? enforce;

  bool get _enforce => enforce ?? kIsWeb;

  @override
  Widget build(BuildContext context) {
    if (!_enforce) return child;
    final orientation =
        MediaQuery.maybeOrientationOf(context) ?? Orientation.portrait;
    if (orientation == Orientation.portrait) return child;

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'KENOS se vit debout.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.serifItalic,
                fontSize: 21,
                color: AppColors.fade(AppColors.pureLight, 0.9),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'TOURNE TON APPAREIL — L\'ÉTHER EST PORTRAIT',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 9,
                letterSpacing: 3,
                color: AppColors.fade(AppColors.teal, 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
