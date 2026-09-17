/// Observatory domain (V3.16): pure aggregates, nothing else.
///
/// The guardian reads shapes and counts — never a text, never an
/// identifier. Every field below mirrors the contentless jsonb of
/// `admin_fetch_metrics` (see the observatory migration).
library;

import '../../echo/data/echo_repository.dart';

class AdminMetrics {
  const AdminMetrics({
    required this.series,
    required this.live,
    required this.sectors,
    required this.derived,
    this.census = const AdminCensus(),
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
    census: AdminCensus.fromJson(
      Map<String, dynamic>.from(json['census'] as Map? ?? const {}),
    ),
  );

  final List<DailyPoint> series;
  final LiveCounts live;
  final List<SectorCell> sectors;
  final DerivedMetrics derived;

  /// V3.56 — what the drifting sky carries: ages, kinds, themes.
  final AdminCensus census;

  /// True when nothing has ever resonated (first-run sky). A reported
  /// artifact breaks the silence: something awaits the guardian's eye.
  bool get isSilent =>
      live.echoesDrifting == 0 &&
      live.constellationReportsOpen == 0 &&
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
    this.salonsSeeded = 0,
    this.corpsesReported = 0,
    this.corpsesRetracted = 0,
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
    salonsSeeded: _int(json['salons_seeded']),
    corpsesReported: _int(json['corpses_reported']),
    corpsesRetracted: _int(json['corpses_retracted']),
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
  final int salonsSeeded;
  final int corpsesReported;
  final int corpsesRetracted;
}

class LiveCounts {
  const LiveCounts({
    required this.echoesDrifting,
    required this.usersTotal,
    required this.constellationsOpen,
    required this.constellationsClosed,
    required this.vestigesLive,
    required this.reportsOpen,
    this.salonsOpen = 0,
    this.constellationReportsOpen = 0,
  });

  factory LiveCounts.fromJson(Map<String, dynamic> json) => LiveCounts(
    echoesDrifting: _int(json['echoes_drifting']),
    usersTotal: _int(json['users_total']),
    constellationsOpen: _int(json['constellations_open']),
    constellationsClosed: _int(json['constellations_closed']),
    vestigesLive: _int(json['vestiges_live']),
    reportsOpen: _int(json['reports_open']),
    salonsOpen: _int(json['salons_open']),
    constellationReportsOpen: _int(json['constellation_reports_open']),
  );

  final int echoesDrifting;
  final int usersTotal;
  final int constellationsOpen;
  final int constellationsClosed;
  final int vestigesLive;
  final int reportsOpen;
  final int salonsOpen;
  final int constellationReportsOpen;
}

class SectorCell {
  const SectorCell({required this.x, required this.y, required this.count});

  final int x;
  final int y;
  final int count;
}

/// The census (V3.56): what the drifting sky carries, as shapes.
///
/// The echoes' three ages (is the ether fluid or congested?), their
/// kinds (a media-less echo is a text, never an absence), their color
/// themes. The keys come from the fixed vocabularies — counts are all
/// there is, exactly like the rest of the ledger.
class AdminCensus {
  const AdminCensus({
    this.fresh = 0,
    this.week = 0,
    this.ancient = 0,
    Map<String, int>? mediaKinds,
    Map<String, int>? themes,
  }) : mediaKinds = mediaKinds ?? const {},
       themes = themes ?? const {};

  factory AdminCensus.fromJson(Map<String, dynamic> json) {
    final ages = Map<String, dynamic>.from(json['echo_ages'] as Map? ?? const {});
    return AdminCensus(
      fresh: _int(ages['fresh']),
      week: _int(ages['week']),
      ancient: _int(ages['ancient']),
      mediaKinds: _countMap(json['media_kinds']),
      themes: _countMap(json['themes']),
    );
  }

  /// Younger than a day.
  final int fresh;

  /// Between one and seven days.
  final int week;

  /// Older than seven days — drifting toward the thirty-day purge.
  final int ancient;

  /// Counts by kind: TEXT (media-less), IMAGE, AUDIO, SONG, EXCERPT.
  final Map<String, int> mediaKinds;

  /// Counts by the sky's three themes: TEAL, INDIGO, LUMEN.
  final Map<String, int> themes;

  /// The whole drifting sky, as the three ages sum it.
  int get drifting => fresh + week + ancient;
}

Map<String, int> _countMap(dynamic raw) {
  final map = raw as Map? ?? const {};
  return {
    for (final key in map.keys) key.toString(): _int(map[key]),
  };
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

/// One REPORTED public artifact, as the guardian sees it (V3.51):
/// shapes only — how many hands flagged it, why (a code, never a
/// text), what it is, where it rests (the sky-link coordinate), and
/// the moon it has left. The poem itself is read in the public sky,
/// never in this ledger.
class ConstellationReportSummary {
  const ConstellationReportSummary({
    required this.constellationId,
    required this.reportCount,
    required this.latestReason,
    required this.kind,
    required this.isCurated,
    required this.seedX,
    required this.seedY,
    required this.moonDaysLeft,
    this.latestReportedAt,
  });

  factory ConstellationReportSummary.fromJson(Map<String, dynamic> json) =>
      ConstellationReportSummary(
        constellationId: json['constellation_id'] as String? ?? '',
        reportCount: _int(json['report_count']),
        latestReason: json['latest_reason'] as String? ?? 'OTHER',
        kind: json['kind'] as String? ?? 'POEM',
        isCurated: json['is_curated'] == true,
        seedX: (json['seed_x'] as num?)?.toDouble() ?? 0.5,
        seedY: (json['seed_y'] as num?)?.toDouble() ?? 0.5,
        moonDaysLeft: _int(json['moon_days_left']),
        latestReportedAt: json['latest_reported_at'] == null
            ? null
            : DateTime.tryParse(json['latest_reported_at'] as String),
      );

  final String constellationId;
  final int reportCount;
  final String latestReason;

  /// 'POEM' or 'MELODY' — what the ring is, not what it says.
  final String kind;

  /// True = the Curator's own (a rights or taste problem); false =
  /// strangers' hands (a moderation problem).
  final bool isCurated;

  final double seedX;
  final double seedY;
  final int moonDaysLeft;
  final DateTime? latestReportedAt;

  /// The shared report taxonomy wears words (the echo grammar).
  String get reasonLabel {
    for (final reason in EchoReportReason.values) {
      if (reason.wire == latestReason) return reason.label;
    }
    return latestReason;
  }
}

int _int(dynamic v) => v is num ? v.toInt() : 0;
