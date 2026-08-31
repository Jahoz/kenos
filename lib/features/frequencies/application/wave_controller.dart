import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/frequency_repository.dart';
import '../domain/kenos_wave.dart';

/// State of the Symphonie Collective: the currently breathing waves —
/// the user's own, and the strangers' heard within the listening
/// radius (V3.2: a 2 s poll over the normalized-space bbox).
class WaveController extends Notifier<List<KenosWave>> {
  static const maxWaves = 24;

  /// Default listening point: the center of the field. Follows the
  /// user's last tap.
  static const double hearingRadius = 0.35;
  static const Duration pollInterval = Duration(seconds: 2);

  int _seq = 0;
  Timer? _purgeTicker;
  Timer? _poll;
  bool _activated = false;

  (double, double) _listenCenter = (0.5, 0.5);

  final _incoming = StreamController<KenosWave>.broadcast();

  /// Waves born elsewhere, heard just now. The screen sounds them.
  Stream<KenosWave> get incomingWaves => _incoming.stream;

  /// Injectable clock (tests pin time to exercise the purge).
  @visibleForTesting
  DateTime Function() nowSource = DateTime.now;

  FrequencyRepository get _repo => ref.read(frequencyRepositoryProvider);

  @override
  List<KenosWave> build() {
    ref.onDispose(() {
      _purgeTicker?.cancel();
      _poll?.cancel();
      _incoming.close();
    });
    return const <KenosWave>[];
  }

  /// The screen is alive: start hearing the ether.
  void activate() {
    if (_activated) return;
    _activated = true;
    _poll = Timer.periodic(pollInterval, (_) => _pollOnce());
  }

  /// The screen went away: silence the poll.
  void deactivate() {
    _activated = false;
    _poll?.cancel();
    _poll = null;
  }

  void setListenCenter(double x, double y) {
    _listenCenter = (x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
  }

  /// Distance of a point to the current listening center, normalized.
  double listenDistanceTo(double x, double y) {
    final dx = x - _listenCenter.$1;
    final dy = y - _listenCenter.$2;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Emits a wave at the normalized tap position. Returns it so the
  /// caller can sound it. The ether crossing is fire-and-forget: an
  /// unreachable backend degrades to a local-only wave, never an error.
  KenosWave emit(double offsetX, double offsetY) {
    final now = nowSource();
    setListenCenter(offsetX, offsetY);
    final wave = KenosWave(
      id: 'w${now.microsecondsSinceEpoch}-${_seq++}',
      offsetX: offsetX.clamp(0.0, 1.0),
      offsetY: offsetY.clamp(0.0, 1.0),
      noteIndex: WaveMath.noteForY(offsetY),
      hueIndex: WaveMath.hueForX(offsetX),
      bornAt: now,
    );
    final alive = _alive(state);
    while (alive.length >= maxWaves) {
      alive.removeAt(0);
    }
    state = [...alive, wave];
    _ensurePurgeTicker();
    unawaited(
      _repo
          .emit(
            offsetX: wave.offsetX,
            offsetY: wave.offsetY,
            noteIndex: wave.noteIndex,
            hueIndex: wave.hueIndex,
          )
          .catchError((Object e) {
        debugPrint('[kenos.frequencies] emit degraded to local: $e');
      }),
    );
    return wave;
  }

  /// Test hook: run one poll cycle deterministically.
  @visibleForTesting
  Future<void> debugPollOnce() => _pollOnce();

  Future<void> _pollOnce() async {
    final List<RemoteWave> heard;
    try {
      heard = await _repo.fetchNearby(
        centerX: _listenCenter.$1,
        centerY: _listenCenter.$2,
        radius: hearingRadius,
      );
    } catch (e) {
      debugPrint('[kenos.frequencies] poll unreachable: $e');
      return;
    }
    if (heard.isEmpty) return;
    final now = nowSource();
    final known = state.map((w) => w.id).toSet();
    for (final remote in heard) {
      if (known.contains(remote.id)) continue;

      // How old is this wave at arrival? The ether's life is 60 s, but
      // the NEBULA breathes for its full envelope from ARRIVAL — a wave
      // heard late must still be seen, never flash-and-vanish (or worse,
      // arrive already dead, which made strangers inaudible-invisible).
      final age = now.difference(remote.createdAt);
      if (age.inSeconds > 45) continue; // almost gone: let it rest.
      final fresh = age.inSeconds <= 10; // sound only for the freshly born.

      final wave = KenosWave(
        id: remote.id,
        offsetX: remote.offsetX,
        offsetY: remote.offsetY,
        noteIndex: remote.noteIndex,
        hueIndex: remote.hueIndex,
        // Arrival, not server birth: the envelope plays in full here.
        bornAt: now,
      );
      final alive = _alive(state);
      while (alive.length >= maxWaves) {
        alive.removeAt(0);
      }
      state = [...alive, wave];
      _ensurePurgeTicker();
      // Catch-up of stale waves stays silent (no wall of sound on
      // open); fresh ones sing, softer the further they were born.
      if (fresh && !_incoming.isClosed) _incoming.add(wave);
    }
  }

  /// Drops the waves whose life is over.
  void purgeExpired() {
    final alive = _alive(state);
    if (alive.length != state.length) {
      state = alive;
    }
    if (alive.isEmpty) {
      _purgeTicker?.cancel();
      _purgeTicker = null;
    }
  }

  List<KenosWave> _alive(List<KenosWave> waves) {
    final now = nowSource();
    return waves.where((w) => !w.isExpiredAt(now)).toList();
  }

  void _ensurePurgeTicker() {
    _purgeTicker ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      purgeExpired();
    });
  }
}

final waveControllerProvider =
    NotifierProvider<WaveController, List<KenosWave>>(WaveController.new);
