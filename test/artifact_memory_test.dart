import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/constellation_repository.dart';
import 'package:kenos/features/constellations/presentation/constellation_sheets.dart';
import 'package:kenos/features/cosmic_map/data/artifact_memory.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/vestige.dart';

/// The traveller's memory of artifacts: read markers are a memory,
/// not a burn (seven days, this device only), and the reliquaire
/// keeps a handful of objects in ONE's sky longer than the moon.
void main() {
  KeptArtifact artifact(String id, {int keptAt = 0}) => KeptArtifact(
        id: id,
        kind: 'constellation',
        x: 0.5,
        y: 0.5,
        texts: ['une ligne', 'une autre ligne'],
        target: 2,
        keptAt: keptAt,
      );

  group('les marqueurs de lecture', () {
    test('lu il y a moins de sept jours : lu ; au-delà : redécouverte',
        () async {
      final io = _MemIO();
      final now = DateTime.now().millisecondsSinceEpoch;
      io.data['kenos.artifact_memory'] =
          '{"read": {"fresh": ${now - 86400000}, "old": ${now - 8 * 86400000}}, "kept": []}';

      final memory = ArtifactMemory(io: io);
      await memory.load();
      expect(memory.isRead('fresh'), isTrue, reason: 'hier, c\'est encore lu');
      expect(memory.isRead('old'), isFalse,
          reason: 'huit jours : l\'artefact redevient une découverte');
    });

    test('marquer persiste — la mémoire survit au redémarrage', () async {
      final io = _MemIO();
      final first = ArtifactMemory(io: io);
      await first.load();
      await first.markRead('c1');

      final second = ArtifactMemory(io: io);
      await second.load();
      expect(second.isRead('c1'), isTrue,
          reason: 'le marqueur ne meurt pas avec la session');
    });
  });

  group('le reliquaire', () {
    test('garder, relire : tout est là, position comprise', () async {
      final io = _MemIO();
      final memory = ArtifactMemory(io: io);
      await memory.load();
      await memory.keep(artifact('c1'));

      final reread = ArtifactMemory(io: io);
      await reread.load();
      final kept = reread.keptById('c1');
      expect(kept, isNotNull);
      expect(kept!.texts, ['une ligne', 'une autre ligne']);
      expect(kept.x, 0.5);
      expect(reread.isKept('c1'), isTrue);
    });

    test('sept objets, pas un de plus — le plus ancien retourne au ciel',
        () async {
      final io = _MemIO();
      final memory = ArtifactMemory(io: io);
      await memory.load();
      for (var i = 0; i < ArtifactMemory.keepLimit; i++) {
        await memory.keep(artifact('c$i', keptAt: i));
      }
      final released = await memory.keep(artifact('c7', keptAt: 7));
      expect(released?.id, 'c0',
          reason: 'le plus ancien garde cède sa place');
      expect(memory.kept(), hasLength(ArtifactMemory.keepLimit));
      expect(memory.isKept('c0'), isFalse);
      expect(memory.isKept('c7'), isTrue);
    });

    test('garder ne périme jamais — même après la semaine des lectures',
        () async {
      final io = _MemIO();
      final now = DateTime.now().millisecondsSinceEpoch;
      io.data['kenos.artifact_memory'] =
          '{"read": {}, "kept": [{"id":"c1","kind":"constellation","x":0.5,"y":0.5,"texts":["ligne"],"target":1,"keptAt":${now - 40 * 86400000}}]}';
      final memory = ArtifactMemory(io: io);
      await memory.load();
      expect(memory.isKept('c1'), isTrue,
          reason: 'la braise ne fond pas : gardé est gardé');
    });
  });

  group('la mémoire guérit au refus de l\'éther', () {
    testWidgets(
        'ALREADY_CONTRIBUTED appris localement — l\'offre meurt après UN refus',
        (tester) async {
      final memory = ArtifactMemory(io: _MemIO());
      await memory.load();
      final repo = _RefusingConstellationRepo('KENOS_ALREADY_CONTRIBUTED');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            constellationRepositoryProvider.overrideWithValue(repo),
            artifactMemoryProvider.overrideWithValue(memory),
          ],
          child: MaterialApp(home: _OpenSheetHost(kind: ConstellationKind.melody)),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pump(const Duration(milliseconds: 600));

      // One note on the composer pad revives the phrase button.
      final pad = find.textContaining('LA HAUTEUR EST LA NOTE');
      await tester.tapAt(tester.getCenter(pad));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'DONNER LA PHRASE'));
      await tester.pump();

      expect(find.textContaining('DÉJÀ DANS CE CORPS'), findsOneWidget,
          reason: 'le refus dit son nom');
      expect(memory.contributedTo('c1'), isTrue,
          reason: 'la vérité de l\'éther devient locale, l\'offre ne reviendra plus');
    });
  });

  group('LE GARDER — les panneau', () {
    testWidgets('un vestige entre au reliquaire, marqué lu au passage',
        (tester) async {
      final memory = ArtifactMemory(io: _MemIO());
      await memory.load();
      const vestige = Vestige(
        id: 'v-keep',
        kind: 'haiku',
        text: 'un grain sur l\'aile d\'une nuit',
        source: 'kenos',
        offsetX: 0.3,
        offsetY: 0.4,
      );
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: OutlinedButton(
              onPressed: () =>
                  showVestigeSheet(context, vestige: vestige, memory: memory),
              child: const Text('OUVRIR'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('OUVRIR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(memory.isRead('v-keep'), isTrue,
          reason: 'ouvrir le panneau marque la lecture (sept jours)');
      await tester.tap(find.text('LE GARDER DANS MON CIEL'));
      await tester.pump();
      expect(find.text('GARDÉ DANS TON CIEL'), findsOneWidget);
      final kept = memory.keptById('v-keep');
      expect(kept, isNotNull);
      expect(kept!.kind, 'vestige');
      expect(kept.texts.single, contains('un grain'));
      expect(kept.x, 0.3);
    });

    testWidgets('une constellation refermée entre au reliquaire, lignes comprises',
        (tester) async {
      final memory = ArtifactMemory(io: _MemIO());
      await memory.load();
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: OutlinedButton(
              onPressed: () => showConstellationReading(
                context,
                figureId: 'c-keep',
                lines: const [
                  AssembledLine(number: 1, text: 'première ligne'),
                  AssembledLine(number: 2, text: 'deuxième ligne'),
                ],
                memory: memory,
                keepPosition: const Offset(0.6, 0.7),
              ),
              child: const Text('OUVRIR'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('OUVRIR'));
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.text('LE GARDER DANS MON CIEL'));
      await tester.pump();
      expect(find.text('GARDÉ DANS TON CIEL'), findsOneWidget);
      final kept = memory.keptById('c-keep');
      expect(kept, isNotNull);
      expect(kept!.texts, ['première ligne', 'deuxième ligne']);
      expect(kept.x, 0.6);
      expect(kept.y, 0.7);
      // Already kept: the offer does not come back.
      expect(find.text('LE GARDER DANS MON CIEL'), findsNothing);
    });
  });
}

class _OpenSheetHost extends ConsumerWidget {
  const _OpenSheetHost({required this.kind});

  final ConstellationKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => showContributeSheet(
        context,
        ref: ref,
        constellation: ConstellationMeta(
          id: 'c1',
          seedX: 0.5,
          seedY: 0.5,
          state: 'OPEN',
          lineCount: 1,
          target: 4,
          kind: kind,
        ),
      ),
      child: const Text('OPEN'),
    );
  }
}

class _RefusingConstellationRepo implements ConstellationRepository {
  _RefusingConstellationRepo(this.code);

  final String code;

  @override
  Future<ContributeResult> contribute({
    required String constellationId,
    required String text,
  }) async =>
      throw Exception('PostgrestException: $code');

  @override
  Future<bool?> hasContributed(String id) async => null;

  @override
  Future<AssembledLine?> peekPrevious(String constellationId) async => null;

  @override
  Future<ConstellationMeta> seed(
    double x,
    double y, {
    ConstellationKind kind = ConstellationKind.poem,
  }) async => throw UnimplementedError();

  @override
  Future<List<ConstellationMeta>> fetchVisible() async => const [];

  @override
  Future<List<AssembledLine>?> read(String id) async => null;
}

class _MemIO implements ArtifactMemoryIO {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}
