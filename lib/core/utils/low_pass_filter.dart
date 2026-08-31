/// Single-axis low-pass filter to smooth sensor streams
/// (hand micro-tremors, accelerometer noise).
class LowPassFilter {
  LowPassFilter({this.alpha = 0.1});

  /// Smoothing coefficient: 0 = frozen, 1 = no smoothing.
  final double alpha;

  double? _last;

  /// Returns the filtered value.
  double filter(double value) {
    final last = _last;
    _last = last == null ? value : last + alpha * (value - last);
    return _last!;
  }

  /// Last filtered value without producing a new one.
  double? get value => _last;

  void reset() => _last = null;
}
