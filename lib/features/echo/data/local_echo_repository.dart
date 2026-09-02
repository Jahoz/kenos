import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import '../../../core/utils/parallax_math.dart';
import '../domain/echo.dart';
import '../domain/echo_cipher.dart';
import '../domain/echo_color_theme.dart';
import '../domain/echo_excerpt.dart';
import '../domain/echo_media.dart';
import '../domain/reception.dart';
import 'echo_repository.dart';
import 'local_echo_store.dart';
import 'sector_grid.dart';
/// Offline demo mode: simulates the ether locally with the same semantics
/// as the backend (atomic single read, texts never on the map) — plus the
/// bottle-in-the-sea loop: echoes you launch get intercepted after a while,
/// sometimes with a trace from the stranger who read them.
///
/// Used for backend-less development, unit tests, and as a fallback
/// when the backend is unreachable at boot.
class LocalEchoRepository implements EchoRepository {
  LocalEchoRepository({
    this.latency = const Duration(milliseconds: 450),
    int randomSeed = 7,
    this.simulateReceptions = true,
    LocalEchoStore? store,
  })  : _random = Random(randomSeed),
        _store = store;

  final Duration latency;
  final Random _random;
  final LocalEchoStore? _store;

  /// When true, launched echoes get intercepted on a demo timer.
  final bool simulateReceptions;

  final Map<String, _DemoEcho> _echoes = {};
  final Set<String> _consumed = {};

  /// The reader's 10-minute decision window (same semantics as
  /// kenos_lineages): momentum + the parent's theme + the text the
  /// reader may re-seal.
  final Map<String, _DemoLineage> _lineages = {};
  final Set<String> _reported = {};

  final List<Reception> _receptions = [];
  final _changes = StreamController<void>.broadcast();
  final Map<String, Timer> _pendingDeliveries = {};
  bool _loaded = false;
  Future<void>? _seedFuture;

  static const _demoTraces = [
    'Reçu. Respiré. Merci.',
    'Tu n\u2019es pas seul dans le noir.',
    'Ça m\u2019a fait du bien de lire ça.',
    'Je te vois. Ça va aller.',
    'Ton écho a trouvé quelqu\u2019un ce soir.',
    'Lu deux fois. Brûlé une seule.',
    'J\u2019aurais voulu l\u2019écrire moi-même.',
    'Garde le cap. Je le garde avec toi.',
  ];

  factory LocalEchoRepository.seeded({
    Duration latency = const Duration(milliseconds: 450),
    LocalEchoStore? store,
  }) {
    final repo = LocalEchoRepository(latency: latency, store: store);
    repo._seedFuture = repo._seed();
    return repo;
  }

  /// Demo parity with the backend: the seeded ether holds only ciphertext.
  /// Each seed is sealed under its own ephemeral key, exactly as a real
  /// author's device would before launching. Excerpt-carrying seeds seal
  /// their door reference under the same key — a door opens exactly like
  /// the text: for the single winner, never on the map.
  Future<void> _seed() async {
    const seeds = [
      ('Je souris toute la journée puis je pleure dans le métro.', 'INDIGO', null),
      ('Je n\'ai jamais osé dire que ce travail m\'épuisait.', 'TEAL', null),
      (
        'J\'ai peur du silence, parce que j\'y entends tout ce que je fuis.',
        'LUMEN',
        null,
      ),
      (
        'Je fais semblant depuis si longtemps que je ne sais plus qui je suis.',
        'INDIGO',
        null,
      ),
      (
        'Je voudrais disparaître quelques semaines, sans prévenir personne.',
        'TEAL',
        null,
      ),
      (
        'Je n\'ai jamais dit à mon père à quel point j\'étais fier de lui.',
        'LUMEN',
        null,
      ),
      (
        'Parfois je regarde les inconnus et je me demande qui les serre dans ses bras.',
        'INDIGO',
        null,
      ),
      ('Je répète mes conversations du soir avant de m\'endormir.', 'TEAL', null),
      ('J\'ai l\'impression de réussir ma vie et de rater la mienne.', 'LUMEN', null),
      ('Le vide me terrifie, et pourtant c\'est là que je respire.', 'INDIGO', null),
      ('Je porte un secret si lourd que mon dos en courbe.', 'TEAL', null),
      (
        'Personne ne sait que j\'ai failli tout arrêter, l\'an dernier.',
        'LUMEN',
        null,
      ),
      (
        'Cette chanson, je ne l\'écoute jamais devant personne.',
        'INDIGO',
        EchoExcerpt(kind: EchoExcerptKind.song, id: '4cOdK2wGLETKBW3PvgPWqT'),
      ),
      (
        'Quand le vide crie trop fort, je laisse la machine murmurer.',
        'TEAL',
        EchoExcerpt(
          kind: EchoExcerptKind.video,
          id: 'jfKfPfyJRdk',
          startSeconds: 0,
        ),
      ),
    ];
    // Volume parity (montée en charge): the demo ether carries a galaxy,
    // not a handful — otherwise demo mode can never reveal the costs the
    // real ether pays. The curated confidés stay the soul; the crowd
    // cycles them across varied orbits, depths and ages, comets included.
    final crowd = <(String, String, EchoExcerpt?)>[...seeds];
    final textOnly = seeds.where((s) => s.$3 == null).toList();
    for (var n = 0; n < 106; n++) {
      final (text, theme, _) = textOnly[n % textOnly.length];
      crowd.add((text, theme, null));
    }
    for (final (text, theme, excerpt) in crowd) {
      final id = _uuid();
      final sealed = await EchoCipher.seal(text);
      _echoes[id] = _DemoEcho(
        echo: Echo(
          id: id,
          coordX: 0.08 + _random.nextDouble() * 0.84,
          coordY: 0.14 + _random.nextDouble() * 0.7,
          coordZ: 0.15 + _random.nextDouble() * 0.75,
          theme: EchoColorTheme.fromWire(theme),
          createdAt: DateTime.now().subtract(
            Duration(minutes: _random.nextInt(60 * 24 * 30)),
          ),
          // A carried thought travels a wilder arc: some crowd stars
          // are comets, so the demo map shows the phoenix tails too.
          momentum: _random.nextDouble() < 0.08
              ? 1 + _random.nextInt(3)
              : 0,
          // Map metadata only: the door's KIND travels, the door itself
          // lives sealed (below) until the single winner opens it.
          mediaKind: excerpt?.kind.mediaKind,
        ),
        sealed: sealed,
        sealedRef: excerpt == null
            ? null
            : await EchoCipher.sealBytesWithKey(
                Uint8List.fromList(utf8.encode(excerpt.ref)),
                sealed.keyB64,
              ),
      );
    }
  }

  /// Sealing the demo ether is asynchronous — every read waits for it.
  Future<void> _ready() async {
    await _seedFuture;
    await _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded || _store == null) {
      _loaded = true;
      return;
    }
    _loaded = true;
    _receptions.addAll(await _store.readReceptions());
  }

  Future<void> _persist() async {
    await _store?.writeReceptions(_receptions);
  }

  @override
  Stream<void> receptionChanges() => _changes.stream;

  /// Test/demo hook: deliver a reception immediately and deterministically.
  Future<void> deliverReception(String echoId, {String? reply}) async {
    await _ensureLoaded();
    final driftSeconds = 2 * 3600 + _random.nextInt(70 * 3600);
    _receptions.insert(
      0,
      Reception(
        echoId: echoId,
        readAt: DateTime.now(),
        driftSeconds: driftSeconds,
        reply: reply,
      ),
    );
    await _persist();
    _changes.add(null);
  }

  void _scheduleReception(String echoId) {
    if (!simulateReceptions) return;
    _pendingDeliveries[echoId] = Timer(
      Duration(seconds: 12 + _random.nextInt(18)),
      () {
        _pendingDeliveries.remove(echoId);
        // Not every stranger leaves a trace: silence is also an answer.
        final reply = _random.nextDouble() < 0.65
            ? _demoTraces[_random.nextInt(_demoTraces.length)]
            : null;
        deliverReception(echoId, reply: reply);
      },
    );
  }

  @override
  Future<List<Echo>> fetchStarMap() => fetchStarMapInSector(0, 0, 1, 1);

  @override
  Future<List<Echo>> fetchStarMapInSector(
    double minX,
    double minY,
    double maxX,
    double maxY, {
    int maxTotal = SectorGrid.maxTotal,
  }) async {
    await _ready();
    await Future<void>.delayed(latency);
    final visible = _echoes.values
        .where((e) => !_consumed.contains(e.echo.id))
        .map((e) => e.echo)
        .where((e) =>
            e.coordX >= minX &&
            e.coordX <= maxX &&
            e.coordY >= minY &&
            e.coordY <= maxY)
        .toList();
    // Same culling as the backend RPC: the demo ether stays a galaxy,
    // never a scrollable feed.
    return SectorGrid.cull(visible, maxTotal: maxTotal);
  }

  @override
  Future<ConsumedEcho?> consumeEcho(String id) async {
    await _ready();
    final demo = _echoes[id];
    if (demo == null || _consumed.contains(id)) {
      await Future<void>.delayed(latency);
      return null;
    }
    // Latency BEFORE the lock: two simultaneous consumers cannot
    // both win — the second one finds the row already destroyed.
    await Future<void>.delayed(latency);
    if (_consumed.contains(id)) return null;
    _consumed.add(id);
    // The key is exchanged at interception: decryption happens here,
    // only for the single winner. The lineage opens the reader's
    // 10-minute phoenix window (momentum + inherited theme).
    final text =
        await EchoCipher.open(demo.sealed.keyB64, demo.sealed.payloadB64);
    EchoExcerpt? excerpt;
    if (demo.sealedRef != null) {
      final refBytes = await EchoCipher.openBytes(
        demo.sealed.keyB64,
        demo.sealedRef!,
      );
      excerpt = EchoExcerpt.fromRef(utf8.decode(refBytes));
    }
    _lineages[id] = _DemoLineage(
      momentum: demo.echo.momentum,
      theme: demo.echo.theme,
      text: text,
    );
    return ConsumedEcho(
      text: text,
      excerpt: excerpt,
      momentum: demo.echo.momentum,
    );
  }

  @override
  Future<Echo> sendEcho({
    required String text,
    required double coordX,
    required double coordY,
    required double coordZ,
    required EchoColorTheme theme,
    EchoMediaDraft? media,
    EchoExcerpt? excerpt,
  }) async {
    await Future<void>.delayed(latency);
    if (media != null && excerpt != null) {
      throw const KenosException(KenosErrorCode.invalid);
    }
    final id = _uuid();
    final echo = Echo(
      id: id,
      coordX: ParallaxMath.clamp(coordX, 0, 1),
      coordY: ParallaxMath.clamp(coordY, 0, 1),
      coordZ: ParallaxMath.clamp(coordZ, 0.05, 1),
      theme: theme,
      createdAt: DateTime.now(),
      isMine: true,
      // The sealed echo carries the door's KIND (metadata for the
      // map) but never the door itself — the author loses it too.
      mediaKind: media?.kind ?? excerpt?.kind.mediaKind,
    );
    _scheduleReception(id);
    return echo;
  }

  @override
  Future<Echo> reboundEcho({
    required String sourceId,
    required int parentMomentum,
    required String text,
    required double coordX,
    required double coordY,
    required double coordZ,
  }) async {
    await Future<void>.delayed(latency);
    final lineage = _lineages[sourceId];
    if (lineage == null ||
        lineage.momentum != parentMomentum ||
        lineage.consumedAt.isBefore(
          DateTime.now().subtract(const Duration(minutes: 10)))) {
      throw const KenosException(KenosErrorCode.invalid);
    }
    final sealed = await EchoCipher.seal(text);
    final id = _uuid();
    final echo = Echo(
      id: id,
      coordX: ParallaxMath.clamp(coordX, 0, 1),
      coordY: ParallaxMath.clamp(coordY, 0, 1),
      coordZ: ParallaxMath.clamp(coordZ, 0.05, 1),
      // The phoenix inherits its parent's color: the comet keeps its hue.
      theme: lineage.theme,
      createdAt: DateTime.now(),
      isMine: true,
      momentum: lineage.momentum + 1,
    );
    _echoes[id] = _DemoEcho(echo: echo, sealed: sealed);
    // One rebound, once: the lineage burns with the decision.
    _lineages.remove(sourceId);
    return echo;
  }

  @override
  Future<bool> leaveTrace(String echoId, String text) async {
    await Future<void>.delayed(latency);
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 140) {
      throw const KenosException(KenosErrorCode.invalid);
    }
    // In demo mode, traces left on the seeded ether vanish into the void.
    return true;
  }

  @override
  Future<bool> reportEcho(String echoId, EchoReportReason reason) async {
    await _ready();
    await Future<void>.delayed(latency);
    if (!_consumed.contains(echoId)) {
      throw const KenosException(KenosErrorCode.rateLimit);
    }
    return _reported.add(echoId);
  }

  @override
  Future<String?> excerptPreviewUrl(String trackId) async {
    // Demo parity: the voice inside the void is a best-effort
    // server-side resolution — offline, it always declines and the
    // door alone remains.
    await Future<void>.delayed(latency);
    return null;
  }

  @override
  Future<List<Reception>> fetchReceptions() async {
    await _ensureLoaded();
    await Future<void>.delayed(latency);
    // Mirror the server: only unseen receptions come back.
    return _receptions.where((r) => !r.seen).toList();
  }

  @override
  Future<void> burnReception(String echoId) async {
    await _ensureLoaded();
    final index = _receptions.indexWhere((r) => r.echoId == echoId);
    if (index == -1) return;
    _receptions[index] = _receptions[index].copyWith(seen: true);
    await _persist();
  }

  String _uuid() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
        '${hex(4)}${hex(5)}-${hex(6)}${hex(7)}-'
        '${hex(8)}${hex(9)}-${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
  }
}

class _DemoLineage {
  _DemoLineage({required this.momentum, required this.theme, required this.text})
      : consumedAt = DateTime.now();

  final int momentum;
  final EchoColorTheme theme;
  final String text;
  final DateTime consumedAt;
}

class _DemoEcho {
  _DemoEcho({required this.echo, required this.sealed, this.sealedRef});
  final Echo echo;

  /// What the demo "ether" holds: ciphertext + the sealed key escrow.
  /// The plaintext exists nowhere — not even here.
  final SealedEchoContent sealed;

  /// A sealed cultural door reference (V3.10 parity): opaque until the
  /// single winner unseals it at interception.
  final Uint8List? sealedRef;
}
