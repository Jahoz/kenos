import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../echo/data/echo_providers.dart';
import '../../echo/domain/echo_cipher.dart';

/// A constellation on the map: metadata only (seed, state, counts).
class ConstellationMeta {
  const ConstellationMeta({
    required this.id,
    required this.seedX,
    required this.seedY,
    required this.state,
    required this.lineCount,
    required this.target,
    this.kind = ConstellationKind.poem,
    this.curatedBy,
  });

  final String id;
  final double seedX;
  final double seedY;
  final String state; // OPEN | CLOSED
  final int lineCount;
  final int target;

  /// POEM (sealed text lines) or MELODY (sealed note phrases — the
  /// constellation-song, V3.14).
  final ConstellationKind kind;

  /// The Curator's attribution (V3.14b): a curated constellation is
  /// REAL public-domain poetry, and the reading NAMES the poet — it
  /// never pretends strangers wrote it. Null = strangers' own.
  final String? curatedBy;

  bool get isClosed => state == 'CLOSED';

  factory ConstellationMeta.fromJson(Map<String, dynamic> json) =>
      ConstellationMeta(
        id: json['id'] as String,
        seedX: (json['seed_x'] as num).toDouble(),
        seedY: (json['seed_y'] as num).toDouble(),
        state: json['state'] as String,
        lineCount: (json['line_count'] as num).toInt(),
        target: (json['target'] as num).toInt(),
        kind: json['kind'] == 'MELODY'
            ? ConstellationKind.melody
            : ConstellationKind.poem,
        curatedBy: json['curated_by'] as String?,
      );
}

/// A corpse is a poem or a song — chosen at the drop, never mixed.
enum ConstellationKind { poem, melody }

/// LE SALON (V3.19): what a drop returns when the ring is born behind
/// a door. The invite token crosses the wire exactly once, here — it
/// exists in the share link and on the seeder's device, nowhere else.
class SeededConstellation {
  const SeededConstellation({required this.meta, this.inviteToken});

  final ConstellationMeta meta;
  final String? inviteToken;

  bool get isSalon => inviteToken != null;
}

/// The salon door refused the key — demo parity for the SQL guard
/// (KENOS_INVITE_UNKNOWN: missing and wrong look alike).
class SalonKeyRefused implements Exception {
  const SalonKeyRefused();

  @override
  String toString() => 'KENOS_INVITE_UNKNOWN';
}

/// One assembled line of a read constellation.
class AssembledLine {
  const AssembledLine({required this.number, required this.text});

  final int number;
  final String text;
}

/// What a contribution returns: the line count so far, and the
/// PRECEDING line (the classic surrealist rule — one continues,
/// nobody sees the whole). Null previous = the contributor opens
/// the poem.
class ContributeResult {
  const ContributeResult({required this.count, this.previous});

  final int count;
  final AssembledLine? previous;
}

/// What the ether actually said when a line was refused — the
/// writer deserves the reason, not a shrug.
String contributeRefusalMessage(Object error) {
  final raw = error.toString();
  if (raw.contains('KENOS_ALREADY_CONTRIBUTED')) {
    return 'TA PHRASE EST DÉJÀ DANS CE CORPS.';
  }
  if (raw.contains('KENOS_RATE_LIMIT')) {
    return 'LE CIEL SOUFFLE — REVIENS DANS DEUX MINUTES.';
  }
  if (raw.contains('KENOS_CLOSED')) {
    return 'LE POÈME S\'EST REFERMÉ AILLEURS.';
  }
  if (raw.contains('KENOS_INVALID_LENGTH')) {
    return 'LA PHRASE EST TROP LONGUE POUR LE CIEL.';
  }
  if (raw.contains('KENOS_INVITE_UNKNOWN')) {
    return 'LE SALON N\'A PAS RECONNU TA CLÉ.';
  }
  return 'L\'ÉTHER A REFUSÉ LA LIGNE.';
}

/// The Exquisite Corpse contract (V3.13 — classic rule): seed,
/// contribute by continuing the preceding line, read the FINISHED
/// poem — an artifact, open to everyone (contributors included),
/// re-readable like the vestiges.
abstract class ConstellationRepository {
  /// Whether THIS stranger already gave a line to the corpse — the
  /// ether's truth (across devices and sessions), asked at the tap.
  /// Null = unreachable (fail-open: the caller falls back to the
  /// device's local memory).
  Future<bool?> hasContributed(String constellationId);

  /// Seeds a new open constellation at the given position — a poem
  /// or a song, chosen at the drop, never mixed. Invited = LE SALON:
  /// the ring is born behind a door and the returned bundle carries
  /// the link's key (once, to the seeder only).
  Future<SeededConstellation> seed(
    double x,
    double y, {
    ConstellationKind kind = ConstellationKind.poem,
    bool invited = false,
  });

  /// Contributes ONE sealed line, continuing from the preceding one
  /// (returned sealed — opened on this device). Never the fragments
  /// of the whole (the soul of the blind poem). A salon ring demands
  /// its door key — the claim IS the contribution.
  Future<ContributeResult> contribute({
    required String constellationId,
    required String text,
    String? inviteToken,
  });

  /// The tail of an OPEN poem — exactly ONE line (the last), to
  /// continue it. Null when the poem has not started. The whole
  /// stays blind. A salon ring demands its key here too.
  Future<AssembledLine?> peekPrevious(
    String constellationId, {
    String? inviteToken,
  });

  /// LE SALON: the link's key resolves the ring's metadata — enough
  /// for the claim screen to speak, blind as the map. Throws when
  /// the key opens nothing (wrong or expired — alike, by design).
  Future<ConstellationMeta> fetchInvited(String token);

  /// The map's constellations (metadata only).
  Future<List<ConstellationMeta>> fetchVisible();

  /// Reads a CLOSED constellation whole — an artifact: no
  /// destruction, no contributor bar, readable again and again.
  /// Returns null when the corpse is not finished (or is gone with
  /// the ether's 30-day horizon).
  Future<List<AssembledLine>?> read(String id);
}

class SupabaseConstellationRepository implements ConstellationRepository {
  SupabaseConstellationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SeededConstellation> seed(
    double x,
    double y, {
    ConstellationKind kind = ConstellationKind.poem,
    bool invited = false,
  }) async {
    final rows = await _client.rpc('seed_constellation', params: {
      'p_seed_x': x,
      'p_seed_y': y,
      'p_kind': kind == ConstellationKind.melody ? 'MELODY' : 'POEM',
      'p_invited': invited,
    });
    final row = ((rows as List).first as Map).cast<String, dynamic>();
    final id = row['id'] as String;
    final token = row['invite_token'] as String?;
    // The server picks a random target 4-7; fetch the whole truth. An
    // open salon never shows in the sky — its exact truth comes back
    // through the door itself.
    if (token != null) {
      return SeededConstellation(
        meta: await fetchInvited(token),
        inviteToken: token,
      );
    }
    final all = await fetchVisible();
    return SeededConstellation(
      meta: all.firstWhere(
        (c) => c.id == id,
        orElse: () => ConstellationMeta(
          id: id,
          seedX: x,
          seedY: y,
          state: 'OPEN',
          lineCount: 0,
          target: 5,
          kind: kind,
        ),
      ),
    );
  }

  @override
  Future<ContributeResult> contribute({
    required String constellationId,
    required String text,
    String? inviteToken,
  }) async {
    // The line is sealed on-device like an echo — the corpse never
    // sees what it carries.
    final sealed = await EchoCipher.seal(text);
    final result = await _client.rpc('contribute_line', params: {
      'p_constellation_id': constellationId,
      'p_ciphertext': sealed.payloadB64,
      'p_key': sealed.keyB64,
      'p_invite_token': ?inviteToken,
    });
    final bundle = (result as Map).cast<String, dynamic>();
    final previousBundle = bundle['previous'] as Map?;
    // The preceding line opens HERE, on the contributor's device —
    // the server passed its key exactly once, for this one line.
    AssembledLine? previous;
    if (previousBundle != null) {
      final cipherText = previousBundle['text'] as String;
      final key = previousBundle['key'] as String?;
      final clear = (key == null || key.isEmpty)
          ? cipherText
          : await EchoCipher.openOrNull(key, cipherText);
      if (clear != null) {
        previous = AssembledLine(
          number: (bundle['count'] as num).toInt() - 1,
          text: clear,
        );
      }
    }
    return ContributeResult(
      count: (bundle['count'] as num).toInt(),
      previous: previous,
    );
  }

  @override
  Future<AssembledLine?> peekPrevious(
    String constellationId, {
    String? inviteToken,
  }) async {
    try {
      final result = await _client.rpc(
        'peek_previous_line',
        params: {
          'p_constellation_id': constellationId,
          'p_invite_token': ?inviteToken,
        },
      );
      if (result == null) return null;
      final bundle = (result as Map).cast<String, dynamic>();
      final cipherText = bundle['text'] as String;
      final key = bundle['key'] as String?;
      final clear = (key == null || key.isEmpty)
          ? cipherText
          : await EchoCipher.openOrNull(key, cipherText);
      if (clear == null) return null;
      return AssembledLine(number: 0, text: clear);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ConstellationMeta>> fetchVisible() async {
    final rows = await _client.rpc('fetch_constellations', params: {
      'p_min_x': 0,
      'p_min_y': 0,
      'p_max_x': 1,
      'p_max_y': 1,
    });
    return (rows as List)
        .map((row) =>
            ConstellationMeta.fromJson((row as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<ConstellationMeta> fetchInvited(String token) async {
    final result = await _client.rpc(
      'fetch_invited_constellation',
      params: {'p_token': token},
    );
    return ConstellationMeta.fromJson(
      (result as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<bool?> hasContributed(String id) async {
    try {
      return await _client.rpc(
        'has_contributed',
        params: {'p_constellation_id': id},
      ) as bool;
    } catch (_) {
      return null; // the sky is a guest here: never block the tap
    }
  }

  @override
  Future<List<AssembledLine>?> read(String id) async {
    try {
      final result = await _client.rpc(
        'read_constellation',
        params: {'p_constellation_id': id},
      );
      if (result == null) return null;
      return assembleFromBundle(
        (result as Map<String, dynamic>).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  /// V3.11a — the winner's bundle, opened on-device: each line travels
  /// as the client-sealed ciphertext plus its key (unsealed from escrow
  /// by the RPC, exactly like `consume_echo`). A line that fails to
  /// open reads as silence — never an error, never a re-read.
  static Future<List<AssembledLine>> assembleFromBundle(
    Map<String, dynamic> bundle,
  ) async {
    final lines = (bundle['lines'] as List).cast<Map>();
    final opened = <AssembledLine>[];
    for (final line in lines) {
      final map = line.cast<String, dynamic>();
      final cipherText = map['text'] as String;
      final key = map['key'] as String?;
      final text = (key == null || key.isEmpty)
          ? cipherText
          : await EchoCipher.openOrNull(key, cipherText) ?? '';
      opened.add(AssembledLine(
        number: (map['line_number'] as num).toInt(),
        text: text,
      ));
    }
    return opened;
  }
}

/// Demo repository: same contract, in memory.
class LocalConstellationRepository implements ConstellationRepository {
  final List<_DemoConstellation> _constellations = [];

  @override
  Future<SeededConstellation> seed(
    double x,
    double y, {
    ConstellationKind kind = ConstellationKind.poem,
    bool invited = false,
  }) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final token = invited ? 'salon-${stamp.toRadixString(36)}' : null;
    final c = _DemoConstellation(
      meta: ConstellationMeta(
        id: 'const-$stamp',
        seedX: x,
        seedY: y,
        state: 'OPEN',
        lineCount: 0,
        target: 4 + (DateTime.now().second % 4),
        kind: kind,
      ),
      inviteToken: token,
    );
    _constellations.add(c);
    return SeededConstellation(meta: c.currentMeta, inviteToken: token);
  }

  @override
  Future<ContributeResult> contribute({
    required String constellationId,
    required String text,
    String? inviteToken,
  }) async {
    final c = _constellations.firstWhere((c) => c.meta.id == constellationId);
    // The salon door: no key, no line — and a wrong key behaves
    // exactly like a missing one (parity with the SQL guard).
    if (c.inviteToken != null && inviteToken != c.inviteToken) {
      throw SalonKeyRefused();
    }
    // The classic rule: the contributor continues the preceding line.
    final previous = c.lines.isEmpty
        ? null
        : AssembledLine(number: c.lines.length, text: c.lines.last);
    c.lines.add(text);
    if (c.lines.length >= c.meta.target) {
      c.closed = true;
    }
    return ContributeResult(count: c.lines.length, previous: previous);
  }

  @override
  Future<AssembledLine?> peekPrevious(
    String constellationId, {
    String? inviteToken,
  }) async {
    final c = _constellations.firstWhere(
      (c) => c.meta.id == constellationId,
      orElse: () => throw StateError('unknown constellation'),
    );
    if (c.inviteToken != null && inviteToken != c.inviteToken) {
      throw SalonKeyRefused();
    }
    if (c.lines.isEmpty) return null;
    return AssembledLine(number: c.lines.length, text: c.lines.last);
  }

  @override
  Future<List<ConstellationMeta>> fetchVisible() async => [
        // Parity with the ether: an open salon does not exist on the
        // map; closed, it joins the sky like any artifact.
        for (final c in _constellations)
          if (c.inviteToken == null || c.closed) c.currentMeta,
      ];

  @override
  Future<ConstellationMeta> fetchInvited(String token) async {
    final matches = _constellations.where((c) => c.inviteToken == token);
    if (matches.isEmpty) throw SalonKeyRefused();
    return matches.first.currentMeta;
  }

  @override
  Future<bool?> hasContributed(String id) async => null;

  @override
  Future<List<AssembledLine>?> read(String id) async {
    final c = _constellations.firstWhere((c) => c.meta.id == id);
    // An artifact: finished poems are read whole, by anyone, as many
    // times as the sky passes by — nothing is consumed.
    if (!c.closed || c.lines.isEmpty) return null;
    return [
      for (var i = 0; i < c.lines.length; i++)
        AssembledLine(number: i + 1, text: c.lines[i]),
    ];
  }
}

class _DemoConstellation {
  _DemoConstellation({required this.meta, this.inviteToken});

  final ConstellationMeta meta;

  /// Null = a public ring; set = a salon behind this key.
  final String? inviteToken;

  final List<String> lines = [];
  bool closed = false;

  ConstellationMeta get currentMeta => ConstellationMeta(
        id: meta.id,
        seedX: meta.seedX,
        seedY: meta.seedY,
        state: closed ? 'CLOSED' : 'OPEN',
        lineCount: lines.length,
        target: meta.target,
        kind: meta.kind,
      );
}

/// Supabase when configured, the demo ether otherwise.
final constellationRepositoryProvider =
    Provider<ConstellationRepository>((ref) {
  final boot = ref.watch(bootstrapProvider);
  if (boot.supabaseConfigured) {
    return SupabaseConstellationRepository(Supabase.instance.client);
  }
  return LocalConstellationRepository();
});
