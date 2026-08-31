import 'dart:async';
import 'dart:math';

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
        consumed = echo.copyWith(text: content.text, media: content.media);
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

  /// Forgets an echo (after post-read dissolution or interception elsewhere).
  void forget(String id) {
    final current = state.valueOrNull ?? const <Echo>[];
    state = AsyncData(current.where((e) => e.id != id).toList());
  }
}

final mapControllerProvider =
    AsyncNotifierProvider<MapController, List<Echo>>(MapController.new);
