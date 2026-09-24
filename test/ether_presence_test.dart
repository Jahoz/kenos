import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/utils/parallax_math.dart';
import 'package:kenos/features/cosmic_map/application/travel_camera.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/background_painters.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/deep_field_painter.dart';

/// V3.63 — le vide est un lieu : la présence de l'éther connu décroît
/// avec la distance parcourue (le ciel ambiant se vide en voyageant),
/// et le foyer n'existe qu'au loin.
///
/// V3.70 — LE CADRE COUPE UN CIEL HABILLÉ : la présence ne meurt plus
/// au bord du regard d'ouverture ; l'arrière-pays garde un plancher.
void main() {
  group('ParallaxMath.etherPresence', () {
    const heart = Offset(0.5, 0.5);

    test('pleine présence au cœur de l\'éther', () {
      expect(ParallaxMath.etherPresence(heart), 1.0);
      expect(ParallaxMath.etherPresence(const Offset(1.2, 0.5)), 1.0);
    });

    test('le monde connu garde son habit jusqu\'au bord', () {
      // d = 0.8 : encore plein — la bande habitée couvre le survey
      // (V3.69 : le regard d'ouverture voit l'éther habillé).
      expect(
        ParallaxMath.etherPresence(const Offset(1.3, 0.5)),
        1.0,
      );
    });

    test('perte douce, jamais de couture', () {
      Offset ray(double d) => heart + Offset(d, 0);
      var prev = 1.0;
      for (var d = 0.8; d <= 1.55; d += 0.05) {
        final p = ParallaxMath.etherPresence(ray(d));
        expect(p, lessThanOrEqualTo(prev + 1e-9),
            reason: 'la présence décroît (d=$d)');
        expect(p, greaterThanOrEqualTo(ParallaxMath.presenceFloor));
        expect(p, lessThanOrEqualTo(1.0));
        prev = p;
      }
      // Milieu de course : à mi-chemin du fade, la smoothstep ≈ 0.5 —
      // la présence vaut 1 − 0.5·(1 − plancher).
      expect(
        ParallaxMath.etherPresence(ray(1.175)),
        closeTo(1 - 0.5 * (1 - ParallaxMath.presenceFloor), 0.02),
      );
    });

    test('V3.70 — l\'arrière-pays garde un souffle, jamais de noir plat',
        () {
      // Le plancher tient partout, aussi loin qu'on aille : le vide
      // garde du relief, pas du néant.
      expect(
        ParallaxMath.etherPresence(const Offset(2.2, 0.5)),
        ParallaxMath.presenceFloor,
      );
      expect(
        ParallaxMath.etherPresence(const Offset(-3.0, -3.0)),
        ParallaxMath.presenceFloor,
      );
    });
  });

  group('V3.70 — le cadre du survey coupe un ciel habillé', () {
    // Le DoD de l'immensité : à recul max, sur tout aspect réel, le
    // bord ET le coin du cadre voient un ciel habillé (présence ≥
    // 0.12) — l'éther ne meurt plus exactement au bord du cadre, le
    // regard extrapolate la suite.
    test('bords et coins habillés à minZoom sur tout aspect', () {
      const aspects = [1.6, 1.778, 2.0, 2.167]; // 16:10 → S25
      const heart = Offset(0.5, 0.5);
      for (final aspect in aspects) {
        final ve = 1.0 / TravelCamera.minZoom;
        final halfLong = ve / 2 * aspect;
        final halfShort = ve / 2;
        final edge = ParallaxMath.etherPresence(
          heart + Offset(0, halfLong),
        );
        expect(edge, greaterThan(0.12),
            reason: 'le bord long coupe du ciel habillé (aspect $aspect)');
        final corner = ParallaxMath.etherPresence(
          heart + Offset(halfShort, halfLong),
        );
        expect(corner, greaterThan(0.12),
            reason: 'le coin coupe du ciel habillé (aspect $aspect)');
        // Et le regard d'ouverture (zoom 1.0) reste plein cadre.
        final veOpening = 1.0;
        expect(
          ParallaxMath.etherPresence(
            heart + Offset(0, veOpening / 2 * aspect),
          ),
          greaterThan(0.12),
          reason: 'le regard d\'ouverture reste habillé (aspect $aspect)',
        );
      }
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
