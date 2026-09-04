/// Observatory domain (V3.16): pure aggregates, nothing else.
///
/// The guardian reads shapes and counts — never a text, never an
/// identifier. Every field below mirrors the contentless jsonb of
/// `admin_fetch_metrics` (see the observatory migration).
library;

class AdminMetrics {
  const AdminMetrics({
    required this.series,
    required this.live,
    required this.sectors,
    required this.derived,
  });

  factory AdminMetrics.fromJson(Map<String, dynamic> json) => AdminMetrics(
    series: ((json['series'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => DailyPoint.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false),
    live: LiveCounts.fromJson(
      Map<String, dynamic>.from(json['live'] as Map? ?? const {}),
    ),
    sectors: ((json['sectors'] as List?) ?? const [])
        .whereType<List>()
        .where((cell) => cell.length >= 3)
        .map(
          (cell) => SectorCell(
            x: _int(cell[0]),
            y: _int(cell[1]),
            count: _int(cell[2]),
          ),
        )
        .toList(growable: false),
    derived: DerivedMetrics.fromJson(
      Map<String, dynamic>.from(json['derived'] as Map? ?? const {}),
    ),
  );

  final List<DailyPoint> series;
  final LiveCounts live;
  final List<SectorCell> sectors;
  final DerivedMetrics derived;

  /// True when nothing has ever resonated (first-run sky).
  bool get isSilent =>
      live.echoesDrifting == 0 &&
      series.every((d) => d.launched == 0 && d.consumed == 0 && d.rebound == 0);
}

class DailyPoint {
  const DailyPoint({
    required this.day,
    required this.launched,
    required this.consumed,
    required this.rebound,
    required this.traces,
    required this.reports,
    required this.corpsesSeeded,
    required this.corpsesClosed,
    required this.lines,
    required this.newUsers,
    required this.activeReaders,
  });

  factory DailyPoint.fromJson(Map<String, dynamic> json) => DailyPoint(
    day: json['day'] as String? ?? '',
    launched: _int(json['echoes_launched']),
    consumed: _int(json['echoes_consumed']),
    rebound: _int(json['echoes_rebound']),
    traces: _int(json['traces_left']),
    reports: _int(json['reports_filed']),
    corpsesSeeded: _int(json['corpses_seeded']),
    corpsesClosed: _int(json['corpses_closed']),
    lines: _int(json['lines_contributed']),
    newUsers: _int(json['new_users']),
    activeReaders: _int(json['active_readers']),
  );

  final String day; // YYYY-MM-DD (UTC, the server's clock)
  final int launched;
  final int consumed;
  final int rebound;
  final int traces;
  final int reports;
  final int corpsesSeeded;
  final int corpsesClosed;
  final int lines;
  final int newUsers;
  final int activeReaders;
}

class LiveCounts {
  const LiveCounts({
    required this.echoesDrifting,
    required this.usersTotal,
    required this.constellationsOpen,
    required this.constellationsClosed,
    required this.vestigesLive,
    required this.reportsOpen,
  });

  factory LiveCounts.fromJson(Map<String, dynamic> json) => LiveCounts(
    echoesDrifting: _int(json['echoes_drifting']),
    usersTotal: _int(json['users_total']),
    constellationsOpen: _int(json['constellations_open']),
    constellationsClosed: _int(json['constellations_closed']),
    vestigesLive: _int(json['vestiges_live']),
    reportsOpen: _int(json['reports_open']),
  );

  final int echoesDrifting;
  final int usersTotal;
  final int constellationsOpen;
  final int constellationsClosed;
  final int vestigesLive;
  final int reportsOpen;
}

class SectorCell {
  const SectorCell({required this.x, required this.y, required this.count});

  final int x;
  final int y;
  final int count;
}

class DerivedMetrics {
  const DerivedMetrics({
    this.medianDriftSeconds,
    this.traceRate,
    this.reboundRate,
  });

  factory DerivedMetrics.fromJson(Map<String, dynamic> json) => DerivedMetrics(
    medianDriftSeconds: (json['median_drift_seconds'] as num?)?.toInt(),
    traceRate: (json['trace_rate_30d'] as num?)?.toDouble(),
    reboundRate: (json['rebound_rate_30d'] as num?)?.toDouble(),
  );

  final int? medianDriftSeconds;
  final double? traceRate;
  final double? reboundRate;
}

int _int(dynamic v) => v is num ? v.toInt() : 0;
