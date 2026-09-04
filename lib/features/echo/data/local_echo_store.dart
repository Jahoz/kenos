import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/echo.dart';
import '../domain/read_scar.dart';
import '../domain/reception.dart';
import 'user_stats_store.dart';

/// Secure local storage: onboarding flag, anonymous local UUID,
/// and the user's sealed echoes (metadata WITHOUT text).
///
/// Any native storage error falls back to an in-memory cache:
/// the app must never crash over a keychain issue.
class LocalEchoStore {
  LocalEchoStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final Map<String, String> _mem = {};

  static const _kOnboarded = 'kenos.onboarded';
  static const _kUid = 'kenos.uid';
  static const _kSealed = 'kenos.sealed_echoes';
  static const _kReceptions = 'kenos.receptions';
  static const _kFreqGuide = 'kenos.freq_guide';
  static const _kCorpseGuide = 'kenos.corpse_guide';
  static const _kEyeGuide = 'kenos.eye_guide';
  static const _kStats = 'kenos.user_stats';
  static const _kScars = 'kenos.read_scars';
  static const _maxSealed = 50;
  static const _maxScars = 80;

  /// Safety net: a wedged keychain I/O must never freeze the
  /// experience — we fall back to the memory cache.
  static const _ioTimeout = Duration(seconds: 2);

  Future<String?> _read(String key) async {
    if (_mem.containsKey(key)) return _mem[key];
    try {
      final value = await _storage
          .read(key: key)
          .timeout(_ioTimeout, onTimeout: () => null);
      if (value != null) _mem[key] = value;
      return value;
    } catch (e) {
      debugPrint('[kenos.store] read failed ($key): $e');
      return _mem[key];
    }
  }

  Future<void> _write(String key, String value) async {
    _mem[key] = value;
    try {
      await _storage
          .write(key: key, value: value)
          .timeout(_ioTimeout, onTimeout: () {});
    } catch (e) {
      debugPrint('[kenos.store] write failed ($key): $e');
    }
  }

  Future<bool> hasOnboarded() async => await _read(_kOnboarded) == '1';

  Future<void> setOnboarded() => _write(_kOnboarded, '1');

  /// Local anonymous UUID (backend-less demo mode).
  Future<String> localUserId() async {
    final existing = await _read(_kUid);
    if (existing != null) return existing;
    final id = _uuidV4();
    await _write(_kUid, id);
    return id;
  }

  Future<List<Echo>> sealedEchoes() async {
    final raw = await _read(_kSealed);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => Echo.fromJson(e as Map<String, dynamic>, isMine: true))
          .toList();
      return list;
    } catch (e) {
      debugPrint('[kenos.store] sealed echoes corrupted: $e');
      return const [];
    }
  }

  Future<void> addSealed(Echo echo) async {
    final current = await sealedEchoes();
    final next = [echo, ...current];
    if (next.length > _maxSealed) next.removeRange(_maxSealed, next.length);
    await _write(_kSealed, jsonEncode(next.map((e) => e.toJson()).toList()));
  }

  /// V3.8: a line was given to a constellation (the Awakening may
  /// whisper when one closes — the only signal, never a push).
  Future<void> recordConstellationTouched() async {
    final stats = await readStats();
    final updated = stats.copyWith(
      constellationsTouched: stats.constellationsTouched + 1,
    );
    await _write(_kStats, jsonEncode(updated.toJson()));
  }

  /// Frequencies guide seen (one-time veil).
  Future<bool> hasFrequenciesGuideSeen() async =>
      await _read(_kFreqGuide) == '1';

  Future<void> markFrequenciesGuideSeen() async =>
      _write(_kFreqGuide, '1');

  /// Corpses guide seen (one-time veil, same grammar).
  Future<bool> hasCorpseGuideSeen() async =>
      await _read(_kCorpseGuide) == '1';

  Future<void> markCorpseGuideSeen() async => _write(_kCorpseGuide, '1');

  /// The wheel whisper seen (one-time, desktop eye only — V3.17).
  Future<bool> hasEyeGuideSeen() async => await _read(_kEyeGuide) == '1';

  Future<void> markEyeGuideSeen() async => _write(_kEyeGuide, '1');

  /// Demo-mode persistence for the bottle-in-the-sea loop.
  Future<List<Reception>> readReceptions() async {    final raw = await _read(_kReceptions);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((r) => Reception.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[kenos.store] receptions corrupted: $e');
      return const [];
    }
  }

  Future<void> writeReceptions(List<Reception> receptions) async {
    await _write(
      _kReceptions,
      jsonEncode(receptions.map((r) => r.toJson()).toList()),
    );
  }

  /// Reading scars: contentless places where you held a light and it
  /// dissolved. Local to this device, capped, forgotten with the
  /// ether's 30-day horizon.
  Future<List<ReadScar>> readScars() async {
    final raw = await _read(_kScars);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final now = DateTime.now();
      return (jsonDecode(raw) as List)
          .map((s) => ReadScar.fromJson(s as Map<String, dynamic>))
          .whereType<ReadScar>()
          .where((s) => now.difference(s.readAt).inDays < 30)
          .toList();
    } catch (e) {
      debugPrint('[kenos.store] read scars corrupted: $e');
      return const [];
    }
  }

  Future<void> addReadScar(ReadScar scar) async {
    final current = await readScars();
    final next = [scar, ...current.where((s) => s.echoId != scar.echoId)];
    if (next.length > _maxScars) next.removeRange(_maxScars, next.length);
    await _write(_kScars, jsonEncode(next.map((s) => s.toJson()).toList()));
  }

  /// Read user stats (echo count, reception count, etc).
  Future<UserStats> readStats() async {
    final raw = await _read(_kStats);
    if (raw == null || raw.isEmpty) return UserStats.empty();
    try {
      return UserStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[kenos.store] stats corrupted: $e');
      return UserStats.empty();
    }
  }

  /// Update stats after sending an echo.
  Future<void> recordEchoSent() async {
    final stats = await readStats();
    final updated = stats.copyWith(
      totalEchosSent: stats.totalEchosSent + 1,
      lastEchoSentAt: DateTime.now(),
    );
    await _write(_kStats, jsonEncode(updated.toJson()));
  }

  /// Update stats after receiving a reception: one more human touched
  /// by something you launched — one mote of stardust.
  Future<void> recordReceptionReceived() async {
    final stats = await readStats();
    final updated = stats.copyWith(
      totalReceptionsReceived: stats.totalReceptionsReceived + 1,
      stardust: stats.stardust + 1,
    );
    await _write(_kStats, jsonEncode(updated.toJson()));
  }

  /// L'Aube: close a visit. What was unseen becomes seen; the sas
  /// will stay silent about it next time.
  Future<void> recordVisit() async {
    final stats = await readStats();
    final updated = stats.copyWith(
      seenReceptions: stats.totalReceptionsReceived,
      lastVisitAt: DateTime.now(),
    );
    await _write(_kStats, jsonEncode(updated.toJson()));
  }

  /// Update stats after leaving a trace.
  Future<void> recordTraceLeft() async {
    final stats = await readStats();
    final updated =
        stats.copyWith(totalTracesLeft: stats.totalTracesLeft + 1);
    await _write(_kStats, jsonEncode(updated.toJson()));
  }

  /// Update stats after reading an echo: you carried a stranger's
  /// thought — the manifest says stardust is earned by reading.
  Future<void> recordEchoRead() async {
    final stats = await readStats();
    final updated = stats.copyWith(
      readCount: stats.readCount + 1,
      stardust: stats.stardust + 1,
    );
    await _write(_kStats, jsonEncode(updated.toJson()));
  }

  String _uuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
        '${hex(4)}${hex(5)}-${hex(6)}${hex(7)}-'
        '${hex(8)}${hex(9)}-${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
  }

  /// Releases resources (the plugin exposes nothing critical, kept
  /// for symmetry with the Riverpod lifecycle).
  void dispose() {}
}
