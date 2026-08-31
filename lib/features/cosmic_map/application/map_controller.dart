import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../echo/data/echo_providers.dart';
import '../../echo/domain/echo.dart';
import '../../echo/domain/echo_color_theme.dart';
import '../../echo/domain/reception.dart';

/// Stellar map controller: merges ether echoes (remote metadata)
/// and the user's sealed echoes (local), plus the reception signals
/// of the bottle-in-the-sea loop.
class MapController extends AsyncNotifier<List<Echo>> {
  StreamSubscription<void>? _receptionSub;
  Timer? _poll;

  List<Reception> _receptions = const [];
  bool _receptionsLoaded = false;

  /// Unseen receptions, newest first.
  List<Reception> get receptions => _receptions;

  int get unseenReceptionCount =>
      _receptions.where((r) => !r.seen).length;

  Reception? receptionFor(String echoId) {
    for (final r in _receptions) {
      if (r.echoId == echoId) return r;
    }
    return null;
  }

  @override
  Future<List<Echo>> build() async {
    ref.onDispose(() {
      _receptionSub?.cancel();
      _poll?.cancel();
    });

    // Anonymous session: on failure we still try the map;
    // the view only needs metadata if a session already exists.
    try {
      await ref.watch(sessionReadyProvider.future);
    } catch (_) {
      // deliberately ignored: the error will surface via fetchStarMap
    }

    final repo = ref.watch(echoRepositoryProvider);
    final store = ref.watch(localEchoStoreProvider);

    final remote = await repo.fetchStarMap();
    final mine = await store.sealedEchoes();
    await _refreshReceptions();

    // Live signals: demo simulation stream + gentle polling for the server.
    _receptionSub = repo.receptionChanges().listen((_) => _refreshReceptions());
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_receptionsLoaded) return;
      _refreshReceptions();
    });

    return [...mine, ...remote];
  }

  Future<void> _refreshReceptions() async {
    try {
      final repo = ref.read(echoRepositoryProvider);
      final fresh = await repo.fetchReceptions();
      _receptionsLoaded = true;
      if (!_sameReceptions(fresh)) {
        _receptions = fresh;
        // Re-emit the echo list so sealed stars re-render their pulse.
        final echoes = state.valueOrNull ?? const <Echo>[];
        state = AsyncData([...echoes]);
      }
    } catch (e) {
      debugPrint('[kenos.map] receptions unreachable: $e');
    }
  }

  bool _sameReceptions(List<Reception> fresh) {
    if (fresh.length != _receptions.length) return false;
    for (var i = 0; i < fresh.length; i++) {
      if (fresh[i].echoId != _receptions[i].echoId ||
          fresh[i].reply != _receptions[i].reply) {
        return false;
      }
    }
    return true;
  }

  /// Atomic interception of an echo.
  /// Returns the echo enriched with its text for the winner, `null` if
  /// someone else read it in the meantime (the echo is then removed from the map).
  Future<Echo?> consume(String id) async {
    final repo = ref.read(echoRepositoryProvider);
    final text = await repo.consumeEcho(id);
    final current = state.valueOrNull ?? const <Echo>[];

    if (text == null) {
      state = AsyncData(current.where((e) => e.id != id).toList());
      return null;
    }

    Echo? consumed;
    final updated = <Echo>[];
    for (final echo in current) {
      if (echo.id == id) {
        consumed = echo.copyWith(text: text);
        updated.add(consumed);
      } else {
        updated.add(echo);
      }
    }
    state = AsyncData(updated);
    return consumed;
  }

  /// Reader side of the loop: leave the one-line trace.
  Future<bool> leaveTrace(String echoId, String text) async {
    final repo = ref.read(echoRepositoryProvider);
    return repo.leaveTrace(echoId, text);
  }

  /// Viewing a reception burns it — the signal exists once.
  Future<void> burnReception(String echoId) async {
    final repo = ref.read(echoRepositoryProvider);
    await repo.burnReception(echoId);
    _receptions =
        _receptions.where((r) => r.echoId != echoId).toList();
    final echoes = state.valueOrNull ?? const <Echo>[];
    state = AsyncData([...echoes]);
  }

  /// Seals the echo, launches it into the ether and anchors it locally (no text).
  Future<void> sendEcho({
    required String text,
    required EchoColorTheme theme,
  }) async {
    final repo = ref.read(echoRepositoryProvider);
    final store = ref.read(localEchoStoreProvider);
    final random = Random();

    final echo = await repo.sendEcho(
      text: text,
      coordX: 0.12 + random.nextDouble() * 0.76,
      coordY: 0.18 + random.nextDouble() * 0.64,
      coordZ: 1.0, // born against the camera, then drifts
      theme: theme,
    );
    await store.addSealed(echo);
    final current = state.valueOrNull ?? const <Echo>[];
    state = AsyncData([echo, ...current]);
  }

  /// Forgets an echo (after post-read dissolution or interception elsewhere).
  void forget(String id) {
    final current = state.valueOrNull ?? const <Echo>[];
    state = AsyncData(current.where((e) => e.id != id).toList());
  }
}

final mapControllerProvider =
    AsyncNotifierProvider<MapController, List<Echo>>(MapController.new);
