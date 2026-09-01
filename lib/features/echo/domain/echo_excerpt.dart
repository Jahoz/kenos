/// An external cultural excerpt travelling with an echo: a door to
/// somewhere outside the void, not bytes we hold. The author lends
/// another voice to their confidence; only the single winner may open
/// the door, inside their reveal window.
enum EchoExcerptKind {
  song('SONG', 'EXTRAIT MUSICAL'),
  video('EXCERPT', 'EXTRAIT VIDÉO');

  const EchoExcerptKind(this.wire, this.label);

  /// Wire value, shared with `echoes.media_kind`.
  final String wire;

  /// French HUD label (product language).
  final String label;
}

/// One excerpt: a Spotify track or a timestamped YouTube video.
///
/// The compact [ref] is what gets sealed under the echo's ephemeral
/// key — the ether never sees which song or video travelled. The raw
/// string is NEVER launched as a URL: [doorUrl] is built canonically
/// from strictly parsed parts, so a forged reference cannot become an
/// arbitrary link.
class EchoExcerpt {
  const EchoExcerpt({required this.kind, required this.id, this.startSeconds = 0});

  final EchoExcerptKind kind;

  /// 22-char base62 Spotify id, or 11-char YouTube id.
  final String id;

  /// EXCERPT only: where the video excerpt begins.
  final int startSeconds;

  /// Compact wire form, sealed before it ever leaves the device.
  String get ref =>
      kind == EchoExcerptKind.song
          ? 'spotify:track:$id'
          : 'youtube:$id:$startSeconds';

  /// The canonical door, opened OUTSIDE the void (browser or app).
  Uri get doorUrl => switch (kind) {
    EchoExcerptKind.song => Uri.parse('https://open.spotify.com/track/$id'),
    EchoExcerptKind.video => Uri.parse(
      startSeconds > 0
          ? 'https://www.youtube.com/watch?v=$id&t=${startSeconds}s'
          : 'https://www.youtube.com/watch?v=$id',
    ),
  };

  /// Strict parse of the internal wire form (the winner's side). A
  /// malformed reference yields null — the door simply never appears.
  static EchoExcerpt? fromRef(String ref) {
    final song = RegExp(r'^spotify:track:([0-9A-Za-z]{22})$').firstMatch(ref);
    if (song != null) {
      return EchoExcerpt(kind: EchoExcerptKind.song, id: song.group(1)!);
    }
    final video = RegExp(
      r'^youtube:([0-9A-Za-z_-]{11}):([0-9]{1,5})$',
    ).firstMatch(ref);
    if (video != null) {
      final start = int.parse(video.group(2)!);
      if (start > 86400) return null;
      return EchoExcerpt(
        kind: EchoExcerptKind.video,
        id: video.group(1)!,
        startSeconds: start,
      );
    }
    return null;
  }

  /// Lenient parse of what a human pastes into the Mirror: share URLs
  /// (with their tracking tails), URI schemes, `youtu.be` shorts,
  /// `t=1m30s` timestamps. Anything else is not a door: null.
  static EchoExcerpt? parseLink(String input) {
    final link = input.trim();
    if (link.isEmpty) return null;

    final spotifyUrl = RegExp(
      r'^https?://(?:open|play)\.spotify\.com/(?:intl-[a-z-]+/)?track/([0-9A-Za-z]{22})(?![0-9A-Za-z])',
    ).firstMatch(link);
    if (spotifyUrl != null) {
      return EchoExcerpt(kind: EchoExcerptKind.song, id: spotifyUrl.group(1)!);
    }
    final spotifyUri = RegExp(
      r'^spotify:track:([0-9A-Za-z]{22})(?![0-9A-Za-z])',
    ).firstMatch(link);
    if (spotifyUri != null) {
      return EchoExcerpt(kind: EchoExcerptKind.song, id: spotifyUri.group(1)!);
    }

    final youTubeId =
        RegExp(r'^https?://(?:www\.|m\.)?youtu\.be/([0-9A-Za-z_-]{11})(?![0-9A-Za-z_-])')
            .firstMatch(link) ??
        RegExp(
          r'^https?://(?:www\.|m\.)?youtube\.com/watch\?.*\bv=([0-9A-Za-z_-]{11})(?![0-9A-Za-z_-])',
        ).firstMatch(link);
    if (youTubeId != null) {
      final t = RegExp(r'[?&]t=([0-9hms]+)').firstMatch(link);
      return EchoExcerpt(
        kind: EchoExcerptKind.video,
        id: youTubeId.group(1)!,
        startSeconds: _parseTimestamp(t?.group(1)),
      );
    }
    return null;
  }

  /// `t=90`, `t=90s`, `t=1m30s`, `t=1h2m3s` — YouTube's share formats.
  static int _parseTimestamp(String? raw) {
    if (raw == null || raw.isEmpty) return 0;
    if (RegExp(r'^\d+$').hasMatch(raw)) {
      return int.parse(raw).clamp(0, 86400);
    }
    final hms = RegExp(r'^((\d+)h)?((\d+)m)?((\d+)s)?$').firstMatch(raw);
    if (hms == null) return 0;
    final hours = int.tryParse(hms.group(2) ?? '0') ?? 0;
    final minutes = int.tryParse(hms.group(4) ?? '0') ?? 0;
    final seconds = int.tryParse(hms.group(6) ?? '0') ?? 0;
    return (hours * 3600 + minutes * 60 + seconds).clamp(0, 86400);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EchoExcerpt &&
          other.kind == kind &&
          other.id == id &&
          other.startSeconds == startSeconds;

  @override
  int get hashCode => Object.hash(kind, id, startSeconds);
}
