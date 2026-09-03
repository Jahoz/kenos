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
  });

  final String id;
  final double seedX;
  final double seedY;
  final String state; // OPEN | CLOSED
  final int lineCount;
  final int target;

  bool get isClosed => state == 'CLOSED';

  factory ConstellationMeta.fromJson(Map<String, dynamic> json) =>
      ConstellationMeta(
        id: json['id'] as String,
        seedX: (json['seed_x'] as num).toDouble(),
        seedY: (json['seed_y'] as num).toDouble(),
        state: json['state'] as String,
        lineCount: (json['line_count'] as num).toInt(),
        target: (json['target'] as num).toInt(),
      );
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

/// The Exquisite Corpse contract (V3.13 — classic rule): seed,
/// contribute by continuing the preceding line, read the FINISHED
/// poem — an artifact, open to everyone (contributors included),
/// re-readable like the vestiges.
abstract class ConstellationRepository {
  /// Seeds a new open constellation at the given position.
  Future<ConstellationMeta> seed(double x, double y);

  /// Contributes ONE sealed line, continuing from the preceding one
  /// (returned sealed — opened on this device). Never the fragments
  /// of the whole (the soul of the blind poem).
  Future<ContributeResult> contribute({
    required String constellationId,
    required String text,
  });

  /// The tail of an OPEN poem — exactly ONE line (the last), to
  /// continue it. Null when the poem has not started. The whole
  /// stays blind.
  Future<AssembledLine?> peekPrevious(String constellationId);

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
  Future<ConstellationMeta> seed(double x, double y) async {
    final rows = await _client.rpc('seed_constellation', params: {
      'p_seed_x': x,
      'p_seed_y': y,
    });
    final id = ((rows as List).first as Map)['id'] as String;
    // The server picks a random target 4-7; fetch it.
    final all = await fetchVisible();
    return all.firstWhere(
      (c) => c.id == id,
      orElse: () => ConstellationMeta(
        id: id,
        seedX: x,
        seedY: y,
        state: 'OPEN',
        lineCount: 0,
        target: 5,
      ),
    );
  }

  @override
  Future<ContributeResult> contribute({
    required String constellationId,
    required String text,
  }) async {
    // The line is sealed on-device like an echo — the corpse never
    // sees what it carries.
    final sealed = await EchoCipher.seal(text);
    final result = await _client.rpc('contribute_line', params: {
      'p_constellation_id': constellationId,
      'p_ciphertext': sealed.payloadB64,
      'p_key': sealed.keyB64,
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
  Future<AssembledLine?> peekPrevious(String constellationId) async {
    try {
      final result = await _client.rpc(
        'peek_previous_line',
        params: {'p_constellation_id': constellationId},
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
  Future<ConstellationMeta> seed(double x, double y) async {
    final c = _DemoConstellation(
      meta: ConstellationMeta(
        id: 'const-${DateTime.now().microsecondsSinceEpoch}',
        seedX: x,
        seedY: y,
        state: 'OPEN',
        lineCount: 0,
        target: 4 + (DateTime.now().second % 4),
      ),
    );
    _constellations.add(c);
    return c.meta;
  }

  @override
  Future<ContributeResult> contribute({
    required String constellationId,
    required String text,
  }) async {
    final c = _constellations.firstWhere((c) => c.meta.id == constellationId);
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
  Future<AssembledLine?> peekPrevious(String constellationId) async {
    final c = _constellations.firstWhere(
      (c) => c.meta.id == constellationId,
      orElse: () => throw StateError('unknown constellation'),
    );
    if (c.lines.isEmpty) return null;
    return AssembledLine(number: c.lines.length, text: c.lines.last);
  }

  @override
  Future<List<ConstellationMeta>> fetchVisible() async =>
      [for (final c in _constellations) c.currentMeta];

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
  _DemoConstellation({required this.meta});

  final ConstellationMeta meta;
  final List<String> lines = [];
  bool closed = false;

  ConstellationMeta get currentMeta => ConstellationMeta(
        id: meta.id,
        seedX: meta.seedX,
        seedY: meta.seedY,
        state: closed ? 'CLOSED' : 'OPEN',
        lineCount: lines.length,
        target: meta.target,
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
