import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/parallax_math.dart';
import '../domain/echo.dart';
import '../domain/echo_cipher.dart';
import '../domain/echo_color_theme.dart';
import '../domain/echo_excerpt.dart';
import '../domain/echo_media.dart';
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
  Future<ConsumedEcho?> consumeEcho(String id) async {
    try {
      final response = await _client.functions.invoke(
        'consume-media',
        body: {'echoId': id},
      );
      final result = response.data;
      if (result == null) return null; // lost the race: dissolved elsewhere.
      final bundle = (result as Map).cast<String, dynamic>();
      final ciphertext = bundle['ciphertext'] as String;
      final key = bundle['key'] as String?;
      final momentum = (bundle['momentum'] as num?)?.toInt() ?? 0;
      if (key == null || key.isEmpty) {
        // Legacy echo (pre-encryption migration): plaintext passthrough.
        return ConsumedEcho(text: ciphertext, momentum: momentum);
      }
      // A seal that fails to open (tampered or corrupted in transit)
      // is a dead echo: null, i.e. dissolved — never a transport error.
      final text = await EchoCipher.openOrNull(key, ciphertext);
      if (text == null) return null;
      final mediaB64 = bundle['media'] as String?;
      final mediaKind = bundle['media_kind'] as String?;
      EchoMedia? media;
      if (mediaB64 != null && mediaKind != null) {
        media = EchoMedia(
          kind: mediaKind == 'IMAGE'
              ? EchoMediaKind.image
              : EchoMediaKind.audio,
          bytes: await EchoCipher.openBytes(key, base64Decode(mediaB64)),
        );
      }
      // The cultural door: a reference sealed under the same echo key,
      // handed only to the winner. Unparsable (forged by a modified
      // client) simply means no door — never an error, never a raw URL.
      final excerptRefB64 = bundle['media_ref'] as String?;
      EchoExcerpt? excerpt;
      if (excerptRefB64 != null && mediaKind != null) {
        final ref = utf8.decode(
          await EchoCipher.openBytes(key, base64Decode(excerptRefB64)),
        );
        excerpt = EchoExcerpt.fromRef(ref);
      }
      return ConsumedEcho(
        text: text,
        media: media,
        excerpt: excerpt,
        momentum: momentum,
      );
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
    EchoMediaDraft? media,
    EchoExcerpt? excerpt,
  }) async {
    try {
      // The ether's media slot is single: fragment XOR door.
      if (media != null && excerpt != null) {
        throw const KenosException(KenosErrorCode.invalid);
      }
      // Ether Seal: the text is encrypted on-device, under a fresh
      // ephemeral key, before it ever leaves for the ether.
      final sealed = await EchoCipher.seal(text);
      String? mediaPath;
      String? mediaKindWire;
      if (media != null) {
        if (!media.isWithinLimit) {
          throw const KenosException(KenosErrorCode.invalid);
        }
        final userId = _client.auth.currentUser?.id;
        if (userId == null) throw const KenosException(KenosErrorCode.unauthenticated);
        final sealedMedia = await EchoCipher.sealBytesWithKey(
          media.bytes,
          sealed.keyB64,
        );
        mediaKindWire = media.kind.wire;
        mediaPath = '$userId/${DateTime.now().microsecondsSinceEpoch}-${media.kind.wire}.bin';
        await _client.storage.from('echo-media').uploadBinary(
          mediaPath,
          sealedMedia,
          fileOptions: const FileOptions(upsert: false),
        );
      } else if (excerpt != null) {
        // The door travels sealed under the same ephemeral key as the
        // text: a dump reveals neither the confidence nor the taste.
        mediaKindWire = excerpt.kind.wire;
        final sealedRef = await EchoCipher.sealBytesWithKey(
          Uint8List.fromList(utf8.encode(excerpt.ref)),
          sealed.keyB64,
        );
        mediaPath = base64Encode(sealedRef);
      }
      final rows = await _client.rpc(
        'launch_echo',
        params: {
          'p_ciphertext': sealed.payloadB64,
          'p_key': sealed.keyB64,
          'p_x': ParallaxMath.clamp(coordX, 0, 1),
          'p_y': ParallaxMath.clamp(coordY, 0, 1),
          'p_z': ParallaxMath.clamp(coordZ, 0.05, 1),
          'p_theme': theme.wire,
          'p_media_kind': mediaKindWire,
          'p_media_path': mediaPath,
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
        // Kind metadata only — the author loses the door with the
        // text: it exists solely for the future single reader.
        mediaKind: media?.kind ?? excerpt?.kind.mediaKind,
      );
    } catch (e) {
      throw KenosException.from(e);
    }
  }

  @override
  Future<Echo> reboundEcho({
    required String sourceId,
    required int parentMomentum,
    required String text,
    required double coordX,
    required double coordY,
    required double coordZ,
  }) async {
    try {
      // The phoenix is sealed FRESH by the reader's device: a new
      // ephemeral key, for one new receiver — never a re-used seal.
      final sealed = await EchoCipher.seal(text);
      final rows = await _client.rpc('rebound_echo', params: {
        'p_source_id': sourceId,
        'p_parent_momentum': parentMomentum,
        'p_x': ParallaxMath.clamp(coordX, 0, 1),
        'p_y': ParallaxMath.clamp(coordY, 0, 1),
        'p_z': ParallaxMath.clamp(coordZ, 0.05, 1),
        'p_ciphertext': sealed.payloadB64,
        'p_key': sealed.keyB64,
      });
      final row = (rows as List).first as Map<String, dynamic>;
      return Echo(
        id: row['id'] as String,
        coordX: coordX,
        coordY: coordY,
        coordZ: coordZ,
        theme: EchoColorTheme.teal, // replaced by the inherited theme on refresh
        createdAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
        isMine: true,
        momentum: (row['momentum'] as num).toInt(),
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
  Future<bool> reportEcho(String echoId, EchoReportReason reason) async {
    try {
      return await _client.rpc(
            'report_echo',
            params: {'p_echo_id': echoId, 'p_reason_code': reason.wire},
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
