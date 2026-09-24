import 'dart:math' as math;

/// A Vestige: real, curated culture drifting in the void — a quote, an
/// etymology, a haiku, a micro-history. NEVER a fake confession: the
/// sacred contract says a star is a real human thought; a Vestige is
/// culture, re-readable, carrying no author, no reception, no
/// stardust. Culture for the traveller who drifts alone.
class Vestige {
  const Vestige({
    required this.id,
    required this.kind,
    required this.text,
    required this.source,
    required this.offsetX,
    required this.offsetY,
    this.createdAt,
  });

  final String id;
  final String kind;
  final String text;
  final String source;
  final double offsetX;
  final double offsetY;

  /// V3.58 — when the ether grew this shard. Null = the bundled
  /// library (the offline canon, timeless by definition): the daily
  /// rotation treats timeless shards as it always has.
  final DateTime? createdAt;

  factory Vestige.fromJson(Map<String, dynamic> json) => Vestige(
        id: json['id'] as String,
        kind: json['kind'] as String,
        text: json['text'] as String,
        source: json['source'] as String,
        offsetX: (json['x'] as num).toDouble(),
        offsetY: (json['y'] as num).toDouble(),
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'] as String),
      );

  /// V3.58b — the moon of favour, as a property: a shard born less
  /// than 30 days ago is ALWAYS adrift, and now it LOOKS the part —
  /// publishing must not only exist, it must be SEEN.
  bool get isFresh =>
      createdAt != null &&
      DateTime.now().difference(createdAt!).inDays < 30;

  String get kindLabel => switch (kind) {
        'quote' => 'CITATION',
        'etymology' => 'ÉTYMOLOGIE',
        'haiku' => 'HAÏKU',
        'history' => 'HISTOIRE',
        'fact' => 'FAIT',
        _ => 'VESTIGE',
      };
}

/// The daily rotation, one pure truth (V3.58): ~2/3 of the OLD
/// library is adrift on any given day, deterministically — every
/// device sees the same drifting set, and tomorrow's sky holds shards
/// today's doesn't. But a shard YOUNGER THAN A MOON (30 days) is
/// always adrift: publishing must appear the same day, everywhere —
/// the rotation curates the old library, never against its publisher
/// (the live report: a published harvest stayed invisible for days).
List<Vestige> dailyRotation(List<Vestige> all, DateTime now) {
  final day = now.difference(DateTime(2026, 1, 1)).inDays;
  final visible = <Vestige>[];
  for (var i = 0; i < all.length; i++) {
    final shard = all[i];
    final fresh = shard.createdAt != null &&
        now.difference(shard.createdAt!).inDays < 30;
    final slot = (i + day * 5) % all.length;
    if (fresh || slot < all.length * 2 / 3) {
      visible.add(shard);
    }
  }
  return visible;
}

/// A Vestige's sky position: STATIC (culture doesn't orbit — it rests
/// where it drifted ashore), and so is its carving.
class VestigeMath {
  VestigeMath._();

  /// V3.73 — the shard's carving angle, STATIC: deterministic from its
  /// id (every hexagon points its own way — no two in choir), and it
  /// never turns. Culture RESTS: it does not tumble, it does not
  /// breathe, it waits ("les vestiges doivent être… statiques, le
  /// reste doit vivre", the owner's word). The old 47 s tumble died
  /// with its 250 ms clock — a battery breath with it.
  static double rotationOf(String id) {
    final h = (id.hashCode & 0x7fffffff);
    return (h % 9973) / 9973 * 2 * math.pi;
  }
}
