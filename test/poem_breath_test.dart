import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/cosmic_map/application/poem_breath.dart';
import 'package:kenos/features/cosmic_map/data/artifact_memory.dart';

/// V3.45 — the poem's breath: a corpse these hands helped write,
/// CLOSED and unread, takes the sky's souffle until read — the
/// participant can FIND their own artifact. Open rings, other hands'
/// poems, read and kept ones never steal the breath.
void main() {
  late _MemIO io;
  late ArtifactMemory memory;

  setUp(() async {
    io = _MemIO();
    memory = ArtifactMemory(io: io);
    await memory.load();
  });

  ConstellationMeta poem(
    String id,
    Offset seed, {
    bool closed = true,
  }) =>
      ConstellationMeta(
        id: id,
        seedX: seed.dx,
        seedY: seed.dy,
        state: closed ? 'CLOSED' : 'OPEN',
        lineCount: 5,
        target: 5,
      );

  test('le poème de ta main, fermé et non lu, prend le souffle', () async {
    await memory.markContributed('mine-1');
    final line = PoemBreath.line(
      [poem('mine-1', const Offset(0.7, 0.5))],
      memory,
      const Offset(0.5, 0.5),
    );
    expect(line, isNotNull);
    expect(line, contains('SOUFFLE VERS 3 H'),
        reason: 'à l\'est de l\'œil, comme les heures du ciel');
    expect(line, contains('TA MAIN'));
  });

  test('ouvert, des autres mains, lu ou gardé : jamais le souffle', () async {
    await memory.markContributed('mine-open');
    await memory.markContributed('mine-read');
    await memory.markContributed('mine-kept');
    await memory.markRead('mine-read');
    await memory.keep(KeptArtifact(
      id: 'mine-kept',
      kind: 'constellation',
      x: 0.4,
      y: 0.4,
      texts: const ['un'],
      keptAt: 0,
    ));
    final line = PoemBreath.line(
      [
        poem('stranger-1', const Offset(0.8, 0.5)), // not mine
        poem('mine-open', const Offset(0.8, 0.5), closed: false),
        poem('mine-read', const Offset(0.8, 0.5)),
        poem('mine-kept', const Offset(0.8, 0.5)),
      ],
      memory,
      const Offset(0.5, 0.5),
    );
    expect(line, isNull,
        reason: 'le souffle ne se vole pas pour ce qui est déjà vécu');
  });

  test('le plus proche gagne, quand plusieurs attendent', () async {
    await memory.markContributed('far');
    await memory.markContributed('near');
    final waiting = PoemBreath.waitingPoem(
      [
        poem('far', const Offset(0.9, 0.5)),
        poem('near', const Offset(0.55, 0.5)),
      ],
      memory,
      const Offset(0.5, 0.5),
    );
    expect(waiting?.id, 'near');
  });

  test('la fermeture dite ne se redit pas (la mémoire traverse le redémarrage)',
      () async {
    await memory.markContributed('mine-1');
    await memory.markClosureTold('mine-1');
    expect(memory.closureTold('mine-1'), isTrue);

    final reborn = ArtifactMemory(io: io);
    await reborn.load();
    expect(reborn.closureTold('mine-1'), isTrue,
        reason: 'le ciel ne radote pas');
    // An un-told closure survives the restart too.
    await reborn.markContributed('mine-2');
    expect(reborn.closureTold('mine-2'), isFalse);
  });
}

class _MemIO implements ArtifactMemoryIO {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}
