import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/constants/app_colors.dart';
import 'package:kenos/features/frequencies/application/wave_controller.dart';
import 'package:kenos/features/frequencies/data/frequency_repository.dart';
import 'package:kenos/features/frequencies/domain/kenos_wave.dart';

/// Silent ether: records emissions, hears nothing by default.
class FakeFrequencyRepository implements FrequencyRepository {
  final emitted = <({double offsetX, double offsetY, int noteIndex, int hueIndex})>[];
  List<RemoteWave> nearby = const [];

  @override
  Future<void> emit({
    required double offsetX,
    required double offsetY,
    required int noteIndex,
    required int hueIndex,
  }) async {
    emitted.add((
      offsetX: offsetX,
      offsetY: offsetY,
      noteIndex: noteIndex,
      hueIndex: hueIndex,
    ));
  }

  @override
  Future<List<RemoteWave>> fetchNearby({
    required double centerX,
    required double centerY,
    required double radius,
  }) async =>
      nearby;
}

void main() {
  group('WaveMath (mécanique du POC portée en Flutter)', () {
    test('Y → note : le bas est grave, le haut cristallin', () {
      expect(WaveMath.noteForY(1.0), 0, reason: 'tout en bas = C2');
      expect(WaveMath.noteForY(0.0), 19, reason: 'tout en haut = A5');
      expect(WaveMath.noteForY(0.5), 10, reason: 'mi-hauteur = C4, moitié de la gamme');
      // Monotonic: sliding DOWN the screen lowers the register.
      expect(WaveMath.noteForY(0.8), lessThan(WaveMath.noteForY(0.5)));
      expect(WaveMath.noteForY(0.2), greaterThan(WaveMath.noteForY(0.5)));
    });

    test('Y → note : bornes hors écran bornées, jamais d\'exception', () {
      expect(WaveMath.noteForY(-0.5), 19);
      expect(WaveMath.noteForY(1.5), 0);
    });

    test('X → teinte : 4 bandes, bornées', () {
      expect(WaveMath.hueForX(0.0), 0);
      expect(WaveMath.hueForX(0.24), 0);
      expect(WaveMath.hueForX(0.25), 1);
      expect(WaveMath.hueForX(1.0), 3);
      expect(WaveMath.hueForX(-1.0), 0);
      expect(WaveMath.hueForX(9.0), 3);
    });

    test('la palette des ondes ne contient JAMAIS le rose (destruction)', () {
      final forbidden = {AppColors.rose.toARGB32(), AppColors.roseText.toARGB32()};
      for (final hue in WavePalette.hues) {
        expect(forbidden, isNot(contains(hue.toARGB32())));
      }
    });

    test('chaque note pointe vers un asset nommé wave_XX.wav', () {
      expect(WaveMath.assetForNote(0), 'assets/audio/waves/wave_00.wav');
      expect(WaveMath.assetForNote(19), 'assets/audio/waves/wave_19.wav');
    });
  });

  group('KenosWave (cycle de vie)', () {
    test('progress et expiration', () {
      final born = DateTime(2026, 8, 31, 12);
      final wave = KenosWave(
        id: 'w1',
        offsetX: 0.5,
        offsetY: 0.5,
        noteIndex: 9,
        hueIndex: 2,
        bornAt: born,
      );
      expect(wave.progressAt(born), 0.0);
      expect(wave.progressAt(born.add(KenosWave.visualLife)), 1.0);
      expect(wave.isExpiredAt(born.add(KenosWave.visualLife)), isTrue);
      expect(
        wave.isExpiredAt(
          born.add(KenosWave.visualLife - const Duration(milliseconds: 1)),
        ),
        isFalse,
      );
    });
  });

  group('WaveController', () {
    test('emit crée une onde mappée, traversée par le repo, purgée à temps',
        () async {
      final repo = FakeFrequencyRepository();
      final container = ProviderContainer(overrides: [
        frequencyRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final controller = container.read(waveControllerProvider.notifier);
      final wave = controller.emit(0.9, 0.1);

      expect(wave.hueIndex, 3, reason: 'X=0.9 → bande cyan');
      expect(wave.noteIndex, greaterThan(15), reason: 'Y=0.1 → registre haut');
      expect(container.read(waveControllerProvider).length, 1);
      // The wave crossed to the ether (fire-and-forget, awaited via pump).
      await Future<void>.delayed(Duration.zero);
      expect(repo.emitted.single.noteIndex, wave.noteIndex);
    });

    test('une onde entendue tard respire ENTIÈREMENT depuis son arrivée', () async {
      // Regression: the nebula's life used to run from the SERVER's
      // birth — a wave heard 5 s after its emission showed for 2 s
      // only; heard after 7 s, never at all. It must breathe in full
      // from ARRIVAL.
      final repo = FakeFrequencyRepository();
      final container = ProviderContainer(overrides: [
        frequencyRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final controller = container.read(waveControllerProvider.notifier);
      controller.nowSource = () => DateTime(2026, 8, 31, 12);
      // Born 30 s ago: stale catch-up — visible, silent.
      // Born 3 s ago: fresh — visible, and it sings.
      repo.nearby = [
        RemoteWave(
          id: 'stale-wave',
          offsetX: 0.4,
          offsetY: 0.4,
          noteIndex: 3,
          hueIndex: 0,
          createdAt: DateTime(2026, 8, 31, 11, 59, 30),
        ),
        RemoteWave(
          id: 'fresh-wave',
          offsetX: 0.6,
          offsetY: 0.6,
          noteIndex: 12,
          hueIndex: 2,
          createdAt: DateTime(2026, 8, 31, 11, 59, 57),
        ),
      ];

      final sung = <String>[];
      final sub = controller.incomingWaves.listen((w) => sung.add(w.id));
      addTearDown(sub.cancel);

      await controller.debugPollOnce();
      await Future<void>.delayed(const Duration(milliseconds: 30)); // stream delivery
      final heard = container.read(waveControllerProvider);
      expect(heard.length, 2, reason: 'les deux ondes arrivent à l\'écran');

      // 5 s after arrival, both still breathe (life counts from HERE).
      controller.nowSource = () => DateTime(2026, 8, 31, 12, 0, 5);
      controller.purgeExpired();
      expect(container.read(waveControllerProvider).length, 2);

      // Only the fresh one sang.
      expect(sung, ['fresh-wave']);

      // A wave older than 45 s at arrival is left to rest.
      repo.nearby = [
        RemoteWave(
          id: 'dead-wave',
          offsetX: 0.2,
          offsetY: 0.2,
          noteIndex: 1,
          hueIndex: 1,
          createdAt: DateTime(2026, 8, 31, 11, 59, 10),
        ),
      ];
      await controller.debugPollOnce();
      expect(
        container.read(waveControllerProvider).map((w) => w.id),
        isNot(contains('dead-wave')),
      );
    });

    test('le poll fusionne les ondes des autres une seule fois chacune',
        () async {
      final repo = FakeFrequencyRepository();
      final container = ProviderContainer(overrides: [
        frequencyRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final controller = container.read(waveControllerProvider.notifier);
      controller.nowSource = () => DateTime(2026, 8, 31, 12);
      repo.nearby = [
        RemoteWave(
          id: 'remote-1',
          offsetX: 0.3,
          offsetY: 0.7,
          noteIndex: 3,
          hueIndex: 0,
          createdAt: DateTime(2026, 8, 31, 11, 59, 58),
        ),
      ];

      await controller.debugPollOnce();
      final heard = container.read(waveControllerProvider);
      expect(heard.single.id, 'remote-1');
      // A second identical poll must not duplicate the wave.
      await controller.debugPollOnce();
      expect(container.read(waveControllerProvider).length, 1);
    });

    test('emit plafonne le nombre d\'ondes actives', () {
      final container = ProviderContainer(overrides: [
        frequencyRepositoryProvider
            .overrideWithValue(FakeFrequencyRepository()),
      ]);
      addTearDown(container.dispose);

      final controller = container.read(waveControllerProvider.notifier);
      for (var i = 0; i < 30; i++) {
        controller.emit(0.5, 0.5);
      }
      expect(
        container.read(waveControllerProvider).length,
        WaveController.maxWaves,
      );
    });

    test('purgeExpired retire les ondes au-delà de leur vie', () {
      final container = ProviderContainer(overrides: [
        frequencyRepositoryProvider
            .overrideWithValue(FakeFrequencyRepository()),
      ]);
      addTearDown(container.dispose);

      final controller = container.read(waveControllerProvider.notifier);
      controller.nowSource = () => DateTime(2026, 8, 31, 12);
      controller.emit(0.5, 0.5);
      expect(container.read(waveControllerProvider).length, 1);

      // 8 s later: the wave's visual life (7 s) is over.
      controller.nowSource = () => DateTime(2026, 8, 31, 12, 0, 8);
      controller.purgeExpired();
      expect(container.read(waveControllerProvider), isEmpty);
    });
  });
}
