import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../cosmic_map/application/sky_link.dart';
import '../data/admin_providers.dart';
import '../data/admin_repository.dart';
import '../domain/admin_metrics.dart';
import 'widgets/guardian_gate_sheet.dart';
import 'widgets/sector_grid.dart';
import 'widgets/spectrum_bars.dart';

/// L'Observatoire (V3.16) — the guardian's usage view of the ether.
///
/// Shapes and counts only: no text, no identifier, no coordinate ever
/// reaches this screen. The door is hidden (long-press L'Aube on the
/// map); the threshold holds the one guardian account; the session
/// lives in memory and closes with the screen.
class ObservatoryScreen extends ConsumerStatefulWidget {
  const ObservatoryScreen({super.key});

  @override
  ConsumerState<ObservatoryScreen> createState() => _ObservatoryScreenState();
}

enum _Phase { threshold, busy, data, error, silent }

class _ObservatoryScreenState extends ConsumerState<ObservatoryScreen> {
  _Phase _phase = _Phase.threshold;
  AdminMetrics? _metrics;
  List<ConstellationReportSummary> _reports = const [];
  // The ledger always asks the ether for its widest sky (three moons,
  // the RPC's ceiling); the window only chooses what the eye sees.
  int _windowDays = 30;
  String? _gateError;
  bool _gateBusy = false;
  bool _retractBusy = false;
  String? _retractError;

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  @override
  void initState() {
    super.initState();
    if (_repo.isSignedIn) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.busy);
    try {
      // Both answers or none: a moderation list the guardian cannot
      // trust is worse than a sky that says it withdrew.
      final answers = await Future.wait([
        _repo.fetchMetrics(days: 90),
        _repo.fetchConstellationReports(),
      ]);
      final metrics = answers[0] as AdminMetrics;
      final reports = answers[1] as List<ConstellationReportSummary>;
      setState(() {
        _metrics = metrics;
        _reports = reports;
        _retractError = null;
        _phase = metrics.isSilent ? _Phase.silent : _Phase.data;
      });
    } on GuardianForbiddenException {
      // The claim is gone (revoked?): close the door, say why, stop.
      await _repo.signOut();
      setState(() => _phase = _Phase.error);
    } catch (_) {
      setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _crossThreshold(String email, String password) async {
    if (_gateBusy) return;
    setState(() {
      _gateBusy = true;
      _gateError = null;
    });
    try {
      await _repo.signIn(email, password);
    } on GuardianAuthException {
      setState(() {
        _gateBusy = false;
        _gateError = 'LE SEUIL REFUSE CES MOTS.';
      });
      return;
    } catch (_) {
      setState(() {
        _gateBusy = false;
        _gateError = 'LE SEUIL EST INTROUVABLE — LE CIEL SE DÉROBE.';
      });
      return;
    }
    setState(() => _gateBusy = false);
    await _load();
  }

  Future<void> _closeThreshold() async {
    await _repo.signOut();
    setState(() {
      _metrics = null;
      _gateError = null;
      _phase = _Phase.threshold;
    });
  }

  /// V3.51 — the guardian's one gesture. A destruction wears rose, as
  /// everywhere in the sanctuary; a human confirms, never a count.
  Future<void> _retract(ConstellationReportSummary report) async {
    if (_retractBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.voidBlack,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.fade(AppColors.rose, 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'RENVOYER CE POÈME AU VIDE ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    letterSpacing: 2,
                    color: AppColors.pureLight,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Il quittera l\'éther, ses lignes et ses signaux avec lui. '
                  'Aucun compteur ne décide — ton œil seul a lu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.fade(AppColors.pureLight, 0.55),
                  ),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('LE LAISSER VIVRE'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.roseText,
                  ),
                  child: const Text('RETRANCHER'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _retractBusy = true;
      _retractError = null;
    });
    try {
      await _repo.retractConstellation(report.constellationId);
      await _load();
    } on GuardianForbiddenException {
      await _repo.signOut();
      setState(() => _phase = _Phase.error);
    } catch (_) {
      setState(() => _retractError = 'LE CIEL SE DÉROBE — RETRANCHER À NOUVEAU.');
    } finally {
      if (mounted) setState(() => _retractBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      appBar: AppBar(
        backgroundColor: AppColors.voidBlack,
        foregroundColor: AppColors.pureLight,
        title: Text(
          'L\'OBSERVATOIRE',
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 11,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        // Manual recalibration only — no live counters, in the sky's
        // spirit: the guardian asks, the ether answers.
        actions: [
          if (_phase == _Phase.data || _phase == _Phase.silent)
            TextButton(
              onPressed: _load,
              child: Text(
                'RAFRAÎCHIR',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
            ),
        ],
      ),
      body: switch (_phase) {
        _Phase.threshold => GuardianGatePanel(
          onSubmit: _crossThreshold,
          busy: _gateBusy,
          error: _gateError,
        ),
        _Phase.busy => _centered('CHARGEMENT…'),
        _Phase.error => _centeredPanel(
          'LE CIEL SE DÉROBE',
          'FRANCHIR À NOUVEAU',
          _repo.isSignedIn ? _load : _closeThreshold,
        ),
        _Phase.silent => _centeredPanel(
          'L\'ÉTHER EST ENCORE SILENCIEUX',
          'RECHERCHER',
          _load,
        ),
        _Phase.data => _ledger(_metrics!),
      },
    );
  }

  Widget _centered(String text) => Center(
    child: Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: 9,
        letterSpacing: 3,
        color: AppColors.fade(AppColors.pureLight, 0.4),
      ),
    ),
  );

  Widget _centeredPanel(
    String text,
    String action,
    Future<void> Function() onAction,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 10,
              letterSpacing: 2,
              height: 1.8,
              color: AppColors.fade(AppColors.pureLight, 0.5),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => onAction(),
              child: Text(
                action,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledger(AdminMetrics m) {
    return SingleChildScrollView(
      // Wide screens: the ledger keeps its readable measure — the same
      // grammar as the Aube and the Mirror.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'L\'astronome ne lit aucun message.\nIl compte les étoiles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 16,
                    height: 1.6,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(height: 34),
                _sectionLabel('L\'ÉTAT DU CIEL'),
                const SizedBox(height: 14),
                // Two measures per row on every phone, one honest
                // ceiling on tablets — never a squeeze.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = ((constraints.maxWidth - 12) / 2).clamp(
                      96.0,
                      176.0,
                    );
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final card in _measures(m))
                          SizedBox(width: cardWidth, child: card),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 38),
                Row(
                  children: [
                    Expanded(
                      child: _sectionLabel('LE SPECTRE — $_windowDays JOURS'),
                    ),
                    for (final window in const [7, 30, 90]) _windowButton(window),
                  ],
                ),
                const SizedBox(height: 10),
                _legend(),
                const SizedBox(height: 6),
                SpectrumBars(series: _windowed(m.series)),
                const SizedBox(height: 38),
                _sectionLabel('LA GRILLE DES SECTEURS'),
                const SizedBox(height: 14),
                SectorGrid(sectors: m.sectors),
                const SizedBox(height: 10),
                Text(
                  'Chaque cellule : la densité d\'un secteur du ciel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 12,
                    height: 1.7,
                    color: AppColors.fade(AppColors.pureLight, 0.55),
                  ),
                ),
                const SizedBox(height: 38),
                _sectionLabel('LES SIGNALEMENTS'),
                const SizedBox(height: 14),
                ..._reportsSection(),
                const SizedBox(height: 38),
                _sectionLabel('CE QUE LES FORMES DISENT'),
                const SizedBox(height: 14),
                _derivedLine(
                  'DÉRIVE MÉDIANE',
                  _driftLabel(m.derived.medianDriftSeconds),
                ),
                _derivedLine(
                  'TRACES LAISSÉES',
                  _rateLabel(m.derived.traceRate),
                ),
                _derivedLine('RENAISSANCES', _rateLabel(m.derived.reboundRate)),
                const SizedBox(height: 44),
                Text(
                  'Ces formes ne disent rien de personne.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 14,
                    height: 1.8,
                    color: AppColors.fade(AppColors.pureLight, 0.5),
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _closeThreshold(),
                    child: const Text(
                      'FERMER LE SEUIL',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 10,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _measures(AdminMetrics m) => [
    _MeasureCard(
      label: 'Échos à la dérive',
      value: m.live.echoesDrifting,
      color: AppColors.teal,
    ),
    _MeasureCard(
      label: 'Voyageurs',
      value: m.live.usersTotal,
      color: AppColors.indigo,
    ),
    _MeasureCard(
      label: 'Anneaux ouverts',
      value: m.live.constellationsOpen,
      color: AppColors.purple,
    ),
    _MeasureCard(
      label: 'Poèmes achevés',
      value: m.live.constellationsClosed,
      color: AppColors.indigo,
    ),
    _MeasureCard(
      label: 'Vestiges vivants',
      value: m.live.vestigesLive,
      color: AppColors.ember,
    ),
    _MeasureCard(
      label: 'Signalements',
      value: m.live.reportsOpen,
      color: AppColors.cyan,
    ),
    _MeasureCard(
      label: 'Artefacts signalés',
      value: m.live.constellationReportsOpen,
      color: AppColors.cyan,
    ),
  ];

  /// V3.51 — the artifact guard: every REPORTED public artifact, as
  /// shapes (counts, reasons, ages, the seed coordinate for the sky
  /// link). The guardian reads the poems themselves in the public
  /// sky — this ledger never carries a text.
  List<Widget> _reportsSection() {
    if (_reports.isEmpty && _retractError == null) {
      return [
        Text(
          'Aucun signal — le ciel est tranquille.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.serifItalic,
            fontSize: 12,
            height: 1.7,
            color: AppColors.fade(AppColors.pureLight, 0.55),
          ),
        ),
      ];
    }
    return [
      if (_retractError != null) ...[
        Text(
          _retractError!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9,
            letterSpacing: 1.5,
            color: AppColors.fade(AppColors.roseText, 0.8),
          ),
        ),
        const SizedBox(height: 12),
      ],
      for (final report in _reports)
        _ReportRow(
          report: report,
          busy: _retractBusy,
          onSee: () => context.go(
            '/ciel/${SkyLink.pathOf(Offset(report.seedX, report.seedY))}',
          ),
          onRetract: () => _retract(report),
        ),
      const SizedBox(height: 8),
      Text(
        'Le gardien lit le poème dans le ciel public, à la position '
        'donnée — jamais ici. Retrancher est un geste humain.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.serifItalic,
          fontSize: 12,
          height: 1.7,
          color: AppColors.fade(AppColors.pureLight, 0.55),
        ),
      ),
    ];
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: 9,
      letterSpacing: 2,
      color: AppColors.fade(AppColors.pureLight, 0.5),
    ),
  );

  /// One of the three windows, 7/30/90 days. The chosen one speaks;
  /// the others wait, faded — the grammar of RAFRAÎCHIR.
  Widget _windowButton(int days) {
    final selected = days == _windowDays;
    return TextButton(
      onPressed: selected ? null : () => setState(() => _windowDays = days),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.fade(
          AppColors.pureLight,
          selected ? 0.9 : 0.4,
        ),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        '$days J',
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 8.5,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  /// The visible slice: the last `_windowDays` of what the ether gave.
  List<DailyPoint> _windowed(List<DailyPoint> series) =>
      series.length <= _windowDays
          ? series
          : series.sublist(series.length - _windowDays);

  Widget _legend() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _legendDot(AppColors.teal, 'semés'),
      const SizedBox(width: 18),
      _legendDot(AppColors.indigo, 'lus'),
    ],
  );

  Widget _legendDot(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8, color: AppColors.fade(c, 0.85)),
      const SizedBox(width: 7),
      Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 9,
          letterSpacing: 1,
          color: AppColors.fade(AppColors.pureLight, 0.5),
        ),
      ),
    ],
  );

  Widget _derivedLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9,
            letterSpacing: 1,
            color: AppColors.fade(AppColors.pureLight, 0.45),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 12,
            color: AppColors.pureLight,
          ),
        ),
      ],
    ),
  );

  String _driftLabel(int? seconds) {
    if (seconds == null) return '—';
    if (seconds < 90) return '$seconds s';
    if (seconds < 5400) return '${(seconds / 60).round()} min';
    if (seconds < 129600) return '${(seconds / 3600).round()} h';
    return '${(seconds / 86400).round()} j';
  }

  String _rateLabel(double? rate) =>
      rate == null ? '—' : '${(rate * 100).round()} %';
}

/// One reported artifact: shapes only (the reason as a word, the
/// count of hands, what it is, the moon left) and the two guardian
/// gestures — go READ it where it rests, or send it back to the void.
class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.report,
    required this.busy,
    required this.onSee,
    required this.onRetract,
  });

  final ConstellationReportSummary report;
  final bool busy;
  final VoidCallback onSee;
  final VoidCallback onRetract;

  String get _kindLabel => report.kind == 'MELODY' ? 'CHANSON' : 'POÈME';

  String get _handsLabel =>
      report.reportCount == 1 ? 'UNE MAIN' : '${report.reportCount} MAINS';

  String get _ageLabel {
    final at = report.latestReportedAt;
    if (at == null) return '';
    final delta = DateTime.now().difference(at);
    if (delta.inMinutes < 2) return 'À L\'INSTANT';
    if (delta.inMinutes < 60) return 'IL Y A ${delta.inMinutes} MIN';
    if (delta.inHours < 24) return 'IL Y A ${delta.inHours} H';
    return 'IL Y A ${delta.inDays} J';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.fade(AppColors.cyan, 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${report.reasonLabel} · $_handsLabel',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    letterSpacing: 1,
                    color: AppColors.fade(AppColors.cyan, 0.85),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$_kindLabel${report.isCurated ? ' CURATÉ' : ' D\'ÉTRANGERS'}'
            ' · LUNE : ${report.moonDaysLeft} J'
            '${_ageLabel.isEmpty ? '' : ' · $_ageLabel'}',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 8.5,
              letterSpacing: 1,
              color: AppColors.fade(AppColors.pureLight, 0.5),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onSee,
                child: Text(
                  'VOIR DANS LE CIEL',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    letterSpacing: 2,
                    color: AppColors.fade(AppColors.teal, 0.9),
                  ),
                ),
              ),
              TextButton(
                onPressed: busy ? null : onRetract,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.roseText,
                ),
                child: const Text(
                  'RETRANCHER',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeasureCard extends StatelessWidget {
  const _MeasureCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label : $value',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.fade(color, 0.3), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 9,
                letterSpacing: 1,
                color: AppColors.fade(color, 0.6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value.toString(),
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: 26,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
