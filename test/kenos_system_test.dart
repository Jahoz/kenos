import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/application/kenos_system.dart';
import 'package:kenos/features/echo/domain/echo.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';

Echo _echo(String id, EchoColorTheme theme, {DateTime? createdAt}) => Echo(
      id: id,
      coordX: 0.5,
      coordY: 0.5,
      coordZ: 0.5,
      theme: theme,
      createdAt: createdAt ?? DateTime(2026, 9, 1),
    );

void main() {
  final t0 = DateTime(2026, 9, 1, 12);

  // V3.67 — errance derives from created_at: tests need one
  // timestamp of EACH verdict, found by scanning deterministically.
  DateTime verdictAt(bool errant) {
    var at = DateTime(2026, 9, 1);
    while (KenosSystem.isErrantThought(at) != errant) {
      at = at.add(const Duration(seconds: 7));
    }
    return at;
  }

  final boundAt = verdictAt(false);
  final errantAt = verdictAt(true);

  group('KenosSystem — le ciel est déterministe', () {
    test('les trois planètes orbitent le trou noir à la bonne distance',
        () {
      for (var i = 0; i < KenosSystem.planets.length; i++) {
        final p = KenosSystem.planetPosition(i, t0);
        final dist = (p - KenosSystem.blackHole).distance;
        // V3.12: each anchor rides its OWN lane — Polaris (i=2) holds
        // still at its fixed distance; the two others at their own.
        // V3.21: the beacon holds the north corner, clear of every
        // orbiting lane (no more conjunctions through her sky).
        if (i == 2) {
          expect(dist, closeTo(0.523259, 1e-5), reason: 'Polaris ne bouge pas');
          // V3.67: Venus's lane widened to 0.44 — the beacon keeps a
          // clear (if closer) sky: no conjunction touches her.
          expect(dist - KenosSystem.orbitRadiusOf(1),
              greaterThan(0.08), reason: 'hors de la voie de Vénus');
        } else {
          expect(dist, closeTo(KenosSystem.orbitRadiusOf(i), 1e-9),
              reason: 'chaque monde a sa propre piste');
        }
      }
    });

    test('les trois intentions occupent trois gravités distinctes', () {
      final positions = [
        for (var i = 0; i < KenosSystem.planets.length; i++)
          KenosSystem.planetPosition(i, t0),
      ];
      for (var a = 0; a < positions.length; a++) {
        for (var b = a + 1; b < positions.length; b++) {
          expect(positions[a], isNot(positions[b]));
        }
      }
    });

    test('les planètes bougent — visiblement (une révolution ~40 min)', () {
      final before = KenosSystem.planetPosition(0, t0);
      final after = KenosSystem.planetPosition(
        0,
        t0.add(const Duration(minutes: 1)),
      );
      expect(after, isNot(before));
      // In one minute: ~9° of arc — the drift is perceptible if you
      // linger (eternal is not motionless).
      final moved = (after - before).distance;
      expect(moved, greaterThan(0.03), reason: 'le ciel doit vivre');
      expect(moved, lessThan(0.12), reason: 'sans tourner la tête');
    });

    test('un écho lié orbit SA planète dans sa bande élargie (ellipse propre)', () {
      final echo =
          _echo('orbit-test-1', EchoColorTheme.indigo, createdAt: boundAt);
      final e = KenosSystem.liaisonEccentricity(echo);
      final A = KenosSystem.liaisonAphelion(echo);
      // V3.67: each bound echo rides its OWN eccentric ellipse —
      // aphelion-bounded: the radius spans [A(1-e)/(1+e), A]. The
      // crowd reads as a wide halo, never a drawn ring.
      for (var i = 0; i < 40; i++) {
        final p = KenosSystem.echoPosition(echo, t0.add(Duration(seconds: 13 * i)));
        final planet =
            KenosSystem.planetPosition(KenosSystem.planetIndexOf(echo), t0.add(Duration(seconds: 13 * i)));
        final dist = (p - planet).distance;
        expect(dist, greaterThanOrEqualTo(A * (1 - e) / (1 + e) - 0.01));
        expect(dist, lessThanOrEqualTo(A + 0.01));
      }
      // The whole population stays inside the widened band.
      expect(A, lessThanOrEqualTo(
          KenosSystem.echoShells.last + KenosSystem.liaisonJitter + 1e-9));
      expect(A, greaterThanOrEqualTo(KenosSystem.echoShells.first - 1e-9));
    });

    test('V3.67 — même coque, tempos différents : la foule se dé-synchronise', () {
      // Two echoes born at the same bound moment no longer turn in
      // unison (per-echo period jitter + eccentricity) — the
      // synchronized ring-read was the complaint; the halo must read
      // as a crowd.
      final a = _echo('desync-a', EchoColorTheme.teal, createdAt: boundAt);
      final b = _echo('desync-b', EchoColorTheme.teal, createdAt: boundAt);
      final t1 = t0.add(const Duration(minutes: 5));
      final d0 =
          (KenosSystem.echoPosition(a, t0) - KenosSystem.echoPosition(b, t0))
              .distance;
      final d1 =
          (KenosSystem.echoPosition(a, t1) - KenosSystem.echoPosition(b, t1))
              .distance;
      // Same pair, two instants: their separation CHANGES — no unison.
      expect((d1 - d0).abs(), greaterThan(1e-6),
          reason: 'deux inconnus ne tournent pas du même pas');
    });

    test('V3.67 — la pensée errante vit autour du VIDE, pas des planètes', () {
      expect(KenosSystem.isErrantThought(errantAt), isTrue);
      expect(KenosSystem.isErrantThought(boundAt), isFalse);

      // An errant launch lands in the MEDIAN crowd (V3.70: crowded
      // toward the system's skirts, thinning into the deep field,
      // capped by the square's true edge — the ring breathes to the
      // corners), never in a gravity band by design.
      final rng = Random(11);
      for (var i = 0; i < 30; i++) {
        final p = KenosSystem.launchCoordsFor(
          EchoColorTheme.teal,
          errantAt,
          rng,
        );
        final fromCenter = (p - KenosSystem.blackHole).distance;
        expect(fromCenter, greaterThanOrEqualTo(0.33),
            reason: 'jamais dans l\'escorte du système');
        expect(fromCenter, lessThanOrEqualTo(0.70),
            reason: 'la foule vit au médian, pas sur les murs');
      }

      // A bound launch still falls inside its planet's gravity band.
      final planet = KenosSystem.planetPosition(0, boundAt);
      for (var i = 0; i < 30; i++) {
        final p = KenosSystem.launchCoordsFor(
          EchoColorTheme.teal,
          boundAt,
          Random(13),
        );
        final dist = (p - planet).distance;
        expect(
          dist,
          lessThanOrEqualTo(
            KenosSystem.echoBandMin + KenosSystem.echoBandSpan + 1e-9,
          ),
          reason: 'née dans la bande de gravité de sa planète',
        );
      }

      // The errant RENDER rides a ring around the void: constant
      // distance from the centre, whatever the moment.
      final errant =
          _echo('errant-1', EchoColorTheme.indigo, createdAt: errantAt);
      final e1 = KenosSystem.echoPosition(errant, t0);
      final e2 = KenosSystem.echoPosition(errant, t0.add(
        const Duration(minutes: 3),
      ));
      final r1 = (e1 - KenosSystem.blackHole).distance;
      final r2 = (e2 - KenosSystem.blackHole).distance;
      expect(r1, closeTo(r2, 1e-9), reason: 'un anneau, un rayon');
    });

    test('un écho naît là où il dérivera (liée en bande, errante sur l\'anneau)', () {
      for (final (at, errant) in [(boundAt, false), (errantAt, true)]) {
        final planet = KenosSystem.planetPosition(0, at);
        for (var i = 0; i < 40; i++) {
          final p = KenosSystem.launchCoordsFor(
            EchoColorTheme.teal,
            at,
            Random(7 + i),
          );
          // Inside the known ether, always.
          expect(p.dx, inInclusiveRange(0.02, 0.98));
          expect(p.dy, inInclusiveRange(0.02, 0.98));
          if (!errant) {
            // ...in its intent planet's gravity band (a hair of clamp
            // slack at the sky's very edge).
            final dist = (p - planet).distance;
            expect(
              dist,
              lessThanOrEqualTo(
                KenosSystem.echoBandMin + KenosSystem.echoBandSpan + 1e-9,
              ),
              reason: 'née dans la bande de gravité de sa planète',
            );
          } else {
            // ...or on its wide ring around the void (V3.67/68).
            final fromCenter = (p - KenosSystem.blackHole).distance;
            expect(fromCenter, greaterThanOrEqualTo(0.27));
            expect(fromCenter, lessThanOrEqualTo(0.93));
          }
        }
      }
      // Determinism with a seeded hand.
      final a = KenosSystem.launchCoordsFor(
        EchoColorTheme.teal,
        boundAt,
        Random(42),
      );
      final b = KenosSystem.launchCoordsFor(
        EchoColorTheme.teal,
        boundAt,
        Random(42),
      );
      expect(a, b);
    });

    test('déterminisme : même écho, même instant → même ciel partout', () {
      final echo = _echo('determinism', EchoColorTheme.teal);
      final a = KenosSystem.echoPosition(echo, t0);
      final b = KenosSystem.echoPosition(echo, t0);
      expect(a, b, reason: 'deux appareils voient le même ciel sans sync');
    });

    test('le rebond hérite de la gravité : comète de la même intention', () {
      final parent = _echo('parent-x', EchoColorTheme.lumen);
      final child = _echo('child-y', EchoColorTheme.lumen);
      expect(
        KenosSystem.planetIndexOf(parent),
        KenosSystem.planetIndexOf(child),
        reason: "le phénix garde l'orbite de sa lignée",
      );
    });

    test('comète : momentum > 0 quitte la gravité de sa planète', () {
      final comet = _echo('comet-1', EchoColorTheme.teal)
          .copyWith(momentum: 2);
      // Repeated sampling over a full sweep: the comet's distance to
      // the void varies WILDLY (eccentric) — it crosses the planets'
      // orbit band and dives near the centre.
      var minD = 1.0;
      var maxD = 0.0;
      for (var i = 0; i < 240; i++) {
        final p = KenosSystem.echoPosition(
          comet,
          t0.add(Duration(minutes: 10 * i)),
        );
        final d = (p - KenosSystem.blackHole).distance;
        if (d < minD) minD = d;
        if (d > maxD) maxD = d;
      }
      expect(maxD, greaterThan(KenosSystem.outerOrbit),
          reason: 'l\'aphélie dépasse les planètes');
      expect(minD, lessThan(0.20),
          reason: 'le périhélie frôle le vide');
      expect(maxD - minD, greaterThan(0.15),
          reason: 'l\'arc est réellement excentrique');
    });

    test('comète : déterministe (même ciel partout)', () {
      final comet = _echo('comet-det', EchoColorTheme.indigo)
          .copyWith(momentum: 1);
      expect(
        KenosSystem.echoPosition(comet, t0),
        KenosSystem.echoPosition(comet, t0),
      );
    });

    test('lignage : les maillons de la chaîne dessinent leurs segments', () {
      final parent = _echo('line-parent', EchoColorTheme.lumen);
      final child = Echo(
        id: 'line-child',
        coordX: 0.6,
        coordY: 0.6,
        coordZ: 0.5,
        theme: EchoColorTheme.lumen,
        createdAt: t0,
        momentum: 1,
        parentId: 'line-parent',
      );
      final segments =
          KenosSystem.lineageSegments([parent, child], t0);
      expect(segments, hasLength(1));
      final (from, to, theme) = segments.single;
      expect(theme, EchoColorTheme.lumen);
      expect(from, isNot(to), reason: 'le segment relie deux points');

      // A consumed parent (absent from the sky) still anchors the
      // constellation: the phantom is the child's launch point.
      final orphan =
          KenosSystem.lineageSegments([child], t0);
      expect(orphan, hasLength(1));
      expect(orphan.single.$1, const Offset(0.6, 0.6));
    });

    test('les orbites restent dans l\'éther traversable', () {
      final echo =
          _echo('bounds-check', EchoColorTheme.teal, createdAt: boundAt);
      // V3.67/68: eccentric aphelia and errant rings (to 0.95 of the
      // sky) let a mote drift past the known rim [0,1] — within the
      // traversable margin (V3.40) — but never fly off it.
      for (final delta in [
        Duration.zero,
        const Duration(hours: 3),
        const Duration(days: 2),
      ]) {
        final p = KenosSystem.echoPosition(echo, t0.add(delta));
        expect(p.dx, inInclusiveRange(-0.5, 1.5));
        expect(p.dy, inInclusiveRange(-0.5, 1.5));
      }
    });
  });

  group('V3.36 — la chute des jours', () {
    // Echo.copyWith is deliberately narrow (sealed content only) —
    // the fall is pinned through direct construction.
    Echo aged(String id, DateTime born,
            {bool mine = false, int momentum = 0}) =>
        Echo(
          id: id,
          coordX: 0.5,
          coordY: 0.5,
          coordZ: 0.5,
          theme: EchoColorTheme.teal,
          createdAt: born,
          isMine: mine,
          momentum: momentum,
        );

    double radiusAt(Echo echo, DateTime at) =>
        (KenosSystem.echoPosition(echo, at) -
                KenosSystem.planetPosition(
                  KenosSystem.planetIndexOf(echo),
                  at,
                ))
            .distance;

    test('la grâce : une pensée fraîche reste dans SA coque, exactement',
        () {
      final echo = aged('grace', boundAt);
      final e = KenosSystem.liaisonEccentricity(echo);
      final A = KenosSystem.liaisonAphelion(echo);
      // 47 h adrift: still in its lane, untouched — the sky it was
      // launched into is the sky it keeps (its OWN ellipse: the
      // radius sweeps [A(1-e)/(1+e), A], never beyond).
      final at = boundAt.add(const Duration(hours: 47));
      expect(KenosSystem.fallFraction(echo, at), 0.0);
      var minR = 1.0;
      var maxR = 0.0;
      for (var i = 0; i < 60; i++) {
        final r = radiusAt(echo, at.add(Duration(seconds: 9 * i)));
        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
      }
      expect(maxR, lessThanOrEqualTo(A + 0.01));
      expect(minR, greaterThanOrEqualTo(A * (1 - e) / (1 + e) - 0.01));
    });

    test('la chute : chaque jour resserre l\'ellipse vers son monde', () {
      final echo = aged('falling', boundAt);
      // The perihelion (the sweep's minimum) shrinks as the aphelion
      // falls — age tightens the embrace, monotone in its envelope.
      double periAt(int days) {
        var minR = 1.0;
        for (var i = 0; i < 60; i++) {
          final r = radiusAt(echo, boundAt.add(Duration(
            days: days,
            seconds: 9 * i,
          )));
          if (r < minR) minR = r;
        }
        return minR;
      }

      var previous = periAt(3);
      for (final days in [6, 10, 16, 22, 26, 29]) {
        final r = periAt(days);
        expect(r, lessThan(previous - 1e-4),
            reason: 'la chute est monotone — l\'âge est une distance');
        previous = r;
      }
      // Still a mote, never a ghost ON the world: the landing keeps
      // its hair of sky.
      expect(previous, greaterThan(KenosSystem.landingRadius *
              (1 - KenosSystem.liaisonEccentricityMax) /
              (1 + KenosSystem.liaisonEccentricityMax) -
          0.01));
    });

    test('la lune pleine : la pensée se pose au bord de son monde', () {
      final echo = aged('landed', boundAt);
      final e = KenosSystem.liaisonEccentricity(echo);
      final at = boundAt.add(const Duration(days: 31));
      expect(KenosSystem.fallFraction(echo, at), 1.0);
      // At the landing the APHELION itself is the world's rim: the
      // ellipse has collapsed to [landing(1-e)/(1+e), landing].
      var minR = 1.0;
      var maxR = 0.0;
      for (var i = 0; i < 60; i++) {
        final r = radiusAt(echo, at.add(Duration(seconds: 9 * i)));
        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
      }
      expect(maxR, lessThanOrEqualTo(
          KenosSystem.landingRadius + 0.01));
      expect(minR, greaterThanOrEqualTo(
          KenosSystem.landingRadius * (1 - e) / (1 + e) - 0.01));
    });

    test('les scellées tombent aussi — même l\'auteur voit la fin venir',
        () {
      final born = DateTime(2026, 9, 1);
      final foreign = aged('foreign', born);
      final own = aged('own', born, mine: true);
      final at = born.add(const Duration(days: 20));
      expect(
        KenosSystem.fallFraction(own, at),
        KenosSystem.fallFraction(foreign, at),
        reason: 'la loi ne connaît pas l\'auteur',
      );
      expect(
        radiusAt(own, at),
        lessThan(radiusAt(own, born)),
        reason: 'même l\'auteur voit sa confidence approcher du monde',
      );
    });

    test('les comètes ne tombent pas : elles traversent, même vieillies',
        () {
      final born = DateTime(2026, 9, 1);
      final comet = aged('old-comet', born, momentum: 2);
      // 29 days adrift: still an eccentric crossing, not a fall.
      var maxD = 0.0;
      for (var i = 0; i < 240; i++) {
        final p = KenosSystem.echoPosition(
          comet,
          born.add(Duration(minutes: 10 * i)),
        );
        final d = (p - KenosSystem.blackHole).distance;
        if (d > maxD) maxD = d;
      }
      expect(maxD, greaterThan(KenosSystem.outerOrbit),
          reason: 'la comète meurt à sa manière — en traversant');
    });
  });
}


