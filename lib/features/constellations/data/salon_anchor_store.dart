import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// L'ANCRE DU SALON — the door holder's local memory of open salons
/// (V3.19's missing participant anchor, delivered).
///
/// An open salon is invisible on the sky by law, and its one link is
/// shown once — a seeder who did not copy it was locked out of their
/// own ring until it died at day seven. The anchor closes that hole
/// without bending any law: it is DEVICE-LOCAL only (never a byte to
/// the network, like the artifact memory), it carries the door key —
/// which already lives on this device by contract ('the token exists
/// in the link and on the seeder's device, nowhere else') — and it
/// holds NO content: no line, no poem, just where the ring sleeps and
/// how to knock.
///
/// The anchor dies with the door: open rings are reaped at 7 days, so
/// an anchor older than that prunes itself, network or not. When the
/// ring closes, the ANCHOR is dropped — the artifact that remains is
/// public and indistinguishable, exactly as before.
class SalonAnchorStore {
  SalonAnchorStore({SalonAnchorIO? io}) : _io = io ?? const SecureSalonIO();

  final SalonAnchorIO _io;
  static const _kData = 'kenos.salon_anchors';

  /// The door's horizon: an open ring is reaped at 7 days (purge),
  /// so an anchor older than this is a memory of a dead key.
  static const anchorTtl = Duration(days: 7);

  final Map<String, SalonAnchor> _anchors = {};
  bool _loaded = false;

  /// Loads and prunes (dead-by-age anchors die quietly). Call once at
  /// boot; safe to call again.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _io.read(_kData);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;
      final ttlMs = anchorTtl.inMilliseconds;
      for (final a in (data['anchors'] as List? ?? const [])) {
        final anchor =
            SalonAnchor.fromJson((a as Map).cast<String, dynamic>());
        if (now - anchor.heldSince < ttlMs) {
          _anchors[anchor.id] = anchor;
        }
      }
    } catch (e) {
      debugPrint('[kenos.salons] anchors corrupted, starting fresh: $e');
    }
  }

  /// The doors this device still holds, oldest first.
  List<SalonAnchor> open() {
    final held = _anchors.values.toList()
      ..sort((a, b) => a.heldSince.compareTo(b.heldSince));
    return List.unmodifiable(held);
  }

  SalonAnchor? byId(String id) => _anchors[id];

  /// Remembers (or refreshes) a door this device holds — sower at the
  /// drop, guest at their first claimed line.
  Future<void> remember(SalonAnchor anchor) async {
    _anchors[anchor.id] = anchor;
    await _persist();
  }

  /// The door is gone (reaped, or the ring closed into its public
  /// artifact): the anchor goes with it.
  Future<void> forget(String id) async {
    if (_anchors.remove(id) == null) return;
    await _persist();
  }

  /// LA BRAISE (V3.60a) — every held door goes dark at once: the
  /// body's honest death (the keys live on in the body that received
  /// the ember; this one holds nothing anymore).
  Future<void> eraseAll() async {
    _anchors.clear();
    await _persist();
  }

  Future<void> _persist() async {
    await _io.write(
      _kData,
      jsonEncode({
        'anchors': [for (final a in _anchors.values) a.toJson()],
      }),
    );
  }
}

/// One door held on this device: where the ring sleeps, how to knock.
/// No content — never a line, never a poem.
class SalonAnchor {
  const SalonAnchor({
    required this.id,
    required this.token,
    required this.seedX,
    required this.seedY,
    required this.kind,
    required this.target,
    required this.heldSince,
  });

  final String id;

  /// The door key (16 bytes hex). Local-only by contract; the base
  /// keeps only its sha256.
  final String token;

  /// Logical sky position in [0,1] — where the seeder planted the ring.
  final double seedX;
  final double seedY;

  /// 'POEM' | 'MELODY' (ConstellationKind wire grammar).
  final String kind;
  final int target;

  /// Epoch ms — when this device started holding the door.
  final int heldSince;

  factory SalonAnchor.fromJson(Map<String, dynamic> json) => SalonAnchor(
        id: json['id'] as String,
        token: json['token'] as String,
        seedX: (json['seedX'] as num).toDouble(),
        seedY: (json['seedY'] as num).toDouble(),
        kind: json['kind'] as String? ?? 'POEM',
        target: (json['target'] as num?)?.toInt() ?? 0,
        heldSince: (json['heldSince'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'token': token,
        'seedX': seedX,
        'seedY': seedY,
        'kind': kind,
        'target': target,
        'heldSince': heldSince,
      };
}

/// Storage seam: secure storage in the app, a plain map in tests.
abstract class SalonAnchorIO {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureSalonIO implements SalonAnchorIO {
  const SecureSalonIO();

  static const _storage = FlutterSecureStorage();
  static const _ioTimeout = Duration(seconds: 2);

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage
          .read(key: key)
          .timeout(_ioTimeout, onTimeout: () => null);
    } catch (e) {
      debugPrint('[kenos.salons] read failed: $e');
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
      debugPrint('[kenos.salons] write failed: $e');
    }
  }
}

/// One door memory per device, shared by the map and the salon doors.
final salonAnchorStoreProvider = Provider<SalonAnchorStore>(
  (ref) => SalonAnchorStore(),
);
