import 'dart:typed_data';

/// One optional, bounded fragment travelling with an echo.
///
/// Limits are deliberately conservative so the ether remains light enough for
/// a standard upload and no media turns KENOS into a file-sharing service.
enum EchoMediaKind {
  image('IMAGE', 'image/jpeg', 1024 * 1024),
  audio('AUDIO', 'audio/mp4', 512 * 1024);

  const EchoMediaKind(this.wire, this.mimeType, this.maxBytes);

  final String wire;
  final String mimeType;
  final int maxBytes;
}

class EchoMediaDraft {
  const EchoMediaDraft({
    required this.kind,
    required this.bytes,
    required this.name,
  });

  final EchoMediaKind kind;
  final Uint8List bytes;
  final String name;

  bool get isWithinLimit => bytes.lengthInBytes <= kind.maxBytes;

  String get sizeLabel {
    final kib = bytes.lengthInBytes / 1024;
    return '${kib.toStringAsFixed(kib >= 100 ? 0 : 1)} KO';
  }
}

/// Clear media exists only in the winner's reveal window.
class EchoMedia {
  const EchoMedia({required this.kind, required this.bytes});

  final EchoMediaKind kind;
  final Uint8List bytes;
}

/// Result of an atomic interception. Neither value appears on the map.
/// [momentum] is the lineage's rebound count: the reader may re-seal
/// the text as a phoenix carrying momentum + 1.
class ConsumedEcho {
  const ConsumedEcho({required this.text, this.media, this.momentum = 0});

  final String text;
  final EchoMedia? media;
  final int momentum;
}
/// Actual audio container of decrypted bytes: web recordings arrive as
/// webm/opus (EBML magic 0x1A45DFA3), native ones as mp4 (ftyp box at
/// offset 4). Anything unrecognized falls back to the wire kind's mp4.
/// The wire carries a KIND, not a container — mislabelling webm bytes
/// as mp4 makes browsers refuse to play them.
String playbackAudioMime(List<int> bytes) {
  if (bytes.length > 4 &&
      bytes[0] == 0x1A &&
      bytes[1] == 0x45 &&
      bytes[2] == 0xDF &&
      bytes[3] == 0xA3) {
    return 'audio/webm';
  }
  if (bytes.length > 8 &&
      bytes[4] == 0x66 && // f
      bytes[5] == 0x74 && // t
      bytes[6] == 0x79 && // y
      bytes[7] == 0x70) { // p
    return 'audio/mp4';
  }
  return EchoMediaKind.audio.mimeType;
}
