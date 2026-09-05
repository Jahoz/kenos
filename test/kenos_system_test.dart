import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/application/kenos_system.dart';
import 'package:kenos/features/echo/domain/echo.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';

Echo _echo(String id, EchoColorTheme theme) => Echo(
      id: id,
      coordX: 0.5,
      coordY: 0.5,
      coordZ: 0.5,
      theme: theme,
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  final t0 = DateTime(2026, 9, 1, 12);

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
          expect(dist - KenosSystem.orbitRadiusOf(1),
              greaterThan(0.15), reason: 'hors de la voie de Vénus');
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

    test('un écho orbit SA planète d\'intention, dans sa bande', () {
      final echo = _echo('orbit-test-1', EchoColorTheme.indigo);
      final p = KenosSystem.echoPosition(echo, t0);
      final planet =
          KenosSystem.planetPosition(KenosSystem.planetIndexOf(echo), t0);
      final dist = (p - planet).distance;
      // V3.23: the band widens (0.075 → 0.145) — stacked neighbours
      // were blanketing each other's catch zones at the old width.
      expect(dist, greaterThanOrEqualTo(KenosSystem.echoBandMin - 1e-9));
      expect(
        dist,
        lessThanOrEqualTo(
          KenosSystem.echoBandMin + KenosSystem.echoBandSpan + 1e-9,
        ),
      );
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

    test('les orbites restent dans l\'éther connu [0,1]', () {
      final echo = _echo('bounds-check', EchoColorTheme.teal);
      for (final delta in [
        Duration.zero,
        const Duration(hours: 3),
        const Duration(days: 2),
      ]) {
        final p = KenosSystem.echoPosition(echo, t0.add(delta));
        expect(p.dx, inInclusiveRange(0, 1));
        expect(p.dy, inInclusiveRange(0, 1));
      }
    });
  });
}


