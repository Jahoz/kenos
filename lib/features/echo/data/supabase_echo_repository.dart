import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/parallax_math.dart';
import '../domain/echo.dart';
import '../domain/echo_color_theme.dart';
import '../domain/reception.dart';
import 'echo_repository.dart';

/// Production repository.
///
/// Principle: the client NEVER touches the `echoes` table directly.
///  - map        → `echoes_map` view (metadata, zero text columns);
///  - read       → `consume_echo` RPC (atomic: lock + delete + return);
///  - launch     → `launch_echo` RPC (validation + anti-spam server-side).
class SupabaseEchoRepository implements EchoRepository {
  SupabaseEchoRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Echo>> fetchStarMap() async {
    final rows = await _client
        .from('echoes_map')
        .select('id, coord_x, coord_y, coord_z, color_theme, created_at')
        .order('created_at', ascending: false)
        .limit(150);
    return (rows as List)
        .map((row) => Echo.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<String?> consumeEcho(String id) async {
    try {
      final text = await _client.rpc(
        'consume_echo',
        params: {'target_echo_id': id},
      );
      return text == null ? null : text as String;
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
      final rows = await _client.rpc(
        'launch_echo',
        params: {
          'p_text': text,
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
