import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../echo/data/echo_providers.dart';
import '../../echo/domain/reception.dart';

/// Bottle-in-the-sea signals, author side.
///
/// Deliberately separate from the star map: a signal landing must
/// re-render the sealed stars (their pulse), NOT re-emit the whole
/// map — the previous single-controller design paid for that with a
/// fake list re-emission on every reception.
///
/// Semantics (same as the backend): only UNSEEN receptions exist here;
/// viewing burns them, one look, then the void.
class ReceptionController extends AsyncNotifier<List<Reception>> {
  StreamSubscription<void>? _signals;
  Timer? _poll;

  @override
  Future<List<Reception>> build() async {
    ref.onDispose(() {
      _signals?.cancel();
      _poll?.cancel();
    });

    final repo = ref.watch(echoRepositoryProvider);

    // Live signals: demo simulation stream + gentle polling for the server.
    _signals = repo.receptionChanges().listen((_) => _refresh());
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());

    return _load();
  }

  Future<List<Reception>> _load() async {
    try {
      return await ref.read(echoRepositoryProvider).fetchReceptions();
    } catch (e) {
      debugPrint('[kenos.receptions] unreachable: $e');
      return state.valueOrNull ?? const <Reception>[];
    }
  }

  Future<void> _refresh() async {
    final fresh = await _load();
    final current = state.valueOrNull;
    if (current == null || !_sameReceptions(current, fresh)) {
      state = AsyncData(fresh);
    }
  }

  bool _sameReceptions(List<Reception> a, List<Reception> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].echoId != b[i].echoId || a[i].reply != b[i].reply) {
        return false;
      }
    }
    return true;
  }

  /// The unseen signal of a given sealed echo, if any.
  Reception? receptionFor(String echoId) {
    final receptions = state.valueOrNull ?? const <Reception>[];
    for (final reception in receptions) {
      if (reception.echoId == echoId) return reception;
    }
    return null;
  }

  /// Viewing a reception burns it — the signal exists once.
  Future<void> burn(String echoId) async {
    try {
      await ref
          .read(echoRepositoryProvider)
          .burnReception(echoId);
    } catch (e) {
      debugPrint('[kenos.receptions] burn failed: $e');
      return;
    }
    final current = state.valueOrNull ?? const <Reception>[];
    state = AsyncData(
      current.where((r) => r.echoId != echoId).toList(),
    );
  }
}

final receptionControllerProvider =
    AsyncNotifierProvider<ReceptionController, List<Reception>>(
      ReceptionController.new,
    );
