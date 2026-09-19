import 'dart:math' as math;

import '../domain/admin_metrics.dart';
import 'admin_repository.dart';

/// Demo path: the Observatory, offline, with the exact backend
/// semantics (iso-semantic demo rule). Any non-empty pair of
/// credentials opens the threshold — there is nothing real to guard,
/// and the shapes shown are a deterministic, plausible sky.
class LocalAdminRepository implements AdminRepository {
  LocalAdminRepository() {
    // V3.57 — the Sower's demo shelves.
    _proposals.addAll([
      const VestigeProposal(
        id: 'demo-proposal-1',
        kind: 'fact',
        text: 'La lumière du Soleil met huit minutes pour nous atteindre '
            '— distance appelée unité astronomique.',
        source: 'astronomie',
        theme: 'astronomie',
        proposedAt: '2026-09-17 08:12',
      ),
      const VestigeProposal(
        id: 'demo-proposal-2',
        kind: 'etymology',
        text: 'COSMOS — du grec κόσμος, « ordre, parure ». L\'univers '
            'n\'est pas chaos : un tissu où chaque poussière chante '
            'l\'harmonie.',
        source: 'grec ancien',
        theme: 'astronomie',
        proposedAt: '2026-09-17 08:12',
      ),
    ]);
    _library.addAll([
      const VestigeLibraryEntry(
        id: 'demo-vestige-1',
        kind: 'haiku',
        text: 'Poussière d\'étoile / un grain sur l\'aile d\'une nuit / '
            'et le temps s\'efface.',
        source: 'kenos',
        live: true,
        createdOn: '2026-09-01',
      ),
      const VestigeLibraryEntry(
        id: 'demo-vestige-2',
        kind: 'fact',
        text: 'Nuage de Magellan : galaxie naine visible à l\'œil nu, '
            'mais sa lumière met 163 000 ans à nous parvenir.',
        source: 'astronomie',
        live: false,
        createdOn: '2026-09-03',
      ),
    ]);
    // V3.51 — a deterministic pair of flagged artifacts, shaped like
    // the ether's answer (metadata only, never a text). Retraction
    // really removes: the demo keeps the gesture honest.
    _reports.addAll([
      ConstellationReportSummary(
        constellationId: 'demo-report-1',
        reportCount: 3,
        latestReason: 'INAPPROPRIATE',
        kind: 'POEM',
        isCurated: false,
        seedX: 0.42,
        seedY: 0.37,
        moonDaysLeft: 24,
        latestReportedAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      ConstellationReportSummary(
        constellationId: 'demo-report-2',
        reportCount: 1,
        latestReason: 'OTHER',
        kind: 'MELODY',
        isCurated: true,
        seedX: 0.68,
        seedY: 0.61,
        moonDaysLeft: 11,
        latestReportedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ]);
  }

  bool _signedIn = false;
  final List<ConstellationReportSummary> _reports = [];

  /// V3.57 — the Sower module's demo: two shards awaiting taste, a
  /// small library with one retired shard, and a canned harvest the
  /// SEMER button grows (the loop, demonstrated without an engine).
  final List<VestigeProposal> _proposals = [];
  final List<VestigeLibraryEntry> _library = [];
  int _demoSowCount = 0;

  @override
  bool get isSignedIn => _signedIn;

  @override
  Future<void> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw GuardianAuthException();
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _signedIn = true;
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
  }

  @override
  Future<List<ConstellationReportSummary>> fetchConstellationReports() async {
    if (!_signedIn) throw GuardianAuthException('no_session');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List.of(_reports);
  }

  @override
  Future<void> retractConstellation(String constellationId) async {
    if (!_signedIn) throw GuardianAuthException('no_session');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _reports.removeWhere((r) => r.constellationId == constellationId);
  }

  @override
  Future<List<VestigeProposal>> fetchVestigeProposals() async {
    if (!_signedIn) throw GuardianAuthException('no_session');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.of(_proposals);
  }

  @override
  Future<bool> decideVestigeProposal(String proposalId, bool approve) async {
    if (!_signedIn) throw GuardianAuthException('no_session');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final proposal = _proposals.where((p) => p.id == proposalId).firstOrNull;
    if (proposal == null) return false;
    _proposals.remove(proposal);
    if (approve) {
      _library.insert(
        0,
        VestigeLibraryEntry(
          id: proposal.id,
          kind: proposal.kind,
          text: proposal.text,
          source: proposal.source,
          live: true,
          createdOn: proposal.proposedAt.split(' ').first,
        ),
      );
    }
    return true;
  }

  @override
  Future<List<VestigeLibraryEntry>> fetchVestigeLibrary() async {
    if (!_signedIn) throw GuardianAuthException('no_session');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.of(_library);
  }

  @override
  Future<void> setVestigeLive(String id, bool live) async {
    if (!_signedIn) throw GuardianAuthException('no_session');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final index = _library.indexWhere((v) => v.id == id);
    if (index < 0) throw GuardianForbiddenException();
    final entry = _library[index];
    _library[index] = VestigeLibraryEntry(
      id: entry.id,
      kind: entry.kind,
      text: entry.text,
      source: entry.source,
      live: live,
      createdOn: entry.createdOn,
    );
  }

  @override
  Future<SowResult> sowVestiges({int count = 6, required String theme}) async {
    if (!_signedIn) throw GuardianAuthException('no_session');
    await Future<void>.delayed(const Duration(milliseconds: 900));
    // The demo sows a canned shard per pass — the loop is real (the
    // proposal awaits taste), the engine is not.
    _demoSowCount += 1;
    _proposals.insert(
      0,
      VestigeProposal(
        id: 'demo-sow-$_demoSowCount',
        kind: 'haiku',
        text: 'Une lumière passe / elle ne demande personne / le vide '
            'la regarde.',
        source: 'kenos',
        theme: theme,
        proposedAt: 'démo',
      ),
    );
    return SowResult(sown: 1, generated: count, reason: 'demo');
  }

  @override
  Future<AdminMetrics> fetchMetrics({int days = 30}) async {
    if (!_signedIn) throw GuardianAuthException('no_session');
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final today = DateTime.now();
    final series = <DailyPoint>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      // Deterministic pseudo-sky: gentle growth, weekend lulls, a
      // spike last Thursday — the same sky on every demo run.
      final noise = math.sin(i * 1.7) * 3 + math.sin(i * 0.31) * 2;
      final lull =
          (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday)
          ? -4
          : 0;
      final spike = i == 4 ? 9 : 0;
      final launched = math.max(
        0,
        (18 + (days - i) * 0.4 + noise + lull + spike).round(),
      );
      final consumed = math.max(0, launched - 2 - (noise / 2).round());
      series.add(
        DailyPoint(
          day:
              '${d.year.toString().padLeft(4, '0')}-'
              '${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}',
          launched: launched,
          consumed: consumed,
          rebound: math.max(0, (consumed * 0.14).round()),
          traces: math.max(0, (consumed * 0.27).round()),
          reports: i % 9 == 0 ? 1 : 0,
          corpsesSeeded: math.max(0, (3 + noise / 2).round() ~/ 2),
          corpsesClosed: math.max(0, (2 + noise / 3).round() ~/ 2),
          lines: 9 + (noise).round() ~/ 2,
          newUsers: 4 + (i * 7) % 5,
          activeReaders: 6 + (i * 13) % 7,
          // A hand-over now and then — never on the last two days, so
          // the live pending count stays honest to the demo's story.
          braisesPassed: i > 1 && i % 6 == 2 ? 1 : 0,
        ),
      );
    }

    // Demo sector pressure: a deterministic scatter (tiny LCG), not an
    // arithmetic lattice — the sky never draws visible grid lines.
    var seed = 42;
    int draw() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    }

    // V3.56 — the census: the same drifting sky, split with
    // deterministic honesty. The three ages sum to the drift, and so
    // do the kinds and the themes — exactly the server's shapes.
    final drifting = series.last.launched * 7;
    final fresh = (drifting * 0.55).round();
    final week = (drifting * 0.3).round();
    final tealShare = (drifting * 0.55).round();
    final indigoShare = (drifting * 0.3).round();

    return AdminMetrics(
      series: series,
      live: LiveCounts(
        echoesDrifting: drifting,
        usersTotal: 412,
        constellationsOpen: 14,
        constellationsClosed: 26,
        vestigesLive: 29,
        reportsOpen: 3,
        salonsOpen: 2,
        constellationReportsOpen: _reports.length,
        // One ember mid-hand-over — the demo sky has its travellers
        // changing bodies too (V3.60c).
        braisesPending: 1,
      ),
      sectors: List.generate(
        22,
        (i) => SectorCell(x: draw() % 8, y: draw() % 8, count: 2 + draw() % 22),
      ),
      derived: DerivedMetrics(
        medianDriftSeconds: 3842,
        traceRate: 0.27,
        reboundRate: 0.14,
      ),
      census: AdminCensus(
        fresh: fresh,
        week: week,
        ancient: drifting - fresh - week,
        mediaKinds: {
          'TEXT': drifting - 9,
          'IMAGE': 4,
          'AUDIO': 1,
          'SONG': 3,
          'EXCERPT': 1,
        },
        themes: {
          'TEAL': tealShare,
          'INDIGO': indigoShare,
          'LUMEN': drifting - tealShare - indigoShare,
        },
      ),
    );
  }
}
