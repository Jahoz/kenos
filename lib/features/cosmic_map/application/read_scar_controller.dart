import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../echo/data/echo_providers.dart';
import '../../echo/domain/read_scar.dart';

/// Reading scars — the reader's own trail. Where a light was held and
/// dissolved, a faint contentless mark remains on THIS device only:
/// the journey of readings paints the sky. Nothing here ever leaves
/// the device, nothing here has content.
class ReadScarController extends AsyncNotifier<List<ReadScar>> {
  @override
  Future<List<ReadScar>> build() =>
      ref.watch(localEchoStoreProvider).readScars();

  /// Called when a consumption succeeded: the scar is pinned at the
  /// star's last orbital position.
  Future<void> record({
    required String echoId,
    required double worldX,
    required double worldY,
  }) async {
    final store = ref.read(localEchoStoreProvider);
    final scar = ReadScar(
      echoId: echoId,
      worldX: worldX.clamp(0, 1),
      worldY: worldY.clamp(0, 1),
      readAt: DateTime.now(),
    );
    await store.addReadScar(scar);
    final current = [...(state.valueOrNull ?? const <ReadScar>[])];
    current.insert(0, scar);
    state = AsyncValue.data(current);
  }
}

final readScarControllerProvider =
    AsyncNotifierProvider<ReadScarController, List<ReadScar>>(
      ReadScarController.new,
    );
