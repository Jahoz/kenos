import '../../../core/utils/parallax_math.dart';
import 'echo_color_theme.dart';
import 'echo_media.dart';

/// An echo: a sealed thought, suspended in the ether.
///
/// [text] is never present on the map (metadata only);
/// it exists only at revelation time, after atomic consumption.
class Echo {
  const Echo({
    required this.id,
    required this.coordX,
    required this.coordY,
    required this.coordZ,
    required this.theme,
    required this.createdAt,
    this.text,
    this.media,
    this.mediaKind,
    this.isMine = false,
    this.momentum = 0,
    this.parentId,
  });

  final String id;

  /// Normalized X position (0..1 — fraction of the screen).
  final double coordX;

  /// Normalized Y position (0..1).
  final double coordY;

  /// Launch depth (0.05..1) — one's own echoes are born at 1.
  final double coordZ;

  final EchoColorTheme theme;
  final DateTime createdAt;

  /// Clear text — only after a successful interception.
  final String? text;

  /// Clear media is present only after a winning atomic consumption.
  final EchoMedia? media;

  /// Map-safe metadata: there is a sealed fragment, never its path or bytes.
  final EchoMediaKind? mediaKind;

  /// The local user's echo: sealed, untouchable, drifting.
  final bool isMine;

  /// Rebound count of the lineage (public metadata, never content):
  /// how many humans carried this thought before it reached you.
  /// momentum > 0 draws a comet tail on the map.
  final int momentum;

  /// The echo this one was rebounded from (lineage link, metadata):
  /// lets the map draw the constellation of a thought's journey.
  final String? parentId;

  /// Rendered depth: one's own echoes slowly drift toward the background.
  double resolveZ(DateTime now) =>
      isMine ? ParallaxMath.driftZ(sentAt: createdAt, now: now) : coordZ;

  Echo copyWith({
    String? text,
    EchoMedia? media,
    EchoColorTheme? theme,
    int? momentum,
  }) => Echo(
    id: id,
    coordX: coordX,
    coordY: coordY,
    coordZ: coordZ,
    theme: theme ?? this.theme,
    createdAt: createdAt,
    text: text ?? this.text,
    media: media ?? this.media,
    mediaKind: mediaKind,
    isMine: isMine,
    momentum: momentum ?? this.momentum,
  );

  factory Echo.fromJson(Map<String, dynamic> json, {bool isMine = false}) =>
      Echo(
        id: json['id'] as String,
        coordX: (json['coord_x'] as num).toDouble(),
        coordY: (json['coord_y'] as num).toDouble(),
        coordZ: (json['coord_z'] as num).toDouble(),
        theme: EchoColorTheme.fromWire(json['color_theme'] as String?),
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        mediaKind: switch (json['media_kind'] as String?) {
          'IMAGE' => EchoMediaKind.image,
          'AUDIO' => EchoMediaKind.audio,
          _ => null,
        },
        isMine: isMine,
      );

  /// Local serialization of sealed echoes — deliberately WITHOUT the text:
  /// once launched, even its author cannot read it again.
  Map<String, dynamic> toJson() => {
    'id': id,
    'coord_x': coordX,
    'coord_y': coordY,
    'coord_z': coordZ,
    'color_theme': theme.wire,
    'created_at': createdAt.toIso8601String(),
    if (mediaKind != null) 'media_kind': mediaKind!.wire,
  };
}
