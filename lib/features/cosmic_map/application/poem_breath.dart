import 'dart:ui';

import '../../../core/utils/parallax_math.dart';
import '../../constellations/data/constellation_repository.dart';
import '../data/artifact_memory.dart';

/// V3.45 — the poem's breath: when a corpse THESE HANDS helped write
/// has closed and not yet been read, it takes the sky's breath — the
/// HUD souffle points at it, so the participant can FIND their own
/// artifact in the immensity (the ember orbit identifies it once
/// there; until then, the way is told).
///
/// Pure: every input is a value, every device agrees.
class PoemBreath {
  PoemBreath._();

  /// The closed-and-mine-and-unread corpse nearest the eye, or null.
  static ConstellationMeta? waitingPoem(
    List<ConstellationMeta> constellations,
    ArtifactMemory memory,
    Offset eye,
  ) {
    ConstellationMeta? nearest;
    var best = double.infinity;
    for (final cst in constellations) {
      if (!cst.isClosed) continue;
      if (!memory.contributedTo(cst.id)) continue;
      if (memory.isRead(cst.id) || memory.isKept(cst.id)) continue;
      final d = (Offset(cst.seedX, cst.seedY) - eye).distance;
      if (d < best) {
        best = d;
        nearest = cst;
      }
    }
    return nearest;
  }

  /// The souffle line for a waiting poem, or null when none waits.
  /// 'UN POÈME DE TA MAIN S'EST REFERMÉ — SOUFFLE VERS 3 H': the
  /// ember orbit is the referent the traveller will recognise on
  /// arrival.
  static String? line(
    List<ConstellationMeta> constellations,
    ArtifactMemory memory,
    Offset eye,
  ) {
    final poem = waitingPoem(constellations, memory, eye);
    if (poem == null) return null;
    final h = ParallaxMath.clockDirection(
      Offset(poem.seedX, poem.seedY) - eye,
    );
    return "UN POÈME DE TA MAIN S'EST REFERMÉ — SOUFFLE VERS $h H";
  }
}
