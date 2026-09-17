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

  /// Releases the dedicated client (provider teardown). The celestial
  /// client in `Supabase.instance` is not ours to touch.
  void dispose() {
    _client?.dispose();
    _client = null;
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

  @override
  Future<List<ConstellationReportSummary>> fetchConstellationReports() async {
    if (!isSignedIn) throw GuardianAuthException('no_session');
    try {
      final raw = await _ether.rpc('admin_list_constellation_reports');
      return ((raw as List?) ?? const [])
          .whereType<Map>()
          .map((row) =>
              ConstellationReportSummary.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (e.message.contains('KENOS_FORBIDDEN') || e.code == '42501') {
        throw GuardianForbiddenException();
      }
      rethrow;
    }
  }

  @override
  Future<void> retractConstellation(String constellationId) async {
    if (!isSignedIn) throw GuardianAuthException('no_session');
    try {
      await _ether.rpc(
        'admin_retract_constellation',
        params: {'p_constellation_id': constellationId},
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('KENOS_FORBIDDEN') || e.code == '42501') {
        throw GuardianForbiddenException();
      }
      rethrow;
    }
  }

  @override
  Future<List<VestigeProposal>> fetchVestigeProposals() async {
    if (!isSignedIn) throw GuardianAuthException('no_session');
    try {
      final raw = await _ether.rpc('admin_list_vestige_proposals');
      return _rows<VestigeProposal>(raw, VestigeProposal.fromJson);
    } on PostgrestException catch (e) {
      if (e.message.contains('KENOS_FORBIDDEN') || e.code == '42501') {
        throw GuardianForbiddenException();
      }
      rethrow;
    }
  }

  @override
  Future<bool> decideVestigeProposal(String proposalId, bool approve) async {
    if (!isSignedIn) throw GuardianAuthException('no_session');
    try {
      final result = await _ether.rpc(
        'admin_decide_vestige_proposal',
        params: {'p_proposal_id': proposalId, 'p_approve': approve},
      );
      return result == true;
    } on PostgrestException catch (e) {
      if (e.message.contains('KENOS_FORBIDDEN') || e.code == '42501') {
        throw GuardianForbiddenException();
      }
      rethrow;
    }
  }

  @override
  Future<List<VestigeLibraryEntry>> fetchVestigeLibrary() async {
    if (!isSignedIn) throw GuardianAuthException('no_session');
    try {
      final raw = await _ether.rpc(
        'admin_fetch_vestiges',
        params: {'p_locale': 'fr'},
      );
      return _rows<VestigeLibraryEntry>(raw, VestigeLibraryEntry.fromJson);
    } on PostgrestException catch (e) {
      if (e.message.contains('KENOS_FORBIDDEN') || e.code == '42501') {
        throw GuardianForbiddenException();
      }
      rethrow;
    }
  }

  @override
  Future<void> setVestigeLive(String id, bool live) async {
    if (!isSignedIn) throw GuardianAuthException('no_session');
    try {
      await _ether.rpc(
        'admin_set_vestige_live',
        params: {'p_id': id, 'p_locale': 'fr', 'p_live': live},
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('KENOS_FORBIDDEN') || e.code == '42501') {
        throw GuardianForbiddenException();
      }
      rethrow;
    }
  }

  @override
  Future<SowResult> sowVestiges({int count = 6, required String theme}) async {
    if (!isSignedIn) throw GuardianAuthException('no_session');
    try {
      final res = await _ether.functions.invoke(
        'vestige-sow',
        body: {'count': count, 'theme': theme},
      );
      final data = res.data;
      if (data is Map) {
        return SowResult.fromJson(Map<String, dynamic>.from(data));
      }
      return const SowResult(sown: 0, reason: 'rpc');
    } catch (_) {
      // The function answers honestly even failing — but a dead road
      // says so too, in the same shape.
      return const SowResult(sown: 0, reason: 'rpc');
    }
  }

  /// PostgREST returns a bare array for these jsonb list RPCs.
  static List<T> _rows<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
    return ((raw as List?) ?? const [])
        .whereType<Map>()
        .map((row) => fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}
