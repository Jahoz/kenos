import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/parallax_math.dart';
import '../domain/echo.dart';
import '../domain/echo_cipher.dart';
import '../domain/echo_color_theme.dart';
import '../domain/reception.dart';
import 'echo_repository.dart';
import 'sector_grid.dart';

/// Production repository.
///
/// Principle: the client NEVER touches the `echoes` table directly.
///  - map        → `fetch_map_sector` RPC (metadata, sector-culled);
///  - read       → `consume_echo` RPC (atomic: lock + delete + one-shot
///                 key exchange — the text is AES-256-GCM sealed, the ether
///                 never sees the plaintext);
///  - launch     → `launch_echo` RPC (sealed payload + anti-spam).
class SupabaseEchoRepository implements EchoRepository {
  SupabaseEchoRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Echo>> fetchStarMap() => fetchStarMapInSector(0, 0, 1, 1);

  /// Viewport variant: normalized rect, sector-culled server-side.
  @override
  Future<List<Echo>> fetchStarMapInSector(
    double minX,
    double minY,
    double maxX,
    double maxY,
  ) async {
    final rows = await _client.rpc('fetch_map_sector', params: {
      'p_min_x': ParallaxMath.clamp(minX, 0, 1),
      'p_min_y': ParallaxMath.clamp(minY, 0, 1),
      'p_max_x': ParallaxMath.clamp(maxX, 0, 1),
      'p_max_y': ParallaxMath.clamp(maxY, 0, 1),
      'p_max_per_sector': SectorGrid.maxPerSector,
      'p_max_total': SectorGrid.maxTotal,
    });
    return (rows as List)
        .map((row) => Echo.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<String?> consumeEcho(String id) async {
    try {
      final result = await _client.rpc(
        'consume_echo',
        params: {'target_echo_id': id},
      );
      if (result == null) return null; // lost the race: dissolved elsewhere.
      final bundle = (result as Map).cast<String, dynamic>();
      final ciphertext = bundle['ciphertext'] as String;
      final key = bundle['key'] as String?;
      if (key == null || key.isEmpty) {
        // Legacy echo (pre-encryption migration): plaintext passthrough.
        return ciphertext;
      }
      // A seal that fails to open (tampered or corrupted in transit)
      // is a dead echo: null, i.e. dissolved — never a transport error.
      return await EchoCipher.openOrNull(key, ciphertext);
    } catch (e) {
      throw KenosException.from(e);
    }
  }

  @override
  Future<Echo> sendEcho({
    required String text,
    required double coordX,
    required double coordY,
    required double coordZ,
    required EchoColorTheme theme,
  }) async {
    try {
      // Ether Seal: the text is encrypted on-device, under a fresh
      // ephemeral key, before it ever leaves for the ether.
      final sealed = await EchoCipher.seal(text);
      final rows = await _client.rpc(
        'launch_echo',
        params: {
          'p_ciphertext': sealed.payloadB64,
          'p_key': sealed.keyB64,
          'p_x': ParallaxMath.clamp(coordX, 0, 1),
          'p_y': ParallaxMath.clamp(coordY, 0, 1),
          'p_z': ParallaxMath.clamp(coordZ, 0.05, 1),
          'p_theme': theme.wire,
        },
      );
      final row = (rows as List).first as Map<String, dynamic>;
      return Echo(
        id: row['id'] as String,
        coordX: coordX,
        coordY: coordY,
        coordZ: coordZ,
        theme: theme,
        createdAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
        isMine: true,
      );
    } catch (e) {
      throw KenosException.from(e);
    }
  }

  @override
  Future<bool> leaveTrace(String echoId, String text) async {
    try {
      return await _client.rpc(
            'leave_trace',
            params: {'p_echo_id': echoId, 'p_text': text},
          ) as bool? ??
          false;
    } catch (e) {
      throw KenosException.from(e);
    }
  }

  @override
  Future<List<Reception>> fetchReceptions() async {
    try {
      final rows = await _client.rpc('fetch_receptions');
      return (rows as List)
          .map((row) => Reception.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw KenosException.from(e);
    }
  }

  @override
  Future<void> burnReception(String echoId) async {
    try {
      await _client.rpc('burn_reception', params: {'p_echo_id': echoId});
    } catch (e) {
      throw KenosException.from(e);
    }
  }

  @override
  Stream<void> receptionChanges() => const Stream.empty();
}
