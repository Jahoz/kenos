import '../../../core/utils/parallax_math.dart';

/// Where YOU held a light and it dissolved — a contentless memory of
/// the reading, local to this device (like the sealed star of one's
/// own sends). The content is gone forever; only the place remains:
/// your journey of readings paints the sky, faint scar by faint scar.
class ReadScar {
  const ReadScar({
    required this.echoId,
    required this.worldX,
    required this.worldY,
    required this.readAt,
  });

  final String echoId;
  final double worldX;
  final double worldY;
  final DateTime readAt;

  /// The ether forgets at 30 days; so does the scar.
  double get opacity =>
      ParallaxMath.clamp(1 - _ageInDays / 30, 0, 1) * 0.16;

  double get _ageInDays =>
      DateTime.now().difference(readAt).inMilliseconds / 87.6e6;

  Map<String, dynamic> toJson() => {
        'echoId': echoId,
        'worldX': worldX,
        'worldY': worldY,
        'readAt': readAt.toIso8601String(),
      };

  static ReadScar? fromJson(Map<String, dynamic> json) {
    final readAt = DateTime.tryParse(json['readAt'] as String? ?? '');
    final x = (json['worldX'] as num?)?.toDouble();
    final y = (json['worldY'] as num?)?.toDouble();
    final id = json['echoId'] as String?;
    if (readAt == null || x == null || y == null || id == null) return null;
    return ReadScar(
      echoId: id,
      worldX: x.clamp(0, 1),
      worldY: y.clamp(0, 1),
      readAt: readAt,
    );
  }
}
