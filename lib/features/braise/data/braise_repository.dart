import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../echo/data/echo_providers.dart';

/// LA BRAISE — the passage repository (V3.60).
///
/// `forge` mints a one-shot ember on the old body; `claim` hands the
/// identity over to the calling body. The server keeps only a sha256
/// fingerprint for ten minutes — the plaintext key crosses the wire
/// exactly once, at the forge (the salon grammar).
abstract class BraiseRepository {
  /// Returns the 16-byte hex passage key, once.
  Future<String> forge();

  /// Consumes the passage: the calling session inherits what the old
  /// body had addressed to it. Throws [BraiseKeyRefused] when the
  /// ember is missing, wrong, expired or already claimed — all alike,
  /// by design.
  Future<void> claim(String key);
}

/// The ether's own hands.
class SupabaseBraiseRepository implements BraiseRepository {
  SupabaseBraiseRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> forge() async {
    final result = await _client.rpc('forge_passage');
    return result as String;
  }

  @override
  Future<void> claim(String key) async {
    await _client.rpc('claim_passage', params: {'p_key': key});
  }
}

/// Demo mode: the ember lives in this device's memory — same grammar,
/// same silences. Forged once, claimed once, replay refused.
class LocalBraiseRepository implements BraiseRepository {
  String? _liveKey;

  @override
  Future<String> forge() async {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    _liveKey = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return _liveKey!;
  }

  @override
  Future<void> claim(String key) async {
    if (_liveKey == null || key != _liveKey) {
      throw BraiseKeyRefused();
    }
    _liveKey = null;
  }
}

/// Wrong and expired look alike — the ember says nothing about which
/// body held it (toString parity with the server's error, the salon's
/// SalonKeyRefused grammar).
class BraiseKeyRefused implements Exception {
  @override
  String toString() => 'KENOS_PASSAGE_UNKNOWN';
}

final braiseRepositoryProvider = Provider<BraiseRepository>((ref) {
  final boot = ref.watch(bootstrapProvider);
  if (boot.supabaseConfigured) {
    return SupabaseBraiseRepository(Supabase.instance.client);
  }
  return LocalBraiseRepository();
});
