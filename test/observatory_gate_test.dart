import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kenos/features/observatory/data/admin_providers.dart';
import 'package:kenos/features/observatory/data/admin_repository.dart';
import 'package:kenos/features/observatory/data/local_admin_repository.dart';
import 'package:kenos/features/observatory/domain/admin_metrics.dart';
import 'package:kenos/features/observatory/presentation/ledger_csv.dart';
import 'package:kenos/features/observatory/presentation/observatory_screen.dart';

void main() {
  group('AdminCensus (domain)', () {
    test('the census parses the ether\'s shapes', () {
      final census = AdminCensus.fromJson({
        'echo_ages': {'fresh': 3, 'week': 2, 'ancient': 1},
        'media_kinds': {'TEXT': 4, 'SONG': 2},
        'themes': {'TEAL': 3, 'INDIGO': 2, 'LUMEN': 1},
      });
      expect(census.fresh, 3);
      expect(census.drifting, 6);
      expect(census.mediaKinds['TEXT'], 4);
      expect(census.themes['LUMEN'], 1);
    });

    test('an absent census is an empty sky, never an error', () {
      final census = AdminCensus.fromJson({});
      expect(census.drifting, 0);
      expect(census.mediaKinds, isEmpty);
      expect(census.themes, isEmpty);
    });
  });

  group('LedgerCsv (the guardian\'s archive)', () {
    test('the register wears the wire\'s vocabulary, one row per day', () {
      final csv = buildLedgerCsv(_metrics().series);
      final lines = csv.trim().split('\n');
      expect(lines, hasLength(31)); // the header + thirty days
      expect(
        lines.first,
        'day,echoes_launched,echoes_consumed,echoes_rebound,traces_left,'
        'reports_filed,corpses_seeded,corpses_closed,lines_contributed,'
        'new_users,active_readers,salons_seeded,corpses_reported,'
        'corpses_retracted',
      );
      // Only counters and dates — never a text, never a name.
      expect(lines[1].startsWith('2026-09-'), isTrue);
      expect(lines[1].contains(RegExp(r'[A-Za-z]')), isFalse);
    });

    test('an empty sky archives its header, honestly', () {
      expect(buildLedgerCsv(const []).trim().split('\n'), hasLength(1));
    });
  });

  group('LocalAdminRepository (demo parity)', () {
    test('empty words never cross the threshold', () async {
      final repo = LocalAdminRepository();
      expect(
        () => repo.signIn('  ', 'x'),
        throwsA(isA<GuardianAuthException>()),
      );
      expect(repo.isSignedIn, isFalse);
    });

    test('any true pair opens the demo observatory, iso-semantic', () async {
      final repo = LocalAdminRepository();
      await repo.signIn('gardien@kenos.local', 'long-secret');
      expect(repo.isSignedIn, isTrue);
      final metrics = await repo.fetchMetrics();
      expect(metrics.series, hasLength(30));
      expect(metrics.isSilent, isFalse);
      expect(metrics.live.usersTotal, greaterThan(0));
      await repo.signOut();
      expect(repo.isSignedIn, isFalse);
    });

    test('the demo census sums to the drift, like the server', () async {
      final repo = LocalAdminRepository();
      await repo.signIn('gardien@kenos.local', 'demo');
      final metrics = await repo.fetchMetrics();
      final census = metrics.census;
      expect(census.drifting, metrics.live.echoesDrifting);
      expect(
        census.mediaKinds.values.fold<int>(0, (a, b) => a + b),
        metrics.live.echoesDrifting,
      );
      expect(
        census.themes.values.fold<int>(0, (a, b) => a + b),
        metrics.live.echoesDrifting,
      );
    });

    test('the demo sky is deterministic — same shapes every run', () async {
      final a = LocalAdminRepository();
      final b = LocalAdminRepository();
      await a.signIn('gardien@kenos.local', 'demo');
      await b.signIn('gardien@kenos.local', 'demo');
      final first = await a.fetchMetrics();
      final second = await b.fetchMetrics();
      expect(
        first.series
            .map((d) => '${d.day}:${d.launched}/${d.consumed}')
            .toList(),
        second.series
            .map((d) => '${d.day}:${d.launched}/${d.consumed}')
            .toList(),
      );
    });
  });

  group('ObservatoryScreen', () {
    testWidgets('refused words are answered, the threshold stays', (
      tester,
    ) async {
      await _pump(tester, repo: _RefusingRepo());
      await _cross(tester, 'intrus@kenos.local', 'mauvais mot');
      expect(find.text('LE SEUIL REFUSE CES MOTS.'), findsOneWidget);
      expect(find.text('L\'ÉTAT DU CIEL'), findsNothing);
    });

    testWidgets('the guardian reads the shapes, never a message', (
      tester,
    ) async {
      await _pump(tester, repo: _FakeRepo());
      await _cross(tester, 'gardien@kenos.local', 'le long secret');
      expect(find.text('L\'ÉTAT DU CIEL'), findsOneWidget);
      expect(find.text('412'), findsOneWidget); // users_total, a count only
      expect(find.text('LE SPECTRE — 30 JOURS'), findsOneWidget);
      expect(find.text('LA GRILLE DES SECTEURS'), findsOneWidget);
    });

    testWidgets('RAFRAÎCHIR asks the ether again — never live', (tester) async {
      final repo = _FakeRepo();
      await _pump(tester, repo: repo);
      await _cross(tester, 'gardien@kenos.local', 'le long secret');
      expect(repo.fetches, 1);
      await tester.tap(find.text('RAFRAÎCHIR'));
      await tester.pumpAndSettle();
      expect(repo.fetches, 2);
      expect(find.text('L\'ÉTAT DU CIEL'), findsOneWidget);
    });

    testWidgets('the window follows the guardian\'s eye', (tester) async {
      final repo = _FakeRepo();
      await _pump(tester, repo: repo);
      await _cross(tester, 'gardien@kenos.local', 'le long secret');
      // The ether is always asked for its widest sky — the RPC's
      // 90-day ceiling; the window only trims what the eye sees.
      expect(repo.askedDays, 90);
      expect(find.text('LE SPECTRE — 30 JOURS'), findsOneWidget);
      // The ledger is long: the windows live under the fold.
      await tester.ensureVisible(find.text('7 J'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 J'));
      await tester.pumpAndSettle();
      expect(find.text('LE SPECTRE — 7 JOURS'), findsOneWidget);
      await tester.ensureVisible(find.text('90 J'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('90 J'));
      await tester.pumpAndSettle();
      expect(find.text('LE SPECTRE — 90 JOURS'), findsOneWidget);
    });

    testWidgets('the spectrum has four breaths', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, repo: _FakeRepo());
      await _cross(tester, 'gardien@kenos.local', 'le long secret');
      // Default breath: the echoes' sowing and reading.
      expect(find.text('semés'), findsOneWidget);
      expect(find.text('lus'), findsOneWidget);

      await tester.ensureVisible(find.text('CADAVRES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CADAVRES'));
      await tester.pumpAndSettle();
      // The legend wears the new breath's words...
      expect(find.text('fermés'), findsOneWidget);
      // ...and the bars speak it: corpses seeded 2, closed 1 (the
      // fake sky's daily truth).
      expect(
        find.bySemanticsLabel(
          RegExp("jusqu'à 2 semés et 1 fermés par jour"),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the moon faces its past self when two moons exist', (
      tester,
    ) async {
      await _pump(tester, repo: _FakeRepo(metrics: _metricsTwoMoons()));
      await _cross(tester, 'gardien@kenos.local', 'le long secret');
      await tester.ensureVisible(find.text('LA LUNE CONTRE LA LUNE'));
      await tester.pumpAndSettle();
      expect(find.text('LA LUNE CONTRE LA LUNE'), findsOneWidget);
      // The fake sky: 100 echoes sown a day last moon, 200 this one —
      // the sums and the delta are arithmetic, not poetry.
      expect(find.text('3000 → 6000 · +100 %'), findsOneWidget);
      expect(find.text('1500 → 3000 · +100 %'), findsOneWidget); // lus
      expect(find.text('270 → 270 · +0 %'), findsOneWidget); // lignes
    });

    testWidgets('one moon of sky keeps the comparison silent', (tester) async {
      await _pump(tester, repo: _FakeRepo());
      await _cross(tester, 'gardien@kenos.local', 'le long secret');
      expect(find.text('LA LUNE CONTRE LA LUNE'), findsNothing);
    });

    testWidgets('the drift shows its ages and kinds', (tester) async {
      await _pump(tester, repo: _FakeRepo(metrics: _metrics(census: true)));
      await _cross(tester, 'gardien@kenos.local', 'le long secret');
      await tester.ensureVisible(find.text('L\'ÂGE DE LA DÉRIVE'));
      await tester.pumpAndSettle();
      expect(find.text('L\'ÂGE DE LA DÉRIVE'), findsOneWidget);
      expect(find.text('MOINS D\'UN JOUR'), findsOneWidget);
      expect(find.text('PLUS DE SEPT JOURS'), findsOneWidget);
      expect(find.text('LES FORMES À LA DÉRIVE'), findsOneWidget);
      expect(find.text('TEXTES'), findsOneWidget);
      expect(find.text('CHANSONS'), findsOneWidget);
      // The themes wear the sky's own names, with their counts.
      expect(find.text('LUMEN · 4'), findsOneWidget);
    });

    testWidgets('an empty drift keeps the census silent', (tester) async {
      await _pump(tester, repo: _FakeRepo());
      await _cross(tester, 'gardien@kenos.local', 'le long secret');
      expect(find.text('L\'ÂGE DE LA DÉRIVE'), findsNothing);
      expect(find.text('LES FORMES À LA DÉRIVE'), findsNothing);
    });

    testWidgets('the guardian keeps an archive', (tester) async {
      // The test VM has no storage to lean on: the path_provider
      // channel answers with an error, the archive falls back to the
      // clipboard — the honest degradation, exercised for real.
      final messenger = tester.binding.defaultBinaryMessenger;
      // The test VM answers neither storage nor clipboard channels.
      // Both are mocked so the honest degradation runs to its end;
      // the platform channel must always reply a JSON-encodable
      // value (a null reply reads as corrupted to the JSON codec).
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async =>
            throw PlatformException(code: 'unavailable', message: 'test VM'),
      );
      messenger.setMockMethodCallHandler(
        // The platform channel speaks JSON (SystemChannels.platform):
        // the mock must wear the same codec or every call reads as
        // corrupted.
        const MethodChannel('flutter/platform', JSONMethodCodec()),
        (call) async => switch (call.method) {
          'Clipboard.setData' => '',
          'Clipboard.hasStrings' => {'value': false},
          _ => false,
        },
      );
      await _pump(tester, repo: _FakeRepo());
      await _cross(tester, 'gardien@kenos.local', 'le long secret');
      await tester.ensureVisible(find.text('ARCHIVER LE REGISTRE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ARCHIVER LE REGISTRE'));
      await tester.pumpAndSettle();
      expect(
        find.text('LE REGISTRE EST COPIÉ — IL VIT DANS TON PRESSE-PAPIERS.'),
        findsOneWidget,
      );
    });

    testWidgets('a revoked rank closes the sky', (tester) async {
      await _pump(tester, repo: _ForbiddenRepo());
      await _cross(tester, 'gardien@kenos.local', 'le long secret');
      expect(find.text('LE CIEL SE DÉROBE'), findsOneWidget);
    });

    testWidgets('a silent ether says so, gently', (tester) async {
      await _pump(tester, repo: _SilentRepo());
      await _cross(tester, 'gardien@kenos.local', 'le long secret');
      expect(find.text('L\'ÉTHER EST ENCORE SILENCIEUX'), findsOneWidget);
    });

    testWidgets('the reports ledger shows shapes, never a text', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _FakeRepo(reports: [_demoReport()]),
      );
      await _cross(tester, 'gardien@kenos.local', 'le long secret');
      expect(find.text('LES SIGNALEMENTS'), findsOneWidget);
      expect(find.text('CONTENU INAPPROPRIÉ · 3 MAINS'), findsOneWidget);
      expect(find.textContaining('POÈME D\'ÉTRANGERS · LUNE : 24 J'),
          findsOneWidget);
      expect(find.text('VOIR DANS LE CIEL'), findsOneWidget);
      expect(find.text('RETRANCHER'), findsOneWidget);
    });

    testWidgets('a quiet sky says it quietly', (tester) async {
      await _pump(tester, repo: _FakeRepo());
      await _cross(tester, 'gardien@kenos.local', 'le long secret');
      expect(find.text('LES SIGNALEMENTS'), findsOneWidget);
      expect(
        find.text('Aucun signal — le ciel est tranquille.'),
        findsOneWidget,
      );
    });

    testWidgets('retraction asks a human, then sends it to the void', (
      tester,
    ) async {
      final repo = _FakeRepo(reports: [_demoReport()]);
      await _pump(tester, repo: repo);
      await _cross(tester, 'gardien@kenos.local', 'le long secret');

      // The ledger is long: the row lives under the fold.
      await tester.ensureVisible(find.text('RETRANCHER'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RETRANCHER'));
      await tester.pumpAndSettle();
      // The rose question, and the refusal that lets the poem live.
      expect(find.text('RENVOYER CE POÈME AU VIDE ?'), findsOneWidget);
      await tester.tap(find.text('LE LAISSER VIVRE'));
      await tester.pumpAndSettle();
      expect(repo.retracted, isEmpty);

      await tester.ensureVisible(find.text('RETRANCHER'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RETRANCHER'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RETRANCHER').last);
      await tester.pumpAndSettle();
      expect(repo.retracted, ['demo-report-1']);
    });

    testWidgets('a reported sky is never a silent sky', (tester) async {
      final metrics = _metrics(silent: true);
      expect(metrics.isSilent, isTrue);
      final flagged = AdminMetrics(
        series: metrics.series,
        live: LiveCounts(
          echoesDrifting: 0,
          usersTotal: 412,
          constellationsOpen: 0,
          constellationsClosed: 1,
          vestigesLive: 29,
          reportsOpen: 0,
          constellationReportsOpen: 1,
        ),
        sectors: metrics.sectors,
        derived: metrics.derived,
      );
      expect(flagged.isSilent, isFalse);
    });
  });
}

Future<void> _pump(WidgetTester tester, {required AdminRepository repo}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: ObservatoryScreen()),
    ),
  );
  await tester.pump();
}

ConstellationReportSummary _demoReport() => ConstellationReportSummary(
      constellationId: 'demo-report-1',
      reportCount: 3,
      latestReason: 'INAPPROPRIATE',
      kind: 'POEM',
      isCurated: false,
      seedX: 0.42,
      seedY: 0.37,
      moonDaysLeft: 24,
      latestReportedAt: DateTime.now().subtract(const Duration(hours: 3)),
    );

Future<void> _cross(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byType(TextField).first, email);
  await tester.enterText(find.byType(TextField).last, password);
  await tester.tap(find.text('FRANCHIR LE SEUIL'));
  await tester.pumpAndSettle();
}

AdminMetrics _metrics({bool silent = false, bool census = false}) => AdminMetrics(
  series: silent
      ? List.generate(
          30,
          (i) => DailyPoint(
            day: '2026-09-${(i % 28 + 1).toString().padLeft(2, '0')}',
            launched: 0,
            consumed: 0,
            rebound: 0,
            traces: 0,
            reports: 0,
            corpsesSeeded: 0,
            corpsesClosed: 0,
            lines: 0,
            newUsers: 0,
            activeReaders: 0,
          ),
        )
      : List.generate(
          30,
          (i) => DailyPoint(
            day: '2026-09-${(i % 28 + 1).toString().padLeft(2, '0')}',
            launched: 10 + i % 7,
            consumed: 8 + i % 5,
            rebound: 2,
            traces: 3,
            reports: 0,
            corpsesSeeded: 2,
            corpsesClosed: 1,
            lines: 9,
            newUsers: 5,
            activeReaders: 6,
          ),
        ),
  live: LiveCounts(
    echoesDrifting: silent ? 0 : 87,
    usersTotal: 412,
    constellationsOpen: 14,
    constellationsClosed: 26,
    vestigesLive: 29,
    reportsOpen: 3,
  ),
  sectors: const [
    SectorCell(x: 3, y: 4, count: 18),
    SectorCell(x: 5, y: 2, count: 7),
  ],
  derived: const DerivedMetrics(
    medianDriftSeconds: 3842,
    traceRate: 0.27,
    reboundRate: 0.14,
  ),
  census: census
      ? const AdminCensus(
          fresh: 11,
          week: 7,
          ancient: 3,
          mediaKinds: {'TEXT': 15, 'SONG': 3, 'EXCERPT': 3},
          themes: {'TEAL': 11, 'INDIGO': 6, 'LUMEN': 4},
        )
      : const AdminCensus(),
);

/// Two moons of sky, deterministic: the older moon sows 100 echoes a
/// day, the younger 200 — every comparison reads as +100 % (or +0 %
/// for the flat counters).
AdminMetrics _metricsTwoMoons() {
  final series = <DailyPoint>[
    for (var i = 0; i < 60; i++)
      DailyPoint(
        day: '2026-0${i < 28 ? 7 : 8}-${(i % 28 + 1).toString().padLeft(2, '0')}',
        launched: i < 30 ? 100 : 200,
        consumed: i < 30 ? 50 : 100,
        rebound: 1,
        traces: 2,
        reports: 0,
        corpsesSeeded: 2,
        corpsesClosed: 1,
        lines: 9,
        newUsers: 5,
        activeReaders: 6,
      ),
  ];
  return AdminMetrics(
    series: series,
    live: const LiveCounts(
      echoesDrifting: 87,
      usersTotal: 412,
      constellationsOpen: 14,
      constellationsClosed: 26,
      vestigesLive: 29,
      reportsOpen: 3,
    ),
    sectors: const [SectorCell(x: 3, y: 4, count: 18)],
    derived: const DerivedMetrics(
      medianDriftSeconds: 3842,
      traceRate: 0.27,
      reboundRate: 0.14,
    ),
  );
}

class _FakeRepo implements AdminRepository {
  int fetches = 0;
  int? askedDays;
  final List<ConstellationReportSummary> reports;
  final AdminMetrics? metrics;
  final retracted = <String>[];

  // V3.57 — the Sower module's memory (proposals + library + sowing).
  final proposals = <VestigeProposal>[];
  final library = <VestigeLibraryEntry>[];
  final sown = <({int count, String theme})>[];
  final decided = <({String id, bool approve})>[];

  _FakeRepo({this.reports = const [], this.metrics});

  @override
  bool get isSignedIn => _in;
  bool _in = false;

  @override
  Future<void> signIn(String email, String password) async => _in = true;

  @override
  Future<void> signOut() async => _in = false;

  @override
  Future<AdminMetrics> fetchMetrics({int days = 30}) async {
    fetches++;
    askedDays = days;
    return metrics ?? _metrics();
  }

  @override
  Future<List<ConstellationReportSummary>> fetchConstellationReports() async =>
      List.of(reports);

  @override
  Future<void> retractConstellation(String constellationId) async =>
      retracted.add(constellationId);

  @override
  Future<List<VestigeProposal>> fetchVestigeProposals() async =>
      List.of(proposals);

  @override
  Future<bool> decideVestigeProposal(String proposalId, bool approve) async {
    decided.add((id: proposalId, approve: approve));
    proposals.removeWhere((p) => p.id == proposalId);
    if (approve) {
      library.insert(
        0,
        VestigeLibraryEntry(
          id: proposalId,
          kind: 'fact',
          text: 'publié par la fausse main',
          source: 'test',
          live: true,
        ),
      );
    }
    return true;
  }

  @override
  Future<List<VestigeLibraryEntry>> fetchVestigeLibrary() async =>
      List.of(library);

  @override
  Future<void> setVestigeLive(String id, bool live) async {
    final index = library.indexWhere((v) => v.id == id);
    if (index >= 0) {
      final e = library[index];
      library[index] = VestigeLibraryEntry(
        id: e.id,
        kind: e.kind,
        text: e.text,
        source: e.source,
        live: live,
        createdOn: e.createdOn,
      );
    }
  }

  @override
  Future<SowResult> sowVestiges({int count = 6, required String theme}) async {
    sown.add((count: count, theme: theme));
    proposals.insert(
      0,
      VestigeProposal(
        id: 'fake-sow-${sown.length}',
        kind: 'haiku',
        text: 'une lumière passe / elle ne demande personne',
        source: 'test',
        theme: theme,
      ),
    );
    return SowResult(sown: 1, generated: count);
  }
}

class _RefusingRepo implements AdminRepository {
  @override
  bool get isSignedIn => false;

  @override
  Future<void> signIn(String email, String password) async =>
      throw GuardianAuthException();

  @override
  Future<void> signOut() async {}

  @override
  Future<AdminMetrics> fetchMetrics({int days = 30}) async => _metrics();

  @override
  Future<List<ConstellationReportSummary>> fetchConstellationReports() async =>
      const [];

  @override
  Future<void> retractConstellation(String constellationId) async {}

  @override
  Future<List<VestigeProposal>> fetchVestigeProposals() async => const [];

  @override
  Future<bool> decideVestigeProposal(String proposalId, bool approve) async =>
      false;

  @override
  Future<List<VestigeLibraryEntry>> fetchVestigeLibrary() async => const [];

  @override
  Future<void> setVestigeLive(String id, bool live) async {}

  @override
  Future<SowResult> sowVestiges({int count = 6, required String theme}) async =>
      const SowResult(sown: 0, reason: 'forbidden');
}

class _ForbiddenRepo implements AdminRepository {
  @override
  bool get isSignedIn => _in;
  bool _in = false;

  @override
  Future<void> signIn(String email, String password) async => _in = true;

  @override
  Future<void> signOut() async => _in = false;

  @override
  Future<AdminMetrics> fetchMetrics({int days = 30}) async =>
      throw GuardianForbiddenException();

  @override
  Future<List<ConstellationReportSummary>> fetchConstellationReports() async =>
      const [];

  @override
  Future<void> retractConstellation(String constellationId) async {}

  @override
  Future<List<VestigeProposal>> fetchVestigeProposals() async => const [];

  @override
  Future<bool> decideVestigeProposal(String proposalId, bool approve) async =>
      false;

  @override
  Future<List<VestigeLibraryEntry>> fetchVestigeLibrary() async => const [];

  @override
  Future<void> setVestigeLive(String id, bool live) async {}

  @override
  Future<SowResult> sowVestiges({int count = 6, required String theme}) async =>
      const SowResult(sown: 0, reason: 'forbidden');
}

class _SilentRepo implements AdminRepository {
  @override
  bool get isSignedIn => _in;
  bool _in = false;

  @override
  Future<void> signIn(String email, String password) async => _in = true;

  @override
  Future<void> signOut() async => _in = false;

  @override
  Future<AdminMetrics> fetchMetrics({int days = 30}) async =>
      _metrics(silent: true);

  @override
  Future<List<ConstellationReportSummary>> fetchConstellationReports() async =>
      const [];

  @override
  Future<void> retractConstellation(String constellationId) async {}

  @override
  Future<List<VestigeProposal>> fetchVestigeProposals() async => const [];

  @override
  Future<bool> decideVestigeProposal(String proposalId, bool approve) async =>
      false;

  @override
  Future<List<VestigeLibraryEntry>> fetchVestigeLibrary() async => const [];

  @override
  Future<void> setVestigeLive(String id, bool live) async {}

  @override
  Future<SowResult> sowVestiges({int count = 6, required String theme}) async =>
      const SowResult(sown: 0, reason: 'empty');
}
