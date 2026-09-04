import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_metrics.dart';
import 'admin_repository.dart';

/// Guardian path: a SECOND, dedicated Supabase client.
///
/// The celestial session (anonymous, in `Supabase.instance`) is never
/// touched — the guardian signs in beside it, not instead of it. The
/// session lives in this repository's memory only: closing the screen's
/// session leaves nothing on the device.
class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository({String? url, String? key})
    : _url = url ?? const String.fromEnvironment('SUPABASE_URL'),
      _key = key ?? const String.fromEnvironment('SUPABASE_ANON_KEY');

  final String _url;
  final String _key;

  SupabaseClient? _client;

  SupabaseClient get _ether {
    final existing = _client;
    if (existing != null) return existing;
    if (_url.isEmpty || _key.isEmpty) {
      throw GuardianAuthException('unconfigured');
    }
    return _client = SupabaseClient(_url, _key);
  }

  @override
  bool get isSignedIn => _client?.auth.currentSession != null;

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _ether.auth.signInWithPassword(email: email, password: password);
    } on AuthException {
      throw GuardianAuthException();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (_) {
      // A dead session is closed all the same; the threshold does not
      // insist on ceremony.
    }
  }

  @override
  Future<AdminMetrics> fetchMetrics({int days = 30}) async {
    if (!isSignedIn) throw GuardianAuthException('no_session');
    try {
      final raw = await _ether.rpc(
        'admin_fetch_metrics',
        params: {'p_days': days},
      );
      return AdminMetrics.fromJson(Map<String, dynamic>.from(raw as Map));
    } on PostgrestException catch (e) {
      // errcode 42501 + KENOS_FORBIDDEN: the JWT carries no rank.
      if (e.message.contains('KENOS_FORBIDDEN') || e.code == '42501') {
        throw GuardianForbiddenException();
      }
      rethrow;
    }
  }
}
