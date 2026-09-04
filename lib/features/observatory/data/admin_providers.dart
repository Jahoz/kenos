import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../echo/data/echo_providers.dart';
import 'admin_repository.dart';
import 'local_admin_repository.dart';
import 'supabase_admin_repository.dart';

/// Guardian repository: Supabase when configured, local demo otherwise
/// (the same branch as the ether itself — the demo keeps the exact
/// backend semantics of the threshold and the shapes).
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final boot = ref.watch(bootstrapProvider);
  final AdminRepository repo;
  if (boot.supabaseConfigured) {
    final guardian = SupabaseAdminRepository();
    repo = guardian;
    // Release the dedicated guardian client when the provider dies —
    // the celestial client is not ours to touch.
    ref.onDispose(guardian.dispose);
  } else {
    repo = LocalAdminRepository();
  }
  return repo;
});
