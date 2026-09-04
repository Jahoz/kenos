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
  if (boot.supabaseConfigured) {
    return SupabaseAdminRepository();
  }
  return LocalAdminRepository();
});
