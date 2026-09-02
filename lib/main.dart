import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/kenos_app.dart';
import 'core/constants/app_layout.dart';
import 'features/echo/data/echo_providers.dart';
import 'features/echo/data/local_echo_store.dart';

/// Credentials passed at launch:
/// flutter run \
///   --dart-define=SUPABASE_URL=... \
///   --dart-define=SUPABASE_ANON_KEY=...
///
/// Without credentials (or when the backend is unreachable), KENOS boots in
/// local demo mode: simulated ether, identical semantics.
const String _kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The ether is portrait — for HELD PHONES. Tablets and desktops live
  // standing in the posture column (see AppLayout): they rotate
  // freely. The web cannot lock orientation at all, so PortraitGuard
  // veils lying phones there instead.
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
  if (logicalWidth < AppLayout.nativeLockMaxWidth) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  // 1. Secure local storage (read before the first frame: the router
  //    depends on it to pick the threshold or the space).
  final store = LocalEchoStore();
  late final bool onboarded;
  try {
    onboarded = await store.hasOnboarded();
  } catch (_) {
    onboarded = false;
  }

  // 2. Backend: anonymous auth + PostgreSQL. Optional.
  var supabaseConfigured = false;
  if (_kSupabaseUrl.isNotEmpty && _kSupabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: _kSupabaseUrl,
        publishableKey: _kSupabaseAnonKey,
      );
      supabaseConfigured = true;
    } catch (e) {
      debugPrint('[kenos.boot] Supabase unreachable, demo mode: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(
          Bootstrap(
            supabaseConfigured: supabaseConfigured,
            hasOnboarded: onboarded,
          ),
        ),
        localEchoStoreProvider.overrideWithValue(store),
      ],
      child: const KenosApp(),
    ),
  );
}
