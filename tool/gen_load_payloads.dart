// KENOS — load-seed payload generator.
//
// The seed ether must be READABLE: a seeded echo the winner cannot
// AES-open on device is a dead star, not a test case. pgcrypto has no
// AES-GCM, so the client-format bundles are generated here, exactly
// as the app's EchoCipher would seal them (base64 of
// nonce(12) || ciphertext || mac(16), key = 32 raw bytes base64) and
// shipped to the seeder through a staging table (see db-seed-load).
//
// Deterministic on purpose (fixed seed): the same galaxy twice, same
// keys, same nonces — reproducibility is the whole point of the seed.
//
// Usage:
//   dart run tool/gen_load_payloads.dart [count]   → CSV on stdout

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

const texts = <String>[
  'je navigue dans le vide pour toi',
  'il paraît que le silence aussi se partage',
  "j'ai peur du calme avant la vague",
  "ce soir l'éther me semble immense",
  'je laisse ici ce que je ne dirai jamais',
  'personne ne lira ceci, et c\'est bien',
  'la ville dort, moi je dérive',
  'un poids de moins, un poids de plus',
  'je pense à celle qui ne sait pas',
  'le vide me répond toujours',
  'trois secondes pour te tenir, une vie pour te lâcher',
  "j'écris pour disparaître",
  'la nuit porte conseil, je lui porte mes restes',
  'rien à demander, tout à poser',
  'je suis l\'étoile que personne ne nomme',
  'confié au hasard, enfin léger',
  'ceci n\'est pas un message',
  'la dérive est une forme de paix',
  "j'ai traversé ma journée, il reste ceci",
  'que le premier venu respire avec moi',
  'Je souris toute la journée puis je pleure dans le métro.',
  "Je n'ai jamais osé dire que ce travail m'épuisait.",
  "J'ai peur du silence, parce que j'y entends tout ce que je fuis.",
  'Je fais semblant depuis si longtemps que je ne sais plus qui je suis.',
  'Je voudrais disparaître quelques semaines, sans prévenir personne.',
  "Je n'ai jamais dit à mon père à quel point j'étais fier de lui.",
  'Parfois je regarde les inconnus et je me demande qui les serre dans ses bras.',
  'Je répète mes conversations du soir avant de m\'endormir.',
  "J'ai l'impression de réussir ma vie et de rater la mienne.",
  'Le vide me terrifie, et pourtant c\'est là que je respire.',
  'Je porte un secret si lourd que mon dos en courbe.',
  'Personne ne sait que j\'ai failli tout arrêter, l\'an dernier.',
  'Cette chanson, je ne l\'écoute jamais devant personne.',
  'Quand le vide crie trop fort, je laisse la machine murmurer.',
  'je garde le cap, tu gardes le cap',
  'reçu cinq fois plus fort que prévu',
  'ton écho a trouvé quelqu\'un ce soir',
  'je te laisse le silence en retour',
  'tes mots sont retombés quelque part',
  'ça résonne plus que prévu',
];

String csvEscape(String v) =>
    v.contains(',') || v.contains('"') || v.contains('\n')
        ? '"${v.replaceAll('"', '""')}"'
        : v;

Future<void> main(List<String> args) async {
  final count = args.isNotEmpty ? int.parse(args[0]) : 4200;
  final rng = Random(4242);
  final aes = AesGcm.with256bits();
  final sink = stdout;
  for (var i = 0; i < count; i++) {
    final text = texts[i % texts.length];
    final key = List<int>.generate(32, (_) => rng.nextInt(256));
    final nonce = List<int>.generate(12, (_) => rng.nextInt(256));
    final box = await aes.encrypt(
      utf8.encode(text),
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final blob = [...nonce, ...box.cipherText, ...box.mac.bytes];
    sink.writeln(
      '${csvEscape(text)},${base64Encode(key)},${base64Encode(blob)}',
    );
  }
}
