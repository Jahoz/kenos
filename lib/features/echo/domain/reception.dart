/// A reception: the bottle-in-the-sea signal sent back to the author
/// when their echo is read by someone.
///
/// One-way by design: drift data + at most one short trace from the reader.
/// Viewing it burns it — no archive, no thread, no way to answer.
class Reception {
  const Reception({
    required this.echoId,
    required this.readAt,
    required this.driftSeconds,
    this.reply,
    this.seen = false,
  });

  final String echoId;
  final DateTime readAt;

  /// Time the echo drifted in the ether before being intercepted.
  final int driftSeconds;

  /// The reader's optional one-line trace (max 140 chars).
  final String? reply;

  /// Already viewed by the author (demo mode persistence;
  /// server-side, seen receptions are never returned again).
  final bool seen;

  Reception copyWith({bool? seen}) => Reception(
        echoId: echoId,
        readAt: readAt,
        driftSeconds: driftSeconds,
        reply: reply,
        seen: seen ?? this.seen,
      );

  /// Poetic distance: how far the echo traveled at the speed of the void.
  /// drift_seconds × c, expressed in astronomical units when it gets huge.
  double get distanceKm => driftSeconds * 299792.458;

  /// "187 UA" or "4 213 KM" — machine typography, French formatting.
  String get distanceLabel {
    final km = distanceKm;
    if (km >= 1.0e8) {
      final ua = km / 1.496e8;
      return '${_fr(ua)} UA';
    }
    return '${_fr(km)} KM';
  }

  /// "26 H 14 MIN" — the real, human drift time.
  String get driftLabel {
    final h = driftSeconds ~/ 3600;
    final m = (driftSeconds % 3600) ~/ 60;
    if (h == 0) return '$m MIN';
    return '$h H ${m.toString().padLeft(2, '0')} MIN';
  }

  static String _fr(double v) {
    if (v >= 100) {
      return v.round().toString().replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (m) => '\u202F',
          );
    }
    return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);
  }

  factory Reception.fromJson(Map<String, dynamic> json, {bool seen = false}) =>
      Reception(
        echoId: json['echo_id'] as String,
        readAt: DateTime.tryParse(json['read_at'] as String? ?? '') ??
            DateTime.now(),
        driftSeconds: (json['drift_seconds'] as num).toInt(),
        reply: (json['reply_text'] as String?),
        seen: seen,
      );

  Map<String, dynamic> toJson() => {
        'echo_id': echoId,
        'read_at': readAt.toIso8601String(),
        'drift_seconds': driftSeconds,
        'reply_text': reply,
        'seen': seen,
      };
}
