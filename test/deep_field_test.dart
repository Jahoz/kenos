import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/application/deep_field.dart';
import 'package:kenos/features/cosmic_map/application/travel_camera.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/deep_field_painter.dart';

/// V3.34 — the deep field: far dust riding slower layers than the
/// world, so the pan reads as a passage. The laws pinned here:
/// determinism (every device drifts past the same far lights), layer
/// factors below 1, the receding transform, and viewport coverage for
/// every legal camera state.
void main() {
  group('layer laws', () {
    test('two layers, ascending factors, all below the world', () {
      expect(deepFieldLayers.length, 2);
      expect(
        deepFieldLayers[0].factor,
        lessThan(deepFieldLayers[1].factor),
      );
      for (final layer in deepFieldLayers) {
        expect(layer.factor, greaterThan(0));
        expect(layer.factor, lessThan(1));
        expect(layer.dustCount, greaterThan(0));
      }
    });
  });

  group('dust determinism', () {
    test('same seed, same sky — forever', () {
      final a = deepFieldDust(0);
      final b = deepFieldDust(0);
      expect(a.length, deepFieldLayers[0].dustCount);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].at, b[i].at);
        expect(a[i].radius, b[i].radius);
        expect(a[i].alpha, b[i].alpha);
      }
    });

    test('the two layers are different skies', () {
      final far = deepFieldDust(0);
      final near = deepFieldDust(1);
      expect(far.first.at, isNot(near.first.at));
      expect(far.length, isNot(near.length));
    });

    test('dust lives inside the decor plane, in its bounds', () {
      for (var li = 0; li < deepFieldLayers.length; li++) {
        final layer = deepFieldLayers[li];
        for (final mote in deepFieldDust(li)) {
          expect(mote.at.dx, greaterThanOrEqualTo(DeepFieldMath.planeMin));
          expect(mote.at.dx, lessThanOrEqualTo(DeepFieldMath.planeMax));
          expect(mote.at.dy, greaterThanOrEqualTo(DeepFieldMath.planeMin));
          expect(mote.at.dy, lessThanOrEqualTo(DeepFieldMath.planeMax));
          expect(mote.radius, inInclusiveRange(layer.radiusMin, layer.radiusMax));
          expect(mote.alpha, inInclusiveRange(layer.alphaMin, layer.alphaMax));
        }
      }
    });
  });

  group('the receding transform', () {
    const viewport = Size(400, 800);

    test('at home, decor and world coincide', () {
      final c = DeepFieldMath.effectiveCenter(
        const Offset(0.5, 0.5),
        0.3,
      );
      expect(c, const Offset(0.5, 0.5));
    });

    test('a layer factor damps the displacement exactly', () {
      const center = Offset(0.8, 0.3);
      final c = DeepFieldMath.effectiveCenter(center, 0.3);
      expect(c.dx, closeTo(0.5 + 0.3 * 0.3, 1e-12));
      expect(c.dy, closeTo(0.5 - 0.2 * 0.3, 1e-12));
    });

    test('zoom grows slower for deeper layers', () {
      expect(DeepFieldMath.effectiveZoom(1.0, 0.3), 1.0);
      expect(DeepFieldMath.effectiveZoom(8.0, 0.0), 1.0);
      expect(DeepFieldMath.effectiveZoom(8.0, 1.0), 8.0);
      expect(
        DeepFieldMath.effectiveZoom(8.0, 0.3),
        lessThan(DeepFieldMath.effectiveZoom(8.0, 0.55)),
      );
    });

    test('sizeScale rests at the eye\'s base zoom', () {
      for (final layer in deepFieldLayers) {
        expect(DeepFieldMath.sizeScale(1.75, layer.factor), 1.0);
      }
    });

    test('dust moves slower than the world — the passage', () {
      const dust = Offset(0.5, 0.5);

      // At zoom 1 the fractions are exact: a world point carried by a
      // pan of δ moves |δ|·viewport on screen; the same dust point
      // moves exactly factor·|δ|·viewport.
      final before = DeepFieldMath.worldToScreen(
        dust,
        center: const Offset(0.5, 0.5),
        zoom: 1.0,
        factor: 0.55,
        viewport: viewport,
      );
      final after = DeepFieldMath.worldToScreen(
        dust,
        center: const Offset(0.7, 0.5),
        zoom: 1.0,
        factor: 0.55,
        viewport: viewport,
      );
      // Eye pans +0.2 → the world apparently moves −0.2·viewport (the
      // sky follows the eye), the dust exactly factor·that: receding.
      expect((after - before).dx, closeTo(-0.2 * 0.55 * viewport.width, 1e-9));

      // At any zoom, dust strictly trails the world it rides behind.
      const z = 4.0;
      final cam1 = TravelCamera(zoom: z);
      final cam2 = TravelCamera(zoom: z);
      cam2.panByWorld(const Offset(0.2, 0));
      final worldMove = (cam2.worldToScreen(dust, viewport) -
              cam1.worldToScreen(dust, viewport))
          .dx
          .abs();
      for (final layer in deepFieldLayers) {
        final dustMove = (DeepFieldMath.worldToScreen(
                  dust,
                  center: cam2.center,
                  zoom: z,
                  factor: layer.factor,
                  viewport: viewport,
                ) -
                DeepFieldMath.worldToScreen(
                  dust,
                  center: cam1.center,
                  zoom: z,
                  factor: layer.factor,
                  viewport: viewport,
                ))
            .dx
            .abs();
        expect(dustMove, lessThan(worldMove));
      }
    });
  });

  group('viewport coverage', () {
    test('every legal camera sees dust to the edges of its screen', () {
      const zooms = [1.2, 1.75, 3.0, 8.0];
      const pans = [
        Offset(-10, -10),
        Offset(10, 10),
        Offset(-10, 10),
        Offset(10, -10),
        Offset(0, 0),
      ];
      for (final pan in pans) {
        for (final zoom in zooms) {
          final camera = TravelCamera(zoom: zoom);
          camera.panByWorld(pan);
          for (final layer in deepFieldLayers) {
            final ve = 1.0 /
                DeepFieldMath.effectiveZoom(camera.zoom, layer.factor);
            final c = DeepFieldMath.effectiveCenter(
              camera.center,
              layer.factor,
            );
            // What the screen asks of the decor plane, per axis.
            expect(
              c.dx - ve / 2,
              greaterThanOrEqualTo(DeepFieldMath.planeMin),
              reason:
                  'left edge bare at zoom ${camera.zoom}, pan $pan, f ${layer.factor}',
            );
            expect(
              c.dx + ve / 2,
              lessThanOrEqualTo(DeepFieldMath.planeMax),
              reason:
                  'right edge bare at zoom ${camera.zoom}, pan $pan, f ${layer.factor}',
            );
            expect(c.dy - ve / 2, greaterThanOrEqualTo(DeepFieldMath.planeMin));
            expect(c.dy + ve / 2, lessThanOrEqualTo(DeepFieldMath.planeMax));
          }
        }
      }
    });
  });

  group('the painter', () {
    test('paintsmoke — 138 motes on a portrait canvas, no throw', () {
      final camera = TravelCamera();
      final painter = DeepFieldPainter(camera: camera);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(390, 844));
      recorder.endRecording().dispose();
    });

    test('shouldRepaint fires only when the eye actually moved', () {
      final camera = TravelCamera();
      final a = DeepFieldPainter(camera: camera);
      final b = DeepFieldPainter(camera: camera);
      expect(a.shouldRepaint(b), isFalse);
      camera.panByWorld(const Offset(0.05, 0));
      final c = DeepFieldPainter(camera: camera);
      expect(b.shouldRepaint(c), isTrue);
    });
  });
}
