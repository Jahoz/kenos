import 'dart:ui';

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
        expect(dist, closeTo(KenosSystem.planetOrbit, 1e-9));
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

    test('les planètes bougent — lentement (une révolution ~6 h)', () {
      final before = KenosSystem.planetPosition(0, t0);
      final after = KenosSystem.planetPosition(
        0,
        t0.add(const Duration(minutes: 1)),
      );
      expect(after, isNot(before));
      // In one minute: ~1° of arc → a small but real movement.
      final moved = (after - before).distance;
      expect(moved, lessThan(0.02), reason: 'le ciel est éternel, pas pressé');
    });

    test('un écho orbit SA planète d\'intention, dans sa bande', () {
      final echo = _echo('orbit-test-1', EchoColorTheme.indigo);
      final p = KenosSystem.echoPosition(echo, t0);
      final planet =
          KenosSystem.planetPosition(KenosSystem.planetIndexOf(echo), t0);
      final dist = (p - planet).distance;
      expect(dist, greaterThanOrEqualTo(0.045));
      expect(dist, lessThanOrEqualTo(0.045 + 0.075 + 1e-9));
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
