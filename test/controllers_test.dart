import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/application/map_controller.dart';
import 'package:kenos/features/cosmic_map/application/reception_controller.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';
import 'package:kenos/features/echo/data/user_stats_store.dart';
import 'package:kenos/features/echo/domain/echo.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';
import 'package:kenos/features/echo/domain/echo_media.dart';
import 'package:kenos/features/echo/domain/reception.dart';

/// In-memory ether with the production CONTRACT semantics:
/// the map never carries text, consumption is single-shot, and one's
/// own echoes never come back from the map (the sealed star is the
/// only representation — as the fixed RPC guarantees).
class FakeEchoRepository implements EchoRepository {
  FakeEchoRepository({List<Echo> ether = const []}) : _ether = [...ether];

  final List<Echo> _ether;
  List<Echo> get ether => _ether;
  final Set<String> _consumed = {};
  final List<Reception> _receptions = [];
  final _changes = StreamController<void>.broadcast();

  @override
  Future<List<Echo>> fetchStarMap() => fetchStarMapInSector(0, 0, 1, 1);

  @override
  Future<List<Echo>> fetchStarMapInSector(
    double minX,
    double minY,
    double maxX,
    double maxY,
  ) async =>
      _ether
          .where((e) => !_consumed.contains(e.id))
          .where((e) =>
              e.coordX >= minX &&
              e.coordX <= maxX &&
              e.coordY >= minY &&
              e.coordY <= maxY)
          .toList();

  @override
  Future<ConsumedEcho?> consumeEcho(String id) async {
    if (_consumed.contains(id)) return null;
    final exists = _ether.any((e) => e.id == id && !e.isMine);
    if (!exists) return null;
    _consumed.add(id);
    return ConsumedEcho(text: 'TEXTE DE $id');
  }

  @override
  Future<Echo> sendEcho({
    required String text,
    required double coordX,
    required double coordY,
    required double coordZ,
    required EchoColorTheme theme,
    EchoMediaDraft? media,
  }) async =>
      Echo(
        id: 'new-${_ether.length + 1}',
        coordX: coordX,
        coordY: coordY,
        coordZ: coordZ,
        theme: theme,
        createdAt: DateTime.now(),
        mediaKind: media?.kind,
        isMine: true,
      );

  @override
  Future<bool> leaveTrace(String echoId, String text) async => true;

  final rebounded = <String>[];

  @override
  Future<Echo> reboundEcho({
    required String sourceId,
    required int parentMomentum,
    required String text,
    required double coordX,
    required double coordY,
    required double coordZ,
  }) async {
    rebounded.add(sourceId);
    return Echo(
      id: 'phoenix-of-$sourceId',
      coordX: coordX,
      coordY: coordY,
      coordZ: coordZ,
      theme: EchoColorTheme.teal,
      createdAt: DateTime.now(),
      isMine: true,
      momentum: parentMomentum + 1,
    );
  }

  @override
  Future<bool> reportEcho(String echoId, EchoReportReason reason) async => true;

  @override
  Future<List<Reception>> fetchReceptions() async => [..._receptions];

  @override
  Future<void> burnReception(String echoId) async {
    _receptions.removeWhere((r) => r.echoId == echoId);
  }

  @override
  Stream<void> receptionChanges() => _changes.stream;

  // Test hooks.
  void land(Reception reception) {
    _receptions.insert(0, reception);
    _changes.add(null);
  }
}

/// In-memory sealed store — same surface, no keychain.
class FakeLocalEchoStore implements LocalEchoStore {
  final List<Echo> sealed = [];
  UserStats stats = UserStats.empty();

  @override
  Future<bool> hasOnboarded() async => true;

  @override
  Future<void> setOnboarded() async {}

  @override
  Future<String> localUserId() async => 'local-uuid';

  @override
  Future<List<Echo>> sealedEchoes() async => [...sealed];

  @override
  Future<void> addSealed(Echo echo) async => sealed.insert(0, echo);

  @override
  Future<List<Reception>> readReceptions() async => const [];

  @override
  Future<void> writeReceptions(List<Reception> receptions) async {}

  @override
  Future<void> recordVisit() async {}

  @override
  Future<UserStats> readStats() async => stats;

  @override
  Future<void> recordEchoSent() async {
    stats = stats.copyWith(totalEchosSent: stats.totalEchosSent + 1);
  }

  @override
  Future<void> recordReceptionReceived() async {
    stats = stats.copyWith(
      totalReceptionsReceived: stats.totalReceptionsReceived + 1,
    );
  }

  @override
  Future<void> recordTraceLeft() async {
    stats = stats.copyWith(totalTracesLeft: stats.totalTracesLeft + 1);
  }

  @override
  Future<void> recordEchoRead() async {
    stats = stats.copyWith(readCount: stats.readCount + 1);
  }

  @override
  void dispose() {}
}

Echo _remote(String id, {double x = 0.5, double y = 0.5}) => Echo(
      id: id,
      coordX: x,
      coordY: y,
      coordZ: 0.5,
      theme: EchoColorTheme.teal,
      createdAt: DateTime.now(),
    );

void main() {
  late FakeEchoRepository repo;
  late FakeLocalEchoStore store;
  late ProviderContainer container;

  setUp(() {
    repo = FakeEchoRepository(ether: [_remote('ether-1'), _remote('ether-2')]);
    store = FakeLocalEchoStore();
    container = ProviderContainer(
      overrides: [
        bootstrapProvider.overrideWithValue(
          const Bootstrap(supabaseConfigured: false, hasOnboarded: true),
        ),
        echoRepositoryProvider.overrideWithValue(repo),
        localEchoStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
  });

  group('MapController', () {
    test('build fusionne éthers distants et scellés, sans doublon d\'id',
        () async {
      final echoes = await container.read(mapControllerProvider.future);
      expect(echoes.map((e) => e.id), ['ether-1', 'ether-2']);

      // A sealed echo appears exactly once, even if the (buggy) remote
      // ether were to return it — the merge must deduplicate by id.
      await container
          .read(mapControllerProvider.notifier)
          .sendEcho(text: 'aveu', theme: EchoColorTheme.indigo);
      final after = await container.read(mapControllerProvider.future);
      expect(after.where((e) => e.id == 'new-3').length, 1);
      expect(after.first.isMine, isTrue);
    });

    test('consume : le vainqueur reçoit le texte, la carte est enrichie',
        () async {
      // Stars must be on the map before they can be held — as in the UI.
      await container.read(mapControllerProvider.future);
      final consumed =
          await container.read(mapControllerProvider.notifier).consume('ether-1');
      expect(consumed?.text, 'TEXTE DE ether-1');
      final echoes = container.read(mapControllerProvider).valueOrNull!;
      expect(
        echoes.firstWhere((e) => e.id == 'ether-1').text,
        isNotNull,
      );
    });

    test('consume perdu : l\'étoile est retirée, pas d\'erreur', () async {
      // Consume directly through the repo first: the controller's
      // attempt then loses the race.
      await repo.consumeEcho('ether-2');
      final consumed =
          await container.read(mapControllerProvider.notifier).consume('ether-2');
      expect(consumed, isNull);
      final echoes = container.read(mapControllerProvider).valueOrNull!;
      expect(echoes.map((e) => e.id), isNot(contains('ether-2')));
    });

    test('sendEcho scelle dans le store SANS le texte', () async {
      await container
          .read(mapControllerProvider.notifier)
          .sendEcho(text: 'un aveu', theme: EchoColorTheme.teal);
      expect(store.sealed, isNotEmpty);
      expect(store.sealed.first.text, isNull,
          reason: 'même son auteur ne relit plus');
      expect(store.stats.totalEchosSent, 1);
    });

    test('lecture et trace comptent seulement après succès', () async {
      await container.read(mapControllerProvider.future);
      await container.read(mapControllerProvider.notifier).consume('ether-1');
      expect(store.stats.readCount, 1);

      final left = await container
          .read(mapControllerProvider.notifier)
          .leaveTrace('ether-1', 'Merci.');
      expect(left, isTrue);
      expect(store.stats.totalTracesLeft, 1);
    });

    test('refreshViewport fusionne : ajoute les nouvelles, garde l\'hors-rect, drop les parties',
        () async {
      await container.read(mapControllerProvider.future);

      // A star appears in a freshly travelled-to sector.
      repo.ether.add(_remote('far-1', x: 0.95, y: 0.95));
      await container.read(mapControllerProvider.notifier).refreshViewport(
            minX: 0.8,
            minY: 0.8,
            maxX: 1.0,
            maxY: 1.0,
          );
      var echoes = container.read(mapControllerProvider).valueOrNull!;
      expect(echoes.map((e) => e.id), containsAll(['ether-1', 'ether-2', 'far-1']),
          reason: 'les étoiles hors rect restent, la nouvelle entre');

      // The ether no longer returns a star inside the synced rect:
      // consumed elsewhere — it must leave the map.
      repo.ether.removeWhere((e) => e.id == 'far-1');
      // Travel a bit further: a NEW window re-asks the ether (the same
      // window would be skipped — already synced).
      await container.read(mapControllerProvider.notifier).refreshViewport(
            minX: 0.7,
            minY: 0.7,
            maxX: 1.0,
            maxY: 1.0,
          );
      echoes = container.read(mapControllerProvider).valueOrNull!;
      expect(echoes.map((e) => e.id), isNot(contains('far-1')));
      expect(echoes.map((e) => e.id), contains('ether-1'),
          reason: 'hors rect : intouché par la fusion');
    });

    test('rebound : le phénix devient une étoile scellée à momentum + 1',
        () async {
      await container.read(mapControllerProvider.future);
      final source = _remote('ether-1');
      final ok = await container
          .read(mapControllerProvider.notifier)
          .rebound(source: source, text: 'pensée relancée');
      expect(ok, isTrue);
      final echoes = container.read(mapControllerProvider).valueOrNull!;
      final phoenix =
          echoes.firstWhere((e) => e.id == 'phoenix-of-ether-1');
      expect(phoenix.isMine, isTrue);
      expect(phoenix.momentum, source.momentum + 1);
      expect(store.sealed.map((e) => e.id), contains(phoenix.id));
    });

    test('forget retire l\'étoile', () async {
      await container.read(mapControllerProvider.future);
      container.read(mapControllerProvider.notifier).forget('ether-1');
      final echoes = container.read(mapControllerProvider).valueOrNull!;
      expect(echoes.map((e) => e.id), isNot(contains('ether-1')));
    });
  });

  group('ReceptionController', () {
    test('un signal qui arrive déclenche un nouvel état', () async {
      await container.read(receptionControllerProvider.future);
      expect(
        container.read(receptionControllerProvider).valueOrNull,
        isEmpty,
      );

      repo.land(Reception(
        echoId: 'sealed-1',
        readAt: DateTime.now(),
        driftSeconds: 3600,
      ));
      // The stream event refreshes asynchronously.
      await Future<void>.delayed(Duration.zero);
      final receptions =
          container.read(receptionControllerProvider).valueOrNull!;
      expect(receptions.single.echoId, 'sealed-1');
      expect(
        container
            .read(receptionControllerProvider.notifier)
            .receptionFor('sealed-1')
            ?.driftSeconds,
        3600,
      );
      expect(store.stats.totalReceptionsReceived, 1);
    });

    test('burn : voir = brûler, le signal ne revient pas', () async {
      repo.land(Reception(
        echoId: 'sealed-1',
        readAt: DateTime.now(),
        driftSeconds: 60,
      ));
      await container.read(receptionControllerProvider.future);
      await container
          .read(receptionControllerProvider.notifier)
          .burn('sealed-1');
      expect(
        container.read(receptionControllerProvider).valueOrNull,
        isEmpty,
      );
      expect(repo._receptions, isEmpty,
          reason: 'le burn traverse bien le repository');
    });
  });
}
