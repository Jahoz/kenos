import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/frequencies/application/spatial_wave_audio.dart';
import 'package:kenos/features/frequencies/domain/spatial_wave_math.dart';

/// V3.6 — the spatial contract: pitch mirrors the baked assets exactly,
/// the stereo field follows the horizontal offset, loudness follows the
/// distance — and an engine that cannot live degrades to the assets,
/// never to silence nor an error.
void main() {
  group('frequencyForNote — miroir exact de gen_audio.py', () {
    test('les 20 notes pentatoniques, C2 à A5', () {
      const expected = [
        65.41, 73.42, 82.41, 98.00, 110.00, //
        130.81, 146.83, 164.81, 196.00, 220.00, //
        261.63, 293.66, 329.63, 392.00, 440.00, //
        523.25, 587.33, 659.25, 783.99, 880.00, //
      ];
      for (final (i, freq) in expected.indexed) {
        expect(SpatialWaveMath.frequencyForNote(i), freq,
            reason: 'la note $i doit chanter le même pitch que son asset');
      }
    });

    test('un index hors bornes s\'écrase, jamais ne crashe', () {
      expect(SpatialWaveMath.frequencyForNote(-3), 65.41);
      expect(SpatialWaveMath.frequencyForNote(99), 880.00);
    });
  });

  group('panFor — le champ stéréo suit l\'écart horizontal', () {
    test('née sous l\'oreille → centrée', () {
      expect(SpatialWaveMath.panFor(0.5, 0.5), 0.0);
    });

    test('née à gauche de l\'oreille → haut-parleur gauche', () {
      expect(SpatialWaveMath.panFor(0.3, 0.5), lessThan(0));
      expect(SpatialWaveMath.panFor(0.7, 0.5), greaterThan(0));
    });

    test('bornée au champ dur au-delà du demi-écran', () {
      expect(SpatialWaveMath.panFor(0.0, 0.5), -1.0);
      expect(SpatialWaveMath.panFor(1.0, 0.5), 1.0);
      expect(SpatialWaveMath.panFor(-5, 0.5), -1.0);
    });
  });

  group('gainFor — le volume suit la distance', () {
    test('sous l\'oreille, pleine présence ; au bord, souffle', () {
      expect(SpatialWaveMath.gainFor(0), 0.85);
      expect(SpatialWaveMath.gainFor(0.35, radius: 0.35), 0.15);
    });

    test('au-delà du rayon, jamais muette ni criarde', () {
      expect(SpatialWaveMath.gainFor(5), 0.15);
    });
  });

  group('dégradation honnête — le moteur est un invité', () {
    test('sans moteur (VM de test), playNote rend la main aux assets',
        () async {
      final played = await SpatialWaveAudio.instance.playNote(
        7,
        pan: 0.4,
        gain: 0.5,
      );
      expect(played, isFalse,
          reason: 'sans moteur natif, la symphonie retombe sur les assets');
    });
  });
}
