import 'dart:ui';

/// V3.35 — the landscapes of the void: three territories told by
/// radius from the heart, named on the CARTE DU CIEL's own map (the
/// far country) and whispered once per session when the eye crosses.
/// Distance becomes places, not just emptiness: the throat that
/// swallows, the gardens where thoughts gravitate, the far country
/// where the wanderers drift.
enum VoidTerritory { throat, gardens, farCountry }

class VoidTerritories {
  VoidTerritories._();

  /// The heart the radii are drawn from — the black hole's position.
  static const Offset heart = Offset(0.5, 0.5);

  /// The throat reaches just past the resting exclusion (0.15): the
  /// hole's own neighbourhood, where comets graze and nothing rests.
  static const double throatEdge = 0.19;

  /// The far country begins clear of Venus's swarm rim (0.515) and of
  /// Polaris's corner (0.523 — she watches the system, she is not of
  /// the far country), with the wanderers (0.55–0.65) inside it.
  static const double farEdge = 0.54;

  static VoidTerritory territoryAt(Offset eye) {
    final r = (eye - heart).distance;
    if (r < throatEdge) return VoidTerritory.throat;
    if (r < farEdge) return VoidTerritory.gardens;
    return VoidTerritory.farCountry;
  }

  /// The HUD's quiet label — short, always told, never a surprise.
  static String hudLabel(VoidTerritory t) => switch (t) {
        VoidTerritory.throat => 'LE GOUFFRE',
        VoidTerritory.gardens => 'LES JARDINS',
        VoidTerritory.farCountry => 'LE PAYS LOINTAIN',
      };

  /// The crossing whisper's title (machine voice, mono caps).
  static String whisperTitle(VoidTerritory t) => switch (t) {
        VoidTerritory.throat => 'LE GOUFFRE',
        VoidTerritory.gardens => 'LES JARDINS DE L\'INTENTION',
        VoidTerritory.farCountry => 'LE PAYS LOINTAIN',
      };

  /// The crossing whisper's breath (the serif voice, lowercase —
  /// the sky's own grammar, like the eye whisper before it).
  static String whisperLine(VoidTerritory t) => switch (t) {
        VoidTerritory.throat => 'Ce qui franchit l\'horizon ne revient pas.',
        VoidTerritory.gardens =>
          'Les pensées gravitent autour de ce qu\'on leur confie.',
        VoidTerritory.farCountry =>
          'Ici dérivent les errants — et le vide est plus vaste.',
      };

  /// The drone's depth by radius: fullest among the gardens — the
  /// sound of thought in orbit — thinning toward the throat (the void
  /// drinks its own sound) and across the far country (thin air). A
  /// pure curve: the audio controller stays dumb, the law lives here.
  static const List<(double, double)> _depthCurve = [
    (0.00, 0.50),
    (0.19, 0.85),
    (0.36, 1.00),
    (0.54, 1.00),
    (0.70, 0.60),
    (1.20, 0.60),
  ];

  static double droneFactor(double radius) {
    final r = radius.clamp(0.0, 1.2);
    for (var i = 1; i < _depthCurve.length; i++) {
      final (r1, v1) = _depthCurve[i];
      final (r0, v0) = _depthCurve[i - 1];
      if (r <= r1) {
        final t = (r - r0) / (r1 - r0);
        return v0 + (v1 - v0) * t;
      }
    }
    return _depthCurve.last.$2;
  }
}
