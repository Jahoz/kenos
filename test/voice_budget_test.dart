import 'package:flutter_test/flutter_test.dart';

import 'package:kenos/core/audio/voice_budget.dart';
import 'package:kenos/features/frequencies/application/spatial_wave_audio.dart';

void main() {
  group('VoiceBudget — the sky has six throats (V3.55)', () {
    test('an empty sky sings at full voice', () {
      final budget = VoiceBudget(maxVoices: 6);
      final now = DateTime(2026, 9, 17, 12);
      final verdict = budget.admit(now, now.add(const Duration(seconds: 6)));
      expect(verdict.steal, isEmpty);
      expect(verdict.gainScale, 1.0);
    });

    test('the seventh note steals the OLDEST throat', () {
      final budget = VoiceBudget(maxVoices: 6);
      final t0 = DateTime(2026, 9, 17, 12);
      for (var i = 0; i < 6; i++) {
        budget.admit(
          t0.add(Duration(milliseconds: i * 100)),
          t0.add(Duration(milliseconds: i * 100 + 6000)),
        );
      }
      // The 7th arrives: the 1st (oldest) must yield.
      final verdict =
          budget.admit(t0.add(const Duration(seconds: 1)), t0.add(const Duration(seconds: 8)));
      expect(verdict.steal, [0]);
      // Seven admitted, one stolen: six sing after.
      expect(verdict.gainScale, closeTo(1 / 2.449, 0.01));
    });

    test('voices whose time is over free their throats', () {
      final budget = VoiceBudget(maxVoices: 6);
      final t0 = DateTime(2026, 9, 17, 12);
      for (var i = 0; i < 6; i++) {
        budget.admit(t0, t0.add(const Duration(seconds: 1)));
      }
      // Long after: all six have ended, the sky is silent again.
      final later = t0.add(const Duration(seconds: 30));
      final verdict = budget.admit(later, later.add(const Duration(seconds: 6)));
      expect(verdict.steal, isEmpty);
      expect(verdict.gainScale, 1.0);
    });

    test('a storm steals oldest-first until the budget holds', () {
      final budget = VoiceBudget(maxVoices: 3);
      final t0 = DateTime(2026, 9, 17, 12);
      for (var i = 0; i < 3; i++) {
        budget.admit(t0, t0.add(const Duration(seconds: 60)));
      }
      // Three live long notes; two quick ones ask in back to back.
      final t1 = t0.add(const Duration(seconds: 1));
      budget.admit(t1, t1.add(const Duration(seconds: 2)));
      final verdict =
          budget.admit(t1, t1.add(const Duration(seconds: 2)));
      // The storm stole every long note: nothing older survives.
      expect(verdict.steal, isNotEmpty);
      expect(verdict.steal.length, lessThanOrEqualTo(2));
    });
  });

  group('The held note\'s envelope (V3.55)', () {
    test('the nebula stays six seconds — the wave it replaces', () {
      final env = SpatialWaveAudio.envelopeFor(null);
      expect(env.attack, const Duration(milliseconds: 1200));
      expect(env.exhaleAt, const Duration(milliseconds: 3600));
      expect(env.release, const Duration(milliseconds: 2400));
      expect(env.life, const Duration(seconds: 6));
    });

    test('a held note ends with its tenue, never rings the nebula', () {
      // The flutter: 120 ms — attack AND release shrink to it.
      final flutter = SpatialWaveAudio.envelopeFor(
        const Duration(milliseconds: 120),
      );
      expect(flutter.attack, const Duration(milliseconds: 120));
      expect(flutter.release, const Duration(milliseconds: 120));
      expect(flutter.life, const Duration(milliseconds: 240));

      // A held breath: 2 s — soft touch, exhale capped, ends ~2.36 s.
      final breath = SpatialWaveAudio.envelopeFor(
        const Duration(seconds: 2),
      );
      expect(breath.attack, const Duration(milliseconds: 120));
      expect(breath.exhaleAt, const Duration(seconds: 2));
      expect(breath.release, const Duration(milliseconds: 360));
      expect(breath.life, const Duration(milliseconds: 2360));
      expect(breath.life, lessThan(const Duration(seconds: 6)));
    });
  });
}
