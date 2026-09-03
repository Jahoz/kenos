import 'dart:convert';

import '../../frequencies/domain/kenos_wave.dart';

/// One line of a constellation-SONG: a short sequence of indices into
/// the public pentatonic scale (the waves' instrument). Wordless by
/// construction — anonymous as the waves, tiny as a few integers,
/// synthesized on-device, never an audio byte in the ether.
///
/// The phrase travels as the line's sealed payload (a compact JSON);
/// [tryParse] returns null for poem lines (plain text), so readers
/// can tell a song from a poem without any metadata.
class NotePhrase {
  const NotePhrase(this.notes);

  /// 1..8 indices, each 0..19 into the pentatonic scale.
  final List<int> notes;

  static const int maxNotes = 8;

  bool get isValid =>
      notes.isNotEmpty && notes.length <= maxNotes &&
      notes.every((n) => n >= 0 && n < WaveMath.noteCount);

  /// The sealed payload: as small as the thought.
  String encode() => jsonEncode({'n': notes});

  /// Parses a line's opened payload as a phrase; null when the line
  /// is a poem's text (or the payload is malformed — it then reads
  /// as silence, never an error).
  static NotePhrase? tryParse(String raw) {
    if (!raw.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final notes = decoded['n'];
      if (notes is! List) return null;
      final phrase = NotePhrase([
        for (final n in notes)
          if (n is num) n.toInt() else -1,
      ]);
      return phrase.isValid ? phrase : null;
    } catch (_) {
      return null;
    }
  }

  /// Plays the phrase through the spatial engine (pan sweeping the
  /// stereo field with the phrase's own progression), falling back
  /// to the baked assets. Fire-and-forget: the song never blocks.
  Duration get playbackSpan =>
      Duration(milliseconds: 500 + notes.length * phraseNoteSpacingMs);

  /// Spacing between a phrase's notes: the swells overlap into one
  /// breath (the wave envelope is 6 s long — a phrase is a wash,
  /// not a scale run).
  static const int phraseNoteSpacingMs = 1400;
}
