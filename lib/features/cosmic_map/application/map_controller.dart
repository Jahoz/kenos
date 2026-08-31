import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../echo/data/echo_providers.dart';
import '../../echo/data/echo_repository.dart';
import '../../echo/domain/echo.dart';
import '../../echo/domain/echo_color_theme.dart';
import '../../echo/domain/echo_media.dart';

/// Stellar map controller: merges the ether (remote metadata, never the
/// text) and the user's sealed echoes (local store, sealed without
/// text). Bottle-in-the-sea signals live in [ReceptionController].
class MapController extends AsyncNotifier<List<Echo>> {
  @override
  Future<List<Echo>> build() async {
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
    return [...mine, ...remote];
  }

  /// Atomic interception of an echo.
  /// Returns the echo enriched with its text for the winner, `null` if
  /// someone else read it in the meantime (the echo is then removed from the map).
  Future<Echo?> consume(String id) async {
    final repo = ref.read(echoRepositoryProvider);
    final store = ref.read(localEchoStoreProvider);
    final content = await repo.consumeEcho(id);
    final current = state.valueOrNull ?? const <Echo>[];

    if (content == null) {
      state = AsyncData(current.where((e) => e.id != id).toList());
      return null;
    }

    Echo? consumed;
    final updated = <Echo>[];
    for (final echo in current) {
      if (echo.id == id) {
        consumed = Echo(
          id: echo.id,
          coordX: echo.coordX,
          coordY: echo.coordY,
          coordZ: echo.coordZ,
          theme: echo.theme,
          createdAt: echo.createdAt,
          text: content.text,
          media: content.media,
          mediaKind: echo.mediaKind,
          isMine: echo.isMine,
          momentum: content.momentum,
        );
        updated.add(consumed);
      } else {
        updated.add(echo);
      }
    }
    state = AsyncData(updated);
    unawaited(store.recordEchoRead());
    ref.invalidate(userStatsProvider);
    return consumed;
  }

  /// The Sling-Shot (phoenix): re-seal the just-read echo and give it
  /// velocity. The rebound lands as one's own sealed star, comet tail
  /// and all. Returns false when the ether refuses (window closed,
  /// cadence) — the UI stays honest, never loud.
  Future<bool> rebound({required Echo source, required String text}) async {
    final repo = ref.read(echoRepositoryProvider);
    final store = ref.read(localEchoStoreProvider);
    try {
      final phoenix = await repo.reboundEcho(
        sourceId: source.id,
        parentMomentum: source.momentum,
        text: text,
        // The comet relaunches from where it was intercepted.
        coordX: source.coordX,
        coordY: source.coordY,
        coordZ: max(0.3, source.coordZ),
      );
      final sealed = phoenix.copyWith(theme: source.theme);
      await store.addSealed(sealed);
      final current = state.valueOrNull ?? const <Echo>[];
      state = AsyncData([sealed, ...current]);
      return true;
    } catch (e) {
      debugPrint('[kenos.map] rebound refused: $e');
      return false;
    }
  }

  /// Reader side of the loop: leave the one-line trace.
  Future<bool> leaveTrace(String echoId, String text) async {
    final repo = ref.read(echoRepositoryProvider);
    final left = await repo.leaveTrace(echoId, text);
    if (left) {
      unawaited(ref.read(localEchoStoreProvider).recordTraceLeft());
      ref.invalidate(userStatsProvider);
    }
    return left;
  }

  /// Reader side: report an already consumed echo without its content.
  Future<bool> reportEcho(String echoId, EchoReportReason reason) {
    return ref.read(echoRepositoryProvider).reportEcho(echoId, reason);
  }

  /// Seals the echo, launches it into the ether and anchors it locally (no text).
  Future<void> sendEcho({
    required String text,
    required EchoColorTheme theme,
    EchoMediaDraft? media,
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
      media: media,
    );
    await store.addSealed(echo);
    unawaited(store.recordEchoSent());
    ref.invalidate(userStatsProvider);
    final current = state.valueOrNull ?? const <Echo>[];
    state = AsyncData([echo, ...current]);
  }

  /// V3.7a — Le Voyage: refresh what the traveller's eye can see.
  ///
  /// Fetches the visible rect (clamped to the server's [0,1]²) plus a
  /// margin, then MERGES: fresh rows upsert by id (new stars appear as
  /// you travel), stars that left the rect are kept (you may go back),
  /// and stars the ether no longer returns inside the rect are dropped
  /// (consumed elsewhere). Sealed stars are never touched.
  /// Slack around the visible rect sent to the ether AND used to
  /// decide which old stars the fresh answer may replace. One single
  /// constant: a star "in rect" is exactly a star the fetch could see.
  static const _travelSlack = 0.05;

  /// Last rect already synced — a stationary release or a jitter does
  /// not re-ask the ether.
  ({double loX, double loY, double hiX, double hiY})? _lastSyncedRect;

  Future<void> refreshViewport({
    required double minX,
    required double minY,
    required double maxX,
    required double maxY,
  }) async {
    final repo = ref.read(echoRepositoryProvider);
    final loX = (minX - _travelSlack).clamp(0.0, 1.0);
    final loY = (minY - _travelSlack).clamp(0.0, 1.0);
    final hiX = (maxX + _travelSlack).clamp(0.0, 1.0);
    final hiY = (maxY + _travelSlack).clamp(0.0, 1.0);
    if (hiX - loX <= 0 || hiY - loY <= 0) return;
    final synced = _lastSyncedRect;
    if (synced != null &&
        synced.loX <= loX &&
        synced.loY <= loY &&
        synced.hiX >= hiX &&
        synced.hiY >= hiY) {
      return; // already seen: nothing new beyond the last sync.
    }
    _lastSyncedRect = (loX: loX, loY: loY, hiX: hiX, hiY: hiY);

    final fresh = await repo.fetchStarMapInSector(
      loX,
      loY,
      hiX,
      hiY,
    );
    if (!state.hasValue) return;
    final current = [...(state.value ?? const <Echo>[])];

    final freshIds = fresh.map((e) => e.id).toSet();
    bool inRect(Echo e) =>
        e.coordX >= loX &&
        e.coordX <= hiX &&
        e.coordY >= loY &&
        e.coordY <= hiY;

    // Drop foreign stars the rect no longer returns (gone from the
    // ether); keep sealed ones whatever happens.
    final kept = current
        .where((e) => e.isMine || !inRect(e) || freshIds.contains(e.id))
        .toList();

    // Upsert fresh rows.
    for (final echo in fresh) {
      final index = kept.indexWhere((e) => e.id == echo.id);
      if (index == -1) {
        kept.add(echo);
      }
    }
    state = AsyncValue.data(kept);
  }

  /// Forgets an echo (after post-read dissolution or interception elsewhere).
  void forget(String id) {
    final current = state.valueOrNull ?? const <Echo>[];
    state = AsyncData(current.where((e) => e.id != id).toList());
  }
}

final mapControllerProvider =
    AsyncNotifierProvider<MapController, List<Echo>>(MapController.new);
