import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../constellations/data/salon_anchor_store.dart';
import '../../echo/data/user_stats_store.dart';
import '../../echo/domain/echo_cipher.dart';

/// LA BRAISE — the ballot (V3.60).
///
/// The local memories that travel with an anonymous passage: the
/// threshold flag, the stats, the one-time guide veils, and the living
/// salon anchors (the door keys this body still holds). NEVER the
/// sealed echoes (no text, and no way to aim at one's own drifting
/// stars), NEVER the read scars — scars belong to the body that earned
/// them.
///
/// The ballot never touches the wire: it rides inside the passage
/// link's `#fragment`, sealed under a key derived from the passage key
/// itself (HKDF-SHA256 → AES-256-GCM via the Ether Seal cipher). The
/// server sees nothing — not the anchors, not the stats, not even the
/// fact that a ballot exists.
class BraiseBallot {
  const BraiseBallot({
    required this.onboarded,
    required this.stats,
    this.freqGuideSeen = false,
    this.corpseGuideSeen = false,
    this.eyeGuideSeen = false,
    this.anchors = const [],
  });

  final bool onboarded;
  final UserStats stats;
  final bool freqGuideSeen;
  final bool corpseGuideSeen;
  final bool eyeGuideSeen;

  /// Living salon doors this body still holds — capped at [maxAnchors]
  /// (oldest first, the store's own order) so the link stays a link.
  final List<SalonAnchor> anchors;

  static const maxAnchors = 8;

  /// The same being, two bodies: counters add up, watermarks take the
  /// latest. `seenReceptions` is a watermark too (what the Aube may
  /// still speak of is the difference, and the server's own
  /// reply_seen flags travelled with the rows).
  UserStats mergedStats(UserStats here) {
    DateTime? latest(DateTime? a, DateTime? b) {
      if (a == null) return b;
      if (b == null) return a;
      return a.isAfter(b) ? a : b;
    }

    return UserStats(
      totalEchosSent: here.totalEchosSent + stats.totalEchosSent,
      totalReceptionsReceived:
          here.totalReceptionsReceived + stats.totalReceptionsReceived,
      totalTracesLeft: here.totalTracesLeft + stats.totalTracesLeft,
      lastEchoSentAt: latest(here.lastEchoSentAt, stats.lastEchoSentAt),
      readCount: here.readCount + stats.readCount,
      stardust: here.stardust + stats.stardust,
      seenReceptions: here.seenReceptions > stats.seenReceptions
          ? here.seenReceptions
          : stats.seenReceptions,
      constellationsTouched:
          here.constellationsTouched + stats.constellationsTouched,
      lastVisitAt: latest(here.lastVisitAt, stats.lastVisitAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'stats': stats.toJson(),
        'freqGuideSeen': freqGuideSeen,
        'corpseGuideSeen': corpseGuideSeen,
        'eyeGuideSeen': eyeGuideSeen,
        'anchors': anchors.map((a) => a.toJson()).toList(),
      };

  /// Tolerant by contract: a ballot is a memory, not a covenant — a
  /// missing field is a forgotten one, never a broken passage.
  factory BraiseBallot.fromJson(Map<String, dynamic> json) => BraiseBallot(
        onboarded: json['onboarded'] as bool? ?? false,
        stats: json['stats'] == null
            ? UserStats.empty()
            : UserStats.fromJson((json['stats'] as Map).cast<String, dynamic>()),
        freqGuideSeen: json['freqGuideSeen'] as bool? ?? false,
        corpseGuideSeen: json['corpseGuideSeen'] as bool? ?? false,
        eyeGuideSeen: json['eyeGuideSeen'] as bool? ?? false,
        anchors: (json['anchors'] as List? ?? const [])
            .map((a) => SalonAnchor.fromJson((a as Map).cast<String, dynamic>()))
            .toList(),
      );

  /// HKDF-SHA256 over the passage key: one key, two lives — the hex
  /// form knocks at the server, the derived form seals the ballot.
  static Future<String> _deriveKeyB64(String keyHex) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final secret = await hkdf.deriveKey(
      secretKey: SecretKey(_hexToBytes(keyHex)),
      info: utf8.encode('kenos-braise-v1'),
    );
    return base64Encode(await secret.extractBytes());
  }

  /// Seals the ballot into the URL-safe fragment payload.
  static Future<String> pack(BraiseBallot ballot, String keyHex) async {
    final keyB64 = await _deriveKeyB64(keyHex);
    final blob = await EchoCipher.sealBytesWithKey(
      Uint8List.fromList(utf8.encode(jsonEncode(ballot.toJson()))),
      keyB64,
    );
    return base64Url.encode(blob).replaceAll('=', '');
  }

  /// Opens a sealed ballot. Any failure (wrong key, tampering, decay)
  /// is a forgotten memory: null, never a broken passage — the claim
  /// itself does not depend on the souvenirs.
  static Future<BraiseBallot?> tryUnpack(String packed, String keyHex) async {
    try {
      final keyB64 = await _deriveKeyB64(keyHex);
      var normalized = packed;
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final clear = await EchoCipher.openBytes(
        keyB64,
        Uint8List.fromList(base64Url.decode(normalized)),
      );
      return BraiseBallot.fromJson(
        jsonDecode(utf8.decode(clear)) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
