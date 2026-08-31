@Timeout(Duration(minutes: 2))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/echo/data/echo_repository.dart';
import 'package:kenos/features/echo/data/supabase_echo_repository.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';
import 'package:kenos/features/frequencies/data/frequency_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// REAL-ETHER smoke test — exercises the production client path against
/// a live Supabase project: on-device sealing (EchoCipher), Vault-escrow
/// key exchange at interception, own-echo map exclusion, single read.
///
/// Not part of CI (no credentials there): it runs only when the
/// project is wired, e.g.
///   flutter test test/cloud_smoke_test.dart \
///     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// Credentials are read from .env.cloud (make dev-cloud uses the same).
const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() {
  final configured = _url.isNotEmpty && _key.isNotEmpty;

  test(
    'Ether Seal sur l\'éther réel : sceller, échanger, déchiffrer, détruire',
    () async {
      final author = SupabaseClient(_url, _key);
      final reader = SupabaseClient(_url, _key);
      addTearDown(author.dispose);
      addTearDown(reader.dispose);

      await author.auth.signInAnonymously();
      await reader.auth.signInAnonymously();
      expect(author.auth.currentSession?.accessToken,
          isNot(reader.auth.currentSession?.accessToken),
          reason: 'deux anonymes distincts');

      const secret = 'un aveu scellé pour l\'éther réel 🌌';
      final repoAuthor = SupabaseEchoRepository(author);
      final repoReader = SupabaseEchoRepository(reader);

      // 1. The author's device seals and launches.
      final echo = await repoAuthor.sendEcho(
        text: secret,
        coordX: 0.42,
        coordY: 0.58,
        coordZ: 0.9,
        theme: EchoColorTheme.indigo,
      );
      expect(echo.isMine, isTrue);
      expect(echo.text, isNull, reason: 'jamais de texte côté client au vol');

      // 2. The author never sees it on their own map.
      final ownMap = await repoAuthor.fetchStarMap();
      expect(ownMap.map((e) => e.id), isNot(contains(echo.id)));

      // 3. A stranger does.
      final strangerMap = await repoReader.fetchStarMap();
      expect(strangerMap.map((e) => e.id), contains(echo.id));

      // 4. Interception: key exchange + authenticated decryption.
      final consumed = await repoReader.consumeEcho(echo.id);
      expect(consumed?.text, secret,
          reason: 'le scellé fait l\'aller-retour complet via l\'escrow');

      // 5. The winner's breath: a second read within 5 s is refused
      //    server-side (KENOS_RATE_LIMIT) — the echo is already gone,
      //    and friction applies to the victor too.
      await expectLater(
        repoReader.consumeEcho(echo.id),
        throwsA(
          isA<KenosException>().having(
            (e) => e.code,
            'code',
            KenosErrorCode.rateLimit,
          ),
        ),
      );
    },
    skip: configured
        ? false
        : 'SUPABASE_URL / SUPABASE_ANON_KEY absents (make dev-cloud fournit .env.cloud)');

    test('Symphonie réelle : l\'onde de A traverse l\'éther jusqu\'à B',
        () async {
      final author = SupabaseClient(_url, _key);
      final stranger = SupabaseClient(_url, _key);
      addTearDown(author.dispose);
      addTearDown(stranger.dispose);

      await author.auth.signInAnonymously();
      await stranger.auth.signInAnonymously();

      final repoAuthor = SupabaseFrequencyRepository(author);
      final repoStranger = SupabaseFrequencyRepository(stranger);

      // Waves live 60 s: earlier runs of this very test still breathe.
      // Emit at a run-unique spot so assertions only see THIS wave.
      final u = 0.02 + (DateTime.now().millisecondsSinceEpoch % 900) / 1000;
      const v = 0.03;

      // A emits.
      await repoAuthor.emit(
        offsetX: u,
        offsetY: v,
        noteIndex: 9,
        hueIndex: 2,
      );

      // A never hears themself at their own spot (waves from other
      // earlier runs may exist elsewhere — this spot is ours alone).
      final selfHeard = await repoAuthor.fetchNearby(
        centerX: u,
        centerY: v,
        radius: 0.005,
      );
      expect(
        selfHeard.where((w) => (w.offsetX - u).abs() < 0.001),
        isEmpty,
        reason: 'on ne s\'entend jamais soi-même',
      );

      // A stranger pointing at the same spot hears exactly that wave.
      final heard = await repoStranger.fetchNearby(
        centerX: u,
        centerY: v,
        radius: 0.005,
      );
      expect(heard, isNotEmpty, reason: 'l\'onde traverse le rayon');
      expect(heard.first.noteIndex, 9);
      expect(heard.first.hueIndex, 2);
      expect(heard.first.offsetX, closeTo(u, 0.001));
    },
    skip: configured
        ? false
        : 'SUPABASE_URL / SUPABASE_ANON_KEY absents (make dev-cloud fournit .env.cloud)',
  );

  test('Phénix réel : A lance, B lit et relance, C lit un momentum 1',
      () async {
    final a = SupabaseClient(_url, _key);
    final b = SupabaseClient(_url, _key);
    final c = SupabaseClient(_url, _key);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    addTearDown(c.dispose);
    await a.auth.signInAnonymously();
    await b.auth.signInAnonymously();
    await c.auth.signInAnonymously();

    final repoA = SupabaseEchoRepository(a);
    final repoB = SupabaseEchoRepository(b);
    final repoC = SupabaseEchoRepository(c);

    // A launches at a run-unique spot.
    final u = 0.05 + (DateTime.now().millisecondsSinceEpoch % 800) / 1000;
    final launched = await repoA.sendEcho(
      text: 'pensée portée puis relancée',
      coordX: u,
      coordY: 0.08,
      coordZ: 0.9,
      theme: EchoColorTheme.indigo,
    );

    // B intercepts: momentum 0.
    final consumedB = await repoB.consumeEcho(launched.id);
    expect(consumedB?.text, 'pensée portée puis relancée');
    expect(consumedB?.momentum, 0);

    // B re-seals it: the phoenix is B's own sealed star, momentum 1.
    final phoenix = await repoB.reboundEcho(
      sourceId: launched.id,
      parentMomentum: consumedB!.momentum,
      text: consumedB.text,
      coordX: u,
      coordY: 0.08,
      coordZ: 0.9,
    );
    expect(phoenix.momentum, 1);
    expect(phoenix.isMine, isTrue);

    // One rebound, once: the lineage burned.
    await expectLater(
      repoB.reboundEcho(
        sourceId: launched.id,
        parentMomentum: 0,
        text: consumedB.text,
        coordX: u,
        coordY: 0.08,
        coordZ: 0.9,
      ),
      throwsA(isA<KenosException>()),
    );

    // C intercepts the phoenix: momentum 1 travels with it.
    final consumedC = await repoC.consumeEcho(phoenix.id);
    expect(consumedC?.text, 'pensée portée puis relancée');
    expect(consumedC?.momentum, 1, reason: 'la comète a voyagé une fois');
  },
      skip: configured
          ? false
          : 'SUPABASE_URL / SUPABASE_ANON_KEY absents (make dev-cloud fournit .env.cloud)');
}
