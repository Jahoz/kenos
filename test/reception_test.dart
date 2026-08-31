import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/echo/data/echo_repository.dart';
import 'package:kenos/features/echo/data/local_echo_repository.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';
import 'package:kenos/features/echo/domain/reception.dart';

void main() {
  LocalEchoRepository newRepo() => LocalEchoRepository(
        latency: const Duration(milliseconds: 5),
        simulateReceptions: false,
      );

  Future<String> launchEcho(LocalEchoRepository repo) => repo
      .sendEcho(
        text: 'un aveu',
        coordX: 0.5,
        coordY: 0.5,
        coordZ: 1,
        theme: EchoColorTheme.teal,
      )
      .then((e) => e.id);

  group('Reception model', () {
    test('poetic distance: UA beyond 1e8 km, thin separators', () {
      final long = Reception(
        echoId: 'e',
        readAt: DateTime(2026, 1, 2),
        driftSeconds: 26 * 3600,
      );
      expect(long.distanceLabel, contains('UA'));
      expect(long.driftLabel, '26 H 00 MIN');

      final short = Reception(
        echoId: 'e',
        readAt: DateTime(2026, 1, 2),
        driftSeconds: 300,
      );
      expect(short.distanceLabel, contains('KM'));
      expect(short.driftLabel, '5 MIN');
    });

    test('local serialization round-trip', () {
      final reception = Reception(
        echoId: 'id-1',
        readAt: DateTime(2026, 1, 2, 3, 4),
        driftSeconds: 3600,
        reply: 'Reçu. Respiré. Merci.',
      );
      final restored = Reception.fromJson(reception.toJson());
      expect(restored.echoId, 'id-1');
      expect(restored.reply, 'Reçu. Respiré. Merci.');
      expect(restored.driftSeconds, 3600);
      expect(restored.readAt, DateTime(2026, 1, 2, 3, 4));
    });
  });

  group('LocalEchoRepository — bottle in the sea', () {
    test('no simulation: nothing lands on its own', () async {
      final repo = newRepo();
      await launchEcho(repo);
      expect(await repo.fetchReceptions(), isEmpty);
    });

    test('delivered reception: seen once, then burned', () async {
      final repo = newRepo();
      final echoId = await launchEcho(repo);
      await repo.deliverReception(echoId, reply: 'Je te vois.');

      final receptions = await repo.fetchReceptions();
      expect(receptions.length, 1);
      expect(receptions.single.reply, 'Je te vois.');
      expect(receptions.single.echoId, echoId);

      // View = burn: the signal never comes back.
      await repo.burnReception(echoId);
      expect(await repo.fetchReceptions(), isEmpty);
    });

    test('leaveTrace: one line, length-validated', () async {
      final repo = newRepo();
      final echoId = await launchEcho(repo);
      expect(await repo.leaveTrace(echoId, '  merci  '), isTrue);
      await expectLater(
        repo.leaveTrace(echoId, 'x' * 141),
        throwsA(isA<KenosException>()),
      );
    });

    test('receptionChanges emits when a signal lands', () async {
      final repo = newRepo();
      final echoId = await launchEcho(repo);
      var emitted = 0;
      final sub = repo.receptionChanges().listen((_) => emitted++);
      await repo.deliverReception(echoId);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emitted, 1);
      await sub.cancel();
    });
  });
}
