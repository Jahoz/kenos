import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/kenos_wave.dart';

/// State of the Symphonie Collective: the currently breathing waves.
/// Local-only in V3.1 — the ether crossing (table `frequencies`,
/// radius hearing) is V3.2.
class WaveController extends Notifier<List<KenosWave>> {
  static const maxWaves = 24;

  int _seq = 0;
  Timer? _ticker;

  /// Injectable clock (tests pin time to exercise the purge).
  @visibleForTesting
  DateTime Function() nowSource = DateTime.now;

  @override
  List<KenosWave> build() {
    ref.onDispose(() => _ticker?.cancel());
    return const <KenosWave>[];
  }

  /// Emits a wave at the normalized tap position. Returns it so the
  /// caller can sound it.
  KenosWave emit(double offsetX, double offsetY) {
    final now = nowSource();
    final wave = KenosWave(
      id: 'w${now.microsecondsSinceEpoch}-${_seq++}',
      offsetX: offsetX.clamp(0.0, 1.0),
      offsetY: offsetY.clamp(0.0, 1.0),
      noteIndex: WaveMath.noteForY(offsetY),
      hueIndex: WaveMath.hueForX(offsetX),
      bornAt: now,
    );
    final alive = _alive(now, state);
    // A sanctuary has a ceiling: beyond it, the oldest waves dissolve
    // early instead of piling into noise.
    while (alive.length >= maxWaves) {
      alive.removeAt(0);
    }
    state = [...alive, wave];
    _ensureTicker();
    return wave;
  }

  /// Drops the waves whose life is over.
  void purgeExpired() {
    final now = nowSource();
    final alive = _alive(now, state);
    if (alive.length != state.length) {
      state = alive;
    }
    if (alive.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  List<KenosWave> _alive(DateTime now, List<KenosWave> waves) =>
      waves.where((w) => !w.isExpiredAt(now)).toList();

  void _ensureTicker() {
    _ticker ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      purgeExpired();
    });
  }
}

final waveControllerProvider =
    NotifierProvider<WaveController, List<KenosWave>>(WaveController.new);
