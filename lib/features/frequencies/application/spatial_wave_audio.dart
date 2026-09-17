import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../core/audio/voice_budget.dart';
import '../domain/kenos_wave.dart';
import '../domain/spatial_wave_math.dart';

/// V3.6 — the spatialized Collective Symphony: real sine oscillators
/// (flutter_soloud), one preloaded AudioSource per pentatonic note,
/// each wave placed in the stereo field by its horizontal offset and
/// attenuated by its distance to the listening point.
///
/// V3.55 — THE SKY HAS SIX THROATS: every note used to ring a full
/// 6-second nebula and stack without limit — fast song phrases (holds
/// from 120 ms) and quick waves clipped the output hard. Now each
/// voice lives inside a [VoiceBudget] (the oldest yields, every voice
/// sings at 1/√n so the power never sums above one), and a note with
/// a HOLD ends with its tenue instead of the nebula.
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

  /// A held note's own envelope law: a soft touch-in, an exhale never
  /// longer than the note itself was.
  static const _heldAttack = Duration(milliseconds: 120);
  static const _heldRelease = Duration(milliseconds: 360);

  /// A stolen voice's mercy: a fast fade, never a click.
  static const _stealFade = Duration(milliseconds: 140);

  bool _initTried = false;
  bool _ready = false;
  final List<AudioSource?> _sources =
      List<AudioSource?>.filled(WaveMath.noteCount, null);

  /// The living voices: handle + absolute end, in admission order
  /// (the budget steals the oldest of these).
  final List<({SoundHandle handle, DateTime endsAt})> _voices = [];
  final VoiceBudget _budget = VoiceBudget(maxVoices: 6);

  bool get isReady => _ready;

  /// One note's envelope: when the fade-in ends, when the exhale
  /// begins, how long the exhale lasts, and the note's full life.
  @visibleForTesting
  static ({Duration attack, Duration exhaleAt, Duration release, Duration life})
      envelopeFor(Duration? hold) {
    if (hold == null) {
      // The nebula: 1.2 s swell, 2.4 s presence, 2.4 s exhale — the
      // 6 s of the asset it replaces.
      return (
        attack: _attack,
        exhaleAt: _attack + _presence,
        release: _release,
        life: _attack + _presence + _release,
      );
    }
    // The tenue IS the presence: the note sounds for exactly as long
    // as the stranger held it, then exhales — never past its phrase.
    final attack = hold < _heldAttack ? hold : _heldAttack;
    final release = hold < _heldRelease ? hold : _heldRelease;
    return (
      attack: attack,
      exhaleAt: hold,
      release: release,
      life: hold + release,
    );
  }

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
  ///
  /// [hold] is the note's TENUE (the constellation-song's rhythm): a
  /// held note swells briefly, sounds exactly its hold, then exhales.
  /// Without a hold the wave keeps its nebula envelope.
  Future<bool> playNote(
    int noteIndex, {
    required double pan,
    required double gain,
    Duration? hold,
  }) async {
    try {
      await _ensureInit();
      if (!_ready) return false;
      final source = _sources[noteIndex.clamp(0, _sources.length - 1)];
      if (source == null) return false;
      final soloud = SoLoud.instance;
      final env = envelopeFor(hold);

      final now = DateTime.now();
      final verdict = _budget.admit(now, now.add(env.life));
      // The stolen die first, gently.
      for (final i in verdict.steal) {
        try {
          soloud.fadeVolume(_voices[i].handle, 0, _stealFade);
          soloud.scheduleStop(
            _voices[i].handle,
            _stealFade + const Duration(milliseconds: 60),
          );
        } catch (_) {
          // Already gone: the silence is the same.
        }
      }
      _voices.removeWhere((v) => !v.endsAt.isAfter(now));

      final handle = soloud.play(source, volume: 0, pan: pan.clamp(-1, 1));
      // 1/√n: however many voices ring, the POWER stays one note's.
      final scaled = gain.clamp(0.0, 1.0) * verdict.gainScale;
      soloud.fadeVolume(handle, scaled, env.attack);
      _voices.add((handle: handle, endsAt: now.add(env.life)));
      unawaited(_exhale(soloud, handle, env));
      soloud.scheduleStop(
        handle,
        env.life + const Duration(milliseconds: 200),
      );
      return true;
    } catch (e) {
      debugPrint('[kenos.spatial] note degraded: $e');
      return false;
    }
  }

  /// The exhale half of the envelope — delayed by design, silent if the
  /// handle died young (ashes don't complain).
  Future<void> _exhale(
    SoLoud soloud,
    SoundHandle handle,
    ({Duration attack, Duration exhaleAt, Duration release, Duration life})
        env,
  ) async {
    await Future<void>.delayed(env.exhaleAt);
    try {
      soloud.fadeVolume(handle, 0, env.release);
    } catch (_) {
      // Already stopped: the silence is the same.
    }
  }
}
