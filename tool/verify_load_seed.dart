// KENOS — load-seed end-to-end verification.
//
// Proves the seeded ether is FUNCTIONAL, not just present: walks the
// exact client path over the real PostgREST (anonymous signup →
// sector map → atomic consume) and opens the sealed bundle on "the
// device" with the app's own cipher — then does the same for a
// closed constellation corpse. Exits non-zero on any failure.
//
// Usage:
//   dart run tool/verify_load_seed.dart [apiUrl] [anonKey]
//   (defaults to the local stack via `supabase status -o json`)

import 'dart:convert';
import 'dart:io';

import 'package:kenos/features/echo/domain/echo_cipher.dart';

Future<dynamic> post(
  String apiUrl,
  String anonKey,
  String path, {
  String? bearer,
  Object? body,
}) async {
  final client = HttpClient();
  try {
    final req = await client
        .openUrl('POST', Uri.parse('$apiUrl$path'));
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('apikey', anonKey);
    if (bearer != null) {
      req.headers.set('Authorization', 'Bearer $bearer');
    }
    req.write(jsonEncode(body ?? {}));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 400) {
      throw StateError('HTTP ${res.statusCode} on $path: $text');
    }
    if (text.isEmpty || text == 'null') return null;
    return jsonDecode(text);
  } finally {
    client.close();
  }
}

Future<void> main(List<String> args) async {
  final apiUrl = args.isNotEmpty
      ? args[0].replaceAll(RegExp(r'/$'), '')
      : 'http://127.0.0.1:56321';
  final anonKey = args.length > 1
      ? args[1]
      : await _localAnonKey();

  stdout.writeln('── KENOS vérification du seed sur $apiUrl ──');

  // 1. Anonymous identity, exactly like the app.
  final session =
      await post(apiUrl, anonKey, '/auth/v1/signup') as Map<String, dynamic>;
  final token = session['access_token'] as String;
  stdout.writeln('  ✓ anonyme créé');

  // 2. The first gaze: opening-camera rect.
  final map = await post(
    apiUrl,
    anonKey,
    '/rest/v1/rpc/fetch_map_sector',
    bearer: token,
    body: const {
      'p_min_x': 0.1643,
      'p_min_y': 0.1643,
      'p_max_x': 0.8357,
      'p_max_y': 0.8357,
    },
  ) as List<dynamic>;
  if (map.isEmpty) {
    throw StateError('carte vide — seed d\'abord (make db-seed-load)');
  }
  stdout.writeln('  ✓ carte consultée (${map.length} étoiles)');

  // 3. Consume one sealed echo and open it on the device.
  final target = map.first as Map<String, dynamic>;
  final bundle = await post(
    apiUrl,
    anonKey,
    '/rest/v1/rpc/consume_echo',
    bearer: token,
    body: {'target_echo_id': target['id']},
  ) as Map<String, dynamic>?;
  if (bundle == null) {
    throw StateError('consume a perdu la course (étoile déjà lue)');
  }
  final ciphertext = bundle['ciphertext'] as String;
  final key = bundle['key'] as String?;
  if (key == null) {
    stdout.writeln('  ✓ écho legacy relu : "$ciphertext"');
  } else {
    final text = await EchoCipher.open(key, ciphertext);
    stdout.writeln('  ✓ écho scellé ouvert sur l\'appareil : "$text"');
  }

  // 4. A closed corpse, read whole once, every line opened.
  final corpses = (await post(
    apiUrl,
    anonKey,
    '/rest/v1/rpc/fetch_constellations',
    bearer: token,
    body: const {'p_min_x': 0, 'p_min_y': 0, 'p_max_x': 1, 'p_max_y': 1},
  ) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final closed = corpses.where((c) => c['state'] == 'CLOSED').toList();
  if (closed.isNotEmpty) {
    final read = await post(
      apiUrl,
      anonKey,
      '/rest/v1/rpc/consume_constellation',
      bearer: token,
      body: {'p_constellation_id': closed.first['id']},
    ) as Map<String, dynamic>;
    final lines = (read['lines'] as List).cast<Map<String, dynamic>>();
    var opened = 0;
    for (final line in lines) {
      final lineKey = line['key'] as String?;
      if (lineKey == null) continue;
      await EchoCipher.open(lineKey, line['text'] as String);
      opened++;
    }
    stdout.writeln('  ✓ cadavre exquis relu entier ($opened lignes ouvertes)');
  }

  stdout.writeln('── SEED FONCTIONNEL ✓ ──');
}

Future<String> _localAnonKey() async {
  final result = await Process.run('supabase', ['status', '-o', 'json']);
  final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  return data.entries
      .firstWhere((e) => e.key.toLowerCase().contains('anon'))
      .value as String;
}
