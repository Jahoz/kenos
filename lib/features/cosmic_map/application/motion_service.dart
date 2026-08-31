import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/utils/low_pass_filter.dart';

/// Normalized device tilt, each component in [-1, 1].
class Tilt {
  const Tilt(this.x, this.y);
  final double x;
  final double y;
  static const Tilt zero = Tilt(0, 0);
}

/// Motion service for the stellar parallax.
///
/// Uses the accelerometer (the gravity vector gives the tilt, which the
/// gyroscope — angular velocity — does not provide directly), filtered
/// through a low-pass to smooth tremors.
///
/// On sensor-less platforms (macOS, web, iOS simulator), it switches to a
/// slow sinusoidal drift: the space stays alive.
class MotionService {
  MotionService() {
    _init();
  }

  final _controller = StreamController<Tilt>.broadcast();
  StreamSubscription<AccelerometerEvent>? _sub;
  Timer? _fallbackTimer;
  double _fallbackT = 0;

  final _fx = LowPassFilter(alpha: 0.08);
  final _fy = LowPassFilter(alpha: 0.08);

  Stream<Tilt> get stream => _controller.stream;

  Future<void> _init() async {
    try {
      _sub =
          accelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 50),
          ).listen(
            _onAccelerometer,
            onError: (Object e) {
              debugPrint('[kenos.motion] sensors unavailable: $e');
              _startFallback();
            },
            cancelOnError: true,
          );
    } catch (e) {
      debugPrint('[kenos.motion] sensors unavailable: $e');
      _startFallback();
    }
  }

  void _onAccelerometer(AccelerometerEvent event) {
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (magnitude < 0.01) return;
    // Normalized by the gravity vector: unit-independent
    // (m/s² on Android, g on iOS) and bounded to [-1, 1].
    final rawX = (event.x / magnitude).clamp(-1.0, 1.0) * 1.6;
    final rawY = (event.y / magnitude).clamp(-1.0, 1.0) * 1.6;
    if (!_controller.isClosed) {
      _controller.add(Tilt(_fx.filter(rawX), _fy.filter(rawY)));
    }
  }

  void _startFallback() {
    if (_fallbackTimer != null) return;
    _fallbackTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _fallbackT += 0.033;
      final x = math.sin(_fallbackT * 0.21) * 0.32;
      final y = math.cos(_fallbackT * 0.13) * 0.27;
      if (!_controller.isClosed) _controller.add(Tilt(x, y));
    });
  }

  void dispose() {
    _sub?.cancel();
    _fallbackTimer?.cancel();
    _controller.close();
  }
}

final tiltProvider = StreamProvider<Tilt>((ref) {
  final service = MotionService();
  ref.onDispose(service.dispose);
  return service.stream;
});
