import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/heavens/heavens.dart';
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

  // V3.75 — moon-companionship derives from created_at: tests need
  // one timestamp of EACH verdict, found by scanning deterministically.
  DateTime verdictAt(bool moon) {
    var at = DateTime(2026, 9, 1);
    while (KenosSystem.ridesAMoon(at) != moon) {
      at = at.add(const Duration(seconds: 7));
    }
    return at;
  }

  final boundAt = verdictAt(false);
  final moonAt = verdictAt(true);

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

    test('les planètes bougent — visiblement (V3.74 : ~10/16 min le tour)',
        () {
      final before = KenosSystem.planetPosition(0, t0);
      final after = KenosSystem.planetPosition(
        0,
        t0.add(const Duration(minutes: 1)),
      );
      expect(after, isNot(before));
      // In one minute: ~36° of arc — the drift reads ALIVE at the
      // survey ("tout est figé" was the complaint), still no carousel:
      // a full sweep takes ten contemplative minutes.
      final moved = (after - before).distance;
      expect(moved, greaterThan(0.06), reason: 'le ciel doit vivre, VISIBLE');
      expect(moved, lessThan(0.18), reason: 'sans devenir un manège');
    });

    test('V3.75 — l\'âge est une distance : l\'orbite s\'élargit en pâlissant',
        () {
      // THE AGING LAW: a thought's distance from its body IS its age.
      // Born tight (aphelion ~0.03), the orbit widens to the far band
      // (~0.26) at the memory moon — its OWN eccentric ellipse at
      // every instant (radius spans [A(1-e)/(1+e), A]).
      final echo =
          _echo('orbit-test-1', EchoColorTheme.indigo, createdAt: boundAt);
      final e = KenosSystem.liaisonEccentricity(echo);
      for (final (label, at) in [
        ('jeune', boundAt),
        ('à mi-lune', boundAt.add(const Duration(days: 15))),
        ('vieux', boundAt.add(const Duration(days: 31))),
      ]) {
        final A = KenosSystem.orbitAphelion(echo, at);
        for (var i = 0; i < 40; i++) {
          final t = at.add(Duration(seconds: 13 * i));
          final p = KenosSystem.echoPosition(echo, t);
          final planet =
              KenosSystem.planetPosition(KenosSystem.planetIndexOf(echo), t);
          final dist = (p - planet).distance;
          expect(dist, greaterThanOrEqualTo(A * (1 - e) / (1 + e) - 0.01),
              reason: 'périhélie tenu ($label)');
          expect(dist, lessThanOrEqualTo(A + 0.01),
              reason: 'aphélie tenu ($label)');
        }
      }
      // The envelope: near when young, the far band when old.
      expect(KenosSystem.orbitAphelion(echo, boundAt),
          lessThanOrEqualTo(0.075), reason: 'né près de son monde');
      expect(KenosSystem.orbitAphelion(echo, boundAt.add(const Duration(days: 31))),
          greaterThanOrEqualTo(KenosSystem.echoFarBand - 0.005),
          reason: 'la vieille pensée atteint la bande lointaine');
      // And the tempo slows as the orbit widens (Kepler's courtesy).
      expect(
        KenosSystem.orbitPeriod(echo, boundAt.add(const Duration(days: 31)))
            .inSeconds,
        greaterThan(KenosSystem.orbitPeriod(echo, boundAt).inSeconds),
        reason: 'loin = lent',
      );
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

    test('V3.75 — un compagnon gravite SA lune, porté à travers le ciel', () {
      expect(KenosSystem.ridesAMoon(moonAt), isTrue);
      expect(KenosSystem.ridesAMoon(boundAt), isFalse);

      // THE CONSTITUTION: every echo orbits a BODY. A moon-companion
      // rides a TIGHT court around one of the four lunes — whatever
      // the moment, it never strays far from ITS moon (the identity
      // picks which lune, forever).
      final echo =
          _echo('companion-1', EchoColorTheme.indigo, createdAt: moonAt);
      final h = echo.id.hashCode & 0x7fffffff;
      final moonIndex = (h >> 7) % 4;
      for (var i = 0; i < 40; i++) {
        final t = t0.add(Duration(minutes: 3 * i));
        final p = KenosSystem.echoPosition(echo, t);
        final moon = Heavens.wandererPosition(moonIndex, t);
        expect((p - moon).distance, lessThanOrEqualTo(0.13 + 0.01),
            reason: 'la cour du compagnon reste serrée sur sa lune');
      }
    });

    test('un écho naît là où il dérivera — près de SON corps', () {
      for (final (at, moon) in [(boundAt, false), (moonAt, true)]) {
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
          if (!moon) {
            // ...beside its intent planet — the newborn band is tight.
            final dist = (p - planet).distance;
            expect(
              dist,
              lessThanOrEqualTo(0.06),
              reason: 'née au bord de sa planète (près = jeune)',
            );
          } else {
            // ...or beside its moon: the companion is born in court.
            // NB: a lune on her wide arc (r up to 1.05) may stand
            // OUTSIDE the storable square — the birth anchors on her
            // clamped projection (the stored truth), while the render
            // follows her true position (within the fetch's slack).
            final h2 = at.millisecondsSinceEpoch;
            final moon = Heavens.wandererPosition(
              (h2 >> 3) % 4,
              at,
            );
            final anchor = Offset(
              moon.dx.clamp(0.02, 0.98),
              moon.dy.clamp(0.02, 0.98),
            );
            final dist = (p - anchor).distance;
            expect(dist, lessThanOrEqualTo(0.06),
                reason: 'née au bord de sa lune (ancrage stockable)');
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

    test('V3.75 — chaque jour ÉLOIGNE : l\'enveloppe s\'élargit, monotone', () {
      final echo = aged('receding', boundAt);
      // The aging law: the envelope (the sweep's maximum) WIDENS with
      // the days — near is young, far is old.
      double apoAt(int days) {
        var maxR = 0.0;
        for (var i = 0; i < 60; i++) {
          final r = radiusAt(echo, boundAt.add(Duration(
            days: days,
            seconds: 9 * i,
          )));
          if (r > maxR) maxR = r;
        }
        return maxR;
      }

      var previous = apoAt(3);
      for (final days in [6, 10, 16, 22, 26, 29]) {
        final r = apoAt(days);
        expect(r, greaterThan(previous - 1e-4),
            reason: 'l\'éloignement est monotone — l\'âge est une distance');
        previous = r;
      }
      // At the moon's end the far band is reached, never beyond a
      // hair: the thought recedes, it does not escape.
      expect(previous, greaterThanOrEqualTo(KenosSystem.echoFarBand - 0.05));
      expect(previous, lessThanOrEqualTo(
          KenosSystem.echoFarBand + 0.06));
    });

    test('la loi ne connaît pas l\'auteur — même les scellées s\'éloignent', () {
      final born = DateTime(2026, 9, 1);
      final foreign = aged('foreign', born);
      final own = aged('own', born, mine: true);
      final at = born.add(const Duration(days: 20));
      expect(
        KenosSystem.ageFraction(own, at),
        KenosSystem.ageFraction(foreign, at),
        reason: 'la loi ne connaît pas l\'auteur',
      );
      expect(
        KenosSystem.orbitAphelion(own, at),
        greaterThan(KenosSystem.orbitAphelion(own, born)),
        reason: 'même l\'auteur voit sa confidence s\'éloigner de lui',
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


