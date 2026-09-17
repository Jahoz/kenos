import 'dart:math' as math;

import '../domain/admin_metrics.dart';
import 'admin_repository.dart';

/// Demo path: the Observatory, offline, with the exact backend
/// semantics (iso-semantic demo rule). Any non-empty pair of
/// credentials opens the threshold — there is nothing real to guard,
/// and the shapes shown are a deterministic, plausible sky.
class LocalAdminRepository implements AdminRepository {
  LocalAdminRepository() {
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
