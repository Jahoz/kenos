import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/echo/domain/echo_cipher.dart';

/// V3.11a — the sealed corpse regression. The bug was server-side
/// ('text' carried the key), but this pins the client contract against
/// the FIXED bundle shape: ciphertext + key per line, opened on-device
/// with a real Ether Seal round trip.
void main() {
  test('une ligne scellée s\'ouvre sur l\'appareil du lecteur', () async {
    const secret = 'je garde le silence des autres';
    final sealed = await EchoCipher.seal(secret);

    final lines = await SupabaseConstellationRepository.assembleFromBundle({
      'lines': [
        {'line_number': 1, 'text': sealed.payloadB64, 'key': sealed.keyB64},
      ],
    });

    expect(lines.single.number, 1);
    expect(lines.single.text, secret,
        reason: 'le texte du bundle est le CHIFFRÉ, ouvert ici seulement');
  });

  test('une ligne héritée en clair passe telle quelle (chemin ancien)', () async {
    final lines = await SupabaseConstellationRepository.assembleFromBundle({
      'lines': [
        {'line_number': 2, 'text': 'ligne héritée', 'key': null},
      ],
    });
    expect(lines.single.text, 'ligne héritée');
  });

  test('un scellé corrompu lit le silence, jamais une erreur', () async {
    final lines = await SupabaseConstellationRepository.assembleFromBundle({
      'lines': [
        {
          'line_number': 3,
          'text': 'Y2VjaS1uZXN0LXBhcy1sZS12b2lkZQ==',
          'key': 'a2Vub3Mta2V5LXRlc3Q=',
        },
      ],
    });
    expect(lines.single.text, isEmpty,
        reason: 'un cadavre mort lit vide — jamais un crash du panneau');
  });

  test('un poème entier revient numéroté, dans l\'ordre', () async {
    final secrets = ['première', 'deuxième', 'troisième', 'quatrième'];
    final sealedLines = <Map<String, dynamic>>[];
    for (final (i, secret) in secrets.indexed) {
      final sealed = await EchoCipher.seal(secret);
      sealedLines.add({
        'line_number': i + 1,
        'text': sealed.payloadB64,
        'key': sealed.keyB64,
      });
    }

    final lines =
        await SupabaseConstellationRepository.assembleFromBundle({'lines': sealedLines});

    expect(lines.map((l) => l.text).toList(), secrets);
    expect(lines.map((l) => l.number).toList(), [1, 2, 3, 4]);
  });
}
