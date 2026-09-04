import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The traveller's memory of artifacts: read markers that fade after
/// a week, and the reliquaire — a handful of objects kept in ONE's
/// own sky longer than the moon.
///
/// Device-local by contract: never a byte to the network, never an
/// identity. The kept culture is PUBLIC text (a closed artifact is
/// readable by all; a vestige is curated domain culture) — the
/// 'sealed echoes carry no text locally' law is about private
/// thoughts, and artifacts are not confessions.
class ArtifactMemory {
  ArtifactMemory({ArtifactMemoryIO? io}) : _io = io ?? const SecureArtifactIO();

  final ArtifactMemoryIO _io;
  static const _kData = 'kenos.artifact_memory';

  /// A read marker is a memory, not a burn: after a week the artifact
  /// becomes a discovery again — for THIS device only, never for the
  /// ether.
  static const readTtl = Duration(days: 7);

  /// The reliquaire's measure: seven objects. Keeping an eighth
  /// returns the oldest to the sky.
  static const keepLimit = 7;

  final Map<String, int> _readAt = {};
  final List<KeptArtifact> _kept = [];
  bool _loaded = false;

  /// Loads and prunes (expired read markers die quietly). Call once
  /// at boot; safe to call again.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _io.read(_kData);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;
      final ttlMs = readTtl.inMilliseconds;
      for (final e
          in (data['read'] as Map<String, dynamic>? ?? {}).entries) {
        final at = e.value is num ? (e.value as num).toInt() : null;
        if (at != null && now - at < ttlMs) _readAt[e.key] = at;
      }
      _kept.addAll([
        for (final k in (data['kept'] as List? ?? const []))
          KeptArtifact.fromJson((k as Map).cast<String, dynamic>()),
      ]);
    } catch (e) {
      debugPrint('[kenos.artifacts] memory corrupted, starting fresh: $e');
    }
  }

  /// Whether THIS device read the artifact within the week.
  bool isRead(String id) => _readAt.containsKey(id);

  Future<void> markRead(String id) async {
    _readAt[id] = DateTime.now().millisecondsSinceEpoch;
    await _persist();
  }

  bool isKept(String id) => _kept.any((k) => k.id == id);

  KeptArtifact? keptById(String id) {
    for (final k in _kept) {
      if (k.id == id) return k;
    }
    return null;
  }

  List<KeptArtifact> kept() => List.unmodifiable(_kept);

  /// Keeps an artifact in this sky — forever local, no expiry. Over
  /// the limit, the oldest kept returns to the sky; the released one
  /// is returned (null when nothing had to go).
  Future<KeptArtifact?> keep(KeptArtifact artifact) async {
    _kept.removeWhere((k) => k.id == artifact.id);
    KeptArtifact? released;
    while (_kept.length >= keepLimit) {
      released = _kept.removeAt(0);
    }
    _kept.add(artifact);
    await _persist();
    return released;
  }

  Future<void> _persist() async {
    await _io.write(
      _kData,
      jsonEncode({
        'read': _readAt,
        'kept': [for (final k in _kept) k.toJson()],
      }),
    );
  }
}

/// One object kept in the traveller's sky: everything needed to
/// render AND re-read it locally, long after the moon takes the
/// original back.
class KeptArtifact {
  const KeptArtifact({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.texts,
    required this.keptAt,
    this.target = 0,
    this.source,
    this.vestigeKind,
    this.curatedBy,
  });

  /// 'constellation' (a closed artifact) or 'vestige'.
  final String kind;
  final String id;

  /// Logical sky position in [0,1] (seed for constellations, shard
  /// coordinates for vestiges) — resting resolution happens live.
  final double x;
  final double y;

  /// The culture itself: the poem's lines in order, or the shard's
  /// single text.
  final List<String> texts;

  /// The figure's station count (constellations; drives the signature).
  final int target;
  final int keptAt;
  final String? source;
  final String? vestigeKind;
  final String? curatedBy;

  factory KeptArtifact.fromJson(Map<String, dynamic> json) => KeptArtifact(
        id: json['id'] as String,
        kind: json['kind'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        texts: [for (final t in (json['texts'] as List)) t as String],
        target: (json['target'] as num?)?.toInt() ?? 0,
        keptAt: (json['keptAt'] as num?)?.toInt() ?? 0,
        source: json['source'] as String?,
        vestigeKind: json['vestigeKind'] as String?,
        curatedBy: json['curatedBy'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'x': x,
        'y': y,
        'texts': texts,
        'target': target,
        'keptAt': keptAt,
        'source': source,
        'vestigeKind': vestigeKind,
        'curatedBy': curatedBy,
      };
}

/// Storage seam: secure storage in the app, a plain map in tests.
abstract class ArtifactMemoryIO {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureArtifactIO implements ArtifactMemoryIO {
  const SecureArtifactIO();

  static const _storage = FlutterSecureStorage();
  static const _ioTimeout = Duration(seconds: 2);

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage
          .read(key: key)
          .timeout(_ioTimeout, onTimeout: () => null);
    } catch (e) {
      debugPrint('[kenos.artifacts] read failed: $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage
          .write(key: key, value: value)
          .timeout(_ioTimeout, onTimeout: () {});
    } catch (e) {
      debugPrint('[kenos.artifacts] write failed: $e');
    }
  }
}

/// One memory per device, shared by the map and the reading panels.
final artifactMemoryProvider = Provider<ArtifactMemory>(
  (ref) => ArtifactMemory(),
);
