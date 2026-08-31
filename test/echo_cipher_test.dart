import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/echo/domain/echo_cipher.dart';

void main() {
  group('EchoCipher (Ether Seal)', () {
    test('roundtrip: seal then open restores the exact plaintext', () async {
      const text = 'un aveu que personne ne doit relire, même pas l\'éther';
      final sealed = await EchoCipher.seal(text);
      expect(sealed.payloadB64, isNot(contains('aveu')));
      expect(await EchoCipher.open(sealed.keyB64, sealed.payloadB64), text);
    });

    test('each echo gets its own ephemeral key and nonce', () async {
      final a = await EchoCipher.seal('même texte');
      final b = await EchoCipher.seal('même texte');
      expect(a.keyB64, isNot(b.keyB64));
      expect(a.payloadB64, isNot(b.payloadB64));
    });

    test('tampering with the ciphertext is detected (GCM auth)', () async {
      final sealed = await EchoCipher.seal('secret');
      final bytes = base64Decode(sealed.payloadB64);
      bytes[bytes.length - 3] ^= 0x01; // flip one bit of the MAC/ciphertext
      final tampered = base64Encode(bytes);
      expect(
        () => EchoCipher.open(sealed.keyB64, tampered),
        throwsA(anything),
      );
    });

    test('the wrong key cannot open a sealed echo', () async {
      final sealed = await EchoCipher.seal('secret');
      final other = await EchoCipher.seal('autre');
      expect(
        () => EchoCipher.open(other.keyB64, sealed.payloadB64),
        throwsA(anything),
      );
    });

    test('openOrNull: corrupt or wrong-key seals resolve to null', () async {
      final sealed = await EchoCipher.seal('secret');
      final other = await EchoCipher.seal('autre');
      // Valid seal → text.
      expect(await EchoCipher.openOrNull(sealed.keyB64, sealed.payloadB64),
          'secret');
      // Wrong key → null (dead echo, not an error).
      expect(
          await EchoCipher.openOrNull(other.keyB64, sealed.payloadB64), isNull);
      // Tampered payload → null.
      final bytes = base64Decode(sealed.payloadB64);
      bytes[bytes.length - 3] ^= 0x01;
      expect(
        await EchoCipher.openOrNull(sealed.keyB64, base64Encode(bytes)),
        isNull,
      );
      // Truncated payload → null.
      expect(
        await EchoCipher.openOrNull(
            sealed.keyB64, base64Encode(bytes.sublist(0, 8))),
        isNull,
      );
    });

    test('multiline and emoji content survives the seal', () async {
      const text = 'ligne une\nligne deux 🌌 — accentué';
      final sealed = await EchoCipher.seal(text);
      expect(await EchoCipher.open(sealed.keyB64, sealed.payloadB64), text);
    });

    test('binary media opens only with the echo ephemeral key', () async {
      final sealed = await EchoCipher.seal('text carrier');
      final bytes = Uint8List.fromList([0, 3, 255, 17, 42]);
      final encrypted = await EchoCipher.sealBytesWithKey(bytes, sealed.keyB64);

      expect(await EchoCipher.openBytes(sealed.keyB64, encrypted), bytes);
      encrypted[encrypted.length - 1] ^= 1;
      expect(
        () => EchoCipher.openBytes(sealed.keyB64, encrypted),
        throwsA(anything),
      );
    });
  });
}
