import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../domain/kenos_wave.dart';
import '../domain/spatial_wave_math.dart';

/// V3.6 — the spatialized Collective Symphony: real sine oscillators
/// (flutter_soloud), one preloaded AudioSource per pentatonic note,
/// each wave placed in the stereo field by its horizontal offset and
/// attenuated by its distance to the listening point.
///
/// Honest degradation, always: if the engine cannot initialize (web
/// without WASM, an exotic platform, a test VM), [playNote] returns
/// false and the caller falls back to the baked assets — the symphony
/// never goes silent over an engine. Fire-and-forget by contract:
/// nothing here may throw or block the UI.
class SpatialWaveAudio {
  SpatialWaveAudio._();

  static final SpatialWaveAudio instance = SpatialWaveAudio._();

  static const _attack = Duration(milliseconds: 1200);
  static const _presence = Duration(milliseconds: 2400);
  static const _release = Duration(milliseconds: 2400);

  bool _initTried = false;
  bool _ready = false;
  final List<AudioSource?> _sources =
      List<AudioSource?>.filled(WaveMath.noteCount, null);

  bool get isReady => _ready;

  Future<void> _ensureInit() async {
    if (_initTried) return;
    _initTried = true;
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) {
        await soloud.init();
      }
      for (var n = 0; n < WaveMath.noteCount; n++) {
        final source = await soloud.loadWaveform(
          WaveForm.sin,
          false, // superwave off: a pure fundamental, spatially clear
          1,
          0,
        );
        soloud.setWaveformFreq(source, SpatialWaveMath.frequencyForNote(n));
        _sources[n] = source;
      }
      _ready = true;
    } catch (e) {
      // The engine is a guest, never a host: waves fall back to assets.
      debugPrint('[kenos.spatial] engine unavailable, waves stay on assets: $e');
      _ready = false;
    }
  }

  /// Plays one spatialized note. Returns false when the engine is not
  /// available — the caller then plays the baked asset instead.
  Future<bool> playNote(
    int noteIndex, {
    required double pan,
    required double gain,
  }) async {
    try {
      await _ensureInit();
      if (!_ready) return false;
      final source = _sources[noteIndex.clamp(0, _sources.length - 1)];
      if (source == null) return false;
      final soloud = SoLoud.instance;

      // The nebula envelope, rebuilt in real time: a 1.2 s swell from
      // silence, 2.4 s of presence, then a 2.4 s exhale — and the wave
      // is gone at 6 s, exactly like the asset it replaces.
      final handle = soloud.play(source, volume: 0, pan: pan.clamp(-1, 1));
      soloud.fadeVolume(handle, gain.clamp(0.0, 1.0), _attack);
      unawaited(_exhale(soloud, handle, gain));
      soloud.scheduleStop(
        handle,
        _attack + _presence + _release + const Duration(milliseconds: 200),
      );
      return true;
    } catch (e) {
      debugPrint('[kenos.spatial] note degraded: $e');
      return false;
    }
  }

  /// The exhale half of the envelope — delayed by design, silent if the
  /// handle died young (ashes don't complain).
  Future<void> _exhale(SoLoud soloud, SoundHandle handle, double gain) async {
    await Future<void>.delayed(_attack + _presence);
    try {
      soloud.fadeVolume(handle, 0, _release);
    } catch (_) {
      // Already stopped: the silence is the same.
    }
  }
}
