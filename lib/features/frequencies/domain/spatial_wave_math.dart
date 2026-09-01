/// V3.6 — spatial arithmetic for the Collective Symphony: where a wave
/// sits in the stereo field, how loud it arrives, and the exact pitch
/// of its oscillator (mirrors `tool/gen_audio.py`'s baked assets).
class SpatialWaveMath {
  SpatialWaveMath._();

  /// C-major pentatonic across 4 octaves — identical to the generated
  /// assets, so oscillator and fallback never disagree on pitch.
  static const List<double> frequencies = [
    65.41, 73.42, 82.41, 98.00, 110.00, // C2 - A2 (heavy / melancholy)
    130.81, 146.83, 164.81, 196.00, 220.00, // C3 - A3 (neutral / calm)
    261.63, 293.66, 329.63, 392.00, 440.00, // C4 - A4 (clear / hope)
    523.25, 587.33, 659.25, 783.99, 880.00, // C5 - A5 (crystalline / joy)
  ];

  static double frequencyForNote(int noteIndex) =>
      frequencies[noteIndex.clamp(0, frequencies.length - 1)];

  /// Stereo position of a wave heard from the listening point: left of
  /// the ear → left speaker, right → right. The full field spans half
  /// the screen; beyond that, hard over.
  static double panFor(double waveX, double listenX) =>
      ((waveX - listenX) * 2).clamp(-1.0, 1.0);

  /// Arrival loudness: full under the ear, breath at the radius edge.
  static double gainFor(double distance, {double radius = 0.35}) =>
      (1.0 - distance / radius).clamp(0.15, 0.85);
}
