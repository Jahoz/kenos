import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/echo/data/local_echo_store.dart';
import 'package:kenos/features/echo/domain/echo.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';
import 'package:kenos/features/echo/domain/read_scar.dart';
import 'package:kenos/features/echo/domain/reception.dart';

/// The secure store's safety nets (audit 2026-09-23): keychain
/// failures, wedged I/O and corrupted payloads must never take the
/// experience down — the memory cache and honest empties carry it.
void main() {
  Echo sealedEcho(String id) => Echo(
        id: id,
        coordX: 0.5,
        coordY: 0.5,
        coordZ: 0.5,
        theme: EchoColorTheme.teal,
        createdAt: DateTime.now(),
        isMine: true,
      );

  group('the keychain misbehaves — the sky keeps breathing', () {
    test('a throwing read falls back to the memory cache', () async {
      final store = LocalEchoStore(storage: const _ThrowingStorage());
      await store.setOnboarded(); // writes to memory, swallows the throw
      expect(await store.hasOnboarded(), isTrue);
    });

    test('a throwing write never crashes — the value lives in memory',
        () async {
      final store = LocalEchoStore(storage: const _ThrowingStorage());
      await store.addSealed(sealedEcho('e1'));
      expect((await store.sealedEchoes()).map((e) => e.id), ['e1']);
    });

    test('a wedged read times out and falls back (never freezes)',
        () async {
      final store = LocalEchoStore(
        storage: const _WedgedStorage(),
        ioTimeout: const Duration(milliseconds: 30),
      );
      final stopwatch = Stopwatch()..start();
      expect(await store.hasOnboarded(), isFalse); // nothing in memory
      expect(stopwatch.elapsed >= const Duration(milliseconds: 30),
          isTrue, reason: 'le timeout a bien borné l\'attente');
      expect(stopwatch.elapsed < const Duration(seconds: 2), isTrue,
          reason: 'l\'attente est le timeout injecté, pas celui du produit');
    });

    test('a wedged write times out silently', () async {
      final store = LocalEchoStore(
        storage: const _WedgedStorage(),
        ioTimeout: const Duration(milliseconds: 20),
      );
      await store.setOnboarded();
      expect(await store.hasOnboarded(), isTrue,
          reason: 'la mémoire cache tient la valeur pendant le blocage');
    });
  });

  group('the payload rots — honesty over crashes', () {
    test('corrupted sealed echoes read as empty, not as an error', () async {
      final storage = _MemStorage();
      await storage.write(
          key: 'kenos.sealed_echoes', value: '{not json at all');
      final store = LocalEchoStore(storage: storage);
      expect(await store.sealedEchoes(), isEmpty);
    });

    test('corrupted receptions and stats read as empty/defaults', () async {
      final storage = _MemStorage();
      await storage.write(key: 'kenos.receptions', value: '["broken"');
      await storage.write(key: 'kenos.user_stats', value: 'null');
      final store = LocalEchoStore(storage: storage);
      expect(await store.readReceptions(), isEmpty);
      expect((await store.readStats()).totalEchosSent, 0);
    });

    test('corrupted scars read as empty', () async {
      final storage = _MemStorage();
      await storage.write(key: 'kenos.read_scars', value: '[[]]');
      final store = LocalEchoStore(storage: storage);
      expect(await store.readScars(), isEmpty);
    });
  });

  group('the caps hold — the device forgets gracefully', () {
    test('sealed echoes cap at 50, newest first', () async {
      final store = LocalEchoStore(storage: _MemStorage());
      for (var i = 0; i < 55; i++) {
        await store.addSealed(sealedEcho('e$i'));
      }
      final echoes = await store.sealedEchoes();
      expect(echoes, hasLength(50));
      expect(echoes.first.id, 'e54',
          reason: 'le plus récent reste en tête');
      expect(echoes.any((e) => e.id == 'e0'), isFalse,
          reason: 'les plus anciens cèdent leur place');
    });

    test('read scars cap at 80, newest first, no duplicates', () async {
      final store = LocalEchoStore(storage: _MemStorage());
      for (var i = 0; i < 85; i++) {
        await store.addReadScar(ReadScar(
          echoId: 's$i',
          worldX: 0.5,
          worldY: 0.5,
          readAt: DateTime.now(),
        ));
      }
      // Re-recording an existing scar moves it, never duplicates.
      await store.addReadScar(ReadScar(
        echoId: 's50',
        worldX: 0.5,
        worldY: 0.5,
        readAt: DateTime.now(),
      ));
      final scars = await store.readScars();
      expect(scars, hasLength(80));
      expect(scars.first.echoId, 's50');
      expect(scars.where((s) => s.echoId == 's50'), hasLength(1));
    });

    test('scars older than 30 days dissolve on read', () async {
      final store = LocalEchoStore(storage: _MemStorage());
      await store.addReadScar(ReadScar(
        echoId: 'old',
        worldX: 0.5,
        worldY: 0.5,
        readAt: DateTime.now().subtract(const Duration(days: 31)),
      ));
      expect(await store.readScars(), isEmpty);
    });
  });

  group('LA BRAISE — the honest death erases everything', () {
    test('eraseAll clears memory and the keychain', () async {
      final storage = _MemStorage();
      final store = LocalEchoStore(storage: storage);
      await store.setOnboarded();
      await store.addSealed(sealedEcho('e1'));
      await store.writeReceptions([
        Reception(echoId: 'e1', readAt: DateTime.now(), driftSeconds: 42),
      ]);
      final uid = await store.localUserId();
      expect(uid, isNotEmpty);

      await store.eraseAll();

      expect(await store.hasOnboarded(), isFalse);
      expect(await store.sealedEchoes(), isEmpty);
      expect(await store.readReceptions(), isEmpty);
      expect(storage.data, isEmpty, reason: 'le trousseau lui-même est vide');
      // A reborn stranger gets a NEW identity, not the corpse's.
      expect(await store.localUserId(), isNot(uid));
    });

    test('eraseAll survives a refusing keychain (memory already dark)',
        () async {
      final store = LocalEchoStore(storage: const _ThrowingStorage());
      await store.setOnboarded();
      await store.eraseAll();
      expect(await store.hasOnboarded(), isFalse);
    });
  });

  group('the anonymous identity is stable and unique-shaped', () {
    test('localUserId is a v4 uuid, stable across calls', () async {
      final store = LocalEchoStore(storage: _MemStorage());
      final a = await store.localUserId();
      final b = await store.localUserId();
      expect(a, b);
      final v4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}'
          r'-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(v4.hasMatch(a), isTrue,
          reason: 'un uuid v4, comme le serveur en attend');
    });

    test('two stores (two devices) draw different identities', () async {
      final a = await LocalEchoStore(storage: _MemStorage()).localUserId();
      final b = await LocalEchoStore(storage: _MemStorage()).localUserId();
      expect(a, isNot(b));
    });
  });

  group('the memory cache serves until the keychain answers', () {
    test('a cold cache reads through once, then memory serves', () async {
      final storage = _CountingStorage();
      final writer = LocalEchoStore(storage: storage);
      await writer.setOnboarded();

      // Same keychain, cold memory: the first read goes through.
      final reader = LocalEchoStore(storage: storage);
      expect(await reader.hasOnboarded(), isTrue,
          reason: 'la valeur survit au redémarrage de l\'app');
      await reader.hasOnboarded();
      expect(storage.reads, 1,
          reason: 'la deuxième lecture sert la mémoire cache');
    });
  });
}

/// In-memory fake with real read/write/delete semantics.
class _MemStorage implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<bool> containsKey({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async =>
      data.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async =>
      data.remove(key);

  @override
  Future<void> deleteAll({
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async =>
      data.clear();

  @override
  Future<String?> read({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async =>
      data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async {
    if (value != null) data[key] = value;
  }

  @override
  Future<Map<String, String>> readAll({
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async =>
      Map.of(data);

  // The plugin's listener plumbing is never touched by the store.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Counts reads (cache behaviour proof).
class _CountingStorage extends _MemStorage {
  int reads = 0;

  @override
  Future<String?> read({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async {
    reads++;
    return super.read(key: key);
  }
}

/// Every call throws — the keychain refuses everything.
class _ThrowingStorage implements FlutterSecureStorage {
  const _ThrowingStorage();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw Exception('keychain unavailable');
  }
}

/// Every call hangs forever — a wedged keychain I/O.
class _WedgedStorage implements FlutterSecureStorage {
  const _WedgedStorage();

  static final Future<String?> _never = Completer<String?>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => _never;
}
