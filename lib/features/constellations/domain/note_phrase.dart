import 'dart:convert';

import '../../frequencies/domain/kenos_wave.dart';

/// One line of a constellation-SONG: a short sequence of indices into
/// the public pentatonic scale (the waves' instrument), each held for
/// its own duration — THE RHYTHM AS THE STRANGER PLAYED IT. Wordless
/// by construction: anonymous as the waves, tiny as a few integers,
/// synthesized on-device, never an audio byte in the ether.
///
/// The phrase travels as the line's sealed payload (a compact JSON);
/// [tryParse] returns null for poem lines (plain text), so readers
/// can tell a song from a poem without any metadata.
class NotePhrase {
  const NotePhrase(this.notes, [this.holdsRaw = const []]);

  /// 1..8 indices, each 0..19 into the pentatonic scale.
  final List<int> notes;

  /// How long each note was HELD before the next tap (ms) — the
  /// rhythm, recorded live by the composer's own fingers. May be
  /// missing/short/invalid (legacy or hand-made payloads): [holds]
  /// always returns a sane, bounded value per note.
  final List<int> holdsRaw;

  static const int maxNotes = 8;

  /// A note is held at least a flutter, at most a breath — whatever
  /// the payload says, playback can never stall on silence.
  static const int minHoldMs = 120;
  static const int maxHoldMs = 4000;
  static const int defaultHoldMs = 1400;

  List<int> get holds => [
        for (var i = 0; i < notes.length; i++)
          (i < holdsRaw.length ? holdsRaw[i] : defaultHoldMs)
              .clamp(minHoldMs, maxHoldMs),
      ];

  bool get isValid =>
      notes.isNotEmpty && notes.length <= maxNotes &&
      notes.every((n) => n >= 0 && n < WaveMath.noteCount);

  /// The sealed payload: as small as the thought, rhythm included.
  String encode() => jsonEncode({'n': notes, 'd': holds});

  /// Total playback span (a small tail for the last swell to exhale).
  Duration get playbackSpan => Duration(
        milliseconds: 500 + holds.fold(0, (a, b) => a + b),
      );

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
      final durations = decoded['d'];
      final holds = durations is List
          ? [
              for (final d in durations)
                if (d is num) d.toInt() else -1,
            ]
          : const <int>[];
      final phrase = NotePhrase(
        [
          for (final n in notes)
            if (n is num) n.toInt() else -1,
        ],
        holds,
      );
      return phrase.isValid ? phrase : null;
    } catch (_) {
      return null;
    }
  }
}
