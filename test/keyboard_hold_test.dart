import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/application/map_controller.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/mindful_hold_star.dart';
import 'package:kenos/features/echo/data/echo_providers.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';
import 'package:kenos/features/echo/data/user_stats_store.dart';
import 'package:kenos/features/echo/domain/echo.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';
import 'package:kenos/features/echo/domain/read_scar.dart';

/// V3.48 — holding by KEYBOARD: the friction is the 3 s and the
/// reception field, never the finger. SPACE held on a focused star
/// arms the very same hold — released early, it rolls back; held
/// whole, it consumes. Beyond the reception field, the whisper —
/// never a hold.
void main() {
  late FocusNode node;
  late _SpyMap map;

  setUp(() {
    node = FocusNode(debugLabel: 'star');
    map = _SpyMap();
    MindfulHoldStar.farWhisperSpoken = false;
  });

  Future<void> boot(WidgetTester tester, {double reception = 1}) async {
    final echo = Echo(
      id: 'star-1',
      coordX: 0.5,
      coordY: 0.5,
      coordZ: 0.8,
      theme: EchoColorTheme.teal,
      createdAt: DateTime.now(),
    );
    map.echo = echo;
    map.revealed = echo.copyWith(text: 'un souffle');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapControllerProvider.overrideWith(() => map),
          localEchoStoreProvider.overrideWithValue(_InstantStore()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: MindfulHoldStar(
                  key: const ValueKey('star'),
                  echo: echo,
                  z: 0.8,
                  reception: reception,
                  focusNode: node,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    node.requestFocus();
    await tester.pump();
  }

  testWidgets('ESPACE tenue trois secondes : la même révélation', (tester) async {
    await boot(tester);
    expect(node.hasFocus, isTrue);
    // The keyboard's mark: a quiet teal ring where SPACE would hold.
    expect(find.byType(DecoratedBox), findsWidgets);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);

    expect(map.consumed, ['star-1'],
        reason: 'le clavier tient ce que le doigt tient');

    // Close the reading window, then absorb the store's secure-I/O
    // timeouts (the 2 s keychain writes fire timers that must die
    // before the test frame ends — the full-app harness does the
    // same after every gate).
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('ESPACE relâchée trop tôt : rien ne se consomme', (tester) async {
    await boot(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(seconds: 2));

    expect(map.consumed, isEmpty,
        reason: 'la friction est la durée — au clavier comme au doigt');
  });

  testWidgets('au-delà du champ : le murmure, jamais le hold', (tester) async {
    await boot(tester, reception: 0);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);

    expect(map.consumed, isEmpty);
    expect(map.consumed, isEmpty, reason: 'TROP LOIN — même pour ESPACE');
  });
}

/// A spy on the map's one gesture that matters: consumption.
class _SpyMap extends MapController {
  Echo? echo;
  Echo? revealed;
  final List<String> consumed = [];

  @override
  Future<List<Echo>> build() async =>
      echo == null ? const <Echo>[] : [echo!];

  @override
  Future<Echo?> consume(String id) async {
    consumed.add(id);
    return revealed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The store without the keychain: the test VM has no secure-storage
/// plugin, and the write guards leave 2 s timers pending past the
/// test frame. Reads empty, writes instant — semantics intact.
class _InstantStore extends LocalEchoStore {
  @override
  Future<void> addReadScar(ReadScar scar) async {}

  @override
  Future<void> recordEchoRead() async {}

  @override
  Future<List<ReadScar>> readScars() async => const <ReadScar>[];

  @override
  Future<UserStats> readStats() async => UserStats.empty();
}
