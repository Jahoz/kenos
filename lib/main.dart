import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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

/// PWW-04 — télémétrie de crash (rien d'autre). Le DSN arrive par
/// --dart-define=SENTRY_DSN (déploiement web : une ligne SENTRY_DSN=
/// dans .env.cloud ; la valeur canonique vit dans le secret GitHub
/// SENTRY_DSN). Vide ou absent — le cas de tout build local et de la
/// CI — le SDK n'est PAS armé du tout (CCC-04 : sentry 9.30 jette
/// « DSN is required. » sur un DSN null, l'init n'a jamais été un
/// no-op — voir la garde dans [main]) : pas de réseau, pas de
/// collecte, le sanctuaire ne change pas d'un poil.
const String _kSentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Crash reporting : initialisé AVANT tout le reste pour que les
  //    crashes des premiers gestes du boot remontent eux aussi.
  //    appRunner embarque toute la séquence de démarrage dans la zone
  //    de capture de Sentry.
  //
  //    CCC-04 — SANS DSN, L'INIT N'EST PAS UN NO-OP : sentry 9.30
  //    jette « DSN is required. » dès que le DSN est null (throw
  //    inconditionnel, sentry-9.30.0/lib/src/sentry.dart) — le boot
  //    entier mourait avant le premier cadre. Depuis PWW-04, tout
  //    build sans --dart-define=SENTRY_DSN (la PWA démo locale, tout
  //    `make dev-local`) était mort au boot ; seul le déployé vivait,
  //    son .env.cloud portant un DSN. La garde tient ENFIN la promesse
  //    de PWW-04 : absent de DSN, le sanctuaire ne s'arme pas du tout —
  //    bootstrap direct, pas de réseau, pas de collecte, pas de crash.
  if (_kSentryDsn.isEmpty) {
    await bootstrap();
    return;
  }
  await SentryFlutter.init(
    (options) {
      options.dsn = _kSentryDsn;
      // Le sanctuaire ne sait rien de qui : aucune donnée personnelle
      // n'accompagne jamais un crash.
      options.sendDefaultPii = false;
      // Crash, rien d'autre : pas de tracing, pas de sessions.
      options.tracesSampleRate = 0.0;
      options.enableAutoSessionTracking = false;
    },
    appRunner: bootstrap,
  );
}

Future<void> bootstrap() async {
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
