import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../echo/data/echo_providers.dart';
import '../domain/vestige.dart';

/// The curated vestige library: where the sky's culture lives.
///
/// Two implementations, one contract:
///  - [SupabaseVestigeRepository]: the ether's library (the Curator
///    feeds it without a release), locale-aware;
///  - [BundledVestigeRepository]: the bundled JSON — the honest
///    offline fallback, so the demo ether keeps its shards.
///
/// The presentation never touches the client — the sheet painters and
/// panels receive [Vestige] objects, nothing else.
abstract class VestigeRepository {
  /// The WHOLE curated library (the daily rotation is decided by the
  /// caller, from [dailyRotation] — the repository carries no clock).
  Future<List<Vestige>> fetchAll();
}

class SupabaseVestigeRepository implements VestigeRepository {
  SupabaseVestigeRepository(this._client, this._fallback);

  final SupabaseClient _client;
  final BundledVestigeRepository _fallback;

  @override
  Future<List<Vestige>> fetchAll() async {
    // 1. The ether's library (when a session lives).
    try {
      final signedIn = _client.auth.currentUser != null ||
          _client.auth.currentSession != null;
      if (signedIn) {
        // V3.16: the shard meets the traveler in their language
        // (device locale, e.g. 'en' or 'fr-FR'); the server falls
        // back to the French canon — the library is never empty.
        //
        // V3.58d — dart:io's Platform is STUBBED on the web:
        // Platform.localeName threw UnsupportedError BEFORE the RPC
        // ever fired, the catch swallowed it, and every web session
        // silently fell to the bundled dozen — the ether's library
        // (every guardian harvest) never reached a browser ("je ne
        // vois aucun vestige", the live report). The platform
        // dispatcher speaks every build, tag-shaped ('fr-FR') exactly
        // as the server normalizes.
        final locale = WidgetsBinding
            .instance.platformDispatcher.locale.toLanguageTag();
        final rows = await _client.rpc('fetch_vestiges', params: {
          'p_locale': locale,
        });
        if (rows is List && rows.isNotEmpty) {
          return [
            for (final row in rows)
              Vestige.fromJson((row as Map).cast<String, dynamic>()),
          ];
        }
      }
    } catch (e) {
      // The ether's library is a guest: if it is unreachable, the
      // bundle carries the culture — silently.
      debugPrint('[kenos.vestiges] ether library unreachable: $e');
    }
    // 2. The bundled library (offline, no session, always honest).
    return _fallback.fetchAll();
  }
}

class BundledVestigeRepository implements VestigeRepository {
  const BundledVestigeRepository();

  @override
  Future<List<Vestige>> fetchAll() async {
    try {
      final raw = await rootBundle.loadString('assets/vestiges.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return (data['vestiges'] as List)
          .map((v) => Vestige.fromJson(v as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // The ether works without its library: the app never blocks.
      debugPrint('[kenos.vestiges] unavailable: $e');
      return const <Vestige>[];
    }
  }
}

/// Supabase when configured, the bundled canon otherwise.
final vestigeRepositoryProvider = Provider<VestigeRepository>((ref) {
  final boot = ref.watch(bootstrapProvider);
  if (boot.supabaseConfigured) {
    return SupabaseVestigeRepository(
      Supabase.instance.client,
      const BundledVestigeRepository(),
    );
  }
  return const BundledVestigeRepository();
});
