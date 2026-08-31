import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Zen bells — pure waves on a pentatonic scale, one per key action.
enum KenosBell {
  seal('bell_seal'),
  send('bell_send'),
  reveal('bell_reveal'),
  burn('bell_burn');

  const KenosBell(this.file);
  final String file;
  String get asset => 'assets/audio/$file.wav';
}

/// KENOS audio engine:
/// - a space drone (~70 Hz) looping constantly, whose pitch rises
///   during the Mindful Hold;
/// - one-shot bells layered on top without cutting the drone.
///
/// All errors are swallowed on purpose: sound is half the experience,
/// never a point of failure.
class AudioController {
  final AudioPlayer _drone = AudioPlayer();
  final List<AudioPlayer> _oneShots = [];

  bool _started = false;
  bool _muted = false;

  static const double _droneVolume = 0.32;

  bool get isMuted => _muted;

  /// Idempotent — called on the first user gesture.
  Future<void> ensureStarted() async {
    if (_started) return;
    _started = true;
    try {
      await _drone.setAsset('assets/audio/drone_loop.wav');
      await _drone.setLoopMode(LoopMode.one);
      await _drone.setVolume(0);
      await _drone.play();
      // Fade in to avoid any startup click.
      await _drone.setVolume(_droneVolume);
    } catch (e) {
      debugPrint('[kenos.audio] drone unavailable: $e');
    }
  }

  /// Drone pitch: 1.0 at rest, ~1.5 at full Mindful Hold charge.
  Future<void> setDronePitch(double pitch) async {
    if (!_started || _muted) return;
    try {
      await _drone.setPitch(pitch);
    } catch (_) {
      // Platforms without pitch support: silently ignored.
    }
  }

  Future<void> playBell(KenosBell bell) async {
    try {
      final player = AudioPlayer();
      _oneShots.add(player);
      await player.setAsset(bell.asset);
      await player.setVolume(_muted ? 0 : 0.5);
      await player.play();
      await player.dispose();
      _oneShots.remove(player);
    } catch (e) {
      debugPrint('[kenos.audio] bell unavailable: $e');
    }
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    try {
      await _drone.setVolume(_muted ? 0 : _droneVolume);
    } catch (_) {}
  }

  void dispose() {
    _drone.dispose();
    for (final p in _oneShots) {
      p.dispose();
    }
    _oneShots.clear();
  }
}
