// KENOS — the Vestige Translator (V3.16).
//
// "On garde KENOS": the product voice stays French, canonical. What
// crosses borders is the CURATED CULTURE — this tool translates the
// canonical French shards into a target locale through Mistral, in
// the kenos voice, with a verification pass, and emits upsert SQL
// (id + locale). The human stays the gate: staging first, --emit to
// write the batch.
//
// THE PRODUCT LAW (enforced by NOT having a tool for it): user
// content — echoes, constellations, songs, traces — is NEVER
// translated. Sealed on-device, it crosses borders in the language
// it was whispered in.
//
// Usage (FREE — Mistral free tier, ~100 tokens/shard):
//   VESTIGE_AI_URL=https://api.mistral.ai/v1/chat/completions \
//   VESTIGE_AI_KEY=... VESTIGE_AI_MODEL=mistral-small-latest \
//     dart run tool/translate_vestiges.dart --to en \
//       [--seed-file supabase/snippets/curate_vestiges.sql] [--emit]
//
// Output: vestiges_staging_<locale>.md (review) and, with --emit,
// supabase/snippets/vestiges_<locale>.sql (upserts, locale-aware).

import 'dart:convert';
import 'dart:io';

import 'gen_vestiges.dart' as g;

void main(List<String> args) async {
  var to = 'en';
  var seedFile = 'supabase/snippets/curate_vestiges.sql';
  var emit = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--to': to = args[++i];
      case '--seed-file': seedFile = args[++i];
      case '--emit': emit = true;
    }
  }

  try {
    await _run(to, seedFile, emit);
  } catch (e) {
    stderr.writeln('TRADUCTEUR: $e');
    exit(1);
  }
}

Future<void> _run(String to, String seedFile, bool emit) async {
  final corpus = g.loadExisting(seedFile);
  if (corpus.isEmpty) {
    throw StateError('no canonical shards found in $seedFile');
  }
  stdout.writeln('── Traducteur de Vestiges ──');
  stdout.writeln('cible: $to · canon FR: ${corpus.length} éclats');

  // Translate in batches of 6 (small JSON, honest model).
  final translated = <Map<String, dynamic>>[];
  for (var i = 0; i < corpus.length; i += 6) {
    final batch = corpus.skip(i).take(6).toList();
    final out = await g.chat([
      {
        'role': 'system',
        'content':
            'Tu traduis des éclats de culture française vers '
            '${_languageName(to)}, pour une app contemplative (KENOS) '
            'où des pensées dérivent dans un « éther » cosmique.\n'
            'LA VOIX : contemplative, précise, jamais marketing ni '
            'fiche Wikipédia. Traduis le SENS et le registre, pas les '
            'mots — une traduction qui sonne naturellement écrite en '
            '${_languageName(to)}, pas calquée du français.\n'
            'Les SOURCES (noms d\'auteurs, domaines comme « grec '
            'ancien ») se traduisent naturellement (« ancient Greek ») '
            'sauf les noms propres. Les HAIKUS restent trois lignes.\n'
            'Réponds en JSON: {"shards": [{"id": "...", "kind": "...", '
            '"text": "translation", "source": "translation"}]}'
      },
      {
        'role': 'user',
        'content': jsonEncode({
          'shards': [
            for (final s in batch)
              {'id': s['id'], 'kind': s['kind'], 'text': s['text'],
               'source': s['source']},
          ],
        }),
      },
    ], temperature: 0.3);
    final shards = (out['shards'] as List? ?? [])
        .map((v) => (v as Map).cast<String, dynamic>())
        .toList();
    translated.addAll(shards);
    stdout.writeln('  traduits ${translated.length}/${corpus.length}…');
  }

  // Verify: meaning preserved, nothing invented, voice intact.
  stdout.writeln('vérification…');
  final verified = await g.chat([
    {
      'role': 'system',
      'content':
          'Tu vérifies des traductions ${_languageName(to)} d\'éclats '
          'français. Pour chaque paire: la traduction préserve-t-elle '
          'le SENS (aucun fait ajouté, retiré ou altéré) et sonne-t-'
          'elle naturelle? Note: {"items": [{"verdict": "ok"|"fix"|"drop", '
          '"confidence": 0-1, "text": "corrigée si fix"}]}. '
          'Une traduction qui invente ou perd un fait = drop.',
    },
    {
      'role': 'user',
      'content': [
        for (var i = 0; i < translated.length; i++)
          '${i + 1}. FR: ${corpus[i]['text']}\n'
          '   ${to.toUpperCase()}: ${translated[i]['text']}',
      ].join('\n\n'),
    },
  ], temperature: 0.1);

  // Normalize both verify shapes (array or numbered map — the sower's
  // lesson: providers disagree).
  final verdicts = <Map<String, dynamic>>[];
  final raw = verified['items'];
  if (raw is List) {
    verdicts.addAll(raw.map((v) => (v as Map).cast<String, dynamic>()));
  } else {
    final keys = verified.keys.toList()
      ..sort((a, b) =>
          (int.tryParse(a.toString()) ?? 1 << 30)
              .compareTo(int.tryParse(b.toString()) ?? 1 << 30));
    for (final k in keys) {
      final v = verified[k];
      if (v is Map) verdicts.add(v.cast<String, dynamic>());
    }
  }

  final kept = <Map<String, dynamic>>[];
  for (var i = 0; i < translated.length; i++) {
    if (i >= verdicts.length) break;
    final v = verdicts[i];
    final conf = (v['confidence'] as num?)?.toDouble() ?? 0;
    final shard = translated[i];
    if (v['verdict'] == 'ok' && conf >= 0.8) {
      kept.add(shard);
    } else if (v['verdict'] == 'fix' && conf >= 0.8) {
      final fixed = (v['text'] as String?)?.trim();
      if (fixed != null && fixed.length >= 10) {
        shard['text'] = fixed;
        kept.add(shard);
      }
    }
  }

  // Positions: the SAME shard keeps its sky position across languages
  // (a star does not move because you read it in English).
  final byId = {
    for (final c in corpus) c['id'] as String: c,
  };
  stdout.writeln('\nkept ${kept.length}/${translated.length}');
  for (final s in kept) {
    stdout.writeln('  [${s['kind']}] ${s['text']}  — ${s['source']}');
  }

  final staging = File('vestiges_staging_$to.md');
  staging.writeAsStringSync('''
# Vestiges — staging ($to)

Traduits du canon FR, vérifiés (sens préservé), prêts à relire.
Approuve puis relance avec --emit.

${kept.map((s) => "- [${s['kind']}] ${s['text']} — ${s['source']}").join('\n')}
''');
  stdout.writeln('\nstaging: ${staging.path}');

  if (emit && kept.isNotEmpty) {
    final rnd = DateTime.now().millisecondsSinceEpoch;
    final buf = StringBuffer('''
-- KENOS — translated vestiges ($to, generated $rnd).
begin;
insert into public.kenos_vestiges (id, kind, text, source, pos_x, pos_y, locale) values
''');
    for (var i = 0; i < kept.length; i++) {
      final s = kept[i];
      final id = s['id'] as String? ?? 'x-$i';
      final src = byId[id];
      // Fall back to a drifting position when the id is unknown.
      final angle = i * 2.39996;
      final r = 0.18 + 0.28 * ((i % 7) / 7);
      final x = src == null
          ? (0.5 + r * _cos(angle)).clamp(0.05, 0.95)
          : (src['x'] as num).toDouble();
      final y = src == null
          ? (0.5 + r * _sin(angle)).clamp(0.05, 0.95)
          : (src['y'] as num).toDouble();
      final tail = i == kept.length - 1 ? '' : ',';
      buf.write(
          "('${_sql(id)}', '${_sql(s['kind']!)}', '${_sql(s['text']!)}', "
          "'${_sql(s['source']!)}', ${x.toStringAsFixed(3)}, "
          '${y.toStringAsFixed(3)}, \'$to\')$tail\n');
    }
    buf.write('''
on conflict (id, locale) do update
    set kind = excluded.kind,
        text = excluded.text,
        source = excluded.source,
        live = true;
commit;
''');
    File('supabase/snippets/vestiges_$to.sql').writeAsStringSync(buf.toString());
    stdout.writeln('SQL: supabase/snippets/vestiges_$to.sql');
  } else if (!emit) {
    stdout.writeln('(mode revue — ajoute --emit pour générer le SQL)');
  }
}

String _sql(String s) => s.replaceAll("'", "''");

String _languageName(String code) => switch (code) {
      'en' => 'anglais',
      'es' => 'espagnol',
      'de' => 'allemand',
      'pt' => 'portugais',
      'it' => 'italien',
      _ => code,
    };

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
