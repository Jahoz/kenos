import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/utils/parallax_math.dart';
import 'package:kenos/features/cosmic_map/application/travel_camera.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/background_painters.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/deep_field_painter.dart';

/// V3.63 — le vide est un lieu : la présence de l'éther connu décroît
/// avec la distance parcourue (le ciel ambiant se vide en voyageant),
/// et le foyer n'existe qu'au loin.
void main() {
  group('ParallaxMath.etherPresence', () {
    const heart = Offset(0.5, 0.5);

    test('pleine présence au cœur de l\'éther', () {
      expect(ParallaxMath.etherPresence(heart), 1.0);
      expect(ParallaxMath.etherPresence(const Offset(0.95, 0.5)), 1.0);
    });

    test('le monde connu garde son habit jusqu\'au bord', () {
      // d = 0.55 : encore plein — la bande habitée va jusqu'au rim
      // (V3.68 : la bande s'élargit avec le regard reculé).
      expect(
        ParallaxMath.etherPresence(const Offset(1.05, 0.5)),
        1.0,
      );
    });

    test('perte douce, jamais de couture', () {
      Offset ray(double d) => heart + Offset(d, 0);
      var prev = 1.0;
      for (var d = 0.55; d <= 1.25; d += 0.05) {
        final p = ParallaxMath.etherPresence(ray(d));
        expect(p, lessThanOrEqualTo(prev + 1e-9),
            reason: 'la présence décroît (d=$d)');
        expect(p, greaterThanOrEqualTo(0.0));
        expect(p, lessThanOrEqualTo(1.0));
        prev = p;
      }
      // Milieu de course : à mi-chemin du fade, la smoothstep ≈ 0.5.
      expect(ParallaxMath.etherPresence(ray(0.9)), closeTo(0.5, 0.02));
    });

    test('le grand vide est vide : présence nulle au loin', () {
      expect(ParallaxMath.etherPresence(const Offset(1.8, 0.5)), 0.0);
      expect(ParallaxMath.etherPresence(const Offset(-0.5, -0.5)), 0.0);
    });
  });

  group('les couches ambiantes portent la présence (V3.63)', () {
    test('champ mort : mêmes graines, même ciel — la présence ne jette que', () {
      // Deux peintures à présence différente ne lèvent pas ; le
      // painter reste constructible et répignable sur la présence.
      final a = BackgroundStarFieldPainter(
        time: 1,
        tiltX: 0,
        tiltY: 0,
        presence: 1.0,
      );
      final b = BackgroundStarFieldPainter(
        time: 1,
        tiltX: 0,
        tiltY: 0,
        presence: 0.0,
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test('nébuleuses : le foyer ne s\'allume qu\'au loin', () {
      final near = NebulaPainter(tiltX: 0, tiltY: 0, presence: 1.0);
      final far = NebulaPainter(
        tiltX: 0,
        tiltY: 0,
        presence: 0.0,
        hearthAt: const Offset(0.2, 0.3),
        hearthGlow: 1.0,
      );
      expect(far.shouldRepaint(near), isTrue);
    });

    test('champ profond : la poussière garde un plancher au loin', () {
      final camera = TravelCamera();
      final home = DeepFieldPainter(camera: camera, presence: 1.0);
      final far = DeepFieldPainter(camera: camera, presence: 0.0);
      expect(far.shouldRepaint(home), isTrue);
    });
  });
}
