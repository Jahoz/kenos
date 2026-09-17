import 'dart:math' as math;

/// The sky has six throats (V3.55).
///
/// Saturation's honest cure, as old as polyphony: a BUDGET of
/// simultaneous voices, the OLDEST throat yields when a younger note
/// asks in (voice stealing — the standard synth mercy), and every
/// voice sings at `1/√n` so the TOTAL POWER stays constant however
/// many notes ring. One note is loud; six are a chord, not a clip.
///
/// Pure arithmetic on end-times: the engine (and the test VM) never
/// needs to exist for the law to be provable.
class VoiceBudget {
  VoiceBudget({this.maxVoices = 6});

  /// Simultaneous voices allowed. Six pentatonic sines is a lush
  /// chord; more is mud — and the sum that clipped.
  final int maxVoices;

  /// Booked end-times (absolute), one per living voice — the caller
  /// keeps them in the same order as its own voice list.
  final List<DateTime> _ends = [];

  /// What admitting one more voice costs and pays.
  /// [steal] indexes (into the caller's CURRENT list, in order) of
  /// the voices that must die NOW — the oldest first, as many as the
  /// budget demands. [gainScale] is `1/√n` for the n voices that will
  /// sing once the steal is done and the new one is in.
  ({List<int> steal, double gainScale}) admit(DateTime now, DateTime endsAt) {
    // The dead are pruned first: a voice whose time is over frees its
    // throat without stealing anything.
    _ends.removeWhere((e) => !e.isAfter(now));

    // The steal: oldest first, only as many as the budget demands.
    final steal = <int>[];
    if (maxVoices > 0) {
      final byAge = [..._ends]..sort();
      while (_ends.length - steal.length >= maxVoices) {
        steal.add(_ends.indexOf(byAge[steal.length]));
      }
    }
    for (final i in steal) {
      _ends[i] = now; // its throat is free from this instant
    }

    _ends.add(endsAt);
    final singing = _ends.where((e) => e.isAfter(now)).length;
    return (
      steal: steal,
      gainScale: 1 / math.sqrt(singing <= 1 ? 1 : singing),
    );
  }
}
