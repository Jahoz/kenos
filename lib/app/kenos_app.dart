import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_layout.dart';
import '../core/theme/dark_theme.dart';
import '../core/widgets/portrait_guard.dart';
import 'router.dart';

class KenosApp extends ConsumerWidget {
  const KenosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'KENOS',
      debugShowCheckedModeBanner: false,
      theme: KenosTheme.dark,
      color: AppColors.voidBlack,
      routerConfig: ref.watch(goRouterProvider),
      // The posture column: KENOS's composition is portrait by design.
      // Wide windows (desktop, tablets) center that column over the
      // void — every designed alignment stays true, nothing stretches.
      builder: (context, child) => PortraitGuard(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.postureMaxWidth,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
