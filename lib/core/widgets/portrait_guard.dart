import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_fonts.dart';
import '../constants/app_layout.dart';

/// Portrait is KENOS's posture: the ether is a held breath, not a
/// widescreen. The app itself lives in a centered posture column
/// (see [AppLayout]) — wide viewports are WELCOMED, tablet and desktop
/// alike. Only a held phone lying flat (a short landscape window)
/// meets the quiet veil asking it to stand back up. Native platforms
/// lock phones upright in `main()`; the web cannot lock a browser
/// orientation, so the ritual veil stands in for the lock.
class PortraitGuard extends StatelessWidget {
  const PortraitGuard({super.key, required this.child, this.enforce});

  final Widget child;

  /// Force the veil-capable behavior regardless of platform (tests).
  /// Defaults to web-only, where no native lock exists.
  final bool? enforce;

  bool get _enforce => enforce ?? kIsWeb;

  @override
  Widget build(BuildContext context) {
    if (_enforce) {
      final size = MediaQuery.sizeOf(context);
      final orientation =
          MediaQuery.maybeOrientationOf(context) ?? Orientation.portrait;
      final heldPhoneLyingFlat =
          orientation == Orientation.landscape &&
          size.height < AppLayout.phoneLandscapeMaxHeight;
      if (heldPhoneLyingFlat) return _veil();
    }
    return child;
  }

  Widget _veil() {
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
