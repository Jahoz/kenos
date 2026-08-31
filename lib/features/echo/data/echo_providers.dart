import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'echo_repository.dart';
import 'local_echo_repository.dart';
import 'local_echo_store.dart';
import 'supabase_echo_repository.dart';
import 'user_stats_store.dart';

/// App boot state, computed in `main()` before runApp.
class Bootstrap {
  const Bootstrap({
    required this.supabaseConfigured,
    required this.hasOnboarded,
  });

  /// True when Supabase was initialized with valid credentials.
  final bool supabaseConfigured;

  /// True when onboarding has already been passed (secure local storage).
  final bool hasOnboarded;
}

/// Must be overridden in `main()`.
final bootstrapProvider = Provider<Bootstrap>(
  (ref) => throw UnimplementedError('bootstrapProvider must be overridden'),
);

/// Secure local store (also overridden in `main` to share the instance
/// already used during boot).
final localEchoStoreProvider = Provider<LocalEchoStore>((ref) {
  final store = LocalEchoStore();
  ref.onDispose(store.dispose);
  return store;
});

/// Ether repository: Supabase when configured, local demo otherwise.
final echoRepositoryProvider = Provider<EchoRepository>((ref) {
  final boot = ref.watch(bootstrapProvider);
  if (boot.supabaseConfigured) {
    return SupabaseEchoRepository(Supabase.instance.client);
  }
  return LocalEchoRepository.seeded(store: ref.watch(localEchoStoreProvider));
});

/// Anonymous session: silent sign-in, one attempt at boot.
/// On network failure the map shows the error + RECALIBRER.
final sessionReadyProvider = FutureProvider<void>((ref) async {
  final boot = ref.watch(bootstrapProvider);
  if (!boot.supabaseConfigured) return;
  final client = Supabase.instance.client;
  if (client.auth.currentSession != null) return;
  try {
    await client.auth.signInAnonymously();
  } catch (e) {
    debugPrint('[kenos.auth] anonymous sign-in failed: $e');
    rethrow;
  }
});

/// User statistics provider (anonymized, local only).
final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final store = ref.watch(localEchoStoreProvider);
  return store.readStats();
});
