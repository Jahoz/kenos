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
class ConsumedEcho {
  const ConsumedEcho({required this.text, this.media});

  final String text;
  final EchoMedia? media;
}