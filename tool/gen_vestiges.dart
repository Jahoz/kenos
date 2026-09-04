// KENOS — the Vestige Sower: AI-generated shards at volume, verified.
//
// Produces curate-ready SQL for kenos_vestiges using an
// OpenAI-compatible chat API. Two passes:
//   1. SOW — generation in the kenos voice (few-shot on the live
//      corpus), one theme at a time, JSON-mode;
//   2. VERIFY — every factual claim re-examined by the model in a
//      separate pass: verdict + confidence; anything below the bar
//      is dropped or corrected, never shipped on faith.
// Deterministic guards regardless of the model: schema, bounds,
// dedup against the existing corpus (exact + normalized), language.
//
// The human stays the gate: default writes a STAGING markdown for
// review; --emit writes the SQL upsert file once you approve.
//
// Usage (FREE — Google AI Studio, no credit card, ~1500 req/day):
//   1. Get a key: https://aistudio.google.com/apikey
//   2. Export:
//        export VESTIGE_AI_URL=https://generativelanguage.googleapis.com/v1beta/openai/chat/completions
//        export VESTIGE_AI_KEY=AIza...
//        export VESTIGE_AI_MODEL=gemini-2.5-flash
//   3. make db-sow-vestiges SOW_ARGS='--count 20'
//
// Alternatives (also free, OpenAI-compatible):
//   Groq   — https://api.groq.com/openai/v1/chat/completions (model: llama-3.3-70b-versatile)
//   Mistral— https://api.mistral.ai/v1/chat/completions (~200 req/day, model: mistral-small-latest)
//
// The URL host is validated: http/https only, never
// loopback/private/reserved addresses.

import 'dart:convert';
import 'dart:io';

// ── Config ─────────────────────────────────────────────────────────────

String? env(String k) => Platform.environment[k]?.trim().isEmpty == true
    ? null
    : Platform.environment[k];

final aiUrl = env('VESTIGE_AI_URL') ?? env('OPENAI_BASE_URL');
final aiKey = env('VESTIGE_AI_KEY') ?? env('OPENAI_API_KEY');
final aiModel = env('VESTIGE_AI_MODEL') ?? 'gpt-4o-mini';

const themes = [
  'astronomie (distances lumineuses, planètes, étoiles, poussières)',
  'étymologies grecques et latines liées au vide, au silence, au voyage',
  'micro-histoires de bouteilles à la mer, Voyager, message spatiaux',
  'physique du vide et du son (quanta, plasma, silence)',
  'océanographie des courants et des dérives',
  'citons de domaine public (mort il y a 70+ ans) sur le vide, le don, le lâcher-prise',
  'neurosciences et mémoire (court, vérifiable)',
  'musique : gammes anciennes, pentatonique, résonances',
];

/// Some free providers ignore response_format and wrap JSON in
/// markdown fences or prose — salvage the outermost object anyway.
Map<String, dynamic> salvageJson(String raw) {
  var text = raw.trim();
  final fenced = RegExp(r'\`\`\`(?:json)?\s*([\s\S]*?)\`\`\`');
  final m = fenced.firstMatch(text);
  if (m != null) text = m.group(1)!.trim();
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start >= 0 && end > start) {
    text = text.substring(start, end + 1);
  }
  return jsonDecode(text) as Map<String, dynamic>;
}

// ── HTTP (stdlib, host-validated) ──────────────────────────────────────

Uri validatedUrl(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw StateError('VESTIGE_AI_URL must be http/https: $raw');
  }
  final host = uri.host;
  const blocked = {'localhost', '0.0.0.0', '[::1]', 'metadata.google.internal'};
  if (blocked.contains(host) ||
      host.startsWith('127.') ||
      host.startsWith('10.') ||
      host.startsWith('192.168.') ||
      host.startsWith('169.254.') ||
      (host.startsWith('172.') &&
          _inRange(int.tryParse(host.split('.')[1]), 16, 31))) {
    throw StateError('VESTIGE_AI_URL host refused (loopback/private/reserved): $host');
  }
  return uri;
}

bool _inRange(int? v, int lo, int hi) => v != null && v >= lo && v <= hi;

Future<Map<String, dynamic>> chat(
  List<Map<String, String>> messages, {
  double? temperature,
  int maxTokens = 4096,
}) async {
  if (aiUrl == null || aiKey == null) {
    throw StateError(
        'Set VESTIGE_AI_URL and VESTIGE_AI_KEY (OpenAI-compatible).');
  }
  final client = HttpClient();
  try {
    final req = await client.openUrl('POST', validatedUrl(aiUrl!));
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Authorization', 'Bearer $aiKey');
    req.write(jsonEncode({
      'model': aiModel,
      'messages': messages,
      'temperature': temperature ?? 0.8,
      'max_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
    }));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 400) {
      throw StateError('AI HTTP ${res.statusCode}: ${body.substring(0, body.length.clamp(0, 300))}');
    }
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List;
    final message = (choices.first as Map<String, dynamic>)['message']
        as Map<String, dynamic>;
    final content = message['content'] as String;
    return salvageJson(content);
  } finally {
    client.close();
  }
}

// ── Existing corpus (dedup + few-shot) ─────────────────────────────────

List<Map<String, dynamic>> loadExisting(String seedFile) {
  final file = File(seedFile);
  if (!file.existsSync()) return const [];
  final sql = file.readAsStringSync();
  final existing = <Map<String, dynamic>>[];
  // Values rows: ('id', 'kind', 'text…', 'source…', x, y),
  final rowRe = RegExp(
      r"\('([a-z0-9-]+)',\s*'(quote|etymology|haiku|history|fact)',\s*((?:'(?:[^']|'')*'|[^,])+),\s*((?:'(?:[^']|'')*'|[^,])+),\s*([0-9.]+),\s*([0-9.]+)\)");
  for (final m in rowRe.allMatches(sql)) {
    String unq(String s) => s.trim().replaceAll("''", "'");
    existing.add({
      'id': m.group(1),
      'kind': m.group(2),
      'text': unq(m.group(3)!.trim()),
      'source': unq(m.group(4)!.trim()),
    });
  }
  return existing;
}

String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-zà-ÿ0-9]'), '');

bool duplicateOf(String text, Iterable<Map<String, dynamic>> corpus) {
  final n = norm(text);
  if (n.length < 12) return true;
  for (final c in corpus) {
    final cn = norm(c['text'] as String);
    if (cn == n) return true;
    // Near-dup: one contains 80% of the other's words.
    final shorter = n.length < cn.length ? n : cn;
    final longer = n.length < cn.length ? cn : n;
    if (shorter.length > 20 && longer.contains(shorter.substring(0, shorter.length - 1))) {
      return true;
    }
  }
  return false;
}

// ── Pass 1: SOW ────────────────────────────────────────────────────────

const voiceGuide = '''
Tu es le curateur des Vestiges de KENOS — une app française de
décharge cognitive où des pensées intimes dérivent dans un « éther »
cosmique. Les Vestiges sont des éclats de CULTURE RÉELLE qui dérivent
aussi : citations, étymologies, faits (astronomie, physique, océan,
neurosciences), micro-histoires, haïkus. Le voyageur seul les lit en
frôlant le vide.

LA VOIX (sacrée) :
- français, court (max ~200 caractères), précis, légèrement poétique —
  jamais mièvre, jamais « wow », jamais liste à la Prévert ;
- un éclat se lit comme une confidence de l'univers, pas comme une
  fiche Wikipédia : le fait est exact, la tournure est contemplative ;
- la source cite le domaine ou l'auteur ('astronomie', 'grec ancien',
  'Sénèque'), jamais d'URL, jamais de date superflue ;
- les FAITS doivent être VÉRIFIABLES et SANS CONTESTATION : une
  constante physique connue, un événement daté documenté, une
  étymologie de dictionnaire. Si tu n'es pas sûr à 100 %, ne le sème
  pas. AUCUN chiffre inventé, aucune « statistique » approximative.
- les CITATIONS doivent être de vraies phrases d'auteurs morts il y a
  plus de 70 ans (domaine public), mot pour mot ou clairement marquées
  « après X » si adaptées.

Exemples de la voix (corpus vivant ci-dessous).''';

Future<List<Map<String, dynamic>>> sow({
  required String theme,
  required int count,
  required List<Map<String, dynamic>> corpus,
}) async {
  final fewShot = corpus.take(8).map((c) =>
      '[${c['kind']}] ${c['text']} — ${c['source']}').join('\n');
  final out = await chat([
    {
      'role': 'system',
      'content': '$voiceGuide\n\nCorpus vivant (ne pas dupliquer) :\n$fewShot'
    },
    {
      'role': 'user',
      'content':
          'Sème $count éclats sur le thème : $theme.\n'
          'Réponds en JSON : {"vestiges": [{"kind": "quote|etymology|haiku|history|fact", "text": "...", "source": "..."}]}'
    },
  ], temperature: 0.9);
  return (out['vestiges'] as List? ?? [])
      .map((v) => (v as Map).cast<String, dynamic>())
      .toList();
}

// ── Pass 2: VERIFY ─────────────────────────────────────────────────────

Future<List<Map<String, dynamic>>> verify(List<Map<String, dynamic>> batch) async {
  final numbered = [
    for (var i = 0; i < batch.length; i++)
      '${i + 1}. [${batch[i]['kind']}] ${batch[i]['text']} — ${batch[i]['source']}'
  ].join('\n');

  final out = await chat([
    {
      'role': 'system',
      'content':
          'Tu es un fact-checker impitoyable pour une bibliothèque culturelle '
          'française. Pour chaque éclat : le FAIT est-il exact et vérifiable '
          'sans contestation ? La CITATION est-elle authentique et de domaine '
          'public ? L\'ÉTYMOLOGIE est-elle correcte ? Note chaque item : '
          '{"verdict": "ok"|"fix"|"drop", "confidence": 0-1, "reason": "...", '
          '"text": "version corrigée si fix"}.\n'
          'Un chiffre arrondi au point d\'être faux = drop. Une citation '
          'paraphrasée non marquée = fix (marque « après X ») ou drop. '
          'Une étymologie contestée = drop. La prudence prime : dans le doute, drop.'
    },
    {'role': 'user', 'content': numbered},
  ], temperature: 0.1);

  final verdicts = (out['items'] as List? ?? [])
      .map((v) => (v as Map).cast<String, dynamic>())
      .toList();
  final kept = <Map<String, dynamic>>[];
  for (var i = 0; i < batch.length; i++) {
    if (i >= verdicts.length) break;
    final v = verdicts[i];
    final conf = (v['confidence'] as num?)?.toDouble() ?? 0;
    final shard = batch[i];
    switch (v['verdict']) {
      case 'ok':
        if (conf >= 0.8) kept.add(shard);
      case 'fix':
        final fixed = (v['text'] as String?)?.trim();
        if (conf >= 0.8 && fixed != null && fixed.length >= 10) {
          shard['text'] = fixed;
          kept.add(shard);
        }
      // drop or low confidence: gone.
    }
  }
  return kept;
}

// ── Guards ─────────────────────────────────────────────────────────────

const kinds = {'quote', 'etymology', 'haiku', 'history', 'fact'};

Map<String, dynamic>? guard(
  Map<String, dynamic> s,
  Set<String> seen,
  List<Map<String, dynamic>> corpus,
) {
  final text = (s['text'] as String?)?.trim();
  final kind = (s['kind'] as String?)?.trim();
  final source = ((s['source'] as String?) ?? '').trim();
  if (text == null || text.length < 10 || text.length > 400) return null;
  if (kind == null || !kinds.contains(kind)) return null;
  final n = norm(text);
  if (seen.contains(n) || duplicateOf(text, corpus)) return null;
  seen.add(n);
  return {...s, 'text': text, 'kind': kind, 'source': source};
}

// ── SQL emission ───────────────────────────────────────────────────────

String sqlEscape(String s) => s.replaceAll("'", "''");

String emitSql(List<Map<String, dynamic>> shards) {
  final rnd = DateTime.now().millisecondsSinceEpoch;
  final buf = StringBuffer('''
-- KENOS — AI-sown vestiges (generated $rnd, verified pass included).
-- Review the staging file before trusting this blindly: the verifier
-- drops and fixes, but the human stays the final gate.
begin;
insert into public.kenos_vestiges (id, kind, text, source, pos_x, pos_y) values
''');
  for (var i = 0; i < shards.length; i++) {
    final s = shards[i];
    // Drifting positions: golden-ish angle spiral, seeded by index.
    final angle = i * 2.39996; // golden angle
    final r = 0.18 + 0.28 * ((i % 7) / 7);
    final x = (0.5 + r * _cos(angle)).clamp(0.05, 0.95);
    final y = (0.5 + r * _sin(angle)).clamp(0.05, 0.95);
    final tail = i == shards.length - 1 ? '' : ',';
    buf.write(
        "('ai-$rnd-${i.toString().padLeft(2, '0')}', "
        "'${sqlEscape(s['kind']!)}', "
        "'${sqlEscape(s['text']!)}', "
        "'${sqlEscape(s['source']!)}', "
        '${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})$tail\n');
  }
  buf.write('''
on conflict (id) do nothing;
commit;
''');
  return buf.toString();
}

double _cos(double x) => _poly(x, [1, -0.5, 0.0416666, -0.0013888]);
double _sin(double x) => _poly(x, [0, 1, -0.1666666, 0.0083333]);
double _poly(double x, List<double> c) {
  var r = 0.0;
  var t = 1.0;
  for (var i = 0; i < 4; i++) {
    r += c[i] * t;
    t *= x;
  }
  return r;
}

// ── Main ───────────────────────────────────────────────────────────────

void main(List<String> args) async {

  try {
    await _run(args);
  } catch (e) {
    stderr.writeln('SEMEUR: $e');
    exit(1);
  }
}

Future<void> _run(List<String> args) async {
  var count = 12;
  var theme = themes[DateTime.now().millisecond % themes.length];
  var emit = false;
  var seedFile = 'supabase/snippets/curate_vestiges.sql';
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--count': count = int.parse(args[++i]);
      case '--theme': theme = args[++i];
      case '--seed-file': seedFile = args[++i];
      case '--emit': emit = true;
    }
  }
  final corpus = loadExisting(seedFile);
  stdout.writeln('── Semeur de Vestiges ──');
  stdout.writeln('modèle: $aiModel · thème: $theme · cible: $count');
  stdout.writeln('corpus existant (dédup): ${corpus.length} éclats');

  // Sow in batches of 6 (keeps JSON small and the model honest).
  final sown = <Map<String, dynamic>>[];
  while (sown.length < count) {
    final batch = (count - sown.length).clamp(1, 6);
    final fresh = await sow(theme: theme, count: batch, corpus: corpus);
    sown.addAll(fresh);
    stdout.writeln('  semé ${sown.length}/$count…');
  }

  // Verify (facts/citations/etymologies) in one pass.
  stdout.writeln('vérification (pass 2)…');
  final verified = await verify(sown);

  // Deterministic guards.
  final seen = <String>{};
  final finalShards = <Map<String, dynamic>>[];
  for (final s in verified) {
    final g = guard(s, seen, corpus);
    if (g != null) finalShards.add(g);
  }

  stdout.writeln('\nkept ${finalShards.length}/${sown.length} '
      '(verify + dedup + bounds)');
  for (final s in finalShards) {
    stdout.writeln('  [${s['kind']}] ${s['text']}  — ${s['source']}');
  }

  // Staging (always) — the human gate.
  final staging = File('vestiges_staging.md');
  staging.writeAsStringSync('''
# Vestiges — staging ($theme)

Vérifiés par la passe 2, prêts à relire humainement. Approuve puis :
`dart run tool/gen_vestiges.dart --emit` ou copie dans curate_vestiges.sql.

${finalShards.map((s) => "- [${s['kind']}] ${s['text']} — ${s['source']}").join('\n')}
''');
  stdout.writeln('\nstaging: ${staging.path} (relis, ajuste)');

  if (emit && finalShards.isNotEmpty) {
    final sql = emitSql(finalShards);
    File('supabase/snippets/vestiges_ai_batch.sql').writeAsStringSync(sql);
    stdout.writeln('SQL: supabase/snippets/vestiges_ai_batch.sql '
        '(à exécuter via db query --linked --file)');
  } else if (!emit) {
    stdout.writeln('(mode revue — ajoute --emit pour générer le SQL)');
  }
}
