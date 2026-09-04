import 'dart:math' as math;
import 'dart:ui';

import '../../echo/domain/echo_color_theme.dart';

/// V3.12 — the named heavens: every anchor and wanderer carries a name,
/// a nature and one poetic truth. Anchors hold the three intentions
/// (they own the echo orbits); wanderers are the ether's open
/// questions — nothing orbits them, yet.
enum CelestialKind { anchor, moon, dwarf, beacon }

class CelestialBody {
  const CelestialBody({
    required this.name,
    required this.kind,
    required this.kindLabel,
    required this.poem,
    this.theme,
    this.intention,
  });

  final String name;
  final CelestialKind kind;
  final String kindLabel;
  final String poem;

  /// Anchors only: the intention whose echoes orbit this body.
  final EchoColorTheme? theme;
  final String? intention;

  bool get isAnchor => kind == CelestialKind.anchor;
}

/// The named system. Anchor order matches [KenosSystem.planets]:
/// index 0 = APAISER, 1 = CONFIER, 2 = ÉCLAIRER.
const List<CelestialBody> celestialBodies = [
  CelestialBody(
    name: 'La Lune',
    kind: CelestialKind.anchor,
    kindLabel: 'SATELLITE DE LA TERRE',
    poem: 'On lui confie ce qui doit descendre :\n'
        'la marée, la nuit, le recommencement.',
    theme: EchoColorTheme.teal,
    intention: 'APAISER',
  ),
  CelestialBody(
    name: 'Vénus',
    kind: CelestialKind.anchor,
    kindLabel: 'PLANÈTE — L\'ÉTOILE DU BERGER',
    poem: 'L\'amour, à voix basse :\nce qu\'on ose enfin confier.',
    theme: EchoColorTheme.indigo,
    intention: 'CONFIER',
  ),
  CelestialBody(
    name: 'Polaris',
    kind: CelestialKind.beacon,
    kindLabel: 'ÉTOILE FIXE',
    poem: 'Le point qui ne bouge pas quand tout tourne :\n'
        'la clarté, le cap.',
    theme: EchoColorTheme.lumen,
    intention: 'ÉCLAIRER',
  ),
];

/// The wanderers: named bodies on far slow arcs, found by travelling.
/// Nothing orbits them — they are the ether's open categories, waiting.
const List<CelestialBody> celestialWanderers = [
  CelestialBody(
    name: 'Pluton',
    kind: CelestialKind.dwarf,
    kindLabel: 'PLANÈTE NAINE',
    poem: 'Déclassée mais toujours là :\n'
        'la petite voix qu\'aucune liste ne retient.',
  ),
  CelestialBody(
    name: 'Triton',
    kind: CelestialKind.moon,
    kindLabel: 'SATELLITE DE NEPTUNE',
    poem: 'Elle orbite à l\'envers :\nl\'exil qui remonte à contre-courant.',
  ),
  CelestialBody(
    name: 'Europe',
    kind: CelestialKind.moon,
    kindLabel: 'SATELLITE DE JUPITER',
    poem: 'Un océan tiède sous la glace :\nce qui dort en toi, intact.',
  ),
  CelestialBody(
    name: 'Titan',
    kind: CelestialKind.moon,
    kindLabel: 'SATELLITE DE SATURNE',
    poem: 'Une brume épaisse et dorée :\nce qu\'on pressent sans le voir encore.',
  ),
];

/// Pure math of the named heavens — deterministic like everything here.
class CelestialMath {
  CelestialMath._();

  /// Polaris does not orbit: the fixed point, top of the void.
  static const Offset polaris = Offset(0.5, 0.5 - 0.32);

  /// A wanderer's world position: far slow arcs beyond every orbit,
  /// found only by travelling. Each drifts at its own imperceptible
  /// pace; every device agrees on where they are.
  static Offset wandererPosition(int index, DateTime at) {
    final i = index % celestialWanderers.length;
    final radius = 0.62 + 0.06 * (i % 3);
    final periodMs = (6 + 2 * i) * 3600000.0;
    final base = i * math.pi / 2;
    final angle =
        base + 2 * math.pi * at.millisecondsSinceEpoch / periodMs;
    return Offset(
      0.5 + radius * math.cos(angle),
      0.5 + radius * math.sin(angle),
    );
  }
}
