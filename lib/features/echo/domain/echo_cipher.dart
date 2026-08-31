import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// One sealed echo payload: the per-echo ephemeral key (base64) and the
/// AES-256-GCM bundle (base64 of `nonce(12) || ciphertext || mac(16)`).
class SealedEchoContent {
  const SealedEchoContent({required this.keyB64, required this.payloadB64});

  final String keyB64;
  final String payloadB64;
}

/// KENOS Ether Seal — real encryption at rest.
///
/// The author's device derives a random 256-bit ephemeral key per echo and
/// seals the text with AES-256-GCM before it ever leaves the device:
/// the ether (server, backups, DB dumps of the ciphertext column) never
/// sees the plaintext. The key is handed back by `consume_echo` inside
/// the same atomic transaction that destroys the echo — exchanged exactly
/// once, at interception.
class EchoCipher {
  EchoCipher._();

  static final AesGcm _aes = AesGcm.with256bits();
  static final Random _rng = Random.secure();

  static const _nonceLength = 12;
  static const _macLength = 16;

  /// Seals [plaintext] under a fresh ephemeral key.
  static Future<SealedEchoContent> seal(String plaintext) async {
    final key = SecretKey(Uint8List.fromList(
      List<int>.generate(32, (_) => _rng.nextInt(256)),
    ));
    final nonce = Uint8List.fromList(
      List<int>.generate(_nonceLength, (_) => _rng.nextInt(256)),
    );
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    final blob = Uint8List.fromList([
      ...nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
    return SealedEchoContent(
      keyB64: base64Encode(await key.extractBytes()),
      payloadB64: base64Encode(blob),
    );
  }

  /// Seals binary media with an existing echo key, using a distinct nonce.
  static Future<Uint8List> sealBytesWithKey(
    Uint8List clear,
    String keyB64,
  ) async {
    final nonce = Uint8List.fromList(
      List<int>.generate(_nonceLength, (_) => _rng.nextInt(256)),
    );
    final box = await _aes.encrypt(
      clear,
      secretKey: SecretKey(base64Decode(keyB64)),
      nonce: nonce,
    );
    return Uint8List.fromList([...nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  /// Opens a sealed payload. Throws on tampering or corruption
  /// (GCM authenticated decryption) — callers decide how to mourn.
  static Future<String> open(
    String keyB64,
    String payloadB64,
  ) async {
    final blob = base64Decode(payloadB64);
    if (blob.length < _nonceLength + _macLength) {
      throw const FormatException('sealed echo too short');
    }
    final clear = await _aes.decrypt(
      SecretBox(
        blob.sublist(_nonceLength, blob.length - _macLength),
        nonce: blob.sublist(0, _nonceLength),
        mac: Mac(blob.sublist(blob.length - _macLength)),
      ),
      secretKey: SecretKey(base64Decode(keyB64)),
    );
    return utf8.decode(clear);
  }

  /// Opening variant for the consumption path: a seal that fails to
  /// open (altered ciphertext, wrong key, corruption) means the echo is
  /// dead — returning null lets the caller treat it as dissolved and
  /// remove the star, instead of surfacing a transport error.
  static Future<String?> openOrNull(
    String keyB64,
    String payloadB64,
  ) async {
    try {
      return await open(keyB64, payloadB64);
    } catch (_) {
      return null;
    }
  }

  /// Opens a binary fragment returned only by the media consumption function.
  static Future<Uint8List> openBytes(String keyB64, Uint8List blob) async {
    if (blob.length < _nonceLength + _macLength) {
      throw const FormatException('sealed media too short');
    }
    final clear = await _aes.decrypt(
      SecretBox(
        blob.sublist(_nonceLength, blob.length - _macLength),
        nonce: blob.sublist(0, _nonceLength),
        mac: Mac(blob.sublist(blob.length - _macLength)),
      ),
      secretKey: SecretKey(base64Decode(keyB64)),
    );
    return Uint8List.fromList(clear);
  }
}
